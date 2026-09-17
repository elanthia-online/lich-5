# Code review: PR #1634 and #1648–#1655

Reviewed September 17, 2026. Recommendation: **request changes before merging the complete stack and enabling WebUI by default**. Seven findings below have reproductions. Two are high priority; five are medium priority. No production files were changed and no GitHub comments were posted.

## Revision and scope

The review used the fetched PR heads, with the complete implementation checked out at `28cd856f1f971d8b64de2bebb29eafc9ad352497` in `C:/Gemstone/review-webui-pr-1648-1655`. This is a separate detached worktree; it does not change the user's working branch.

| PR | Layer | Reviewed head |
| --- | --- | --- |
| #1634 | Vendor/runtime foundation | `01d51c8e93668ed0aa4bdd4e1b229430ab599482` |
| #1648 | Core corrections | `dba90bf276a4ebd26b3aa5bdf7f7a40163851993` |
| #1649 | Wiring | `eab7a799db9aa04591c209b2f92a4f2f3693d0c2` |
| #1650 | Contract primitives/client | `4251f279c870c632002c62d0413cd6b951736411` |
| #1651 | Services boundary | `4e86df0a5978c29bbc42b41c28636e34ab9518ed` |
| #1652 | Launcher | `ded07b486c64bc99ff9e71648ade0e16a40604c3` |
| #1653 | Shim core | `26b6b46b962f414df8d470c894a0d84ae4390810` |
| #1654 | Shim data | `d11525ee546af56a9832cc812f77b7dd2f859c90` |
| #1655 | Default flip | `28cd856f1f971d8b64de2bebb29eafc9ad352497` |

This review follows callers and state transitions in the full checkout: launcher selection and startup, authentication/catalog mutations, asynchronous cancellation, runtime attachments and modal completion, dispatch and shutdown, server authentication and writes, client editing and replay, native window discovery, and shim materialization and data widgets. It also reassesses the previous review's fixes. It is not a claim that every line of the vendor import or every GTK API has been exhaustively verified.

The companion scripts PR is outside this requested set. No live game login, real credential mutation, or manipulation of the user's browser windows was performed. Native window findings use controlled discovery seams; browser DOM findings execute the real client in jsdom.

## Findings

### F1 — P1: A commit exception can kill the session thread and strand synchronous callers

**Layer:** #1653. **Code:** [session.rb:436](/C:/Gemstone/review-webui-pr-1648-1655/lib/common/script_scope/gtk/session.rb:436), also `run_batch` at 413, `commit` at 480, and `sync` at 358.

`run_batch` rescues errors from `job.call`, but its final `commit unless @closed` executes outside that rescue. `commit` itself rescues only `Lich::WebUI::Error`. A normal `NoMethodError` or other script/materialization exception therefore terminates the worker.

There is a consequential race with `sync`: enqueue a synchronous job while the worker is still alive inside the failing commit. `ensure_thread` sees a live worker and does not start another. When that commit raises, the new job remains queued and its caller waits indefinitely on `done.pop`. A future enqueue might restart the worker, but nothing guarantees another enqueue will arrive.

**Reproduction:** A barrier holds a real session inside a synthetic failing window's `materialize!`; a second thread calls `session.sync`; releasing the barrier raises `NoMethodError`. The observed result is `worker_alive: false, sync_still_waiting: true`. The probe terminates its own waiting thread afterward.

The broad suite stalled with the same commit stack. Interestingly, the existing “survives a script error raised during commit” example passed when isolated while printing worker-death traces: its later call can restart a dead worker. That assertion does not prove the worker survived or cover the enqueue-before-death ordering.

**Fix direction:** Put batch commit inside the worker's exception boundary. Define how a failed session completes or rejects outstanding synchronous jobs, and test the barrier-controlled ordering rather than relying on sleeps and a later successful `sync`.

### F2 — P1: Master-password changes still commit after launcher cancellation

**Layer:** #1652. **Code:** [webui_launcher.rb:929](/C:/Gemstone/review-webui-pr-1648-1655/lib/common/webui_launcher.rb:929).

`change_master_password` transfers the three submitted secrets, creates an operation, and queues a worker. That worker calls `@catalog.change_master_password(current, replacement)` directly. It never uses the new `commit(operation)` arbiter.

`close` clears active operations, but `SerialExecutor#stop(wait: false)` places a stop marker behind already queued work. A password change waiting behind another operation therefore still runs after close. Only its subsequent UI completion is rejected. The underlying method changes credential storage, so rejecting the completion is too late.

**Reproduction:** Queue the production handler using real `Submission` and `SensitiveValue` objects, close the launcher, then release the queued work. A recording catalog receives the password-change call while `launcher.lifecycle == :closed`.

**Fix direction:** Arbitrate the mutation itself under `commit(operation)`, as the corrected account-save and persistent-launch paths do. Cover close and viewer cancellation before the queued job starts. Do not treat a rejected `complete` as cancellation of an earlier write.

### F3 — P2: Modal close races destruction of the attachment used for the next lifecycle callback

**Layer:** #1648, interacting with the foundational runtime. **Code:** [runtime.rb:292](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/runtime.rb:292), [runtime.rb:572](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/runtime.rb:572).

`detach` enqueues `:close`, then separately constructs and enqueues `:detach`. The owner dispatcher is free to run the first callback immediately. The new modal close callback resolves the Future; completion closes the page; `ViewerStore#destroy_locked!` clears `attachment.render`. The second `enqueue_lifecycle` then dereferences `attachment.render.tree` and raises `NoMethodError`.

This exception is outside the runtime's normal contract/protocol refusal handling. The modal may already be resolved, but the detach message fails and the detach lifecycle callback is lost.

**Reproduction:** Use the real modal coordinator, runtime and viewer store with a dispatcher seam that executes each enqueued callback immediately. Attach a modal and detach it. The result is `undefined method 'tree' for nil` at `runtime.rb:572`. This forces a legal ordering of the actual independent worker; it does not replace the modal implementation.

**Fix direction:** Capture the necessary lifecycle contexts before dispatching either callback, or serialize the complete detach transition. Ensure destruction is idempotent and does not invalidate data still needed by the close path.

### F4 — P2: Shim tree expansion disappears on the next server render

**Layers:** #1654 and #1650 integration. **Code:** [widgets_data.rb:1558](/C:/Gemstone/review-webui-pr-1648-1655/lib/common/script_scope/gtk/widgets_data.rb:1558), [app.js:1061](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/assets/app.js:1061).

The new client renders a hierarchy and changes `row.expanded` locally when its arrow is clicked. It then tries to emit `row_toggle`. Shim `TreeView#always_bound_events` binds selection and cell editing, but not `row_toggle`; the client's `emit` drops unbound events. Consequently the runtime never stores expansion for shim tables. Their row properties also supply no expanded state.

Clicking the arrow works briefly, but any server render reconstructs the rows as collapsed. A selection or periodic script update can therefore collapse the tree the player just opened. `expand_all`, `collapse_all`, and `expand_row` are also still no-ops.

**Reproduction:** Run the real client with a hierarchical table using the shim's bindings and row shape. Visible rows go from 3 to 5 on expansion, no event is sent, and a fresh render returns the visible count to 3. The native client test passes because its fixture binds `row_toggle`; it does not cover the shim combination.

**Fix direction:** Bind expansion events for shim trees so the viewer store receives them, and implement the programmatic expansion methods against the same state model. Test expand → select/update → rerender through the shim-generated contract.

### F5 — P2: Retry records have no effective idle expiry and retain cleared passwords

**Layer:** #1650. **Code:** [app.js:171](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/assets/app.js:171), [app.js:1868](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/assets/app.js:1868), `page_closed` at 1972.

Every eligible event adds a request record, including its submission. Successful records are retained for possible delayed stale refusals. The stated 30-second TTL is checked only when another render of that same page arrives. There is no timer, count bound, or page-close cleanup of these records. An idle or closed page can therefore retain them indefinitely; `clear_sensitive` empties controls but leaves the submitted password in this map.

Additionally, the render handler checks `record.replay` before checking age. A stale refusal arriving after the nominal expiry marks the old record for replay and bypasses expiration entirely.

**Reproduction:** Submit a synthetic password, receive `clear_sensitive`, advance the browser clock by an hour, then deliver a stale refusal naming the original request and a render. The visible field remains empty, but the client sends a second event containing the original password. This demonstrates retention and expired replay, not credential disclosure to an outside party.

**Fix direction:** Enforce expiry before accepting a refusal or replay, sweep idle records, and remove records for closed pages. Define a bounded lifecycle for sensitive submissions that still permits legitimate in-flight stale recovery; an acknowledgment protocol is another option.

### F6 — P2: Favorite lookup can choose a different custom launch entry

**Layer:** #1652. **Code:** [webui_launcher.rb:1463](/C:/Gemstone/review-webui-pr-1648-1655/lib/common/webui_launcher.rb:1463), caller at 1092.

The catalog now correctly distinguishes entries by custom launch command, but `find_entry_key` compares only account, character, game and frontend. Manual Play with Favorite enabled saves the requested command, then finds the first entry sharing those four fields and toggles its favorite. If the same character/frontend has two commands, that can be the other entry.

**Reproduction:** Create an actual temporary catalog with `command-one` and `command-two` for the same account/character/game/frontend. Request the key for `command-one` through the production lookup; it resolves the entry whose command is `command-two`.

**Fix direction:** Return the exact saved key from the upsert operation or share the catalog's complete identity comparison. Avoid duplicating a weaker identity definition in the launcher. Also review whether the Manual Entry checkbox should set favorite true rather than toggle an existing favorite off.

### F7 — P2: Title fallback can apply a new window's settings to an existing window

**Layer:** #1648. **Code:** [window_presentation.rb:169](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/window_presentation.rb:169), [presented_window.rb:79](/C:/Gemstone/review-webui-pr-1648-1655/lib/webui/presented_window.rb:79).

Native presentation discovery falls back to a title-prefix search on its very first poll if the spawned PID has no window. With a shared Chromium profile, the process can hand off asynchronously. If one older window already matches the same page title and the new window has not appeared yet, that older window is the unique match and is adopted immediately.

Refusing multiple matches does not cover this ordering: there is only one match at discovery time. Presentation settings intended for the new window then change the old one; the new window is never discovered. The PID check in `adopt` compares the requested PID with the stored requested PID, not the actual ownership of the discovered HWND.

**Reproduction:** Run the real discovery/presentation orchestration with controlled finder results: new PID has no HWND yet; title search returns existing HWND 31. `PresentedWindow.open` immediately applies the new settings to 31. No actual desktop window is modified by the probe.

**Fix direction:** Use an identity unique to the particular browser window/open attempt. At minimum exclude preexisting candidates and resolve ambiguity after the newly opened page identifies itself. A reusable title prefix is not sufficient ownership evidence.

## Previous findings and implementation quality

The earlier fixes materially improve the stack. The explicit GTK launcher route, frontend submission extraction, port-specific cookie name, atomic dispatcher owner lookup, bounded socket writes including lock acquisition, table editing drafts, renderer signal behavior, catalog key derivation, and password change notifications all have concrete corrections in this checkout. I am not repeating the original versions of those findings as if they remained unchanged.

Four closure claims need qualification: cancellation is still incomplete (F2); modal close now resolves but races cleanup (F3); stale-event retention solves the earlier lost-replay case but lacks a bounded lifecycle (F5); and the native table hierarchy improvement is not wired through shim expansion state (F4).

The most consequential duplication is behavioral: catalog identity is defined more strongly than the launcher's lookup, and most asynchronous mutations use an arbiter while master-password mutation bypasses it. These should become shared operations with contracts that are difficult to omit. Adding more path-specific comments and isolated happy-path tests will not prevent the same omissions.

The services extraction and the shim's reuse of adapter traversal are useful reductions in structural duplication. The remaining release concern is integration across those boundaries: a client feature can pass its native fixture while the shim never emits the needed event, and a lifecycle fix can resolve a Future while invalidating another callback's input.

## Validation and limits

- Broad targeted Ruby run: **1,620 examples, 5 failures**, after excluding the one nondeterministic session-survival example that stalled the initial run. Completed in 47.37 seconds, seed 34436. Log: [audit-tests-completed.log](/C:/Gemstone/review-webui-pr-1648-1655/audit-tests-completed.log).
- The five failures match the earlier baseline's failures: three `GtkCompaction`/Ruby-Fiddle examples, Windows `SessionLauncher` path normalization, and the Windows custom-frontend launch representation expectation. The prior baseline ran 247 examples with those same five failures at `6dccc612`; log: [review-baseline.log](/C:/Gemstone/review-webui-d12/review-baseline.log). They are not attributed to this stack.
- The excluded example was rerun alone under a timeout wrapper: **1 example, 0 failures**, but it still printed uncaught worker exceptions. The deterministic barrier probe demonstrates the actual dead-worker/pending-sync failure. Log: [audit-hang-isolated.log](/C:/Gemstone/review-webui-pr-1648-1655/audit-hang-isolated.log).
- Actual client harness: **22 tests passed**. Log: [audit-client.log](/C:/Gemstone/review-webui-pr-1648-1655/audit-client.log).
- `git diff --check origin/main...HEAD` passed. The boundary checker exited successfully and printed its existing GTK-idiom inventory warnings; this is not a warning-free scan.
- Ruby reproductions: [current-probes.rb](/C:/Gemstone/review-webui-pr-1648-1655/review-artifacts/current-probes.rb), [results](/C:/Gemstone/review-webui-pr-1648-1655/review-artifacts/current-probes.json). Client reproductions: [review-probes.mjs](/C:/Gemstone/review-webui-pr-1648-1655/spec/webui_client/review-probes.mjs).

The probes use synthetic secrets, temporary catalog storage, and controlled collaborators around the real implementation. They do not establish cross-platform GUI acceptance or compatibility with every existing script. In particular, a green unit/client suite should not be taken as sufficient evidence for the default flip while F1–F7 remain unresolved.
