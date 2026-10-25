# PLAN

Open work is ordered below; completed work is archived in [docs/PLAN_LOG.md](docs/PLAN_LOG.md). Architecture and deferred-feature context live in [docs/ARCHITECTURE_AND_OPERATIONS.md](docs/ARCHITECTURE_AND_OPERATIONS.md).

## Current CLI correctness

- [x] Diagnose iOS Mail.app image-attachment retrieval through the packaged SMTP/LMTP/Maildir/IMAP path; all ten live PNGs and MIME metadata were valid, and the live retry passed after reconnecting the phone's private network; retain exact image MIME/byte coverage (risk: generic binary fixtures can pass while `image/*` metadata remains unusable). (done 2026-10-25 17:02 EDT; commit 387c83f)
- [x] Reproduce and repair silent missing-Himalaya/spawn failures, preserve truthful nonzero delivery status, name the executable/configuration on stderr, qualify minimal-PATH packaging, and run the complete isolated suite (risk: reply preparation can duplicate a raw spawn error). (done 2026-10-24 10:10 EDT; commit 7924f55)
- [ ] Reproduce and repair `--body -`/`@stdin` ownership semantics, including empty/read failures, attachment conflicts, MIME body integrity, and explicit help (risk: body and attachment must never both consume stdin).
- [ ] Reproduce and repair `post read --json` stdout contamination while preserving mark-seen behavior and keeping effect notices off machine-readable stdout (risk: fixing output must not skip the Seen mutation).

## Test infrastructure

- [x] Keep the cached NixOS integration-test TLS fixture valid for long-lived binary caches and assert substantial remaining lifetime before exercising clients (risk: a short-lived certificate can make an unchanged derivation fail only after cache aging). (done 2026-10-25 17:08 EDT; commit 80da892)
- [ ] Attribute and reduce the complete `./test` path from 5.96-7.06 seconds to the five-second execution budget without weakening coverage; Lua unit/integration execution accounts for 0.297-0.335 seconds, leaving shell setup and process-heavy suites unseparated (risk: Nix/admission time must remain distinct from execution time).

## Deployment and live gates

- [ ] Carry both repaired package pins into the next authorized NixOS activation, then retire the scoped runtime drop-in described in [docs/HERDR_MAIL.md](docs/HERDR_MAIL.md) (risk: do not fold this into an unrelated activation).
- [ ] Verify a fresh email wakes the idle Einstein agent after the observing turn ends (risk: a working-session dry run is not idle end-to-end evidence).
- [ ] Complete the live Apple Mail S/MIME import/signing gate in [docs/SMIME.md](docs/SMIME.md) before activating signed-mail authority, and evaluate Sigil only as a custody boundary (risk: any unattended readable signing key defeats the authority claim).

## Product and security roadmap

- [ ] Investigate a fixed-content native agent wake that never enters the human terminal input stream, starting with Codex app-server provenance and concurrent-turn behavior (risk: `turn/start` may still create an ordinary user-role prompt).
- [ ] Add explicit `user:`, `project:`, `tmux:`, `claude:`, `codex:`, and `grok:` recipient namespaces plus a durable agent/session registry; reject ambiguous generic `agent:` matches (risk: persona and normalized project names can collide).
- [ ] Add delivery, notice, read, reply, and defer tracing plus a diagnostics/dead-letter mailbox (risk: completion markers must prove effects instead of hiding partial failures).
- [ ] Add opt-in sanitized Markdown as `multipart/alternative` while retaining source Markdown as `text/plain` (risk: reject scripts, event handlers, unsafe URLs, remote images, arbitrary CSS, and raw HTML).
- [ ] Red-team the temporary unsigned-mail authority model in an isolated deployment, covering spoofed From headers, shared submission credentials, Maildir mutation, replay, aliases, and compromised local agents (risk: Tailscale device trust does not distinguish local principals).
