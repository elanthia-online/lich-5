# Saga XML stream support: deferred items

Since #1700, Lich identifies as Saga (`/VERSION:saga-… /P:SAGA`) on the handshakes that use `Frontend::CLIENT_STRING`: Wizard/Avalon, Frostbite, Mudlet and `--without-frontend`. Profanity is in that group: it runs Lich with `--without-frontend --detachable-client` (ProfanityFE's USER_GUIDE) and sends no handshake of its own, and a Profanity session's logs (2026-10-16) show the Saga stream. Front ends that send their own handshake (Genie, Warlock, Wrayth) still get the legacy stream. **DragonRealms therefore has two stream dialects live at once**, and Lich must parse both: DR Saga captures carry the `<room>` block and `<a exist>` links in room objects, players and the stow feed, and DR legacy captures carry neither.

GemStone has one dialect as far as the captures show: `<a exist>` links and no `<room>` under both identities. DragonRealms only now sends links, to the Saga identity. Logs from 15 GS Shattered sessions (2026-10-15, "GS-15"), recorded with Lich sending the Saga client string (per the user), show `<a exist>` links in room objects, players and the stow feed, doubled bold (`<pushBold/><pushBold/>`), `roomName`/`roomDesc` styles, `compDef`/`component` room parts, `<roommeta>`, and main `streamWindow` subtitles with no brackets (` - Name - 1234`). They carry no `<room>` element, so **the `<room>` block is DragonRealms-only**. Two short cuts of them are committed with goldens, `spec/fixtures/streams/gs_saga_login.xml` and `gs_saga_hunt.xml`, so anyone can repeat the check. The committed `gs_sample` stream has the same links and no `<room>`; it was committed on 2026-06-28 (6366dc03, #1396), before #1700, so it was captured under the legacy identity. It has no doubled bold, but it also has no main-text room view, which is where the GS Saga captures carry their doubled bold; its `room objs` components use `<b> <pushBold/>…<popBold/></b>` exactly as the Saga captures' do. So whether GS's doubled bold depends on the identity is not known (`MANIFEST.md`, Negative evidence). This closes E11 for links and `<room>`.

This file tracks what the Saga-dialect work has **not** verified or fixed yet. It exists so nothing is dropped silently.

**Rules:**
- While an item is open, this series leaves the code paths it touches unchanged. This is a rule for the Saga-stream PRs, not a freeze on other work. The legacy replay goldens and existing specs protect those paths.
- Closing an item means: add a capture to `spec/fixtures/streams/`, record its golden, and compare it with the other dialect. Open a fix only if that comparison shows a difference.
- Every PR touching a related area repeats the relevant items under "Known gaps".

## Missing evidence

| # | Item | Missing | Code it could affect | Risk if the Saga shape differs | Closes when |
|---|---|---|---|---|---|
| E1 | Injury radios / `_injury N -1` mode switching | Saga capture | radio handler in `XMLParser#tag_start`, `fix_injury_mode` (games.rb) | DR radio ids (`injrRadExt`/`injrRadInt`/…) never match the GS ids, so `XMLData.injury_mode` never updates on DR; Wounds/Scars read the wrong mode. Blocks the DR injury-mode fix | Saga capture with a wound or scar, cycling `_injury 0/1/3/4 -1` and `health` |
| E2 | Room with no UID (`(**)`) | A move into a no-UID room, in either dialect. The only `(**)` shape in the 2026-10-16 logs (10 to 12 subtitles, all `[The Heavens]`) is committed as `dr_saga_no_room_heavens.xml`: a bare `<nav/>`, ` - [The Heavens] (**)` subtitles and legacy room components, with no `<room>` | streamWindow subtitle UID parsing, `map_dr` title/description/exits fallback, the `(**)` room-number display | go2 / `Map.current` fail in unmapped or no-UID rooms | Capture entering a `(**)` room |
| E3 | Familiar / vision room views | A Saga familiar view. A remote view is committed: `dr_saga_locate_descflag.xml` holds a Locate, which arrives as a bare `<room>` (with its description, even under FLAG DESCRIPTION OFF) and no `<nav>`, subtitle or room components | familiar parsing keyed on `roomName`/`roomDesc` (XMLParser, markup.rb), the familiar prefix in `process_room_information` | Familiar room views not parsed or rendered | Saga capture on a character with a familiar |
| E4 | Room-window-disabled room | Captures in both dialects | `room_window_disabled` + `<dir>` compass path | The Saga dialect sends no `<dir>`, so exits may be empty there | Captures in both dialects |
| E5 | Servant / escort block | Captures in both dialects | common-travel Flag `^A servant (blocks\|stops)` | go2 doesn't react if the servant is linked or reworded | Captures in both dialects |
| E6 | `...wait N seconds` split room component | Captures in both dialects | `GameInstance#buffer_room_objs` | Split component not reassembled, so that refresh loses room objs/players | Captures in both dialects |
| E7 | Mount / gelapod in room objs | Captures in both dialects | drdefs `MOUNT_DESCRIPTION`, `GELAPOD`; GS mount inference in XMLParser | Mounts misclassified as NPCs, or the gelapod not recognized | Captures in both dialects |
| E8 | Scar images in the injuries dialog | Captures in both dialects | injuries `<image>` handler (`Scar\d`) | Scars not tracked | Captures in both dialects (overlaps E1) |
| E9 | IconSTUNNED / IconWEBBED | Saga capture | `stunned?` / `webbed?` | Low: the tag is the same in both dialects | Saga capture while stunned or webbed |
| E10 | ESP thoughts stream | A committed Saga capture (the 2026-10-16 DR logs hold 27 thought lines with linked names; none is committed) | DR Flags and scripts on thought text | Name-anchored thought Flags break if names are linked | Saga capture with a telepathy source |
| E11 | GemStone under the Saga identity: **closed 2026-10-16** for links and `<room>` | Nothing for links and `<room>`: `gs_sample` (legacy identity) and the GS Saga captures `gs_saga_login.xml`/`gs_saga_hunt.xml` both have links and no `<room>`. Doubled bold is seen only in the Saga captures, in a shape `gs_sample` lacks (see the intro) | every shared parser path | None from a dialect switch for links and `<room>`. Shared-path changes can still break GS, so they are checked against the goldens of `gs_sample`, `gs_saga_login` and `gs_saga_hunt` | Closed for links and `<room>`. Doubled bold under the legacy identity needs a legacy-identity GS capture of a room view |
| E12 | dr-scripts consumers of raw stream text with no capture of the relevant output in either dialect | Captures in both dialects | sorter's other inputs (`(You are\|He is\|She is) wearing`, the LOOK items list; its container lists get their own fix, see Series decisions), playermonitor (`WHO`), healme (wound-healed messages), textsubs (name-bearing substitutions) | False positives/negatives if those outputs gained links | A capture of each output in both dialects; open a dr-scripts PR only if the comparison shows a difference |

## Parked fixes (known bugs, intentionally not fixed yet)

| # | Item | Where | Why parked | Unpark when |
|---|---|---|---|---|
| P1 | Title lost after `" and "`: `and Druid X` drops `Druid` | room players title capture (XMLParser text handler) | Shared with GS, so a fix changes what GS sees; not part of this series | A separate fix PR, checked against the `gs_sample`, `gs_saga_login` and `gs_saga_hunt` goldens. Neither GS Saga capture holds a players list, so that PR also commits a short GS capture with one (cut with `extract.rb`) and its golden |
| P2 | Greedy status regex eats the next title: `who is sitting and Druid` | same | same | same |
| P3 | `@pc` not reset at the start of a players refresh, so status can attach to the previous room's pc | `begin_room_players` path | same | same |
| P4 | Titles containing an apostrophe (`War 'Tog X`) | same | Needs a spec first; GS behavior unknown | Fix with P1–P3 |
| P5 | DR `GroupMembers` (`<pushStream id="group"/>  (?<member>\w+):`) misses a leader other than you (`  X (Leader): Healthy.`) and records `You` as a member | `drparser.rb` | **Pre-existing**, not a Saga regression: the regex is the same for both dialects. The legacy fixture shows only `You (Leader)` (`dr_legacy_group.xml:48,57`); another player as leader is captured only in the Saga dialect (`dr_saga_group_bank.xml:27`), so the legacy shape of that line is assumed, not seen | Separate `fix(dr)` |
| P6 | Legacy DR players splitter keeps a trailing period on the last name (`Chieftain X.`) | XMLParser DR players branch | Pre-existing legacy behavior; changing it alters legacy goldens | Separate `fix(dr)` with deliberate golden update |
| P7 | Legacy DR players carry no status in `GameObj.pcs` (`who is ...` / `(...)` is parsed but dropped) | GameObj pc status is keyed by id; legacy players have none | Pre-existing; the Saga dialect's linked players do carry status | Separate `fix(dr)` if a consumer needs it |
| P8 | GemStone `<crtrStatus>` sent outside `room objs` (a standalone combat update for an already-linked creature) is stashed, then discarded when the next `room objs` opens, so `Creature` health lags until the next room refresh and a stun that starts and ends between refreshes is never seen | `<crtrStatus>` handler and the `room objs` open in `XMLParser#tag_start` | **Pre-existing on main since #1425**, not a Saga regression; fixing it changes what GemStone sees, so it doesn't belong in this series | Open as elanthia-online/lich-5#1716 (off main): a standalone tag for a creature in the current room roster is applied at once; everything else is stashed as before, keeping registration on the `room objs` path |

## Corrections recorded during planning

These claims were made during planning and turned out to be false. They are recorded so they aren't re-raised.

| Claim | Why it's false |
|---|---|
| percWindow refreshes lack `pushStream` / active spells wiped | `;logxml` without `streams` drops every line starting with push/popStream; captures with streams show push/clear intact |
| Assess stream gone | Same logxml artifact |
| Injuries `dialogData clear` → ActiveSpell NameError → parser reset | Executed: no reset |
| percWindow `spell.strip!` before the nil check raises | Lich's NilClass patch makes `nil.strip!` return nil |
| `<right/left exist>` is new in the Saga dialect | Legacy streams already carry it |
| `<inv id='stow'>` / `clearContainer` are new in the Saga dialect | Legacy streams send them too, as plain text. What's new is the `<a exist>` links inside them, which make the parser create GameObj entries for the stow container's contents. In a live session the login's `<container id='stow' target='#N'>` tag names the container; only a capture that starts mid-session lacks it |
| `room_count` double-increments via `popStream id='room'` | 0 `popStream id='room'` in the committed DR fixtures, across 71 `<nav>` moves; one compass close per nav. (The "567 moves" figure used during planning has no recorded source) |

## Series decisions (scope changes made during implementation)

| Planned item | Decision | Evidence |
|---|---|---|
| Order-independent `<crtrStatus>` apply | Dropped for DR; only the move into the game deltas shipped. The GemStone half is parked as P8 | DR's id-first sync already works in either order (Saga goldens show flags on the right ids). GemStone does send `<crtrStatus>` after the creature link: in 15 GS logs (2026-10-15), 11,694 of 22,903 tags sit inside `room objs`, each before its creature's link, and the other 11,209 arrive outside `room objs`, 11,203 of them for a creature already linked earlier in the log. The parser drops those (P8) |
| DR injury radio modes; shared `InjuriesBase` | Blocked | Needs E1 (a Saga `_injury` capture) |
| `DRStats.position` from indicators | Dropped | `DRStats.position` is combat advantage from the balance line, not posture; the posture predicates (`sitting?`, `kneeling?`, `standing?`, `checkprone`) already read `XMLData.indicator` for both games in global_defs.rb |
| `Flags` in common code | Deferred (product decision) | It would add a new feature to GemStone; DR Flags already match link-stripped lines (DRParser.match_line) |
| `DRRoom` backed by GameObj/Creature | Deferred until the legacy dialect is gone | Legacy room objects carry no object links: the legacy stream carries ids elsewhere (hand tags, `<crtrStatus>`, the inventory feed) but never an `<a exist>` link in `room objs`, so `gameobj.npcs` is populated in 0% of DR legacy-fixture prompts. DRRoom therefore cannot be GameObj-backed while both dialects are live |
| dr-scripts fixes | status-monitor fix in elanthia-online/dr-scripts#7664 (the open refactor #7402 needs the same change); sorter's container lists are fixed in elanthia-online/dr-scripts#7676, stream-agnostic so it works on both dialects: sorter reads the raw XML line (`want_downstream_xml`), so a linked item reaches `DRC.list_to_array` as `<a exist=… noun="stack">barghest-bone stack</a>`, `DRC.get_noun` returns nil, and the item sorts as `other` instead of its category (the `You rummage … and see` line in `dr_saga_containers_speech.xml`; in the 2026-10-16 DR Saga logs, 242 of 242 rummage lines and 792 of 796 `In/On the … you see` lines carry links, while legacy lines carry none); droughtmans needs none (its `^Obvious` matches stripped lines, restored by the `<room>` parsing); healer's raw-line hook strips every tag itself before matching, and its room scan reads `DRRoom.pcs`, which DRParser fills from the link-stripped line (the Saga goldens show linked names parsed); echo only logs raw lines; the rest are E12 | Replay goldens, the Saga captures and each script's source |

## Stream-shape answers (2026-10-16)

Questions the series' reviews raised about what the game sends. The maintainer answered them, and the 2026-10-16 DR logs (116 files) and 2026-10-15 GS logs (15 files) checked the answers. The logs are authoritative: a shape they never show is treated as not occurring and isn't handled, and a shape they show is handled. Two shapes the logs never show are handled anyway, on the maintainer's word that they can occur: a `<name>` without brackets and an empty `<description>`. The PR named in the first column owns the outcome.

| Question | Answer | Outcome in the code |
|---|---|---|
| Does `<settingsInfo>` arrive mid-session? (#1703) | No, never | The detected stream features last the whole session |
| Can `<settingsInfo>` share a line with the main `streamWindow` subtitle? (#1704) | No | Nothing to handle |
| Do Saga exp components carry `<a exist>` links or doubled bold? (#1702) | Yes | The inline exp rewrite formats the server line itself, so the client keeps the links and bold; only the skill and rate come from the link-stripped copy |
| Is bold around a link doubled or single? (#1702, #1705) | Both occur: doubled in DR Saga room objs and on GS, single in some DR combat lines | Both shapes are handled. If the game changes the shape, adjust then |
| Can a creature link's `noun=` differ from the last word of its text? (#1705) | Yes | `apply_room_name` keeps the link's `noun=`. Assess still ties creatures by the `look #id` id in both dialects. Where the subject is linked, its noun comes from the link's `noun=`; without a link (legacy) it's derived from the name's last word, as before |
| Can a Saga players list hold an unlinked player? (#1705) | Not observed: 0 in 24,589 linked players lists | Nothing extra to handle. The players splitter goes by each list's shape, not by whether the session has links |
| Can a Saga `<name>` lack `[…]`? (#1707) | Yes, in edge cases; none in 53,663 real `<name>` children | `room_name` falls back to the name minus a trailing room number instead of going nil. The legacy `roomName` path gets the same fallback |
| Can a `<room>` child element repeat? (#1707) | Not observed: 0 in 53,663 `<room>` blocks | Not handled |
| Can `<description>` be empty? (#1707) | Possible, not normal; none in 53,663 real blocks | The legacy layout matches what the legacy stream sends for an empty description: no `roomDesc` preset, and no whitespace-only description line in script lines |
| Can one `<room>` block be split across lines? (#1707, #1708) | Not observed: 0 in 53,663 `<room>` blocks | Not handled. The split handling added during review (the #1708 hold and #1707's split-block specs) was removed |
| Is `<room>` sent by GemStone too? | No: GS sends `<roommeta>` and the `roomName`/`roomDesc` styles, never `<room>` (E11) | The `<room>` parsing and rewrite are DragonRealms-only in practice |
| Can two stow containers arrive in one burst? (#1709) | The maintainer thinks never | Accepted limitation: the code assumes one per burst |
| Can a stow header arrive without `clearContainer`? (#1709) | Always has it | Nothing to handle |
