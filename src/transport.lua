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
		"message", "read", id, "--mailbox", mailbox,
	})
end

function M.mark_seen(config, mailbox, id)
	return append(base(config), {
		"flag", "add", "--flag", "seen", id, "--mailbox", mailbox,
	})
end

function M.status(config, format)
	return append(base(config, format), { "mailbox", "list" })
end

function M.compose(config, from, to, subject, format)
	return append(base(config, format), {
		"message", "compose",
		"--from", from,
		"--to", to,
		"--subject", subject,
		"--save", "Sent",
		"--send",
	})
end

function M.reply_candidate(config, mailbox, id, from, format)
	return append(base(config, format), {
		"message", "reply", id,
		"--mailbox", mailbox,
		"--from", from,
	})
end

function M.send_candidate(config, format)
	return append(base(config, format), {
		"message", "send", "--save", "Sent",
	})
end

return M
