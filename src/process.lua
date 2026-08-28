local uv = require("luv")

local M = {}

local function command_args(argv)
	local result = {}
	for index = 2, #argv do
		result[index - 1] = argv[index]
	end
	return result
end

function M.run(argv, options)
	options = options or {}
	local stdout_chunks = {}
	local stderr_chunks = {}
	local stdin_pipe
	local stdout_pipe
	local stderr_pipe
	local stdio
	local stdin_done = options.stdin == nil
	local stdout_done = not options.capture
	local stderr_done = not options.capture

	if options.stdin ~= nil then
		stdin_pipe = uv.new_pipe(false)
	end
	if options.capture then
		stdout_pipe = uv.new_pipe(false)
		stderr_pipe = uv.new_pipe(false)
	end
	stdio = {
		stdin_pipe or 0,
		stdout_pipe or 1,
		stderr_pipe or 2,
	}

	local exit_code
	local exit_signal
	local handle, spawn_error = uv.spawn(argv[1], {
		args = command_args(argv),
		cwd = options.cwd,
		stdio = stdio,
	}, function(code, signal)
		exit_code = code
		exit_signal = signal
	end)

	if not handle then
		if stdin_pipe then stdin_pipe:close() end
		if stdout_pipe then stdout_pipe:close() end
		if stderr_pipe then stderr_pipe:close() end
		return {
			rc = 127,
			stdout = "",
			stderr = tostring(spawn_error),
		}
	end

	if stdin_pipe then
		local function close_stdin()
			stdin_pipe:close()
			stdin_done = true
		end
		local function shutdown_stdin(error_message)
			if error_message then
				table.insert(stderr_chunks, error_message)
			end
			uv.shutdown(stdin_pipe, function(shutdown_error)
				if shutdown_error then
					table.insert(stderr_chunks, shutdown_error)
				end
				close_stdin()
			end)
		end
		if options.stdin == "" then
			shutdown_stdin()
		else
			uv.write(stdin_pipe, options.stdin, shutdown_stdin)
		end
	end

	if options.capture then
		uv.read_start(stdout_pipe, function(error_message, chunk)
			if error_message then
			table.insert(stderr_chunks, error_message)
			end
			if chunk then
				table.insert(stdout_chunks, chunk)
			else
				stdout_pipe:close()
				stdout_done = true
			end
		end)
		uv.read_start(stderr_pipe, function(error_message, chunk)
			if error_message then
				table.insert(stderr_chunks, error_message)
			end
			if chunk then
				table.insert(stderr_chunks, chunk)
			else
				stderr_pipe:close()
				stderr_done = true
			end
		end)
	end

	while exit_code == nil or not stdin_done or not stdout_done or not stderr_done do
		uv.run("once")
	end
	handle:close()

	return {
		rc = exit_code,
		signal = exit_signal,
		stdout = table.concat(stdout_chunks),
		stderr = table.concat(stderr_chunks),
	}
end

return M
