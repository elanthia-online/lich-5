# Test Fixtures

This directory contains static test fixtures used by the RSpec test suite.

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

