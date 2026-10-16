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
