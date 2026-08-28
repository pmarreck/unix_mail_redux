{ pkgs, module, package }:

let
	testTls = pkgs.runCommand "unix-mail-redux-test-tls" {
		nativeBuildInputs = [ pkgs.openssl ];
	} ''
		mkdir -p "$out"
		openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
			-subj /CN=UNIX-MAIL-REDUX-Test-CA \
			-addext basicConstraints=critical,CA:TRUE \
			-addext keyUsage=critical,keyCertSign,cRLSign \
			-keyout "$out/ca.key" -out "$out/ca.crt"
		openssl req -new -newkey rsa:2048 -nodes \
			-subj /CN=mail.example.ts.net \
			-addext subjectAltName=DNS:mail.example.ts.net,IP:127.0.0.1 \
			-keyout "$out/server.key" -out "$out/server.csr"
		openssl x509 -req -days 1 \
			-in "$out/server.csr" \
			-CA "$out/ca.crt" -CAkey "$out/ca.key" -CAcreateserial \
			-copy_extensions copy -out "$out/server.crt"
	'';
in
pkgs.testers.runNixOSTest {
	name = "unix-mail-redux-server";

	nodes.machine = { lib, pkgs, ... }: {
		imports = [ module ];
		system.stateVersion = "26.05";

		users.users.operator = {
			isNormalUser = true;
			uid = 1000;
			group = "users";
			home = "/home/operator";
		};

		networking.extraHosts = ''
			127.0.0.1 mail.example.ts.net
		'';
		security.pki.certificateFiles = [ "${testTls}/ca.crt" ];

		environment.systemPackages = with pkgs; [
			curl
			openssl
			package
			swaks
		];

		services.unix-mail-redux = {
			enable = true;
			owner = "operator";
			humanLocalPart = "peter";
			domain = "agents.home.arpa";
			tailscaleDomain = "mail.example.ts.net";
			tailscaleInterface = "lo";
		};

		# The VM proves the mail stack, not Tailscale's certificate service. Keep
		# the same out-of-store certificate paths while replacing only their
		# provisioner with a test CA and leaf certificate trusted by the VM.
		systemd.services.unix-mail-redux-tls = {
			requires = lib.mkForce [ ];
			after = lib.mkForce [ ];
			wants = lib.mkForce [ ];
			script = lib.mkForce ''
				${pkgs.coreutils}/bin/install -d -m 0750 -o root -g unix-mail-redux-tls /var/lib/unix-mail-redux/tls
				${pkgs.coreutils}/bin/install -m 0644 ${testTls}/server.crt /var/lib/unix-mail-redux/tls/mail.example.ts.net.crt
				${pkgs.coreutils}/bin/install -m 0640 ${testTls}/server.key /var/lib/unix-mail-redux/tls/mail.example.ts.net.key
				${pkgs.coreutils}/bin/chown root:unix-mail-redux-tls /var/lib/unix-mail-redux/tls/mail.example.ts.net.key
			'';
		};
	};

	testScript = ''
from datetime import timedelta

start_all()
machine.wait_for_unit("postfix.service")
machine.wait_for_unit("dovecot.service")
machine.wait_for_open_port(465)
machine.wait_for_open_port(993)

password = machine.succeed("cat /home/operator/.config/post/password").strip()
send = (
    "swaks --server 127.0.0.1:465 --tls-on-connect "
    "--auth LOGIN --auth-user operator --auth-password='" + password + "' "
    "--from validate@agents.home.arpa "
    "--to sctui_rust@agents.home.arpa "
    "--header 'Subject: Integration delivery' "
	"--header 'Message-ID: <integration-root@agents.home.arpa>' "
    "--body 'mail crossed SMTP, LMTP, Maildir, and IMAP'"
)
machine.succeed(send)

search_command = (
    "curl --insecure --silent --show-error "
    "--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.sctui_rust -X 'SEARCH ALL'"
)
machine.wait_until_succeeds(
	search_command + " | grep -qF 'SEARCH 1'",
	timeout=timedelta(seconds=20),
)
search = machine.succeed(search_command)
assert "SEARCH 1" in search

message = machine.succeed(
    "curl --insecure --silent --show-error "
    "--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.sctui_rust -X 'FETCH 1 BODY.PEEK[]'"
)
assert "Subject: Integration delivery" in message
assert "Message-ID: <integration-root@agents.home.arpa>" in message
assert "mail crossed SMTP, LMTP, Maildir, and IMAP" in message
machine.succeed(
    "! journalctl -u postfix.service --no-pager "
    "| grep -Fq 'address with illegal extension'"
)

seen_before = machine.succeed(
	"curl --insecure --silent --show-error "
	"--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.sctui_rust -X 'SEARCH SEEN'"
)
assert "SEARCH 1" not in seen_before
machine.succeed("post read 1 --as sctui_rust >/dev/null")
machine.wait_until_succeeds(
	"curl --insecure --silent --show-error "
	"--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.sctui_rust -X 'SEARCH SEEN' "
	"| grep -qF 'SEARCH 1'",
	timeout=timedelta(seconds=20),
)

machine.succeed(
	"post reply 1 --as sctui_rust --yes "
	"--body 'The threaded reply crossed the same account.'"
)
reply_search_command = (
	"curl --insecure --silent --show-error "
	"--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.validate -X 'SEARCH ALL'"
)
machine.wait_until_succeeds(
	reply_search_command + " | grep -qF 'SEARCH 1'",
	timeout=timedelta(seconds=20),
)
reply_message = machine.succeed(
	"curl --insecure --silent --show-error "
	"--user operator:'" + password + "' "
	"imaps://127.0.0.1:993/Agents.validate -X 'FETCH 1 BODY.PEEK[]'"
)
assert "Subject: Re: Integration delivery" in reply_message
assert "In-Reply-To: <integration-root@agents.home.arpa>" in reply_message
assert "References: <integration-root@agents.home.arpa>" in reply_message
assert "The threaded reply crossed the same account." in reply_message

relay = send.replace(
    "--to sctui_rust@agents.home.arpa",
    "--to outside@example.com --quit-after RCPT",
)
machine.fail(relay)
'';
}
