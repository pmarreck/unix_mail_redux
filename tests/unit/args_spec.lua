local args = require("args")

describe("post argument parsing", function()
	it("defaults to the current project's unread list", function()
		assert.same({ verb = "list", format = "human" }, args.parse({}))
	end)

	it("accepts global options in any position and later values win", function()
		assert.same({
			verb = "read",
			id = "42",
			identity = "validate_gui",
			format = "json",
		}, args.parse({ "--as", "validate", "read", "42", "--json", "--as", "validate_gui" }))
	end)

	it("parses a confirmed non-interactive reply", function()
		assert.same({
			verb = "reply",
			id = "42",
			format = "human",
			confirm = false,
		}, args.parse({ "reply", "42", "--yes" }))
	end)

	it("parses composition without losing spaces", function()
		assert.same({
			verb = "to",
			recipient = "validate",
			subject = "Pin validate Release",
			body = "Please pin the known-good commit.",
			format = "human",
		}, args.parse({
			"to", "validate",
			"--subject", "Pin validate Release",
			"--body", "Please pin the known-good commit.",
		}))
	end)

	it("parses deterministic watcher controls and paths with spaces", function()
		assert.same({
			verb = "watch",
			format = "human",
			once = true,
			interval = 3.5,
			maildir = "/tmp/mail root",
			state_file = "/tmp/state root/watch.json",
			wake = false,
		}, args.parse({
			"watch", "--once", "--interval", "3.5",
			"--maildir", "/tmp/mail root",
			"--state-file", "/tmp/state root/watch.json",
			"--no-wake",
		}))
	end)

	it("parses an offline private-CA creation ceremony", function()
		assert.same({
			verb = "smime",
			action = "init-ca",
			output = "/media/Offline Keys/agent mail ca",
			passphrase_file = "/run/user/1000/ca passphrase",
			format = "human",
		}, args.parse({
			"smime", "init-ca",
			"--out", "/media/Offline Keys/agent mail ca",
			"--passphrase-file", "/run/user/1000/ca passphrase",
		}))
	end)

	it("parses an Apple S/MIME identity issuance ceremony in any option order", function()
		assert.same({
			verb = "smime",
			action = "issue",
			ca = "/media/Offline Keys/agent mail ca",
			output = "/media/Offline Keys/peter iphone",
			email = "peter@agents.home.arpa",
			name = "Peter iPhone",
			ca_passphrase_file = "/run/user/1000/ca passphrase",
			identity_passphrase_file = "/run/user/1000/iphone passphrase",
			format = "human",
		}, args.parse({
			"--name", "Peter iPhone",
			"smime", "issue",
			"--identity-passphrase-file", "/run/user/1000/iphone passphrase",
			"--ca", "/media/Offline Keys/agent mail ca",
			"--email", "peter@agents.home.arpa",
			"--out", "/media/Offline Keys/peter iphone",
			"--ca-passphrase-file", "/run/user/1000/ca passphrase",
		}))
	end)

	it("rejects incomplete or secret-bearing S/MIME arguments", function()
		assert.has_error(function()
			args.parse({ "smime", "init-ca", "--out", "/tmp/ca" })
		end, "smime init-ca requires --passphrase-file")
		assert.has_error(function()
			args.parse({ "smime", "issue", "--email", "peter@agents.home.arpa" })
		end, "smime issue requires --ca")
		assert.has_error(function()
			args.parse({ "smime", "issue", "--passphrase", "visible-secret" })
		end, "unknown option: --passphrase")
	end)

	it("parses signed-message verification with an explicit trust root", function()
		assert.same({
			verb = "smime",
			action = "verify",
			input = "/tmp/signed message.eml",
			ca_certificate = "/media/public root/root-ca.pem",
			email = "peter@agents.home.arpa",
			replay_directory = "/var/lib/post/replays",
			format = "human",
		}, args.parse({
			"--input", "/tmp/signed message.eml",
			"smime", "verify",
			"--replay-dir", "/var/lib/post/replays",
			"--email", "peter@agents.home.arpa",
			"--ca-cert", "/media/public root/root-ca.pem",
		}))
	end)

	it("recognizes help and about", function()
		assert.same({ verb = "help", format = "human" }, args.parse({ "-h" }))
		assert.same({ verb = "about", format = "human" }, args.parse({ "--about" }))
	end)

	it("rejects unknown switches and missing values", function()
		assert.has_error(function() args.parse({ "--wat" }) end, "unknown option: --wat")
		assert.has_error(function() args.parse({ "read" }) end, "read requires a message ID")
		assert.has_error(function() args.parse({ "--as" }) end, "--as requires a project identity")
		assert.has_error(function() args.parse({ "--body" }) end, "--body requires a value")
		assert.has_error(function() args.parse({ "watch", "--interval", "0" }) end,
			"--interval requires a positive number")
	end)
end)
