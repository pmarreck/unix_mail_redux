local state_store = require("watch_state")
local uv = require("luv")

describe("mail watch state", function()
	local directory
	local path

	before_each(function()
		directory = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/post-state-XXXXXX"))
		path = directory .. "/nested/watch.json"
	end)

	after_each(function()
		local nested = directory .. "/nested"
		uv.fs_unlink(path)
		uv.fs_rmdir(nested)
		uv.fs_rmdir(directory)
	end)

	it("treats a missing file as empty state", function()
		assert.same({ version = 1, messages = {}, last_wake = {} }, state_store.load(path))
	end)

	it("atomically round-trips message and cooldown state", function()
		local expected = {
			version = 1,
			messages = {
				["validate\0mail-1"] = { noticed_at = 1000, woken_at = 1001 },
			},
			last_wake = { validate = 1001 },
		}
		assert(state_store.save(path, expected))
		assert.same(expected, state_store.load(path))
		local stat = assert(uv.fs_stat(path))
		assert.are.equal(384, stat.mode % 512)
	end)

	it("rejects corrupt state instead of repeating wakes from an empty fallback", function()
		assert(uv.fs_mkdir(directory .. "/nested", 448))
		local fd = assert(uv.fs_open(path, "w", 384))
		assert(uv.fs_write(fd, "not json", -1))
		assert(uv.fs_close(fd))
		assert.has_error(function()
			state_store.load(path)
		end, "invalid watch state JSON")
	end)
end)
