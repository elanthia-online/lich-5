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
