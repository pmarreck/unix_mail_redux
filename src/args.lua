local M = {}

local verbs = {
	list = true,
	read = true,
	reply = true,
	to = true,
	status = true,
	watch = true,
	smime = true,
}

local function require_value(argv, index, option, description)
	local value = argv[index + 1]
	if value == nil then
		error(option .. " requires " .. description, 0)
	end
	return value
end

function M.parse(argv)
	local result = { format = "human" }
	local positional = {}
	local index = 1
	local options_done = false

	while index <= #argv do
		local value = argv[index]
		if options_done then
			table.insert(positional, value)
		elseif value == "--" then
			options_done = true
		elseif value == "--json" then
			result.format = "json"
		elseif value == "--simple" or value == "--ascii" then
			result.simple = true
		elseif value == "--yes" then
			result.confirm = false
		elseif value == "--once" then
			result.once = true
		elseif value == "--no-wake" then
			result.wake = false
		elseif value == "--interval" then
			local interval = tonumber(require_value(argv, index, value, "a positive number"))
			if not interval or interval <= 0 then
				error("--interval requires a positive number", 0)
			end
			result.interval = interval
			index = index + 1
		elseif value == "--maildir" then
			result.maildir = require_value(argv, index, value, "a path")
			index = index + 1
		elseif value == "--state-file" then
			result.state_file = require_value(argv, index, value, "a path")
			index = index + 1
		elseif value == "--out" then
			result.output = require_value(argv, index, value, "a path")
			index = index + 1
		elseif value == "--passphrase-file" then
			result.passphrase_file = require_value(argv, index, value, "a path or -")
			index = index + 1
		elseif value == "--ca" then
			result.ca = require_value(argv, index, value, "a path")
			index = index + 1
		elseif value == "--email" then
			result.email = require_value(argv, index, value, "an address")
			index = index + 1
		elseif value == "--name" then
			result.name = require_value(argv, index, value, "a label")
			index = index + 1
		elseif value == "--ca-passphrase-file" then
			result.ca_passphrase_file = require_value(argv, index, value, "a path or -")
			index = index + 1
		elseif value == "--identity-passphrase-file" then
			result.identity_passphrase_file = require_value(argv, index, value, "a path or -")
			index = index + 1
		elseif value == "--as" then
			result.identity = require_value(argv, index, value, "a project identity")
			index = index + 1
		elseif value == "--subject" then
			result.subject = require_value(argv, index, value, "a value")
			index = index + 1
		elseif value == "--body" then
			result.body = require_value(argv, index, value, "a value")
			index = index + 1
		elseif value == "-h" or value == "--help" then
			result.verb = "help"
		elseif value == "--about" then
			result.verb = "about"
		elseif value:sub(1, 1) == "-" then
			error("unknown option: " .. value, 0)
		else
			table.insert(positional, value)
		end
		index = index + 1
	end

	if result.verb == "help" or result.verb == "about" then
		return result
	end

	result.verb = positional[1] or "list"
	if not verbs[result.verb] then
		error("unknown command: " .. result.verb, 0)
	end

	if result.verb == "read" or result.verb == "reply" then
		result.id = positional[2]
		if not result.id then
			error(result.verb .. " requires a message ID", 0)
		end
	elseif result.verb == "to" then
		result.recipient = positional[2]
		if not result.recipient then
			error("to requires a project identity", 0)
		end
	elseif result.verb == "smime" then
		result.action = positional[2]
		if result.action ~= "init-ca" and result.action ~= "issue" then
			error("smime requires init-ca or issue", 0)
		end
		local required = result.action == "init-ca"
			and {
				{ "output", "--out" },
				{ "passphrase_file", "--passphrase-file" },
			}
			or {
				{ "ca", "--ca" },
				{ "output", "--out" },
				{ "email", "--email" },
				{ "name", "--name" },
				{ "ca_passphrase_file", "--ca-passphrase-file" },
				{ "identity_passphrase_file", "--identity-passphrase-file" },
			}
		for _, field in ipairs(required) do
			if not result[field[1]] then
				error("smime " .. result.action .. " requires " .. field[2], 0)
			end
		end
	end

	return result
end

return M
