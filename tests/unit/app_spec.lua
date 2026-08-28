local app = require("app")

describe("post application planning", function()
	local config = {
		executable = "himalaya",
		config = "/etc/unix-mail-redux/himalaya.toml",
		account = "unix_mail_redux",
	}

	it("uses an explicit project identity", function()
		local plan = app.plan({
			verb = "list",
			identity = "Validate_GUI",
			format = "json",
		}, { config = config })
		assert.are.equal("validate_gui", plan.identity)
		assert.are.equal("Agents/validate_gui", plan.mailbox)
		assert.same({
			"himalaya", "--config", "/etc/unix-mail-redux/himalaya.toml",
			"--account", "unix_mail_redux", "--json",
			"envelope", "list", "--mailbox", "Agents/validate_gui",
		}, plan.argv)
	end)

	it("infers identity from a Git root", function()
		local plan = app.plan({ verb = "read", id = "42", format = "human" }, {
			config = config,
			git_root = "/home/peter/Code/sctui_rust",
		})
		assert.are.equal("sctui_rust", plan.identity)
		assert.are.equal("Agents/sctui_rust", plan.mailbox)
	end)

	it("uses Peter's INBOX outside a project", function()
		local plan = app.plan({ verb = "list", format = "human" }, {
			config = config,
			git_root = nil,
		})
		assert.are.equal("peter", plan.identity)
		assert.are.equal("INBOX", plan.mailbox)
	end)

	it("does not require a project for fleet status", function()
		local plan = app.plan({ verb = "status", format = "json" }, {
			config = config,
		})
		assert.is_nil(plan.identity)
		assert.is_nil(plan.mailbox)
		assert.same({
			"himalaya", "--config", "/etc/unix-mail-redux/himalaya.toml",
			"--account", "unix_mail_redux", "--json", "mailbox", "list",
		}, plan.argv)
	end)

	it("rejects an unsafe explicit identity before transport", function()
		assert.has_error(function()
			app.plan({ verb = "list", identity = "../escape", format = "human" }, {
				config = config,
			})
		end, "invalid project identity: ../escape")
	end)

	it("plans a project-to-project message with its body on stdin", function()
		local plan = app.plan({
			verb = "to",
			recipient = "validate",
			subject = "Bound the scanner",
			body = "Please reproduce this under a cgroup ceiling.\n",
			format = "human",
			confirm = false,
		}, {
			config = config,
			git_root = "/home/peter/Code/unix_mail_redux",
			domain = "agents.home.arpa",
			human_local_part = "peter",
		})

		assert.are.equal("unix_mail_redux", plan.identity)
		assert.are.equal("unix_mail_redux@agents.home.arpa", plan.from)
		assert.are.equal("validate@agents.home.arpa", plan.to)
		assert.are.equal("Please reproduce this under a cgroup ceiling.\n", plan.stdin)
		assert.are.equal("Bound the scanner", plan.subject)
		assert.are.equal("Please reproduce this under a cgroup ceiling.\n", plan.body)
		assert.same({
			"himalaya", "--config", "/etc/unix-mail-redux/himalaya.toml",
			"--account", "unix_mail_redux",
			"message", "compose",
			"--from", "unix_mail_redux@agents.home.arpa",
			"--to", "validate@agents.home.arpa",
			"--subject", "Bound the scanner",
			"--save", "Sent", "--send",
		}, plan.argv)
	end)

	it("rejects header injection in a message subject", function()
		assert.has_error(function()
			app.plan({
				verb = "to",
				recipient = "validate",
				subject = "Hello\nBcc: outside@example.com",
				body = "Nope",
				format = "human",
				confirm = false,
			}, {
				config = config,
				git_root = "/home/peter/Code/unix_mail_redux",
				domain = "agents.home.arpa",
				human_local_part = "peter",
			})
		end, "message subject must be one line")
	end)

	it("rejects an incomplete message before transport", function()
		assert.has_error(function()
			app.plan({ verb = "to", recipient = "validate", format = "human" }, {
				config = config,
				git_root = "/home/peter/Code/unix_mail_redux",
				domain = "agents.home.arpa",
				human_local_part = "peter",
			})
		end, "message subject is required")
	end)
end)
