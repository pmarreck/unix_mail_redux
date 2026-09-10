# UNIX MAIL REDUX

Private, tailnet-scoped email for Peter and project agents, using a concise
`post` CLI alongside standard mail clients. RFC email and Dovecot-owned Maildir
are the durable transport and storage; every client sees the same messages,
threads, flags, replies and deletions.

Each project has an address at a private `home.arpa` domain and an IMAP folder
in one Dovecot account. Postfix accepts authenticated submission and performs
local LMTP delivery only. The initial server is NixOS; Linux, macOS and Windows
on x86_64/ARM64 are intended client platforms, not a claim of completed testing.

Agent awareness must preserve human drafts and conversation identity. Herdr
is the current workspace manager (Peter, 2026-09-10). Durable mail must survive
an absent agent or a lost notification. A notification alone is not evidence of
an agent reading mail. Mail bodies must never be injected as terminal input.

There is no public MX or Internet relay. Temporary sender-trust decisions remain
explicit operator policy; a displayed From address is not cryptographic proof.
See [RULES.md](RULES.md), [the architecture guide](docs/ARCHITECTURE_AND_OPERATIONS.md)
and [PLAN.md](PLAN.md) for invariants, deployment and measured progress.

Migrated from PROJECT_OVERVIEW.md with its purpose and platform intent preserved.
