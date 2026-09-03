local ffi = require("ffi")

ffi.cdef([[
	const char *OpenSSL_version(int type);
]])

local path = os.getenv("POST_LIBCRYPTO")
if not path or path == "" then
	error("POST_LIBCRYPTO must name the pinned OpenSSL libcrypto library", 0)
end

local crypto = ffi.load(path)
local M = {}

function M.library_path()
	return path
end

function M.version()
	return ffi.string(crypto.OpenSSL_version(0))
end

return M
