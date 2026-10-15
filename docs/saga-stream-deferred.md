# Saga XML stream support: deferred items

Since #1700, Lich identifies as Saga (`/VERSION:saga-… /P:SAGA`) on the handshakes that use `Frontend::CLIENT_STRING`: Wizard/Avalon, Frostbite, Mudlet and `--without-frontend`. Front ends that send their own handshake (Genie, Profanity, Warlock, Wrayth) still get the legacy stream. **DragonRealms therefore has two stream dialects live at once**, and Lich must parse both: DR Saga captures carry the `<room>` block and `<a exist>` links in room objects, players and the stow feed, and DR legacy captures carry neither.

For GemStone only one stream is verified. Logs from 15 GS Shattered sessions (2026-10-15, not committed) show `<a exist>` links in room objects, players and the stow feed, `roomName`/`roomDesc` styles, `compDef`/`component` room parts, and no `<room>` element. They don't record the handshake, and `<settingsInfo client="1.0.1.28">` reports the character's stored client-settings record (Lich seeds exactly that value for a character that has none, `gameloader.rb`), so it doesn't identify the handshake either. Whether GemStone answers the Saga identity with a different stream is still open (E11).

This file tracks what the Saga-dialect work has **not** verified or fixed yet. It exists so nothing is dropped silently.

**Rules:**
- While an item is open, this series leaves the code paths it touches unchanged. This is a rule for the Saga-stream PRs, not a freeze on other work. The legacy replay goldens and existing specs protect those paths.
- Closing an item means: add a capture to `spec/fixtures/streams/`, record its golden, and compare it with the other dialect. Open a fix only if that comparison shows a difference.
- Every PR touching a related area repeats the relevant items under "Known gaps".

## Missing evidence

| # | Item | Missing | Code it could affect | Risk if the Saga shape differs | Closes when |
|---|---|---|---|---|---|
| E1 | Injury radios / `_injury N -1` mode switching | Saga capture | radio handler in `XMLParser#tag_start`, `fix_injury_mode` (games.rb) | DR radio ids (`injrRadExt`/`injrRadInt`/…) never match the GS ids, so `XMLData.injury_mode` never updates on DR; Wounds/Scars read the wrong mode. Blocks the DR injury-mode fix | Saga capture with a wound or scar, cycling `_injury 0/1/3/4 -1` and `health` |
| E2 | Room with no UID (`(**)`) | Saga capture | streamWindow subtitle UID parsing, `map_dr` title/description/exits fallback, the `(**)` room-number display | go2 / `Map.current` fail in unmapped or no-UID rooms | Saga capture entering a `(**)` room |
| E3 | Familiar / vision room views | Saga capture | familiar parsing keyed on `roomName`/`roomDesc` (XMLParser, markup.rb), the familiar prefix in `process_room_information` | Familiar room views not parsed or rendered | Saga capture on a character with a familiar |
| E4 | Room-window-disabled room | Captures in both dialects | `room_window_disabled` + `<dir>` compass path | The Saga dialect sends no `<dir>`, so exits may be empty there | Captures in both dialects |
| E5 | Servant / escort block | Captures in both dialects | common-travel Flag `^A servant (blocks\|stops)` | go2 doesn't react if the servant is linked or reworded | Captures in both dialects |
| E6 | `...wait N seconds` split room component | Captures in both dialects | `GameInstance#buffer_room_objs` | Split component not reassembled, so that refresh loses room objs/players | Captures in both dialects |
| E7 | Mount / gelapod in room objs | Captures in both dialects | drdefs `MOUNT_DESCRIPTION`, `GELAPOD`; GS mount inference in XMLParser | Mounts misclassified as NPCs, or the gelapod not recognized | Captures in both dialects |
| E8 | Scar images in the injuries dialog | Captures in both dialects | injuries `<image>` handler (`Scar\d`) | Scars not tracked | Captures in both dialects (overlaps E1) |
| E9 | IconSTUNNED / IconWEBBED | Saga capture | `stunned?` / `webbed?` | Low: the tag is the same in both dialects | Saga capture while stunned or webbed |
| E10 | ESP thoughts stream | Saga capture | DR Flags and scripts on thought text | Name-anchored thought Flags break if names are linked | Saga capture with a telepathy source |
| E11 | GemStone under the Saga identity | GS captures under a known handshake, in both identities (the 2026-10-15 GS logs show links and no `<room>`, but not which handshake) | every shared parser path | GS regressions go undetected beyond specs and the legacy `gs_sample` golden | GS captures under both identities. Until then, no GS-observable changes; GS maintainers smoke-test shared-path PRs |

## Parked fixes (known bugs, intentionally not fixed yet)

| # | Item | Where | Why parked | Unpark when |
|---|---|---|---|---|
| P1 | Title lost after `" and "`: `and Druid X` drops `Druid` | room players title capture (XMLParser text handler) | Shared with GS; no GS oracle (E11) | E11 closed |
| P2 | Greedy status regex eats the next title: `who is sitting and Druid` | same | same | E11 closed |
| P3 | `@pc` not reset at the start of a players refresh, so status can attach to the previous room's pc | `begin_room_players` path | same | E11 closed |
| P4 | Titles containing an apostrophe (`War 'Tog X`) | same | Needs a spec first; GS behavior unknown | Fix with P1–P3 |
| P5 | DR `GroupMembers` (`<pushStream id="group"/>  (?<member>\w+):`) misses a leader other than you (`  X (Leader): Healthy.`) and records `You` as a member | `drparser.rb` | **Pre-existing in both dialects.** Replay confirms the legacy stream uses the same `(Leader)` shape; not a Saga regression | Separate `fix(dr)` |
| P6 | Legacy DR players splitter keeps a trailing period on the last name (`Chieftain X.`) | XMLParser DR players branch | Pre-existing legacy behavior; changing it alters legacy goldens | Separate `fix(dr)` with deliberate golden update |

## Corrections recorded during planning

These claims were made during planning and turned out to be false. They are recorded so they aren't re-raised.

| Claim | Why it's false |
|---|---|
| percWindow refreshes lack `pushStream` / active spells wiped | `;logxml` without `streams` drops every line starting with push/popStream; captures with streams show push/clear intact |
| Assess stream gone | Same logxml artifact |
| Injuries `dialogData clear` → ActiveSpell NameError → parser reset | Executed: no reset |
| percWindow `spell.strip!` before the nil check raises | Lich's NilClass patch makes `nil.strip!` return nil |
| `<right/left exist>` is new in the Saga dialect | Legacy streams already carry it |
| `<inv id='stow'>` / `clearContainer` are new in the Saga dialect | Legacy streams send them too, as plain text. What's new is the `<a exist>` links inside them, which make the parser create GameObj entries without a resolved stow container |
| `room_count` double-increments via `popStream id='room'` | 0 room pops across 567 moves; one compass close per nav |
