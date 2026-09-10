[![Mechatron Prime CI](https://img.shields.io/endpoint?url=https%3A%2F%2Fthelio-nixos.tail66c90.ts.net%2Fbadges%2Funix_mail_redux.json&style=for-the-badge)](https://thelio-nixos.tail66c90.ts.net/mechatron-prime/)

# UNIX MAIL REDUX

Deliciously retro mail plumbing with a small modern interface for humans and
agents. The repository name is never part of normal use: its CLI is `post`.

The command-line client is the LuaJIT `post` interface over
[Himalaya](https://pimalaya.org/himalaya/); Postfix and Dovecot provide standard
SMTP, LMTP, Maildir, and IMAP. `agents.home.arpa` uses the private-network domain
reserved by [RFC 8375](https://www.rfc-editor.org/rfc/rfc8375.html), matching a
service that exists only inside a tailnet.

See the [complete architecture, setup, usage, security, and operations
guide](docs/ARCHITECTURE_AND_OPERATIONS.md).

Private S/MIME root creation, Apple Mail identity issuance, and signed-message
verification are documented in the [offline S/MIME ceremony](docs/SMIME.md).

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

# Named mailboxes are addressable, including Einstein.
post to einstein --as peter \
	--subject "Status check" \
	--body "Please inspect the project fleet."

# Reply in the human inbox, preserving thread headers.
post reply 42 --as peter --body "Acknowledged."
```

`--yes` skips the interactive review and is intended only for an already
reviewed message. For one-letter use in an interactive shell:

```bash
alias m=post
```

## Mail.app over Tailscale

The preferred configuration uses TLS for both directions:

| Field | Value |
|---|---|
| Email address | `peter@agents.home.arpa` |
| Username | `pmarreck` |
| Password | Contents of `~/.config/post/password` on the Thelio |
| Incoming server | `thelio-nixos.tail66c90.ts.net`, IMAPS port 993 |
| Outgoing server | `thelio-nixos.tail66c90.ts.net`, SMTPS port 465 |
| Transport security | TLS required |

iPhone Mail has been observed opening TCP/993 without sending a TLS handshake,
which leaves its refresh spinner waiting until the server times out. For that
client, use this incoming-only compatibility configuration:

| Field | Value |
|---|---|
| Incoming server | `thelio-nixos.tail66c90.ts.net` (no port suffix) |
| Use SSL | Off |
| Server port | 143 |
| Authentication | Password |
| IMAP path prefix | Blank |

Keep the outgoing settings on SSL port 465. Port 143 is admitted only on the
Thelio's Tailscale interface, so its unencrypted IMAP stream remains inside
Tailscale's encrypted tunnel. Tailscale must be connected before refreshing.
IMAPS on 993 remains available for clients that complete its TLS handshake.
Internet delivery and Internet relay are deliberately disabled.

The watcher discovers agents in Herdr by unique agent name or project-directory
basename. Explicit `mailboxRoutes` support aliases such as Einstein and offline
projects. It writes fixed-content `inbox/*.frontmatter.md` notices for the existing
LLMsend application monitors/hooks and emits a Herdr toast. It never types into
an agent's terminal, starts a client or changes focus.

Claude's installed inbox monitor can wake an idle session; Codex prompt/tool
hooks expose notices when that session next acts. A standalone idle Codex TUI
still needs a human turn or an explicitly supervised native Herdr prompt.
Toast delivery alone does not mean an agent read mail. See
[Herdr mail notifications](docs/HERDR_MAIL.md) for configuration, persistence,
limitations and the older tmux experiment.

See `PLAN.md` for the tested delivery milestones and remaining live-client
verification.
