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
	local stdout_pipe
	local stderr_pipe
	local stdio

	if options.capture then
		stdout_pipe = uv.new_pipe(false)
		stderr_pipe = uv.new_pipe(false)
		stdio = { nil, stdout_pipe, stderr_pipe }
	else
		stdio = { 0, 1, 2 }
	end

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
		if stdout_pipe then stdout_pipe:close() end
		if stderr_pipe then stderr_pipe:close() end
		return {
			rc = 127,
			stdout = "",
			stderr = tostring(spawn_error),
		}
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
			end
		end)
	end

	while exit_code == nil do
		uv.run("once")
	end
	handle:close()
	uv.run("nowait")

	return {
		rc = exit_code,
		signal = exit_signal,
		stdout = table.concat(stdout_chunks),
		stderr = table.concat(stderr_chunks),
	}
end

return M
