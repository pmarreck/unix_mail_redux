# Herdr mail notifications

`post` still sends and reads ordinary SMTP/IMAP mail. The watcher reads only
Maildir names and flags, including unread messages in both `new/` and `cur/`.
It does not copy mail bodies or change Seen flags. Dovecot owns those operations.

## Routes and awareness

For each mailbox, a unique Herdr agent name or cwd basename identifies its
project directory. Multiple matches defer delivery. Explicit `mailboxRoutes`
take precedence and work without a live agent:

```nix
services.unix-mail-redux = {

  herdrCommand = "/etc/profiles/per-user/operator/bin/herdr";
  herdrSocket = "/home/operator/.config/herdr/herdr.sock";
  mailboxRoutes = {
    einstein = "/home/operator";
    code = "/home/operator";
  };
  wakeProjects = [ "*" ]; # authorizes durable notices, not terminal input
  terminalWakeProjects = [ "*" ]; # separate, optional guarded-input opt-in
};
```

The daemon uses the explicitly configured operator-owned socket. It does not
fabricate a managed pane identity, attach a client, or select the focused pane.
No additional Herdr server is installed or launched.

The watcher writes a fixed-content `llmsend/v1` frontmatter note in the target
inbox. Existing LLMsend monitors/hooks tell the agent to run `post list --as NAME`
and `post read ID --as NAME`. Replies use `post reply ID --as NAME --body TEXT`.
The agent trashes the generated notice after processing mail. Trashing the notice
does not mark mail read; `post read` does. Each new arrival batch gets a distinct
notice, so processing an older notice cannot delete a concurrent new arrival.
Delivered notices are deduplicated across watcher restarts. Legacy tmux wake
state does not suppress a new Herdr-era notice.

Claude's plugin inbox monitor can wake idle Claude sessions. Codex's prompt/tool
hooks expose pending notices during an existing turn or next submitted prompt.
The optional guarded wake also reaches idle Codex and Grok agents. Installing
the watcher does not install application plugins into agents.

Herdr 0.8.2 offers `herdr agent prompt TARGET TEXT`, but that is terminal text and
Enter, not a separate mailbox/event channel. Its public API does not expose a
human-draft lock. `terminalWakeProjects` explicitly accepts this advisory race;
it defaults to empty. `allowDetachedCodexWake` is retired and grants no permission.

## Automatic guarded wakes

The flake pins the llmsend helper and supplies `herdrWakeCommand`. Direct module
imports must supply that absolute executable path themselves. The daemon uses
`--service-socket` and `--expect-session`, verifying the socket is private and
owned by its UID and the target still has the native conversation it discovered.
It never sets `HERDR_ENV` or starts another agent.

Two asynchronous workers maximum inspect ANSI-preserving snapshots and wait for
two stable, empty prompt observations. Human text, uncertain layouts, scrollback,
or non-idle state defer input. Resizing invalidates recovery evidence. The mail
poller continues while workers observe. Each worker has a 20-second observation
budget and a 120-second outer timeout (plus 5-second forced termination grace).

The durable note path is saved before starting a worker. The helper journals an
attempt before typing, so watcher crashes cannot blindly resend it. A stalled
Herdr response permits at most one guarded Enter recovery. Transport uncertainty
does not. Deferred attempts retry after `wakeCooldownSeconds` (default 60).
`unconfirmed`, `already-attempted`, and `activity-observed` are terminal results
for that note/native-session pair; none is a read acknowledgment. Inspect the
agent and attempt journal before deciding whether a manual retry is justified.

The watcher stores outcomes in its state JSON and system journal. The helper
stores per-note attempt records in the owner's
`$HOME/.local/state/llmsend-wake/` (or `$XDG_STATE_HOME/llmsend-wake/`). Notes and
mail remain available if wakes fail. New messages receive a new batch notice.
`post watch --no-wake` disables both durable bridging and terminal wakes.

## Persistent visibility

Herdr 0.8.2 has no notification-list/history command or duration option.
Its pinned source (`client/shell/notifications.rs`) sets custom/finished toasts
to 5 seconds, attention toasts to 8, and update toasts to 3. `ui.toast.delay_seconds`
controls when a toast appears, not how long it remains. Changing the lifetime
or adding general Herdr notification history needs an upstream code change.

Mail remains in IMAP/Maildir until explicitly deleted; notices remain in project
inboxes until processed. Watcher outcomes are retained in the system journal:

```bash
post list --as einstein
journalctl -u unix-mail-redux-watch.service --since today --no-pager
```

Toasts repeat at `noticeRetrySeconds` (default 300) while mail remains unread.
An unsuccessful toast is retried independently of a successfully written notice.
Neither a written notice nor a successful toast is a read acknowledgment.

The obsolete experimental terminal client remains documented in
[TMUX_WAKE.md](TMUX_WAKE.md) for archaeology. It is not used by `post watch`.

## Live verification

On 2026-09-10, Thelio's deployed watcher delivered test mail to existing Codex
and Grok sessions at 17:50:39 EDT. Both began processing by 17:50:41 without a
manual Enter or session restart. Codex returned the requested acknowledgment
through SMTP at 17:51:07; Grok returned its acknowledgment at 17:53:09. The
reply-to headers matched the original test messages. Longer model response time
did not cause the watcher to resend the prompt. `PLAN.md` retains the commit,
native-session and mailbox evidence.
