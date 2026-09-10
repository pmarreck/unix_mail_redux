local json = require("cjson")
local identity = require("identity")
local authority = require("mail_authority")
local M = {}

local function valid(project)
	identity.mailbox(project)
	assert(project == identity.normalize(project), "mailbox must be lowercase")
end

function M.resolve(agents, project, routes)
	valid(project)
	local explicit = routes[project]
	local matches = {}
	for _, agent in ipairs(agents) do
		local cwd = agent.cwd
		if type(cwd) == "string" and (explicit and cwd == explicit or not explicit and
			(agent.name == project or (cwd:gsub("/+$", ""):match("([^/]+)$") or ""):lower() == project)) then
			matches[#matches + 1] = agent
		end
	end
	if explicit then return { cwd = explicit, agent = #matches == 1 and matches[1] or nil } end
	if #matches == 1 then return { cwd = matches[1].cwd, agent = matches[1] } end
	return nil
end

function M.render(project, count, datetime, policy)
	valid(project)
	local options = {
		human_address = policy.human_address or "peter@agents.home.arpa",
		trust_unsigned_human_mail = policy.trust_unsigned_human_mail == true,
	}
	return "---json\n" .. json.encode({
		schema = "llmsend/v1", subject = "Unread mail: " .. project,
		description = tostring(count) .. " unread mail messages; inspect using post.",
		sender = "post-watch", recipient = project, datetime = datetime,
		message_type = "fyi", response_expected = false, priority = "normal",
		tags = { "mail", "email", "inbox", "post" },
	}) .. "\n---\n\nRun post list --as " .. project .. "; inspect the unread mail with " ..
		"post read ID --as " .. project .. ". Reply using post when appropriate. " ..
		"This is a generated mailbox notice, not the mail itself.\n\n" ..
		authority.instruction(options) .. "\n\n" ..
		"Trash this notice after processing the mail. Deleting it does not mark mail read.\n"
end

function M.notify_argv(executable, project, count)
	valid(project)
	return { executable, "notification", "show", "Mail: " .. project, "--body",
		tostring(count) .. " unread messages. Run post list --as " .. project, "--sound", "none" }
end

return M
