# UNIX MAIL REDUX plan

- [x] Repair the detached Codex wake regression reproduced live on 2026-09-03:
      the fixed wake text reached `glob`'s input buffer, but the helper waited
      for an echo in its short-lived terminal transcript, never sent Return,
      and exited fatally. Preserve this as a deterministic failing integration
      test, make target-pane observation authoritative, prevent watcher restart
      loops for uncertain submission outcomes, and repeat the live detached
      test before calling it fixed.
      - Curiosity poke: an apparent pane redraw proves text visibility, not
        accepted submission; success must require a separately observable
        transition out of the prompt.
      - Completed 2026-09-03 09:18 EDT. A RED integration fixture now removes
        the helper-client transcript and hard-wraps the shared pane. The helper
        observes normalized target-pane output and returns safe deferral status
        for uncertain outcomes. The live retry submitted, then Codex 0.153.0
        interrupted its conversation; the exact `glob` conversation was
        restored and its draft cleared through a real attached client. Codex
        is now passive-only, while Claude and Grok retain active wake. The full
        suite and NixOS VM pass.
- [ ] Investigate a harness-native, fixed-content wake event that can trigger
      an agent without entering the same terminal input stream as Peter's
      typing. Start with Codex app-server; retain passive notification and
      deferred wake after the last client detaches as the safe fallback.
      - Curiosity poke: an API method named `turn/start` may still create an
        ordinary user-role prompt rather than a separately authenticated event;
        inspect provenance and concurrent-turn behavior before calling it safe.
- [ ] Implement the design improvements Peter approved by email on 2026-09-02
      and confirmed in the live prompt on 2026-09-03: explicit recipient
      namespaces, a durable
      agent/session registry, fixed sender-independent wake events, message
      delivery/notice/read/reply/defer tracing, Markdown multipart mail, and a
      diagnostics/dead-letter mailbox. Keep signed action directives deferred.
      - Temporary authority policy accepted by Peter on 2026-09-03: treat mail
        apparently sent by the configured human address as Peter's instruction,
        subject to the same scope and safety rules as a live prompt. Document
        that the present shared host credential and unrestricted local agents
        make this
        sender identity forgeable; this is accepted operational risk, not an
        MFIC-grade authentication claim.
      - Curiosity poke: bind future authorization decisions to a server-stamped
        authenticated identity rather than trusting a caller-controlled From
        header.
- [ ] Design the easiest standards-compatible way for Peter to digitally sign
      instructions from Apple Mail on macOS and iPhone, then verify signatures
      mechanically before granting stronger authority. Prefer native S/MIME if
      its certificate lifecycle and mobile compose flow remain tolerable;
      compare it with PGP/MIME and a small signed-directive attachment.
      - [x] Add a narrow LuaJIT FFI adapter for the Nix-pinned OpenSSL 3
        `libcrypto`, with opaque handles and explicit ownership transfer. Load
        its immutable Nix-store path; never fall back to an ambient library in
        packaged operation.
        Completed 2026-09-03 15:07 EDT. The adapter generates P-256 keys,
        encrypted PKCS#8 roots, constrained X.509 certificates, and PKCS#12
        identities entirely in memory. An independently invoked, Nix-pinned
        OpenSSL CLI checks the algorithms, extensions, S/MIME purpose, exact
        mailbox identity, chain, encryption, and PKCS#12 readability.
      - [x] Generate a self-signed P-256 private root CA in a caller-selected
        offline directory, storing its private key only as encrypted PKCS#8 and
        refusing to replace any existing key or certificate.
        Completed 2026-09-03 15:14 EDT. `post smime init-ca` creates a new
        mode-0700 directory, mode-0600 encrypted root key, and public root
        certificate. Existing output directories are never reused or replaced.
      - [x] Issue a purpose-separated P-256 S/MIME signing identity whose
        RFC822 subjectAltName matches the requested mailbox, then export the
        identity and CA chain as a password-protected PKCS#12 file for Apple
        Mail. Keep private passphrases out of argv, logs, Git, and the Nix
        store.
        Completed 2026-09-03 15:14 EDT. `post smime issue` reads both secrets
        from bounded files or one stdin stream, reads the offline root, and
        writes only the password-protected identity package and public leaf
        certificate into a new protected directory. The CLI and real-filesystem
        tests prove path-with-spaces handling, file modes, and collision refusal.
      - [x] Verify signed S/MIME messages through the FFI adapter against an
        explicit private trust root, expected email identity, injected
        verification time, exactly one signer, and a durable replay key before
        granting authority.
        Completed 2026-09-03 15:32 EDT. Verification uses a private trust store,
        strict X.509 rules, an exact mailbox check, one CMS signer, and a
        filesystem-exclusive SHA-256 signature claim before returning content.
      - [x] Differentially test generated certificates and signed messages
        against the independent `openssl` CLI oracle. Cover valid, tampered,
        wrong-address, untrusted-root, expired, multi-signer, and replay cases.
        Completed 2026-09-03 15:32 EDT. The pinned CLI independently signs the
        fixtures and inspects the generated chain, extensions, algorithms,
        PKCS#12 encryption, DER export, identity match, and rejection cases.
      - [x] Document the offline ceremony and stop at the live-install gate:
        Peter imports the CA/identity on his iPhone, enables signing, and sends
        the first signed message. Do not activate signed-mail authority until
        that Apple Mail round trip passes.
        Completed 2026-09-03 15:32 EDT. `docs/SMIME.md` contains the offline
        key-custody procedure, exact commands, Apple import boundary, raw-mail
        verification pipe, renewal limits, and optional YubiKey migration. The
        live Apple Mail round trip remains the parent task's final gate.
      - Evaluate Sigil as the operator-facing certificate/custody boundary,
        while keeping CMS, X.509, MIME canonicalization, and message
        verification in an established independent implementation. Never
        reuse a license/update key for mail, and never treat Sigil's custom
        envelope as an S/MIME object.
      - Curiosity poke: a signing key stored where unrestricted agents can read
        it proves nothing; the private key needs Secure Enclave, hardware-token,
        or offline custody while verification remains unattended.
- [ ] Red-team the accepted temporary mail-authority model in an isolated test
      deployment: sender-header spoofing, shared-account submission, direct
      Maildir mutation, replay, alias ambiguity, and compromised local-agent
      paths. Record which attacks are prevented, detected, or accepted without
      using production credentials or mailboxes.
      - Curiosity poke: Tailscale authenticates devices and encrypts transport;
        it does not distinguish Peter from an unrestricted agent on the same
        trusted host.
- [x] Publish one cohesive, shareable architecture and operations guide after
      the remaining live mail contracts are proved. Link it prominently from
      the README and distinguish measured behavior from planned features.
      - Cover goals and non-goals; Postfix, LMTP, Maildir, Dovecot, Himalaya,
        `post`, watcher, tmux, Tailscale, certificate and credential lifecycle;
        address namespaces; trust and execution-authority boundaries; NixOS
        installation; iPhone/Mail.app and generic client setup; CLI and agent
        workflows; observability; backup/recovery; troubleshooting; tests/CI;
        portability; limitations; and the roadmap.
      - Include a compact architecture diagram and copy-pasteable setup and
        diagnostic commands without Peter-specific secrets or private state.
      - Curiosity poke: a public guide must not imply that terminal wake input
        has cryptographic provenance or that plain IMAP is Internet-safe merely
        because this deployment restricts it to an encrypted tailnet.
      - Completed 2026-09-03 09:18 EDT. README now answers which command-line
        mail program is used and why `home.arpa` is appropriate. The linked
        guide covers the measured architecture, NixOS installation, Apple Mail,
        CLI use, operational diagnostics, state, tests, trust limits, the
        temporary authority policy, S/MIME proposal, and unshipped roadmap.
- [ ] Add opt-in Markdown composition as a standards-compliant
      `multipart/alternative` message: retain the Markdown source as the
      `text/plain` fallback and add a restricted, sanitized `text/html` part
      for graphical mail clients.
      - Curiosity poke: permit only static structural markup and safe URL
        schemes; scripts, inline event handlers, remote images, arbitrary CSS,
        and raw HTML must not cross the renderer boundary.
      - Prove exact MIME structure, Unicode, escaping, nested lists, links,
        code blocks, malformed input, plain-client fallback, and Mail.app
        rendering before making Markdown the default for any path.
- [x] Make delivery notification safe and resilient after the live 2026-09-02
      failure: an attached-human veto must be classified before wake input,
      remain a successful watcher cycle if attachment races the probe, and
      never trigger a systemd restart loop.
      - Live reproduction: `code` mail reached the watcher, the helper safely
        refused the attached `Einstein` client, and `Restart=on-failure`
        retried the unchanged message more than 800 times.
      - Curiosity poke: an attached client can appear after the initial probe,
        so the helper remains the final gate and needs a distinct temporary-
        deferral result rather than an indistinguishable hard failure.
      - Completed 2026-09-02 22:07 EDT. RED tests reproduced five independent
        gaps. The watcher now preclassifies attached sessions, records helper
        exit 75 as a deferred wake, preserves prior wake records, and leaves
        genuine failures fatal. The full suite and NixOS VM pass; the live
        service remained active with zero restarts after a new delivery.
- [x] Make passive tmux mail notices wait for a keypress and resolve an
      unqualified mailbox to a uniquely matching tmux session name, allowing
      `einstein@agents.home.arpa` to notify the `Einstein` session.
      - Curiosity poke: session-name and project-directory matches may collide;
        more than one matching live pane must remain ambiguous and receive no
        terminal input.
      - Completed 2026-09-02 22:07 EDT. Tmux's documented zero-delay message
        waits for the next keypress. A live `code` to `einstein` delivery
        resolved the `Einstein` session and logged one passive notice without
        changing the agent input buffer.
- [x] Add a tailnet-only plaintext IMAP fallback on port 143 for iPhone Mail,
      while retaining IMAPS 993 and SMTPS 465.
      - Live reproduction: iPhone Mail repeatedly opened TCP/993 but sent no
        TLS ClientHello, leaving both sides waiting until Dovecot timed out.
        The same phone authenticated and sent successfully through SMTPS 465.
      - Security boundary: port 143 must be admitted only on `tailscale0`;
        plaintext IMAP credentials remain inside Tailscale's encrypted tunnel.
      - Curiosity poke: prove plain authentication and continued IMAPS support
        in the NixOS VM so the diagnostic path cannot silently replace TLS.
      - Completed 2026-09-02 18:03 EDT. Module evaluation and the project test
        suite pass; the NixOS VM exercises authenticated plain IMAP alongside
        the retained IMAPS and SMTPS listeners.
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
- [x] Connect Mail.app over Tailscale and add a shell-level `You have new mail.`
      notice.
      Completed 2026-09-03 09:18 EDT: iPhone Mail exchanges messages in both
      directions through the tailnet-only IMAP 143 compatibility listener and
      SMTPS 465. Shell/harness notices are live; active Codex wake is tracked
      separately because the 0.153.0 TUI interrupted under terminal injection.
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
