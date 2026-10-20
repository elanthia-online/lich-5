# Test Fixtures

This directory contains static test fixtures used by the RSpec test suite.

## lich.db3

### What is it?

`lich.db3` is a sample SQLite database file added with the Settings module
(PR #591). It serves as a reference fixture for database schema and structure.

### Current Status

**Note:** The Settings specs currently use `mock_database_adapter.rb` for
in-memory testing rather than this file. This fixture is retained for:
- Schema reference when developing database-related features
- Potential future integration tests that need a real database

## effect-list.xml

### What is it?

`effect-list.xml` contains spell definitions for GemStone IV, including:
- Spell numbers, names, and types
- Duration formulas
- Mana/stamina/spirit costs
- Buff/debuff bonuses
- Start/end messages for spell detection

This file is used by `Lich::Common::Spell.load()` to populate the spell database.

### Why is it here?

**This is a LOCAL COPY to eliminate network dependencies during testing.**

Without this fixture, tests would need to download the file from GitHub on every
run, which:
- Slows down test execution
- Fails when offline or GitHub is unavailable
- Makes tests non-deterministic (upstream changes could break tests)

### Canonical Source

The authoritative version lives in the elanthia-online/scripts repository:

```text
https://github.com/elanthia-online/scripts/blob/master/scripts/effect-list.xml
```

### Keeping it Updated

**IMPORTANT: This fixture must be periodically synced with upstream!**

When new spells are added to GemStone IV, or spell properties change, the
upstream effect-list.xml is updated by the community. Our local copy will
become stale if not refreshed.

#### Manual Update

```bash
curl -o spec/fixtures/effect-list.xml \
  https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts/effect-list.xml
```

#### From a local lich-5 data directory

If you have a running lich-5 installation with an up-to-date effect-list.xml:

```bash
cp /path/to/lich-5/data/effect-list.xml spec/fixtures/effect-list.xml
```

### Future Automation (TODO)

We should automate keeping this fixture current. Options include:

1. **GitHub Actions workflow** - Weekly scheduled job to check for upstream
   changes and open a PR if the file differs

2. **Dependabot-style automation** - Custom action that monitors the upstream
   repo and creates update PRs

3. **Pre-release hook** - Check fixture freshness as part of the release
   process and warn/fail if stale

4. **Git submodule** - Track elanthia-online/scripts as a submodule (adds
   complexity but ensures consistency)

Until automation is in place, maintainers should periodically check for
upstream changes, especially after major GemStone IV updates that add new
spells or modify existing ones.


## creature/dr_saga_room_objs_shapes.xml

### What is it?

Lines captured verbatim from DragonRealms Saga-dialect `;logxml streams`
sessions, one per room-objects shape the XMLParser creature path branches on.
Only the per-line timestamp is removed; a line that named a player would be
pseudonymised and its player id remapped (see `spec/fixtures/streams/MANIFEST.md` for the corpus labels).

| Shape | Source | Used by |
|---|---|---|
| `room objs` with a corpse `</a><popBold/><popBold/> which appears dead,`, caged creatures `that is caught in …`, plain creatures and the ` and some junk.` tail after the last creature | C7, `2026-10-16_01-57-21`, line 13664 | `xmlparser_dr_creature_spec.rb` ("reads every status on a captured Saga room objs line") |
| `room objs` whose first creature link is padded, `noun=" moth"`, beside four unpadded `noun="moth"` siblings, one `(immobile)`; the ` and some junk.` tail follows a non-creature item | C1, `2026-10-17_03-49-51`, line 22331 (the same line repeats at 22335) | `xmlparser_dr_creature_spec.rb` ("trims the padded noun … for the DR roster …") |

Shapes #1705 also handles that no fetched capture holds yet, so they are
specced with synthetic lines only: a link whose `noun=` differs from the text's
last word (a long-named pet), a padded `noun=" moth"` in assess (the room objs
form is captured above), a `the <a …>` named NPC, an article-less NPC, and a
creature-behind-creature assess subject. A long-named creature checked for the
first shape, the "white-tailed leopard" of C8 `2026-10-17_00-00-00`, does not
supply it: all 125 of its links in that capture send `noun="leopard"`, the
text's last word.

## room_block/dr_legacy_desc_no_objects.xml

### What is it?

A legacy-dialect DragonRealms room view captured verbatim (per-line
timestamps removed): the `roomName` line, the description line and the exits
line for a room with no objects, so the description line ends
`…</preset>  ` with nothing after the two spaces.

| Shape | Source | Used by |
|---|---|---|
| legacy `<style id=""/><preset id='roomDesc'>…</preset>  ` with no objects | C2, `2026-10-07_13-38-12`, lines 35–37 | `room_block_spec.rb` ("rewrites a captured Saga block into the captured legacy lines for the same room"), against the Saga `<room>` for the same room in `streams/dr_saga_locate_descflag.xml` |

## room_block/dr_legacy_locate.xml

### What is it?

A legacy-dialect DragonRealms capture (per-line timestamps and the
command echoes removed, player names pseudonymised): two moves, each with its
room view and the top-level `<compass>` after the exits line, then a Locate
whose view of another room (230008, while the character stands in 230007) is
followed by that room's compass, `<compass><dir value="n"/><dir value="s"/></compass>`.

| Shape | Source | Used by |
|---|---|---|
| legacy own-room views with their compasses; a Locate view of another room followed by the located room's compass | C2, `2026-10-07_13-38-12`, lines 5–39, 45–46 and 77–86 | `room_block_spec.rb` ("rebuilds the compass the legacy stream sent after every exits line in the legacy captures"; "sends after a captured Saga Locate view the exits line and compass the legacy stream sent after its Locate view") |

## room_block/dr_legacy_no_exits.xml

### What is it?

The room-exits lines of a legacy-dialect DragonRealms view of a room without
exits: the `room exits` component, `Obvious paths: none.` and the top-level
empty `<compass></compass>` the legacy stream sent after it. Copied from
ProfanityFE's public fixture `spec/fixtures/room_pipeline/dr_cut_short_objs.xml`
(main, 3dae6f2), lines 5, 10 and 11; line 11 is cut after `</compass>`, because
the `room players` component that shared the line names players. Only these
lines are copied. The capture is from 2026-08-27; the character is not
recorded.

| Shape | Source | Used by |
|---|---|---|
| legacy `Obvious paths: none.` followed by `<compass></compass>` | ProfanityFE `dr_cut_short_objs.xml:5,10-11` | `room_block_spec.rb` ("rebuilds the compass …"; "gives a captured Saga room without exits the legacy view's exits line and empty compass") |

## room_block/dr_saga_no_exits.xml

### What is it?

Two Saga-dialect DragonRealms lines captured verbatim (per-line timestamps
removed) for a room without exits: the `room exits` component and the `<room>`
block, whose `<exits>` is `Obvious paths: none.` with no `<d>`.

| Shape | Source | Used by |
|---|---|---|
| Saga `<room>` with `<exits>Obvious paths: none.</exits>` | C7, `2026-10-16_01-57-21`, lines 16015 and 16017 | `room_block_spec.rb` ("gives a captured Saga room without exits …") |

A Saga `<room>` whose exits are hidden by fog is not in any fetched capture,
so its wording in `room_block_spec.rb` is synthetic.

## room_block/dr_saga_arrival_without_exits_component.xml

### What is it?

Two Saga-dialect DragonRealms arrivals captured verbatim (per-line timestamps
removed): the first with every room component, the second (room 2108013) with
no `room exits` or `room players` component before its `<room>` block. It is
the one arrival without a `room exits` component in the Saga logs.

| Shape | Source | Used by |
|---|---|---|
| an arrival whose `<room>` (with a room number) has no `room exits` component before it | C7, `2026-10-16_01-57-21`, lines 14731–14752 | `room_block_spec.rb` ("sends the compass of the block, not the exits XMLParser kept from the last room") |

## room_block/dr_saga_peer.xml

### What is it?

A Saga-dialect DragonRealms capture cut with extract.rb (per-line timestamps
and the command echoes removed, player names pseudonymised and player ids
remapped; the synthetic header dropped): from room 230008, PEER SOUTH and PEER
NORTH, each answered by `You peer <dir> and see ...` and a bare `<room>` block
of the room peered into (230007, 230009) with no `<nav>`, subtitle or room
components, then LOOK and the `<room>` block of 230008. No capture has a
legacy-dialect PEER.

| Shape | Source | Used by |
|---|---|---|
| a PEER view: "You peer south/north and see ..." and a bare `<room>` of the room peered into; the own room's `<room>` after LOOK | C8, `2026-10-17_13-24-35`, lines 14–19, 39–44 and 74–77 | `room_block_spec.rb` ("gives each PEER view the compass of the room peered into …"; "sends after the PEER view of 230007 the exits line and compass the legacy stream sent in 230007"), `games_spec.rb` ("sends the compass of the room peered into after a captured PEER view") |

## flag/dr_saga_flag_listing.xml

The reply to a bare `FLAG` command on the DragonRealms Saga-identity stream,
captured from C6's session on 2026-10-17 at 07:27 (corpus labels in
`spec/fixtures/streams/MANIFEST.md`): the usage help, then the table in a mono
block. Each row links the flag name with a `<d>` whose `cmd` is the toggle
(the opposite of the Status column), and the first row leads with
`<popBold/>`. Log timestamps were stripped; it holds no character names.

Used by `room_description_filter_spec` and `games_spec`, which read the
Description row from it. The listing was taken with descriptions ON; the OFF
listing is the next fixture.

## flag/dr_saga_flag_listing_description_off.xml

The same `FLAG` listing taken with descriptions OFF, then the game's replies to
FLAG DESCRIPTION ON and OFF, from C8's Saga-identity session on 2026-10-17 at
12:12 (`2026-10-17_11-02-10`). The Description row is
`  <d cmd="flag Description on">Description</d>        OFF  Do not display room descriptions.`:
the `cmd` is the ON command, the opposite of the Status column. The command
echoes and log timestamps were stripped; it holds no character names.

| Shape | Source | Used by |
|---|---|---|
| the listing (usage help and table) with the Description row OFF, and its prompt | C8, `2026-10-17_11-02-10`, lines 27148–27200 | `room_description_filter_spec` (".observe with the bare FLAG listing"), `games_spec` ("with the bare FLAG listing") |
| `You will now see room descriptions.` and its prompt | same capture, lines 27202–27203 | `room_description_filter_spec` (the listing, reply, listing sequence) |
| `You will no longer see room descriptions.` and its prompt | same capture, lines 27282–27283 | `room_description_filter_spec` (the listing, reply, listing sequence) |

In the capture, the next listing (after the ON reply) is the ON table of the
previous fixture apart from the Avoid* and NoHarnessShare rows, and the one
after the OFF reply starts as this table does, Description row OFF included.

## stow/dr_saga_handover.xml

### What is it?

Four lines from one DragonRealms Saga-dialect `;logxml streams` session, each
followed by the prompt that came after it, cut with
`spec/support/stream_replay/extract.rb` (timestamps removed, the other
character's name pseudonymised and player id remapped). Between them the session holds other output
that the parser does not need here.

| Line | Shape | Source (C8, `2026-10-17_00-00-00`) |
|---|---|---|
| 1 | own stow burst: `clearContainer`, header `In the <a exist="200981348" noun="pack">pack</a>:`, 6 items, then the PUT echo on the same line | line 229 |
| 3 | `You accept <a …>Brenna</a>'s offer and are now holding a <a exist="200708744" noun="pack">scuffed traveler's pack</a>.` | line 575 |
| 5 | stow burst whose header names the handed-over pack (`In the <a exist="200708744" …>`), 71 items | line 617 |
| 7 | the next own stow burst (header 200981348 again, 5 items), after the pack was given back | line 1402 |

Used by `xmlparser_inventory_streams_spec.rb` ("stow feed for a handed-over
pack (captured)"), with and without a login `<container id='stow'>`. The
capture's login is not in the fixture, so the tagged examples feed a tag of
the shape `streams/dr_saga_login.xml` captured, naming this capture's pack.

## crtr_status/gs_saga_crtr_status.xml

Six verbatim server lines from a GemStone Shattered `;logxml` capture of
2026-10-15 15:08, one of the 15 GemStone captures recorded that day while Lich
sent the Saga client string. Lines 1-3 are capture lines 11, 18 and 29; lines
4-6 are capture lines 569, 576 and 598.

| Line | Shape |
|---|---|
| 1 | `<nav>` and the room window: a room-objs `compDef` with `<crtrStatus>` just before the creature's `<a exist>` link |
| 2 | the main-text room description: `You also see <crtrStatus …/>` inline, then a doubled-bold link |
| 3 | combat: two standalone tags for the same creature on one line (the second `dead`/`prone`), then a room-objs refresh |
| 4-5 | the same pair as lines 1-2, for a second creature in the next room |
| 6 | a room-objs `component`: the tag after a non-creature link and just before the creature's link |

Every tag here carries `health`/`maxhealth` and no flag is `="0"`, as in all
22,903 tags of the 15 captures. The older fragments in
`xmlparser_crtr_status_spec.rb`, which its comments describe as live GST
captures, include tags without `health` and with `hostile="0"`; the spec
covers both. The fetched window holds no tag just before a `room players`
component (the third standalone position, seen in the 15-log scan), so that
shape has no fixture yet.

Exist ids, room numbers and creature names are as captured. The one player
name (a disk owner's) was replaced with a pseudonym. Line endings were
normalised to LF.

Used by `spec/lib/common/xmlparser_crtr_status_spec.rb`.

## client_string_log/

Lich's debug log from six live sessions on 2026-10-17, one per front end,
each from start-up to "logged in as": five on Windows (Lich 5.22.0, Ruby
4.0.7) and Avalon on macOS (Lich 5.23.0, Ruby 4.0.5). Each
holds the two lines `Frontend.log_client_string` writes at login: the client
string the front end sent and the one Lich sent the game.

| File | Front end | Game | Login path |
|---|---|---|---|
| `wizard_gs.log` | Wizard 2.04 | GemStone | launcher (eaccess), GSL branch |
| `avalon_gs.log` | Avalon | GemStone (GST) | CLI login (eaccess), GSL branch |
| `frostbite_dr.log` | Frostbite | DragonRealms | game-host spoof, Frostbite branch |
| `genie_dr.log` | Genie | DragonRealms | game-host spoof, proxy (`proxy_handshake`) |
| `warlock_dr.log` | Warlock | DragonRealms | game-host spoof, proxy |
| `wrayth_gs.log` | Wrayth | GemStone | launcher (eaccess), proxy |

Avalon introduces itself as Wizard (`/FE:WIZARD /VERSION:2.02 /P:WIN32`), even
on macOS. The Wizard, Avalon and Frostbite captures predate the "(Lich's, in
place of the front end's)" note on those paths' sent-to-game line.

The character names were replaced with `Testchar`. The login key was already
scrubbed by Lich. The Avalon log is cut at "logged in as", which drops a later
error from an unrelated script, and everything else is as captured.

Used by `spec/lib/main/client_string_log_spec.rb`, which replays each
front-end line through its login path.
