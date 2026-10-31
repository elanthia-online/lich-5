# Genie engine -- open items

What is still open in the Genie `.cmd` engine (`lib/genie/`), and the decided differences from
Genie that should not be "fixed". The parity target is Genie4 Remix v4.2.4; `R` after a file and
line (`Game.cs:545 R`) cites the Remix source.

None of the items below is a known wrong run of a real script: every script in the test corpus
behaves as it does in Remix, and every flow-oracle case matches except the four decided ones
listed under "Decided divergences". Each item says why it is open. Item ids (U1, K7, ...) are
stable, so code comments and issues can cite them.

Checks a maintainer can run from the repo:

- `bundle exec rspec spec/lib/genie/` (also with `TZ=UTC`, as CI runs; the specs that read the
  clock pin their own time zone);
- `bundle exec rubocop lib/genie/ spec/lib/genie/`.

`spec/lib/genie/flow_parity_spec.rb` replays frozen Remix results ("goldens") recorded by a
headless build of Remix's own script code. A difference fails the spec; the four accepted
differences are `pending`, so a change that makes one match also fails until its entry is removed.

## Decisions (D1-D10)

- **D1 Persistence works like Remix.** Variables live in memory and reach `variables.cfg` only on
  `#var save`; `variables.cfg` and `triggers.cfg` load at engine start. The engine has its own
  config folder (`GenieProfiles/Config`), not native Genie's.
- **D2 No loop guard on sends.** Remix has none. Only a loop that runs 5 seconds without waiting is
  stopped.
- **D3 Nested dispatch stops at depth 20.** A `#trigger`, `#parse` or variable-change action that
  keeps setting itself off ends with a script error after 20 nested rounds (Remix crashes).
- **D4 JavaScript array helpers fail where Remix's JavaScript engine fails.**
- **D5 Remix's timing races are not copied.** Where Remix's result depends on thread timing, the
  engine picks the deterministic order.
- **D6 `$scriptdir` and friends name this engine's folders,** not native Genie's.
- **D7 Two kinds of pause.** Genie's `#script pause` drops the game text that arrives while paused,
  as Genie does. A Lich pause (`;pause`, or another Lich script pausing all scripts) freezes the
  script and keeps its input for after the unpause, so a waiting script does not miss the reply it
  waits for.
- **D8 `#goto <n>` resolves the room by the current map.** In a room that carries a Genie zone
  stamp, `<n>` is only that zone's Genie node. In an unstamped room it is tried as a Lich room id,
  then as a game room id.
- **D9 No third-party JavaScript in the repo.** The community `js_arrays.js` (GPLv3) and similar
  sources are not committed; the engine keeps only fingerprints and its own replays, and the flow
  cases that need those files skip without them.
- **D10 Lich commands only from author-written text.** A send starting with `,` or `;` reaches
  Lich's command path only when that character was written by the script author, not produced by
  a variable or a capture. The commands that run code (`,e` and its variants, `,lich5-update`)
  additionally need a literal `put` row with nothing to expand. See K7.

## U -- needs a maintainer or user decision

- **U1 Regex character classes.** In .NET (Remix) `\w`, `\d` and `\s` match Unicode letters,
  digits and spaces; in Ruby they match ASCII only. Ruby also has POSIX classes such as
  `[[:alpha:]]` that .NET lacks. Pattern validity already follows .NET. DR text is ASCII, so no
  script is affected. Decide: keep Ruby's classes, or rewrite patterns to the .NET meaning.
- **U2 The 400-item input buffer.** A paused or roundtime-held script keeps its last 400 input
  items (D7). A long roundtime with many watched variables can push lines out of it. Raising the
  limit or merging variable-change items needs a decision.
- **U3 Match timeouts for script patterns.** `#trigger`, gag and substitute patterns time out after
  1 second. Script patterns (`action`, `matchre`, `waitforre`) and emulated `#trigger` patterns do
  not: a catastrophic pattern blocks only its own script (or delays the trigger worker). A timeout
  needs a decision on what a timed-out match does to the script.
- **U4 Third-party `.cmd` excerpts in the spec fixtures.** Some flow fixtures under
  `spec/fixtures/genie/` quote short excerpts of community scripts, and one golden quotes one line
  of a community script's output. Decide: keep them, or move them out of the repo like D9 (their
  cases would then skip).
- **U5 Genie map data.** The Lich map has no Genie notes or Genie zone maps, so `#goto <note name>`
  is never found, `#path`, `#mapper reset` and `#map` do nothing, and a zone with no Genie map shows
  Lich's zone id. Decide: import the Genie map and notes data (from where?), or keep these as
  documented no-ops.
- **U6 A typed `/` command still reaches the game.** Remix never sends text that starts with its
  command character `/`. The engine holds back every `/` text a script sends, but what the user
  types goes through Lich's input path (L8). The engine's input hook could swallow typed `/` lines;
  that would change what a Lich user's own input does while the engine is loaded.

## F -- needs a game fact (answer from a game log, not by assumption)

- **F1 Substitutes across a bold run.** Remix substitutes on the whole row; this engine substitutes
  per text run between tags, so a substitute whose match spans an inline `<pushBold/>` applies in
  Remix only. Does DR send such rows where a substitute would target them?
- **F2 Talk lines in the main stream.** Does DR also send the talk and whisper family into the main
  stream, and does it send main-window rows while another stream is open? Remix's client behaviour
  is ported either way; the answer only tells whether a difference can be seen.

## T -- needs a tester

- **T1 Saved "triggers loaded" flags from engines before 0.12.** Those engines saved every `#var`
  at once but never saved triggers, so a saved flag can say the triggers are loaded while no
  `triggers.cfg` exists. The fix is a one-time reset of the flag (user-guide section 7,
  PROTOTYPE-TESTING section 2). The engine does not migrate it silently (Genie would not). Close
  when a tester confirms the reset holds over a few sessions.
- **T2 Scripts beyond combat.** Live runs cover combat, crafting and public scripts. Travel and
  errand scripts (hand-offs to Lich's `go2`, bank trips, room-title matches) are untested live.
- **T3 A native Genie capture (optional).** A log of a native Genie session, replayed through the
  flow oracle, would add live ground truth. The flow oracle already runs Remix's own script code,
  so this is a nice to have.

## L -- needs a Lich core change (outside `lib/genie`)

- **L1 No JavaScript engine.** JavaScript beyond the recognised `js_arrays.js` functions and
  `<% %>` blocks is reported as unsupported. A real engine needs a new gem.
- **L2 Lines a genie script can miss.** A line a `.lic` DownstreamHook pushes with `send_scripts`
  does not reach genie scripts, and a game-state feed error loses that row. A fix needs a marker on
  such pushes in Lich core.
- **L3 Lich edits rows before the engine sees them.** `<settings>` and desync rows never arrive; a
  bare CR or BEL is not split as Remix splits it; Lich's cleaners rewrite some rows; Lich strips the
  room number from the subtitle (`$uid`).
- **L4 The prompt is the only packet boundary.** Lich delivers rows one at a time with no packet
  edge (see interpreter-spec.md, "Lich delivery facts"). With several prompts in one packet the
  engine ends the packet at each prompt, Remix at the packet's end. A typed command can wait behind
  the trigger worker's backlog.
- **L5 `DRCT.walk_to` limits for `#goto`.** Its flag names are global (two walks at once can delete
  each other's flags); a walk cannot be paused; a `#goto` from a `#trigger` body during a walk runs
  on the walk's thread.
- **L6 Receive time per buffered row.** Rows replayed at engine start stamp `$spellstarttime` with
  the replay time, so a script started mid-cast reads a short `$spelltime` until the next spell row.
- **L7 Map-loaded line re-entrancy.** A `#trigger` on Lich's "--- Map loaded" line that reads
  `$roomid` would re-enter the map's load lock and fail as a trigger error.
- **L8 Typed input belongs to Lich.** What the user types does not go through the engine's command
  parser (`-2 look`, `a;b`, `\;` are handled by Lich); a typed `#...` sets `$lastinput` here, where
  Remix treats it as a client command.
- **L9 `$useridle` and `$connected`.** Lich has no idle timer or disconnect event for the engine to
  read. Porting Remix's idle timer would send `usertimeoutcommand` (default `quit`), unsafe for AFK
  scripts, so the engine behaves as `usertimeout 0`.
- **L9b `servertimeout`.** Remix sends `servertimeoutcommand` (default `fatigue`) after
  `servertimeout` seconds without server data, then reconnects or disconnects. Not ported: the
  connection belongs to Lich, and a client-side send no script asked for would be new behaviour.
- **L10 Lich-level script effects.** A genie script runs beside a `.lic` of the same name, and
  `;kill x` hits whichever Lich finds first. Start and normal-stop lines are Lich's (`--- Lich: x has
  exited.`), which `^--- Lich:` watchers can match; Remix prints `[Script finished ...]`, which no
  script sees. An abort prints Remix's `[Script aborted! ...]`. Kept on purpose and documented in
  the user guide.
- **L11 The run path under a live Lich.** The command queue start and the downstream hook install
  are only exercised end to end; the worker logic they use is spec'd.
- **L12 Flaky specs outside the engine.** `account_manager_spec` and `gui_login_spec` share a fixed
  `/tmp/test_data`; `master_password_change_spec` names a temp folder per second;
  `inventory_spec:975` has a 0.2 s deadline; `reusable_tcp_server` (EADDRNOTAVAIL) and
  `stream_replay` ("probe ready") look flaky too. They belong in a separate PR.

## K -- decided divergences (kept on purpose)

- **K1 Decisions.** D2-D9 above. Also: an evaluator error prints a Genie-style error line and stops
  the script; a `#trigger`, gag or substitute is switched off after 3 match timeouts in a row; a
  failing `#trigger` action prints `--- Lich: genie trigger error: <message>` (Remix stays silent).
  Accepted flow cases: t39 and t51 (D3), t43 (D6), t49 (D5).
- **K2 Timing (D5):** trigger-worker lag; the end of a run on any thread ends the tick; a script
  launched by the host is listed at the end of its first run; `#script resume` resumes on the
  script's own thread; launch order can flip when a first run is busy; a TCP split longer than
  10 ms resumes a wait mid-packet.
- **K3 Remix crashes and hangs are not copied.** An invalid `math` with no `scripterror` label, an
  action `goto` to a missing label, alias self-recursion, `count(x, "")`, `exit` inside an eval
  action, an action `exit` after a script error, a `#log` write failure, an action list changed or
  a script aborted mid-pass, an error in the command queue's next-time calculation, and very
  deeply nested parentheses in any expression (`math`, `evalmath`, `eval`, `if`) end cleanly here (a script
  error, or one echoed error line) where Remix overflows its stack, loops forever or dies.
- **K4 Approximations.** `$prompt` rewriting; some merged Game.cs conditions; `#unvar` of a
  reserved name; a parse exception inside an XML buffer does not freeze the parser; the start-up
  replay of the last 400 rows; SpellTimer details; `$account` is empty; `#config load|save` does
  not touch the capture. Reserved names are never saved to or loaded from `variables.cfg` (Remix
  writes some of them on any `#var save`). A display-time `$roomid`/`$zoneid` is the last room
  update's value; a reader can see a row half applied while it is displayed; Lich's own echo lines
  are not run through Remix's row parser.
- **K5 Front-end-only commands are hooks or echoes.** `#config` alone, `#ls`/`#lichsettings`, `#lc`
  with a profile, `#config save|load` (echo only; `settings.cfg` is neither rewritten nor re-read),
  `#script trace|vars|list|explorer`, the `#preset`/`#highlight`/`#macro`/`#name` listings, `#edit`,
  `#help`, `#svar <stgupd>` and `#raw` (not sent), `#cr`, profile loading, echo colours, and
  `#save profile` (echo only). See hook-protocol.md.
- **K6 One `variables.cfg` for every character.** Remix loads a per-profile `variables.cfg`. This
  engine has one `GenieProfiles/Config/variables.cfg` (and `triggers.cfg`) per scripts folder, so
  two characters' whole-file saves are last-writer-wins. Warned in the user guide. Per-character
  files need Lich's character identity in the config path: a design change.
- **K7 Lich commands only from author-written text (D10).** Genie running in front of Lich forwards
  any send that starts with `,` or `;` to Lich, so a whisper relayed by `action put $1` could run
  Ruby through `,e`. Two layers (`lib/genie/authored_command.rb`):
  - *Provenance.* A send reaches Lich's command path only when its leading `,`/`;` was written by
    the author: in a `.cmd` `put`/`send` row before any variable or capture is expanded, or in the
    body of a `#trigger`, alias or action whose definition was itself authored. That is decided when
    the definition is made: rows loaded from `triggers.cfg`/`aliases.cfg` (unless their side file
    lists them, below), `#trigger`/`#alias` from a literal `put` row or an authored trigger body no
    capture changed, and `action` rows of a `.cmd` file count as authored; definitions built from
    captures, expanded rows, queued releases, JavaScript or typed input do not.
  - *Code commands.* `,e`, `,eq`, `,exec`, `,execq`, `,execname`, `,en` (Ruby) and
    `,lich5-update`/`,l5u` (installs Lich code) run only from a literal `.cmd` `put` row with nothing
    to expand. From a `send` row, any trigger/alias/action body, `#send`/`#put`/`#if` or JavaScript
    they go to the game as text.
  - *Command name.* The name after an authored `,`/`;` (up to the first white space) must be
    literal: a `$`, `%` or `@` in it (`put ,%cmd`, `action put ,$1 when ...`, `{,$1}`) sends the row
    to the game as text, whether or not the variable exists (0 corpus rows; 18 with variables only
    in the arguments, which stay Lich commands).
  - *Saved provenance (closed).* Decided: `#trigger save`/`#alias save` list the definitions that are
    not authored in `triggers.cfg.untrusted`/`aliases.cfg.untrusted` (written atomically before the
    cfg, which stays Remix's bytes); a load reads listed rows as not authored, other rows (hand
    edits too) as authored, and every row as not authored, with one notice, when the side file is
    unreadable.
- **K8 Engine off means everything off, at once.** `Lich::Genie.enabled = false` closes the
  game-state feed, passes every display and typed line through untouched, skips the script-output
  feed and trigger-on-input, runs no `#trigger` body, and drops queued commands. A `.cmd` still
  running gets no game text and its sends are dropped, with one notice per script. Turning the
  engine back on replays only the rows Lich parsed while it was off, so no row is applied twice.
  The gate (`Lich::Genie.engine_active?`) is a cached read after login.
- **K9 `<genieHook>` tags are opt-in.** `Lich::Genie.hooks_enabled` is off by default per character,
  because no shipped front end reads the tags and a Wizard front end would show them as text. Off,
  `#echo >window` and `#link` text go through `Lich::Messaging.stream_window`, input-box text is
  echoed, and the other hook ops do nothing (hook-protocol.md, "Opt-in").

## Q -- known Remix quirks not copied (no script in the corpus uses them)

- **Q1 JavaScript array helpers.** Constructs Remix runs or reports (template literals, `a++ / 2`,
  top-level `var` in an included `.js`, block-scoped functions, BigInt, member access, regex
  literals, ...) are announced as unsupported here. Always announced, never a wrong result.
- **Q2 Culture-sensitive string comparisons.** Remix's .NET comparisons (StartsWith, IndexOf,
  sorted lists) skip default-ignorable characters such as soft hyphens and zero-width spaces; this
  engine compares ordinally. DR text carries none.
- **Q3 Regex dialect rest.** Some .NET constructs are still refused (`\p{Is<Block>}`, octal escapes,
  a forward `\k<n>`, a numbered back-reference to a named group, repeat counts above 100000, `(?x)`
  comments, class subtraction, duplicate group names, `(?n)`). Group numbering, empty-loop captures,
  lookbehind captures in `replacere`, `\G` in emulated patterns and UTF-16 surrogate splits can
  differ. Eval's `matchre()` treats `^`/`$` as multiline (moot: a Genie value cannot hold a newline).
  Groups nested more than 256 deep never fire (one warning line) where Genie takes any depth: Onigmo
  would overflow a script thread's stack. js_arrays `buildArrayStr` skips its regex check for them,
  as Jint accepts them. The corpus nests 6 deep at most.
- **Q4 Load path details.** Dates parse only the listed .NET formats; an include name over 255
  bytes is "File not found".
- **Q5 Script lifecycle.** `#script reload` restarts with the launch arguments (Remix reloads at
  the next label); `#script` matches the launch name, not a reassigned `%scriptname`; `\` launch
  paths; the script extension is fixed at `cmd`; `#script reload all except x`; pausing a finished
  script; a ready `pause 0` does not end the run; `#script` from a `#trigger` body updates
  `$scriptlist` at once; a script that pauses itself mid-chain finishes its remaining rows.
- **Q6 Wait and buffer model.** An input-line match holds every wait state until the packet ends
  (Remix gates only `waitfor`/`matchwait`/`waitdo`); another script receives a `#parse` text at its
  next wait; prompt-row ordering; closed-window text goes to main in Remix's default layout;
  `parsegameonly` is not modelled.
- **Q7 Variable-change dispatch.** Remix raises each change mid-row, this engine after the row.
  Also: a fault in a listed change, an eval action on `%lastlabel`, eval `#trigger` order, the
  interleaving of several scripts, `action remove` of an eval action mid-pass, EXP tracker
  variables raising no change, server `<vars>` not captured, and a `#trigger` body's dispatch
  carrying the trigger as its origin.
- **Q8 Changing the trigger list from a trigger action** (`#trigger load|clear|add`, `#untrigger`)
  fails in Remix and works here. `#class x on|off` from a trigger body is not a list change and
  behaves the same in both (flow t254).
- **Q9 Command queue.** A literal U+00A4 in a sent text; a self-requeueing `delay 0` chain loops on
  the worker (Remix hangs its UI); Remix's 250 ms lock-wait error; a blank line in the `#queue`
  listing; the year-9999 bound uses local time.
- **Q10 `#trigger` details.** An unsupported pattern is re-warned on every command touching it; a
  substituted run re-encodes `&`.
- **Q11 Send order for a trigger on typed input.** An eval `#trigger` on `$lastinput` sends before
  the typed command in Remix and after it here. Fixing it needs the glue to hold the typed send
  behind the trigger dispatch.

## G -- test oracle limits (no effect on players)

- **G1 Flow oracle gaps.** Display verbs print nothing headless (they are covered by router specs);
  plugins are identity; no automapper plugin (`#goto` has its own specs); `#script list|vars|trace`
  output is not modelled; `@unixtime@` reads the wall clock; the client glue is a transcription.
- **G2 .NET 10 regex bugs.** Synthetic fuzzing finds a few patterns where .NET 10 itself is wrong
  (for example `(?:b{1,2}|){2}` not matching ""). No corpus pattern has these shapes; not emulated.
- **G3 Harness details.** The first tick after a launch is 10 ms here and 20 ms in the oracle; the
  queue clock is exact where .NET rounds to ticks; an accepted pending case passes on any
  difference; engine echoes are classified by their text.
- **G4** Two eval rows the oracle marks unsupported are recorded as such.
- **G5 Corpus sweep coverage.** The corpus sweep checks every script's outcome against one trace,
  not which rows ran. Script flow is gated by the flow oracle; a per-row coverage report would need
  a tracer.

## H -- optional engineering (developer-only paths)

- **H1** Reloading one engine file with `;hmr` (`game_state.rb`, `triggers.rb`, `class_list.rb`,
  `alias_list.rb`, `stream_filters.rb`) leaves existing objects without their mutexes; restart the
  engine after such a reload.
- **H2** A timed wait resumes 10 ms after entry, not at Remix's next tick boundary.
- **H3** `Lich::Genie.config_dir=` resets the store, but the cached trigger runner keeps the old
  one; `reset_global_store!` is unsynchronized and unused; `stream_filters` is an unguarded memo.
- **H4** Ruby warns "regular expression has ']' without escape" on stderr for a `#trigger` pattern
  such as `p]i` (valid in both dialects), twice. Cosmetic.
