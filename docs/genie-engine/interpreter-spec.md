# Genie Script Interpreter — Ruby Port Spec

Behaviour spec for the clean-room Ruby port (`lib/genie/lexer.rb`, `interpreter.rb`,
`parse_command.rb`, `command_queue.rb`, glue `genie_script.rb`). **Parity target: Genie4 Remix
v4.2.4.** Line numbers marked **R** are Remix `Script/Script.cs` unless another file is named
(`Utility/Utility.cs`, `Lists/Config.cs`, `Core/Command.cs`, `Forms/FormMain.cs` ...). The spec was
first extracted from upstream Genie4 4.5.0.3 (context only); where this text and the code (or
Remix) disagree, the code and Remix win. The code's doc comments cite Remix per method.

> **Two fidelity caveats up front:**
> 1. **`while` has NO back-edge.** The `evalwhile*` block states are set but never consumed
>    to jump backward. Genie's `while` is a one-shot `if`-style guard; real loops are
>    label+`goto`. Do **not** synthesize a loop back-edge.
> 2. Several verbs (`if`/`while`/`else`/`waiteval`/`timer`/`debuglevel`/`js`/`jscall`/`plugin`/
>    `action`) read the **raw** `sRowContent`, not the variable-substituted `ParsedLine`.
>    Replicate per-verb (see verb table).

---

## 0. Core data structures

- **`ScriptLine`** {`iFileId`, `iFileRow` (1-based), `sRowContent`, `oFunction:ScriptFunctions`}.
  The whole program is `m_oScript` = flat ordered array; the PC is an index `I` into it.
  Ours: `Lexer::Instruction` / `Lexer::Program`.
- **`Line`** = one call-stack frame: `iIndex` (PC / return address), `bSkipBlock`, `iBlockDepth`
  (`TargetBlockDepthValue`), `oBlockList` (block-state stack), `oArgList` (`$0..$n`),
  `bLastRowWasEvaluation` (single-line `if…then <cmd>` marker). Ours: `CallStack`.
- **`CurrentLine`** = the call stack (`oLineList`). **Index 0 = base/main frame; last = active.**
  All accessors operate on the **top** frame: `LineValue` (PC get/set), `AddJump`/`RemoveJump`
  (push/pop; never pops base), `AddBlock`/`RemoveBlock`/`BlockValue`/`BlockCount`, `ArgList`,
  `SkipBlock`, `TargetBlockDepthValue`, `LastRowWasEvaluation`, `Clear` (wipe stack),
  `ClearBlocks` (clear active frame's block list only).
- **`BlockState`** (48 R): `noeval, evaltrue, evalfalse, evalwhiletrue, evalwhilefalse`.
- **`ScriptState`** (607 R): `finished, running, pausing, delayed, wait, waitfor, waitdo, waiteval,
  move, matchwait, actionwait, actioninstant, scripterror` (`waitdo` is never entered in Remix:
  not ported).
- Storage: `m_oScriptLabels` (label→index, lowercased), `m_oLocalVarList` (`%`-vars, SortedList,
  **case-sensitive keys**), `m_oActions`, `MatchList`.
- Concurrency: Remix's public entry points take `Monitor.TryEnter(m_oThreadLock, ...)`; TriggerParse
  waits at most `Config.iScriptMatchTimeout` (100 ms, Config.cs:28 R) and otherwise drops the line.

> **Threading in the Lich port.** Remix ticks every script every 10 ms on its timer thread. Ours runs
> each script on its own Lich script thread: `Interpreter#run_rows` runs rows until a wait verb, then
> `Interpreter#await_resume` blocks on the input port (game lines, `#parse` texts, variable-change
> batches and `GameEvents`) and fires the script's actions as items arrive. Global `#trigger`s run on
> one engine thread (`TriggerWorker`) before the scripts get the line. The 100 ms drop is not
> emulated (D5).

---

## 1. Control flow

**Main loop `RunScript(iArrayIndex=-1)`** (1707 R): start at `LineValue` if arg is -1; loop
`for I = start; I <= Count; I++`. Each iteration first writes `LineValue = I` (so gosub/return/
reload see the PC). Break if state≠running or paused. If `I >= Count`: finish. Else fetch
`m_oScript[I]`, do block bookkeeping for `{`/`}` (§2), then if `!SkipBlock`:
`I = RunScriptRow(oLine, I)` (2436 R; return value becomes new `I`; loop `I++` advances). If an
action set `m_bStopRunning`, reset and `return`. Per-invocation wall-clock guard: if elapsed >
`Config.iScriptTimeout` → "Possible infinite loop" + trace, finish (Script.cs:1713, 1819-1830 R).

**Jump mechanic:** handlers return a target index; the loop's `I++` means execution resumes at
`target+1`. Labels are their own instruction, so landing on `labelIndex`+`I++` = first line after.

- **`goto`** (2451 R): resolve lowercased label; set `%lastlabel`; **`ClearBlocks()`** (drop block
  depth on active frame); return label index. Unknown → error + `AbortOnScriptError`. Does NOT
  touch the call stack. No round-time wait.
- **`gosub`** (2480 R): `gosub clear` wipes the stack. Else `AddJump(iRowIndex, <args-after-label>)`
  pushes a frame (return addr = current PC; `$0`=full arg string, `$1..$n`=parsed tokens);
  depth check vs `Config.iMaxGoSubDepth` (50; `Maximum GOSUB depth (50) on: <label>` + trace);
  return label index. Forbidden inside actions.
- **`return`** (2516 R): `RemoveJump()` pops top frame (only if Count>1); return the now-active
  frame's `LineValue` (the gosub line's index) → resumes after the gosub. Empty stack → error+abort.
- **`exit`** (2558 R): set `I = Count`, finish. Terminal.
- **`label`** (2541 R): pass-through; **error if `BlockCount > 1`** (passing a label from within a
  nested block is illegal; being in one block is OK).
- **Hot reload** (`HotReload`/`FindNewJumpLineIndex`, 1907-1970 R): Remix re-parses the file at the
  next jump after `#script reload` and remaps frame indices. **Not ported:** ours `#script reload`
  aborts the script and relaunches it with its launch arguments (`LichScriptControl#reload`; locals are
  lost). Tracked divergence.

---

## 2. Block model (`if`/`elseif`/`else`/`while`/`{`/`}`)

**Compilation (`AddLine`, 3819 R; ours `Lexer`):** `if <c> then <cmd>` splits into an `if` line
(ending at `then`) + a recursively-added `<cmd>` line; bare ` then` = block-opening `if`. Same for
`while … do` (case-sensitive ` do `). `else <cmd>` → `else` + `<cmd>`. **`elseif <c>` desugars to
`else` + `if <c>` as two sibling lines** (governed by single-line-skip, §2.4). `{`/`begin`→
`blockstart`, `}`/`end`→`blockend`. `if_N` → `if %argcount >= N …`. The split-off `<cmd>` gets no
comment skip: `if x then #echo y` is the unknown command `#echo y` (a load error, §11).

**Runtime transitions** (in `RunScript` before `RunScriptRow` for `{`/`}`):
- **`{` blockstart** (1832 R): if `SkipBlock` and `TargetBlockDepthValue<=0`, set it to current
  `BlockCount`; `AddBlock()` (push noeval); `LastRowWasEvaluation=false`.
- **`}` blockend** (1845 R): `RemoveBlock()`; if `SkipBlock` and `TargetBlockDepthValue>=BlockCount`,
  clear `SkipBlock` and `TargetBlockDepthValue=0` (resume).
- **`if`** (2571 R): if row ends ` then`, `LastRowWasEvaluation=true`. `EvalIfStatement(arg)`
  true→`BlockValue=evaltrue`; false→`BlockValue=evalfalse` + `SkipBlock=true`.
- **`while`** (2593 R): same but `evalwhiletrue`/`evalwhilefalse`; `do`→LastRowWasEvaluation.
  **No back-edge** — behaves as `if`.
- **`else`** (2615 R): if row ends `else`, LastRowWasEvaluation. If `BlockValue==evaltrue` (matching
  if was true) → `SkipBlock=true` (skip else); else run else. Relies on the if's marker still
  being top-of-block after its `}` popped.

**Single-line forms (§2.4, ~1872 R):** an evaluation line that set `SkipBlock=true` also set
`LastRowWasEvaluation=true`; the next line is skipped, then `SkipBlock` cleared — UNLESS that next
line is itself an `if` (lets `if…then if…then` chains skip). Cleared on every `blockstart`.

`EvalIfStatement` (3560 R) strips a trailing ` then`, calls `Eval.DoEval`, and the frame's
`ArgList` IS Eval's result list (capture groups of a `matchre()`): Remix aliases the two, so the
next `if`/`eval` in that frame clears `$0..$n` (N21, ported v0.21.0). `EvalWhileStatement` (3587 R)
is a bare `Eval.DoEval`.

---

## 3. Variable substitution (`ParseVariables`/`ParseVariable`, 2282 R; ours `Substitution`)

Applied to `sRowContent` → `ParsedLine` at top of `RunScriptRow`. Passes, in order:

1. **`$`-args** (if text has `$`): protect `\$`; for `i=0..iArgumentCount-1` (15, Config.cs:18 R:
   `$0..$14`) naive `Replace("$"+i, ArgList[i] or "")` **low→high** (so `$10` is hit by `$1`
   first — replicate this quirk); `$argcount`→`ArgList.Count-1` (-1 for an empty list: top level,
   no-arg gosub; launch args are NOT in the $-list, they are `%1..%9`/`%0`/`%argcount`,
   Script.cs:2064-2082 R); restore `\$`→`$`.
2. **`%`/`$` vars** (if text has `%`): protect `\%`,`\$`; **scan right-to-left**, expanding `%name`
   via local list and `$name` via globals at each unescaped sigil (right-to-left = single-level,
   positional; expansion isn't re-scanned). Else (no `%`) → `Globals.ParseGlobalVars` ($ + @).
3. **`@`-specials** (if text has `@`): `@timer@`→elapsed secs; `Globals.ParseSpecialVariables`
   (`@time@`,`@time24@`,`@date@`,`@militarytime@`,`@unixtime@`,`@year@`,`@month@`[=minutes, a
   quirk—preserve],`@spelltime@`, etc. — copy format strings verbatim).

**`ParseVariable`** (2369 R): name ends at first space. Array form `name(idx)`: split value on `|`,
return element+remainder (invalid idx → empty for locals). Longest-prefix match; `name.length`
→ element count. **Undefined → literal `%name`/`$name` left in place** (triggers eval warnings).
Locals (`%`) and globals (`$`) are separate namespaces, not a fallback chain.

**Engine-set vars:** `scriptname`, `0..9`+`argcount`, `lastlabel`, `lastcommand`,
`lastscripterror`, `s` (save), `r` (random), `c` (counter), `t` (timer; stored literally as
`"@timer@"` while running so it re-expands live). Escaping `\%`/`\$` → literal.

---

## 4. match / matchwait

- **Register** (`EvalMatch`, 3351 R): `match <label> <text>` / `matchre <label> <regex>`.
  `match clear` empties list. Stores {Text, Label, IgnoreCase, IsRegExp, precompiled Regex}.
  `matchre` strips `/…/`; a trailing `/i` (with or without a leading `/`) → IgnoreCase
  (ClassMatchList.Add, 517-535 R). Patterns are checked with .NET rules (`NetRegex`); invalid →
  error+abort. `waitforre` strips the delimiters too but stays case-sensitive.
- **Block** (`EvalMatchWait`, 3335 R): `matchwait [timeout_secs]`. timeout>0 → set deadline +
  `m_bMatchTimeoutState`. state=`matchwait`; loop breaks.
- **Select** (`TriggerParse`, 1179-1275 R): skipped while paused/done and for a whitespace-only
  line. A pending `waitfor` tests first (literal `Contains`, case-sensitive; `waitforre`
  `Match(text.Trim())`, groups → ArgList). Then, only in the `matchwait` state, iterate MatchList
  **in insertion order**, first hit wins: literal `Contains`, or regex `Match(text.Trim())` (groups
  0..N → ArgList, `$0`=whole match). Set label, `m_bWaitForMatch`, `SetBufferWait()` (the resume
  waits for the end of the packet, §10), `MatchList.Clear()`, break.
- **Resume** (`TickScript`, 1600 R): when `m_bWaitForMatch && m_bBufferEnd`: set `%lastlabel`,
  **`ClearBlocks()`**, `RunScript(labelIndex)`. Timeout → `RunScript()` (fall through past
  `matchwait`). **RT-gated:** the jump waits for round-time even though selection already happened.

---

## 5. action (async triggers)

- **Register** (`EvalAction`, 3122 R; uses **raw row**): optional `(class)` toggle; sub-commands
  `remove`/`clear`/`add`/`instant`; split on ` when ` → `<commands> when <trigger>` (no ` when ` →
  error+abort). Trigger is variable-expanded at registration unless it starts `eval `. `e/`/`eval `
  prefix → `IsEvalAction`. Precompile regex for non-eval. Keyed by trigger (replaces existing).
  Class active-state via `ClassActionList` (a class keeps the state of its first mention).
- **Fire on text** (`TriggerParse`, ~1270 R): iterate `m_oActions` (**sorted by trigger key**,
  SortedList collation), for each active non-eval action `oRegExp.Match(text)`; success → groups
  1..N + `ParseAction`. Every matching action fires (the last goto wins). Ours walks a snapshot of
  the list (tracked divergence: Remix faults when a body changes the list mid-pass).
- **Fire on var change** (`TriggerVariableChanged`, 1358-1433 R; ported WP3b v0.16.0):
  active eval-actions whose key CONTAINS the changed name (`%x`, `$health`, `lastcommand`, ...); a
  key equal to the name fires unevaluated, otherwise `EvalString(ParseVariables(key))` nonempty and
  ≠"0" → `ParseAction(key, [], name)` (`$0` = the name); an abort ends the pass. Raised by
  `AddLocalVariable`/setvariable/save/put's `%lastcommand`/eval/evalmath/math/counter/goto and match
  `%lastlabel`/jscall (NOT random/shift/unvar), and for globals by FormMain's script loop
  (`VariableDispatch`, FormMain.cs:4725-4989 R). Also arms the `waiteval` flag. Nested dispatch is
  capped at depth 20 with a script error + abort (D3, `DispatchDepth`).
- **Execute** (`ParseAction`, 2119-2270 R): split action on `Config.cSeparatorChar` via `SafeSplit`.
  Rows starting `%`→`setvariable`, `$`→`put #var`. The first word is looked up CASE-SENSITIVELY
  (an unknown or capitalised word, or a bare `#command`, is a silent no-op). `$1..$15` from the
  groups (quotes removed), `$0` = the whole line. **Forbidden in actions:** `gosub`, `{`, `}`,
  `return` (each → error+abort). Inline `if…then…`. Run `RunScriptRow(oLine, -1)`; if it returned a
  goto (`>-1`): set `m_bStopRunning`, state=`actioninstant` (if instant) else `actionwait`,
  **`Clear()`** call stack, `MatchList.Clear()`, `LineValue=target`, return — hijacks the
  interpreter to the target.
- **Gating:** `SetClass` flips `IsActive` per class; instant actions bypass the RT gate.

---

## 6. Verb table (`GetFunctionType` 4090 R → `ScriptFunctions` 556 R → `RunScriptRow` 2436 R)

| Keyword(s) | Effect |
|---|---|
| `action` | register/toggle async trigger (raw row), §5 |
| `include` | load-time file include (no runtime); a missing or empty file fails the LOAD (§11) |
| `echo` | print in scriptecho color |
| `put` | EvalPut → SendText(text): ParseCommand (§7); sets `%lastcommand` |
| `send` | EvalSend (3469 R) → SendText(text, queue=true): command queue (§7) |
| `do` | EvalDo (3477-3531 R): snapshot MatchList; `{cmd}{regex}` form; a match entry for the repeat pattern; the command is queued like `send` but also held while webbed/stunned; a matchwait that sees the repeat pattern re-sends it; invalid regex → "Invalid RegExp in Do" + abort |
| `exit` | terminate |
| `goto` / `gosub` / `return` | see §1 |
| `save` | set `%s` |
| `var`/`vars`/`variable`/`setvar`/`setvariable` | set local var |
| `unvar`/`unvariable`/`unsetvar`/`unsetvariable` | delete local var |
| `counter` | `DoMath("c", arg)` |
| `shift` | EvalShift (3003-3027 R): if `%argcount` > 0, `%k` = `%(k+1)`, old last = "", dec `%argcount`, rebuild `%0` from non-empty values (Trim); never touches `$`-args (`ScriptArgs.shift`) |
| `pause` | state=pausing until now+ms (default 1000; at least one 10 ms tick, `Interpreter::TICK_SECONDS`) |
| `delay` | state=delayed (RT-exempt) until now+ms (at least one tick) |
| `waitfor` / `waitforre` | wait for game line contains/regex (§4 Select) |
| `waiteval` | EvalWaitEval (3439-3445 R): state=waiteval, flag false, raw row; resumes only when a variable change named in the text makes it true (never on a line); a variable change never resumes `wait`/`move` |
| `match`/`matchre`/`matchwait` | §4 |
| `wait [N]` | EvalWait (3381-3393 R) = a prompt seen since the wait began AND N s passed (default 1 s, also for 0/negative/unparseable N: Utility.EvalDoubleTime) AND no roundtime |
| `move` / `nextroom` | EvalMove (3447-3458 R): a blank text (`nextroom`, bare `move`) is a no-op (no send, no wait); else clear the move flag, state=move, send; resume on the next room-desc component (TriggerMove, Game.cs:1763-1765 R) |
| `if`/`while`/`else`/`elseif` | §2 (`elseif` load-time desugar) |
| `timer` | start/stop/setstart/clear `%t` (raw row; EvalTimer 3034 R) |
| `random` | set `%r` = rand(min,max) (EvalRandom 3107 R) |
| `math` | `DoMath(var, "op number")` (Utility.MathCalc) |
| `eval`/`evaluate` | var = `Eval.EvalString(expr)`; groups→ArgList |
| `evalmath`/`evaluatemath` | var = `MathEval.Evaluate(expr)`; an error is a PrintError ("Invalid expression: ... Local Variable x has been set to 0.", 3220-3252 R), var = 0, the script goes on |
| `debug`/`debuglevel` | set DebugLevel (raw row); levels print Genie's `name.cmd(row): ...` debug lines |
| `js`/`javascript`/`jscall` | Jint in Remix (raw row); ours `JsRuntime`: the corpus JavaScript reproduced, anything else announced unsupported (WP12, D4) |
| `jsblock` rows (`<% %>`, `.js` include) | collected; run at the next non-jsblock row unless SkipBlock (and at the end, whatever); error → PrintJSError + engine dropped + AbortOnScriptError (1736-1815 R; ours `JsRuntime`) |
| `plugin` / `pluginscript` | plugin invoke / load-time expand. Ours: `plugin` announces unsupported; `pluginscript` appends nothing (no plugins) |
| `{`/`begin`, `}`/`end`, `label:` | block push/pop, label marker |

See expressions-spec.md for `Eval`, `MathEval`, and `Utility.MathCalc` (math/counter) details.

---

## 7. Sending, round-time & pacing

- `SetRoundTime(iTime)` (999 R): `m_oRoundTimeEnd = now + iTime*1000 + dRTOffset*1000` (seconds;
  offset may be negative). Called when the server reports RT.
- **RT gate** (`TickScript`, 1505-1511 R): if state ∉ {delayed, actioninstant} and
  `now < RoundTimeEnd`, do nothing this tick. So all resumes (pause/wait/waitfor/waiteval/move/
  matchwait jump AND timeout/actionwait) stall until RT clears. Sends are never held.
  Ours (v0.18.0, G07): GameState records SetRoundTime at the prompt (GameEvents::RoundTime, rt +
  RTOffset), the host delivers it to every listed script (paused too) as GameEvents::RoundTimeEnd
  on the interpreter's clock, and `Interpreter#await_resume` holds every resume but `delay`/
  `action instant` until then. A script launched during the roundtime is not gated (it was not in
  the list at the prompt; flow t144). Nothing calls `waitrt?`.
- **`SendText(text, queue, docommand)`** (4438 R) → `EventSendText`. `put`/`move`→queue=false,
  `send`→true, `do`→queue=true+docommand. Remix keeps no send history (§8).
- **queue=false** → Command.ParseCommand(text, bSendToGame: text does not start with the command
  char) as an un-awaited top level (FormMain.cs:6812-6823 R; ours `ParseCommand#run`, a fault ends
  that ParseCommand quietly):
  1. a text starting (case-insensitively) with `bug `, `sing ` or `;` is sent whole, unsplit;
  2. otherwise `SafeSplit` on `Config.cSeparatorChar` (`separatorchar`, default `;`; `\;`
     escapes); a piece whose first word is an alias key is replaced by the alias and split again
     (Command.cs:223-244 R);
  3. per row: a leading `-` becomes `#send ` (quick send); a row starting with the command char
     (`#`) runs its `#command` arm (`CommandRouter`); one starting with the script char (`.`)
     launches that script; any other row is sent (ParseGlobalVars + SendTextToGame) when
     bSendToGame;
  4. SendTextToGame (Command.cs:2826-2839 R, FormMain.cs:4378-4422 R): backslash escapes are
     resolved (`\\` → `\`, a lone `\` dropped); a text that still holds `@` or `\x` goes to the
     input box (ours: the `inputbox` hook) instead of the game; `\@` is sent as `@`.
- **queue=true** (`send`) → int.Parse delay prefix (a fraction or a value past Int32 is an error,
  nothing queued), ParseGlobalVars, CommandQueue.AddToQueue(delay, text, roundtime-gated)
  (FormMain.cs:6826-6845 R). The queue (ours `CommandQueue`, one per session) is drained by
  FormMain's tick before the scripts (ours `CommandQueue::Worker`); timing is relative and
  sequential, and a restricted head blocks the queue. Each released item runs through ParseCommand
  with bSendToGame. Ours also stores the queuing script with each item and sends the released
  command as that script (`[name]>cmd`, `silent` honoured).
- `#send N` takes fractions; `#do` also waits out webbed/stunned; `#queue N` items ignore
  roundtime; `#send clear`/`#queue clear` empty the queue.

---

## 8. Loop safety

**Remix (parity target): there is NO send-history guard** (SendText, 4438-4441 R). The only runaway
guards are the per-`RunScript` wall-clock timeout (`Config.iScriptTimeout`, 5000 ms default,
1713, 1819-1830 R) and the gosub-depth guard (`Config.iMaxGoSubDepth`, 50). Ours matches (N01/D2,
v0.11.0); the deadline excludes the time blocked inside the host's send (a slow client write,
Lich's pause checkpoint) and inside a `#parse` broadcast (the global #triggers run on the issuing
thread). Both limits come from settings.cfg or `#config scripttimeout|maxgosubdepth`.

Upstream 4.5.0.3 only, NOT ported: a send-history guard (10 identical or 30 total sends in 10 s →
error, finish, do not send).

Ours adds the D3 cap: nested trigger / `#parse` / variable-change dispatch (and nested first-run
relaunches) stop at depth 20 with `[Script error: maximum nested dispatch depth (20) exceeded on:
...]` and the script stops (Remix recurses until its stack overflows).

---

## 9. Helpers to port (Utility.cs R)

`GetKeywordString` (957, first word), `GetArgumentString` (971, after first space), `ParseArgs`
(390, tokenize honoring `"…"`/`{…}`/`\`), `SafeSplit` (782, split ignoring quotes/braces/escapes;
ours `Text.remix_safe_split`), `EvalDoubleTime` (707, `StringToDouble*1000` or default ms),
`MathCalc` (883, math/counter), `Count` (985), `ValidateRegExp` (113). Regex options: read
`RegexOptions.cs` R; patterns are validated and translated by `NetRegex` (.NET dialect on Onigmo:
variable-length lookbehinds emulated where they sit at a fixed distance from the match start, the
rest registered as never-firing with one warning line).

## 10. State machine driver (`TickScript`, 1487-1664 R) — resume conditions

After paused/done early-return and the RT gate, dispatch on state: `scripterror`→run scripterror
label (before the RT gate); `pausing`/`delayed`→run at deadline; `wait`→on prompt after deadline;
`waitfor`→on buffer-end + resume flag; `waiteval`→on event flag; `move`→on move flag;
`matchwait`→§4 Resume; `actionwait`/`actioninstant`→clear stop-flag + run. `RunScript()` resumes at
the active frame's `LineValue`.

**Ours (v0.18.0, WP6): `Interpreter#await_resume`.** One loop for every wait state: each input item is
received as it arrives (a game line, a queued `#parse`, a variable-change batch, and the GameEvents
RoundTimeEnd / Prompt / Move / Resumed), and the wait resumes once (1) the script is not paused,
(2) no DR packet is arriving, (3) the roundtime is over (unless delayed/actioninstant), (4) the
state's own arm fires (`resume_ready`). (2) is genieflow's deterministic model (no tick inside a
chunk) of Remix's m_bBufferEnd and tick timing (1551, 1600, 2098-2104 R): a game line, a game row's
variable batch (`Change#game?`), a RoundTimeEnd or a Move opens the packet; its Prompt (which also
offers the prompt text like a game line, G73 -- nothing is offered while the last row printed to the
main window was a prompt: GameState#last_row_was_prompt, Game.cs:2397 R) or `CHUNK_IDLE_SECONDS`
(10 ms) with no further game item ends it (Lich has no packet boundary: section 12, "Lich
delivery facts"). Not emulated (D5): Remix's Channel race (t49) and the 100 ms TriggerParse
lock-wait drop. A timed wait (pause/delay/wait N/matchwait timeout) resumes no sooner than one Remix
tick (10 ms) after entry (`timed_end`; TickScript looks only on its tick). A paused script (any
pause) runs no row (RunScript breaks before the next row, 1731-1734 R) and takes no resume; under
Genie's `#script pause` its host drops what arrives meanwhile except a roundtime (GenieScript::
InputBuffer, G20); under a Lich-level pause it keeps it for after the unpause (D7).

## 11. Load and error model (WP9)

- **Load** (`LoadFile` 1971/2064 R, `AppendFile` 3683-3800 R, `AddLine` 3819 R; ours `Lexer`):
  lines split like StreamReader.ReadLine (CR, LF or CRLF; a UTF-8/16/32 byte-order mark honoured),
  each TrimStart()ed; `#` starts a comment; `<%` opens a JavaScript block. **Fatal** (the script does
  not start): an unknown command (unless `ignorescriptwarnings`), an `if` without ` then`, a `while`
  without a case-sensitive ` do`, a missing (`File not found: <name>`) or empty (`Unable to load
  file: <name>`) main file or include. A duplicate label is a warning (unless
  `ignorescriptwarnings`) and the last copy wins. Load lines print as `[Script error(<row>):
  <text>]` (`[Script error, <include>(<row>): ...]` for an included file; no row for a file error):
  the main file name is not known yet while loading. `ignorescriptwarnings` defaults to False.
- **Include** resolution: exactly the named file in the script dir (no extension added, no
  `custom/` layer; a case-insensitive directory match stands in for Windows); an include already
  loaded is skipped. Launch resolution is the same (`ScriptLaunch`): `.name` → `name.cmd`.
- **Runtime errors** (`PrintError` 4340-4360 R): `[Script error in <file>[, <include>][(<row>)]:
  <text>]`, the text also in `%lastscripterror`; then `AbortOnScriptError` (1109-1135 R): with a
  `scripterror` label (and not already in that state) the blocks are cleared and the script resumes
  there on the next tick (`[Script moving to scripterror label (<file>)]`), else it ends.
  `PrintJSError` prints `[Javascript error in ...]`.
- **Evaluator / host faults** (G46, decided): where Remix's catch hands an exception to GenieError
  (which recurses until Remix's client dies), ours prints the .NET message as one `[<message>]` line
  and the script stops (no scripterror jump).

## 12. Lich delivery facts

How Lich hands game rows to the engine, read from Lich's source. The interpreter's packet and
resume model (section 10) rests on these.

- **One row at a time, no packet boundary.** Lich's socket reader reads one row per `gets`
  (`lib/games.rb`), so the boundary of a TCP read is lost. One parser thread finishes a row before
  the next: XMLData parses it, `strip_xml` strips it, `Script.new_downstream_xml(row)` runs (the
  engine's GameStateFeed tap: game-state changes and GameEvents are queued here), each stripped line
  goes to every script buffer (`Script.new_downstream`, no pause check), and only then do the
  DownstreamHooks run. A hook that returns nil stops the later ones, so the engine's display hook is
  not a reliable per-row signal.
- **A prompt row never reaches a script as a line.** `<prompt ...>&gt;</prompt>` is a data element:
  `strip_xml` removes it and a whitespace-only result is dropped, so no line is pushed. Remix prints
  the prompt text and offers it to `#trigger`s and scripts (Game.cs:2397-2405 R); the engine takes it
  from GameState (`GameEvents::Prompt`), not from Lich's lines.
- **Roundtime comes first, the prompt last.** DR sends `<roundTime value=.../>` on a packet's first
  row and `<prompt>` as its last row. `XMLData.roundtime_end` is set at that first row; Remix computes
  the roundtime end at the prompt (Game.cs:2366-2373 R), and so does GameState. Resumes wait for the
  packet's end anyway, so the two agree.
- **The prompt row is the end of a DR packet.** In a recorded hunting session almost every receive
  burst ended with a prompt row, and the rows of one packet arrived at most a few milliseconds
  apart. So the engine ends a packet at the prompt row, and after `CHUNK_IDLE_SECONDS` (10 ms) with
  no further game row for a burst without a prompt. Remix ends it at each socket receive
  (FormMain.cs:5620-5643 R) and resumes on the next 10 ms tick. A TCP split longer than 10 ms resumes
  a wait mid-packet, in Remix too (D5 in open-items.md).
- **Buffer reads.** `Script#gets(timeout)` with timeout 0 returns a buffered item or nil at once and
  does not check for a pause. Lich's pause only blocks at checkpoints, so the glue drops what is
  pushed during a Genie `#script pause` itself (`GenieScript::InputBuffer`) and the interpreter has a
  paused state.
- **Remix holds the script's lock for a whole RunScript** (Script.cs:1703 R), so a line that
  arrives while the script runs rows is handled in the wait state the row loop ends in, which is
  what the buffered input does here.
