local maildir = require("maildir")
local uv = require("luv")

local function mkdir(path)
	assert(uv.fs_mkdir(path, 448))
end

local function touch(path)
	local fd = assert(uv.fs_open(path, "w", 384))
	assert(uv.fs_close(fd))
end

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

describe("Maildir delivery discovery", function()
	it("finds only direct project messages in new directories", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/post-maildir-XXXXXX"))
		mkdir(root .. "/.Agents.validate")
		mkdir(root .. "/.Agents.validate/new")
		mkdir(root .. "/.Agents.validate/cur")
		mkdir(root .. "/.Agents.rarz")
		mkdir(root .. "/.Agents.rarz/new")
		mkdir(root .. "/.Sent")
		mkdir(root .. "/.Sent/new")
		touch(root .. "/.Agents.validate/new/unique-1:2,")
		touch(root .. "/.Agents.validate/cur/already-read:2,S")
		touch(root .. "/.Agents.rarz/new/unique-2")
		touch(root .. "/.Sent/new/outbound")

		assert.same({
			{ project = "rarz", key = "unique-2" },
			{ project = "validate", key = "unique-1" },
		}, maildir.scan(root))
		remove_tree(root)
	end)
end)
