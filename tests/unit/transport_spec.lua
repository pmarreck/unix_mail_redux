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
			"--mailbox", "Agents.odd;touch nope",
		}, transport.list(config, "Agents.odd;touch nope", "json"))
	end)

	it("builds read argv with an explicit mailbox", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "read", "42",
			"--mailbox", "Agents.validate",
		}, transport.read(config, "Agents.validate", "42", "human"))
	end)

	it("builds an explicit Seen flag update", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"flag", "add", "--flag", "seen", "42",
			"--mailbox", "Agents.validate",
		}, transport.mark_seen(config, "Agents.validate", "42"))
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

	it("builds a send command without exposing the body in argv", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "compose",
			"--from", "einstein@agents.home.arpa",
			"--to", "validate@agents.home.arpa",
			"--subject", "Bound the scanner",
			"--save", "Sent",
			"--send",
		}, transport.compose(
			config,
			"einstein@agents.home.arpa",
			"validate@agents.home.arpa",
			"Bound the scanner"
		))
	end)

	it("builds separate reply preparation and candidate-send commands", function()
		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "reply", "42",
			"--mailbox", "Agents.validate",
			"--from", "validate@agents.home.arpa",
		}, transport.reply_candidate(
			config,
			"Agents.validate",
			"42",
			"validate@agents.home.arpa"
		))

		assert.same({
			"/run/current-system/sw/bin/himalaya",
			"--config", "/home/test/.config/post/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "send", "--save", "Sent",
		}, transport.send_candidate(config))
	end)
end)
