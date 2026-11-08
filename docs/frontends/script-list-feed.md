# Running-script list (`script_list` and the scripts window)

Lich keeps a front end told which scripts are running, with controls to pause, unpause and kill them. Each client gets exactly one of two forms, or nothing:

| A client that | gets |
|---|---|
| has the `script_list` feed | one data element, `<lichScripts …/>`, for a front end that draws its own panel or buttons |
| otherwise, when the user has turned on `;display scriptwindow` (off by default), on a front end with the `streams` capability (in the catalog: Wrayth/StormFront, Saga, Profanity) | a StormFront-style `scripts` stream window that Lich fills itself, with pause/unpause and kill links, shown with no change to the front end |
| neither | nothing |

Both forms are built from the same list at the same moments.

## Asking for the data element

A client gets `script_list` by declaring it with the `SET_FRONTEND_CAPS` line (see [capability-declaration.md](capability-declaration.md)). Name the rewrite capabilities the client handles on the same line, so the line means the same thing to every Lich that reads it. Saga, for example, sends:

```
SET_FRONTEND_CAPS room_element game_links double_bold script_list
```

A client with no rewrites of its own sends just `SET_FRONTEND_CAPS script_list`.

From then on it gets the data element instead of the window. It can also come from the session's `--frontend-caps=` launch flag or a custom front end's `capabilities` in `frontends.yml`; no built-in catalog entry has it. `script_list` is a feed, kept apart from the rewrite capabilities: a line that names only feeds leaves the client's rewrites exactly as they were, so a Saga client keeps its rich stream. A line that names only rewrites keeps the feed; a bare `SET_FRONTEND_CAPS` clears it along with the rewrites, which puts a `streams` client back on the window.

## Turning on the window

The window is a user setting, not a capability: `;display scriptwindow` toggles it (`;display scriptwindow true` or `false` sets it), and it is off by default. It is stored in the `lich_settings` table (`Lich.display_script_window`). Even when it is on, only a front end with the `streams` capability (`Frontend.supports_streams?`) gets it, so a Wizard or Avalon (GSL) session, and Genie and Frostbite, whose catalog entries have no `streams`, never get the window's XML.

- Turning it on draws the window at once in every client that now gets it.
- Turning it off replaces the window's contents with `The Lich Scripts window is off. Turn it on with ;display scriptwindow.` in each client that had it, and stops updating it.
- A client that declared `script_list` gets the data element whatever the setting says.

With the setting on, a client that declares `script_list` on attach may get one window draw first, sent before Lich has read its declaration. The window's lines stay in its own stream (`ifClosed=""`), so the client can ignore them.

### Older Lich

- **A Lich that knows `SET_FRONTEND_CAPS` but not `script_list`** (5.23.0, for one) logs `script_list` as unknown and applies the rest of the line by its older rule: the line's known names *replace* the client's rewrite set. So `SET_FRONTEND_CAPS script_list` alone declares the empty rewrite set there, and a front end that gets rewrites from its catalog entry (Saga gets `room_element game_links double_bold`) drops to the legacy stream. Restating the rewrites on the same line, as above, keeps them on that Lich and on this one alike.
- **A Lich too old to know `SET_FRONTEND_CAPS` at all** forwards the line to the game as a command, so a client should send it only to a Lich new enough to read it (check `LICH_VERSION` in `lib/version.rb`).

## The stream window

Each update is this block, sent whole:

```
<streamWindow id="scripts" title="Lich Scripts" location="right" ifClosed="" resident="true"/>
<clearStream id="scripts"/>
<pushStream id="scripts"/>bigshot  <d cmd=";pause bigshot">pause</d> <d cmd=";kill bigshot">kill</d>
go2 (paused)  <d cmd=";unpause go2">unpause</d> <d cmd=";kill go2">kill</d>
<popStream/>
```

- The links send the same `;pause`, `;unpause` and `;kill` commands a user would type, with the session's command character.
- With nothing running, the window holds the line `No scripts running.`
- `ifClosed=""` keeps the lines out of the main window while the window is closed; the user opens it from the front end's window list.
- Wrayth shows a stream window the first time it sees its id; no attribute creates it closed. `location="right"` docks that first showing in the right panel, as the game does for its own optional windows (Bounties, Loot), instead of a floating window at the mouse. `resident="true"` makes Wrayth remember when the user closes it, so it stays closed in later sessions. Re-sending the tag on each update only refreshes the title and never reopens a closed window.
- Names are XML-escaped (`&`, `<`, `>`, `"`).
- ProfanityFE (which has `streams`) gets the window, but shows a stream only in a window its layout defines, so most layouts show nothing. A layout with a `scripts` window gets a new copy of the list on each change, because ProfanityFE applies `clearStream` only to the spell window.

## The data element (`script_list`)

```
<lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>
```

| Attribute | Meaning |
|---|---|
| `v` | Format version, `1`. A later version adds attributes rather than changing these. |
| `char` | The Lich command character (`$clean_lich_char`), percent-encoded. |
| `list` | The running scripts, comma-separated, each `name:paused` where `paused` is `1` or `0`. The name is percent-encoded. An empty value means no scripts are running. |

- **Encoding.** Every byte outside `A-Z a-z 0-9 _ . / -` is percent-encoded as `%XX` (UTF-8 bytes, upper-case hex), so no name can contain `,`, `:`, `"`, `<`, `>` or `&`. Decode each name and `char` after splitting.
- **Replace, do not merge.** Each element is the whole list. Replace the panel's list with it.
- **Acting on it.** The feed is read-only. To act on a script, send an ordinary Lich command built from `char` and the decoded name, for example `;pause bigshot`. It behaves exactly as typed: Lich matches the name exactly first, then by prefix.

## Both forms

- **Which scripts.** Exactly those `;list` shows, in the same order: hidden scripts (`hide_me`) are left out.
- **Never in the game stream.** Lich writes the feeds straight to each client that gets them, at the next point where no stream is open. Scripts do not see them: they do not go through `respond`/`_respond`, downstream hooks or script output.
- **When.** When the client starts getting a feed (on attach, or right after its declaration), and again only when the list changes: a script starts or stops, is paused or unpaused, or hides or unhides itself. Changes within about 0.1 seconds of each other go out as one update, so a `;kill all` sends one. Nothing is resent on a timer, so a window is redrawn only when its contents differ. Lich records what it last sent each client, so a client that attaches in the middle of a change is still brought up to date.
- **Getting the list again.** A client that loses its copy without re-attaching (it reloads its view, say) sends its `SET_FRONTEND_CAPS` line again; Lich answers with the current list at once.
- **No "stopped" state.** The feeds run inside Lich, so they end only when the session does, which the client sees as the connection closing.

## Code

- `lib/common/script_list_feed.rb`: both forms, the change thread and the per-client fan-out.
- `lib/common/client_capabilities.rb`: the feeds (`FEEDS`), resolved apart from the rewrites.
- `lib/common/frontend.rb` `supports_streams?`: which front ends get the window.
- `lib/common/script.rb`: the change signals (`__publish`, `__publish_generated`, `__discard_startup`, `__complete_stop`, `pause`, `unpause`, `hidden=`).
- `lib/global_defs.rb` `handle_detachable_client` and `lib/main/main.rb` (primary client loop): the attach-time send.
