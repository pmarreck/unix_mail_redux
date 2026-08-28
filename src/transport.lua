local M = {}

local function base(config, format)
	local argv = { config.executable }
	if config.config then
		table.insert(argv, "--config")
		table.insert(argv, config.config)
	end
	if config.account then
		table.insert(argv, "--account")
		table.insert(argv, config.account)
	end
	if format == "json" then
		table.insert(argv, "--json")
	end
	return argv
end

local function append(argv, values)
	for _, value in ipairs(values) do
		table.insert(argv, value)
	end
	return argv
end

function M.list(config, mailbox, format)
	return append(base(config, format), {
		"envelope", "list", "--mailbox", mailbox,
	})
end

function M.read(config, mailbox, id, format)
	return append(base(config, format), {
		"message", "read", id, "--mailbox", mailbox, "--seen",
	})
end

function M.status(config, format)
	return append(base(config, format), { "mailbox", "list" })
end

return M
