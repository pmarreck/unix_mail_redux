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
end)
