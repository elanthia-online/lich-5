# Saga XML stream support: deferred items

Since #1700, Lich identifies as Saga (`/VERSION:saga-… /P:SAGA`) on the handshakes that use `Frontend::CLIENT_STRING`: Wizard/Avalon, Frostbite, Mudlet and `--without-frontend`. Front ends that send their own handshake (Genie, Profanity, Warlock, Wrayth) still get the legacy stream. **Each game therefore has two stream dialects live at once**, and Lich must parse both.

This file tracks what the Saga-dialect work has **not** verified or fixed yet. It exists so nothing is dropped silently.

**Rules:**
- While an item is open, the code paths it touches stay unchanged. The legacy replay goldens and existing specs protect them.
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
| E11 | GemStone under the Saga identity | GS captures in both dialects | every shared parser path | GS regressions go undetected beyond specs and the legacy `gs_sample` golden | GS captures under both identities. Until then, no GS-observable changes; GS maintainers smoke-test shared-path PRs |
| E12 | dr-scripts consumers of raw stream text with no capture of the relevant output in either dialect | Captures in both dialects | sorter (`(You are\|He is\|She is) wearing`, LOOK item lists), playermonitor (`WHO`), healme (wound-healed messages), textsubs (name-bearing substitutions) | False positives/negatives if those outputs gained links | A capture of each output in the Saga dialect; open a dr-scripts PR only if it breaks |

## Parked fixes (known bugs, intentionally not fixed yet)

| # | Item | Where | Why parked | Unpark when |
|---|---|---|---|---|
| P1 | Title lost after `" and "`: `and Druid X` drops `Druid` | room players title capture (XMLParser text handler) | Shared with GS; no GS oracle (E11) | E11 closed |
| P2 | Greedy status regex eats the next title: `who is sitting and Druid` | same | same | E11 closed |
| P3 | `@pc` not reset at the start of a players refresh, so status can attach to the previous room's pc | `begin_room_players` path | same | E11 closed |
| P4 | Titles containing an apostrophe (`War 'Tog X`) | same | Needs a spec first; GS behavior unknown | Fix with P1–P3 |
| P5 | DR `GroupMembers` (`<pushStream id="group"/>  (?<member>\w+):`) misses a leader other than you (`  X (Leader): Healthy.`) and records `You` as a member | `drparser.rb` | **Pre-existing in both dialects.** Replay confirms the legacy stream uses the same `(Leader)` shape; not a Saga regression | Separate `fix(dr)` |
| P6 | Legacy DR players splitter keeps a trailing period on the last name (`Chieftain X.`) | XMLParser DR players branch | Pre-existing legacy behavior; changing it alters legacy goldens | Separate `fix(dr)` with deliberate golden update |
| P7 | Legacy DR players carry no status in `GameObj.pcs` (`who is ...` / `(...)` is parsed but dropped) | GameObj pc status is keyed by id; legacy players have none | Pre-existing; the Saga dialect's linked players do carry status | Separate `fix(dr)` if a consumer needs it |

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

## Series decisions (scope changes made during implementation)

| Planned item | Decision | Evidence |
|---|---|---|
| Order-independent `<crtrStatus>` apply | Dropped; only the move into the game deltas shipped | DR's id-first sync already works in either order (Saga goldens show flags on the right ids); GemStone was never observed sending `<crtrStatus>` after the creature link |
| DR injury radio modes; shared `InjuriesBase` | Blocked | Needs E1 (a Saga `_injury` capture) |
| `DRStats.position` from indicators | Dropped | `DRStats.position` is combat advantage from the balance line, not posture; the posture predicates (`sitting?`, `kneeling?`, `standing?`, `checkprone`) already read `XMLData.indicator` for both games in global_defs.rb |
| `Flags` in common code | Deferred (product decision) | It would add a new feature to GemStone; DR Flags already match link-stripped lines (DRParser.match_line) |
| `DRRoom` backed by GameObj/Creature | Deferred until the legacy dialect is gone | Legacy room objects carry no object links: the legacy stream carries ids elsewhere (hand tags, `<crtrStatus>`, the inventory feed) but never an `<a exist>` link in `room objs`, so `gameobj.npcs` is populated in 0% of legacy-fixture prompts. DRRoom therefore cannot be GameObj-backed while both dialects are live |
| dr-scripts fixes | status-monitor fix in elanthia-online/dr-scripts#7664 (the open refactor #7402 needs the same change); droughtmans needs none (its `^Obvious` matches stripped lines, restored by the `<room>` parsing); healer's raw-line hook strips every tag itself before matching, and its room scan reads `DRRoom.pcs`, which DRParser fills from the link-stripped line (the Saga goldens show linked names parsed); echo only logs raw lines; the rest are E12 | Replay goldens, the Saga captures and each script's source |

