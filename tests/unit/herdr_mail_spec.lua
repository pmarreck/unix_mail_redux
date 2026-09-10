local bridge = require("herdr_mail")

describe("Herdr mail routing", function()
	it("classifies the complete recipient set without guessing between agents", function()
		local agents = {
			{ pane_id = "w1:p1", agent = "codex", cwd = "/home/operator", name = "einstein" },
			{ pane_id = "w2:p1", agent = "claude", cwd = "/code/validate" },
			{ pane_id = "w3:p1", agent = "grok", cwd = "/fork/validate" },
			{ pane_id = "w4:p1", agent = "claude", cwd = "/code/a space", name = "space" },
		}
		local routes = { code = "/home/operator", einstein = "/home/operator" }
		local expected = { code = "/home/operator", einstein = "/home/operator", space = "/code/a space" }
		for _, recipient in ipairs({ "code", "einstein", "space", "validate", "absent" }) do
			local target = bridge.resolve(agents, recipient, routes)
			assert.equal(expected[recipient], target and target.cwd, recipient)
		end
		assert.equal("/offline", bridge.resolve({}, "offline", { offline = "/offline" }).cwd)
	end)
	it("does not map a duplicate explicit name to an arbitrary cwd", function()
		assert.is_nil(bridge.resolve({
			{ name = "dup", cwd = "/a", pane_id = "p1" },
			{ name = "dup", cwd = "/b", pane_id = "p2" },
		}, "dup", {}))
	end)
	it("renders fixed metadata-only notices with an injected datetime", function()
		local notice = bridge.render("validate", 2, "2026-09-10T16:00:00-04:00", {})
		local metadata = require("cjson").decode(notice:match("^%-%-%-json\n(.-)\n%-%-%-"))
		assert.equal("llmsend/v1", metadata.schema)
		assert.matches('Run post list --as validate', notice, 1, true)
		assert.matches('2026-09-10T16:00:00-04:00', notice, 1, true)
		assert.has_error(function() bridge.render("../escape", 1, "now", {}) end)
	end)
	it("only generates a side-band Herdr command, never terminal input", function()
		assert.same({ "herdr", "notification", "show", "Mail: validate",
			"--body", "2 unread messages. Run post list --as validate", "--sound", "none" },
			bridge.notify_argv("herdr", "validate", 2))
	end)
end)
