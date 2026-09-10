local uv = require("luv")
local json = require("cjson.safe")
local M = {}

-- Scheduling is independent of processes and clocks. Completed jobs remain
-- until their caller persists/consumes the result and removes the request.
function M.new(start)
	local jobs = {}
	return { step = function(_, tasks)
		local active, keys, results = 0, {}, {}
		for key, job in pairs(jobs) do
			if job.status == "running" then active = active + 1
			elseif not tasks[key] then jobs[key] = nil end
		end
		for key in pairs(tasks) do keys[#keys+1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			if not jobs[key] and active < 2 then
				jobs[key] = {status="running"}; active = active + 1
				local ok, err = pcall(start, tasks[key], function(result) jobs[key] = result end)
				if not ok then jobs[key] = {status="error", reason=tostring(err)}; active = active - 1 end
			end
			results[key] = jobs[key] or {status="deferred", reason="worker-capacity"}
		end
		return results
	end }
end

function M.argv(config, task)
	return {"timeout", "--kill-after=5s", "120s", config.wake_command,
		task.pane, "--wake", task.note, "--service-socket", config.socket,
		"--expect-session", task.session, "--timeout", "20"}
end

function M.start(config, task, done)
	local argv = M.argv(config, task)
	local args = {}; for i=2,#argv do args[#args+1]=argv[i] end
	local output, size, exited, eof = {}, 0, false, false
	local pipe = uv.new_pipe(false)
	local handle
	local function finish()
		if not exited or not eof then return end
		local value = json.decode(table.concat(output))
		local known = { ["activity-observed"]=true, deferred=true, unconfirmed=true,
			["already-attempted"]=true, ["note-gone"]=true, error=true }
		if type(value)~="table" or not known[value.status] then
			value = {status="unconfirmed", reason="worker exited without a valid result; inspect attempt journal"}
		end
		done(value)
	end
	handle = uv.spawn(argv[1], {args=args, stdio={nil,pipe,nil}}, function()
		exited=true; handle:close(); finish()
	end)
	if not handle then pipe:close(); error("could not start guarded wake worker") end
	uv.read_start(pipe, function(err, chunk)
		if chunk then
			size=size+#chunk; if size<=8192 then output[#output+1]=chunk end
		else eof=true; pipe:close(); finish() end
	end)
end

local pool
function M.step(config, tasks)
	if not pool then pool=M.new(function(task, done) M.start(config, task, done) end) end
	uv.run("nowait")
	local pending, results = {}, {}
	for key, task in pairs(tasks) do
		local stat = uv.fs_lstat(task.note)
		if not stat or stat.type~="file" then
			results[key] = {status="note-gone", reason="notice removed; not proof of mail read"}
		else pending[key] = task end
	end
	for key, result in pairs(pool:step(pending)) do results[key]=result end
	return results
end
return M
