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

### #1703

### #1704

### #1705

### #1706

### #1707

### #1709

### #1711

### #1713

### #1721

### #1722

### #1725
