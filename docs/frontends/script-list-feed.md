# Script list feed (`script_list`)

A front end can ask Lich to keep it told which scripts are running, so it can show them in a panel with pause, unpause and kill buttons. Lich sends the list as one XML element whenever it changes. The feed works the same for every front end; nothing in it is specific to one client.

## Asking for it

Declare the `script_list` capability with the `SET_FRONTEND_CAPS` line (see [capability-declaration.md](capability-declaration.md)):

```
SET_FRONTEND_CAPS script_list
```

`script_list` is a *feed*, not a rewrite, and Lich keeps the two apart: naming only a feed leaves the client's rewrites exactly as they were (its earlier declaration, or the session's default), so a client asks for the feed without restating them. It can name both on one line too (`SET_FRONTEND_CAPS script_list room_element`). A later line that names only rewrites keeps the feed on; a bare `SET_FRONTEND_CAPS` turns it off along with the rewrites.

A client can also get the feed without declaring, from the session's `--frontend-caps=` launch flag (`--frontend-caps=script_list`, handy for testing; the catalog rewrites stay as they are) or from a custom front end's `capabilities` in `frontends.yml`. No built-in front end gets it by default, so a client that has not asked never sees the element.

A Lich without this feature ignores `script_list` in a declaration and logs it as unknown. A Lich too old to know `SET_FRONTEND_CAPS` at all forwards the line to the game as a command, so a client should send it only to a Lich new enough to read it (check `LICH_VERSION` in `lib/version.rb`).

## The element

```
<lichScripts v="1" char="%3B" list="bigshot:0,go2:1"/>
```

| Attribute | Meaning |
|---|---|
| `v` | Format version, `1`. A later version adds attributes rather than changing these. |
| `char` | The Lich command character (`$clean_lich_char`), percent-encoded. |
| `list` | The running scripts, comma-separated, each `name:paused` where `paused` is `1` or `0`. The name is percent-encoded. An empty value means no scripts are running. |

- **Encoding.** Every byte outside `A-Z a-z 0-9 _ . / -` is percent-encoded as `%XX` (UTF-8 bytes, upper-case hex), so no name can contain `,`, `:`, `"`, `<`, `>` or `&`. Decode each name and `char` after splitting.
- **Which scripts.** Exactly those `;list` shows, in the same order: hidden scripts (`hide_me`) are left out.
- **Replace, do not merge.** Each element is the whole list. Replace the panel's list with it.
- **Always one line, never in the game stream.** Lich writes it straight to each subscribing client, outside any `pushStream`. Scripts do not see it: it does not go through `respond`/`_respond`, downstream hooks or script output.

## When it is sent

- **When the client becomes a subscriber:** right after it declares `script_list`, or on attach when the session's set already includes it.
- **When the list changes:** a script starts or stops, is paused or unpaused, or hides or unhides itself. Changes within about 0.1 seconds of each other go out as one element (a `;kill all` sends one list, not one per script).
- **Every 30 seconds** regardless, so a client that reloads its view without re-attaching relearns the list, and a change of the command character reaches it.

There is no "stopped" state. The feed runs inside Lich, so it ends only when the session does, which the client sees as the connection closing.

## Acting on the list

The feed is read-only. To act on a script, send an ordinary Lich command on the same connection, built from `char` and the decoded name, for example `;pause bigshot`, `;unpause go2` or `;kill bigshot`. These are the commands a user would type, so they behave exactly as typed: Lich matches the name exactly first, then by prefix.

## Code

- `lib/common/script_list_feed.rb`: the element, the change thread and the subscriber fan-out.
- `lib/common/client_capabilities.rb`: `script_list` as a declarable feed (`FEEDS`), kept out of the rewrite grouping.
- `lib/common/script.rb`: the change signals (`__publish`, `__publish_generated`, `__discard_startup`, `__complete_stop`, `pause`, `unpause`, `hidden=`).
- `lib/global_defs.rb` `handle_detachable_client` and `lib/main/main.rb` (primary client loop): the attach-time send.
