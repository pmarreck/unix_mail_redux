local cjson = require("cjson")
local policy = require("smime_policy")
local uv = require("luv")

local M = {}

local function parent_directory(path)
	return path:match("^(.*)[/\\][^/\\]+$")
end

local function make_directories(path)
	if not path or path == "" or uv.fs_stat(path) then
		return
	end
	make_directories(parent_directory(path))
	local created, create_error, create_code = uv.fs_mkdir(path, 448)
	if not created and create_code ~= "EEXIST" then
		error("could not create S/MIME replay directory: "
			.. tostring(create_error), 0)
	end
	if created then
		local protected, chmod_error = uv.fs_chmod(path, 448)
		if not protected then
			error("could not protect S/MIME replay directory: "
				.. tostring(chmod_error), 0)
		end
	end
end

local function digest_from_key(key)
	if type(key) ~= "string" or #key ~= 71 then
		error("invalid S/MIME replay key", 0)
	end
	local digest = key:match("^sha256:([0-9a-f]+)$")
	if not digest or #digest ~= 64 then
		error("invalid S/MIME replay key", 0)
	end
	return digest
end

function M.claim(directory, claim)
	local digest = digest_from_key(claim.key)
	local email = policy.require_email(claim.email)
	if type(claim.verified_at) ~= "number"
		or claim.verified_at ~= math.floor(claim.verified_at)
	then
		error("invalid S/MIME replay verification time", 0)
	end
	make_directories(directory)
	local path = directory .. "/sha256-" .. digest .. ".json"
	local descriptor, open_error, open_code = uv.fs_open(path, "wx", 384)
	if not descriptor then
		if open_code == "EEXIST" then
			error("replayed S/MIME signature: " .. claim.key, 0)
		end
		error("could not claim S/MIME signature: " .. tostring(open_error), 0)
	end

	local document = cjson.encode({
		version = 1,
		replay_key = claim.key,
		signer_email = email,
		verified_at = claim.verified_at,
	}) .. "\n"
	local written, write_error = uv.fs_write(descriptor, document, 0)
	if not written or written ~= #document then
		uv.fs_close(descriptor)
		error("could not record S/MIME signature claim: "
			.. tostring(write_error or "partial write"), 0)
	end
	local synced, sync_error = uv.fs_fsync(descriptor)
	local closed, close_error = uv.fs_close(descriptor)
	if not synced or not closed then
		error("could not sync S/MIME signature claim: "
			.. tostring(sync_error or close_error), 0)
	end
	local protected, chmod_error = uv.fs_chmod(path, 384)
	if not protected then
		error("could not protect S/MIME signature claim: "
			.. tostring(chmod_error), 0)
	end
	return true
end

return M
