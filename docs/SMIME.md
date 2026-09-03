# Private S/MIME signing

UNIX MAIL REDUX can create a private S/MIME certification authority, issue a
signing identity for Apple Mail, and verify a signed raw message before its
contents cross the instruction-authority boundary.

The root certificate is self-signed. The Apple Mail identity is signed by that
root. The root's private key stays encrypted and offline; only the public root
is installed on the mail server.

## What the tool creates

`post smime init-ca` creates a new mode-0700 directory containing:

| File | Contents | Mode | Destination |
|---|---|---:|---|
| `root-ca-key.pem` | AES-256-CBC-encrypted PKCS#8 P-256 private key | 0600 | Offline media only |
| `root-ca.pem` | Public root certificate in PEM form | 0644 | Thelio verifier and offline backup |
| `root-ca.cer` | The same public root certificate in DER form | 0644 | Apple device import |

The root certificate is valid for 10 years. Its critical constraints permit
certificate and revocation-list signing, identify it as a CA, and limit the
chain to one issued level.

`post smime issue` creates a separate new mode-0700 directory containing:

| File | Contents | Mode | Destination |
|---|---|---:|---|
| `identity.p12` | Password-protected P-256 private key, leaf certificate, and root chain | 0600 | Peter's Apple device |
| `identity.pem` | Public leaf certificate | 0644 | Inspection or backup |

The identity is valid for one year and is restricted to digital signatures,
the S/MIME email-protection purpose, and the exact email address in its
`subjectAltName`. It cannot issue certificates.

The implementation calls the Nix-pinned OpenSSL 3 `libcrypto` through LuaJIT
FFI. It generates all keys and certificates in memory and writes no plaintext
private key. The OpenSSL command-line tool is present only in the development
shell as an independent test oracle.

## Root ceremony

Choose a removable encrypted volume for the CA directory. Do this on a machine
with no unrestricted agent process running, disconnect it from the network,
and leave the volume disconnected except when issuing or renewing an identity.
The command refuses to reuse an existing output directory.

First build the tool while the machine is online, then disconnect it. In a
checked-out repository:

```bash
nix build .#post
post_binary="$(readlink -f result)/bin/post"
```

Create a root passphrase with `randompassdict`. Store the temporary passphrase
file on a RAM filesystem, never in the repository or on persistent `/tmp`.
On NixOS, `$XDG_RUNTIME_DIR` is suitable:

```bash
umask 077
root_secret="$XDG_RUNTIME_DIR/unix-mail-redux-root-passphrase"
randompassdict 10 > "$root_secret"
printf 'Root passphrase: '
< "$root_secret" tr -d '\n'
printf '\n'

"$post_binary" smime init-ca \
	--out "/path/on/offline-media/unix-mail-redux-ca" \
	--passphrase-file "$root_secret"
```

Record the passphrase using Peter's chosen offline recovery procedure. Delete
the temporary RAM copy immediately after issuance:

```bash
rm-safe "$root_secret"
```

Keep at least two physically separate encrypted backups of the CA directory.
Possession of both `root-ca-key.pem` and its passphrase permits issuing an
identity that the verifier will accept as Peter.

## Issue Peter's Apple Mail identity

Reconnect the offline CA volume only for this step. Create an independent,
typeable PKCS#12 import passphrase. It protects the transfer package and does
not need to match the root passphrase.

```bash
umask 077
root_secret="$XDG_RUNTIME_DIR/unix-mail-redux-root-passphrase"
phone_secret="$XDG_RUNTIME_DIR/unix-mail-redux-phone-passphrase"

# Enter or restore the root passphrase without putting it in shell history.
read -r -s -p 'Offline root passphrase: ' root_value
printf '\n'
printf '%s\n' "$root_value" > "$root_secret"
unset root_value

randompassdict 6 > "$phone_secret"
printf 'iPhone import passphrase: '
< "$phone_secret" tr -d '\n'
printf '\n'

"$post_binary" smime issue \
	--ca "/path/on/offline-media/unix-mail-redux-ca" \
	--out "/path/on/transfer-media/peter-iphone-smime" \
	--email peter@agents.home.arpa \
	--name "Peter Marreck" \
	--ca-passphrase-file "$root_secret" \
	--identity-passphrase-file "$phone_secret"

rm-safe "$root_secret" "$phone_secret"
```

The root passphrase exists briefly in the shell and generator process memory.
That is why the ceremony machine must be clean and offline. Lua strings cannot
promise a forensic zeroization guarantee after use.

## Install on iPhone or Mac

Transfer only these files to the Apple device:

- `root-ca.cer`
- `identity.p12`

Open each file and approve its profile or identity installation. Enter the
six-word identity import passphrase when prompted. Current Apple settings labels
vary by OS release; the S/MIME controls are under the mail account's advanced
settings. Enable S/MIME and signing for `peter@agents.home.arpa`. Leave
encryption off because this identity is deliberately signing-only.

Do not copy `root-ca-key.pem` to the iPhone, Mac keychain, Thelio, email, cloud
storage, or a transfer directory. Delete the transferred `.p12` after the
identity is installed. Installing broad SSL/TLS trust for this private root is
unnecessary for message signing and would grant the root more authority than
this design needs.

Apple documents the account certificate requirement and signed-message trust
flow in [Use S/MIME in Mail on iOS](https://support.apple.com/en-us/102245).
The certificate profile formats accepted by managed Apple devices are described
in [Apple Platform Deployment certificate payload settings](https://support.apple.com/guide/deployment/certificate-payload-settings-dep91d2eb26/web).

## Live verification gate

Copy only `root-ca.pem` to a protected verifier path on the Thelio. Send a
signed message from Apple Mail to an agent mailbox, then find its ID:

```bash
post --as peter list
```

Himalaya can emit the original RFC 5322 bytes. Pipe those bytes directly into
the verifier:

```bash
himalaya \
	--config /etc/unix-mail-redux/himalaya.toml \
	--account unix_mail_redux \
	message read --raw MESSAGE_ID |
	post smime verify \
		--input - \
		--ca-cert "/protected/path/root-ca.pem" \
		--email peter@agents.home.arpa
```

Successful verification writes only the authenticated message content to
stdout. The exact signer address and a SHA-256 replay key go to stderr. The
first accepted signature creates a mode-0600 claim below
`$XDG_STATE_HOME/unix-mail-redux/smime-replays`, or
`$HOME/.local/state/unix-mail-redux/smime-replays`. Verifying the same signed
message again fails closed as a replay. `--json` emits the three fields as one
JSON object.

The verifier requires all of these conditions:

- exactly one CMS signer;
- a valid signature and certificate chain rooted only in the supplied CA;
- strict X.509 validation at the current injected time;
- an exact certificate match for `peter@agents.home.arpa`;
- a signature that has not been claimed before.

Do not grant automatic instruction authority yet. First prove that an actual
iPhone-composed message passes this command and that tampering or replay fails.
The project tests already exercise valid, tampered, wrong-address,
untrusted-root, expired, multiple-signer, and replay cases against an
independently invoked OpenSSL CLI.

[RFC 8550](https://www.rfc-editor.org/rfc/rfc8550) specifies S/MIME certificate
handling and requires certificate-path processing. Verification uses OpenSSL's
documented [`CMS_verify`](https://docs.openssl.org/3.0/man3/CMS_verify/)
implementation with an explicit trust store.

## Renewal, loss, and YubiKey migration

Issue a fresh identity before the one-year leaf expires. A lost or compromised
Apple identity should be removed from the device and replaced. This small
private PKI does not yet publish a CRL or OCSP service, so the unattended
verifier also needs an explicit local denylist before compromised-certificate
revocation can be called complete.

The unopened YubiKey is optional for this first round trip. A later provider
adapter can place the CA signing key in its PIV application and issue leaves
without exporting that key. Keep the YubiKey sealed until that path has its own
tests and recovery design. The encrypted offline PKCS#8 root remains the
simplest portable starting point and retains a migration path.
