local replay = require("smime_replay")
local uv = require("luv")

local function remove_tree(path)
	local iterator = uv.fs_scandir(path)
	if iterator then
		while true do
			local name, kind = uv.fs_scandir_next(iterator)
			if not name then break end
			local child = path .. "/" .. name
			if kind == "directory" then
				remove_tree(child)
			else
				assert(uv.fs_unlink(child))
			end
		end
	end
	assert(uv.fs_rmdir(path))
end

describe("S/MIME replay guard", function()
	it("durably claims one verified signature and refuses its replay", function()
		local parent = assert(uv.fs_mkdtemp(
			(os.getenv("TMPDIR") or "/tmp") .. "/post-smime-replay-XXXXXX"))
		local directory = parent .. "/nested/replays"
		local key = "sha256:" .. string.rep("ab", 32)
		assert(replay.claim(directory, {
			key = key,
			email = "peter@agents.home.arpa",
			verified_at = 1788440400,
		}))

		local path = directory .. "/sha256-" .. string.rep("ab", 32) .. ".json"
		local stat = assert(uv.fs_stat(path))
		assert.are.equal(384, bit.band(stat.mode, 511))
		local descriptor = assert(uv.fs_open(path, "r", 0))
		local contents = assert(uv.fs_read(descriptor, stat.size, 0))
		assert(uv.fs_close(descriptor))
		assert.same({
			version = 1,
			replay_key = key,
			signer_email = "peter@agents.home.arpa",
			verified_at = 1788440400,
		}, require("cjson").decode(contents))

		assert.has_error(function()
			replay.claim(directory, {
				key = key,
				email = "peter@agents.home.arpa",
				verified_at = 1788440401,
			})
		end, "replayed S/MIME signature: " .. key)
		remove_tree(parent)
	end)

	it("rejects malformed claims before creating state", function()
		local parent = assert(uv.fs_mkdtemp(
			(os.getenv("TMPDIR") or "/tmp") .. "/post-smime-replay-invalid-XXXXXX"))
		local directory = parent .. "/replays"
		assert.has_error(function()
			replay.claim(directory, {
				key = "sha256:not-a-digest",
				email = "peter@agents.home.arpa",
				verified_at = 1788440400,
			})
		end, "invalid S/MIME replay key")
		assert.is_nil(uv.fs_stat(directory))
		remove_tree(parent)
	end)
end)
