local wake = require("wake")

describe("wake policy", function()
	it("classifies terminal states as a set", function()
		local cases = {
			{ state = "absent", action = "defer" },
			{ state = "busy", action = "notify" },
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

