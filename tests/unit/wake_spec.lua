local wake = require("wake")

describe("wake policy", function()
	it("recognizes empty prompts for the supported agent TUIs", function()
		local cases = {
			{ command = "claude", cursor_line = "❯   ", screen = "" },
			{ command = "grok", cursor_line = " │ ❯                                      │ ", screen = "" },
		}

		for _, case in ipairs(cases) do
			assert.are.equal("empty_prompt", wake.classify_pane(case), case.command)
		end
	end)

	it("keeps an idle Codex prompt passive until a native wake can start a turn", function()
		assert.are.equal("idle_passive", wake.classify_pane({
			command = "codex",
			cursor_line = "› Ask Codex to do anything",
			screen = "",
		}))
	end)

	it("allows an explicitly accepted detached Codex terminal wake", function()
		assert.are.equal("empty_prompt", wake.classify_pane({
			command = "codex",
			cursor_line = "› Ask Codex to do anything",
			screen = "",
			allow_codex_terminal_wake = true,
		}))
	end)

	it("classifies drafts and dialogs conservatively", function()
		local cases = {
			{
				command = "claude",
				cursor_line = "❯ I am still typing",
				screen = "",
				expected = "busy",
			},
			{
				command = "codex",
				cursor_line = "› Fix the parser",
				screen = "",
				expected = "busy",
			},
			{
				command = "claude",
				cursor_line = "❯ ",
				screen = "Do you trust this folder? (y/n)",
				expected = "dialog",
			},
			{
				command = "bash",
				cursor_line = "$ ",
				screen = "",
				expected = "absent",
			},
		}

		for _, case in ipairs(cases) do
			assert.are.equal(case.expected, wake.classify_pane(case), case.command)
		end
	end)

	it("classifies terminal states as a set", function()
		local cases = {
			{ state = "absent", action = "defer" },
			{ state = "attached", action = "notify" },
			{ state = "busy", action = "notify" },
			{ state = "idle_passive", action = "notify" },
			{ state = "dialog", action = "defer" },
			{ state = "crashed", action = "notify" },
			{ state = "empty_prompt", action = "wake" },
		}

		for _, case in ipairs(cases) do
			local decision = wake.decide({
				message_key = "1:42",
				terminal_state = case.state,
				authorized = true,
				now = 1000,
				last_wake = 0,
				cooldown = 60,
				seen = {},
			})
			assert.are.equal(case.action, decision.action, case.state)
		end
	end)

	it("never wakes without explicit authorization", function()
		local decision = wake.decide({
			message_key = "1:42",
			terminal_state = "empty_prompt",
			authorized = false,
			now = 1000,
			last_wake = 0,
			cooldown = 60,
			seen = {},
		})
		assert.are.equal("notify", decision.action)
	end)

	it("deduplicates delivery and respects cooldown", function()
		local duplicate = wake.decide({
			message_key = "1:42",
			terminal_state = "empty_prompt",
			authorized = true,
			now = 1000,
			last_wake = 0,
			cooldown = 60,
			seen = { ["1:42"] = true },
		})
		assert.are.equal("ignore", duplicate.action)

		local cooling = wake.decide({
			message_key = "1:43",
			terminal_state = "empty_prompt",
			authorized = true,
			now = 1000,
			last_wake = 980,
			cooldown = 60,
			seen = {},
		})
		assert.are.equal("defer", cooling.action)
	end)
end)
