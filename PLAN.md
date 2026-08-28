# UNIX MAIL REDUX plan

- [x] Define the project identity, address, mailbox, CLI, and wake-state
      contracts as failing unit and CLI tests.
      - Curiosity poke: normalized project names can collide even when their
        directory names differ by case.
      Completed 2026-08-27 20:56 EDT: 14 pure LuaJIT tests and three Bash CLI
      checks now cover set-based identity classification, option precedence,
      shell-free transport argv, and conservative wake decisions.
- [x] Implement the `post` CLI as a thin LuaJIT adapter over Himalaya 2.
	  - Curiosity poke: message IDs are mailbox-scoped, so every command must
	    carry an explicit or mechanically inferred mailbox.
	  Completed 2026-08-27 21:44 EDT: `post` now lists, reads, marks Seen,
	  reports mailbox status, composes, reviews, sends, and replies through
	  shell-free Himalaya argv. Every outbound message requires human review
	  unless `--yes` explicitly bypasses it.
- [x] Implement a reusable NixOS module for Dovecot IMAPS, Postfix submissions
      and LMTP, Maildir storage, Tailscale-only firewall access, and automatic
      Tailscale certificate renewal.
      - Curiosity poke: neither a private TLS key nor a login credential may
        enter the Git tree or Nix store.
      Completed 2026-08-27 21:31 EDT: the module keeps credentials and
      Tailscale certificates outside the Nix store, exposes only authenticated
      SMTPS/IMAPS on the configured tailnet interface, routes project addresses
      into per-project Maildir mailboxes, and rejects Internet delivery.
- [x] Prove SMTP-to-LMTP-to-Maildir-to-IMAP delivery, reply threading, shared
	  seen state, authentication, and relay rejection in an isolated test.
      - Curiosity poke: a passing local delivery does not prove Mail.app can
        negotiate the same TLS and authentication settings.
	  Completed 2026-08-27 21:44 EDT: the NixOS VM proves authenticated SMTPS,
	  project routing, LMTP, Maildir, IMAPS subject/body retrieval, shared Seen
	  state, reviewed replies with exact thread headers, Sent-copy storage,
	  warning-free Postfix delivery, and SMTP-time relay rejection.
- [x] Implement a pure, audited wake-decision state machine and a delivery
	  watcher that never types into an ambiguous terminal.
	  - Curiosity poke: delivery is data, never authorization to execute its
	    contents.
	  Completed 2026-08-27 22:00 EDT: the unprivileged watcher discovers new
	  project Maildir entries, persists notice/wake state atomically, waits for
	  busy agents to become idle, and recognizes empty Claude, Codex, and Grok
	  prompts at the tmux cursor row. Unknown panes, drafts, dialogs, duplicate
	  agents, absent sessions, and unauthorized projects receive no input.
- [x] Integrate the module into the Thelio NixOS flake, build and dry-activate
      it, then request Peter's approval before activation.
      - Peter approved preparing a live NixOS switch on 2026-08-28; this
        service-only activation must not require a reboot.
      Completed 2026-08-28 09:04 EDT: the live Thelio stack passed authenticated
      SMTP, LMTP, Maildir, IMAP, installed-CLI retrieval, and tmux watcher
      proofs after three RED/GREEN deployment defects were repaired.
- [ ] Connect Mail.app over Tailscale and add a shell-level `You have new mail.`
      notice; the operator guide and underlying IMAPS/SMTPS endpoints are live.
- [ ] Accept the configured human local-part through explicit `--as`.
- [ ] Add explicit `user:`, `project:`, `tmux:`, `claude:`, `codex:`, and
      `grok:` recipient namespaces; permit generic `agent:` only when its
      registry lookup is unique, retain an unqualified name as shorthand for
      the common `project:` case, and preserve the namespace in durable
      mailbox storage.
      - Canonical human address: `user:pmarreck`, matching the authenticated
        account. Optional `user:peter` is an explicit alias to the same inbox.
      - Curiosity poke: persona names can collide across harnesses, so an
        ambiguous generic `agent:` lookup must fail instead of broadcasting.
      - Curiosity poke: `tmux:` delivery must keep working after the pane uses
        `cd`, while `project:` delivery must follow the unique project pane.
- [x] Put the installed `post` CLI on Peter's PATH and document the optional
      one-letter `m` alias without making the repository name part of normal
      use.
      Completed 2026-08-28 09:04 EDT: `/run/current-system/sw/bin/post` is live;
      the README documents `alias m=post` without imposing it.
