# Rules

- Dovecot is the sole authority that mutates Maildir and IMAP state.
- Delivery and a caller-controlled From address do not cryptographically prove
  instruction authority. Any temporary trust policy is an explicit operator
  risk decision and must remain documented until signed-message verification
  replaces it.
- Mail bodies never enter a terminal input stream. A wake contains only fixed,
  program-generated text directing the agent to inspect its mailbox and apply
  the configured authority policy.
- A wake may submit input only after two stable ANSI-aware observations of an
  authorized idle agent's empty prompt. Ambiguity defers the wake. These checks
  are advisory; they cannot atomically exclude a racing human keystroke.
- The automatic watcher writes durable fixed-content inbox notices first.
  Terminal wakes require a separate explicit operator opt-in, a private owned
  Herdr socket, and the expected native conversation ID. It never fabricates
  HERDR_ENV, clears drafts, starts another agent, or blindly resends uncertainty.
- No public MX, Internet relay, or listener outside loopback and the Tailscale
  firewall boundary is permitted.
- Credentials and private TLS keys never enter Git or the Nix store.
- Stable message identity includes the account, mailbox, UIDVALIDITY, and UID.
- Human-facing sends show the candidate message and require confirmation unless
  an explicit non-interactive approval flag is present.
- Machine output is valid JSON and contains no ANSI escapes or prose.
