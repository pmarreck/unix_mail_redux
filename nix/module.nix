{ config, lib, pkgs, ... }:

let
	cfg = config.services.unix-mail-redux;
	ownerHome = if cfg.ownerHome == null then "/home/${cfg.owner}" else cfg.ownerHome;
	ownerGroup = cfg.ownerGroup;
	passwordFile = if cfg.passwordFile == null
		then "${ownerHome}/.config/post/password"
		else cfg.passwordFile;
	authFile = "${cfg.stateDirectory}/auth/users";
	tlsDirectory = "${cfg.stateDirectory}/tls";
	tlsCertificateFile = "${tlsDirectory}/${cfg.tailscaleDomain}.crt";
	tlsKeyFile = "${tlsDirectory}/${cfg.tailscaleDomain}.key";
	watchStateDirectory = "${cfg.stateDirectory}/watch";
	watchStateFile = "${watchStateDirectory}/state.json";
	postfixQueue = "/var/lib/postfix/queue";
	himalayaConfig = pkgs.writeText "unix-mail-redux-himalaya.toml" ''
		[accounts.unix_mail_redux]
		default = true
		mailbox.alias.inbox = "INBOX"
		mailbox.alias.sent = "Sent"
		mailbox.alias.drafts = "Drafts"
		mailbox.alias.trash = "Trash"
		imap.server = "imaps://${cfg.tailscaleDomain}:993"
		imap.sasl.plain.username = "${cfg.owner}"
		imap.sasl.plain.password.command = ["${pkgs.coreutils}/bin/cat", "${passwordFile}"]
		smtp.server = "smtps://${cfg.tailscaleDomain}:465"
		smtp.sasl.plain.username = "${cfg.owner}"
		smtp.sasl.plain.password.command = ["${pkgs.coreutils}/bin/cat", "${passwordFile}"]
	'';
	virtualAliases = lib.concatStringsSep "\n" [
		"/^${cfg.humanLocalPart}@${lib.escapeRegex cfg.domain}$/ ${cfg.owner}"
		"/^postmaster@${lib.escapeRegex cfg.domain}$/ ${cfg.owner}"
		"/^([a-z0-9][a-z0-9_-]{0,62})@${lib.escapeRegex cfg.domain}$/ ${cfg.owner}+Agents.$1"
	] + "\n";
in
{
	options.services.unix-mail-redux = {
		enable = lib.mkEnableOption "tailnet-local mail for humans and agents";

		owner = lib.mkOption {
			type = lib.types.str;
			description = "Existing local user who owns the mailbox and client credential.";
		};

		ownerHome = lib.mkOption {
			type = lib.types.nullOr lib.types.str;
			default = null;
			description = "Owner home directory; defaults to /home/OWNER.";
		};

		ownerGroup = lib.mkOption {
			type = lib.types.str;
			default = "users";
			description = "Existing primary group for the mailbox owner.";
		};

		humanLocalPart = lib.mkOption {
			type = lib.types.strMatching "[a-z0-9][a-z0-9_-]{0,62}";
			default = "peter";
			description = "Address delivered to INBOX rather than a project mailbox.";
		};

		domain = lib.mkOption {
			type = lib.types.str;
			default = "agents.home.arpa";
			description = "Private, non-Internet mail domain.";
		};

		tailscaleDomain = lib.mkOption {
			type = lib.types.str;
			description = "MagicDNS name used for IMAPS/SMTPS and Tailscale TLS certificates.";
		};

		tailscaleInterface = lib.mkOption {
			type = lib.types.str;
			default = "tailscale0";
			description = "Only network interface whose firewall admits mail clients.";
		};

		stateDirectory = lib.mkOption {
			type = lib.types.str;
			default = "/var/lib/unix-mail-redux";
			readOnly = true;
			description = "Mutable mail, authentication, and TLS state outside the Nix store.";
		};

		mailDirectory = lib.mkOption {
			type = lib.types.str;
			default = "/var/lib/unix-mail-redux/mail";
			readOnly = true;
			description = "Canonical Maildir owned by Dovecot.";
		};

		passwordFile = lib.mkOption {
			type = lib.types.nullOr lib.types.str;
			default = null;
			description = "Out-of-store cleartext client password file, mode 0600.";
		};

		himalayaConfigFile = lib.mkOption {
			type = lib.types.path;
			readOnly = true;
			default = himalayaConfig;
			description = "Generated non-secret Himalaya account configuration.";
		};

		package = lib.mkOption {
			type = lib.types.package;
			default = pkgs.callPackage ./package.nix { };
			defaultText = lib.literalExpression "pkgs.callPackage ./nix/package.nix { }";
			description = "The post CLI package used by people and the delivery watcher.";
		};

		enableWatcher = lib.mkOption {
			type = lib.types.bool;
			default = true;
			description = "Watch new Maildir deliveries and notify matching agent sessions.";
		};

		wakeProjects = lib.mkOption {
			type = lib.types.listOf (lib.types.strMatching "([*]|[a-z0-9][a-z0-9_-]{0,62})");
			default = [ ];
			description = "Projects authorized for empty-prompt wake input; * authorizes all projects.";
		};

		watchIntervalSeconds = lib.mkOption {
			type = lib.types.ints.positive;
			default = 2;
			description = "Seconds between local Maildir scans.";
		};

		wakeCooldownSeconds = lib.mkOption {
			type = lib.types.ints.positive;
			default = 60;
			description = "Minimum seconds between wakes for one project.";
		};

		noticeRetrySeconds = lib.mkOption {
			type = lib.types.ints.positive;
			default = 300;
			description = "Seconds before an unwoken delivery is announced again.";
		};
	};

	config = lib.mkIf cfg.enable {
		assertions = [
			{
				assertion = lib.hasSuffix ".home.arpa" cfg.domain;
				message = "services.unix-mail-redux.domain must remain beneath home.arpa";
			}
			{
				assertion = lib.hasSuffix ".ts.net" cfg.tailscaleDomain;
				message = "services.unix-mail-redux.tailscaleDomain must be a Tailscale DNS name";
			}
			{
				assertion = !lib.hasPrefix "/nix/store/" passwordFile;
				message = "UNIX MAIL REDUX credentials may not be stored in the Nix store";
			}
		];

		environment.etc."unix-mail-redux/himalaya.toml".source = himalayaConfig;
		environment.systemPackages = [ cfg.package ];

		networking.firewall.interfaces.${cfg.tailscaleInterface}.allowedTCPPorts = [
			465
			993
		];

		users.groups.unix-mail-redux-tls.members = [ "postfix" "dovecot2" ];

		services.postfix = {
			enable = true;
			enableSmtp = false;
			enableSubmission = false;
			enableSubmissions = true;
			postmasterAlias = cfg.owner;
			rootAlias = cfg.owner;
			virtualMapType = "regexp";
			virtual = virtualAliases;
			settings.main = {
				myhostname = cfg.tailscaleDomain;
				mydestination = [ cfg.tailscaleDomain "localhost" ];
				mynetworks = [ "127.0.0.0/8" "[::1]/128" ];
				virtual_alias_domains = [ cfg.domain ];
				recipient_delimiter = "+";
				mailbox_transport = "lmtp:unix:private/dovecot-lmtp";
				default_transport = "error:Internet delivery disabled by UNIX MAIL REDUX";
				relay_transport = "error:Internet relay disabled by UNIX MAIL REDUX";
				smtpd_sasl_type = "dovecot";
				smtpd_sasl_path = "private/auth";
				smtpd_relay_restrictions = "permit_mynetworks,permit_sasl_authenticated,reject";
				smtpd_tls_chain_files = [ tlsKeyFile tlsCertificateFile ];
				smtpd_tls_security_level = "may";
			};
			submissionsOptions = {
				smtpd_tls_security_level = "encrypt";
				smtpd_sasl_auth_enable = "yes";
				smtpd_sasl_type = "dovecot";
				smtpd_sasl_path = "private/auth";
				smtpd_sasl_security_options = "noanonymous";
				smtpd_client_restrictions = "permit_sasl_authenticated,reject";
				smtpd_relay_restrictions = "permit_sasl_authenticated,reject";
				smtpd_recipient_restrictions = "permit_sasl_authenticated,reject";
				milter_macro_daemon_name = "ORIGINATING";
			};
		};

		services.dovecot2 = {
			enable = true;
			enablePAM = false;
			package = pkgs.dovecot_2_4;
			settings = {
				dovecot_config_version = config.services.dovecot2.package.version;
				dovecot_storage_version = config.services.dovecot2.package.version;
				protocols = {
					imap = true;
					lmtp = true;
				};
				mail_driver = "maildir";
				mail_home = ownerHome;
				mail_path = cfg.mailDirectory;
				auth_username_format = "%{user | username}";
				auth_allow_cleartext = false;
				auth_mechanisms = [ "plain" "login" ];
				recipient_delimiter = "+";
				lmtp_save_to_detail_mailbox = true;
				lda_mailbox_autocreate = true;
				lda_mailbox_autosubscribe = true;
				"namespace inbox" = {
					inbox = true;
					separator = ".";
				};
				ssl = "required";
				ssl_server_cert_file = tlsCertificateFile;
				ssl_server_key_file = tlsKeyFile;
				"passdb passwd-file".passwd_file_path = authFile;
				"userdb passwd" = { };
				service = [
					{
						_section.name = "imap-login";
						"inet_listener imap".port = 0;
						"inet_listener imaps" = {
							port = 993;
							ssl = true;
						};
					}
					{
						_section.name = "lmtp";
						"unix_listener ${postfixQueue}/private/dovecot-lmtp" = {
							mode = "0600";
							user = "postfix";
							group = "postfix";
						};
					}
					{
						_section.name = "auth";
						"unix_listener ${postfixQueue}/private/auth" = {
							mode = "0660";
							user = "postfix";
							group = "postfix";
						};
					}
				];
			};
		};

		systemd.services.unix-mail-redux-credentials = {
			description = "Create the UNIX MAIL REDUX mailbox credential";
			wantedBy = [ "multi-user.target" ];
			before = [ "dovecot.service" "postfix.service" ];
			serviceConfig = {
				Type = "oneshot";
				RemainAfterExit = true;
			};
			script = ''
				set -eu
				password_file=${lib.escapeShellArg passwordFile}
				auth_file=${lib.escapeShellArg authFile}
				mail_dir=${lib.escapeShellArg cfg.mailDirectory}
				${pkgs.coreutils}/bin/install -d -m 0700 -o ${lib.escapeShellArg cfg.owner} -g ${lib.escapeShellArg ownerGroup} "$(${pkgs.coreutils}/bin/dirname "$password_file")"
				${pkgs.coreutils}/bin/install -d -m 0750 -o root -g dovecot2 "$(${pkgs.coreutils}/bin/dirname "$auth_file")"
				${pkgs.coreutils}/bin/install -d -m 0700 -o ${lib.escapeShellArg cfg.owner} -g ${lib.escapeShellArg ownerGroup} "$mail_dir"
				${pkgs.coreutils}/bin/install -d -m 0700 -o ${lib.escapeShellArg cfg.owner} -g ${lib.escapeShellArg ownerGroup} ${lib.escapeShellArg watchStateDirectory}
				for mailbox in Sent Drafts Trash; do
					mailbox_dir="$mail_dir/.$mailbox"
					${pkgs.coreutils}/bin/install -d -m 0700 \
						-o ${lib.escapeShellArg cfg.owner} \
						-g ${lib.escapeShellArg ownerGroup} \
						"$mailbox_dir" "$mailbox_dir/cur" \
						"$mailbox_dir/new" "$mailbox_dir/tmp"
				done

				if [ ! -s "$password_file" ]; then
					tmp_password="$password_file.tmp.$$"
					${pkgs.openssl}/bin/openssl rand -base64 36 > "$tmp_password"
					${pkgs.coreutils}/bin/chown ${lib.escapeShellArg cfg.owner}:${lib.escapeShellArg ownerGroup} "$tmp_password"
					${pkgs.coreutils}/bin/chmod 0600 "$tmp_password"
					${pkgs.coreutils}/bin/mv "$tmp_password" "$password_file"
				fi

				if [ ! -s "$auth_file" ] || [ "$password_file" -nt "$auth_file" ]; then
					password="$(LC_ALL=C ${pkgs.coreutils}/bin/tr -d '\r\n' < "$password_file")"
					hash="$(${pkgs.coreutils}/bin/printf '%s\n%s\n' "$password" "$password" | ${config.services.dovecot2.package}/bin/doveadm pw -s SHA512-CRYPT 2>/dev/null)"
					unset password
					tmp_auth="$auth_file.tmp.$$"
					${pkgs.coreutils}/bin/printf '%s:%s\n' ${lib.escapeShellArg cfg.owner} "$hash" > "$tmp_auth"
					${pkgs.coreutils}/bin/chown root:dovecot2 "$tmp_auth"
					${pkgs.coreutils}/bin/chmod 0640 "$tmp_auth"
					${pkgs.coreutils}/bin/mv "$tmp_auth" "$auth_file"
				fi
			'';
		};

		systemd.services.unix-mail-redux-tls = {
			description = "Issue or renew the UNIX MAIL REDUX Tailscale certificate";
			wantedBy = [ "multi-user.target" ];
			after = [ "network-online.target" "tailscaled.service" ];
			wants = [ "network-online.target" ];
			requires = [ "tailscaled.service" ];
			before = [ "dovecot.service" "postfix.service" ];
			serviceConfig.Type = "oneshot";
			script = ''
				set -eu
				tls_dir=${lib.escapeShellArg tlsDirectory}
				cert_file=${lib.escapeShellArg tlsCertificateFile}
				key_file=${lib.escapeShellArg tlsKeyFile}
				${pkgs.coreutils}/bin/install -d -m 0750 -o root -g unix-mail-redux-tls "$tls_dir"
				tmp_cert="$tls_dir/.certificate.$$"
				tmp_key="$tls_dir/.key.$$"
				trap '${pkgs.coreutils}/bin/rm -f "$tmp_cert" "$tmp_key"' EXIT

				if ! ${pkgs.tailscale}/bin/tailscale cert --min-validity 168h \
					--cert-file "$tmp_cert" --key-file "$tmp_key" \
					${lib.escapeShellArg cfg.tailscaleDomain}; then
					if [ -s "$cert_file" ] && [ -s "$key_file" ]; then
						exit 0
					fi
					exit 1
				fi

				changed=0
				if ! ${pkgs.diffutils}/bin/cmp -s "$tmp_cert" "$cert_file" 2>/dev/null; then
					${pkgs.coreutils}/bin/install -m 0644 -o root -g unix-mail-redux-tls "$tmp_cert" "$cert_file"
					changed=1
				fi
				if ! ${pkgs.diffutils}/bin/cmp -s "$tmp_key" "$key_file" 2>/dev/null; then
					${pkgs.coreutils}/bin/install -m 0640 -o root -g unix-mail-redux-tls "$tmp_key" "$key_file"
					changed=1
				fi

				if [ "$changed" -eq 1 ]; then
					${pkgs.systemd}/bin/systemctl try-reload-or-restart dovecot.service postfix.service || true
				fi
			'';
		};

		systemd.timers.unix-mail-redux-tls = {
			description = "Daily UNIX MAIL REDUX certificate renewal check";
			wantedBy = [ "timers.target" ];
			timerConfig = {
				OnCalendar = "daily";
				Persistent = true;
				RandomizedDelaySec = "15m";
			};
		};

		systemd.services.unix-mail-redux-watch = lib.mkIf cfg.enableWatcher {
			description = "Notify idle agent sessions of new UNIX MAIL REDUX mail";
			wantedBy = [ "multi-user.target" ];
			after = [
				"dovecot.service"
				"unix-mail-redux-credentials.service"
			];
			requires = [
				"dovecot.service"
				"unix-mail-redux-credentials.service"
			];
			environment = {
				HOME = ownerHome;
				POST_TMUX = lib.getExe pkgs.tmux;
				POST_TMUX_WAKE = lib.getExe' cfg.package "post-tmux-wake";
				POST_WAKE_PROJECTS = lib.concatStringsSep "," cfg.wakeProjects;
				POST_WATCH_INTERVAL_SECONDS = toString cfg.watchIntervalSeconds;
				POST_WAKE_COOLDOWN_SECONDS = toString cfg.wakeCooldownSeconds;
				POST_NOTICE_RETRY_SECONDS = toString cfg.noticeRetrySeconds;
			};
			serviceConfig = {
				Type = "simple";
				User = cfg.owner;
				Group = ownerGroup;
				ExecStart = "${lib.getExe cfg.package} watch --maildir ${lib.escapeShellArg cfg.mailDirectory} --state-file ${lib.escapeShellArg watchStateFile}";
				Restart = "on-failure";
				RestartSec = 2;
				NoNewPrivileges = true;
			};
		};

		systemd.services.dovecot = {
			requires = [
				"postfix-setup.service"
				"unix-mail-redux-credentials.service"
				"unix-mail-redux-tls.service"
			];
			after = [
				"postfix-setup.service"
				"unix-mail-redux-credentials.service"
				"unix-mail-redux-tls.service"
			];
		};

		systemd.services.postfix = {
			requires = [
				"dovecot.service"
				"unix-mail-redux-credentials.service"
				"unix-mail-redux-tls.service"
			];
			after = [
				"dovecot.service"
				"unix-mail-redux-credentials.service"
				"unix-mail-redux-tls.service"
			];
		};
	};
}
