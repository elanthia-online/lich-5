# Genie engine -- how to test (v0.25)

The Genie scripting engine runs your `.cmd` scripts inside Lich. Since v0.10.5 it has been
rebuilt to follow **Genie Remix 4.2.4** line by line: if a script works in Remix it should work
here, and if it fails in Remix it should fail here the same way. The full guide is
[user-guide.md](user-guide.md); this page is what a tester needs.

## What changed since v0.10.5

Many of these change what you see. Where it helps, the user-guide section with the details is in
parentheses.

**Saving variables and triggers (persistence)**
- `#var` no longer writes to disk. Globals are shared by every running script at once and live
  until Lich exits; `#var save` (or `#save vars` / `#save all`) writes `variables.cfg`.
- `#trigger`s work the same way: `#trigger save` (or `#save triggers`) writes `triggers.cfg`.
- Both files are read once, when the engine starts with your session (user-guide section 7).
- `#class`, `#gag`, `#sub` and `#alias` have their own `save`/`load` too (`classes.cfg`, `gags.cfg`,
  `substitutes.cfg`, `aliases.cfg`), all in `<scripts>/GenieProfiles/Config/`.

**Timing**
- Roundtime holds the script, not its commands. A `put` in roundtime goes out at once and the game
  answers "...wait", as in Genie. A script's next row waits for the roundtime instead.
- `send` (and `send 2 look`, `put #send`, `put -2 look`) uses Genie's command queue: the command
  goes out once the roundtime is over (and after its delay). `put #queue 2 bow` is not held by
  roundtime, as in Genie.
- `wait` resumes at the next prompt (at least 1 second), `move` at the next room.
- A script started during roundtime is not held by it, so a `put` + `matchre ... \.\.\.wait` retry
  loop resends on every "...wait" until the roundtime ends. Genie does the same.
- A wait never ends in the middle of the game's reply: the rest of the reply reaches your actions
  first. The prompt (`>`, `R>`) is seen as a line (section 6, "Roundtime").
- `put stand;look` sends two commands; `\;` is a literal semicolon (section 6).

**Matching and regular expressions**
- `waitfor` and `match` are case-sensitive, as in Genie.
- `matchre`, `waitforre`, `action` and `#trigger` patterns follow Genie's .NET rules. An invalid
  pattern stops the script (a bad `#trigger` is refused) (section 10).
- `#parse` reaches every running script and your `#trigger`s at once; it is never stored for later.
- Actions: variables in the pattern are filled in when the `action` line runs; the same pattern
  twice replaces the first; every matching action fires (the last `goto` wins).
- `action ... when eval <expr>` and `waiteval` work as in Genie: they react when a variable named
  in the expression changes.
- The `if`/`eval`/`evalmath` evaluators are now exact copies of Genie's, quirks included.

**Errors and strict loading**
- A script is checked as a whole before it starts. An unknown command, an `if` without `then`, or
  a missing `include` file stops it from starting (section 15).
- Errors while running print Genie's `[Script error in name.cmd(12): ...]`. A `scripterror:` label
  catches them. `gosub` nesting stops at 50, a wait-less loop at 5 seconds.
- `debug N` prints Genie's debug lines. `timer` and `%t` work.

**Starting and stopping scripts**
- `put .name` runs exactly `name.cmd` from your scripts folder, never a `.lic` of that name. A
  missing file prints `[Script error: File not found: name.cmd]`.
- Starting a script that is already running restarts it (Genie's `abortdupescript`).
- An aborted script (`#script abort`, a restart, a script error) prints Genie's `[Script aborted!
  (Run time: N seconds): name.cmd]` and no `--- Lich: ... was killed` line; scripts and triggers
  never see it.
- A script that aborts itself stops at once. A freshly started script is not in the script list
  until its first wait, so `put #script abort all except x` at the top no longer kills itself.
- Arguments split like Genie: `"two words"` is one argument, `red_gem` becomes `red gem`, `%1`..`%9`
  are always defined. `$1`..`$9` are NOT the script's arguments (section 14).

**#commands**
- `#class`, `#gag`, `#sub`, `#alias` and `#name` are run by the engine with Genie's listings and
  messages. `#class` re-applies the whole class list each time; only `on`, `true`, `1` mean on.
- A `#command` Genie does not know (`#ping`, a typo) prints `Unknown command: <line>`.
- `#config key value` prints `Set key: value`; the settings the engine uses take effect at once.
- Gags and subs work on the line's display text; a gagged line still updates your windows.
- A command holding `@` is not sent: Genie puts it in the input box for you to finish (section 6).
- A command starting with `/` (Genie's `mycommandchar`) is not sent and does not change
  `$lastcommand`: `put /spelltimer` (in 8 of the tester's scripts) shows its echo and nothing reaches the
  game, as in Genie. A `/` line you type yourself still goes to the game (Lich owns your input).

**Triggers and game text**
- The engine starts with your session (first game line after login), so saved `#trigger`s fire
  from login, before you run any `.cmd`.
- `#trigger`s fire before any script sees a line, on their own thread.
- What you type or send also reaches `#trigger`s and scripts (Genie's `triggeroninput`).
- The engine's own output (`echo`, `#echo`, its messages) is never fed back to scripts or triggers.
- Scripts and triggers see the game text as Genie's parser prints it: all windows except Room and
  Inventory, leading spaces kept (`{^   Last login}` matches), entities as Genie decodes them.

**JavaScript**
- `js_arrays.js` behaves as under Genie Remix's JavaScript engine (Jint 4). That means most of its
  functions FAIL, as they do in Remix: `doPop`, `doShift`, `doXCompare`, `findIndex`, ... print
  `[Script error in name.cmd(N): Property 'length' of object is not a function]`; `doPush`,
  `doUnshift`, `doConcat`, `doReplace`, `buildArray` work.
- `<% %>` blocks run. Other JavaScript is announced as unsupported (section 12).

**#goto**
- `#goto N` returns at once and walks in the background. It ends with Genie's automapper lines,
  `YOU HAVE ARRIVED!` or `MOVE FAILED`, delivered to every script.
- The number is a room of the zone you are in. A number your zone has no room for gives
  `DESTINATION NOT FOUND` (section 13, "Moving by room number").

**Reserved variables**
- Only Genie Remix's own reserved variables exist (plus the plugin ones: `$SpellTimer.*`,
  `$Time.*`, `$<Skill>.*`). `$inside`, `$gameroomid`, `$name`, `$level`, `$maxhealth`, `$roomtitle`
  and the case-insensitive lookups are gone (`$Health` is undefined; use `$health`).
- `$roomobjs`, `$roomplayers`, `$roomexits` hold the game's raw text, as in Genie (section 13).

## 1. Update Lich to the testing build

1. Run the update. This page writes Lich commands with `,`, your Lich command character (use `;`
   if yours is Lich's default):

   ```
   ,lich5-update --branch=MahtraDR:feature/genie-scripting-engine
   ```

2. **Fully close and restart Lich.** Relogging is not enough.
3. Check the version:

   ```
   ,eq echo Lich::Genie::VERSION
   ```

   It should print `0.26.12 (2026-10-27)` or later. The engine also prints
   `--- Genie engine v0.26.12 (2026-10-27) active` once per session.
4. The engine stays on for a character once you turned it on. If it is off
   (`,eq echo Lich::Genie.enabled?` shows `false`), turn it on: `,e Lich::Genie.enabled = true`.

## 2. Reset: a saved "triggers loaded" flag

Some setups keep a flag that says "my triggers are loaded", for example `$triggersloaded`, and a
hunting script that skips its trigger loader when the flag is `1`. If yours does, reset the flag
once before the first run on this build (and again after any session that did not end with a
quit script run in this engine, see below).

Engines before v0.12 saved every `#var` to disk at once, but never saved triggers. So your
`GenieProfiles/Config/variables.cfg` may say `triggersloaded 1` while no `triggers.cfg` exists.
The hunting script then skips its loader and waits forever for a trigger that does not exist.

Reset the flag in this engine with a two-line script, for example `reset.cmd`:

```
put #var triggersloaded 0
put #var save
```

Run it (`,reset`) before the first run. Then the hunting script loads its triggers and sets the
flag back to 1, as it should.

To keep it from coming back, log off through a quit script that runs in this engine and does
`#trigger save` and `#var save`, not through native Genie (that only updates native Genie's
files). Many scripts run `#var save` in the middle of a session, which writes the flag as 1 while
the triggers are only saved by the quit script. So **if a session ended without that quit
script** (a disconnect, closing Lich, a quit run by native Genie), run `,reset` again before the
next hunt. The engine does not reset the flag for you, on purpose: Genie does not either.

## 3. Put your include files in the scripts folder

Loading is strict, as in Genie. `include helper.cmd` loads exactly that file from your Lich
`scripts` folder: no `scripts/custom` copy, no `.cmd` added for you, upper/lower case does not
matter. `include js_arrays.js` needs the file too.

A missing include stops the script before it starts. You see:

```
[Script error: File not found: helper.cmd]
```

(an empty file gives `[Script error: Unable to load file: helper.cmd]`). Nothing of the script
runs. Move the file into `scripts` and run the script again.

## 4. Decided differences from Genie (on purpose)

These differ from Genie Remix by decision. Please do not report them as bugs.

- **No send-loop guard (D2).** Remix has none. A loop that sends quickly but waits is never
  stopped; only a loop that runs 5 seconds without waiting is.
- **Endless trigger chains stop at 20 (D3).** A `#trigger`, `#parse` or eval action that keeps
  setting itself off stops after 20 nested rounds with
  `[Script error: maximum nested dispatch depth (20) exceeded on: ...]`. Genie would crash.
- **JavaScript fails where Remix fails (D4).** See "JavaScript" above.
- **Remix's timing races are not copied (D5).** Where Remix can miss a line because two of its
  threads race (or a script was busy for over 100 ms), this engine still delivers it.
- **Folder variables are this engine's folders (D6).** `$scriptdir` is your Lich scripts folder;
  `$logdir`, `$mapdir`, `$sounddir`, ... are folders under `<scripts>/GenieProfiles/`.
- **Only Genie's `#script pause` drops game lines (D7).** A Lich `,pause` (or another Lich script
  pausing yours) keeps the lines that arrive (the last 400 items, the same input buffer as Remix's)
  and hands them over after `,unpause`.
- **`#goto` numbers (D8).** In a zone where Lich's map knows the Genie room numbers, only that
  zone's rooms are found. Only from a room with no Genie number is the number tried as a Lich room
  id (then a game room id).
- **An evaluator crash stops the script (G46).** Where Genie's `if`/`eval`/`evalmath` throws (for
  example `substr` past the end of the text), the script prints the message in brackets and stops.
- **A pattern that is too slow is switched off.** A `#trigger`, gag or substitute whose pattern
  takes over 1 second on 3 lines in a row is turned off with one `--- Lich: genie ... disabled`
  line. Add it again to turn it back on. Genie would hang.
- **Genie crashes are not copied.** Where Genie's client itself dies (for example `count(x, "")`,
  or a `#log` write failure), the script stops with an error line instead (or, for `#log`, prints
  `[LogLine: ...]` and goes on).
- **A failing `#trigger` action is reported.** Genie is silent; this engine prints
  `--- Lich: genie trigger error: ...`. The other triggers still fire.

## 5. Try it

The sample `docs/genie-engine/examples/genie-hello.cmd` (in the branch) sends no game commands.
Copy it into your `scripts` folder and run `,genie-hello`. You should see a greeting, three
iterations (one per second), then `doubled is 6` and `isdone flag is 1`.

## What works

Everything the script corpus uses:

- every Genie script command: `echo`, `put`, `send`, `goto`, `gosub`/`return`, `if`/`elseif`/
  `else`, `while`, `{ }` blocks, `pause`, `delay`, `wait`, `waitfor`/`waitforre`, `waiteval`,
  `match`/`matchre`/`matchwait`, `move`/`nextroom`, `var`/`setvariable`/`unvar`/`save`/`counter`/
  `math`/`eval`/`evalmath`/`random`/`shift`, `action` (with classes, `instant`, `eval`), `do`,
  `timer`, `debug`, `include`, `exit`, labels;
- variables: `%local`, `$global`, `%name(idx)` arrays, `%name.length`, `@time@`-style specials,
  script arguments, Genie's reserved game variables, the SpellTimer plugin (`$SpellTimer.*`),
  `$<Skill>.*` (from Lich) and `$Time.*` (from moonwatch);
- `#` commands: `#var`/`#tvar`/`#unvar`, `#trigger`, `#class`, `#gag`, `#sub`, `#alias`, `#name`,
  `#send`/`#queue`/`#do`/`#event`, `#parse`, `#echo`, `#log`, `#config`, `#script`, `#goto`,
  `#save`/`#load`, `#eval`/`#evalmath`/`#math`/`#if`/`#random`;
- `#echo >Window text` and `#link` text: shown in that window through Lich's own window messages
  (an XML front end's familiar/thoughts/combat window), else the main window, on every front end;
- the other front-end effects (`#highlight`, `#macro`, `#window`, `#playsound`, ...) are sent as a
  `<genieHook>` tag (hook-protocol.md) only for a character that turned them on
  (`,e Lich::Genie.hooks_enabled = true`, for a front end that supports them); off (the default)
  they do nothing;
- Lich's own controls: `,list`, `,kill`, `,pause`/`,unpause`.

## Limitations

- **No general JavaScript.** Only `js_arrays.js` (every published version), simple `js`/`jscall`
  calls and the two known `<% %>` blocks (SkillData, ubercombat) are reproduced. Other JavaScript, and
  `#plugin`, print `[Genie: ... not supported in the in-Lich engine: ...]` and the script goes on.
- **One config for every character.** Genie can keep a `variables.cfg` per profile; this engine has
  one `GenieProfiles/Config/variables.cfg` (and `triggers.cfg`) for every character using that
  scripts folder. The last character to save writes the whole file.
- **`#script reload`** restarts the script with its arguments. Genie re-reads the file in place and
  keeps its variables.
- **`#goto <name>`** (Genie map notes such as `#goto bank`) is never found, and `#path` does
  nothing: both need Genie's own map files.
- **A few rare .NET regex constructs** cannot be matched here (balancing groups, some lookbehinds,
  groups nested more than 256 deep).
  The engine prints one `[Genie: ... it will never fire: ...]` line naming the construct.
- **Same-named Lich scripts.** `,kill train` stops whichever of `train.cmd` / `train.lic` Lich finds
  first; use `put #script abort train` for the Genie one.
- **Highlights, macros, windows, sounds** appear only with a front end that supports `<genieHook>`,
  and only after `,e Lich::Genie.hooks_enabled = true` (off by default).
- **Lich commands only from what you wrote yourself (decided divergence D10; user guide section 14).**
  `put ,go2 x`, `put ,go2 %dest`, `send 2 ,go2 x`, and `,...` rows in the body of an `action` line of
  a `.cmd`, of a `#trigger`/`#alias` from your `triggers.cfg`/`aliases.cfg` or from a `put #trigger
  ...` line with nothing filled in, run as Lich commands. A `,`/`;` that only appears once a variable
  or a captured `$1`/`$2` is filled in, a command whose name is a variable or capture (`put ,%cmd`,
  `action put ,$1 when ...`), and anything in a trigger/alias/action that a script defined from
  captured or filled-in text -- also after `#trigger save` and a load (`triggers.cfg.untrusted` /
  `aliases.cfg.untrusted` remember which) -- goes to the GAME as text (the game says "Please
  rephrase that command"). Code-running Lich commands (`,e`/`,eq`/`,exec`/`,execq`/`,execname`/`,en`, `,l5u`) run
  only from a `put` line of a `.cmd` with nothing filled in (`put ,e $T2.reload_settings` works):
  never from `send`, a trigger/alias/action body, or `#send`/`#put`. A Lich command inside
  `#send`/`#put`/`#queue`/`#event`, after `move`/`do`, as a `gosub` argument, after `send %d`, or from
  JavaScript goes to the game too. If one of your scripts stops reaching Lich, report the line.
- **Turning the engine off** (`,e Lich::Genie.enabled = false`) stops `#trigger`s, gags,
  substitutions and queued sends at once; a `.cmd` still running gets no more game text and its
  sends are dropped (one `[Genie: the engine is off ...]` line per script; `,kill` it). Turning it
  back on resumes them, no restart; the game state catches up on the lines Lich parsed meanwhile.

## Report back

When a script misbehaves, please send:

1. The version line (`,eq echo Lich::Genie::VERSION`).
2. The script file, and every file it `include`s.
3. What you did (the exact command and arguments), what you expected, and what happened.
4. Any error line you saw (`[Script error ...]`, `--- Lich: genie ...`) copied exactly.
5. The game text around the problem (your front end's log, or Lich's log for that session).
6. If it works in Genie Remix on the same character, say so. That is the strongest evidence.

For a `#trigger` that does not fire, turn on `,e Lich::Genie.trace_triggers = true` first: each
game line then shows as `--- genie rx: ...`, followed by the triggers that match it.
