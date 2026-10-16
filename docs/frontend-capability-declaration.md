# Front-end capability declaration (`SET_FRONTEND_CAPS`)

Lich identifies to the game as Saga, so DragonRealms sends it the Saga-identity ("rich") stream. Lich rewrites that stream for a front end that cannot take it. A front end tells Lich which parts it renders itself with one control line, `SET_FRONTEND_CAPS`. Lich applies the rewrites per client connection, so front ends with different needs can share one session.

## The rewrites

| Capability | The client renders | Without it, Lich sends |
|---|---|---|
| `room_element` | the inline `<room>` block (`<name>`, `<description>`, `<exists>`, `<players>`, `<exits>`, `<extra>`) | the legacy `roomName` / `roomDesc` lines, plus the legacy `<compass>` line after a view of the character's own room |
| `game_links` | `<a exist="…" noun="…">…</a>` object links | the link text without the `<a>` tags (a script's own `<a href>` stays) |
| `double_bold` | the doubled `<pushBold/><pushBold/>…<popBold/><popBold/>` around linked creatures | one `<pushBold/>…<popBold/>` pair |

`game_links` and `double_bold` apply only to DragonRealms. GemStone has always sent links and doubled bold, and its front ends expect them, so Lich leaves GemStone lines alone whatever the client declares. `room_element` matters only where the game sends `<room>`, which today means DragonRealms.

## The line

The client sends it to Lich on its connection, terminated like any other command line:

```
SET_FRONTEND_CAPS room_element game_links double_bold
```

- The command name is case-sensitive, like `SET_FRONTEND_PID`, and must start the line.
- The names follow, separated by spaces, tabs or commas, in any order and any case.
- Names Lich does not know are ignored and logged, so a newer client can declare capabilities an older Lich lacks.
- `SET_FRONTEND_CAPS` with no known name (bare, or `SET_FRONTEND_CAPS none`) declares the empty set: the client gets every rewrite, the full legacy stream.
- Lich consumes the line. It never reaches the game, scripts or upstream hooks.
- A later declaration replaces the earlier one from the same client. It takes effect from the next server line Lich sends.
- Lich sends no reply.

Send it once, as early as possible. On a detachable connection (`--detachable-client`), send it straight after connecting; anything the game sends before Lich reads the line is rewritten by the next rule down. On the primary connection, send it after the two handshake lines (the key and the client string), which Lich forwards to the game unread.

## Precedence

Each client connection gets, highest priority first:

1. the set it declared with `SET_FRONTEND_CAPS`;
2. the session's `--frontend-caps=LIST` launch flag (comma-separated names; an empty list is the empty set), which applies to every client that has not declared;
3. the frontend catalog's capabilities for the session's front end (`--frontend=NAME`, `--genie` and so on, or a custom front end's `capabilities` in `frontends.yml`).

A client that declares nothing, in a session without `--frontend-caps`, gets exactly the bytes every client got before declarations existed. In the catalog only Saga has all three capabilities; Genie, Frostbite, Wrayth/StormFront, Profanity and unknown front ends have none.

## What a declaration does not change

- **Scripts see one stream.** XMLParser, `downstream_xml`, `downstream` and downstream hooks see the stream as the game sent it, whatever the attached clients declared. The rewrites run only on the way to each client.
- **Everything else follows the session's front end.** The Wizard/Avalon GSL conversion, the origin sentinel, mono output, the room-number display and the Genie and Frostbite subtitle edits still depend on `$frontend`, as before.
- **A Wizard/Avalon (GSL) session ignores declarations.** Its GSL conversion keeps state across lines, so every client there gets the session's set. Lich still consumes the line.
- **Lich's own output is not rewritten.** `respond`, `_respond` and the attach-time state push go to the clients as before.
- **The detach rule is unchanged.** While any detachable client is attached, the primary client gets no game output.

## Several clients on one session

Lich groups the attached clients by capability set and rewrites each server line once per distinct set, not once per client. Clients with the same set share one rewrite, so the usual case (every client with the same set) costs what a single client did. A Saga client and a released Profanity client attached to the same listener therefore get the rich line and the legacy line respectively.

## Backward compatibility

- **Old client, new Lich:** a client that never sends the line gets today's behaviour (rules 2 and 3 above).
- **New client, old Lich:** a Lich without this feature does not recognise the line and forwards it to the game as a command, so the game answers it as it would any unknown command, once. A client that must avoid that can send the line only when the user turns the feature on. A client that renders both dialects (the rich-stream Profanity does) needs nothing more: under an old Lich it gets whatever that Lich sends.

## Implementing it in a client (ProfanityFE)

A rich-stream-aware ProfanityFE build renders `<room>`, links and doubled bold, so it should send, right after connecting to the detachable port:

```
SET_FRONTEND_CAPS room_element game_links double_bold
```

It then gets the stream as the game sent it. A released Profanity build sends nothing and keeps getting the legacy shape. To test without a client change, launch Lich with `--frontend-caps=room_element,game_links,double_bold`.

## Code

- `lib/common/client_capabilities.rb`: parsing, precedence and grouping.
- `Lich::Common::SynchronizedSocket#declared_capabilities`: the per-connection set.
- `lib/global_defs.rb` `handle_detachable_client` and `lib/main/main.rb` (primary client loop): where the line is consumed.
- `lib/games.rb` `process_downstream_hooks`, `rich_stream_rewrite` and `finish_client_line`: the per-set rewrite and fan-out.
