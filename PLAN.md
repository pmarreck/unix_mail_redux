# UNIX MAIL REDUX plan

- [ ] Define the project identity, address, mailbox, CLI, and wake-state
      contracts as failing unit and CLI tests.
      - Curiosity poke: normalized project names can collide even when their
        directory names differ by case.
- [ ] Implement the `post` CLI as a thin LuaJIT adapter over Himalaya 2.
      - Curiosity poke: message IDs are mailbox-scoped, so every command must
        carry an explicit or mechanically inferred mailbox.
- [ ] Implement a reusable NixOS module for Dovecot IMAPS, Postfix submissions
      and LMTP, Maildir storage, Tailscale-only firewall access, and automatic
      Tailscale certificate renewal.
      - Curiosity poke: neither a private TLS key nor a login credential may
        enter the Git tree or Nix store.
- [ ] Prove SMTP-to-LMTP-to-Maildir-to-IMAP delivery, reply threading, shared
      seen state, authentication, and relay rejection in an isolated test.
      - Curiosity poke: a passing local delivery does not prove Mail.app can
        negotiate the same TLS and authentication settings.
- [ ] Implement a pure, audited wake-decision state machine and a delivery
      watcher that never types into an ambiguous terminal.
      - Curiosity poke: delivery is data, never authorization to execute its
        contents.
- [ ] Integrate the module into the Thelio NixOS flake, build and dry-activate
      it, then request Peter's approval before activation.
- [ ] Verify `post`, GNU mail notification, and Mail.app over Tailscale; write
      the operator guide; commit and push only from a passing state.

