{ pkgs, module }:

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

		environment.systemPackages = with pkgs; [
			curl
			openssl
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
		# provisioner with a deterministic local test certificate.
		systemd.services.unix-mail-redux-tls = {
			requires = lib.mkForce [ ];
			after = lib.mkForce [ ];
			wants = lib.mkForce [ ];
			script = lib.mkForce ''
				${pkgs.coreutils}/bin/install -d -m 0750 -o root -g unix-mail-redux-tls /var/lib/unix-mail-redux/tls
				${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
					-subj /CN=mail.example.ts.net \
					-addext subjectAltName=DNS:mail.example.ts.net,IP:127.0.0.1 \
					-keyout /var/lib/unix-mail-redux/tls/mail.example.ts.net.key \
					-out /var/lib/unix-mail-redux/tls/mail.example.ts.net.crt
				${pkgs.coreutils}/bin/chown root:unix-mail-redux-tls /var/lib/unix-mail-redux/tls/mail.example.ts.net.key
				${pkgs.coreutils}/bin/chmod 0640 /var/lib/unix-mail-redux/tls/mail.example.ts.net.key
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
assert "mail crossed SMTP, LMTP, Maildir, and IMAP" in message
machine.succeed(
    "! journalctl -u postfix.service --no-pager "
    "| grep -Fq 'address with illegal extension'"
)

relay = send.replace(
    "--to sctui_rust@agents.home.arpa",
    "--to outside@example.com --quit-after RCPT",
)
machine.fail(relay)
'';
}
