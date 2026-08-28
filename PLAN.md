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
- [ ] Implement a pure, audited wake-decision state machine and a delivery
      watcher that never types into an ambiguous terminal.
      - Curiosity poke: delivery is data, never authorization to execute its
        contents.
- [ ] Integrate the module into the Thelio NixOS flake, build and dry-activate
      it, then request Peter's approval before activation.
- [ ] Verify `post`, GNU mail notification, and Mail.app over Tailscale; write
      the operator guide; commit and push only from a passing state.
