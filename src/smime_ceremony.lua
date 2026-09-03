local policy = require("smime_policy")

local M = {}
local CA_DAYS = 3650
local IDENTITY_DAYS = 365
local CA_COMMON_NAME = "UNIX MAIL REDUX Offline S/MIME Root CA"

function M.init_ca(options, dependencies)
	local passphrase = policy.passphrase(
		dependencies.read_secret(options.passphrase_file))
	local generated = dependencies.crypto.create_ca({
		common_name = CA_COMMON_NAME,
		passphrase = passphrase,
		now = dependencies.now(),
		days = CA_DAYS,
	})
	local paths = policy.ca_paths(options.output)
	dependencies.create_directory(options.output, {
		{
			name = "root-ca-key.pem",
			contents = generated.private_key_pem,
			mode = 384,
		},
		{
			name = "root-ca.pem",
			contents = generated.certificate_pem,
			mode = 420,
		},
		{
			name = "root-ca.cer",
			contents = generated.certificate_der,
			mode = 420,
		},
	})
	return {
		kind = "ca",
		private_key = paths.private_key,
		certificate = paths.certificate,
		apple_certificate = paths.apple_certificate,
	}
end

function M.issue(options, dependencies)
	if options.ca_passphrase_file == "-"
		and options.identity_passphrase_file == "-"
	then
		error("CA and identity passphrases cannot both be read from stdin", 0)
	end
	local ca_paths = policy.ca_paths(options.ca)
	local ca_passphrase = policy.passphrase(
		dependencies.read_secret(options.ca_passphrase_file))
	local identity_passphrase = policy.passphrase(
		dependencies.read_secret(options.identity_passphrase_file))
	local email = policy.require_email(options.email)
	local generated = dependencies.crypto.issue_identity({
		ca_private_key_pem = dependencies.read_file(ca_paths.private_key),
		ca_certificate_pem = dependencies.read_file(ca_paths.certificate),
		ca_passphrase = ca_passphrase,
		identity_passphrase = identity_passphrase,
		email = email,
		name = options.name,
		now = dependencies.now(),
		days = IDENTITY_DAYS,
	})
	local paths = policy.identity_paths(options.output)
	dependencies.create_directory(options.output, {
		{
			name = "identity.p12",
			contents = generated.pkcs12_der,
			mode = 384,
		},
		{
			name = "identity.pem",
			contents = generated.certificate_pem,
			mode = 420,
		},
	})
	return {
		kind = "identity",
		pkcs12 = paths.pkcs12,
		certificate = paths.certificate,
		email = email,
		name = options.name,
	}
end

return M
