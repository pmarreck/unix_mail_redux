local secure_files = require("secure_files")
local uv = require("luv")

local function read_file(path)
	local descriptor = assert(uv.fs_open(path, "r", 0))
	local stat = assert(uv.fs_fstat(descriptor))
	local contents = assert(uv.fs_read(descriptor, stat.size, 0))
	assert(uv.fs_close(descriptor))
	return contents
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

describe("secure ceremony files", function()
	it("creates a protected directory atomically and refuses replacement", function()
		local root = assert(uv.fs_mkdtemp(
			(os.getenv("TMPDIR") or "/tmp") .. "/post-secure-files-XXXXXX"))
		local output = root .. "/mail identity"
		secure_files.create_directory(output, {
			{ name = "secret.bin", contents = "PRIVATE", mode = 384 },
			{ name = "public.pem", contents = "PUBLIC", mode = 420 },
		})

		assert.are.equal(448, bit.band(assert(uv.fs_stat(output)).mode, 511))
		assert.are.equal(384,
			bit.band(assert(uv.fs_stat(output .. "/secret.bin")).mode, 511))
		assert.are.equal(420,
			bit.band(assert(uv.fs_stat(output .. "/public.pem")).mode, 511))
		assert.are.equal("PRIVATE", read_file(output .. "/secret.bin"))
		assert.are.equal("PUBLIC", read_file(output .. "/public.pem"))
		assert.has_error(function()
			secure_files.create_directory(output, {
				{ name = "secret.bin", contents = "REPLACED", mode = 384 },
			})
		end, "refusing to replace existing output directory: " .. output)
		assert.are.equal("PRIVATE", read_file(output .. "/secret.bin"))
		remove_tree(root)
	end)

	it("reads bounded regular files and rejects oversized input", function()
		local root = assert(uv.fs_mkdtemp(
			(os.getenv("TMPDIR") or "/tmp") .. "/post-secure-read-XXXXXX"))
		local path = root .. "/secret"
		local descriptor = assert(uv.fs_open(path, "w", 384))
		assert(uv.fs_write(descriptor, "a sufficiently long passphrase\n", 0))
		assert(uv.fs_close(descriptor))

		assert.are.equal("a sufficiently long passphrase\n",
			secure_files.read_secret(path))
		assert.has_error(function()
			secure_files.read_file(path, 8)
		end, "input file exceeds 8 bytes: " .. path)
		remove_tree(root)
	end)
end)
