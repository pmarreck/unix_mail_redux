local ffi = require("ffi")
local policy = require("smime_policy")

ffi.cdef([[
	typedef struct bio_st BIO;
	typedef struct bio_method_st BIO_METHOD;
	typedef struct evp_pkey_st EVP_PKEY;
	typedef struct evp_pkey_ctx_st EVP_PKEY_CTX;
	typedef struct evp_md_st EVP_MD;
	typedef struct evp_cipher_st EVP_CIPHER;
	typedef struct x509_st X509;
	typedef struct X509_name_st X509_NAME;
	typedef struct X509_req_st X509_REQ;
	typedef struct X509_crl_st X509_CRL;
	typedef struct X509_extension_st X509_EXTENSION;
	typedef struct asn1_string_st ASN1_INTEGER;
	typedef struct asn1_string_st ASN1_TIME;
	typedef struct bignum_st BIGNUM;
	typedef struct pkcs12_st PKCS12;
	typedef struct stack_st OPENSSL_STACK;
	typedef struct X509V3_CONF_METHOD_st X509V3_CONF_METHOD;
	typedef struct v3_ext_ctx {
		int flags;
		X509 *issuer_cert;
		X509 *subject_cert;
		X509_REQ *subject_req;
		X509_CRL *crl;
		X509V3_CONF_METHOD *db_meth;
		void *db;
		EVP_PKEY *issuer_pkey;
	} X509V3_CTX;
	typedef int pem_password_cb(char *buf, int size, int rwflag, void *userdata);

	const char *OpenSSL_version(int type);
	void ERR_clear_error(void);
	unsigned long ERR_get_error(void);
	void ERR_error_string_n(unsigned long error, char *buffer, size_t length);

	EVP_PKEY_CTX *EVP_PKEY_CTX_new_from_name(void *libctx, const char *name,
		const char *properties);
	void EVP_PKEY_CTX_free(EVP_PKEY_CTX *context);
	int EVP_PKEY_keygen_init(EVP_PKEY_CTX *context);
	int EVP_PKEY_CTX_set_group_name(EVP_PKEY_CTX *context, const char *name);
	int EVP_PKEY_generate(EVP_PKEY_CTX *context, EVP_PKEY **key);
	void EVP_PKEY_free(EVP_PKEY *key);
	const EVP_MD *EVP_sha256(void);
	const EVP_CIPHER *EVP_aes_256_cbc(void);

	X509 *X509_new(void);
	void X509_free(X509 *certificate);
	int X509_set_version(X509 *certificate, long version);
	ASN1_INTEGER *X509_get_serialNumber(X509 *certificate);
	int X509_set_issuer_name(X509 *certificate, const X509_NAME *name);
	int X509_set_subject_name(X509 *certificate, const X509_NAME *name);
	X509_NAME *X509_get_subject_name(const X509 *certificate);
	int X509_set1_notBefore(X509 *certificate, const ASN1_TIME *time);
	int X509_set1_notAfter(X509 *certificate, const ASN1_TIME *time);
	int X509_set_pubkey(X509 *certificate, EVP_PKEY *key);
	int X509_sign(X509 *certificate, EVP_PKEY *key, const EVP_MD *digest);
	int X509_check_private_key(const X509 *certificate, const EVP_PKEY *key);
	int X509_NAME_add_entry_by_txt(X509_NAME *name, const char *field, int type,
		const unsigned char *bytes, int length, int location, int set);
	int X509_add_ext(X509 *certificate, X509_EXTENSION *extension, int location);
	void X509_EXTENSION_free(X509_EXTENSION *extension);

	ASN1_TIME *ASN1_TIME_new(void);
	void ASN1_TIME_free(ASN1_TIME *time);
	int ASN1_TIME_set_string_X509(ASN1_TIME *time, const char *text);
	int RAND_bytes(unsigned char *buffer, int length);
	BIGNUM *BN_bin2bn(const unsigned char *bytes, int length, BIGNUM *result);
	void BN_free(BIGNUM *number);
	ASN1_INTEGER *BN_to_ASN1_INTEGER(const BIGNUM *number, ASN1_INTEGER *integer);

	void X509V3_set_ctx(X509V3_CTX *context, X509 *issuer, X509 *subject,
		X509_REQ *request, X509_CRL *crl, int flags);
	int X509V3_set_issuer_pkey(X509V3_CTX *context, EVP_PKEY *key);
	X509_EXTENSION *X509V3_EXT_conf(void *configuration, X509V3_CTX *context,
		const char *name, const char *value);

	BIO *BIO_new(const BIO_METHOD *method);
	BIO *BIO_new_mem_buf(const void *buffer, int length);
	const BIO_METHOD *BIO_s_mem(void);
	int BIO_free(BIO *bio);
	size_t BIO_ctrl_pending(BIO *bio);
	int BIO_read_ex(BIO *bio, void *data, size_t length, size_t *read);
	int PEM_write_bio_PKCS8PrivateKey(BIO *bio, const EVP_PKEY *key,
		const EVP_CIPHER *cipher, const char *passphrase, int passphrase_length,
		pem_password_cb *callback, void *userdata);
	EVP_PKEY *PEM_read_bio_PrivateKey(BIO *bio, EVP_PKEY **key,
		pem_password_cb *callback, void *userdata);
	int PEM_write_bio_X509(BIO *bio, const X509 *certificate);
	X509 *PEM_read_bio_X509(BIO *bio, X509 **certificate,
		pem_password_cb *callback, void *userdata);

	OPENSSL_STACK *OPENSSL_sk_new_null(void);
	int OPENSSL_sk_push(OPENSSL_STACK *stack, const void *value);
	void OPENSSL_sk_free(OPENSSL_STACK *stack);
	PKCS12 *PKCS12_create(const char *passphrase, const char *friendly_name,
		EVP_PKEY *key, X509 *certificate, OPENSSL_STACK *ca_chain,
		int key_nid, int certificate_nid, int iterations, int mac_iterations,
		int key_type);
	void PKCS12_free(PKCS12 *pkcs12);
	int i2d_PKCS12_bio(BIO *bio, const PKCS12 *pkcs12);
]])

local path = os.getenv("POST_LIBCRYPTO")
if not path or path == "" then
	error("POST_LIBCRYPTO must name the pinned OpenSSL libcrypto library", 0)
end

local crypto = ffi.load(path)
local M = {}
local X509_VERSION_3 = 2
local MBSTRING_UTF8 = 0x1000
local MBSTRING_ASC = 0x1001

local function openssl_error(context)
	local messages = {}
	while true do
		local code = crypto.ERR_get_error()
		if code == 0 then
			break
		end
		local buffer = ffi.new("char[256]")
		crypto.ERR_error_string_n(code, buffer, 256)
		table.insert(messages, ffi.string(buffer))
	end
	local detail = #messages > 0 and ": " .. table.concat(messages, "; ") or ""
	error(context .. detail, 0)
end

local function require_pointer(pointer, context)
	if pointer == nil then
		openssl_error(context)
	end
	return pointer
end

local function require_one(result, context)
	if result ~= 1 then
		openssl_error(context)
	end
end

local function owned(pointer, destructor, context)
	return ffi.gc(require_pointer(pointer, context), destructor)
end

local function require_text(value, label)
	if type(value) ~= "string" or value == "" or value:find("\0", 1, true) then
		error(label .. " must be non-empty text without NUL", 0)
	end
	return value
end

local function new_memory_bio()
	return owned(crypto.BIO_new(crypto.BIO_s_mem()), crypto.BIO_free,
		"could not allocate an OpenSSL memory BIO")
end

local function bio_contents(bio)
	local length = tonumber(crypto.BIO_ctrl_pending(bio))
	if length == 0 then
		return ""
	end
	local buffer = ffi.new("unsigned char[?]", length)
	local count = ffi.new("size_t[1]")
	require_one(crypto.BIO_read_ex(bio, buffer, length, count),
		"could not read an OpenSSL memory BIO")
	if tonumber(count[0]) ~= length then
		error("OpenSSL memory BIO returned a partial read", 0)
	end
	return ffi.string(buffer, length)
end

local function generate_p256_key()
	crypto.ERR_clear_error()
	local context = owned(crypto.EVP_PKEY_CTX_new_from_name(nil, "EC", nil),
		crypto.EVP_PKEY_CTX_free, "could not allocate a P-256 key context")
	require_one(crypto.EVP_PKEY_keygen_init(context),
		"could not initialize P-256 key generation")
	require_one(crypto.EVP_PKEY_CTX_set_group_name(context, "prime256v1"),
		"could not select the P-256 curve")
	local output = ffi.new("EVP_PKEY *[1]")
	require_one(crypto.EVP_PKEY_generate(context, output),
		"could not generate a P-256 key")
	return owned(output[0], crypto.EVP_PKEY_free,
		"OpenSSL returned no generated P-256 key")
end

local function set_random_serial(certificate)
	local bytes = ffi.new("unsigned char[16]")
	require_one(crypto.RAND_bytes(bytes, 16),
		"could not generate a certificate serial number")
	bytes[0] = bit.band(bytes[0], 0x7f)
	local all_zero = true
	for index = 0, 15 do
		if bytes[index] ~= 0 then
			all_zero = false
			break
		end
	end
	if all_zero then
		bytes[15] = 1
	end
	local number = owned(crypto.BN_bin2bn(bytes, 16, nil), crypto.BN_free,
		"could not convert the certificate serial number")
	require_pointer(crypto.BN_to_ASN1_INTEGER(number,
		crypto.X509_get_serialNumber(certificate)),
		"could not store the certificate serial number")
end

local function asn1_time(epoch)
	local value = owned(crypto.ASN1_TIME_new(), crypto.ASN1_TIME_free,
		"could not allocate a certificate time")
	local text = os.date("!%Y%m%d%H%M%SZ", epoch)
	require_one(crypto.ASN1_TIME_set_string_X509(value, text),
		"could not encode certificate time " .. text)
	return value
end

local function add_name_entry(name, field, value, encoding)
	require_one(crypto.X509_NAME_add_entry_by_txt(name, field, encoding,
		value, #value, -1, 0), "could not add certificate subject " .. field)
end

local function add_extension(certificate, context, name, value)
	local extension = owned(crypto.X509V3_EXT_conf(nil, context, name, value),
		crypto.X509_EXTENSION_free, "could not create X.509 extension " .. name)
	require_one(crypto.X509_add_ext(certificate, extension, -1),
		"could not add X.509 extension " .. name)
end

local function new_certificate(options)
	local certificate = owned(crypto.X509_new(), crypto.X509_free,
		"could not allocate an X.509 certificate")
	require_one(crypto.X509_set_version(certificate, X509_VERSION_3),
		"could not select X.509 version 3")
	set_random_serial(certificate)

	local subject = require_pointer(crypto.X509_get_subject_name(certificate),
		"could not access the certificate subject")
	add_name_entry(subject, "CN", options.common_name, MBSTRING_UTF8)
	if options.email then
		add_name_entry(subject, "emailAddress", options.email, MBSTRING_ASC)
	end
	require_one(crypto.X509_set_subject_name(certificate, subject),
		"could not set the certificate subject")

	local issuer = options.issuer_certificate or certificate
	require_one(crypto.X509_set_issuer_name(certificate,
		crypto.X509_get_subject_name(issuer)), "could not set the certificate issuer")
	local window = policy.validity_window(options.now, options.days)
	require_one(crypto.X509_set1_notBefore(certificate, asn1_time(window.not_before)),
		"could not set the certificate start time")
	require_one(crypto.X509_set1_notAfter(certificate, asn1_time(window.not_after)),
		"could not set the certificate end time")
	require_one(crypto.X509_set_pubkey(certificate, options.subject_key),
		"could not set the certificate public key")

	local extension_context = ffi.new("X509V3_CTX[1]")
	crypto.X509V3_set_ctx(extension_context, issuer, certificate, nil, nil, 0)
	require_one(crypto.X509V3_set_issuer_pkey(extension_context,
		options.issuer_key), "could not set the X.509 extension issuer key")
	for _, extension in ipairs(options.extensions) do
		add_extension(certificate, extension_context, extension[1], extension[2])
	end
	if crypto.X509_sign(certificate, options.issuer_key, crypto.EVP_sha256()) <= 0 then
		openssl_error("could not sign the X.509 certificate")
	end
	return certificate
end

local function certificate_pem(certificate)
	local bio = new_memory_bio()
	require_one(crypto.PEM_write_bio_X509(bio, certificate),
		"could not encode the X.509 certificate")
	return bio_contents(bio)
end

local function encrypted_private_key_pem(key, passphrase)
	local bio = new_memory_bio()
	require_one(crypto.PEM_write_bio_PKCS8PrivateKey(bio, key,
		crypto.EVP_aes_256_cbc(), passphrase, #passphrase, nil, nil),
		"could not encrypt the private key")
	return bio_contents(bio)
end

local function input_bio(contents)
	return owned(crypto.BIO_new_mem_buf(contents, #contents), crypto.BIO_free,
		"could not allocate an OpenSSL input BIO")
end

local function read_certificate(contents)
	local bio = input_bio(contents)
	return owned(crypto.PEM_read_bio_X509(bio, nil, nil, nil), crypto.X509_free,
		"could not read the CA certificate")
end

local function read_private_key(contents, passphrase)
	local bio = input_bio(contents)
	local callback = ffi.cast("pem_password_cb *", function(buffer, size)
		if #passphrase > size then
			return -1
		end
		ffi.copy(buffer, passphrase, #passphrase)
		return #passphrase
	end)
	local key = crypto.PEM_read_bio_PrivateKey(bio, nil, callback, nil)
	callback:free()
	return owned(key, crypto.EVP_PKEY_free, "could not decrypt the CA private key")
end

function M.library_path()
	return path
end

function M.version()
	return ffi.string(crypto.OpenSSL_version(0))
end

function M.create_ca(options)
	options = options or {}
	local common_name = require_text(options.common_name, "CA common name")
	local passphrase = policy.passphrase(require_text(options.passphrase,
		"CA passphrase"))
	local key = generate_p256_key()
	local certificate = new_certificate({
		common_name = common_name,
		now = options.now,
		days = options.days,
		subject_key = key,
		issuer_key = key,
		extensions = {
			{ "basicConstraints", "critical,CA:TRUE,pathlen:0" },
			{ "keyUsage", "critical,keyCertSign,cRLSign" },
			{ "subjectKeyIdentifier", "hash" },
			{ "authorityKeyIdentifier", "keyid:always" },
		},
	})
	return {
		private_key_pem = encrypted_private_key_pem(key, passphrase),
		certificate_pem = certificate_pem(certificate),
	}
end

function M.issue_identity(options)
	options = options or {}
	local email = policy.require_email(options.email)
	local name = require_text(options.name, "identity name")
	local ca_passphrase = policy.passphrase(require_text(options.ca_passphrase,
		"CA passphrase"))
	local identity_passphrase = policy.passphrase(require_text(
		options.identity_passphrase, "identity passphrase"))
	local ca_certificate_pem = require_text(options.ca_certificate_pem,
		"CA certificate")
	local ca_private_key_pem = require_text(options.ca_private_key_pem,
		"CA private key")
	local ca_certificate = read_certificate(ca_certificate_pem)
	local ca_key = read_private_key(ca_private_key_pem, ca_passphrase)
	require_one(crypto.X509_check_private_key(ca_certificate, ca_key),
		"CA private key does not match the CA certificate")

	local identity_key = generate_p256_key()
	local identity_certificate = new_certificate({
		common_name = name,
		email = email,
		now = options.now,
		days = options.days,
		subject_key = identity_key,
		issuer_key = ca_key,
		issuer_certificate = ca_certificate,
		extensions = {
			{ "basicConstraints", "critical,CA:FALSE" },
			{ "keyUsage", "critical,digitalSignature" },
			{ "extendedKeyUsage", "emailProtection" },
			{ "subjectAltName", "email:" .. email },
			{ "subjectKeyIdentifier", "hash" },
			{ "authorityKeyIdentifier", "keyid:always" },
		},
	})

	local chain = owned(crypto.OPENSSL_sk_new_null(), crypto.OPENSSL_sk_free,
		"could not allocate the PKCS#12 certificate chain")
	require_one(crypto.OPENSSL_sk_push(chain, ca_certificate),
		"could not add the root certificate to the PKCS#12 chain")
	local pkcs12 = owned(crypto.PKCS12_create(identity_passphrase, name,
		identity_key, identity_certificate, chain, 0, 0, 0, 0, 0),
		crypto.PKCS12_free, "could not create the PKCS#12 identity")
	local bio = new_memory_bio()
	require_one(crypto.i2d_PKCS12_bio(bio, pkcs12),
		"could not encode the PKCS#12 identity")

	return {
		pkcs12_der = bio_contents(bio),
		certificate_pem = certificate_pem(identity_certificate),
	}
end

return M
