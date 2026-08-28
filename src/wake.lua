local M = {}

local state_actions = {
	absent = "defer",
	busy = "notify",
	dialog = "defer",
	crashed = "notify",
	empty_prompt = "wake",
}

function M.decide(input)
	if input.seen[input.message_key] then
		return { action = "ignore", reason = "duplicate" }
	end

	local action = state_actions[input.terminal_state]
	if not action then
		return { action = "defer", reason = "unknown-terminal-state" }
	end

	if action == "wake" and not input.authorized then
		return { action = "notify", reason = "wake-not-authorized" }
	end

	if action == "wake" and input.now - input.last_wake < input.cooldown then
		return { action = "defer", reason = "cooldown" }
	end

	return { action = action, reason = input.terminal_state }
end

return M

