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
	typedef struct asn1_string_st ASN1_STRING;
	typedef struct asn1_string_st ASN1_OCTET_STRING;
	typedef struct bignum_st BIGNUM;
	typedef struct pkcs12_st PKCS12;
	typedef struct stack_st OPENSSL_STACK;
	typedef struct x509_store_st X509_STORE;
	typedef struct X509_VERIFY_PARAM_st X509_VERIFY_PARAM;
	typedef struct CMS_ContentInfo_st CMS_ContentInfo;
	typedef struct CMS_SignerInfo_st CMS_SignerInfo;
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
	int i2d_X509_bio(BIO *bio, X509 *certificate);
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

	CMS_ContentInfo *SMIME_read_CMS(BIO *bio, BIO **detached_content);
	void CMS_ContentInfo_free(CMS_ContentInfo *cms);
	OPENSSL_STACK *CMS_get0_SignerInfos(CMS_ContentInfo *cms);
	OPENSSL_STACK *CMS_get0_signers(CMS_ContentInfo *cms);
	ASN1_OCTET_STRING *CMS_SignerInfo_get0_signature(CMS_SignerInfo *signer);
	int CMS_verify(CMS_ContentInfo *cms, OPENSSL_STACK *certificates,
		X509_STORE *store, BIO *detached_content, BIO *output,
		unsigned int flags);
	X509_STORE *X509_STORE_new(void);
	void X509_STORE_free(X509_STORE *store);
	int X509_STORE_add_cert(X509_STORE *store, X509 *certificate);
	X509_VERIFY_PARAM *X509_STORE_get0_param(const X509_STORE *store);
	int X509_VERIFY_PARAM_set_flags(X509_VERIFY_PARAM *parameters,
		unsigned long flags);
	void X509_VERIFY_PARAM_set_time(X509_VERIFY_PARAM *parameters, long time);
	int X509_check_email(X509 *certificate, const char *email, size_t length,
		unsigned int flags);
	int OPENSSL_sk_num(const OPENSSL_STACK *stack);
	void *OPENSSL_sk_value(const OPENSSL_STACK *stack, int index);
	int ASN1_STRING_length(const ASN1_STRING *string);
	const unsigned char *ASN1_STRING_get0_data(const ASN1_STRING *string);
	int EVP_Digest(const void *data, size_t length, unsigned char *digest,
		unsigned int *digest_length, const EVP_MD *type, void *implementation);
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
local X509_V_FLAG_X509_STRICT = 0x20

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

local function certificate_der(certificate)
	local bio = new_memory_bio()
	require_one(crypto.i2d_X509_bio(bio, certificate),
		"could not DER-encode the X.509 certificate")
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

local function sha256_hex(contents, length)
	local digest = ffi.new("unsigned char[32]")
	local digest_length = ffi.new("unsigned int[1]")
	require_one(crypto.EVP_Digest(contents, length, digest, digest_length,
		crypto.EVP_sha256(), nil), "could not hash the S/MIME signature")
	if digest_length[0] ~= 32 then
		error("OpenSSL returned an invalid SHA-256 digest length", 0)
	end
	local bytes = {}
	for index = 0, 31 do
		bytes[index + 1] = string.format("%02x", tonumber(digest[index]))
	end
	return table.concat(bytes)
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
		certificate_der = certificate_der(certificate),
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

function M.verify_smime(options)
	options = options or {}
	local message = require_text(options.message, "S/MIME message")
	local root_pem = require_text(options.ca_certificate_pem,
		"trusted CA certificate")
	local email = policy.require_email(options.email)
	if type(options.at) ~= "number" or options.at ~= math.floor(options.at) then
		error("S/MIME verification time must be a whole-number Unix timestamp", 0)
	end

	crypto.ERR_clear_error()
	local input = input_bio(message)
	local detached_output = ffi.new("BIO *[1]")
	local cms_pointer = crypto.SMIME_read_CMS(input, detached_output)
	if cms_pointer == nil then
		while crypto.ERR_get_error() ~= 0 do end
		error("invalid S/MIME message", 0)
	end
	local cms = ffi.gc(cms_pointer, crypto.CMS_ContentInfo_free)
	local detached = detached_output[0]
	if detached ~= nil then
		detached = ffi.gc(detached, crypto.BIO_free)
	end

	local signer_infos = crypto.CMS_get0_SignerInfos(cms)
	if signer_infos == nil or crypto.OPENSSL_sk_num(signer_infos) ~= 1 then
		error("S/MIME message must contain exactly one signer", 0)
	end
	local root = read_certificate(root_pem)
	local store = owned(crypto.X509_STORE_new(), crypto.X509_STORE_free,
		"could not allocate the private S/MIME trust store")
	require_one(crypto.X509_STORE_add_cert(store, root),
		"could not add the private S/MIME root to the trust store")
	local parameters = require_pointer(crypto.X509_STORE_get0_param(store),
		"could not access S/MIME verification parameters")
	require_one(crypto.X509_VERIFY_PARAM_set_flags(parameters,
		X509_V_FLAG_X509_STRICT), "could not enable strict X.509 verification")
	crypto.X509_VERIFY_PARAM_set_time(parameters, options.at)

	local output = new_memory_bio()
	if crypto.CMS_verify(cms, nil, store, detached, output, 0) ~= 1 then
		while crypto.ERR_get_error() ~= 0 do end
		error("S/MIME signature or certificate verification failed", 0)
	end
	local signers = owned(crypto.CMS_get0_signers(cms), crypto.OPENSSL_sk_free,
		"could not resolve the verified S/MIME signer")
	if crypto.OPENSSL_sk_num(signers) ~= 1 then
		error("S/MIME message must contain exactly one signer", 0)
	end
	local signer = ffi.cast("X509 *", crypto.OPENSSL_sk_value(signers, 0))
	if signer == nil or crypto.X509_check_email(signer, email, #email, 0) ~= 1 then
		error("S/MIME signer does not match expected email: " .. email, 0)
	end

	local signer_info = ffi.cast("CMS_SignerInfo *",
		crypto.OPENSSL_sk_value(signer_infos, 0))
	local signature = require_pointer(crypto.CMS_SignerInfo_get0_signature(signer_info),
		"could not read the S/MIME signature")
	local signature_length = crypto.ASN1_STRING_length(signature)
	local signature_bytes = require_pointer(crypto.ASN1_STRING_get0_data(signature),
		"could not read the S/MIME signature bytes")
	return {
		content = bio_contents(output),
		replay_key = "sha256:" .. sha256_hex(signature_bytes, signature_length),
		signer_email = email,
	}
end

return M
