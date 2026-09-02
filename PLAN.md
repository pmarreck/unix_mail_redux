# UNIX MAIL REDUX plan

- [x] Prevent wake injection whenever a human client is attached to the target
      tmux session, and prove the gate before and after the helper attaches its
      short-lived client.
      - Reproduction: on 2026-09-02 at 17:47 EDT, Peter was typing in the
        attached `Einstein` session when two wake attempts inserted text but
        failed to submit; both exited with `agent did not echo the wake input`.
      - Curiosity poke: a human can attach between any two checks, so the final
        pre-input check must distinguish the helper's own client from every
        other attached client without relying on timing.
      Completed 2026-09-02 17:54 EDT: an integration test reproduced the
      missing attached-client veto against a real tmux server, failed against
      the prior helper, and now passes. The helper rejects pre-attached clients,
      requires its PTY to be the sole client immediately before input, and
      leaves the pane unchanged on rejection. All local and Nix flake checks
      pass.
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
- [x] Replace direct tmux wake injection with a controllable terminal client
      attached to the target session, then prove Codex submission and retain
      Claude Code and Grok as live follow-up checks.
      - Prior live evidence: plain tmux `Enter` and kitty-keyboard encodings did
        not submit reliably across harnesses, especially Codex; Claude Code was
        the permissive case. The 2026-08-28 wake inserted text into Codex but
        remained queued for five hours until Peter pressed Enter manually.
      - Curiosity poke: the client must target one exact tmux pane, negotiate
        the pane's active keyboard protocol, and exit without leaving a hidden
        terminal process or attached client behind.
      Completed 2026-08-28 15:08 EDT: libghostty isolated the missing focus
      state; `strace` proved detached Codex received and ignored Return without
      `FocusIn`. The production helper now uses a short-lived `script(1)` PTY,
      revalidates the prompt around attachment, separates focus/text/Return by
      observed render boundaries, ignores client geometry, and leaves no tmux
      client behind. The deterministic fixture, full suite, Nix package, and a
      late-attached Codex 0.150.1 proof all pass.
- [x] Accept the configured human local-part through explicit `--as`.
      Completed 2026-08-28 09:04 EDT.
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
