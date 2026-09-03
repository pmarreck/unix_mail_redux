local policy = require("smime_policy")

describe("S/MIME certificate policy", function()
	it("classifies the complete address set conservatively", function()
		local addresses = {
			"peter@agents.home.arpa",
			"peter+iphone@agents.home.arpa",
			"Peter@agents.home.arpa",
			"peter@AGENTS.home.arpa",
			"peter..phone@agents.home.arpa",
			".peter@agents.home.arpa",
			"peter@-agents.home.arpa",
			"peter@agents..home.arpa",
			"peter agents.home.arpa",
			"peter@agents.home.arpa\nBcc: attacker@example.com",
		}

		assert.same({
			valid = {
				"peter+iphone@agents.home.arpa",
				"peter@agents.home.arpa",
			},
			invalid = {
				".peter@agents.home.arpa",
				"Peter@agents.home.arpa",
				"peter agents.home.arpa",
				"peter..phone@agents.home.arpa",
				"peter@-agents.home.arpa",
				"peter@AGENTS.home.arpa",
				"peter@agents..home.arpa",
				"peter@agents.home.arpa\nBcc: attacker@example.com",
			},
		}, policy.classify_addresses(addresses))
	end)

	it("derives deterministic validity windows from an injected clock", function()
		assert.same({
			not_before = 1788440100,
			not_after = 1819976400,
		}, policy.validity_window(1788440400, 365))
	end)

	it("defines fixed output paths without exposing a plaintext key", function()
		assert.same({
			private_key = "/offline/mail ca/root-ca-key.pem",
			certificate = "/offline/mail ca/root-ca.pem",
		}, policy.ca_paths("/offline/mail ca"))
		assert.same({
			pkcs12 = "/offline/peter iphone/identity.p12",
			certificate = "/offline/peter iphone/identity.pem",
		}, policy.identity_paths("/offline/peter iphone"))
	end)

	it("normalizes one text-file newline and rejects unsafe passphrases", function()
		assert.are.equal("a sufficiently long passphrase", policy.passphrase(
			"a sufficiently long passphrase\n"
		))
		assert.are.equal("a sufficiently long passphrase", policy.passphrase(
			"a sufficiently long passphrase\r\n"
		))
		assert.has_error(function()
			policy.passphrase("too short\n")
		end, "passphrase must contain at least 16 bytes")
		assert.has_error(function()
			policy.passphrase("sixteen bytes ok\nsecond line")
		end, "passphrase file must contain exactly one line")
		assert.has_error(function()
			policy.passphrase("sixteen bytes ok\0hidden")
		end, "passphrase must not contain NUL")
	end)
end)
