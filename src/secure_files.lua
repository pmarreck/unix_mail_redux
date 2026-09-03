local uv = require("luv")

local M = {}
local DEFAULT_MAXIMUM_BYTES = 16 * 1024 * 1024
local MAXIMUM_SECRET_BYTES = 4096
local MAXIMUM_MESSAGE_BYTES = 16 * 1024 * 1024

local function fail(message)
	error(message, 0)
end

local function close(descriptor)
	local closed, close_error = uv.fs_close(descriptor)
	if not closed then
		fail("could not close file: " .. tostring(close_error))
	end
end

local function valid_filename(name)
	return type(name) == "string"
		and name ~= "."
		and name ~= ".."
		and name:match("^[A-Za-z0-9._-]+$") ~= nil
end

local function write_atomic(directory, file)
	local temporary = directory .. "/." .. file.name .. ".partial"
	local final = directory .. "/" .. file.name
	local descriptor, open_error = uv.fs_open(temporary, "wx", file.mode)
	if not descriptor then
		fail("could not create ceremony file " .. temporary .. ": "
			.. tostring(open_error))
	end

	local written = 0
	local write_ok, write_error = pcall(function()
		while written < #file.contents do
			local count, error_message = uv.fs_write(descriptor,
				file.contents:sub(written + 1), written)
			if not count or count == 0 then
				fail("could not write ceremony file " .. temporary .. ": "
					.. tostring(error_message))
			end
			written = written + count
		end
		local synced, sync_error = uv.fs_fsync(descriptor)
		if not synced then
			fail("could not sync ceremony file " .. temporary .. ": "
				.. tostring(sync_error))
		end
	end)
	local closed, close_error = uv.fs_close(descriptor)
	if not write_ok then
		fail(tostring(write_error))
	end
	if not closed then
		fail("could not close ceremony file " .. temporary .. ": "
			.. tostring(close_error))
	end
	local renamed, rename_error = uv.fs_rename(temporary, final)
	if not renamed then
		fail("could not publish ceremony file " .. final .. ": "
			.. tostring(rename_error))
	end
	local protected, chmod_error = uv.fs_chmod(final, file.mode)
	if not protected then
		fail("could not set ceremony file permissions on " .. final .. ": "
			.. tostring(chmod_error))
	end
end

function M.create_directory(directory, files)
	if type(directory) ~= "string" or directory == "" then
		fail("ceremony output directory must be a non-empty path")
	end
	local names = {}
	for _, file in ipairs(files) do
		if not valid_filename(file.name) then
			fail("invalid ceremony filename: " .. tostring(file.name))
		end
		if names[file.name] then
			fail("duplicate ceremony filename: " .. file.name)
		end
		names[file.name] = true
		if type(file.contents) ~= "string" then
			fail("ceremony file contents must be a string: " .. file.name)
		end
		if file.mode ~= 384 and file.mode ~= 420 then
			fail("unsupported ceremony file mode: " .. tostring(file.mode))
		end
	end

	local created, create_error, create_code = uv.fs_mkdir(directory, 448)
	if not created then
		if create_code == "EEXIST" then
			fail("refusing to replace existing output directory: " .. directory)
		end
		fail("could not create ceremony output directory " .. directory .. ": "
			.. tostring(create_error))
	end
	local protected, chmod_error = uv.fs_chmod(directory, 448)
	if not protected then
		fail("could not protect ceremony output directory " .. directory .. ": "
			.. tostring(chmod_error))
	end
	for _, file in ipairs(files) do
		write_atomic(directory, file)
	end
end

function M.read_file(path, maximum_bytes)
	maximum_bytes = maximum_bytes or DEFAULT_MAXIMUM_BYTES
	local descriptor, open_error = uv.fs_open(path, "r", 0)
	if not descriptor then
		fail("could not open input file " .. path .. ": " .. tostring(open_error))
	end
	local stat, stat_error = uv.fs_fstat(descriptor)
	if not stat then
		close(descriptor)
		fail("could not inspect input file " .. path .. ": " .. tostring(stat_error))
	end
	if stat.type ~= "file" then
		close(descriptor)
		fail("input path is not a regular file: " .. path)
	end
	if stat.size > maximum_bytes then
		close(descriptor)
		fail("input file exceeds " .. maximum_bytes .. " bytes: " .. path)
	end
	local contents, read_error = uv.fs_read(descriptor, stat.size, 0)
	close(descriptor)
	if not contents then
		fail("could not read input file " .. path .. ": " .. tostring(read_error))
	end
	if #contents ~= stat.size then
		fail("input file changed while it was being read: " .. path)
	end
	return contents
end

function M.read_secret(path)
	if path ~= "-" then
		return M.read_file(path, MAXIMUM_SECRET_BYTES)
	end
	local contents = io.stdin:read(MAXIMUM_SECRET_BYTES + 1) or ""
	if #contents > MAXIMUM_SECRET_BYTES then
		fail("secret from stdin exceeds " .. MAXIMUM_SECRET_BYTES .. " bytes")
	end
	return contents
end

function M.read_input(path)
	if path ~= "-" and path ~= "@stdin" then
		return M.read_file(path, MAXIMUM_MESSAGE_BYTES)
	end
	local contents = io.stdin:read(MAXIMUM_MESSAGE_BYTES + 1) or ""
	if #contents > MAXIMUM_MESSAGE_BYTES then
		fail("S/MIME input exceeds " .. MAXIMUM_MESSAGE_BYTES .. " bytes")
	end
	return contents
end

return M
