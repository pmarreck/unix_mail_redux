local uv = require("luv")
local attachments = require("attachments")

describe("attachment preflight", function()
	it("accepts binary and empty regular files, including spaced and UTF-8 paths", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/attachments-XXXXXX"))
		local paths = {root .. "/résumé a.bin", root .. "/empty.md"}
		local file = assert(io.open(paths[1], "wb")); file:write("\0\255\r\n"); file:close()
		file = assert(io.open(paths[2], "wb")); file:close()
		local prepared = attachments.prepare(paths)
		assert.same(paths, prepared.paths)
		prepared.cleanup()
		assert(uv.fs_unlink(paths[1])); assert(uv.fs_unlink(paths[2])); assert(uv.fs_rmdir(root))
	end)
	it("rejects missing files, directories and unreadable files before transport", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/attachments-XXXXXX"))
		local path = root .. "/unreadable"
		local file = assert(io.open(path, "wb")); file:close(); assert(uv.fs_chmod(path, 0))
		for _, bad in ipairs({root .. "/absent", root, path}) do
			assert.has_error(function() attachments.prepare({bad}) end)
		end
		assert(uv.fs_chmod(path, 384)); assert(uv.fs_unlink(path)); assert(uv.fs_rmdir(root))
	end)
	it("spools stdin privately and cleans it up without touching source files", function()
		local input = {read=function(_, size) assert.equal(65536, size); return nil end}
		local prepared = attachments.prepare({"@stdin"}, input)
		assert.equal(1, #prepared.paths)
		assert.equal(384, uv.fs_stat(prepared.paths[1]).mode % 512)
		assert.equal(0, uv.fs_stat(prepared.paths[1]).size)
		prepared.cleanup()
		assert.is_nil(uv.fs_stat(prepared.paths[1]))
	end)
end)
