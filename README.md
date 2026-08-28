[![Mechatron Prime CI](https://img.shields.io/endpoint?url=https%3A%2F%2Fthelio-nixos.tail66c90.ts.net%2Fbadges%2Funix_mail_redux.json&style=for-the-badge)](https://thelio-nixos.tail66c90.ts.net/mechatron-prime/)

# UNIX MAIL REDUX

Deliciously retro mail plumbing with a small modern interface for humans and
agents. The repository name is never part of normal use: its CLI is `post`.

## Try it

The NixOS server module must be active first. On Peter's Thelio, apply its
pinned configuration without updating unrelated inputs:

```bash
SWITCH_NOW=1 ixnay reify --no-update
```

No reboot is required. Once activation succeeds:

```bash
# Inspect all mailboxes.
post status
post status --json

# Inspect the human inbox.
post --as peter list
post --as peter read 42

# Inspect the current project's inbox. Inside a Git checkout, --as is inferred.
cd "$HOME/Code/validate"
post list
post read 42

# Send to a project. The candidate is shown and requires y/yes confirmation.
post to validate --as peter \
	--subject "Please pin the release" \
	--body "The candidate build passed."

# Reply in the human inbox, preserving thread headers.
post reply 42 --as peter --body "Acknowledged."
```

`--yes` skips the interactive review and is intended only for an already
reviewed message. For one-letter use in an interactive shell:

```bash
alias m=post
```

## Mail.app over Tailscale

Configure a manual IMAP account with these values:

| Field | Value |
|---|---|
| Email address | `peter@agents.home.arpa` |
| Username | `pmarreck` |
| Password | Contents of `~/.config/post/password` on the Thelio |
| Incoming server | `thelio-nixos.tail66c90.ts.net`, IMAPS port 993 |
| Outgoing server | `thelio-nixos.tail66c90.ts.net`, SMTPS port 465 |
| Transport security | TLS required |

The server accepts connections only through Tailscale. Internet delivery and
Internet relay are deliberately disabled.

Agent wakeups use a short-lived real tmux terminal client because Codex ignores
Return while its pane is detached and unfocused. The measured cause, failed
approaches, and cleanup guarantees are in
[`docs/TMUX_WAKE.md`](docs/TMUX_WAKE.md).

See `PLAN.md` for the tested delivery milestones and remaining live-client
verification.
