{ pkgs, lib, module }:

let
	evaluated = lib.nixosSystem {
		system = pkgs.stdenv.hostPlatform.system;
		modules = [
			module
			{
				boot.isContainer = true;
				system.stateVersion = "26.05";
				users.users.operator = {
					isNormalUser = true;
					uid = 1000;
					group = "users";
					home = "/home/operator";
				};
				services.unix-mail-redux = {
					enable = true;
					owner = "operator";
					humanLocalPart = "peter";
					domain = "agents.home.arpa";
					tailscaleDomain = "mail.example.ts.net";
					wakeProjects = [ "*" ];
				};
			}
		];
	};
	cfg = evaluated.config;
	mail = cfg.services.unix-mail-redux;
in
assert cfg.services.postfix.enable;
assert !cfg.services.postfix.enableSmtp;
assert cfg.services.postfix.enableSubmissions;
assert cfg.services.postfix.virtualMapType == "regexp";
assert cfg.services.postfix.settings.main.default_transport ==
	"error:Internet delivery disabled by UNIX MAIL REDUX";
assert cfg.services.postfix.settings.main.mailbox_transport ==
	"lmtp:unix:private/dovecot-lmtp";
assert cfg.services.dovecot2.enable;
assert lib.versionAtLeast cfg.services.dovecot2.package.version "2.4";
assert cfg.services.dovecot2.settings.mail_driver == "maildir";
assert cfg.services.dovecot2.settings.mail_path == mail.mailDirectory;
assert cfg.services.dovecot2.settings.auth_username_format == "%{user | username}";
assert cfg.services.dovecot2.settings.lmtp_save_to_detail_mailbox;
assert cfg.services.dovecot2.settings.recipient_delimiter == "+";
assert cfg.services.dovecot2.settings."namespace inbox".inbox;
assert cfg.services.dovecot2.settings."namespace inbox".separator == ".";
assert cfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 465 993 ];
assert cfg.systemd.services ? unix-mail-redux-credentials;
assert cfg.systemd.services ? unix-mail-redux-tls;
assert cfg.systemd.services ? unix-mail-redux-watch;
assert cfg.systemd.services.unix-mail-redux-watch.serviceConfig.User == "operator";
assert cfg.systemd.services.unix-mail-redux-watch.environment.POST_TMUX == lib.getExe pkgs.tmux;
assert cfg.systemd.services.unix-mail-redux-watch.environment.POST_WAKE_PROJECTS == "*";
assert cfg.systemd.timers ? unix-mail-redux-tls;
assert lib.hasInfix "peter@agents\\.home\\.arpa" cfg.services.postfix.virtual;
assert lib.hasInfix "Agents.$1" cfg.services.postfix.virtual;
pkgs.runCommand "unix-mail-redux-module-eval" { } ''
	touch "$out"
''
