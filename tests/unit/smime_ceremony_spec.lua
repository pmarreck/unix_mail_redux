local ceremony = require("smime_ceremony")

describe("S/MIME offline ceremony", function()
	local now = 1788440400

	it("creates a purpose-separated root in a new protected directory", function()
		local writes
		local result = ceremony.init_ca({
			output = "/offline/mail ca",
			passphrase_file = "/run/secrets/root passphrase",
		}, {
			now = function() return now end,
			read_secret = function(path)
				assert.are.equal("/run/secrets/root passphrase", path)
				return "root passphrase with enough entropy\n"
			end,
			crypto = {
				create_ca = function(options)
					assert.same({
						common_name = "UNIX MAIL REDUX Offline S/MIME Root CA",
						passphrase = "root passphrase with enough entropy",
						now = now,
						days = 3650,
					}, options)
					return {
						private_key_pem = "ENCRYPTED ROOT KEY",
						certificate_pem = "ROOT CERTIFICATE",
					}
				end,
			},
			create_directory = function(directory, files)
				assert.are.equal("/offline/mail ca", directory)
				writes = files
			end,
		})

		assert.same({
			{ name = "root-ca-key.pem", contents = "ENCRYPTED ROOT KEY", mode = 384 },
			{ name = "root-ca.pem", contents = "ROOT CERTIFICATE", mode = 420 },
		}, writes)
		assert.same({
			kind = "ca",
			private_key = "/offline/mail ca/root-ca-key.pem",
			certificate = "/offline/mail ca/root-ca.pem",
		}, result)
	end)

	it("issues one mailbox identity without writing a plaintext identity key", function()
		local writes
		local result = ceremony.issue({
			ca = "/offline/mail ca",
			output = "/offline/peter iphone",
			email = "peter@agents.home.arpa",
			name = "Peter iPhone",
			ca_passphrase_file = "/run/secrets/root passphrase",
			identity_passphrase_file = "/run/secrets/iphone passphrase",
		}, {
			now = function() return now end,
			read_secret = function(path)
				return path:find("root", 1, true)
					and "root passphrase with enough entropy\n"
					or "phone passphrase with enough entropy\n"
			end,
			read_file = function(path)
				local values = {
					["/offline/mail ca/root-ca-key.pem"] = "ENCRYPTED ROOT KEY",
					["/offline/mail ca/root-ca.pem"] = "ROOT CERTIFICATE",
				}
				return assert(values[path], "unexpected read: " .. path)
			end,
			crypto = {
				issue_identity = function(options)
					assert.same({
						ca_private_key_pem = "ENCRYPTED ROOT KEY",
						ca_certificate_pem = "ROOT CERTIFICATE",
						ca_passphrase = "root passphrase with enough entropy",
						identity_passphrase = "phone passphrase with enough entropy",
						email = "peter@agents.home.arpa",
						name = "Peter iPhone",
						now = now,
						days = 365,
					}, options)
					return {
						pkcs12_der = "BINARY IDENTITY",
						certificate_pem = "IDENTITY CERTIFICATE",
					}
				end,
			},
			create_directory = function(directory, files)
				assert.are.equal("/offline/peter iphone", directory)
				writes = files
			end,
		})

		assert.same({
			{ name = "identity.p12", contents = "BINARY IDENTITY", mode = 384 },
			{ name = "identity.pem", contents = "IDENTITY CERTIFICATE", mode = 420 },
		}, writes)
		assert.same({
			kind = "identity",
			pkcs12 = "/offline/peter iphone/identity.p12",
			certificate = "/offline/peter iphone/identity.pem",
			email = "peter@agents.home.arpa",
			name = "Peter iPhone",
		}, result)
	end)

	it("refuses two secrets from the same standard-input stream", function()
		assert.has_error(function()
			ceremony.issue({
				ca = "/offline/mail ca",
				output = "/offline/peter iphone",
				email = "peter@agents.home.arpa",
				name = "Peter iPhone",
				ca_passphrase_file = "-",
				identity_passphrase_file = "-",
			}, {})
		end, "CA and identity passphrases cannot both be read from stdin")
	end)
end)
