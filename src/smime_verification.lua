local M = {}

function M.verify(options, dependencies)
	local verified_at = dependencies.now()
	local verified = dependencies.crypto.verify_smime({
		message = dependencies.read_input(options.input or "-"),
		ca_certificate_pem = dependencies.read_file(options.ca_certificate),
		email = options.email,
		at = verified_at,
	})
	dependencies.claim(options.replay_directory, {
		key = verified.replay_key,
		email = verified.signer_email,
		verified_at = verified_at,
	})
	return verified
end

return M
