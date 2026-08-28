local identity = require("identity")
local maildir = require("maildir")
local process = require("process")
local tmux_wake = require("tmux_wake")
local watch = require("watch")
local watch_state = require("watch_state")

local M = {}

local function sorted_keys(values)
	local keys = {}
	for key in pairs(values) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function default_report(action, target)
	if action.type == "notify" then
		io.stderr:write(string.format(
			"post: %d unread mail %s for %s%s\n",
			action.count,
			action.count == 1 and "message" or "messages",
			action.project,
			target.session and "" or " (no unambiguous agent pane)"
		))
	end
end

local function default_dependencies()
	return {
		scan = maildir.scan,
		load = watch_state.load,
		save = watch_state.save,
		probe = function(tmux, project)
			return tmux_wake.probe(process.run, tmux, project)
		end,
		run = process.run,
		now = os.time,
		report = default_report,
	}
end

function M.parse_authorized(value)
	local authorized = {}
	for token in (value .. ","):gmatch("(.-),") do
		token = token:match("^%s*(.-)%s*$")
		if token ~= "" then
			if token == "*" then
				authorized[token] = true
			else
				authorized[identity.normalize(token)] = true
			end
		end
	end
	return authorized
end

function M.run_once(config, dependencies)
	local deps = dependencies or default_dependencies()
	local deliveries = deps.scan(config.maildir)
	local state = deps.load(config.state_file)
	local projects = {}
	for _, delivery in ipairs(deliveries) do
		projects[delivery.project] = true
	end

	local probes = {}
	local terminal_states = {}
	for _, project in ipairs(sorted_keys(projects)) do
		local probe = deps.probe(config.tmux, project)
		probes[project] = probe
		terminal_states[project] = probe.state
	end

	local next_state, actions = watch.cycle({
		deliveries = deliveries,
		state = state,
		terminal_states = terminal_states,
		authorized = config.authorized,
		now = deps.now(),
		cooldown = config.cooldown,
		notice_retry = config.notice_retry,
	})

	for _, action in ipairs(actions) do
		local target = probes[action.project] or { state = "absent" }
		deps.report(action, target)
		local argv
		if action.type == "notify" and target.session then
			argv = tmux_wake.notify_argv(config.tmux, target, action.project, action.count)
		elseif action.type == "wake" then
			argv = tmux_wake.wake_argv(
				config.wake_client,
				config.tmux,
				target,
				action.project,
				action.count
			)
		end
		if argv then
			local result = deps.run(argv, { capture = true })
			if result.rc ~= 0 then
				local detail = (result.stderr or ""):gsub("%s+$", "")
				error(string.format(
					"%s failed for %s: %s",
					action.type == "wake" and "terminal wake" or "tmux notify",
					action.project,
					detail ~= "" and detail or "exit " .. tostring(result.rc)
				), 0)
			end
		end
	end

	deps.save(config.state_file, next_state)
	return actions
end

return M
