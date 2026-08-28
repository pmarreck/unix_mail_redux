# Rules

- Dovecot is the sole authority that mutates Maildir and IMAP state.
- Mail delivery never grants authority to execute a message or wake an agent.
- A wake may submit input only after mechanically proving an authorized agent
  is idle at an empty prompt. Ambiguity defers the wake.
- No public MX, Internet relay, or listener outside loopback and the Tailscale
  firewall boundary is permitted.
- Credentials and private TLS keys never enter Git or the Nix store.
- Stable message identity includes the account, mailbox, UIDVALIDITY, and UID.
- Human-facing sends show the candidate message and require confirmation unless
  an explicit non-interactive approval flag is present.
- Machine output is valid JSON and contains no ANSI escapes or prose.

