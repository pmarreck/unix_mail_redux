local uv = require("luv")
local bridge = require("herdr_mail")
local runtime = require("herdr_watch")
describe("durable mail notice", function()
	it("writes atomically with private mode, including an owned symlink inbox", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/mail-notice-XXXXXX"))
		local datetime = "2026-09-10T16:00:00-04:00"
		local body = bridge.render("validate", 1, datetime, {})
		local path = runtime.write_notice(root, "validate", body, datetime)
		local file = assert(io.open(path)); assert.equal(body, file:read("*a")); file:close()
		assert.equal(384, uv.fs_stat(path).mode % 512)
		local second = runtime.write_notice(root, "validate", body .. "new delivery\n", datetime)
		assert.is_not.equal(path, second)
		-- Processing/trashing an old notice must not remove a concurrent arrival.
		assert(uv.fs_unlink(path)); assert.is_not_nil(uv.fs_stat(second))
		assert(uv.fs_unlink(second)); assert(uv.fs_rmdir(root .. "/inbox"))
		assert(uv.fs_symlink(root, root .. "/inbox"))
		local linked = runtime.write_notice(root, "validate", body, datetime)
		assert.equal(root, linked:match("^(.*)/[^/]+$"))
		assert.equal(384, uv.fs_stat(linked).mode % 512)
		assert(uv.fs_unlink(linked))
		assert(uv.fs_unlink(root .. "/inbox")); assert(uv.fs_rmdir(root))
	end)
	it("classifies directory targets and rejects dangling, looping, file, or writable links", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/mail-link-XXXXXX"))
		local target = root .. "/target"
		local inbox = root .. "/inbox"
		assert(uv.fs_mkdir(target, 448))
		local file = assert(io.open(root .. "/file", "w")); file:close()
		for _, case in ipairs({
			{target="target", mode=448, allowed=true},
			{target=target, mode=493, allowed=true},
			{target="target", mode=511, allowed=false},
			{target="absent", mode=448, allowed=false},
			{target="inbox", mode=448, allowed=false},
			{target="file", mode=448, allowed=false},
		}) do
			assert(uv.fs_chmod(target, case.mode))
			assert(uv.fs_symlink(case.target, inbox))
			local ok, path = pcall(runtime.write_notice, root, "code", "notice", "2026-09-18T13:00:00-04:00")
			assert.equal(case.allowed, ok, case.target)
			if ok then assert(uv.fs_unlink(path)) end
			assert(uv.fs_unlink(inbox))
		end
		assert(uv.fs_unlink(root .. "/file")); assert(uv.fs_rmdir(target)); assert(uv.fs_rmdir(root))
	end)
end)
