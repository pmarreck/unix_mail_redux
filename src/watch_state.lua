local cjson = require("cjson")
local uv = require("luv")

local M = {}

local function empty_state()
	return { version = 1, messages = {}, last_wake = {} }
end

local function validate(state)
	if type(state) ~= "table" or state.version ~= 1
		or type(state.messages) ~= "table"
		or type(state.last_wake) ~= "table"
	then
		error("invalid watch state schema", 0)
	end
	for key, status in pairs(state.messages) do
		if type(key) ~= "string" or type(status) ~= "table"
			or (status.noticed_at ~= nil and type(status.noticed_at) ~= "number")
			or (status.woken_at ~= nil and type(status.woken_at) ~= "number")
		then
			error("invalid watch state schema", 0)
		end
	end
	for project, timestamp in pairs(state.last_wake) do
		if type(project) ~= "string" or type(timestamp) ~= "number" then
			error("invalid watch state schema", 0)
		end
	end
	return state
end

local function parent_directory(path)
	return path:match("^(.*)[/\\][^/\\]+$")
end

local function make_directories(path)
	if not path or path == "" or uv.fs_stat(path) then
		return
	end
	make_directories(parent_directory(path))
	local ok, message, code = uv.fs_mkdir(path, 448)
	if not ok and code ~= "EEXIST" then
		error("cannot create watch state directory: " .. tostring(message), 0)
	end
end

function M.load(path)
	local fd, open_error, open_code = uv.fs_open(path, "r", 0)
	if not fd then
		if open_code == "ENOENT" then
			return empty_state()
		end
		error("cannot open watch state: " .. tostring(open_error), 0)
	end
	local stat, stat_error = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		error("cannot stat watch state: " .. tostring(stat_error), 0)
	end
	local data, read_error = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	if not data then
		error("cannot read watch state: " .. tostring(read_error), 0)
	end
	local ok, decoded = pcall(cjson.decode, data)
	if not ok then
		error("invalid watch state JSON", 0)
	end
	return validate(decoded)
end

function M.save(path, state)
	validate(state)
	make_directories(parent_directory(path))
	local temporary = path .. ".tmp." .. tostring(uv.os_getpid())
	local fd, open_error = uv.fs_open(temporary, "w", 384)
	if not fd then
		error("cannot create watch state: " .. tostring(open_error), 0)
	end
	local data = cjson.encode(state) .. "\n"
	local written, write_error = uv.fs_write(fd, data, 0)
	if not written then
		uv.fs_close(fd)
		uv.fs_unlink(temporary)
		error("cannot write watch state: " .. tostring(write_error), 0)
	end
	local synced, sync_error = uv.fs_fsync(fd)
	local closed, close_error = uv.fs_close(fd)
	if not synced or not closed then
		uv.fs_unlink(temporary)
		error("cannot sync watch state: " .. tostring(sync_error or close_error), 0)
	end
	local renamed, rename_error = uv.fs_rename(temporary, path)
	if not renamed then
		uv.fs_unlink(temporary)
		error("cannot replace watch state: " .. tostring(rename_error), 0)
	end
	assert(uv.fs_chmod(path, 384))
	return true
end

return M
