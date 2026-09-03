local M = {}

local state_actions = {
	absent = "defer",
	attached = "notify",
	busy = "notify",
	dialog = "defer",
	crashed = "notify",
	empty_prompt = "wake",
	idle_passive = "notify",
}

local agent_commands = {
	claude = true,
	codex = true,
	grok = true,
}

local function trim(value)
	return (value:gsub("^[%s\194\160]+", ""):gsub("[%s\194\160]+$", ""))
end

function M.classify_pane(input)
	if not agent_commands[input.command] then
		return "absent"
	end

	local screen = string.lower(input.screen or "")
	if screen:find("do you trust", 1, true) then
		return "dialog"
	end
	if screen:find("server exited unexpectedly", 1, true)
		or screen:find("process exited", 1, true)
	then
		return "crashed"
	end

	local cursor_line = trim(input.cursor_line or "")
	if input.command == "claude" then
		local draft = cursor_line:match("^❯(.*)$")
		return draft and trim(draft) == "" and "empty_prompt" or "busy"
	end
	if input.command == "codex" then
		if cursor_line ~= "› Ask Codex to do anything" then
			return "busy"
		end
		-- Codex 0.153.0 accepted text through a temporary tmux client but
		-- interrupted the conversation when that client detached. Keep the
		-- reusable default passive; a deployment must explicitly accept that
		-- measured risk before using the terminal wake path.
		return input.allow_codex_terminal_wake and "empty_prompt" or "idle_passive"
	end

	local draft = cursor_line:match("^│%s*❯(.-)%s*│$")
	return draft and trim(draft) == "" and "empty_prompt" or "busy"
end

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
