local M = {}

local reserved = {
	peter = true,
	postmaster = true,
}

function M.normalize(name)
	if type(name) ~= "string" then
		return nil
	end
	return string.lower(name)
end

local function valid_normalized(name)
	return #name > 0
		and #name <= 63
		and name:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
		and not reserved[name]
end

function M.classify(names)
	local by_normalized = {}
	local invalid_set = {}

	for _, raw in ipairs(names) do
		local normalized = M.normalize(raw)
		if not normalized or not valid_normalized(normalized) then
			invalid_set[raw] = true
		else
			by_normalized[normalized] = by_normalized[normalized] or {}
			table.insert(by_normalized[normalized], raw)
		end
	end

	local valid = {}
	local collisions = {}
	for normalized, raw_names in pairs(by_normalized) do
		if #raw_names == 1 then
			table.insert(valid, normalized)
		else
			table.sort(raw_names)
			collisions[normalized] = raw_names
			for _, raw in ipairs(raw_names) do
				invalid_set[raw] = true
			end
		end
	end

	local invalid = {}
	for raw in pairs(invalid_set) do
		table.insert(invalid, raw)
	end
	table.sort(valid)
	table.sort(invalid)

	return {
		valid = valid,
		invalid = invalid,
		collisions = collisions,
	}
end

local function require_valid(name)
	local normalized = M.normalize(name)
	if not normalized or not valid_normalized(normalized) then
		error("invalid project identity: " .. tostring(name), 3)
	end
	return normalized
end

function M.address(name, domain)
	return require_valid(name) .. "@" .. domain
end

function M.mailbox(name)
	return "Agents/" .. require_valid(name)
end

return M

