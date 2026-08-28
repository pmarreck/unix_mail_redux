local M = {}

function M.render(message)
	local lines = {
		"From: " .. message.from,
		"To: " .. message.to,
	}
	if message.cc and message.cc ~= "" then
		table.insert(lines, "Cc: " .. message.cc)
	end
	table.insert(lines, "Subject: " .. message.subject)
	table.insert(lines, "")
	table.insert(lines, message.body)
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

function M.from_mime(candidate, body)
	local normalized = candidate:gsub("\r\n", "\n"):gsub("\r", "\n")
	local header_block = normalized:match("^(.-)\n\n")
	if not header_block then
		error("reply candidate has no header block", 0)
	end

	local headers = {}
	local current
	for line in (header_block .. "\n"):gmatch("(.-)\n") do
		if line:match("^[ \t]") and current then
			headers[current] = headers[current] .. " " .. trim(line)
		else
			local name, value = line:match("^([^:]+):%s*(.*)$")
			if name then
				current = name:lower()
				if headers[current] then
					headers[current] = headers[current] .. ", " .. trim(value)
				else
					headers[current] = trim(value)
				end
			else
				current = nil
			end
		end
	end

	for _, name in ipairs({ "from", "to", "subject" }) do
		if not headers[name] or headers[name] == "" then
			error("reply candidate is missing the " .. name:gsub("^%l", string.upper) .. " header", 0)
		end
	end

	return {
		from = headers.from,
		to = headers.to,
		cc = headers.cc,
		subject = headers.subject,
		body = body,
	}
end

function M.confirmed(answer)
	if type(answer) ~= "string" then
		return false
	end
	local normalized = answer:match("^%s*(.-)%s*$"):lower()
	return normalized == "y" or normalized == "yes"
end

return M
