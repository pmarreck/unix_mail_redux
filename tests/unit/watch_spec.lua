local watch = require("watch")

local function delivery(project, key)
	return { project = project, key = key }
end

describe("mail watch cycle", function()
	it("notifies and wakes an authorized empty project once", function()
		local next_state, actions = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = watch.empty_state(),
			terminal_states = { validate = "empty_prompt" },
			authorized = { validate = true },
			now = 1000,
			cooldown = 60,
			notice_retry = 300,
		})

		assert.same({
			{ type = "notify", project = "validate", count = 1 },
			{ type = "wake", project = "validate", count = 1 },
		}, actions)
		assert.are.equal(1000, next_state.messages["validate\0mail-1"].noticed_at)
		assert.are.equal(1000, next_state.messages["validate\0mail-1"].woken_at)

		local repeated_state, repeated = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = next_state,
			terminal_states = { validate = "empty_prompt" },
			authorized = { validate = true },
			now = 1010,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({}, repeated)
		assert.are.equal(1000, repeated_state.messages["validate\0mail-1"].woken_at)
	end)

	it("holds busy mail until the same agent becomes idle", function()
		local waiting, first_actions = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = watch.empty_state(),
			terminal_states = { validate = "busy" },
			authorized = { validate = true },
			now = 1000,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({
			{ type = "notify", project = "validate", count = 1 },
		}, first_actions)
		assert.is_nil(waiting.messages["validate\0mail-1"].woken_at)

		local woken, second_actions = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = waiting,
			terminal_states = { validate = "empty_prompt" },
			authorized = { validate = true },
			now = 1010,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({
			{ type = "wake", project = "validate", count = 1 },
		}, second_actions)
		assert.are.equal(1010, woken.messages["validate\0mail-1"].woken_at)
	end)

	it("defers dialogs and unauthorized prompts", function()
		local _, actions = watch.cycle({
			deliveries = {
				delivery("validate", "mail-1"),
				delivery("rarz", "mail-2"),
			},
			state = watch.empty_state(),
			terminal_states = { validate = "dialog", rarz = "empty_prompt" },
			authorized = { validate = true },
			now = 1000,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({
			{ type = "notify", project = "rarz", count = 1 },
			{ type = "notify", project = "validate", count = 1 },
		}, actions)
	end)

	it("applies wake cooldown per project and prunes mail no longer new", function()
		local state = {
			version = 1,
			messages = {
				["validate\0old"] = { noticed_at = 900 },
				["validate\0mail-1"] = { noticed_at = 900 },
			},
			last_wake = { validate = 980 },
		}
		local cooling, actions = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = state,
			terminal_states = { validate = "empty_prompt" },
			authorized = { validate = true },
			now = 1000,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({}, actions)
		assert.is_nil(cooling.messages["validate\0old"])

		local _, after_cooldown = watch.cycle({
			deliveries = { delivery("validate", "mail-1") },
			state = cooling,
			terminal_states = { validate = "empty_prompt" },
			authorized = { validate = true },
			now = 1040,
			cooldown = 60,
			notice_retry = 300,
		})
		assert.same({
			{ type = "wake", project = "validate", count = 1 },
		}, after_cooldown)
	end)
end)
