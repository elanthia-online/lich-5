# Review of the rebuilt WebUI branch chain

Reviewed September 17, 2026. **Recommendation: request changes; do not ship the default flip yet.** The layering and several repairs are substantial improvements, but the combined implementation still has launch, persistence, browser-session, and interaction defects. This review identifies **14 actionable findings: six P1 and eight P2**. P1 means resolve before making this the default; P2 means a concrete correctness defect to address in the affected layer.

This is a fresh review of the rebuild, not a republication of the earlier PR-stack findings. Production files were not edited. No reviews or comments were posted to GitHub.

**Snapshot and scope**

Several branches had advanced beyond the supplied table. These are the exact local tips reviewed:

| Layer | Branch | Reviewed tip |
| --- | --- | --- |
| Base | `webui/01-vendor` | `01d51c8e` |
| L1 | `webui/core-corrections` | `a1489a37` |
| L2 | `webui/wiring` | `b987ec46` |
| L3 | `webui/contract-primitives` | `0ec7af2f` |
| L4 | `webui/services-boundary` | `f8b4c57d` |
| L5 | `webui/launcher` | `aa826e3b` |
| L6a | `webui/shim-core` | `04bc6ad8` |
| L6b | `webui/shim-data` | `d9d31336` |
| L7 | `webui/default-flip` | `626294a9` |
| Separate | `fix/frontend-window-handle` | `6dccc612` |

The combined checkout is pinned at `626294a903302f82323c23cea0ce4860a93c4f55`, in `C:/Gemstone/review-webui-rebuild`. Its difference from the vendor branch spans 139 files, 31,687 additions and 1,811 deletions, including the generated contract. The contract is **2.19.0** and the client harness has **18 cases**, rather than the older numbers in the request. Source links below target that isolated checkout so they remain accurate if the working branch changes.

Review covered layer diffs, runtime/transport, actual client behavior, launcher workflows, authentication extraction, shim lifecycle/data handling, and the independent window-handle patch. Browser tests used a separate headless Chrome context; no user profile, credentials, or game session was used. The referenced `docs/webui-rebuild-plan.md` was absent from this snapshot, so its admission/support claims could not be verified as a checked-in release contract.

**P1 findings**

**R1 — L2/L7: `--gtk` does not open the fallback launcher.**

The parser records `launcher: :gtk` without setting `gui`. The GTK branch still requires `ARGV.empty?` or `@argv_options[:gui]`. With `lich.rbw --gtk`, neither is true, even though initialization loads GTK. This makes the advertised escape hatch fail to present the login window. `--gtk --gui` is a workaround, not the promised behavior.

Evidence: [GTK branch](/C:/Gemstone/review-webui-rebuild/lib/main/main.rb:211), [flag parsing](/C:/Gemstone/review-webui-rebuild/lib/main/argv_options.rb:83). The probe executes the actual parser and extracted production branch condition: `options={launcher: :gtk}`, `opens_gtk=false`.

Fix the entry-path predicate consistently for both launchers. Test startup dispatch for `--gtk` alone, `--webui` alone, persisted choices, and explicit headless options. The existing source-presence assertions do not exercise this routing.

**R2 — L5: Frontends Save uses the wrong submission interface.**

`frontend_fields_from` calls `Array(event.submission).map(&:to_s)`. A real runtime event contains a `WebUI::Submission`, which has `cids` and `fetch`, but no array conversion. The resulting first field is `"#<Lich::WebUI::Submission:...>"`; label, command and other fields become empty. Creating a valid custom frontend fails ID validation; editing an existing frontend cannot resolve the submitted ID correctly.

Evidence: [field extraction](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher.rb:1288), [Submission API](/C:/Gemstone/review-webui-rebuild/lib/webui/submission.rb:8). A real `Submission` carrying `myclient`, `My Client`, and `client.exe` reproduces the malformed fields. The [passing test](/C:/Gemstone/review-webui-rebuild/spec/lib/common/webui_launcher_redux_spec.rb:356) supplies an Array instead of the runtime object, concealing the defect.

Use the same CID-based extraction as the other launcher workflows. Add a real runtime submit/save/reload test using a temporary frontend configuration.

**R3 — L6a, inherited transport assumption: ordinary browser profiles make different Lich servers overwrite each other's authentication cookie.**

Every server writes `lich_webui=<its token>; Path=/` on `127.0.0.1`. Cookies are not isolated by port. Removing private profiles from shim windows means two game sessions share that cookie. Opening session B overwrites session A's cookie: A's existing socket may survive, but subsequent authenticated requests and reconnects fail. The five-second detach policy can then close A's script window.

Evidence: [cookie issuance](/C:/Gemstone/review-webui-rebuild/lib/webui/server.rb:332), [shared-profile shim launch](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/session.rb:816). **Real Chrome, two real production servers, one clean browser context:** opening A returned 200, opening B returned 200, reloading A returned **403**. A cookie-jar probe independently shows B's token being sent to A's port.

Isolate authentication per server instance while retaining the desired browser-process policy—for example, use a server-specific cookie name and matching authorization lookup. Verify two simultaneous Lich services, authenticated file loads, and reconnects in one browser profile.

**R4 — L5: cancellation still permits persistence, and launch acceptance is not atomic with close.**

Two distinct gaps remain in the same cancellation boundary. First, Add Account authenticates and calls `add_or_update_account` before `complete` checks whether the operation survived. Closing during authentication still saves the account when authentication returns. Encryption changes and generic mutations also perform work before their completion guard. Second, persistent saved launch calls `operation_live?`, releases the mutex, and then launches. Close can be accepted between those steps. Nonpersistent completion also releases its lock and refreshes before `terminal_launch`.

Evidence: [Add Account](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher.rb:881), [saved launch](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher.rb:1114), [live check](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher.rb:1169). A blocked authentication/close/release probe records a catalog save after close. A barrier immediately after the successful production live check records a child-launch request after close returns. All collaborators are synthetic; no real persistence or child process occurred.

Introduce a synchronized operation state transition that arbitrates cancellation versus committing side effects, and apply it across authentication, catalog writes and launch. Checking liveness before a side effect without claiming the commit does not settle the race. The earlier close-during-saved-authentication case is improved, but does not establish “cancellation on every path.”

**R5 — L1/L3: stale replay still loses ordinary clicks when a refresh arrives first.**

`acceptRender` deletes every outstanding record for that page unless a refusal has already marked it for replay. A legitimate ordering is: browser sends generation-1 click; an independently generated generation-2 render arrives; server receives and refuses the old click; server sends its refusal/render pair. The first render has already deleted the click. Reordering the refusal and its own corrective render cannot undo that earlier deletion. The stale refusal is then only logged to the console, so the action disappears without a visible failure.

Evidence: [pending record](/C:/Gemstone/review-webui-rebuild/lib/webui/assets/app.js:158), [deletion on render](/C:/Gemstone/review-webui-rebuild/lib/webui/assets/app.js:1773). The actual-client harness sends one click, delivers a newer render, then a refusal and corrective render: total sends remain **1**, meaning no recovery. Additionally, `(page,cid,event)` is not a unique request identifier: two submissions from the same button overwrite each other's records.

Correlate individual requests and acknowledgements; a render is not an acknowledgement of every in-flight action. Test the refresh-before-refusal ordering and two distinct submissions from the same terminal. Keep the existing replay limit and immutable submitted values.

**R6 — L6a: closing a MessageDialog window leaves its answer pending for an hour.**

`Session#modal` opens a coordinator page with a 3,600-second timeout. That page has no close/detach lifecycle handler resolving its Future. `open_modal_window` ignores its Future argument and supplies neither a process-exit callback nor the shim window lifecycle bindings. Closing the sole modal window therefore leaves `MessageDialog#run` waiting until timeout or script termination. Plain `Dialog` now has cancellation handling; that does not cover `MessageDialog`.

Evidence: [modal creation](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/session.rb:663), [modal window](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/session.rb:716), [coordinator page](/C:/Gemstone/review-webui-rebuild/lib/webui/modal_coordinator.rb:40). The probe opens a production modal, attaches through the runtime, and explicitly detaches at the delivered generation. Result: `resolved=false`, coordinator `pending=1`.

Resolve the Future on intentional closure and define the grace policy for transient disconnects. Verify both standalone message dialogs and dialogs hosted by another page, while keeping the repaired owner-shutdown cancellation.

**P2 findings**

**R7 — L6b: cell editing changes the model before GTK's handler can decide what to do.**

`TreeView#apply_event(:cell_edit)` assigns the submitted value, then emits both `edited` and `toggled`. A normal GTK toggle handler does `iter[column] = !iter[column]`; it now inverts the value that the shim just changed, returning the checkbox to its original state. Text edit handlers likewise cannot reject an edit without explicitly restoring a value GTK would not have changed yet.

Evidence: [premature mutation](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/widgets_data.rb:1611). A false model value, browser `true`, and conventional toggle handler finish with **false**. The installed [bsprofiles handler](/C:/Gemstone/lich-5/scripts/bsprofiles.lic:1108) uses exactly this inversion pattern; the full script was not run.

Emit the renderer-appropriate signal and let the script own the model mutation. Test toggle, accepted text edit, and rejected text edit through browser events.

**R8 — L4: “stable” saved-entry keys still alias different supported frontend configurations.**

The key hashes account, character and game, then distinguishes duplicates by enumeration ordinal. The catalog explicitly permits the same character/game with different frontends or custom launch commands, so these are legitimate entries. Removing the first of those entries moves the second onto the deleted entry's old key. A stale delete/edit/launch reference can target a different configuration.

Evidence: [key generation](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher/catalog.rb:397), [supported matching identity](/C:/Gemstone/review-webui-rebuild/lib/common/webui_launcher/catalog.rb:124). A temporary catalog with StormFront and Wizard entries for the same character gives `entry-<digest>` and `entry-<digest>-2`. After removing StormFront, its old key resolves to **Wizard**.

Use persistent entry IDs or a complete identity plus explicit conflict handling. The fix does stabilize unrelated characters, but its duplicate case still has the original class of failure.

**R9 — L1: a concurrent enqueue can revive an owner after shutdown.**

The terminated-owner check and `owner_state(owner)` acquisition use separate critical sections. Shutdown can mark the owner terminal and remove its state between them; `owner_state` then creates a new running worker without checking the tombstone. The comment claiming the shared mutex prevents revival is incorrect because the mutex is released between the two operations.

Evidence: [enqueue check](/C:/Gemstone/review-webui-rebuild/lib/webui/dispatcher.rb:53), [state creation](/C:/Gemstone/review-webui-rebuild/lib/webui/dispatcher.rb:115). A deterministic barrier between these methods, followed by shutdown and resume, executes the supposedly refused callback.

Check termination and acquire/create the state atomically; preserve the state-level running check for shutdown racing an already acquired state. Add this concurrent case beside the existing sequential late-enqueue test.

**R10 — L3: table editor drafts and focus are discarded on refresh.**

`editorCell` creates inputs but never registers them in `page.controls`, which is the only set `captureEditing` traverses. Typing into a cell without committing, then receiving an unrelated render, replaces the input with the old model value. Selection changes and other script activity make such renders normal. The text/number/password draft fixes do not cover these editors.

Evidence: [cell editor](/C:/Gemstone/review-webui-rebuild/lib/webui/assets/app.js:208), [capture loop](/C:/Gemstone/review-webui-rebuild/lib/webui/assets/app.js:1676). Actual-client probe: `old` → type `unfinished` → unchanged newer render → **`old`**.

Track editor state using table CID, row key and column key, with server-base conflict handling, or preserve the editor DOM across compatible renders. Test focus, caret, cancellation and intentional model updates.

**R11 — L6b: Builder never applies CellRenderer properties.**

`CellRenderer#apply_builder_property` requires `!respond_to?(:method_missing)`. The class publicly defines `method_missing`, so that condition is always false. Declared setters such as `editable=` and `activatable=` are skipped without applying the XML property. An editable Glade text column remains read-only; a toggle explicitly disabled in XML retains its default behavior.

Evidence: [guard](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/widgets_data.rb:1212). Calling the production property path with `editable=True` leaves `editable=false`, `editor=nil`.

Check for an actually defined setter rather than the existence of `method_missing`. Add Builder fixtures exercising true and false properties on text and toggle renderers.

**R12 — L1: D2 bounds individual writable waits, not the write operation.**

`write_within_timeout` passes the full timeout to every `IO.select`; it never tracks an overall deadline. A slow reader making periodic progress can keep a large synchronous render write alive far longer than `WRITE_TIMEOUT`, holding the session thread and page lock. Waiting to acquire `@write_mutex` is also outside the timeout. This is a useful stall improvement, but not the stated bounded-write guarantee.

Evidence: [write loop](/C:/Gemstone/review-webui-rebuild/lib/webui/server.rb:200). A controlled partial-write fixture with a 20-ms configured timeout, each writable wait shorter than that timeout, completed successfully after approximately **249 ms**, still marked alive. This is a synthetic deadline test, not a measured browser workload.

Use one monotonic deadline for the operation and pass only its remaining budget to waits; define the concurrency policy for lock acquisition. Test a reader that drains slowly as well as one that never drains.

**R13 — L3/L6a: the shim still suppresses password `changed` after the contract adds it.**

Contract 2.18+ and the browser support a password `change` event with no plaintext payload. `Entry#event_for(:changed)` nevertheless logs that this event does not exist and returns nil, while `always_bound_events` excludes it. Script handlers are never notified. The implementation and its explanation are still based on the older contract.

Evidence: [password signal suppression](/C:/Gemstone/review-webui-rebuild/lib/common/script_scope/gtk/widgets.rb:2821). Probe: `contract_declares_change=true`, `shim_event=nil`.

Bind the no-value notification and document its semantics accurately. Do not put plaintext into ordinary change messages to make old handlers appear compatible. Handlers that require the current password contents need an explicit supported policy; a notification alone does not implement a server-side strength calculation.

**R14 — L3/L6b: tree rows are still rendered as a flat list, ignoring expansion.**

The contract carries `parent`, `expanded`, and `row_toggle`, and the shim admits TreeStore. The browser loops over every row as an ordinary sibling, never interpreting parent/expanded or offering a toggle. A collapsed parent still displays its descendants, and no expansion gesture can reach the runtime. This contradicts the “whole client” claim even though ordinary table selection, editing controls, sorting gestures and activation are present.

Evidence: [unconditional row loop](/C:/Gemstone/review-webui-rebuild/lib/webui/assets/app.js:1009), [tree contract](/C:/Gemstone/review-webui-rebuild/lib/webui/contract.rb:505). Actual-client fixture with a collapsed parent and one child renders **two rows, zero expansion controls**.

Render the visible hierarchy with indentation and expansion controls, and emit `row_toggle`; also align the shim's expand/collapse methods with it. If trees are deliberately excluded, narrow the admission policy and report that degradation rather than treating TreeStore as fully supported.

**Architecture, duplication and remaining support limits**

The authentication extraction is mostly a real boundary improvement. Compatibility constants in `lib/common/gui` alias the moved modules rather than maintaining independent copies of their implementations. The heap-compaction strategy and the adapter's three extension hooks also reduce coupling and duplicated traversal. These are worth retaining.

The frontend boundary is not fully shared. `FrontendEditor` says both launchers call it, but [GTK's save path](/C:/Gemstone/review-webui-rebuild/lib/common/gui/frontend_manager_tab.rb:391) still implements its own validation, document edits and persistence flow. `FrontendChoices` explicitly acknowledges another copy in `GUI::FrontendSelector`. More significantly, `WebUILauncher::Catalog` still duplicates account/character mutation rules now housed in `Authentication::AccountManager`. Moving the files does not give both UIs one mutation service. Either finish that consolidation or describe this accurately as temporary duplication with parity tests; do not claim the shared rules are already authoritative.

The GTK boundary checker works as its comments describe, but is a **warning**, not a gate: the review run exited successfully while identifying 13 core files with GTK references. It is useful inventory, not proof of a GTK-free core. The initial entry point still installs the GTK compaction guard. This is consistent with staged migration, provided that is the stated claim.

Several intentional limitations matter more once L7 changes the default:

- Images, drawing areas, layouts and menus are deliberately excluded from the shim. Their native replacement scripts and a versioned acceptance manifest are not delivered by this branch chain. No live supported-script acceptance was established here.
- Clearing a ComboBox selection explicitly remains unrepresentable by the current select/overlay contract; the code acknowledges that an existing viewer can retain the old selection.
- A child rejected in `Container#materialize!` is still omitted from positional layout. Tooltip clamping repairs the previously observed trigger, and logging is better, but another schema rejection can still shift subsequent grid cells. Preserve a placeholder or use explicit placement if continued partial rendering is the policy.
- The Windows presentation support table claims capabilities based on host availability, while shared-profile Chromium may hand the launcher a process ID that owns no window. Failed discovery does not make those capabilities false for the affected page. The ledger should report the actual failure, not merely platform-level support.
- Session batching moves `commit` outside the per-job exception rescue. The existing “survives a script error raised during commit” test printed an uncaught worker exception while passing: a later `sync` can start another worker. Pin thread identity and queued-work survival if that test is intended to prove the worker survives. This is an observed test weakness, not counted as an additional release blocker above.

**What improved since the previous stack review**

The current implementation includes real repairs for the attach/refresh ordering race, selection cursors mutating model row identities, TreeStore ancestor/sibling traversal, dropdown option/update ordering, password submission transfer across the dispatcher/session hop, pending dialog cancellation on owner shutdown, repeated attachment on page broadcasts, and removed-widget bookkeeping. Text, number and password draft preservation and the real-client harness are also improvements.

The distinctions matter: password submission now has a transport bridge, but password change notification is still suppressed; ordinary Dialog shutdown is repaired, but MessageDialog window closure is not; a sequential late enqueue is refused, but a concurrent one can revive its owner; different controls' retries are correlated, but renders still erase in-flight requests. The remaining findings target those gaps, not the repaired cases.

**Independent D12 branch**

`fix/frontend-window-handle` at `6dccc61217ecc40125fb6175a9adf1224659de3e` is a narrow, reasonable change. It removes the undersized native-long packing round trip, uses pointer-sized arguments in the modified EnumWindows path, and handles the no-match case without reading an uninitialized handle buffer. **No new blocking finding in this patch.** Its frontend suite passed **180 examples, zero failures**, including synthetic wide-handle and no-match cases. This does not claim live focus acceptance against every frontend or a 32-bit Windows environment.

**Validation and reproducibility**

| Check | Result |
| --- | --- |
| Runtime, client, shim, launcher, catalog, choice, frontend services, startup flags, boundary and session-launcher specs | 689 examples, 1 pre-existing Windows failure |
| Authentication, GUI compatibility, CLI orchestration, compaction, memory and combat specs | 863 examples, 4 pre-existing platform failures |
| Actual-client jsdom harness | 18 passed |
| Independent D12 frontend suite | 180 passed |
| Changed Ruby files, RuboCop | 119 files, no offenses |
| Diff whitespace check | Clean |
| Real Chrome with two real WebUI servers | Cookie collision reproduced: 200, 200, then 403 |
| Targeted Ruby and actual-client probes | Reproductions described in R1–R14 |

The five failures from the two main Ruby runs were all reproduced on the separate main-based D12 checkout: the existing `/tmp` versus `C:/tmp` expectation, a custom-launch serialization expectation, and three GtkCompaction cases depending on a Ruby C symbol unavailable to this Windows runtime. They are not attributed to the rebuild. The main review total is **1,552 examples, 5 baseline failures**, not an entirely green suite. The 180 D12 examples are reported separately.

Evidence is retained in the isolated checkout:

- [Core probes](/C:/Gemstone/review-webui-rebuild/review-artifacts/probes.rb) and [results](/C:/Gemstone/review-webui-rebuild/review-artifacts/probes-output.txt): frontend submission, GTK routing, dispatcher race, toggle semantics, Builder properties and password mapping.
- [Lifecycle/catalog probes](/C:/Gemstone/review-webui-rebuild/review-artifacts/lifecycle-probes.rb) and [results](/C:/Gemstone/review-webui-rebuild/review-artifacts/lifecycle-output.txt): cancellation, launch race, duplicate entry keys and modal closure.
- [Actual-client probes](/C:/Gemstone/review-webui-rebuild/spec/webui_client/review-probes.mjs) and [results](/C:/Gemstone/review-webui-rebuild/review-artifacts/client-output.txt): replay ordering, editor drafts and collapsed trees.
- [Real server fixture](/C:/Gemstone/review-webui-rebuild/review-artifacts/cookie-servers.rb) and [Chrome probe](/C:/Gemstone/review-webui-rebuild/review-artifacts/cookie-browser.cjs): shared-cookie collision.
- [Write-budget probe](/C:/Gemstone/review-webui-rebuild/review-artifacts/write-probe.rb).
- [Primary Ruby log](/C:/Gemstone/review-webui-rebuild/review-tests.log), [authentication/compatibility log](/C:/Gemstone/review-webui-rebuild/review-auth-tests.log), [lint log](/C:/Gemstone/review-webui-rebuild/review-lint.log), and [baseline failure reproduction](/C:/Gemstone/review-webui-d12/review-baseline.log).

Run the Ruby probes with `bundle exec ruby review-artifacts/<name>.rb` from the isolated checkout; run the client probe with `node spec/webui_client/review-probes.mjs` after `npm ci` in its harness directory. Chrome probes use the installed Chrome and the retained Playwright dependency from the earlier isolated review. Cookie-server URLs contain only ephemeral local test tokens and must be regenerated for another run.

These checks do not establish live-game acceptance, macOS/Linux browser behavior, clean-install dependency removal, or merge compatibility with every newer main change. Fix the P1 paths and their integration tests before promoting L7; then exercise the declared supported scripts through open, edit, save, reopen, disconnect and close on the intended platforms.
