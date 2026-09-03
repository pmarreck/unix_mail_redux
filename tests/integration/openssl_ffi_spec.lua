local openssl = require("openssl_crypto")
local process = require("process")
local uv = require("luv")

local function write_file(path, contents)
	local descriptor = assert(uv.fs_open(path, "w", 384))
	assert(uv.fs_write(descriptor, contents, 0))
	assert(uv.fs_close(descriptor))
end

local function remove_tree(path)
	local iterator = uv.fs_scandir(path)
	if iterator then
		while true do
			local name, kind = uv.fs_scandir_next(iterator)
			if not name then break end
			local child = path .. "/" .. name
			if kind == "directory" then
				remove_tree(child)
			else
				assert(uv.fs_unlink(child))
			end
		end
	end
	assert(uv.fs_rmdir(path))
end

local function run_oracle(executable, arguments, stdin)
	local argv = { executable }
	for _, argument in ipairs(arguments) do
		table.insert(argv, argument)
	end
	return process.run(argv, { capture = true, stdin = stdin })
end

describe("Nix-pinned OpenSSL FFI", function()
	it("loads only an explicit libcrypto path", function()
		assert.matches("^/nix/store/", openssl.library_path())
		assert.matches("^OpenSSL 3%.", openssl.version())
	end)

	it("creates an encrypted root and issues an Apple Mail identity in memory", function()
		local ca = openssl.create_ca({
			common_name = "UNIX MAIL REDUX Offline Root CA",
			passphrase = "correct horse battery staple for root",
			now = 1788440400,
			days = 3650,
		})

		assert.matches("^%-%-%-%-%-BEGIN ENCRYPTED PRIVATE KEY%-%-%-%-%-", ca.private_key_pem)
		assert.matches("^%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-", ca.certificate_pem)
		assert.is_nil(ca.private_key)

		local identity = openssl.issue_identity({
			ca_private_key_pem = ca.private_key_pem,
			ca_certificate_pem = ca.certificate_pem,
			ca_passphrase = "correct horse battery staple for root",
			identity_passphrase = "correct horse battery staple for phone",
			email = "peter@agents.home.arpa",
			name = "Peter Marreck",
			now = 1788440400,
			days = 365,
		})

		assert.are.equal(0x30, identity.pkcs12_der:byte(1))
		assert.is_true(#identity.pkcs12_der > 1000)
		assert.matches("^%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-", identity.certificate_pem)
		assert.is_nil(identity.private_key)
	end)

	it("produces a purpose-restricted chain accepted by the independent CLI oracle", function()
		local executable = assert(os.getenv("POST_OPENSSL"),
			"POST_OPENSSL must name the independent OpenSSL CLI oracle")
		local now = 1788440400
		local root_passphrase = "correct horse battery staple for root"
		local identity_passphrase = "correct horse battery staple for phone"
		local email = "peter@agents.home.arpa"
		local ca = openssl.create_ca({
			common_name = "UNIX MAIL REDUX Offline Root CA",
			passphrase = root_passphrase,
			now = now,
			days = 3650,
		})
		local identity = openssl.issue_identity({
			ca_private_key_pem = ca.private_key_pem,
			ca_certificate_pem = ca.certificate_pem,
			ca_passphrase = root_passphrase,
			identity_passphrase = identity_passphrase,
			email = email,
			name = "Peter Marreck",
			now = now,
			days = 365,
		})
		local directory = assert(uv.fs_mkdtemp(
			(os.getenv("TMPDIR") or "/tmp") .. "/post-smime-oracle-XXXXXX"))
		local root_key_path = directory .. "/root-key.pem"
		local root_certificate_path = directory .. "/root.pem"
		local identity_certificate_path = directory .. "/identity.pem"
		local pkcs12_path = directory .. "/identity.p12"
		write_file(root_key_path, ca.private_key_pem)
		write_file(root_certificate_path, ca.certificate_pem)
		write_file(identity_certificate_path, identity.certificate_pem)
		write_file(pkcs12_path, identity.pkcs12_der)

		local key_check = run_oracle(executable, {
			"pkey", "-in", root_key_path, "-passin", "stdin", "-check", "-noout",
		}, root_passphrase)
		assert.are.equal(0, key_check.rc, key_check.stderr)
		assert.matches("Key is valid", key_check.stdout)

		local root_text = run_oracle(executable, {
			"x509", "-in", root_certificate_path, "-noout", "-text",
		})
		assert.are.equal(0, root_text.rc, root_text.stderr)
		assert.matches("Signature Algorithm: ecdsa%-with%-SHA256", root_text.stdout)
		assert.matches("ASN1 OID: prime256v1", root_text.stdout)
		assert.matches("CA:TRUE, pathlen:0", root_text.stdout)
		assert.matches("Certificate Sign, CRL Sign", root_text.stdout)

		local identity_text = run_oracle(executable, {
			"x509", "-in", identity_certificate_path, "-noout", "-text",
		})
		assert.are.equal(0, identity_text.rc, identity_text.stderr)
		assert.matches("CA:FALSE", identity_text.stdout)
		assert.matches("Digital Signature", identity_text.stdout)
		assert.matches("E%-mail Protection", identity_text.stdout)
		assert.matches("email:" .. email, identity_text.stdout, 1, true)

		local chain_check = run_oracle(executable, {
			"verify", "-attime", tostring(now), "-purpose", "smimesign",
			"-verify_email", email, "-CAfile", root_certificate_path,
			identity_certificate_path,
		})
		assert.are.equal(0, chain_check.rc, chain_check.stderr)
		assert.matches(": OK", chain_check.stdout, 1, true)

		local pkcs12_check = run_oracle(executable, {
			"pkcs12", "-in", pkcs12_path, "-passin", "stdin", "-info", "-noout",
		}, identity_passphrase)
		assert.are.equal(0, pkcs12_check.rc, pkcs12_check.stderr)
		assert.matches("MAC: sha256", pkcs12_check.stderr)
		assert.matches("AES%-256%-CBC", pkcs12_check.stderr)
		remove_tree(directory)
	end)
end)
