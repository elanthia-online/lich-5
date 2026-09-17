# Combined review: the WebUI stack, lich-5 #1634 + #1648–#1655 + #1657 + #1658

**Reviewed:** 11 stacked PRs, `ed662ca7..e945baf0` — 285 files, +50,863/−2,036 at the tip `e945baf0` on 2026-09-17.
**Based on:** full local clone, every PR head fetched, whole test suite and RuboCop executed on Linux / Ruby 4.0.7, plus five targeted probes against production code. No Windows host, no `npm`, no `yard`, no live game session.
**Verdict:** **Request changes** — narrowly. Two Major findings, both in code added by #1657, both with a contained fix. Everything else in the stack is in good shape, and #1658 is clean.

**Summary:** This is the third outside review of this stack. Two prior reviews (both committed under `docs/`) produced R1–R14 and F1–F7; #1657 claims to close F1–F7. I verified each of the seven against the code and, where possible, against a probe. **Six of the seven are genuinely fixed.** F1 is not: the same "dead worker, stranded `sync`" failure is still reachable through a narrower window, and I have a deterministic reproduction. Separately, #1657 carries an entire feature that no review has ever seen — `--webui-port` / `--webui-no-browser` remote play — and that feature ships a 60-second credential against a documented workflow that cannot complete in 60 seconds. **#1658 adds no risk**: I verified its comment-only claim mechanically rather than on trust.

---

## The stack

| PR | Head | What it is | Verdict |
|---|---|---|---|
| #1634 | `01d51c8e` | Vendor the lich-6 WebUI, flag-gated | Approve |
| #1648 | `dba90bf2` | Core corrections to the vendored runtime | Approve with comments |
| #1649 | `eab7a799` | Launcher choice + `ScriptScope` | Approve |
| #1650 | `4251f279` | Contract 2.19 + the browser client | Approve with comments |
| #1651 | `4e86df0a` | Authentication out of GTK; boundary check | Approve with comments |
| #1652 | `ded07b48` | The WebUI launcher as a complete login | Approve with comments |
| #1653 | `26b6b46b` | GTK shim, core | **Request changes** (Major 1) |
| #1654 | `d11525ee` | GTK shim, data | Approve with comments |
| #1655 | `28cd856f` | **The default flip** | Approve; hold the merge |
| #1657 | `19d2a7be` | F1–F7 fixes + new remote-play feature | **Request changes** (Majors 1 & 2) |
| #1658 | `e945baf0` | YARD documentation sweep | Approve with comments |

---

## Verification of the previous review's findings

| | Layer | Claim | Verdict |
|---|---|---|---|
| **F1** | #1653 | commit inside the rescue; a queued `sync` is refused when the thread ends; `enqueue` answers whether it took the job | ⚠️ **Partially fixed** — Major 1 |
| **F2** | #1652 | master-password change runs under `commit(operation)` | ✅ Fixed |
| **F3** | #1648 | `detach` builds both lifecycle jobs before dispatching either | ✅ Fixed |
| **F4** | #1654 + #1650 | tree expansion bound, pushed per viewer, `expand_*` real | ✅ Fixed (server + shim verified; client half not executable here) |
| **F5** | #1650 | records swept on every send/receive, aged before honoured, capped, dropped on close/clear/disconnect | ✅ Fixed (one narrow gap, open question) |
| **F6** | #1652 | catalog answers the upsert with the key it wrote; `set_favorite` sets | ✅ Fixed |
| **F7** | #1648 | pre-existing titled windows listed and excluded | ✅ Fixed for the reported repro (one sub-point open) |

R1–R14 were spot-checked rather than re-derived; both prior reviews already re-verified those and I found no reason to reopen any.

---

## Major

### 1. The F1 fix leaves the same hang reachable — `sync` can still park for ever — `lib/common/script_scope/gtk/session.rb:346` (#1653, fix attempted in #1657)

```ruby
def enqueue(job = nil, &block)
  job ||= block
  raise ArgumentError, 'block required' unless job
  return nil if @closed

  @queue << job
```

The `@closed` check at line 349 and the push at line 351 are still two separate, unsynchronized steps — the very structure the fix's own comment at line 385 says it replaced ("The closed check and the enqueue used to be two steps, and a shutdown between them queued a job nobody would ever run"). `shutdown` (753) sets `@closed` and pushes `:stop` without taking `@thread_mutex`, and `run_loop`'s new `ensure reject_queued_jobs` (818) drains the queue once, on the way out.

So this interleaving strands a job permanently:

1. A script thread enters `enqueue`, reads `@closed` → false.
2. `shutdown` runs: `@closed = true`, `@queue << :stop`.
3. The session thread pops `:stop`, leaves the loop, and `reject_queued_jobs` drains an **empty** queue. The thread ends.
4. The script thread now pushes its `SyncJob` and calls `ensure_thread`, which returns immediately because `@closed` is true (787).
5. `enqueue` returns `true` — asserting it took the job — and `sync` blocks on `done.pop` (391), which has no timeout.

Reproduced deterministically against the real `Session`, pausing only inside the production `enqueue` between its two steps:

```
closed=true
worker_alive=false
queue_size=1
sync_result=:STILL_WAITING
```

This is the F1 failure mode — dead worker, `sync` still waiting — re-entered through a smaller window. It is narrower than the original (which also killed a *live* session's worker), so it is a Major rather than a blocker, but the fix is advertised as closing it and the new spec at `spec/lib/common/script_scope/gtk_review_fixes_spec.rb:228` does not cover this ordering: it kills the thread *after* the job is already queued, which is the case `reject_queued_jobs` handles.

Reachability is not hypothetical. `GLib::Timeout.add` spawns a source thread that loops `sleep(interval)` then `session.sync { block.call }` (`lib/common/script_scope/gtk/glib.rb:47`), and script exit fires `@owner.at_exit { session.shutdown }` (`session.rb:833`) on another thread. A script with a repeating timer stopped mid-tick is exactly this race. The parked thread never reaches its `ensure`, so `GLib.remove_source(id)` never runs and the source entry leaks until Lich tears the script's threads down.

**Fix:** put the `@closed` read and the `@queue <<` under one lock that `shutdown` and `reject_queued_jobs` also take, so "took the job" and "the thread will drain it" are decided together. Then `enqueue`'s `true` means what the F1 fix says it means — and what #1658 has now written into a `@return` tag.

### 2. `--webui-no-browser` hands the player a URL that is dead in 60 seconds — `lib/webui/server.rb:27` (#1657)

```ruby
LAUNCH_TOKEN_LIFETIME = 60
```

The launch URL carries a one-shot token with a 60-second monotonic lifetime; `handle_auth` deletes it on use and answers a bare `403 Forbidden` once it has expired, with no body explaining why. Confirmed against the real server over HTTP:

```
TTL constant = 60 seconds
after 61s of wall clock: 403 Forbidden body="Forbidden"
fresh URL:               302 Found -> /
```

That is the right lifetime when Lich opens the browser itself — the URL is consumed in milliseconds. It is the wrong lifetime for the feature #1657 adds, whose entire premise is that the player is *somewhere else*. `docs/webui-remote-play.md` instructs:

> Script windows in a game session use their own ephemeral port, so each one needs its own `-L`. Add them to the same SSH command, or **run a second tunnel when the URL appears in the game window.**

Noticing the URL in the game window, switching to a terminal, running `ssh -L`, and pasting the URL into a browser will exceed 60 seconds most of the time. The failure is opaque — `403 Forbidden` — and the doc names no recovery. There is one, undocumented: `Lich::API.webui_launch_url(page: …)` (`lib/api/webui.rb:30`) mints a fresh URL.

**Fix (pick one):** give the no-browser path a longer lifetime than the browser path; or re-announce the URL on demand via a `;` command and document it; or at minimum have the 403 body say the link expired and how to get another.

---

## Minor

### 3. The remote-play doc is wrong about how many tunnels are needed — `docs/webui-remote-play.md` (#1657)

> Script windows in a game session use their own ephemeral port, so each one needs its own `-L`.

They do not. There is one WebUI server per Lich **process**, and script windows are *pages* on it — `Session#service` resolves to the process-wide singleton (`lib/common/script_scope/gtk/session.rb:326`: `@service ||= Lich::WebUI.service`). Every script window in one game session is reachable through that session's single port, so **one `-L` per session** covers all of them. As written the doc tells a remote player to set up N tunnels for N script windows.

### 4. "RuboCop clean" is claimed by two PRs and is wrong in both — #1657 and #1658

Running the repo's own CI command (`bundle exec rubocop`, whole repo):

| Tree | Offenses | Exit |
|---|---|---|
| `main` | 73 | 1 |
| `pr-1657` | 77 | 1 |
| `pr-1658` (tip) | 77 | 1 |

**Methodology (verified, not assumed):** `bundle exec rubocop` run from the repo root with no flags, which resolves `/home/tysong/claude-stuff/lich-5/.rubocop.yml` (confirmed via `--debug`: *"configuration from .../.rubocop.yml"*), RuboCop 1.91.0 from the bundle, the repo's custom `Custom/AsciiOnlySource` cop registered and enabled (confirmed via `--show-cops`). **No PR in the stack modifies `.rubocop.yml`**, and no `.rubocop_todo.yml` exists, so the `main`-vs-tip comparison is like for like. Per-cop breakdown:

| Cop | `main` | tip |
|---|---|---|
| `Layout/ExtraSpacing` | 68 | 68 |
| `Layout/MultilineMethodCallIndentation` | 4 | **8** |
| `Lint/RedundantCopDisableDirective` | 1 | 1 |
| `Custom/AsciiOnlySource` | 0 | 0 |

The entire delta is four `Layout/MultilineMethodCallIndentation` offenses; every other count is identical.

The `pr-1657` and `pr-1658` offense sets are **identical** — a `diff` shows one line, and it is a line-number shift caused by #1658's added documentation, not a new offense. Four offenses are introduced by the stack, all `Layout/MultilineMethodCallIndentation`, all autocorrectable:

| File:line (at the tip) | Introduced by |
|---|---|
| `spec/lib/common/webui_launcher/catalog_integration_spec.rb:126`, `:132` | #1651 |
| `spec/lib/common/script_scope/gtk_review_fixes_spec.rb:354` | #1653 |
| `lib/common/script_scope/gtk/widgets_data.rb:2671` | #1654 |

(A fifth apparent delta, `lib/common/script.rb:2866`, is `main`'s pre-existing offense at `:2852` shifted by added lines — not new.)

The two in `catalog_integration_spec.rb` were added by commit `b80dcfda`, titled *"style(launcher): align a multiline call in the catalog spec"* — a commit that fixed one instance of this cop and introduced two more.

Practical impact is limited: CI is **already red on `main`**, so the stack does not newly break it. One `rubocop -A` anywhere in the stack makes both claims true and closes this for good.

### 5. 163 documented private methods, none carrying `@api private` — `docs/YARD-STYLE-GUIDE.md` requires it (#1658)

The repo's committed style guide is explicit that the private tier requires `summary line, @param, @return, @api private`. Across #1658's 46 files there are **163 documented methods below a bare `private`, and `@api private` appears zero times**. This is not cosmetic: the tag is what keeps those methods out of the generated public documentation, so a sweep whose purpose is a published reference will publish 163 internal methods as API.

### 6. A busy `--webui-port` tells the player the wrong thing — `lib/common/webui_launcher.rb:142` (#1657)

`TCPServer.new` on a taken port raises `Errno::EADDRINUSE`, which lands in `rescue StandardError` and produces *"WebUI launcher unavailable: Errno::EADDRINUSE. Retry with the GTK launcher or abort safely."* — no port number, and advice that is wrong (the fix is another port, not abandoning the WebUI). A fixed port is the one most likely to collide, since a leftover Lich holds it. Inconsistent with the care right next door: `handle_webui_port` (`lib/main/argv_options.rb:187`) dies with *"--webui-port must be from 1 through 65535, got N"*.

### 7. Two new YARD tags formalize the contract Major 1 violates — `lib/common/script_scope/gtk/session.rb` (#1658)

`@return [true, nil] true when queued, nil for a closed session` on `enqueue`, and `@raise [Lich::WebUI::Error] when the session has been shut down` on `sync`. Both describe #1657's *intent* accurately and neither describes current behaviour. Not #1658's bug — but it converts the behaviour into a published promise. Re-check both tags when F1 is properly fixed; if it lands as suggested in Major 1, they become true as written.

---

## Nits

### 8. `--webui-no-browser` propagation reads raw `ARGV` — `lib/common/session_launcher.rb:144` (#1657)

The line directly above resolves its flag through `resolve_launcher(context)`; this one reaches into global `ARGV`. It works — nothing clears `ARGV` wholesale — and it has a spec. But two adjacent flags now have different plumbing.

### 9. `yard` is not in the Gemfile (#1658)

`.yardopts` and a style guide exist, but `bundle exec yard` fails, so #1658's "56.9% → 68.6%" stats are unverifiable with the repo's own bundle. Not asking for CI enforcement — the style guide rules it out — just a dev-group dependency.

---

## Open questions

- **`PresentedWindow#adopt` still trusts the requested pid** — `lib/webui/presented_window.rb:79`. F7 made two points; the exclusion list answers the first, and the second — "the PID check in `adopt` compares the requested PID with the stored requested PID, not the actual ownership of the discovered HWND" — is untouched. **Settles it:** deliberate, or missed? Windows-only, untestable here.

- **F5's replay path can carry a submission outside its own `scope`** — `lib/webui/assets/app.js:171`. On a replay `scope` is recomputed from the *current* render; if the component was rebuilt with no `submissions` entry, the record carries the original password with `scope: []` and `clear_sensitive`'s `dropPending` cannot match it. The 30s TTL still bounds it. **Settles it:** can a page re-render between a send and its stale refusal in a way that drops that cid's entry? One harness case either way.

- **Shim expansion state is per-page, not per-viewer** — `lib/common/script_scope/gtk/widgets_data.rb:1434`. The runtime keeps expansion per viewer; the shim keeps one `@expanded_keys` and emits `row[:expanded]` as the shared base prop. I believe this is unreachable because D26 makes a shim page refuse a second viewer, which is why it is not a finding. **Settles it:** does D26 hold for every shim page, including one re-attached after a reconnect?

- **Are #1658's `@!method` / `@!macro` directives correct?** They declare methods that do not exist in source, so no mechanical check touches them. **Settles it:** one `yard doc` run, eyeballing the generated `Gtk::Widget` page.

---

## What this stack gets right

- **The suite is genuinely green.** `bundle exec rspec` at the tip: **8,717 examples, 0 failures, 1 pending** (the jsdom harness skipping because `npm` is absent — and it skips *loudly*, which is the right design). #1657 reports "55 failures, all the known environment cases"; those are Windows-specific and do not occur on Linux. The claim understates the result. #1658's identical count is also positive evidence that it changed no behaviour.

- **#1658's comment-only claim is true, and provably so.** A token-stream diff across all 46 changed files — comments, whitespace and newlines removed — shows exactly two code deltas, both the disclosed `attr_reader` splits, both with unchanged token counts. This is the check a docs PR most deserves and it passes cleanly.

- **#1658's documentation is accurate where it can be checked mechanically.** 683 documented methods, **zero** `@param` names that do not exist in their signature. It also documents warts rather than smoothing them — `Catalog#toggle_favorite` gets a `@return` that admits its own ambiguity.

- **The stack's non-ASCII additions are suppressed correctly, not broadly.** This repo enforces ASCII-only source through a custom cop, which matters when a PR adds 5,625 lines of prose. The whole stack adds exactly one file containing non-ASCII — `spec/lib/common/script_scope/gtk_shim_spec.rb` (#1653), where an `'e-acute' * 600` tooltip is the point of the test — and it carries a narrowly scoped `# rubocop:disable Custom/AsciiOnlySource` with a stated reason, re-enabled 18 lines later. A byte-level scan of all 147 `.rb`/`.lic` files the stack touches found no other non-ASCII anywhere, including in #1658's documentation sweep.

- **`lib/webui/file_service.rb` is the right shape for a file server.** Realpath containment computed after `expand_path`, an extension allowlist that rejects before any filesystem work, a NUL check, a bounded alias pattern, and a `within?` that fails closed on case-differing paths. I went looking for a traversal and did not find one.

- **The server's auth model is carefully built** (`lib/webui/server.rb`): loopback enforced in the constructor *and* re-checked against the bound address; a `Host` allowlist; `Origin` checked on every authenticated route; `Sec-Fetch-Site`/`Mode` checks; `HttpOnly; SameSite=Strict` cookies named per-port; `Protocol.secure_compare` for the token; one-shot expiring launch tokens; a strict CSP (`default-src 'none'`).

- **The decision *not* to offer `--bind-address` for the WebUI** (`docs/webui-remote-play.md`, "What is deliberately not offered") is the correct call, correctly reasoned, and written down. Major 2 is a complaint about a timeout, not about this stance.

- **Four of the six real fixes remove the mechanism rather than guarding it.** F6 *deletes* the duplicated `find_entry_key`; F3 turns `enqueue_lifecycle` into a context-capturing `lifecycle_job`; F2 routes the last unguarded mutation through the `commit` arbiter every other path already used; F5 sweeps on every send and receive rather than adding a second special case. F4 goes further than asked — `model_changed!` prunes `@expanded_keys` alongside `@selected_keys`, which is the bug you would have filed next.

- **Committing both review documents and a ledger that answers each finding** (`docs/webui-pr-review-1634-1648-1655.md`, `docs/webui-rebuild-review-2026-09-17.md`, `docs/webui-review-ledger.md`) made this review far cheaper and sharper, and is what let me confirm six fixes quickly instead of re-deriving them — and what made F1's gap findable. **#1658 keeping those reasoning comments verbatim**, review references included, protects exactly that. Keep doing both.

---

## Suggested landing order

1. **Fix F1 properly** in #1653 or as a follow-up to #1657 — one lock in `enqueue`, plus a spec that queues *before* shutdown rather than after.
2. **Decide Major 2** — either lengthen the token on the no-browser path or document the reissue API.
3. `rubocop -A` once, anywhere in the stack, which closes finding 4 for both #1657 and #1658.
4. Fix the two doc corrections in #1657 (tunnels per session) and the `@api private` tag in #1658.
5. **Then** merge, with #1655's flip landing only after 1 and 2.

Consider splitting #1657's remote-play feature into its own PR: it is not an F1–F7 fix, it is the only unreviewed feature in the stack, and findings 2, 3, 6 and 8 all live in it. Splitting would let the F1–F7 fixes merge on their own evidence. Note also that #1658 documents `session.rb` and `webui_launcher.rb` heavily — the two files steps 1 and 2 must change — so landing those fixes before the doc sweep, or rebasing it after, is less work than the reverse.

---

## Coverage notes

**Ran:** full `bundle exec rspec` (8,717 examples, 0 failures) and full `bundle exec rubocop` at both `pr-1657` and `pr-1658`, plus `rubocop` on `main` for a baseline — all using the repo's own `.rubocop.yml` (verified by `--debug`) with RuboCop 1.91.0 and the custom ASCII cop active, and confirmed that no PR in the stack alters that config; targeted suites (`spec/lib/webui`, `spec/lib/common/webui_launcher*`, `spec/lib/common/script_scope`, `spec/lib/main`) at 752 examples, 0 failures. Five probes against production code, all attached: the F1 `enqueue`/`shutdown` race, the launch-token expiry over real HTTP, the `--webui-port` end-to-end binding, #1658's token-stream comment-only check, and its `@param`/`@api private` tag checks.

**Did not run, and did not review as if I had:**

- **The jsdom client harness (23 cases) — `npm` is not installed on this box.** The largest gap. Every client-side claim in #1650, and the client halves of F4 and F5, rests on reading `app.js`, not executing it. It is the biggest single artifact in the stack and I read it selectively, not exhaustively.
- **`yard` — not in the Gemfile.** #1658's coverage percentages and all its `@!method` / `@!macro` directives are unverified.
- **All Windows-only code.** `window_presentation.rb`, `presented_window.rb`, the Fiddle/Win32 work and therefore all of F7's fix are unexecutable here.
- **Live acceptance.** No game login, no real browser, no SSH tunnel, no supported-script run (`;eloot`, `;jinx`, `;map`, …). The shim's compatibility claims are reviewed as code, not behaviour.
- **The vendored import in #1634** was reviewed at its security surface rather than line by line.
- **#1658's 5,625 lines of prose** were not read end to end for factual accuracy; the mechanical checks cover tag/signature agreement, not whether each summary sentence describes its method correctly. Spot checks in areas I knew well were accurate.

**Method note:** I did not re-litigate R1–R14 or F1–F7 as open findings — both prior reviews are committed and I treated their resolved items as resolved unless the code said otherwise, which is how F1 surfaced.
