local M = {}

local DAY_SECONDS = 24 * 60 * 60
local CLOCK_SKEW_SECONDS = 5 * 60
local MINIMUM_PASSPHRASE_BYTES = 16

local function valid_email(address)
	if type(address) ~= "string" or #address == 0 or #address > 254 then
		return false
	end
	if address:find("[^a-z0-9@._+%-]") then
		return false
	end
	local local_part, domain = address:match("^([^@]+)@([^@]+)$")
	if not local_part or #local_part > 64
		or local_part:sub(1, 1) == "."
		or local_part:sub(-1) == "."
		or local_part:find("..", 1, true)
	then
		return false
	end
	for label in (domain .. "."):gmatch("(.-)%.") do
		if #label == 0 or #label > 63
			or not label:match("^[a-z0-9][a-z0-9-]*[a-z0-9]$")
		then
			return false
		end
	end
	return true
end

function M.classify_addresses(addresses)
	local valid = {}
	local invalid = {}
	for _, address in ipairs(addresses) do
		table.insert(valid_email(address) and valid or invalid, address)
	end
	table.sort(valid)
	table.sort(invalid)
	return { valid = valid, invalid = invalid }
end

function M.require_email(address)
	if not valid_email(address) then
		error("invalid S/MIME email address: " .. tostring(address), 0)
	end
	return address
end

function M.validity_window(now, days)
	if type(now) ~= "number" or type(days) ~= "number"
		or days ~= math.floor(days) or days <= 0
	then
		error("certificate validity requires a positive whole number of days", 0)
	end
	return {
		not_before = now - CLOCK_SKEW_SECONDS,
		not_after = now + days * DAY_SECONDS,
	}
end

local function join(directory, name)
	local trimmed = directory:gsub("[/\\]+$", "")
	return trimmed .. "/" .. name
end

function M.ca_paths(directory)
	return {
		private_key = join(directory, "root-ca-key.pem"),
		certificate = join(directory, "root-ca.pem"),
	}
end

function M.identity_paths(directory)
	return {
		pkcs12 = join(directory, "identity.p12"),
		certificate = join(directory, "identity.pem"),
	}
end

function M.passphrase(contents)
	if type(contents) ~= "string" then
		error("passphrase must be text", 0)
	end
	if contents:find("\0", 1, true) then
		error("passphrase must not contain NUL", 0)
	end
	local value = contents:gsub("\r?\n$", "")
	if value:find("[\r\n]") then
		error("passphrase file must contain exactly one line", 0)
	end
	if #value < MINIMUM_PASSPHRASE_BYTES then
		error("passphrase must contain at least 16 bytes", 0)
	end
	return value
end

return M
