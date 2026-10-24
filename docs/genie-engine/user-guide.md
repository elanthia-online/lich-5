# Running Genie Scripts in Lich — User Guide

This guide shows you, step by step, how to run **Genie-style `.cmd` scripts** directly in Lich.
No prior experience required. Every section has examples you can copy and try.

> ⚠️ **This is a testing preview — you are a tester.** This feature is **not yet part of official
> Lich.** It lives on a development branch and needs testers before it can be submitted and merged.
> You'll install it from that branch (below), try it out, and report anything that looks wrong.
> Expect occasional updates while it's being polished. It is safe: it's off until you turn it on, and
> it only affects `.cmd` files.
>
> - **Fork:** `MahtraDR/lich-5`
> - **Branch:** `feature/genie-scripting-engine`

> **The short version:** With this build, Lich can *run your Genie `.cmd` scripts as-is*. You install
> the testing branch, turn the feature on once per character, and your `.cmd` files start working.
> Nothing changes until you turn it on, and you can turn it back off at any time.

---

## Table of contents

1. [What this is (and what it is not)](#1-what-this-is-and-what-it-is-not)
2. [Before you start: five things that will put you at ease](#2-before-you-start-five-things-that-will-put-you-at-ease)
   - [Prerequisite — install the testing build (from the fork)](#prerequisite--install-the-testing-build-from-the-fork)
3. [Step 1 — Turn the engine on](#3-step-1--turn-the-engine-on)
4. [Step 2 — Write and run your first script](#4-step-2--write-and-run-your-first-script)
5. [Step 3 — Turn it back off (so you know you can)](#5-step-3--turn-it-back-off-so-you-know-you-can)
6. [The building blocks of a script](#6-the-building-blocks-of-a-script)
7. [Variables](#7-variables)
8. [Making decisions: `if` / `else`](#8-making-decisions-if--else)
9. [Loops: labels, `goto`, and `gosub`](#9-loops-labels-goto-and-gosub)
10. [Reacting to the game: `match`, `waitfor`, and `action`](#10-reacting-to-the-game-match-waitfor-and-action)
11. [Effects and triggers: `#` commands](#11-effects-and-triggers--commands)
12. [Splitting a script into multiple files: `include`](#12-splitting-a-script-into-multiple-files-include)
13. [Reserved variables reference](#13-reserved-variables-reference)
   - [13b. Surfacing creature IDs in ASSESS (opt-in, an addition Genie lacks)](#13b-surfacing-creature-ids-in-assess-opt-in-an-addition-genie-lacks)
14. [Running, listing, and stopping scripts](#14-running-listing-and-stopping-scripts)
15. [Troubleshooting](#15-troubleshooting)
   - [Reporting problems (you're a tester)](#reporting-problems-youre-a-tester)
16. [Frequently asked questions](#16-frequently-asked-questions)
17. [Quick reference card](#17-quick-reference-card)

---

## 1. What this is (and what it is not)

Genie is a game client with its own scripting language. Its scripts end in **`.cmd`**. This feature
teaches Lich to **run those `.cmd` scripts natively** — the same automation you had in Genie, now
running inside Lich.

**What it does:**

- Runs your `.cmd` automation: sending commands, waiting for text, loops, math, variables,
  triggers, and more.
- Keeps your global variables and triggers between sessions once you save them (`#var save`,
  `#trigger save`), as Genie does.
- Applies **gags** (hide lines) and **substitutions** (rewrite lines) to what you see.
- Shows `#echo >Window` text in that window (where your front end has it), and can announce the
  other front-end effects (highlights, macros, colored classes, windows, sounds) in a universal
  format for a front end that supports it (off unless you turn it on -- see Group B in section 11).

**What it is not:**

- It is **not** a replacement for your existing Lich `.lic` scripts. Those keep working exactly as
  before.
- It does **not** change anything until *you* turn it on, per character.

---

## 2. Before you start: five things that will put you at ease

1. **It is OFF by default.** If you do nothing, nothing changes.
2. **It is per-character.** Turning it on for one character does **not** affect any other character.
3. **It is remembered.** Turn it on once; it stays on for that character across relogs. Turn it off
   once; it stays off.
4. **It is reversible.** One command turns it off and you are back to exactly how things were.
5. **Your `.lic` scripts are untouched.** This only affects `.cmd` files.

> **One thing to know:** while the engine is **on**, `.wiz` (old Wizard) scripts are turned off for
> that character, because `.cmd` and `.wiz` cannot both be interpreted at once. If you rely on
> `.wiz` scripts, leave the engine off (or turn it off before running them).

---

## Prerequisite — install the testing build (from the fork)

Because this feature isn't in official Lich yet, you first update Lich to the testing branch. This
is the same one-line update you may already use, pointed at the branch:

```
;lich5-update --branch=MahtraDR:feature/genie-scripting-engine
```

Then **fully close and restart Lich** (log out and back in). That's it — you're now running the
testing build.

> **Read this — it matters:**
> - You must **re-run that update command whenever there's a new version to test**, then restart.
>   Simply relogging does **not** pull new changes.
> - This replaces your Lich files with the testing branch's copy. Your characters, settings, and
>   saved variables are not touched, but any local edits you made to Lich's own files will be
>   overwritten by the update.
> - To go back to official Lich later, run your normal update command (without the `--branch=...`
>   part) and restart.

Once you've updated and restarted, continue to Step 1.

---

## 3. Step 1 — Turn the engine on

Log in with the character you want to use. Then type this in your game window:

```
;e Lich::Genie.enabled = true
```

That's it. You should see no error. To confirm it worked, type:

```
;eq echo Lich::Genie.enabled?
```

You should see:

```
true
```

**You only ever have to do this once per character.** It is remembered across relogs.

From then on **the engine starts with your session**: at the first game line after you log in with
that character (or, the first time, at the next game line after you turn it on) -- before you run
any `.cmd`. It prints `--- Genie engine v... active` once, reads your saved variables and triggers,
and your saved `#trigger`s fire from login on. A character you never enabled is untouched: nothing
of the engine runs for it.

To turn it on for another character, log in as that character and run the same command there.

> **Tip:** If you want to double-check what's stored for your characters, run:
> ```
> ;eq echo Lich.db.execute("SELECT * FROM lich_settings WHERE name LIKE 'genie_enabled:%';")
> ```
> You'll see one row per character you've enabled, like `["genie_enabled:DR:Yourname", "true"]`.

---

## 4. Step 2 — Write and run your first script

Let's make the simplest possible script.

1. In your Lich **`scripts`** folder, create a new text file named **`mytest.cmd`**.
2. Put exactly this inside it:

   ```
   echo Hello from my first Genie script!
   ```

3. Save the file.
4. In the game, run it by typing its name **without** the `.cmd`:

   ```
   ;mytest
   ```

You should see `Hello from my first Genie script!` printed in your window.

`echo` prints to **you** only — it does not send anything to the game.

Now let's actually do something in the game. Change `mytest.cmd` to:

```
echo I am going to look around now.
put look
```

Run `;mytest` again. This time the script prints a message to you, then sends the **`look`** command
to the game, exactly as if you had typed `look` yourself.

- `echo` → shows text to you.
- `put` (or `send`) → sends a command to the game.

Congratulations — you're scripting. 🎉

---

## 5. Step 3 — Turn it back off (so you know you can)

Any time you want to go back to how things were:

```
;e Lich::Genie.enabled = false
```

Confirm with:

```
;eq echo Lich::Genie.enabled?
```

which now shows `false`. It takes effect at once, no restart: your `#trigger`s stop firing, your gags
and substitutions stop hiding or changing lines, and anything still waiting in the command queue
(`send 2 ...`, `#send`) is dropped instead of sent. Your `.cmd` files will no longer start through the
Genie engine, and `.wiz` scripts work normally again. A `.cmd` that was already running gets no more
game text while the engine is off and sends nothing: each command it tries is dropped, and the first
one prints `[Genie: the engine is off (Lich::Genie.enabled) -- <name> sends nothing until it is turned
back on.]` -- stop it with `;kill <name>`. Turn it back on whenever you like
(`;e Lich::Genie.enabled = true`): the triggers, gags and substitutions work again at once, a script
still running sends again, and the engine's view of the game (`$roomname`, `$health`, ...) catches
up on the lines that came in while it was off.

---

## 6. The building blocks of a script

A script is just a list of lines, read top to bottom.

### Comments and blank lines

- A line that **starts with `#`** is a comment and is ignored.
- Blank lines are ignored.

```
# This is a comment. The engine skips it.

echo This line runs.
```

### Sending commands vs. showing text

```
put stand           # sends "stand" to the game right away
send get my pack    # queues "get my pack": it goes out once any roundtime is over
send 2 look         # queues "look" to go out 2 seconds later
echo done standing  # shows text to you only
```

`send` puts the command in Genie's **command queue** instead of sending it at once: the queue sends
it on its next tick (every 10 ms) once you are out of roundtime. `send 2 look` waits 2 seconds
first, and each queued command's wait starts when the one before it went out, so `send 2 look`
followed by `send 1 smile` sends `look` after 2 s and `smile` after 3 s. The delay must be a whole
number for `send` (`send 0.5 look` is an error, exactly as in Genie). `put #send 0.5 look` (or
`#send` inside a trigger) takes fractions, `put #do 1 grab` also waits while you are webbed or
stunned, `put #queue 2 bow` queues a command the queue does not hold back for roundtime (it goes
out on time, in roundtime too, as in Genie), and `put #queue clear` (or `#send clear`) empties the
queue; `put #queue` lists it. A queued command is
shown as sent by the script that queued it (`[myscript]>look`), and not shown if that script is
silenced; one queued by a `#trigger` or typed by you shows as `[(unknown script)]>`.

A `put` line is split on `;` into several commands, like typing them: `put stand;look` sends two
commands (the separator is Genie's `separatorchar` setting, `;` by default). Write `\;` for a
semicolon the game should see (`put say a\;b` says `a;b`); a line starting with `sing `, `bug ` or
`;` is never split. A part starting with `-` is a quick send: `put -2 look` is `put #send 2 look`.
A line that starts with `#` runs its commands but sends none of its plain parts: `put #echo
hi;look` echoes `hi` and does NOT send `look` (Genie does the same).

A command that starts with `/` (Genie's `mycommandchar` setting, `/` by default) is **not sent to
the game** either, exactly as in Genie, where it is meant for plugins: `put /spelltimer` or `put
/sort` shows `[myscript]>/spelltimer` but sends nothing and leaves `$lastcommand` alone (a typed one
leaves `$lastinput` alone too); your `#trigger`s still see it (trigger-on-input). Only the very first
character counts (`put  /x`, with a space first, is sent). If you change the setting (`#config
mycommandchar !`), that character is held back instead and `/` is a normal command again. (What you
type yourself still goes to the game through Lich: Lich, not the engine, owns your input line.)

As in Genie, a backslash in a sent command is an escape and is not sent (`\\` sends one `\`), and a
command that holds `@` (or `\x`) is NOT sent to the game: Genie puts it into the input box for you
to finish, so here it is shown to you in the main window instead (or, with front-end effects turned
on, handed to your front end as an `inputbox` effect). Write `\@` to send a real `@`.

`#echo` takes an optional colour before the text: `put #echo #33CC99 Ready` shows `Ready` and
`put #echo >Log #cf2319 Error!` shows `Error!` in the Log window (the colour itself is not carried).
A `>Window` text goes through Lich's own window messages, so every front end shows it: in that window
where Lich lets your front end have it (`>Familiar`, `>Thoughts`, `>Combat` on an XML front end such
as Stormfront, Profanity or Genie), otherwise in the main window -- a Wizard front end gets plain text. Colour names work the same way, in any case (`put #echo red Ready`, `put #echo Crimson
*** ALERT ***`): Genie's 140 web colour names are recognised and dropped from the text; any other word
stays. A line that is just a colour code (`#ff0000`) does nothing, and `#var hx #ff0000` stores
`#ff0000`. A `#command` Genie does not know (`#ping`, `#automapper`, a typo) shows `Unknown command:
<the line>`, exactly like Genie.

### Roundtime

As in Genie, roundtime holds a script, not its commands: a script that is waiting -- `pause`, `wait`,
`waitfor`, `waitforre`, `waiteval`, `match`/`matchwait` (its timeout too), `move`, or the jump of an
`action ... goto` -- goes on only once the roundtime is over. `delay` is the exception (it is the
"pause that ignores roundtime"), and so is `action instant ... goto`. Commands are never held: a
`put` (or a trigger's command) during roundtime goes out at once and the game answers "...wait N
seconds", exactly as in Genie; a `send` waits in the queue for the roundtime to end. A script
started DURING a roundtime is not held by it (Genie only holds the scripts running when the prompt
reported it), so a retry loop such as `put get rock` + `matchre RETRY \.\.\.wait` + `RETRY: goto
...` in a script started during roundtime resends every time the game answers "...wait", until the
roundtime is over -- as in Genie. The roundtime is known from the game's prompt in whole seconds, so it can end up
to a second before the game's own; `#config roundtimeoffset 0.5` (or `roundtimeoffset` in
settings.cfg) adds a margin, as in Genie.

A timed wait (`pause`, `delay`, `wait N`, a `matchwait` timeout) lasts at least one Genie tick (10
ms), as in Genie, whose timer looks at the waits every 10 ms: `delay 0.001` in a loop runs the loop
once per tick instead of spinning.

A wait also never ends in the middle of the game's reply: when `waitfor`/`match` sees its line, the
rest of that reply (up to its prompt) still reaches the script's actions first, so an action on a
later line (an `action goto`, a variable a later line changes) wins, as in Genie.

The game's prompt reaches your actions, `waitfor`/`match` and `#trigger`s as a line (`>`, `R>` in
roundtime, ...; a `matchre X .*` catches it) -- but only when something was shown since the previous
prompt, as in Genie: a prompt right after a prompt (for example after a vitals-only update) is not
shown, matches nothing, and leaves `$prompt` without Genie's `> ` ending. `wait` resumes on every
prompt either way.

### Waiting

Sometimes you need to slow down. Use `pause` (seconds):

```
put stand
pause 1
put open my pack
pause 0.5
put get coin from my pack
```

`pause` with no number waits 1 second. `pause 3` waits 3 seconds. `delay 3` is the same, except
that roundtime does not hold it. `wait` waits for the game's next prompt, and at least 1 second
(`wait 3`: at least 3 seconds). `move north` sends `north` and waits until you are in the next
room; a bare `move` or `nextroom` does nothing. A time Genie cannot add to the
clock (an infinity such as `evalmath t 1/0` stores, or thousands of years) stops the script with
Genie's error message; the same goes for `delay`, `wait` and a `matchwait` timeout.

---

## 7. Variables

Variables let a script remember things. There are three kinds, told apart by their first symbol.

| Symbol | Name | Lives where | Example |
|---|---|---|---|
| `%` | **Local** | Only inside the running script | `%count` |
| `$` | **Global** | Shared by every running script; written to disk only by `#var save` | `$mymode` |
| `$` | **Reserved** | Provided by the game (read-only) | `$health` |

Reserved variables also start with `$`; you just don't create them — the game fills them in
(see [section 13](#13-reserved-variables-reference)).

### Local variables (`%`)

Set one, then use it by writing `%name` anywhere:

```
%target = kobold
echo My target is %target
put attack %target
```

You can also write it the long way with `setvariable` (same effect):

```
setvariable target kobold
```

### Global variables (`$`) — shared now, saved when you say so

Set a global with `$name = value` (or `put #var name value`). A global is shared at once by every
running script and by your triggers, and lasts until Lich exits. It is written to disk **only when
something saves it**, exactly like Genie:

```
put #var mymode hunting
put #var save          # write every saved-type global to variables.cfg
```

- `#var save`, `#save vars` and `#save all` write the file. A plain `#var` never does, and neither
  does a script ending or Lich closing (Genie saves nothing on exit either).
- `#var load` reads the file back in on top of what you have; `#load vars` replaces your saved-type
  globals with the file's.
- `#tvar` (temporary) and `#svar` globals are never written.
- Genie's built-in game variables (`$health`, `$roomname`, `$invisible`, ...) are never written or
  read back: they always come from the game.
- Triggers work the same way: `#trigger save` / `#save triggers` writes `triggers.cfg`,
  `#trigger load` merges it back, `#load triggers` replaces your triggers with it.

When the engine starts -- with your session, at the first game line after you log in with the
engine on (or, if you turn it on later, at the next game line) -- it reads `variables.cfg` and
`triggers.cfg` once, so saved `#trigger`s (a login trigger on `   Last login` too) fire before you
run any `.cmd`. It never re-reads them on its own, so another character's save shows up only
after `#var load` / `#trigger load` or a restart.

> **Where are they saved?** In `variables.cfg` and `triggers.cfg` inside a `GenieProfiles/Config`
> folder next to your scripts — the engine's own folder, not native Genie's. The format is Genie's
> own, so you can copy a Genie `variables.cfg`/`triggers.cfg` in (or out) as-is (a
> `triggers.cfg.untrusted` next to it lists the triggers a script made from game text; Genie
> ignores it; see "Saving keeps this" in section 14). Files written by
> engine versions before 0.12.0 (which saved on every `#var`) still load. An eval trigger
> (`e/.../` or `eval ...`) fires on variable changes, like an eval `action` (see `action`). A trigger whose
> pattern is not a valid regular expression is dropped (typing one echoes
> `Invalid regexp in trigger: ...`; a `triggers.cfg` row with one is skipped without a message).
> The engine checks patterns with Genie's .NET rules, so `[\w-']` works and `a++` or `\Qx` are
> refused, as in Genie (so are Ruby-only forms such as `(?a)` or `\p{Alpha}`). Variable-length
> lookbehinds such as `(?<=a+)b` and inline `(?i)`/`(?-i)` switches work as in Genie, also inside
> `matchre()` / `replacere()` in an `if` or `eval`. A long list of alternatives is fine
> (`(armored )?warklin|...|(?<!arisen \S+ )zombie` matches like Genie). A variable-length lookbehind
> inside a repeated group, or after a variable-length part of its own alternative (`\w+(?<=a+)b`),
> cannot be matched here, and neither can a few rare .NET constructs (balancing groups,
> conditionals on an expression or on a group defined later in the pattern): the trigger, action
> or match is still added, but never fires, and the engine prints one
> `[Genie: ... it will never fire: ...]` line naming the construct (`matchre()` / `replacere()` in
> an `if` or `eval` print it once too, then answer false / leave the text unchanged). A few rare
> .NET constructs are still refused although Genie accepts them (a numbered back-reference to a
> named group, `\p{IsGreek}` block names, octal escapes such as `\377`); a trigger using one is
> dropped.
> If a cfg file cannot be read (for example, another program
> has it locked), the engine starts with that list empty instead of failing.
>
> **One file for every character.** Genie can keep a separate `variables.cfg` per profile
> (`Config/Profiles/<profile>/`). This engine has a single `GenieProfiles/Config/variables.cfg`
> (and `triggers.cfg`) shared by every character in that scripts folder. A save writes the WHOLE
> file from that character's memory, so if character A saves after character B, B's saved changes
> are overwritten by A's copy.
>
> **Upgrading from engines before 0.12.** Those versions saved every `#var` immediately but never
> saved triggers, so a "triggers are loaded" flag such as `triggersloaded` may already be `1`
> in `variables.cfg` with no `triggers.cfg` next to it. A script that checks the flag (for example
> `if ($triggersloaded != 1) then put .loadtriggers`) then skips its loader and waits
> for a trigger that does not exist. Reset the flag in this engine before running such a script:
> run a script with `put #var triggersloaded 0` and `put #var save`. Logging off through a
> quit script that runs in this engine (one that does `#trigger save` and `#var save`) keeps the two
> files in step; a quit script run by native Genie only updates native Genie's files. Any script
> that runs `#var save` mid-session writes the flag as `1` while the triggers are not yet saved, so
> if a session ended without such a quit script, run the reset again. The engine never resets the
> flag by itself (Genie does not either). See PROTOTYPE-TESTING.md, step 2.

### Doing math

Use `math` for simple arithmetic on a variable:

```
%count = 0
math count add 1      # %count is now 1
math count add 5      # %count is now 6
math count subtract 2 # %count is now 4
math count multiply 3 # %count is now 12
```

There's a handy shortcut called `counter` that works on a variable named `%c`:

```
counter add 1   # adds 1 to %c
echo I have looped %c times
```

For a full expression, use `evalmath`:

```
evalmath total (2 + 3 * 4)   # %total becomes 14
echo total is %total
```

Like Genie, `evalmath` stops at the end of the first complete expression (`evalmath x 1+1 = 2` gives 2)
and accepts plain VB numbers (`1,000`, `$5`). An expression it cannot read prints `[Script error in
name.cmd: Invalid expression: ... Local Variable x has been set to 0.]`, sets the variable to 0, and
the script goes on.

### Comparing and testing

`eval` stores the result of a comparison (`1` for true, `0` for false):

```
%hp = 55
eval healthy %hp > 50
echo healthy = %healthy      # prints "healthy = 1"
```

`if`, `while` and `eval` evaluate exactly like Genie's evaluator, quirks included (an unquoted
`1x = 1` gives "1", `!"text"` is not true, a function called with the wrong number of arguments does
nothing). Where Genie's evaluator throws -- `substr` past the end of the text, `element` with a
non-number index, `replace` with an empty search text, an invalid `matchre()` pattern -- the script
prints the error message and stops (Genie itself crashes there).

---

## 8. Making decisions: `if` / `else`

### One-line form

```
if %hp < 30 then put drink my potion
```

### Block form (multiple lines)

Use braces `{ }` to run several lines when the test is true:

```
if %hp < 30 then
{
  echo Health is low!
  put drink my healing potion
  pause 2
}
```

### `if` / `else`

```
if $health > 50 then
{
  put advance
}
else
{
  put retreat
}
```

### `elseif` for several choices

```
if %stance = offense then put attack
elseif %stance = defense then put parry
else echo I do not know that stance.
```

### Comparisons you can use

- `=` equal, `!=` not equal
- `>` greater, `<` less, `>=` at least, `<=` at most

> **Good to know:** numbers compare as numbers (`10 > 9` is true). If either side isn't a plain
> number, they compare as **text**. So `"$roomname" = "Town Square"` compares the room name as text —
> wrap text values in quotes when you compare them.

---

## 9. Loops: labels, `goto`, and `gosub`

### The one surprising rule

In Genie, **`while` does not loop.** It behaves like a one-time `if`. To actually repeat something,
you use a **label** and **`goto`**. This trips up newcomers, so here it is up front.

### A label is a landmark

A label is a word followed by a colon on its own line:

```
top:
```

### `goto` jumps to a label

Here is a counter that loops five times:

```
%c = 0
loopstart:
counter add 1
echo pass number %c
if %c < 5 then goto loopstart
echo done
exit
```

- `goto loopstart` jumps back up to the `loopstart:` label.
- `exit` ends the script (optional at the very end, but tidy).

> **Safety net:** the engine watches for runaway loops. If a loop spins for more than 5 seconds
> without pausing or waiting, it stops the script
> and prints **`[Script timeout in name.cmd(12): Possible infinite loop.]`** followed by
> `Trace follows:` and the last jumps it made. As in Genie, a loop that sends commands quickly but
> finishes is not stopped. This protects you from a
> stuck script. If you see that message, add a `pause` or a proper stopping condition to your loop.
> The limit is Genie's `scripttimeout` setting (milliseconds, default 5000; see
> [Troubleshooting](#15-troubleshooting)).

### `gosub` runs a mini-routine and comes back

`gosub` jumps to a label, runs until `return`, then continues where it left off. Great for reusable
steps. You can pass arguments, read inside as `$1`, `$2`, …

```
gosub greet Traveler
gosub greet Friend
echo all greeted
exit

greet:
echo Hello, $1!
return
```

Output:

```
Hello, Traveler!
Hello, Friend!
all greeted
```

---

## 10. Reacting to the game: `match`, `waitfor`, and `action`

Real scripts wait for the game to say something, then react.

### What your scripts see of the game

Scripts and `#trigger`s see the game the way Genie shows it, line by line as the game sends them:
the main window's text plus every other window except the Room and Inventory windows (thoughts,
speech/talk, combat, familiar, logons, death, spells, ...); a stream that stays open over several
lines reaches them line by line; a room look's description and its "You also see ..." part arrive
as two lines, and so does text before and after a window change inside one game line. Each line
keeps its spaces (only the line break is removed), so a trigger such as `{^   Last login}` matches.
Genie's `parsegameonly`, `showlinks` and `condensed` settings (in `GenieProfiles/Config/settings.cfg`)
work as in Genie. `#trigger`s always fire before any script sees the line.

Everything you SEND (from a script, an action, a `#trigger`, the queue) and everything you TYPE is
also offered to your `#trigger`s and scripts right after it goes out, as Genie does with its
`triggeroninput` setting (on by default; `#config {triggeroninput} {False}` in settings.cfg turns it
off). So `#trigger {^look$} {#echo you looked}` fires when you type or send `look`. A `waitfor` or
`matchwait` that your own sent text satisfies goes on only after the game's next reply has arrived.
A trigger that re-sends its own text is stopped after 20 rounds with a script error (Genie would
crash).

### `waitfor` — pause until a line appears

```
put stand
waitfor You are now standing
put forward
```

The script waits until a line containing "You are now standing" arrives, then continues. As in
Genie, the text must match exactly, including upper/lower case: `waitfor You Stand` does not resume
on "you stand up". For a regular-expression version, use `waitforre`; its capture groups land in
`$1`, `$2`, ... (and the whole match in `$0`):

```
put analyze my tongs
waitforre ^(These tongs are used|This tool is used to shovel)
if "$1" = "This tool is used to shovel" then var tongs.adj 1
```

Genie accepts `/pattern/` and `/pattern/i` around `matchre`, `waitforre` and `action` patterns.
The `i` makes `matchre` and `action` case-insensitive; on `waitforre` Genie drops it and the
pattern stays case-sensitive (the engine copies that).

### `waiteval` — pause until a condition becomes true

Where `waitfor` waits for a *line*, `waiteval` waits for an *expression* to become true — handy for
waiting on a variable or game state that changes as the game goes on:

```
waiteval $roomid = %home.room     # wait until you're back in the home room
waiteval $Time.isXibarUp = 1      # wait for Xibar to rise
```

As in Genie, the condition is checked only when a variable named in it CHANGES: a script `var`/
`math`/`eval`/`save`/`counter`/`evalmath`, a `goto`'s `%lastlabel`, a `#var`/`#tvar`/`#math`, a game
update of a reserved variable (`$health`, `$roundtime`, `$prompt`, `$roomname`, ...), the mapper's
`$roomid` at the prompt after you enter (or look at) a room, a send (`$lastcommand`), `$scriptlist`
(a Genie script starting or stopping, a `#script pause|resume|abort`, and a `#goto` walk starting
and ending -- in Genie that walk is the automapper script, and here too it shows in `$scriptlist`
as `automapper` while you walk), a
`$SpellTimer.*` update. Game text alone never resumes it, and a condition that is ALREADY true when
the `waiteval` starts still waits for the next such change. `random` (`%r`), `shift` and `unvar`
change nothing it can see. Lich's own `;pause`/`;unpause` of a Genie script does not count as a
`$scriptlist` change (only `#script` does), and a script not in the script list yet (still in its
first rows, see `#script`) gets no variable changes, like `#parse`. (It has no timeout — pair it with logic that guarantees the condition will
eventually hold.)

### `#parse` — send a line to your scripts and triggers

`put #parse SOME TEXT` hands "SOME TEXT" to every running script (their `waitfor`, `matchwait` and
`action`s) and to your `#trigger`s, as if the game had sent it. It never reaches the game. Scripts
use it to signal each other, for example a movement helper telling the automapper it is done:

```
put #parse MOVE SUCCESSFUL       # in the helper
matchre MOVE.SCRIPT.DONE ^MOVE SUCCESSFUL   # in the waiting script
```

The script that sends the `#parse` sees it at once, while it is still on that line: its own
`action`s fire, and if the `#parse` comes from one of its actions while it is in a `waitfor` or
`matchwait`, that wait sees it too. It is never stored for later, so a `matchwait` the script
starts AFTER its own `put #parse` row will not see it. As in Genie, a script gets nothing from its
own `#parse` before its first wait (`pause`, `waitfor`, `matchwait`, ...), a script just started
gets nothing from anyone until it is in the script list (see `#script`), and a script paused with
`#script pause` gets no `#parse` text at all (one paused by Lich -- `;pause`, another Lich script --
gets it once it is unpaused). A chain that keeps re-`#parse`ing (an action or `#trigger` re-triggering itself, two
scripts answering each other, or a `#trigger` `#echo` that an action answers with a `#parse`) is
stopped after 20 nested rounds with a script error (Genie itself would crash). As in Genie, what
the engine itself prints -- `echo`, `#echo`, a `#trigger`'s echo, its own messages -- is never fed
back to your scripts or `#trigger`s, so an `#echo` cannot start such a loop.

If a `#trigger`'s action fails (for example an invalid pattern in its `#if`), the rest of THAT
action is skipped and the other triggers and scripts still get the line, as in Genie. Genie says
nothing; the Lich engine prints `--- Lich: genie trigger error: ...` so you can see why.

### `match` + `matchwait` — branch on what happens

Set up several possible outcomes with `match` (each names a label), then `matchwait` pauses until one
of them is seen and jumps to that label:

```
top:
match killed falls to the ground
match missed You miss
matchwait

killed:
echo Target down!
exit

missed:
echo Missed, trying again.
put attack
goto top
```

- `match killed falls to the ground` → if a line contains "falls to the ground", jump to `killed:`.
- `matchwait` → wait for one of the matches (optionally with a timeout: `matchwait 15`).
- Use `matchre` instead of `match` for regular-expression patterns.
- As in Genie, a `matchre`, `waitforre` or `action` pattern that is not a valid regular expression
  (by Genie's .NET rules, see the trigger note above) stops the script with an error line.

Here's a small, generic hunting loop that attacks until the creature dies:

```
huntloop:
match dead falls to the ground
match again a creature
matchwait 20

again:
put attack creature
goto huntloop

dead:
echo The creature is dead.
put search
exit
```

### `action` — a background trigger

An `action` watches **every** incoming line while your script runs and reacts automatically, no
matter what else the script is doing. The form is:

```
action <commands> when <pattern>
```

Example — automatically stand up if you ever get knocked down:

```
action put stand when you are knocked to the ground

# ... the rest of your script does its normal thing ...
top:
put attack creature
matchwait 20
goto top
```

Anytime a line matching "you are knocked to the ground" appears, the action fires `put stand` on its
own.

You can capture pieces of the matching line with `$1`, `$2`, … and use them:

```
action echo I was hit by $1 when hit by (a|an) (\w+)
```

How actions behave (exactly as in Genie):

- **Variables in the pattern are filled in once, when the `action` line runs.** `action goto MOVED
  when %move_OK` uses the value `%move_OK` has at that moment; changing the variable later does not
  change the action. `action remove` fills in variables the same way.
- **One action per pattern.** Defining an action with a pattern that already has one replaces it,
  so an `action` line inside a loop does not pile up copies.
- **Every matching action fires**, in Genie's sorted order of the patterns (not the order you wrote
  them). A `goto` ends the rest of its own action; if several actions `goto`, the last one wins.
- **In the commands**, `$0` is the whole line and `$1`, `$2`, … the captures, with any `"` removed.
  Commands are separated by `;` and any script command works (`var`, `math`, `eval`, `if … then …`,
  `goto`, `pause`, `put`, …). Command words must be lower case: a misspelled or capitalised word, or
  a `#command` without `put`, does nothing (it is not sent to the game). `gosub`, `return`, `{` and
  `}` in an action are a script error and stop the script.
- A line `action <commands>` without ` when ` is a script error and stops the script.
- **Classes remember how they started.** A class keeps the state it had the first time the script
  mentioned it for actions defined later: after `action (c) off` as the first mention, actions added
  to `(c)` start off even after `action (c) on` (the ones that already exist are switched on).

**Eval actions — react to a variable instead of a line.** `action <commands> when eval <expression>`
fires when a variable named in the expression changes and the expression is then true:

```
action goto LOWHEALTH when eval $health < 30
action var hidden.lost 1 when eval ($hidden = 0)
action goto done when eval %flag = 1
```

The same changes that resume a `waiteval` (above) wake it. The expression is checked as written
when the change happens (its variables are NOT filled in when the `action` line runs; an `e/.../`
pattern is, so `e/%x = 1/` is frozen at that moment). As in Genie: the test is "the variable's name
appears in the expression" (so a change of `%a` also re-checks `%ab = 1`), an expression that is
exactly the variable (`eval $standing`) fires on every change without being evaluated, and `$0` in
the commands is the variable's name. A game update fires the eval actions before the text of the
same packet reaches the line actions. An eval action whose commands keep changing the variable it
watches would loop forever (native Genie crashes); the engine stops such a chain after 20 nested
changes with `[Script error: maximum nested dispatch depth (20) exceeded on: variable change ...]`
and stops the script. Only actions that actually FIRE count towards the 20 (`action math y add 1
when eval %y < 20` runs to 20, as in Genie). Variable changes never end a `wait` or a `move`: those
still wait for the game's prompt / next room. A script's own `#var` before its first wait (`pause`, `waitfor`, ...) does
not reach its own eval actions, and a script paused with `#script pause` misses the changes made
while it was paused (one paused by Lich gets them once it is unpaused).

Managing actions:

```
action clear                         # remove all actions
action remove you are knocked to the ground   # remove one by its pattern
```

**Action classes — grouping actions you can switch on and off.** Put a name in parentheses to
assign an action to a *class*, then toggle the whole group at once:

```
action (mapper) goto RETRY when You can't climb that     # define, scoped to class "mapper"
action (mapper) goto FAILED when the path is blocked
action (mapper) off                                      # both mapper actions stop firing
action (mapper) on                                       # ...and start again
```

Classes start **on**, so an action fires as soon as you define it. `off`/`on` also accept
`0`/`1`/`true`/`false`/`activate`/`inactivate`. A common pattern is for an action to switch its own
class off once it has done its job (`action (loop) …; action (loop) off when …`). Note these action
classes are separate from the `#class` used by triggers — you turn action classes on and off with
`action (name) on|off`, not `#class`.

---

## 11. Effects and triggers: `#` commands

Genie scripts use **`#` commands** (sent with `put`) for two kinds of things: **automation** that
Lich runs itself, and **display effects** that a front-end shows. They behave differently in Lich.

### Group A — Automation: triggers, gags, substitutions (work everywhere, right now)

These run in Lich itself, so they work on **any** front-end immediately.

**Trigger** — run command(s) automatically whenever a game line matches, for as long as you're
connected (not just while a script runs):

```
put #trigger {^You are no longer stunned} {put stand} {recovery}
```

Format: `#trigger {pattern} {commands} {class}`. The `pattern` is a regular expression; `commands`
is what to run when it matches (use `$1`, `$2`, … for captured groups); `class` (optional) is a
group name you can switch on/off. Multiple commands are separated with `;`:

```
put #trigger {^(\w+) glances at you} {echo $1 is watching;put face $1} {social}
```

Manage them:

```
put #trigger              # list all loaded triggers ("Active triggers:", pattern=commands)
put #trigger stun         # list only the triggers whose pattern contains "stun"
put #untrigger ^You are no longer stunned   # remove one by its pattern
put #trigger clear        # remove them all
```

A trigger pattern may use `$variables`: they are filled in when the trigger is added, as in Genie.
When several triggers match one line they fire in Genie's order (sorted by pattern), and a trigger's
own `#class` command decides for the triggers after it on that same line.

**Classes turn groups of triggers on and off.** A trigger with a `class` only fires while that class
is on. Classes start **on**; turn them off/on with `#class`:

```
put #class recovery off    # the "recovery" trigger above stops firing
put #class recovery on     # ...and starts again
put #class                 # list the classes ("recovery=True" ...); #class rec lists those containing "rec"
put #class all off         # every class off except "default" ("All Classes InActivated")
put #class +combat -loot   # several at once
```

Like Genie, the class list is re-applied as a whole on every `#class` command: a trigger you add while
its class is off still fires until the next `#class` command switches it off. Only `on`, `true` and
`1` mean on -- anything else (even `yes`) means off. The class `default` stands for triggers with no
class. `#class save` / `#class load` (and `#save classes`) keep the list in `classes.cfg`.

> `put #trigger` prints your loaded triggers to your window, so you can always see what's active —
> handy while testing.

> **A trigger that cannot be matched in time is switched off.** Every game line is checked against
> every trigger, and a few regular expressions (nested repeats such as `(a+)+`) can take a very long
> time on some lines. A trigger pattern gets 1 second per line; if it runs out of time on 3 lines in a
> row, it stops being checked and you see one line: `--- Lich: genie #trigger disabled: /pattern/
> timed out 3 times in a row (add it again to re-enable it)`. It stays in your trigger list (and is
> still saved); add it again with `#trigger` (or `#trigger load`) to switch it back on. Genie itself
> would hang on such a pattern; here the rest of your triggers and scripts keep going.

**Gag** — hide any line matching a pattern:

```
put #gag a small bird flies past
```

From now on, lines containing "a small bird flies past" won't be shown to you.

**Substitute** — rewrite matching text:

```
put #sub {a fierce creature} {*** DANGER ***}
```

Now "a fierce creature" is displayed as "*** DANGER ***".

To undo them:

```
put #ungag a small bird flies past
put #unsub a fierce creature
```

> **Important and reassuring:** gags and substitutions only change what is **displayed**. Other
> scripts, your logs, and the game itself still see the original text. A gag hides a line's
> **text** only: your front end still gets the line's markup -- window streams, the room
> components, the compass, the prompt and its server time -- just as Genie keeps processing them,
> so a gagged line never leaves a window or the room panel out of step. A line that shows nothing
> (markup only) is never gagged. A gag or substitute whose pattern takes too long on a line
> (over a second -- a pattern Ruby's regex engine backtracks on) counts as no match; after three
> such lines in a row it is switched off with a `--- Lich: genie gag disabled: ...` notice (add it
> again to switch it back on).
>
> Patterns are treated as regular expressions. `put #gag ^You see nothing` hides only lines that
> *start* with "You see nothing". A pattern Genie would reject is refused with Genie's message
> (`Invalid regexp in gag: ...`). A replacement may use Genie's `$1`, `${1}`, `$&` and `$variables`
> (filled in when the line is shown; `$roomid`, `$zoneid`, `$zonename`, `$scriptlist` and the
> `$Time.*` / `$<Skill>.*` values there are the last ones the engine read -- the map ones are read
> again at each room update once Lich's map is loaded -- because the line is filtered on Lich's game
> thread, which must not wait on Lich's map). `put #gag` / `put #sub` list them; `#gag save|load`,
> `#sub save|load` keep them in `gags.cfg` / `substitutes.cfg`. One Genie quirk is kept: a gag that
> matches a SCRIPT's name hides that script's command echoes.

Gags and substitutions can belong to a **class**, and `#class` turns them off/on just like it does
for triggers — so you can silence a whole group of filters at once:

```
put #gag {a small bird flies past} {ambience}   # a gag in the "ambience" class
put #class ambience off                          # ...stop hiding it
put #class ambience on                           # ...hide it again
```

A gag/sub with no class follows the `default` class. Class names of gags and substitutions are
matched exactly (upper/lower case matters), unlike triggers -- as in Genie.

**Aliases** -- `put #alias {nx} {recall nexus list}` makes a script's `put nx` send `recall nexus
list` (aliases also apply inside `#trigger` bodies and queued commands, as in Genie); `$1`, `$2`...
and `$0` take the words after the alias. `put #alias` lists them, `#alias save|load` keeps them in
`aliases.cfg`.

### Group B — Display effects: highlights, macros, windows, sounds…

These change how the game *looks or sounds*. Lich announces them in a **universal format** that any
front-end can choose to display. Examples:

```
put #highlight line yellow {a treasure chest}
put #macro {ctrl+a} {attack creature}
put #playsound alert.wav
```

**What happens today:** the commands never cause an error, and your script keeps running normally.
The *visual/audio* effect itself (the yellow highlight, the macro key, the sound) needs a front end
that understands Lich's announcement (a `<genieHook>` tag, docs: hook-protocol.md). No released front
end does yet, and a front end that doesn't would show the raw tag, so the announcements are **off**
unless you turn them on for your character:

```
;e Lich::Genie.hooks_enabled = true     # only with a front end that supports <genieHook>
;e Lich::Genie.hooks_enabled = false    # back to the default
```

While they are off, the effects that carry text still reach you on every front end: `#echo >Window
text` and a `#link`'s text appear in that window (or the main window -- see `#echo` in section 6), and
a command Genie would put into your input box (one holding `@`) is shown in the main window. The
other effects do nothing.

> **A note on `#class`:** classes do double duty. They gate your **triggers** (Group A, working now)
> *and* they can color text via highlights (Group B, front-end-dependent). So `#class x off` always
> stops class-`x` triggers immediately; the coloring part waits on front-end support.

> **Launcher commands do nothing here (N14).** Genie's `#lc` / `#lconnect` / `#lichconnect
> <profile>` start Lich and connect a profile, and `#config lichpath ...`-style rows set up that
> launch (35 of the tester's scripts are such launchers). You are already inside Lich, so the engine only
> prints Genie's `Profile "<name>" not found. Lich was not started.` when no
> `Config/Profiles/<name>.xml` exists, and otherwise does nothing (with front-end effects turned on,
> it hands the command to your front end as a `<genieHook>` effect). `#config` prints its `Set ...` lines as usual. Do not use
> these scripts to switch characters.

> **You don't need to memorize the `#` commands.** If your existing `.cmd` scripts already use them,
> they'll just work (or be safely ignored). This section is here so you know what they are.

### Group C — Controlling other scripts: `#script`

One script can start, stop, pause, or resume another. Starting is just `put .name` (see §4). To
**stop** scripts, use `#script`:

```
put #script abort sk               # stop the script named "sk"
put #script abort all              # stop every running Genie (.cmd) script
put #script abort all except sc    # stop every Genie script EXCEPT "sc"
```

This is how a "sheath and stop combat" or "skin the kill" script cleans up: `#script abort all
except <the-script-that-should-keep-running>`. You can also pause and resume:

```
put #script pause all              # pause every running Genie script (game lines meanwhile are lost)
put #script resume sc              # resume the script named "sc"
put #script reload sc              # stop "sc" and start it again, with the arguments it was started with
```

> **Things worth knowing:**
> - **`all` means your Genie `.cmd` scripts only** — it will *not* stop Lich's own background helpers
>   (the mapper, your other `.lic` scripts, etc.). A stray `#script abort all` can't take down your
>   session.
> - **A script that aborts itself stops right there** — the rows after `put #script abort all` (or
>   `#script abort <its own name>`) never run, as in Genie. If it is part of `abort all`, the rest of
>   the list is still stopped (in list order, as in Genie).
> - **A script just started is not in the list yet.** As in Genie, a script joins the script list
>   only after its first rows have run up to its first wait (`pause`, `waitfor`, `matchwait`, ...) and
>   the script that started it has reached its own next wait (and so on up a chain: scripts started
>   inside one another's first rows all join together, in the order they were started). Until then `#script abort|pause|...`
>   (from itself or anyone) does not touch it, `#parse` text and game lines do not reach it, and
>   `$scriptlist` does not name it. That is why scripts that open with `put #script abort all except
>   <name>` (meaning "stop everything else") keep running even when `<name>` is not their own name.
> - **`$scriptlist` is updated when a script's run ends**, not the moment something changes: right
>   after `#script abort other` in the same run it still names `other`; after the script's next wait
>   it no longer does (Genie stores it at the end of its timer tick). A script you start runs its first
>   rows inside your row, so its first wait does not update it either: right after `put .helper x`
>   replaces a running helper, `$scriptlist` still shows the old value until your own next wait.
>
> - **An aborted script prints Genie's line**: `#script abort`, the replacing of a running copy
>   (`abortdupescript`) and a script error with no `scripterror:` label show `[Script aborted! (Run
>   time: 0.20 seconds): name.cmd]`, and Lich prints no `--- Lich: name was killed` / `has exited`
>   notice for it. Like every line the engine prints, your scripts and `#trigger`s never see it (Genie
>   does not offer it either). A script that simply ends still gets Lich's `--- Lich: name has exited.`
>
> Names match exactly and are case-sensitive (`sc`, `chl`, `cl`; a script started as `.Foo` is named
> `foo`, as in Genie). `#script abort` with no name behaves like `#script abort all` (it stops
> everything) — the same as Genie. Genie's `#script reload` re-reads the file in place at the
> script's next `goto` and keeps its variables; ours restarts the script (a known difference).

---

## 12. Splitting a script into multiple files: `include`

Large setups are easier to manage in pieces. `include` pulls another `.cmd` file's labels into your
script, so you can `gosub` into them.

**`helper.cmd`** (a library of routines):

```
standup:
put stand
waitfor You are now standing
return

restup:
put rest
waitfor You rest
return
```

**`main.cmd`** (uses the library):

```
include helper.cmd

gosub standup
echo I am standing.
gosub restup
echo I am resting.
exit
```

Run `;main` and it will use the routines from `helper.cmd`. The include rules are Genie's, exactly:

- `include` loads **exactly the file you name, from your Lich `scripts` folder** (`$scriptdir`).
  Nothing else is searched -- **not** `scripts/custom`, not another folder.
- **No extension is added:** write `include helper.cmd`, not `include helper` (that looks for a
  file called just `helper` and fails).
- Upper/lower case does not matter (`include Helper.cmd` finds `helper.cmd`), as on Windows.
- A missing file stops the script **before it starts**:
  `[Script error: File not found: helper.cmd]`. An empty (zero-byte) file does the same with
  `[Script error: Unable to load file: helper.cmd]`. Nothing of the script runs in either case.
- An error inside an included file names that file. While the script runs it names both files,
  `[Script error in main.cmd, helper.cmd(3): ...]` (Genie's PrintError); a load error, before the
  main file's name is known, is `[Script error, helper.cmd(3): ...]`.
- Including the same file twice (or the script itself) is harmless: the second one is skipped.
- `include js_arrays.js` is no exception (next section): the file **must be in your `scripts`
  folder**, or the script does not start.

### JavaScript: the `js_arrays` library, `js` / `jscall`, `<% %>` blocks

Genie runs JavaScript with the Jint 4 engine. The engine has no JavaScript engine of its own; it
reproduces what Genie Remix 4.2.4 does with the JavaScript that real scripts use, **including where
that fails**:

- **The community `js_arrays.js` library** (DR-Genie-Scripts `JS_Arrays/`, `Miner/`, `mm_train/`)
  is recognised **function by function**: every version published since 2019 (seven of them; your
  copy may be any) works as it does in Genie, whatever its comments or indentation. Under Genie
  Remix most of its functions do not work: they call `list.length()`, and Jint 4 stops with
  `Property 'length' of object is not a function`. So, exactly as in Genie:
  * `doPush`, `doUnshift`, `doConcat`, `doReplace` and `buildArray` work (`doReplace` exists only
    in the 2025 JS_Arrays copies, `zipArrays` only since 2024: elsewhere they are "not defined");
  * `doPop`, `doShift`, `doInsert`, `doRemove`, `findIndex`, `checkExists`, `doXCompare`,
    `buildArrayStr`, `findMax`/`findMin` (and the `Index`/`Global` variants) and `zipArrays` print
    `[Script error in name.cmd(<line>): Property 'length' of object is not a function]`, change
    nothing, and a `jscall` stores `undefined` in its variable; `doSort` does the same for the orders
    `0` and `1` (any other order leaves the list as it is);
  * an array variable that does not exist reads as the text `undefined` (`doConcat("new", "a")`
    gives `undefined|a`);
  * older copies differ in small ways, reproduced too: before 2024 `doPush` does not reuse an empty
    first element and some functions read `"$name"` literally; in the 2019-02 and 2022 copies a
    `%name` whose value starts with `$` is then read as a global.
  The script goes on after such an error. `include js_arrays.js` needs the file in your `scripts`
  folder, as in Genie (without it: `[Script error: File not found: js_arrays.js]`, and the script
  does not start); include it before the first `js` line runs, or the functions are "not defined".
- **`js` / `jscall` lines** may call `setVar`, `getVar`, `setGlobal`, `getGlobal`, `echo` and `put`
  (Genie's own JavaScript helpers) and the `js_arrays` functions, with text and number arguments:
  ```
  js setVar("target", "goblin")        # %target = goblin
  jscall where getGlobal("roomid")     # %where = $roomid
  js doPush("loot", "%item")           # the library reads %item itself
  ```
  The line is handed to JavaScript as written: `%name` / `$name` are NOT replaced first (the library
  functions look `%name` up themselves); in an `action`, `$1`... are replaced, with any `"` removed.
  A JavaScript error is printed as `[Script error in name.cmd(<line>): <message>]` and the script
  goes on; a `jscall` then stores `undefined`. Number typos are reported as Genie reports them
  (`1__000`: "Only one underscore is allowed as numeric separator").
- **`<% ... %>` blocks** run when the script reaches the next ordinary line. A block of plain calls
  (`setVar(...)`, `put(...)`, ...) runs; the two corpus blocks that do more are recognised: SkillData's
  sort (fails as in Genie) and ubercombat's `TEXT_TO_NUMBER` ("twenty-three" -> 23, as `AMMO_SET`
  uses it). An error inside a block prints `[Javascript error in name.cmd(<line>): <message>]` and
  stops the script (or jumps to its `scripterror:` label); the `js_arrays` functions are then gone
  for the rest of that script, as in Genie.
- **Write `<%` and `%>` on lines of their own.** A line that starts with `<%` and ends with `%>`
  (`<% setVar("a", "1") %>`) does NOT end the block in Genie: every following line up to one ending
  with `%>` becomes JavaScript too, and the block then fails with `[Javascript error in
  name.cmd(<line>): Unexpected token '>' (<anonymous>:1:<column>)]` -- the script stops (or jumps to
  `scripterror:`). The engine does exactly the same.
- **Anything else** -- other JavaScript (operators, `var`, objects, member calls), or a function of
  `js_arrays.js` that you (or a copy we have not seen) changed -- cannot be run here. The engine
  tells you in the window, with the reason, when the script reaches it:
  `[Genie: #jscall not supported in the in-Lich engine: doPop("loot") (doPop() -- a function body
  this port does not recognise ...)]`, and goes on. Only that function is affected; the rest of the
  file still works. **Beware loops:** a `jscall` that is not supported leaves its variable as it was
  (Genie would store a result), so a loop such as `jscall item doPop("loot")` ... `if "%item" !=
  "undefined" then goto LOOP` can spin forever. In Genie itself `doPop` never works (it always gives
  `undefined`), so such loops end at once there; use an unchanged `js_arrays.js`, or stop the script.

---

## 13. Reserved variables reference

Reserved variables are filled in by the game, exactly as Genie Remix 4.2.4 fills them in (the engine
reads the same game stream Genie reads). You mostly **read** them. If a script sets one with `#var`,
your value holds until the game next updates that variable, and then the game's value wins again,
as in Genie. Names are case-sensitive: `$health` works, `$Health` does not.

### Vitals

| Variable | Meaning |
|---|---|
| `$health`, `$mana`, `$stamina`, `$spirit`, `$concentration` | Current values (0-100) |
| `$healthBarText`, `$manaBarText`, `$spiritBarText`, `$staminaBarText`, `$concentrationBarText` | The bar's text, e.g. `Health 87%` |
| `$encumbrance` | Encumbrance level |

```
if $health < 40 then put drink my potion
```

Genie has no `$maxhealth`-style variables, so neither does the engine.

### Your room

These hold the game's own text, as Genie shows it:

| Variable | Meaning |
|---|---|
| `$roomname` | The room's title (brackets removed) |
| `$uid` | The game's room number from the title, or `0` |
| `$roomdesc` | The room description (double quotes removed) |
| `$roomexits` | The exits line, e.g. `Obvious paths: north, east.` |
| `$roomobjs` | The objects line, e.g. `You also see a goblin, a rat which appears dead and a rock.` |
| `$roomplayers` | The players line, e.g. `Also here: Foo who is lying down.` |
| `$monstercount` | Number of creatures (bold names), not counting any whose name contains an entry of `monstercountignorelist` (default `appears dead\|(dead)`) |
| `$monsterlist` | Those creatures, comma-separated, e.g. `a goblin, a kobold that is lying down` |
| `$north`, `$south`, `$east`, `$west`, `$northeast`, `$northwest`, `$southeast`, `$southwest`, `$up`, `$down`, `$out` | `1` if that exit exists, else `0` |
| `$roomid` | Current room's Genie room number (`0` if the room isn't mapped yet) |
| `$zoneid` | The Genie map zone of the current room; it keeps the last zone while you're in an unmapped room |
| `$zonename` | That zone's name from the Genie maps, e.g. `Crossing` (`0` before any zone; the previous name in a zone with no Genie map) |

```
if $north = 1 then put go north
if matchre("$roomobjs", "which appears dead") then put loot
```

A new room description clears `$roomobjs`, `$roomplayers` and `$roomexits` until the game sends
them again. `monstercountignorelist`, `prompt`, `promptforce` and `roundtimeoffset` are read from
`settings.cfg` in the engine's Genie config folder (`#config {key} {value}` lines, as Genie writes
them), and a script's `put #config monstercountignorelist ...` (or `roundtimeoffset`, `prompt`,
`promptforce`) changes them at once, as in Genie.

`$roomid`, `$zoneid`, `$zonename` and `$game` follow the game even if your `variables.cfg` holds an
old copy: a script's own `#var roomid ...` lasts until the next room you enter, as in Genie. A
`#var zoneid ...` / `#var zonename ...` lasts until you walk into another zone -- the change takes
over at the first prompt after the new room's title, where Genie's automapper loads the new map.
`#var game ...` lasts for good (Genie sets `$game` only when you connect).
In a zone with no Genie map (festival areas, for example) `$zonename` keeps the previous zone's name.

**Moving by room number.** `put #goto <room>` walks you to a Genie room number using Lich's own
pathfinder (go2), and `$roomid` tells you the room you're in — so the classic Genie pattern works:

```
if $roomid != 8 then put #goto 8
```

As in Genie, `#goto` does not hold your script: it echoes `#goto <room>`, sets `$destination`,
announces `DESTINATION FOUND` (as if `#parse`d) and returns at once while the walk runs on its own --
your next lines run and your actions keep firing. While it walks, `automapper` is in `$scriptlist`.
When it ends you get Genie's automapper lines, `YOU HAVE ARRIVED!` then `AUTOMAPPER: YOU HAVE
ARRIVED!` (or `MOVE FAILED` then `AUTOMAPPER: MOVEMENT FAILED!`), delivered to every script and
`#trigger` like a `#parse` -- so wait for them the Genie way:

```
put #goto 8
waitforre ^YOU HAVE ARRIVED|^MOVE FAILED
```

A room it cannot place gives `[AutoMapper] Destination ID #8 not found - your current location is
unknown.`, `$destination` 0 and `DESTINATION NOT FOUND`; a room name instead of a number (Genie's
map notes, e.g. `#goto bank`) is never found here. The number is a room of the zone you are in, as
in Genie: in a zone Lich's map knows the Genie numbers of, a number that zone has no room for is not
found (it is never taken as some other room). Only when the room you stand in carries no Genie
number in Lich's map is the number tried as a Lich room number (then a game room id) -- a stand-in
for the rooms Genie's own map would know. If you are already in that room, or Lich does not
know where you are, nothing walks and no ARRIVED line comes (Genie's mapper does the same). A second
`#goto` replaces a walk in progress, and `#script abort automapper` (or `#script abort all`) stops it.
The walk outlives the script that started it. `#go`, `#g`, `#walk` and `#walkto` are the same
command, as in Genie; a bare `#goto` prints `[AutoMapper] Goto - please specify a room id to travel
to.` and sets `$destination` 0. (`#path` does nothing here: it needs Genie's own map.)

The walk runs as a small hidden Lich script named `automapper1` (2, 3, ...; not in `;list`), which
runs go2 the way Lich's own travel helper does -- standing up, opening a shop door that blocks the way,
retreating when you get engaged. Stopping the walk (or `;kill automapper1`) stops that script and the
go2 it started; a go2 you (or another script) started yourself is never touched.

Genie room numbers are matched to Lich's map behind the scenes. A room that hasn't been matched yet
reports `$roomid = 0` ("location unknown"), just like Genie's mapper when it's lost.

### Your hands

| Variable | Meaning |
|---|---|
| `$lefthand`, `$righthand` | What's in each hand ("Empty" if nothing) |
| `$lefthandnoun`, `$righthandnoun` | Just the one-word noun of the held item (e.g. `sword`) |
| `$lefthandid`, `$righthandid` | The item's game id (empty when the hand is empty) |

```
if "$righthand" = "Empty" then put get my weapon
put stow $lefthandnoun
```

### Status

Each of these is `1` when true, `0` when false:

`$standing`, `$kneeling`, `$sitting`, `$prone`, `$hidden`, `$invisible`, `$bleeding`, `$dead`,
`$stunned`, `$webbed`, `$joined`, `$poisoned`, `$diseased`

```
if $standing = 0 then put stand
if $bleeding = 1 then put tend my wounds
```

### Spell timers (the SpellTimer plugin)

The engine includes the SpellTimer plugin Genie users install. It reads the game's active-spells
window and sets, for each spell it has seen (name with spaces, apostrophes and hyphens removed):

| Variable | Meaning |
|---|---|
| `$SpellTimer.MyBuff.active` | `1` if the spell is listed, else `0` |
| `$SpellTimer.MyBuff.duration` | Roisaen left; `999` for OM/Indefinite; `0` when the game gives no number |
| `$SpellTimer.StellarCollector.charge` | Stellar Collector's charge percent |

```
if $SpellTimer.MyBuff.active = 0 then put cast mybuff
```

Like the plugin, these are ordinary saved variables: a spell the engine has never seen listed is
not defined, and `#var save` writes them.

### Your spell

| Variable | Meaning |
|---|---|
| `$preparedspell` | The spell you have prepared (`None` if none) |
| `$spelltime` | Seconds since you started preparing it (`0` with none) |
| `$casttime` | The game's cast-ready time stamp (a server time, not a countdown) |
| `$spellpreptime`, `$casttimeremaining` | Preparation length and the seconds left of it |

### Time

`$unixtime` (seconds since 1970) is updated each time a game prompt arrives (use `@unixtime@` for
the live clock):

```
var nextcast @unixtime@
math nextcast add 60
# ...later...
if $unixtime > %nextcast then put cast myspell
```

Also available, with Genie's exact formats: `$time` (`02:05:09 PM`), `$time24` (`14:05:09 PM`),
`$date` (`8/18/2026`), `$datetime`, `$datetime24`, `$militarytime`, `$year`, `$dayofmonth`,
`$dayofyear` (`5`, not `005`) and `$month` — which, as in Genie, is the current **minute**.

**Day/night and moons (the TimeTracker equivalent).** Scripts that gated on Genie's
TimeTracker plugin work unchanged — these are bridged to Lich's **moonwatch**:

| Variable | Meaning |
| --- | --- |
| `$Time.isDay` | `1` during the day, `0` at night |
| `$Time.isXibarUp` | `1` when Xibar is above the horizon |
| `$Time.isYavashUp` | `1` when Yavash is above the horizon |
| `$Time.isKatambaUp` | `1` when Katamba is above the horizon |

> Requires **moonwatch** to be running (it feeds the moon/day data, the way the
> TimeTracker plugin did in Genie): `;e autostart('moonwatch')`. If moonwatch has no
> data yet, `$Time.*` falls back to any value your script set with `#var` — so scripts
> that self-populate `$Time.*` from `observe` still work.

### Skills & experience (the EXPTracker equivalent)

Per-skill training data, sourced from Lich (no plugin needed). Use the skill name with spaces
written as underscores (e.g. `Small_Edged`, `Targeted_Magic`):

| Variable | Meaning |
|---|---|
| `$<Skill>.LearningRate` | Mindstate / learning rate (0–34; 34 = mind-locked) |
| `$<Skill>.Ranks` (or `.Rank`) | Skill ranks |
| `$<Skill>.Percent` | Percent toward the next rank |

### Other

| Variable | Meaning |
|---|---|
| `$roundtime` | Round time at the last prompt (it does not count down between prompts) |
| `$gametime` | The game's clock at the last prompt |
| `$prompt` | The last prompt with Genie's status letters, e.g. `HR> ` (hidden, in round time); just `>` (`>HR`, ...) when nothing was shown since the prompt before it, as in Genie |
| `$lastcommand` | The last command sent to the game (by you, a script or a trigger) |
| `$lastinput` | The last command you typed -- an ordinary saved variable in Genie (it shows in `#var`, `#var save` writes it, `#unvar` removes it until you type again) |
| `$charactername`, `$gamename`, `$game` | Your character and the game |
| `$client`, `$version` | `Genie Remix Client 4`, `4.2.4.0` |
| `$scriptdir`, `$mapdir`, `$plugindir`, `$logdir`, `$artdir`, `$sounddir` | The engine's script folder, and folders under its Genie config folder |
| `$scriptlist` | `\|`-joined names of your listed Genie scripts (no `.cmd`), or `none`; updated when a script's run ends (see `#script`) |
| `$repeatregex` | The pattern `do` retries on |

`%lastcommand` (a script's own variable) is the last text that script sent with `put`.

> If you know a Genie reserved variable that isn't listed here, please report it with its exact
> name.

---

## 13b. Surfacing creature IDs in ASSESS (opt-in, an addition Genie lacks)

DragonRealms tags every creature in the `assess` combat stream with its **exist-id**, but Lich
normally strips that tag before your script sees it, so the id is gone from the visible text. Some
front ends re-add it as `[#nnnnn]`, and Genie scripts written against them capture the id with a
pattern such as `\[#(\d+)\]`. That ties those scripts to one front end.

The **assess-ids shim** moves that surfacing into Lich. **Genie itself has no such feature**: this
is an addition, so it is off by default. When on, it re-emits each assess creature line with the
id spliced back into the visible text, where such a front end puts it:

```
You (1) are facing an elder Adan'f sorcerer [#78195083] (2) at melee range.
```

A pattern that expects the id then works unchanged:

```
matchre Target ^You .*facing .*\[#(\d+)\]
put assess
matchwait
# $1 now holds the creature's exist-id
```

Who sees the added lines:

- **In-Lich engine:** your Genie scripts and `#trigger`s, right after the assess output they belong
  to, and only while the engine is on (`Lich::Genie.enabled?`). With the engine off, nothing is
  added.
- **Native Genie in front of Lich** (Lich started with the Genie front end): the lines go to
  Genie's game window, so Genie's own scripts can match them.
- **Lich scripts (`.lic`) never see them.** They get the game text exactly as without the shim.

The normal assess output and Lich's own creature tracking are untouched.

### Turning it on

It is **off by default** and set **per character** (like the engine toggle). Turn it on with:

```
;e Lich::Genie::AssessIds.enabled = true
```

(If your front end uses `,` as its Lich command character, type `,e` instead of `;e`.)

- **In-Lich engine:** that's it. The shim re-arms itself each session when the engine starts (at
  login, see Step 1), so you set it once.
- **Native Genie in front of Lich:** the setting persists, but the hook must be re-installed each
  login. Add this line to your Lich autostart (for example a small `.lic`, or your existing startup
  script); it does nothing while the setting is off:

  ```ruby
  Lich::Genie::AssessIds.install!
  ```

Check status any time:

```
;e echo Lich::Genie::AssessIds.enabled?   # saved on/off
;e echo Lich::Genie::AssessIds.active?    # hook armed this session?
```

Turn it back off with `;e Lich::Genie::AssessIds.enabled = false` (it stops at once).

---

## 14. Running, listing, and stopping scripts

- **Run a script:** `;name` (leave off `.cmd`). Example: `;mytest`.
- **Pass information to a script:** type it after the name. `;mytest kobold 3` makes `%1` be
  `kobold` and `%2` be `3` inside the script; `%0` is all of them (`kobold 3`) and `%argcount` is
  how many (`2`). As in Genie, `%1`..`%9` are always defined (empty when not given), so
  `if ("%1" = "")` works with no arguments. Arguments are split like Genie: `"two words"` (or
  `{two words}`) is one argument, and an underscore becomes a space (`;mytest red_gem` makes `%1`
  be `red gem`). `$1`, `$2`, … are NOT the script's arguments: they hold `gosub` arguments and
  `matchre`/`action` captures (at the top of a script they are empty and `$argcount` is `-1`).
  `shift` drops `%1` and moves the rest down (`%argcount` goes down by one, `%0` is rebuilt).
  There is no `quiet` argument: `;mytest quiet` passes the word `quiet` as `%1`.
- **See what's running:** `;list`
- **Stop one script:** `;kill name` (or `;k name`)
- **Stop everything:** `;killall`
- **Pause / unpause a script:** `;pause name` / `;unpause name`: while paused the script runs
  nothing and its waits do not end; the game lines that arrive meanwhile are KEPT and handled after
  `;unpause`, before a wait whose time ran out during the pause gives up (a `matchwait 5` paused for a
  minute still matches the reply that came in the pause). The buffer keeps the last 400 items (game
  lines plus the engine's own prompt/roundtime/variable notices), so a very long pause in a busy
  room can lose the oldest. The same holds when another Lich script pauses it (`pause_script`,
  `DRC.pause_all`, ...). Only Genie's own `#script pause` drops them, as Genie does (a decided
  difference, D7: Genie has no outside pauser, and a dropped reply would hang a `waitfor`).

### Launching one script from another

Inside a script, a command that begins with a period (`.`) **launches another script** instead of
being sent to the game — exactly like Genie's `.scriptname`:

```
put .setup            # runs setup.cmd
put .buffs full       # runs buffs.cmd with %1 = "full"
send .helper          # send works too (once the command queue releases it)
```

The first word after the `.` is the script name, lower-cased (it also ends at a `{`, so `put
.child{a b} c` runs `child` with `%1` = `a b`); anything after it becomes that script's `%1`, `%2`, … arguments, split
the same way as typed arguments. `put .child %0` passes your arguments as ONE text that the child
splits again, so an argument you received as `"two words"` or `two_words` arrives as two separate
arguments (`two`, `words`), exactly as in Genie. A Lich script calling `start_script('child',
['two words'])` gets the same treatment: the list is joined with spaces and split again.

Exactly like Genie, `put .name` runs **`name.cmd` from the Lich scripts folder (`$scriptdir`) and
nothing else**: no `.lic`/`.rb` script of that name, no `custom/` subfolder, no "first script whose
name starts with ..." guess (`put .wait` never starts Lich's `wait.lic`). `put .name.cmd` works too,
and the name may differ in upper/lower case from the file's. A missing file prints `[Script error:
File not found: name.cmd]`, an empty one `[Script error: Unable to load file: name.cmd]` (`put .`
alone looks for `.cmd`). To run a Lich script, use `,name` (below).

The new script's first rows -- up to its first wait -- run before your next row, as in Genie (your
script waits for them, at most 6 seconds), so a variable it sets at once is there when you read it.
After that both run side by side. A launch from a `#trigger` your script set off itself (its own
`put #parse`, a variable it changed) waits the same way; one from a `#trigger` fired by the game, or
from a queued command, does not wait.

**Starting a script that is already running replaces it** (Genie's `abortdupescript`, on by default
and read from your `settings.cfg`): the running copy is stopped and the new one starts with the new
arguments -- `put .hunt next` from inside `hunt.cmd` restarts it, which many scripts rely on. With
`#config {abortdupescript} {False}` in settings.cfg both copies run. (A copy started in the same run
that is not in the script list yet is not replaced.)

**Same-named Lich scripts.** The replacing above, `#script abort` and `$scriptlist` only know your
Genie (`.cmd`) scripts. If a Lich script of the same name is running too -- dr-scripts has `train`,
`wait`, `pick`, `repair`, `steal`, `tip`, `smoke`, `sorcery`, `t2`, `om`, `arrows`, `bolts`,
`tinker`, all names some Genie script collections also use -- `put .train` starts `train.cmd`
beside `train.lic`, and Lich's own `;kill train` stops whichever of the two Lich finds first. Use
`put #script abort train` (from a Genie script) to stop the Genie one.

> Ordinary commands are unaffected — `put attack kobold` still goes to the game. Only a leading `.`
> means "launch a script."

#### Running a **Lich** script or command (`,name` / `;name`)

A command that begins with a **Lich command character** (`,` or `;`) is run by **Lich**, exactly as
if you had typed it into your client — so you can launch a Lich `.lic` script (like `go2`) or use any
Lich command from inside a Genie script:

```
put ,go2 2572         # walk to room 2572 via Lich's go2  (send ,go2 2572 works too)
put ;kill mapper      # any Lich command works: kill/pause/list/…
```

This is the counterpart to the `.` launcher above: `.name` launches a **Genie** script; `,name` /
`;name` runs a **Lich** script or command. (Both `,` and `;` are accepted regardless of which one
your front-end uses.)

> **Only what you wrote yourself runs as a Lich command (safety rule).** Genie in front of Lich passes
> any text starting with `,`/`;` on to Lich, so another player's words relayed by a script -- a follow
> script's `action put $1 when ^Mallory whispers, "do (.*)"$` fed `,e <Ruby code>` -- would run as a
> Lich command. This engine deliberately does not (a decided difference from Genie, "D10"). Two rules:
>
> 1. **A Lich command (`,go2`, `;kill`, ...) runs only when you wrote its `,`/`;` and its name
>    yourself**, before any variable or captured `$1` is filled in. The name (`go2`, `kill`, the
>    word up to the first space) must be typed out: its arguments may be variables (`put ,go2
>    %dest`), the name may not:
>    - in a `put`/`send` line of a `.cmd` file -- `put ,go2 %dest`, `put ,go2 $home`, `send 2 ,go2 2572`;
>    - in the body of an `action`, a `#trigger` or an alias that **you** defined: an `action` line of
>      a `.cmd` file; a `#trigger`/`#alias` in your `triggers.cfg`/`aliases.cfg`, or defined by a
>      `put #trigger ...`/`put #alias ...` line in which no variable is filled in, or by one of your
>      own `#trigger` bodies that no capture filled in. An alias is used through a name that starts
>      with `,`/`;` (`#alias {,gh} {,go2 home}`, then `put ,gh`).
>
>    A definition made from anything else -- an action body, a `#trigger` body with a `$1` filled in,
>    a line in which a variable was filled in (`put #trigger {^x} {%cmd}`), a queued `send`, JavaScript
>    -- is not yours: its `,`/`;` lines go to the **game** as text. So does every `,`/`;` that only
>    appears once a variable or a `$1` is filled in (`put %x`, `send %x`, a `{$2}` trigger body), and
>    every command whose name holds a `%`, `$` or `@` (`put ,%cmd`, `put ;%x args`, `put ,pro%x`,
>    `action put ,$1 when ...`, a `{,$1}` trigger or alias body), whether or not such a variable
>    exists, so another player's words can never pick which Lich script runs; the game just answers
>    "Please rephrase that command".
> 2. **A Lich command that runs code -- `,e`/`,eq`/`,exec`/`,execq` and `,execname`/`,en` (Ruby), and
>    `,lich5-update`/`,l5u` (installs Lich code) -- runs only from a `put` line of a `.cmd` file in
>    which nothing at all is filled in**: `put ,e $T2.reload_settings` works while there is no
>    Genie variable `T2`. From anywhere else -- a `send` line (it is queued), any `action`, `#trigger`
>    or alias body (even your own), `put ,e %x`, `#send`/`#put` -- it goes to the game as text.
>
> These used to reach Lich and now go to the game as text: a Lich command inside `#send`/`#put`/
> `#queue`/`#event` (also when an `#if` runs one), after `move` or `do`, from JavaScript (`js
> put(",go2 1")`), as a `gosub` argument (`gosub go ,go2 1` then `put $1 $2`), after a delay variable
> (`send %d ,go2 1`), escaped (`put \,go2 1`), a repeated command (`put %lastcommand` /
> `send 1 $lastcommand` after `put ,go2 1`), a command whose name is a variable or a capture (`put
> ,%cmd`, `put ;%x args`, `action put ,$1 when ...`, `#trigger {...} {,$1}`), or as the value of an
> alias whose name does not start with `,`/`;`. Write it as its own `put`/`send` line, with the name
> typed out, instead (`put ,go2 %dest`; for a choice of scripts, an `if` per script).
>
> **Saving keeps this.** `#trigger save` / `#alias save` (and `#save triggers|aliases|all`) write
> `triggers.cfg` / `aliases.cfg` exactly as Genie does, plus a small file next to each,
> `triggers.cfg.untrusted` / `aliases.cfg.untrusted`, that lists the triggers and aliases a script
> made from game text. When the file is read back (`#trigger load`, `#load triggers`, `#alias load`,
> the next session), those stay game text under rule 1; every other row counts as yours, and so does
> a row you edit by hand. No such file means none was needed. If the file is damaged, nothing read
> with it counts as yours, and the engine says so once (`triggers.cfg.untrusted is unreadable:
> ...`); a save then lists every one of those rows. Once you have checked that every row of
> `triggers.cfg` is your own, delete the damaged file and `#load triggers` (or `#load aliases`). If
> the `.untrusted` file cannot be written, the save stops there with a line saying so, and
> `triggers.cfg` / `aliases.cfg` stay as they were.

> **Matching what Lich prints back.** Text that **Lich** echoes — go2's *"You're already there,"* a
> *"--- Lich: &lt;script&gt; has exited"* notice (of a Lich script, or of a Genie script that ended
> normally; an aborted Genie script prints Genie's own line instead), or output from another script — is visible to
> your `matchwait`/`matchre` **and** your `#trigger`s, just like game text. So you can `matchre Done
> You're already there` after a `put ,go2 …` and it will fire. (Genie has no such text; this is an
> addition of the Lich engine.) What the Genie engine prints itself -- `echo`, `#echo`, a trigger's
> echo, its `--- Lich: genie ...` messages -- is never offered, as in Genie. A Lich command a script
> sends (`put ,go2 2572`) is recorded in `$lastcommand` like any command, as Genie behind Lich does.

Example script that uses arguments:

```
# Run with:  ;mytest kobold 3
echo I will attack %1, and repeat %2 times.
%c = 0
loop:
counter add 1
put attack %1
matchwait 15
if %c < %2 then goto loop
exit
```

---

## 15. Troubleshooting

**"My `.cmd` script gives errors about syntax / `eval` / `matchre`."**
The engine is probably **off** for this character, so Lich is trying to read your `.cmd` as an old
Wizard script. Turn the engine on:

```
;e Lich::Genie.enabled = true
```

Confirm with `;eq echo Lich::Genie.enabled?` (should be `true`), then run your script again.

**"I turned it on, but after relogging it's off again."**
First make sure you're on a current testing build — re-run the update and restart Lich:

```
;lich5-update --branch=MahtraDR:feature/genie-scripting-engine
```

The setting is saved per character; verify what's stored:

```
;eq echo Lich.db.execute("SELECT * FROM lich_settings WHERE name LIKE 'genie_enabled:%';")
```

You should see a row for your character with the value `true`. If it says `true` but the engine
still acts off after a fresh login, please report it (see below) — that's exactly the kind of thing
testers help catch.

**"I see 'Possible infinite loop' and my script stopped."**
A loop ran too fast or forever. Add a `pause` inside the loop, or a proper stopping condition (a
`match`/`matchwait`, or an `if ... then goto done`). See [section 9](#9-loops-labels-goto-and-gosub).

**"Why didn't my script start?"**
Before a script runs, the engine reads the whole file (and every `include`) the way Genie does, and
refuses to start it on any of these -- you see one line like `[Script error(14): ...]` (the number is
the line in the file; `[Script error, helper.cmd(3): ...]` for a line in an included file) and
nothing of the script runs:

- `Unknown script command: <line>` -- a line that is not a Genie command: a typo, or a `#`
  command after `then`/`else` without `put` (`if %x then #echo hi` is refused -- write
  `if %x then put #echo hi`; a line that STARTS with `#` is a comment).
- `Invalid IF statement: <line>` -- an `if` without `then`; `Invalid WHILE statement: <line>` -- a
  `while` without `do` (lower-case `do` only: `while x DO ...` is invalid too).
- `File not found: <name>` / `Unable to load file: <name>` -- an `include` (or the script itself)
  that is missing or empty. See [section 12](#12-splitting-a-script-into-multiple-files-include):
  the file must be in the `scripts` folder, named exactly, extension included.

A label that appears twice is only a warning: `[Script error(20): Replacing duplicate label: name]`
is printed at the start, the script runs anyway, and the LAST copy of the label is the one used.

Genie's `ignorescriptwarnings` setting decides how strict this is. It is **False** unless you set it,
as in Genie: then unknown commands stop the load and duplicate labels warn. Set to True, unknown
command lines are skipped silently and the duplicate-label warning is not shown. It never lets an
invalid `if`/`while` or a missing/empty include through. Set it in
`GenieProfiles/Config/settings.cfg` (`#config {ignorescriptwarnings} {True}`, as Genie writes it), or
from a running script with `put #config ignorescriptwarnings True` (it applies to the next script
that loads).

**"My script printed a `[Script error in name.cmd(12): ...]` line and stopped."**
Something failed while it ran: a `goto`/`gosub` to a label that does not exist, a `return` with no
`gosub` to return to, a label reached inside a `{ }` block, an invalid `math`, a bad regular
expression in `matchre`/`waitforre`/`do`, a `timer setstart` date it cannot read, or more than 50
nested `gosub`s (`Maximum GOSUB depth (50) on: label`, then a trace). The text of the last error is in
`%lastscripterror`. As in Genie, a script can catch these: if it has a label named `scripterror:`,
the engine prints `[Script moving to scripterror label (name.cmd)]` and the script carries on from
that label instead of stopping:

```
goto %1
exit
scripterror:
echo Something went wrong: %lastscripterror
exit
```

Keep the `scripterror:` section itself free of errors: an error inside it sends the script back to
`scripterror:` again, over and over, until you `;kill` it (Genie does exactly the same).

Two more Genie settings, read from `settings.cfg` or changed with `put #config <name> <value>`:
`scripttimeout` (milliseconds a loop may run without waiting before "Possible infinite loop",
default 5000) and `maxgosubdepth` (how many `gosub`s may be nested, default 50).

**"My script prints lots of lines with its file name and line numbers."**
It contains a `debug N` (or `debuglevel N`) line: Genie's debugging output, shown as in Genie.
Each line starts with the file and line (`name.cmd(12): ...`). Levels 1-9 show everything up to that
level (jumps, waits, variable changes, `if` results, actions...); 10 shows every line as it runs.
`debug 0` turns it off. While debugging is on (and `ignorescriptwarnings` is False), an `if`/`eval`
that still contains a `%` or `$` -- usually a variable that was never set -- also prints
`[Script error in name.cmd(12): Eval (...) contains variable character '%'. Did you use an unassigned
variable?]`; the script keeps going. Remove or comment out the `debug` line to silence all of this.

**"A highlight/macro/sound in my script does nothing."**
Those are front-end effects (Group B in [section 11](#11-effects-and-triggers--commands)).
The automation still runs; the visual/audio part needs a front end that supports Lich's `<genieHook>`
announcement, turned on with `;e Lich::Genie.hooks_enabled = true` (off by default).
Gags and substitutions (Group A) work everywhere right now.

**"My `.wiz` scripts stopped working."**
That's expected while the engine is on. Turn it off (`;e Lich::Genie.enabled = false`) to use `.wiz`
again, or convert them.

**"A variable prints literally, like `%count` or `$mymode`, instead of a value."**
That variable was never set (undefined variables are left as-is). Set it first, and check spelling —
`%local` and `$global` are different variables even with the same name.

---

## Reporting problems (you're a tester)

This is a preview, and your feedback is what gets it merged into official Lich. If something doesn't
work or looks wrong, note it down and send it to the branch maintainer (fork `MahtraDR/lich-5`,
branch `feature/genie-scripting-engine`). Helpful details:

- What you did (the exact command or the script you ran — feel free to trim/rename it).
- What you expected vs. what happened.
- Any error text you saw in your window.
- Your character's game and name (so per-character behavior can be checked).

Small, specific reports ("`;foo` printed X but I expected Y") are the most useful.

---

## 16. Frequently asked questions

**Do I have to convert my Genie `.cmd` scripts?**
No. Put them in your `scripts` folder and run them.

**Will this change my other characters?**
No. It's per character. Enable it only where you want it.

**Will it touch my `.lic` scripts?**
No. Only `.cmd` files are affected, and only when the engine is on.

**Is it safe to turn on and off repeatedly?**
Yes. It's a simple toggle with no side effects.

**Where are my saved (`$`) variables kept?**
In `GenieProfiles/Config/variables.cfg` near your scripts, written only by `#var save` / `#save vars`
/ `#save all` (triggers: `triggers.cfg`, `#trigger save`). The folder is shared by your characters,
like one Genie install; each Lich session reads it once at start.

**Can I run more than one `.cmd` at once?**
Yes, just like other Lich scripts. They share your saved global variables.

**Is anything not supported yet?**
A few advanced Genie features are still in progress — notably general JavaScript (only the
`js_arrays` library, simple `js` / `<% %>` calls and the known corpus blocks run, section 12) and
plugins. Ordinary automation, variables, math, triggers, gags,
substitutions, launching other scripts (`.name`), and room navigation (`#goto` / `$roomid`, where
the map has been matched) all work today. Front-end visual effects work as your front-end adds
support for them.

---

## 17. Quick reference card

**Turn on/off (per character):**

```
;e Lich::Genie.enabled = true
;e Lich::Genie.enabled = false
;eq echo Lich::Genie.enabled?
```

**Output & sending:**

```
echo text-to-me
put command-to-game
send command-to-game        # queued: out after roundtime (send 2 cmd = 2 s later)
pause 2
```

**Variables:**

```
%local = value
$global = value          # shared by all scripts (put #var save writes it to disk)
setvariable name value   # same as %name = value
math name add 5
counter add 1            # works on %c
evalmath name (2 + 3)
eval name %x > 3         # 1 or 0
```

**Decisions:**

```
if COND then command
if COND then { ... }
else { ... }
elseif COND then command
```

**Loops & routines:**

```
label:
goto label
gosub label args   ...   return
exit
```

**Reacting:**

```
waitfor text
waitforre pattern
match labelname text
matchre labelname pattern
matchwait 15
wait                    # until the next prompt, at least 1 s (wait 3 = at least 3 s)
move north              # send "north", wait for the next room
action commands when pattern
action remove pattern
action clear
```

**Launch another script (leading `.`):**

```
put .scriptname args    # runs scriptname.cmd with %1.. = args
```

**Triggers, filters, lists (run in Lich, work now):**

```
put #trigger {pattern} {commands} {class}
put #trigger              # list loaded triggers
put #untrigger pattern
put #trigger clear
put #class name on|off    # gate a group of triggers (also +a -b, all on|off)
put #gag pattern
put #ungag pattern
put #sub {pattern} {replacement}
put #unsub pattern
put #alias {key} {command}
put #var                  # list variables (#var word lists those containing word)
put #event 5 #echo hi     # run a command in 5 seconds
put #log text             # append to your character's log in GenieProfiles/Logs (>file: that file)
put #log >/path/x.log hi  # >file: a name in Logs, or a path of its own (absolute, or holding a \ as
                          # in Genie); no folder is created: a missing one prints [LogLine: ...]
put #config key value     # change a setting ("Set key: value")
```

**Display effects (front-end dependent):**

```
put #highlight line color {text}
put #macro {key} {command}
put #playsound file
```

**Files:**

```
include helper.cmd     # exact file name from the scripts folder, extension included
```

**Common reserved variables:**

```
$health $mana $stamina $spirit $concentration
$roomname $roomexits $north $south $east $west
$lefthand $righthand
$standing $bleeding $stunned $hidden
$SpellTimer.MyBuff.active  $SpellTimer.MyBuff.duration
$unixtime  $preparedspell  $roundtime
```

---

*Happy scripting. Start small — a one-line `echo` script — and build up from there. Everything in
this guide is something you can copy, paste, and run today.*
