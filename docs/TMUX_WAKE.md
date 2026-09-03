# Why waking Codex requires a terminal client

## Symptom

The delivery watcher originally ran:

```text
tmux send-keys -l MESSAGE ; send-keys Enter
```

The message appeared in Codex's input box, but Return did not submit it. One
live incident sat in that state for five hours until Peter pressed Return.
Claude Code accepted comparable synthetic input, which hid the defect during
the first implementation.

## Measured cause

Codex 0.150.1 enables terminal focus reporting with `ESC [ ? 1004 h`. tmux
tracks that mode on the pane and only emits `FocusIn` (`ESC [ I`) when the pane
belongs to an attached, focused terminal client.

An external `tmux send-keys` command targets a pane without creating such a
client. `strace` showed that tmux still delivered the prompt and carriage
return:

```text
read(0, "Reply with TRACE_NOCLIENT ...", 1024) = 66
read(0, "\r", 1024)                              = 1
```

Codex displayed the text but ignored Return while unfocused. With a real
terminal client attached, its stdin began with `FocusIn`, and the same
`send-keys Enter` submitted successfully:

```text
read(0, "\33[I", 1024)                           = 3
read(0, "Reply with TRACE_CLIENT ...", 1024)     = 64
read(0, "\r", 1024)                              = 1
```

The experiments separated the possible causes:

| Input path | Result |
|---|---|
| Text and Return in one `send-keys` command | Text remained queued |
| Text redraw, then a separate `send-keys Enter` | Text remained queued |
| tmux control-mode client | Text remained queued |
| PTY client attached after Codex was already idle | Racy; text could remain queued |
| libghostty-backed `agent-tty` client with an explicit focus event | Submitted |
| Minimal PTY client with ordered focus, text, and Return phases | Submitted |

The full libghostty stack was valuable because it supplied a real PTY, rendered
the terminal for inspection, waited on visible state, and let us test exact key
events. It proved that tmux's pane-level injection omitted client state. It is
not a production dependency.

That is why a mail notification feature briefly needed an entire terminal
emulator. The missing input was not another byte sequence. It was the state of
an attached, focused terminal client, plus observable render boundaries between
focus, text, and Return. A terminal emulator supplied all three and exposed the
actual protocol. Once measured, the production path could be reduced to a
short-lived PTY client without carrying libghostty and its renderer.

## Production mechanism

`post-tmux-wake` uses util-linux `script(1)` only as a short-lived PTY
allocator. The helper:

1. verifies that the selected project pane is still the active pane;
2. refuses when any human client is already attached to the target session;
3. verifies that its cursor row and input line still match the empty prompt
   observed by the watcher;
4. attaches an `xterm-256color` tmux client with `ignore-size`, so the hidden
   client cannot resize Peter's session;
5. rechecks the prompt after attachment;
6. verifies that its short-lived client is still the session's only client;
7. sends `FocusOut`, `FocusIn`, and the fixed wake message through that client;
8. waits until the TUI renders the complete message;
9. sends Return as a separate input write;
10. waits for pane content to change, proving that the TUI processed Return;
11. closes the PTY and verifies through tests that no client remains attached.

The attached-client veto was added after a live 2026-09-02 collision. Peter
was typing in an attached Codex session while two watcher retries began wake
input and failed before submission. Prompt text alone was therefore too weak a
gate: a human draft can race terminal rendering. Tmux's independent client
attachment state now blocks unattended input before the helper sends any byte.

The watcher now checks that attachment state before it classifies an empty
prompt as wakeable. An attached session receives a passive tmux message with a
zero timeout, which keeps the notice visible until the next keypress and never
enters the agent's input buffer. If a human attaches after that probe, the
helper returns temporary-deferral status 75. The watcher records the notice and
cooldown without claiming that the agent was woken; it does not crash and ask
systemd to retry the same safety veto. Unexpected adapter failures still fail
the watcher so systemd can restart a genuinely broken process.

This does not give terminal input cryptographic provenance. Tmux, a terminal
emulator, and the agent TUI all see the fixed wake sentence as keyboard input.
The safety case depends on admitting only a hard-coded sentence at a detached,
revalidated empty prompt. Mail bodies are never injected. After reading a
message, the agent inspects its sender and applies the deployment's documented
authority policy. Automated cryptographic authority remains disabled until the
live Apple Mail S/MIME gate passes.

The phase boundaries matter. A trace of an earlier draft showed Codex receiving
`FocusOut + FocusIn + message + Return` in one `read(2)` call and ignoring
Return. Rendering the message before the separate Return gives the TUI an
event-loop boundary without a guessed sleep.

The helper refuses multiline or control-bearing messages. Mail content is
never typed into the agent. When `trustUnsignedHumanMail` is enabled, the fixed
wake names the exact configured human address and states that unsigned mail
displaying that address is temporarily authoritative under normal scope and
safety rules. Otherwise it states that mail grants no authority without
independent sender authentication.

Codex 0.153.0 is passive by default. A live detached test on 2026-09-03
submitted the fixed text but then interrupted the Codex conversation when the
short-lived client detached. A deployment may set `allowDetachedCodexWake`
only after accepting that measured risk. The prompt and attached-human gates
remain mandatory. Claude Code and Grok use the gated terminal path without
that extra opt-in.

## Regression controls

`tests/fixtures/focus_gate.lua` behaves like the relevant part of Codex. It
requests focus events, records direct detached Return as `IGNORED`, and records
focused Return as `SUBMITTED`.

`tests/integration/tmux_focus_wake_test` proves all of these conditions against
a real tmux server:

- direct `send-keys` reproduces the failure;
- an attached human client vetoes the wake without changing the agent screen;
- the PTY helper submits;
- the expected focus transition occurred;
- no hidden tmux client survives.

The packaged helper was also exercised against a fresh, already-idle Codex
0.150.1 session. Codex answered `PACKAGED_WAKE_V3_OK`, and `list-clients`
returned empty afterward.

## Alternative

A tmux fork could expose a command that injects a key through a named client's
key-processing path, or explicitly establishes pane focus before injection.
That could eliminate the short-lived PTY. Carrying and rebasing a tmux fork is
not justified while the tested helper remains small.
