local verification = require("smime_verification")

describe("S/MIME verification boundary", function()
	it("claims a verified signature before returning authenticated content", function()
		local claimed
		local result = verification.verify({
			input = "/tmp/signed instruction.eml",
			ca_certificate = "/etc/unix-mail-redux/root-ca.pem",
			email = "peter@agents.home.arpa",
			replay_directory = "/var/lib/unix-mail-redux/replays",
		}, {
			now = function() return 1788440400 end,
			read_input = function(path)
				assert.are.equal("/tmp/signed instruction.eml", path)
				return "SIGNED MIME"
			end,
			read_file = function(path)
				assert.are.equal("/etc/unix-mail-redux/root-ca.pem", path)
				return "ROOT CERTIFICATE"
			end,
			crypto = {
				verify_smime = function(options)
					assert.same({
						message = "SIGNED MIME",
						ca_certificate_pem = "ROOT CERTIFICATE",
						email = "peter@agents.home.arpa",
						at = 1788440400,
					}, options)
					return {
						content = "approved directive\n",
						replay_key = "sha256:" .. string.rep("ab", 32),
						signer_email = "peter@agents.home.arpa",
					}
				end,
			},
			claim = function(directory, claim)
				assert.are.equal("/var/lib/unix-mail-redux/replays", directory)
				claimed = claim
			end,
		})

		assert.same({
			key = "sha256:" .. string.rep("ab", 32),
			email = "peter@agents.home.arpa",
			verified_at = 1788440400,
		}, claimed)
		assert.same({
			content = "approved directive\n",
			replay_key = "sha256:" .. string.rep("ab", 32),
			signer_email = "peter@agents.home.arpa",
		}, result)
	end)
end)
