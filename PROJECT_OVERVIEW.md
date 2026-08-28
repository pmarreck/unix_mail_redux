# UNIX MAIL REDUX

UNIX MAIL REDUX is a private, tailnet-scoped messaging system shared by human
operators and software agents. It keeps RFC email as the durable protocol and
Maildir as the recoverable storage format while adding a concise `post` CLI,
project-aware addresses, structured output, and conservative agent wakeups.

One Dovecot account owns mailbox state. Each project gets an IMAP folder and a
matching address at a private `home.arpa` domain. Postfix accepts authenticated
submission and performs local LMTP delivery only. Mail.app, Himalaya, `post`,
and other standard clients therefore observe the same threads, flags, replies,
and deletions.

The initial deployment is hosted on NixOS and reachable only over Tailscale.
The client protocols and `post` behavior are intended to work from Linux,
macOS, and Windows on x86_64 and ARM64.

