local uv = require("luv")

local M = {}

local function project_from_directory(name)
	local project = name:match("^%.Agents%.([a-z0-9][a-z0-9_-]*)$")
	if not project or #project > 63 then
		return nil
	end
	return project
end

local function entries(path)
	local result = {}
	local scanner = uv.fs_scandir(path)
	if not scanner then
		return result
	end
	while true do
		local name, kind = uv.fs_scandir_next(scanner)
		if not name then break end
		table.insert(result, { name = name, kind = kind })
	end
	return result
end

function M.scan(root)
	local deliveries = {}
	for _, mailbox in ipairs(entries(root)) do
		local project = mailbox.kind == "directory"
			and project_from_directory(mailbox.name)
			or nil
		if project then
			local seen = {}
			-- IMAP clients can move new -> cur without marking a message Seen.
			-- Scan both locations and deduplicate a rename observed between scans.
			for _, directory in ipairs({ "new", "cur" }) do
			for _, message in ipairs(entries(root .. "/" .. mailbox.name .. "/" .. directory)) do
				local flags = message.name:match(":2,(.*)$") or ""
				if message.kind == "file" and not flags:find("S", 1, true)
					and not flags:find("T", 1, true) then
					local key = message.name:gsub(":2,.*$", "")
					if key ~= "" and not seen[key] then
						seen[key] = true
						table.insert(deliveries, { project = project, key = key })
					end
				end
			end
			end
		end
	end
	table.sort(deliveries, function(left, right)
		if left.project == right.project then
			return left.key < right.key
		end
		return left.project < right.project
	end)
	return deliveries
end

return M
