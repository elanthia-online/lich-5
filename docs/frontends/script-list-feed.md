# Script list feeds (`script_list`, `script_window`)

Lich can keep a front end told which scripts are running, with controls to pause, unpause and kill them. It does this in one of two forms, each a *feed* the front end gets through its capabilities:

| Feed | What Lich sends | For |
|---|---|---|
| `script_window` | a StormFront-style stream window that Lich fills itself: each script on a line with pause/unpause and kill links | any front end that renders stream windows, with no change of its own. **On by default** for Wrayth/StormFront and Saga. |
| `script_list` | one data element, `<lichScripts …/>`, with the list | a front end that draws its own panel or buttons. Off unless the client asks for it. |

Both are built from the same list at the same moments, and both work the same for every front end.

## Who gets which

A client's feeds come from, highest priority first:

1. what it declared with `SET_FRONTEND_CAPS` (see [capability-declaration.md](capability-declaration.md));
2. the session's `--frontend-caps=` launch flag;
3. the frontend catalog: `script_window` is in the Wrayth/StormFront and Saga entries, and no built-in entry has `script_list`. A custom front end can add either to its `capabilities` in `frontends.yml`.

A declaration that names a feed replaces the client's whole feed set, so a front end that wants the native experience declares:

```
SET_FRONTEND_CAPS script_list
```

and from then on gets the data element and no longer the window. To get both, name both (`SET_FRONTEND_CAPS script_list script_window`). Feeds are kept apart from the rewrite capabilities: a line that names only feeds leaves the client's rewrites exactly as they were, so a Saga client keeps its rich stream. A line that names only rewrites keeps the feeds; a bare `SET_FRONTEND_CAPS` turns the feeds off along with the rewrites.

A client that declares on attach may get one window draw first, sent before Lich has read its declaration. The window's lines stay in its own stream (`ifClosed=""`), so the client can ignore them.

A Lich without these feeds ignores their names in a declaration and logs them as unknown. A Lich too old to know `SET_FRONTEND_CAPS` at all forwards the line to the game as a command, so a client should send it only to a Lich new enough to read it (check `LICH_VERSION` in `lib/version.rb`).

## The stream window (`script_window`)

Each update is this block, sent whole:

```
<streamWindow id="scripts" title="Lich Scripts" ifClosed="" resident="true"/>
<clearStream id="scripts"/>
<pushStream id="scripts"/>bigshot  <d cmd=";pause bigshot">pause</d> <d cmd=";kill bigshot">kill</d>
go2 (paused)  <d cmd=";unpause go2">unpause</d> <d cmd=";kill go2">kill</d>
<popStream/>
```

- The links send the same `;pause`, `;unpause` and `;kill` commands a user would type, with the session's command character.
- With nothing running, the window holds the line `No scripts running.`
- `ifClosed=""` keeps the lines out of the main window while the window is closed; the user opens it from the front end's window list.
- Names are XML-escaped (`&`, `<`, `>`, `"`).
- ProfanityFE is not in the default: it shows a stream only in a window its layout defines, and it applies `clearStream` only to the spell window, so each update would add a copy rather than replace the last. Genie and Frostbite are not in the default either: their catalog entries do not mark stream support.

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
- **When.** When the client starts getting a feed (on attach, or right after its declaration); when the list changes (a script starts or stops, is paused or unpaused, or hides or unhides itself), with changes within about 0.1 seconds folded into one update, so a `;kill all` sends one; and every 30 seconds regardless, so a client that reloads without re-attaching relearns the list and a change of the command character reaches it.
- **No "stopped" state.** The feeds run inside Lich, so they end only when the session does, which the client sees as the connection closing.

## Code

- `lib/common/script_list_feed.rb`: both forms, the change thread and the per-client fan-out.
- `lib/common/client_capabilities.rb`: the feeds (`FEEDS`), resolved apart from the rewrites.
- `lib/common/frontend/wrayth.rb`, `lib/common/frontend/saga.rb`: the `script_window` defaults.
- `lib/common/script.rb`: the change signals (`__publish`, `__publish_generated`, `__discard_startup`, `__complete_stop`, `pause`, `unpause`, `hidden=`).
- `lib/global_defs.rb` `handle_detachable_client` and `lib/main/main.rb` (primary client loop): the attach-time send.
