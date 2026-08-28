local wake = require("wake")

local M = {}

local function message_key(delivery)
	return delivery.project .. "\0" .. delivery.key
end

local function sorted_keys(values)
	local keys = {}
	for key in pairs(values) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function M.empty_state()
	return {
		version = 1,
		messages = {},
		last_wake = {},
	}
end

function M.cycle(input)
	local previous = input.state or M.empty_state()
	local next_state = M.empty_state()
	local groups = {}

	for project, timestamp in pairs(previous.last_wake or {}) do
		next_state.last_wake[project] = timestamp
	end

	for _, delivery in ipairs(input.deliveries) do
		local key = message_key(delivery)
		local old = (previous.messages or {})[key] or {}
		next_state.messages[key] = {
			noticed_at = old.noticed_at,
			woken_at = old.woken_at,
		}
		groups[delivery.project] = groups[delivery.project] or {}
		table.insert(groups[delivery.project], key)
	end

	local actions = {}
	for _, project in ipairs(sorted_keys(groups)) do
		local pending = {}
		local notice_due = false
		for _, key in ipairs(groups[project]) do
			local status = next_state.messages[key]
			if not status.woken_at then
				table.insert(pending, key)
				if not status.noticed_at
					or input.now - status.noticed_at >= input.notice_retry
				then
					notice_due = true
				end
			end
		end

		if #pending > 0 then
			if notice_due then
				table.insert(actions, {
					type = "notify",
					project = project,
					count = #pending,
				})
				for _, key in ipairs(pending) do
					next_state.messages[key].noticed_at = input.now
				end
			end

			local decision = wake.decide({
				message_key = pending[1],
				terminal_state = input.terminal_states[project] or "absent",
				authorized = input.authorized[project] or input.authorized["*"] or false,
				now = input.now,
				last_wake = next_state.last_wake[project] or -math.huge,
				cooldown = input.cooldown,
				seen = {},
			})
			if decision.action == "wake" then
				table.insert(actions, {
					type = "wake",
					project = project,
					count = #pending,
				})
				for _, key in ipairs(pending) do
					next_state.messages[key].woken_at = input.now
				end
				next_state.last_wake[project] = input.now
			end
		end
	end

	return next_state, actions
end

return M
