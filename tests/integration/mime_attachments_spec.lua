local uv = require("luv")
local process = require("process")

describe("real Himalaya MIME attachments (offline)", function()
	it("preserves two filenames and binary bytes without an SMTP connection", function()
		local root = assert(uv.fs_mkdtemp((os.getenv("TMPDIR") or "/tmp") .. "/mime-attachments-XXXXXX"))
		local function write(name, body)
			local path = root .. "/" .. name
			local f = assert(io.open(path, "wb")); assert(f:write(body)); assert(f:close())
			return path
		end
		local mailbox = root .. "/mail"
		assert(uv.fs_mkdir(mailbox, 448))
		-- The pinned Himalaya enables m2dir, not the legacy maildir backend.
		local config = write("himalaya.toml", '[accounts.test]\ndefault = true\nm2dir.root = '
			.. require("cjson").encode(mailbox):gsub("\\/", "/") .. '\n')
		local a = write("a b.md", "# Read me\n")
		local bytes = {}; for n = 0, 255 do bytes[#bytes+1] = string.char(n) end
		local binary = table.concat(bytes)
		local b = write("binary.bin", binary)
		local result = process.run({"himalaya", "--config", config, "message", "compose",
			"--from", "a@example.test", "--to", "b@example.test", "--subject", "offline",
			"--attach", a, "--attach", b}, {stdin="body", capture=true})
		assert.equal(0, result.rc, result.stderr .. result.stdout)
		assert.truthy(result.stdout:find('filename="a b.md"', 1, true))
		assert.truthy(result.stdout:find('filename="binary.bin"', 1, true))
		local _, count = result.stdout:gsub("Content%-Disposition: attachment", "")
		assert.equal(2, count)
		local encoded = assert(result.stdout:match('filename="binary.bin".-Content%-Transfer%-Encoding: base64\r\n\r\n(.-)\r\n%-%-'))
		local decoded = process.run({os.getenv("POST_OPENSSL") or "openssl", "base64", "-d", "-A"},
			{stdin=encoded:gsub("%s", ""), capture=true})
		assert.equal(0, decoded.rc, decoded.stderr)
		assert.equal(binary, decoded.stdout)
		for _, path in ipairs({config,a,b}) do assert(uv.fs_unlink(path)) end
		for _, name in ipairs({"cur", "new", "tmp"}) do
			if uv.fs_stat(mailbox .. "/" .. name) then assert(uv.fs_rmdir(mailbox .. "/" .. name)) end
		end
		assert(uv.fs_rmdir(mailbox))
		assert(uv.fs_rmdir(root))
	end)
end)
