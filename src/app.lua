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
		identity.mailbox(normalized)
		return normalized
	end
	if context.git_root then
		local normalized = identity.normalize(basename(context.git_root))
		identity.mailbox(normalized)
		return normalized
	end
	return "peter"
end

function M.plan(parsed, context)
	if parsed.verb == "status" then
		return {
			argv = transport.status(context.config, parsed.format),
		}
	end

	local resolved = resolve_identity(parsed, context)
	local mailbox = resolved == "peter" and "INBOX" or identity.mailbox(resolved)
	local argv
	if parsed.verb == "list" then
		argv = transport.list(context.config, mailbox, parsed.format)
	elseif parsed.verb == "read" then
		argv = transport.read(context.config, mailbox, parsed.id, parsed.format)
	else
		error(parsed.verb .. " is not implemented yet", 0)
	end

	return {
		identity = resolved,
		mailbox = mailbox,
		argv = argv,
	}
end

return M
