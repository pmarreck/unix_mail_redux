local transport = require("transport")

describe("Himalaya command construction", function()
	local config = {
		executable = "/run/current-system/sw/bin/himalaya",
		config = "/home/test/.config/post/himalaya.toml",
		account = "unix_mail_redux",
	}

	it("builds argv without shell interpolation", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"--json",
			"envelope", "list",
			"--mailbox", "Agents/odd;touch nope",
		}, transport.list(config, "Agents/odd;touch nope", "json"))
	end)

	it("builds read argv with explicit mailbox and seen behavior", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "read", "42",
			"--mailbox", "Agents/validate",
			"--seen",
		}, transport.read(config, "Agents/validate", "42", "human"))
	end)

	it("builds fleet status argv", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"--json",
			"mailbox", "list",
		}, transport.status(config, "json"))
	end)
end)
