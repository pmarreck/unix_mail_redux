local M = {}

function M.render(message)
	return table.concat({
		"From: " .. message.from,
		"To: " .. message.to,
		"Subject: " .. message.subject,
		"",
		message.body,
		"",
	}, "\n")
end

function M.confirmed(answer)
	if type(answer) ~= "string" then
		return false
	end
	local normalized = answer:match("^%s*(.-)%s*$"):lower()
	return normalized == "y" or normalized == "yes"
end

return M
