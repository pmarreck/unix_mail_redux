local uv = require("luv")
local M = {}

-- Preflight all inputs before SMTP; only stdin needs a private temporary file.
-- MIME encoding belongs to Himalaya, not this adapter.
function M.prepare(paths, input)
	local prepared = {paths = {}}
	local temporary, descriptor
	function prepared.cleanup()
		if descriptor then uv.fs_close(descriptor); descriptor = nil end
		if temporary then uv.fs_unlink(temporary); temporary = nil end
	end
	local ok, err = pcall(function()
		for _, path in ipairs(paths or {}) do
			local attachment = path
			if path == "-" or path == "@stdin" then
				assert(not temporary, "only one stdin attachment is allowed")
				descriptor, temporary = assert(uv.fs_mkstemp(
					(os.getenv("TMPDIR") or uv.os_tmpdir()) .. "/post-stdin-XXXXXX"))
				assert(uv.fs_fchmod(descriptor, 384))
				local offset = 0
				while true do
					local chunk, read_error = input:read(65536)
					assert(not read_error, read_error)
					if not chunk then break end
					local written = 0
					while written < #chunk do
						local count = assert(uv.fs_write(descriptor, chunk:sub(written + 1), offset))
						assert(count > 0, "short stdin attachment write")
						written = written + count; offset = offset + count
					end
				end
				assert(uv.fs_close(descriptor)); descriptor = nil
				attachment = temporary
			else
				local stat = uv.fs_stat(path)
				if not stat or stat.type ~= "file" or not uv.fs_access(path, "R") then
					error("attachment is not a readable regular file: " .. path, 0)
				end
				-- Make leading-hyphen filenames unambiguous to the backend parser.
				if not path:match("^/") and not path:match("^%a:[/\\]") and not path:match("^\\\\") then
					attachment = uv.cwd() .. "/" .. path
				end
			end
			prepared.paths[#prepared.paths + 1] = attachment
		end
	end)
	if not ok then prepared.cleanup(); error(err, 0) end
	return prepared
end

return M
