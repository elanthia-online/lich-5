# Stream replay fixtures

Captured DragonRealms and GemStone server streams, replayed by
`spec/stream_replay/stream_replay_spec.rb` through a real `lich.rbw --pipe`
process (see `spec/support/stream_replay/`). Each fixture's per-prompt parsed
state must match `goldens/<name>.jsonl`.

All fixtures come from `;logxml streams` captures and were produced with
`spec/support/stream_replay/extract.rb`:
- timestamps, client echoes and reget content stripped;
- windows snapped to prompt boundaries;
- a synthetic login header added, or, for a window that starts at a real login, the login's own lines kept (`--real-login`, with the stored `<settings>` blob emptied by `--drop-settings-body`);
- every player name pseudonymized and account names replaced.

Character names below are the pseudonyms used inside the fixture.

DragonRealms has two dialects:
- **legacy** is the stream sent to a front end that identifies as Wrayth 1.0.1.28. This is the default before #1700, and still what Genie, Warlock and Wrayth get.
- **saga** is the stream sent for the `/VERSION:saga-… /P:SAGA` identity. This is the default after #1700 for Wizard/Avalon, Frostbite, Mudlet and `--without-frontend`, which includes Profanity (it runs Lich with `--without-frontend`).

| Fixture | Dialect | Captured | Prompts | Covers |
|---|---|---|---|---|
| `dr_legacy_hunt.xml` | legacy | 2026-10-15 15:35 | 341 | hunting: bold room objs, dead NPCs, assess, combat stream, percWindow, PC postures, spell prep/castTime, movement |
| `dr_legacy_stow_movement.xml` | legacy | 2026-10-15 15:20 | 70 | inventoryManager, `clearContainer`/`<inv id='stow'>` (plain text, no links), movement with roomName |
| `dr_legacy_hide_whisper.xml` | legacy | 2026-10-07 | 57 | IconHIDDEN, whispers |
| `dr_legacy_group.xml` | legacy | 2026-10-07 | 32 | group stream incl. `You (Leader)` |
| `dr_legacy_bank.xml` | legacy | 2026-10-03 | 15 | bank clerk lines |
| `dr_saga_hunt.xml` | saga | 2026-10-15 16:15 | 276 | hunting: `<a exist>` links with doubled bold, dead NPCs, assess with nested `<d><a>`, combat, percWindow, `<room>` block, movement |
| `dr_saga_inventory.xml` | saga | 2026-10-15 16:15 | 56 | INV SEARCH, passive inventoryManager, linked hands |
| `dr_saga_stow.xml` | saga | 2026-10-15 16:15 | 10 | linked stow container feed (`<inv id='stow'>` with links, no `<container>`) |
| `dr_saga_group_bank.xml` | saga | 2026-10-15 16:37 | 79 | group join/list/leave with another leader, bank balance with linked name |
| `dr_saga_containers_speech.xml` | saga | 2026-10-15 17:49 | 100 | open/close/look in/rummage, bank deposit/withdraw, hide/unhide, linked speech preset |
| `dr_saga_login.xml` | saga | 2026-10-16 09:00 | 2 | C8 capture `2026-10-16_09-00-23`, lines 2–228, cut with `--real-login --drop-settings-body`. Real Saga login: the stored `<settings>` record (emptied), `<settingsInfo instance='DR'>` at line 5, `<app char>`, a linked worn list before any other link, `<exposeContainer>`/`<container id='stow' target>` + `clearContainer` + the first stow header on one line (line 35), the stream-window and injury declarations, `<endSetup/>`, `<nav>`, the room components and then the first `<room>` block |
| `dr_saga_no_room_heavens.xml` | saga | 2026-10-16 09:18 | 9 | C8 capture `2026-10-16_09-00-23`, lines 10717–10725 and 10803–10839, joined at a prompt boundary (`sed -n` of both ranges, then extract.rb with no window). A `<room>` block from LOOK, then a `[The Heavens]` view with a bare `<nav/>` and ` - [The Heavens] (**)` subtitles, and the return to the room, both sent as legacy room components with no `<room>` |
| `dr_saga_locate_descflag.xml` | saga | 2026-10-16 14:26 | 21 | DR-extra (C2) capture `2026-10-16_14-26-39`, lines 2–94 (synthetic header). FLAG DESCRIPTION OFF and its reply, the own room's `<room>` (description still sent), a Locate whose view of another room is a bare `<room>` with its description and no `<nav>`, subtitle or room components, then FLAG DESCRIPTION ON and the own room again |
| `gs_saga_login.xml` | GS, Saga identity | 2026-10-15 11:29 | 1 | GS-15 capture `2026-10-15_11-29-55`, lines 1–80, cut with `--real-login --end-prompt` (the window ends mid-login, so the closing prompt is the driver's synthetic one). Real login: `<settingsInfo instance='GSF'>` at line 5, then bracketless main/room subtitles (` - Shattered Nexus - 7199`), `compDef` room parts, a linked worn list, and `<exposeContainer>`/`<container id='stow' target>` + `clearContainer` + the first stow header on one line; no `<room>`. GS sends no `<app char>` in these 80 lines, so extract.rb adds one |
| `gs_saga_hunt.xml` | GS, Saga identity | 2026-10-15 15:08 | 14 | GS-15 capture `2026-10-15_15-08-37`, lines 2–130 (synthetic header). A move with `<nav>`, bracketless subtitles, `compDef` room parts, `<roommeta>`, the `roomName`/`roomDesc` styles and a `<dir>` compass; the main-text room view with `<crtrStatus>` before a doubled-bold (`<pushBold/><pushBold/>`) creature link; standalone `<crtrStatus>` tags before a `room objs` component whose own tag precedes a single-bold `<b> <pushBold/>…<popBold/></b>` link; linked combat lines in single bold |

`benchmark/fixtures/gs_sample.xml` and `dr_sample.xml` are also replayed (goldens `gs_sample.jsonl`, `dr_sample.jsonl`). `gs_sample` was committed in 6366dc03 (#1396) on 2026-06-28, before #1700 made Saga the default identity, so it was captured under the legacy identity. Its `settingsInfo client=` value doesn't show the identity: that attribute belongs to the stored settings record, and the Saga-identity `gs_saga_login.xml` carries `client="1.0.1.28"` while DR Saga logins carry `1.0.1.26`. `gs_sample` and the two `gs_saga_*` captures are the GS replay oracles for shared-path changes. All three have `<a exist>` links and no `<room>` block (see E11 in `docs/saga-stream-deferred.md`); doubled bold is covered under Negative evidence.

## Regenerating

- **A fixture:** run `extract.rb` against the source log with the same `--from`/`--to`, and pass `--scrub-names` a local, uncommitted list of names that must never appear in the repo.
- **Goldens:** `UPDATE_STREAM_GOLDENS=1 bundle exec rspec spec/stream_replay`. Review every golden diff in the PR; a changed golden is a behavior change.

## Negative evidence

Absences can't be fixtures. Each row records the corpus that was searched and what was counted.
The corpora are `;logxml streams` captures that are not committed. Characters are pseudonymised as C1–C8.
The counts come from the reviews of each PR in the Saga-stream series and were not recounted for this file; where two reviews counted differently, the row gives both values.

| Corpus | What it is |
|---|---|
| DR-16 | 116 DragonRealms captures, 2026-10-16, 8 characters (C1–C8), about 3.30M lines. C6 ran Profanity. (Other reports count 107 to 131 DR files, depending on what they included; this file uses 116 DR + 15 GS + 1 extra) |
| DR-16 Saga | 108 of them (C1–C7, and C8 from 09:00), 3,087,133 lines. 89 contain `<room>`, with 53,663 blocks |
| DR-16 legacy | C8's 8 captures from 00:00 to 08:48, 214,898 lines. The character stood in one room: 8 moves, no login |
| DR-extra | 1 DragonRealms capture, 2026-10-16 14:26, C2, 227 lines (FLAG DESCRIPTION OFF/ON and a Locate) |
| GS-15 | 15 GemStone (Shattered) captures, 2026-10-15, about 414,000 lines, 41,384 prompts, 2 with a login. Recorded while Lich sent the Saga client string (per the user; the stream itself can't show the handshake) |
| FIX | the committed fixtures in this directory and `benchmark/fixtures/` |

No legacy-identity GemStone capture exists apart from `benchmark/fixtures/gs_sample.xml`, committed 2026-06-28 before #1700.
The front end that recorded each `dr_legacy_*` fixture was not noted when it was captured.

Each PR in the series records its own rows under its heading.

### #1701

| Absent or counted | Corpus |
|---|---|
| DR legacy dialect: 0 `<a exist>` links, 0 `<pushBold/><pushBold/>`, 0 `<room>` blocks | DR-16 legacy (214,898 lines); the 5 `dr_legacy_*` fixtures and `dr_sample.xml` |
| DR Saga sends 0 `<style id="roomName"/>` and 0 `<preset id='roomDesc'>` (the legacy FIX streams have 39 and 15) | DR-16 Saga (89 captures with `<room>`); the 5 `dr_saga_*` fixtures |
| GemStone sends 0 `<room>` blocks; it sends `<roommeta>` and the `roomName` style instead (11,002 of each) | GS-15; `gs_sample.xml`, `gs_saga_login.xml`, `gs_saga_hunt.xml` |
| GemStone doubled bold: 2,293 `<pushBold/><pushBold/>` against 33,775 single. `gs_sample.xml` has 0 doubled. In the committed captures the doubled bold sits in the main-text room view (`roomDesc` … `You also see <crtrStatus/><pushBold/><pushBold/>a <a …>`), a shape `gs_sample` doesn't contain, while `room objs` components use `<b> <pushBold/>…<popBold/></b>` in both identities. Whether doubled bold depends on the identity is not known: no legacy-identity GS capture of a room view exists | GS-15 (Saga identity); `gs_sample.xml` (legacy identity), `gs_saga_hunt.xml` |

### #1702

| Absent or counted | Corpus |
|---|---|
| 0 room components spanning lines; 0 `<a>` unbalanced, nested or split across lines. Every DR `<a>` is `<a exist="…" noun="…">`: 0 `href`, 0 other attributes (the DR link total is 2,047,948 to 2,087,191 depending on the report). 0 GS `room objs` in a familiar or peer stream (GS sends its room parts as `compDef` inside `pushStream id='room'`, as `gs_saga_hunt.xml` shows) | DR-16 + GS-15 (about 3.7M lines); the 5 `dr_saga_*` fixtures (2,386 links, all `exist`/`noun`) |
| DR doubled bold: 345,655 doubled pushes and 345,655 doubled pops, in 54,632 lines; every line with a doubled push has the doubled pop; 0 triples; 0 doubled spans without a link inside. Doubled bold occurs only in room-object listings (`room objs`, `<exists>`). The 510 lines with unbalanced bold are single-bold spans split across lines (0 doubled) | DR-16 Saga; the 5 `dr_saga_*` fixtures (39 doubled-bold lines, all balanced, all in `room objs` or `<exists>`) |
| Saga exp components: 0 of 4,171 `<component id='exp …'>` lines carry an `<a exist>` link. The same captures carry links elsewhere, and the Lich that recorded them rewrites inline exp on the line as sent, links kept, so a link from the server would have been logged. The game also refuses `toggle expbrief` under the Saga identity ("This toggle is not available for characters using a Front End other than Wrayth.", seen by the user on 2026-10-17). The linked exp lines in `drparser_spec.rb` are synthetic | C8's 11 Saga-stream captures of 2026-10-17 (not in the corpus table) |

### #1703

| Absent or counted | Corpus |
|---|---|
| `<settingsInfo>`: 3 occurrences, each at line 5 of a real login (C8 09:00; GS 11:29 and 12:38). 0 mid-session; 0 on the same line as a main `streamWindow` subtitle; 0 creature tags before it in any of the 3 logins; 0 captures that start at a login without one. `dr_saga_login.xml` and `gs_saga_login.xml` are two of the three logins | DR-16 + GS-15 (131 captures) |
| 0 links with `exist=""` | DR-16 + GS-15; FIX |

### #1704

| Absent or counted | Corpus |
|---|---|
| GemStone main subtitles: 11,004 of 11,004 have no brackets (` - Area, Title - N`); 0 without a number; 0 shorter than 3 characters. `gs_saga_login.xml` and `gs_saga_hunt.xml` carry the shape | GS-15 |
| DragonRealms main subtitles: 0 of 51,722 without a room marker (a number or `(**)`); 10 with `(**)`, all `[The Heavens]` (`dr_saga_no_room_heavens.xml` carries two) | DR-16 |

### #1705

| Absent or counted | Corpus |
|---|---|
| Players lists: the 24,589 linked lists contain 0 unlinked players, and 0 link-free lists occur in a capture that has links. The 1,106 link-free lists are each one tag-free run on one line | 107 DR-16 Saga captures; DR-16 legacy; the legacy FIX streams |
| Legacy bold runs that are only an article: 0 of 187 room-objs bold runs in `dr_legacy_hunt.xml` (0 of 253 bold runs in all the legacy FIX streams). DR-16 legacy has almost no room objects (the character stood still), so FIX is the corpus | FIX |
| Saga room objs: 63,702 components with 337,203 linked creatures. Articles: a 336,525, an 611, the 28, none 39; 0 "some", 0 capitalised. 0 single-bold components; 0 bold text outside a link except a bare article; 0 `a <pushBold/><a` (article outside the bold) | DR-16 Saga |
| GemStone room objs: 0 "which appears dead" in 13,869 components (GS says "that is/appears …"). DragonRealms: 205 "which appears dead", 26 of them followed by ` and some junk.`; one is committed as `spec/fixtures/creature/dr_saga_room_objs_shapes.xml` | GS-15; DR-16 Saga |
| Assess (4,069 pushes, 2,829 linked subjects): the subject's `exist` equals the `look #` id in 2,829 of 2,829; 0 links outside `<d>`; 0 `<d>` without a link; 0 first links that are not the subject; 0 subjects whose `noun=` (trimmed) differs from the text's last word. GS-15: 0 assess streams. DR-16 legacy: 0 assess lines (FIX has 14, in `dr_legacy_hunt.xml`) | DR-16 + DR-extra |
| Room objs link `noun=` differing from the text's last word: 0 of the 125 "white-tailed leopard" links in C8 `2026-10-17_00-00-00`, all `noun="leopard"`. The shape #1705 handles for long-named pets is still not captured. A padded noun is: C1 `2026-10-17_03-49-51` sends `noun=" moth"` (committed in `spec/fixtures/creature/dr_saga_room_objs_shapes.xml`) | 2 user-named 2026-10-17 captures (not in the corpus table) |

### #1706

| Absent or counted | Corpus |
|---|---|
| GemStone `<crtrStatus>`, 22,903 tags: 11,694 inside `room objs`, each before its creature's link (0 after). 11,209 standalone: 11,200 for a creature in the current room roster, 3 known only to the registry, 6 never linked (11,203 if counted as "linked earlier in the log"). 0 tags without `health`/`maxhealth`; 0 flags `="0"`; 0 ids recycled inside a room between refreshes. `gs_saga_hunt.xml` carries a room-objs tag before its link and standalone tags before a `room objs` component. These rows back #1716 too | GS-15 |
| DragonRealms sends 0 `<crtrStatus>` inside a `room objs` component; the batch follows the component | DR-16; the `dr_saga_*` and `dr_legacy_hunt.xml` fixtures |

### #1707

| Absent or counted | Corpus |
|---|---|
| `<room>` block shape, 53,663 blocks: 0 opening tags with attributes; 0 not preceded by `<resource picture="0"/>` at line start; 0 lines with two blocks; 0 out-of-order, repeated or self-closed children; 0 elements other than `<crtrStatus>` between parts (0 to 17 tags, in 2,616 blocks); 0 `<name>` without `[…]`; 0 `<name>` with `(**)`; 0 empty `<exits>`; 0 non-empty `<extra>`; 0 lines with content after `</room>` (6 with trailing whitespace) | DR-16 Saga; the `<room>` blocks in the `dr_saga_*` fixtures |
| Legacy `roomName` text: 11,035 of 11,035 bracketed | GS-15 (11,002), DR-16 legacy, FIX |
| `<room>` split across lines: 0 of 53,663 blocks. 0 of 53,666 lines with `<room>` over DR-16, GS-15 and DR-extra (the 3 extra are DR-extra's). 0 `<room>` without `</room>` on the same line, and 0 the other way | DR-16 Saga; DR-16 + GS-15 + DR-extra |
| `<description>` empty or self-closing: 0 of 53,663, including every block sent while FLAG DESCRIPTION was OFF (48,826 to 48,937 such blocks, depending on the report). `dr_saga_locate_descflag.xml` shows the description still sent while OFF | DR-16 Saga; DR-extra |

### #1709

| Absent or counted | Corpus |
|---|---|
| `<container id='stow'>`: 1 in DR-16, at C8's login (line 35, committed in `dr_saga_login.xml`), and 0 before any of the 1,657 linked mid-session stow feeds. 0 changes of the stow container. 0 legacy DR logins in the corpus, so the legacy login shape is unknown. GemStone resends the tag mid-session (20 to 22 tags in 8 captures, depending on the report, always the same target) | DR-16; GS-15 |
| Stow feed (DR: 2,126 bursts, 1,657 linked and 469 plain; GS: 3,043 bursts or 3,044 headers, depending on the report): each burst has exactly 1 `clearContainer` and 1 header; every header has exactly 1 link (0 with two or more); 0 headers other than `In the …:` (`On`/`Under`/`Behind` never occur); 0 legacy headers with a link; 0 GS headers naming a container other than the tag's; 0 stow items outside a burst; 0 `<inv>` split across lines; 0 empty refreshes; 0 `… is closed.` headers | DR-16; GS-15 |
| Worn list: 15,951 blocks hold only item lines between push and pop (624,413 linked, 25,040 plain); 0 mixed lists (Saga 14,675, all linked; legacy 1,252, all plain) | DR-16 |

### #1711

| Absent or counted | Corpus |
|---|---|
| DragonRealms sends 0 `nextLvlPB` and 0 Active Spells/Buffs/Debuffs/Cooldowns `dialogData`; the DR dialog ids seen are `minivitals` and `injuries` | DR-16; the `dr_*` fixtures (`minivitals` 189, `injuries` 19) |
| GemStone's `nextLvlPB` text never changes mid-session; GemStone sends 0 combat, atmospherics or familiar streams (this also backs #1710) | GS-15; `gs_sample.xml`, `gs_saga_login.xml`, `gs_saga_hunt.xml` |

### #1713

### #1721

### #1722

### #1725
