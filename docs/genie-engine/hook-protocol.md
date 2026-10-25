# genieHook Protocol — front-end-agnostic Genie front-end effects

**Audience:** front-end developers (Lichborne first, but any front-end). This is the contract for
the front-end effects a Genie script can trigger. Lich runs the Genie *automation* engine; when a
script touches a Genie *front-end* feature (highlights, windows, macros, sounds, echo-to-window,
...), Lich emits a `<genieHook>` event carrying Genie's parameters -- for a character that turned
the tags on (below). Lich contains no front-end-specific code.

> **Status (engine v0.26.11):** every op below is produced by `lib/genie/command_router.rb` (the port
> of Remix `Core/Command.cs`, cited `R`) and asserted in `spec/lib/genie/command_router_spec.rb`.
> The payloads listed are what the engine sends today. Lists the engine owns itself (variables,
> #triggers, classes, gags, substitutes, aliases) emit no hook, except the two noted below.

## Opt-in (off by default)

No released front end consumes `<genieHook>` (ProfanityFE drops it as an unknown tag; a Wizard,
non-XML, front end would print it as text), so the tags are written only for a character that turned
them on, persisted per character in `lich_settings` (`genie_hooks:<game>:<character>`):

```
;e Lich::Genie.hooks_enabled = true     # a hook-aware front end
;e Lich::Genie.hooks_enabled = false    # the default
```

With the tags off, `LichHookSink#emit` (`lib/genie/genie_script.rb`) still shows the text an effect
carries, on every front end, through Lich's own messaging; everything else is dropped:

| op | with hooks off |
|---|---|
| `echo` (`#echo >window text`) | the text through `Lich::Messaging.stream_window(text, window.downcase)`: the stream of that name where Lich lets the front end have it (familiar, thoughts, combat on DR; plus loot, voln on GS; an XML front end), else the main window (Lich wraps familiar / thoughts / voln for a front end without streams), XML-encoded and Wizard-converted by Lich. Engine output: never fed to matchwait or the #triggers. A failure falls back to a plain engine echo. |
| `link` (`#link [>window] text command`) | its text, the same way (a link's command is a Genie command, which Lich could not run: no clickable link) |
| `inputbox` (a send holding `@` / `\x`) | the text, echoed to the main window (nothing is sent, as in Genie) |
| `highlight`, `preset`, `class`, `window`, `layout`, `macro`, `alias`/`unalias`, `name`/`unname`, `playsound`, `image`, `icon`, `beep`/`flash`, `config`, `clear`, `status`/`statusbar`, `comment`, `save`/`load`, the generic ops | nothing (no text to show, or chrome Lich cannot draw); the engine-side part of the command -- the class list, the alias list, `#config` settings, their echoes -- happens either way |

## Design goals
1. **Front-end agnostic.** Hooks describe *intent + Genie's parameters*, not a widget model.
2. **Self-describing.** A front end can reproduce Genie's behaviour from the hook alone.
3. **Safe to ignore.** A front end that does not implement a hook drops it; the script's
   automation is unaffected.
4. **Versioned & extensible.** New ops/fields can be added without breaking older front ends.

## Transport
- Hooks ride the downstream stream to the connected front end: `LichHookSink#emit`
  (`lib/genie/genie_script.rb`) writes one line to `$_CLIENT_` (nothing when no client is
  connected; a write error is swallowed).
- Wire form: one self-closing tag on its own line, the payload as a JSON object in the `data`
  attribute:

  ```
  <genieHook v="1" op="<name>" data='<JSON>'/>
  ```

  - `v` — protocol version (integer). Current: `1`.
  - `op` — the operation name (see catalog).
  - `data` — the payload. `&`, `<`, `>`, `'` and `"` in `op` and in the JSON are written as
    `&amp;`, `&lt;`, `&gt;`, `&apos;` and `&quot;` (`LichHookSink.hook_tag`), so a payload holding an
    apostrophe or markup is well-formed XML. A front end decodes the attribute, then parses the JSON.
- The tag is unknown to the game protocol, so XML parsers that do not recognise it skip it. Front
  ends match on `<genieHook` at line start.
- There is no capability negotiation: with the character's hook setting on, every hook is emitted to
  whatever front end is connected; off, none is (see "Opt-in" above). (A `:genie_hooks` front-end
  capability was a design idea; it is not implemented.)

## Op catalog

| op | Genie verb(s) | Payload |
|---|---|---|
| `highlight` | `#highlight` | add / clear (below) |
| `preset` | `#preset <key> <value>` | `{"name", "value"}` |
| `class` | `#class` (each class event) | `{"classes": {...}}` |
| `window` | `#window add\|show\|position\|remove\|close\|hide` | below |
| `layout` | `#layout`, `#window load\|save` | `{"action", "name"}` |
| `echo` | `#echo >window text` | `{"window", "text"}` |
| `macro` | `#macro <key> <command>` | `{"key", "command"}` |
| `alias` / `unalias` | `#alias`, `#unalias`, `#unclass` | `{"pattern", "command"}` / `{"pattern"}` |
| `name` / `unname` | `#name`, `#unname` | `{"name", "value"}` / `{"name"}` |
| `playsound` | `#playsound`/`#playwave`/`#play` | `{"file"}` or `{"stop": true}` |
| `link` | `#link` | `{"window", "text", "command"}` |
| `image` | `#image`/`#img` | `{"filename", "window", "width", "height"}` |
| `icon` | `#icon <file>` | `{"file"}` |
| `beep` / `flash` | `#beep`/`#bell`, `#flash` | `{}` |
| `config` | `#config` / `#set` / `#setting(s)` | `{"key", "value"}` or `{"action": "list"\|"edit"}` |
| `inputbox` | a sent text holding `@` or `\x` | `{"text"}` |
| `clear` | `#clear` | generic + `"window"` |
| `status` / `statusbar` | `#status`, `#statusbar` | generic + `"text"`, `"index"` |
| `comment` | `#comment <window> <text>` | generic + `"window"`, `"text"` |
| `save` / `load` | `#save` / `#load` of a front-end list | generic |
| generic ops | see "Generic payload" | `{"args": [...], "raw": "..."}` |

## Payloads

- **`highlight`** — add: `{"kind": "line"|"string"|"beginswith"|"regex", "whole_row": <bool>,
  "color": <string>, "pattern": <string>, "case_sensitive": <bool>, "sound": <string>,
  "class": <string>, "active": <bool>}`; clear (`#highlight clear`, after the "Highlights Cleared"
  echo): `{"clear": true}`. Remix's argument order (N10; Command.cs:1928-2004 R): `#highlight
  <kind> <color> <pattern> [class] [sound] [case TRUE] [active TRUE]`; `pattern` is
  ParseGlobalVars(oArgs[3]) (one token), `active` defaults to true, `case_sensitive` to false. A
  `/x/i` or `/x/` pattern is unwrapped as Remix's lists do (`/i` makes it case-insensitive). No
  pattern argument, or an empty pattern, emits nothing; an invalid `regex` pattern echoes
  "Invalid RegExp in highlight: ..." and emits nothing. `#highlight load|save` echo "Highlights
  Loaded|Saved" and emit the generic op; another word (or none) is the listing (generic op).
- **`preset`** — `{"name": <key, lower-cased>, "value": <string>}`, only for a key Remix knows
  (`roomname`, `scriptecho`, `automapper.path`, ...); another key echoes "Invalid #preset keyword."
  and emits nothing. Colour parsing is the front end's job.
- **`class`** — `{"classes": {<name>: <bool>, ...}}`: the engine's whole class list (Remix
  Globals.ClassList, `default` included) after each class event: `#class name value`, `+a -b`,
  `all on|off`, a one-word listing, `#class load`, `#load classes` (Command.cs:1234-1354, 674-681 R).
  Remix re-applies EVERY entry to every list on each such event (Command_EventClassChange,
  FormMain.cs:7483-7519 R): a highlight added while its class is off stays on until the next class
  event, which switches it off. The engine re-applies it to its #triggers (class names compared
  lower-cased) and gags/substitutes (compared exactly); a front end applies it to its highlights.
- **`window`** — `{"action": "add"|"show"|"remove"|"close"|"hide", "name": <string>}`; `add`/`show`
  also carry Genie's fixed `"width": 300, "height": 200, "top": 10, "left": 10`. `position`:
  `{"action": "position", "name", "width", "height", "top", "left"}`, each an int or `null` (an empty
  or `0` width/height is `null`); a syntax error is echoed (Remix's text) and nothing is emitted.
- **`layout`** — `{"action": "load"|"save", "name": <string>}`; a bare `#layout` is
  `{"action": "load", "name": "@windowsize@"}`. `#window load <name>` and `#window save <name>` both
  emit `{"action": "load", ...}`: Remix raises its load-layout event for both (Command.cs:2390-2400 R).
- **`echo`** — `{"window": <string>, "text": <string>}` for `#echo >window text` (the `>window` may
  also come after a colour). Plain `#echo text` is a local echo, not a hook. A colour argument
  (`#RRGGBB`, or a web colour name in any case, also as the fg of `fg,bg`) is dropped from the text
  and not carried.
- **`macro`** — `{"key": <string>, "command": <string>}` for `#macro <key> <command>`. `#macro
  load|save|clear` echo "Macros Loaded|Saved|Cleared" and emit the generic op; `#unmacro` and the
  listing emit the generic op.
- **`alias` / `unalias`** — `{"pattern", "command"}` / `{"pattern"}`. The engine keeps its own alias
  list (`aliases.cfg`; it is what a script's `put` expands, Command.cs:235-241 R); the hook lets a
  front end expand what its user types. `#unclass <key>` removes an ALIAS in Remix
  (Command.cs:1356-1364 R) and emits `unalias` too.
- **`name` / `unname`** — one event per target: `#name <value> <target...>` emits
  `{"name": <target>, "value": <value>}` for each non-empty target; `#unname <target...>` emits
  `{"name": <target>}` for each. `#name load|save|clear` echo "Names Loaded|Saved|Cleared" and emit
  the generic op.
- **`playsound`** — `{"file": <string>}`, or `{"stop": true}` for `#play stop`. No argument: nothing.
- **`link`** — `{"window": <string, "" if none>, "text": <string>, "command": <string>}` for
  `#link [>window] <text> <command...>`.
- **`image`** — `{"filename": <string>, "window": <string>, "width": <int>, "height": <int>}`;
  `>window`, `w:`/`width:`, `h:`/`height:` in any order (0 = not given). No file name echoes "No
  File Name was specified for the Image Command." and emits nothing; a bad size echoes "Invalid
  Width|Height Specified: ..." and uses 0.
- **`icon`** — `{"file": ParseGlobalVars(<arg 1>)}`. `#icon` with no argument emits nothing (it
  faults, as in Remix).
- **`beep` / `flash`** — `{}`.
- **`config`** — after a setting is set (and SetSetting's echoes, "Set key: value" / "Don't forget
  to #save config"): `{"key": <string>, "value": <string>}`; `#config` alone:
  `{"action": "list"}`; `#config edit`: `{"action": "edit"}`. `#config load|save` echo "Settings
  Loaded|Saved" only. The settings the engine itself reads (prompt, roundtimeoffset,
  scripttimeout, triggeroninput, ...) take effect in the engine too.
- **`inputbox`** — `{"text": <string>}`: a text ParseCommand would send that holds `@` or `\x` is
  not sent; Genie puts it into its input box for the user to finish (SendTextInputBox,
  FormMain.cs:4378-4422 R). An escaped `\@` is sent as `@` instead.
- **`clear`**, **`status`/`statusbar`**, **`comment`** — the generic payload plus the value Remix
  hands its event: `clear` adds `"window"`; `status`/`statusbar` add `"text"` and `"index"` (bar
  1-10, default 1); `comment` adds `"window"` and `"text"` (Command.cs:482-486, 2269-2300,
  2407-2414 R). `#status` alone and `#comment` with fewer than three arguments emit nothing.

## Generic payload

`{"args": [<tokens after the keyword>], "raw": "<the argument text>"}` — safe to ignore. Emitted
for the arms that are host or front-end business with no engine state: `#connect` (1, 2 or 5
arguments; another count echoes Remix's syntax line instead), `#lc`/`#lconnect`/`#lichconnect` (an
existing profile; a missing one echoes `Profile "x" not found. Lich was not started.`),
`#ls`/`#lichsettings`, `#disconnect`, `#exit`, `#browser`, `#playsystem`, `#edit`, `#help`,
`#profile`, `#plugin`, `#xml`, `#raw`, `#unmacro`; the listing / list-word forms of `#macro`,
`#preset`, `#name`, `#highlight`; `#script` with no action or an action other than
abort/pause/resume/pauseorresume/reload/debug; and the `edit` forms of `#var`, `#class`,
`#trigger`, `#gag`, `#sub`, `#alias`. `#save` / `#load` naming a list the front end owns
(settings, macros, highlights, names, presets, layout, profile, or `all`) emit one generic `save` / `load` op after
Remix's `<Kind> Saved|Loaded` echoes.

## What emits no hook

- **Engine-owned lists:** `#var`/`#tvar`/`#svar`/`#unvar`, `#trigger`/`#untrigger`, `#class` (apart
  from the `class` op), `#gag`/`#ungag`, `#sub`/`#unsub`, `#alias` (apart from `alias`/`unalias`),
  with their load/save/clear/listing forms and files under `GenieProfiles/Config/` (variables.cfg,
  triggers.cfg, classes.cfg, gags.cfg, substitutes.cfg, aliases.cfg). Before v0.23.0 these were
  front-end hooks; they are not any more.
- **Engine commands:** `#eval`/`#evalmath`/`#math`/`#if`/`#random`, `#send`/`#do`/`#queue`/`#event`,
  `#put`, `#nop`/`#cr`/`#push`, `#log`, `#keys`/`#colors`, `#parse` (it goes to the #triggers and
  scripts, as in Genie; before v0.13.0 it emitted a `parse` hook), `#script
  abort|pause|resume|pauseorresume|reload|debug`, `#goto` and its aliases (the engine walks with
  Lich's go2), `#path`/`#mapper`/`#map`/`#m` (no-ops here).
- **Unknown commands** (Command.cs:2518-2530 R): a `#command` Remix has no arm for (`#ping`,
  `#automapper`, `# echo` with a space, a bare `#`, `#unhighlight`, `#gauge`, ...) echoes
  `Unknown command: <row>` and emits nothing; a `#RRGGBB` row is its own result.
- **Gags and substitutes** are applied by the engine itself (`StreamFilters`, through one Lich
  `DownstreamHook`) to what the front end is sent; see below.

### Gags and substitutes (engine-side, no hook)

The raw line is already in `$_SERVERBUFFER_` when the filter runs, so reget, logs and other scripts
see the original; only the client's copy is filtered, as Remix filters only what it prints. A gag
is tested on the line's display text (tags dropped, entities decoded, CR/LF trimmed) and never in
the thoughts window; a gagged line still reaches the client as its TAGS (stream pushes, room
components, compass, `<prompt>`), with its text and line end dropped; a line whose display text is
blank is never gagged. A substitute replaces with .NET's replacement syntax (`$1`, `${1}`,
`${name}`, `$$`, `$&`, `` $` ``, `$'`, `$+`, `$_`) in each text run between tags; its replacement is
ParseGlobalVars'd at display time (Game.cs:3075-3103, 3173-3206 R) without calling Lich host code:
host-sourced values (`$roomid`, `$zoneid`, `$zonename`, `$scriptlist`, `$Time.*`, `$<Skill>.*`) are
the last ones the engine read. An invalid regexp is refused with Remix's echo. A send by a script
whose NAME a gag matches is not echoed (Game.cs:481-511 R). Each pattern match is time-limited;
three timeouts in a row switch the pattern off with one notice.

## Example
```
<genieHook v="1" op="highlight" data='{&quot;kind&quot;:&quot;string&quot;,&quot;whole_row&quot;:false,&quot;color&quot;:&quot;yellow&quot;,&quot;pattern&quot;:&quot;a treasure chest&quot;,&quot;class&quot;:&quot;&quot;,&quot;sound&quot;:&quot;&quot;,&quot;case_sensitive&quot;:false,&quot;active&quot;:true}'/>
<genieHook v="1" op="echo" data='{&quot;window&quot;:&quot;Log&quot;,&quot;text&quot;:&quot;don&apos;t&quot;}'/>
<genieHook v="1" op="playsound" data='{&quot;file&quot;:&quot;alert.wav&quot;}'/>
```
(from `#highlight string yellow {a treasure chest}`, `#echo >Log don't`, `#playsound alert.wav`)

## Notes for front-end implementers
- Treat an unknown `op` or unknown JSON fields as ignorable (forward-compat).
- `class`/`preset`/`highlight` interact (classes gate highlights; presets supply colours) —
  mirror Genie's model: a highlight may name a `class` and a colour that may be a preset name.
- Persistence is the front end's choice. Genie keeps these in `.cfg` files; hooks represent the
  *runtime application* of script-issued changes. A front end may also import Genie config
  directly (e.g. Lichborne ships a Genie config importer) — orthogonal to this protocol.
