# Rules

- Dovecot is the sole authority that mutates Maildir and IMAP state.
- Delivery and a caller-controlled From address do not cryptographically prove
  instruction authority. Any temporary trust policy is an explicit operator
  risk decision and must remain documented until signed-message verification
  replaces it.
- Mail bodies never enter a terminal input stream. A wake contains only fixed,
  program-generated text directing the agent to inspect its mailbox and apply
  the configured authority policy.
- A wake may submit input only after mechanically proving an authorized agent
  is idle at an empty prompt. Ambiguity defers the wake.
- No public MX, Internet relay, or listener outside loopback and the Tailscale
  firewall boundary is permitted.
- Credentials and private TLS keys never enter Git or the Nix store.
- Stable message identity includes the account, mailbox, UIDVALIDITY, and UID.
- Human-facing sends show the candidate message and require confirmation unless
  an explicit non-interactive approval flag is present.
- Machine output is valid JSON and contains no ANSI escapes or prose.
