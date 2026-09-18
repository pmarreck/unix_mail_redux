local json = require("cjson")
local uv = require("luv")
local bridge = require("herdr_mail")
local M = {}
M.parse_authorized = require("watch_runtime").parse_authorized

-- A distinct notice per new delivery batch. Never write mail bodies to a project.
function M.write_notice(cwd, project, text, datetime)
	require("identity").mailbox(project)
	assert(datetime:match("^%d%d%d%d%-%d%d%-%d%dT"), "invalid notice datetime")
	local root = assert(uv.fs_realpath(cwd), "recipient directory is unavailable")
	local inbox = root .. "/inbox"
	local stat = uv.fs_lstat(inbox)
	if not stat then assert(uv.fs_mkdir(inbox, 448))
	elseif stat.type == "link" then
		-- Operator-owned aliases consolidate inboxes (HOME/inbox -> Code/inbox).
		assert(stat.uid == uv.getuid(), "recipient inbox link must be owned by the operator")
	end
	inbox = assert(uv.fs_realpath(inbox), "recipient inbox target is unavailable")
	stat = assert(uv.fs_stat(inbox))
	assert(stat.type == "directory", "recipient inbox target must be a directory")
	assert(stat.uid == uv.getuid(), "recipient inbox target must be owned by the operator")
	assert(require("bit").band(stat.mode, 18) == 0,
		"recipient inbox target must not be group/other writable")
	local fd, temporary = assert(uv.fs_mkstemp(inbox .. "/.post-mail-XXXXXX"))
	local name = datetime:sub(1, 10) .. "-from-post-watch-mail-" .. project .. "-" ..
		temporary:match("([^/]+)$"):sub(#".post-mail-" + 1) .. ".frontmatter.md"
	local destination = inbox .. "/" .. name
	local ok, err = pcall(function()
		assert(uv.fs_fchmod(fd, 384))
		assert(uv.fs_write(fd, text, 0) == #text, "short mail notice write")
		assert(uv.fs_fsync(fd))
	end)
	uv.fs_close(fd)
	if not ok then uv.fs_unlink(temporary); error(err, 0) end
	-- Link publishes only complete bytes and refuses a collision atomically.
	-- Never overwrite a notice another agent might currently be processing.
	local renamed, rename_error = uv.fs_link(temporary, destination)
	uv.fs_unlink(temporary)
	if not renamed then error(rename_error, 0) end
	return destination
end

local function defaults(config)
	local process = require("process")
	local state = require("watch_state")
	return {
		scan = require("maildir").scan, load = state.load, save = state.save,
		now = os.time,
		datetime = function(now)
			local value = os.date("%Y-%m-%dT%H:%M:%S%z", now)
			return value:gsub("([+-]%d%d)(%d%d)$", "%1:%2")
		end,
		write = M.write_notice,
		wakes = function(tasks) return require("wake_workers").step(config, tasks) end,
		agents = function()
			local result = process.run({ config.herdr, "agent", "list" }, { capture = true })
			if result.rc ~= 0 then return {} end
			local ok, value = pcall(json.decode, result.stdout)
			if not ok or type(value) ~= "table" or type(value.result) ~= "table"
				or type(value.result.agents) ~= "table" then return {} end
			return value.result.agents
		end,
		notify = function(project, count)
			local result = process.run(bridge.notify_argv(config.herdr, project, count), { capture = true })
			return result.rc == 0
		end,
		report = function(message) io.stderr:write("post: ", message, "\n") end,
	}
end

function M.run_once(config, dependencies)
	local deps = dependencies or defaults(config)
	local deliveries = deps.scan(config.maildir)
	local old = deps.load(config.state_file)
	local state = { version = 1, messages = {}, last_wake = old.last_wake or {}, wakes = {} }
	local wake_tasks = {}
	local groups, projects = {}, {}
	for _, delivery in ipairs(deliveries) do
		local project, key = delivery.project, delivery.project .. "\0" .. delivery.key
		if not groups[project] then groups[project] = {}; projects[#projects + 1] = project end
		groups[project][#groups[project] + 1] = key
		state.messages[key] = old.messages[key] or {}
	end
	table.sort(projects)
	local agents = #projects > 0 and deps.agents() or {}
	local now = deps.now()
	for _, project in ipairs(projects) do
		local target = bridge.resolve(agents, project, config.routes or {})
		local pending, notice_due = false, false
		for _, key in ipairs(groups[project]) do
			local record = state.messages[key]
			pending = pending or not record.bridged_at or not record.note_path or target and record.bridge_cwd ~= target.cwd
			notice_due = notice_due or not record.herdr_noticed_at or now - record.herdr_noticed_at >= config.notice_retry
		end
		local allowed = config.authorized[project] or config.authorized["*"]
		if target and pending and allowed then
			local datetime = deps.datetime(now)
			local ok, path = pcall(deps.write, target.cwd, project,
				bridge.render(project, #groups[project], datetime, config), datetime)
			if ok then
				for _, key in ipairs(groups[project]) do
					state.messages[key].bridged_at = now
					state.messages[key].bridge_cwd = target.cwd
					state.messages[key].note_path = path
				end
				deps.report("mail notice delivered for " .. project .. ": " .. path)
			else deps.report("mail notice deferred for " .. project .. ": " .. tostring(path)) end
		end
		if target and target.agent and notice_due then
			if deps.notify(project, #groups[project]) then
				for _, key in ipairs(groups[project]) do state.messages[key].herdr_noticed_at = now end
				deps.report("Herdr notified: " .. project .. " (" .. #groups[project] .. " unread)")
			end
		end
		local wake_allowed = config.terminal_authorized or {}
		local agent = target and target.agent
		if allowed and (wake_allowed[project] or wake_allowed["*"]) and agent and agent.pane_id
			and agent.agent_session and agent.agent_session.value then
			for _, message_key in ipairs(groups[project]) do
				local note = state.messages[message_key].note_path
				if note then
					local key = note .. "\0" .. agent.agent_session.value
					local record = (old.wakes or {})[key] or {}
					state.wakes[key] = record
					local retryable = not record.status or record.status=="deferred" or record.status=="error"
					local idle = agent.agent_status=="idle" or agent.agent_status=="done"
					if record.status=="running" or retryable and idle and
						(not record.checked_at or now-record.checked_at >= (config.cooldown or 60)) then
						wake_tasks[key] = {key=key, pane=agent.pane_id, session=agent.agent_session.value, note=note, project=project}
					end
				end
			end
		end
	end
	-- Persist the bridge before a worker can type. Restarting must reuse this
	-- exact note, whose content/native-session dedup lives in the wake helper.
	deps.save(config.state_file, state)
	if deps.wakes then
		for key, result in pairs(deps.wakes(wake_tasks)) do
			local prior = state.wakes[key] or {}
			if prior.status ~= result.status or prior.reason ~= result.reason then
				deps.report("Herdr mail wake " .. wake_tasks[key].project .. ": " .. result.status .. " (" .. (result.reason or "") .. ")")
			end
			state.wakes[key] = {status=result.status, reason=result.reason, checked_at=now}
		end
		deps.save(config.state_file, state)
	end
	return state
end
return M
