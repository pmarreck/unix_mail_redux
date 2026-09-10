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
Grok needs its own inbox integration or a supervised wake. Installing this
watcher does not magically install monitors into every agent application.

Herdr 0.8.2 offers `herdr agent prompt TARGET TEXT`, but that is terminal text and
Enter, not a separate mailbox/event channel. Its public API does not expose a
human-draft lock. The automatic mail watcher therefore never invokes it. Existing
owner-authorized manual wake rules still apply. `allowDetachedCodexWake` is a
retired compatibility option with no effect on this watcher.

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
