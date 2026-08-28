local identity = require("identity")
local transport = require("transport")

local M = {}

local function basename(path)
	local without_trailing = path:gsub("[/\\]+$", "")
	return without_trailing:match("([^/\\]+)$")
end

local function resolve_identity(parsed, context)
	if parsed.identity then
		local normalized = identity.normalize(parsed.identity)
		if normalized ~= identity.normalize(context.human_local_part or "peter") then
			identity.mailbox(normalized)
		end
		return normalized
	end
	if context.git_root then
		local normalized = identity.normalize(basename(context.git_root))
		identity.mailbox(normalized)
		return normalized
	end
	return "peter"
end

local function address(name, context)
	if name == context.human_local_part then
		return name .. "@" .. context.domain
	end
	return identity.address(name, context.domain)
end

function M.plan(parsed, context)
	if parsed.verb == "status" then
		return {
			argv = transport.status(context.config, parsed.format),
		}
	end

	local resolved = resolve_identity(parsed, context)
	local human = identity.normalize(context.human_local_part or "peter")
	local mailbox = resolved == human and "INBOX" or identity.mailbox(resolved)
	local argv
	if parsed.verb == "list" then
		argv = transport.list(context.config, mailbox, parsed.format)
	elseif parsed.verb == "read" then
		argv = transport.read(context.config, mailbox, parsed.id, parsed.format)
	elseif parsed.verb == "reply" then
		if not parsed.body or parsed.body == "" then
			error("message body is required", 0)
		end
		local from = address(resolved, context)
		return {
			identity = resolved,
			mailbox = mailbox,
			from = from,
			body = parsed.body,
			stdin = parsed.body,
			argv = transport.reply_candidate(
				context.config,
				mailbox,
				parsed.id,
				from,
				parsed.format
			),
			send_argv = transport.send_candidate(context.config, parsed.format),
		}
	elseif parsed.verb == "to" then
		if not parsed.subject or parsed.subject == "" then
			error("message subject is required", 0)
		end
		if parsed.subject:find("[\r\n]") then
			error("message subject must be one line", 0)
		end
		if not parsed.body or parsed.body == "" then
			error("message body is required", 0)
		end
		local recipient = identity.normalize(parsed.recipient)
		local from = address(resolved, context)
		local to = address(recipient, context)
		return {
			identity = resolved,
			from = from,
			to = to,
			subject = parsed.subject,
			body = parsed.body,
			stdin = parsed.body,
			argv = transport.compose(context.config, from, to, parsed.subject, parsed.format),
		}
	else
		error(parsed.verb .. " is not implemented yet", 0)
	end

	return {
		identity = resolved,
		mailbox = mailbox,
		argv = argv,
		after_argv = parsed.verb == "read"
			and transport.mark_seen(context.config, mailbox, parsed.id)
			or nil,
	}
end

return M
