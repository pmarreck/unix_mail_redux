local openssl = require("openssl_crypto")

describe("Nix-pinned OpenSSL FFI", function()
	it("loads only an explicit libcrypto path", function()
		assert.matches("^/nix/store/", openssl.library_path())
		assert.matches("^OpenSSL 3%.", openssl.version())
	end)
end)
