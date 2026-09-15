#!/usr/bin/env bash
# =============================================================================
# test-format-body-harvest.sh - Tests for the RP-bullet PR-number harvest logic
# in .github/actions/format-body/action.yaml (the "Compose prerelease body" step).
#
# The logic under test lives inside a `script:` block in that action.yaml and
# can't be required/sourced directly, so it is mirrored here for standalone
# testing (same approach as test-union-merge.sh's parse_and_resolve_conflicts).
# If the harvest logic in action.yaml changes, update the JS below to match.
# =============================================================================

set -euo pipefail

echo "Testing format-body PR-number harvest..."
echo

# Mirrors the harvest loop body in .github/actions/format-body/action.yaml
# (the "Harvest PR numbers from existing RP bullets" section).
harvest_last_ref() {
  local line="$1"
  node -e '
    const l = process.argv[1];
    const matches = [...l.matchAll(/#(\d+)/g)];
    if (matches.length) process.stdout.write(matches[matches.length - 1][1]);
  ' "$line"
}

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local expected="$1" actual="$2" test_name="$3"
  ((++TESTS_RUN))

  if [[ "$expected" == "$actual" ]]; then
    echo "✓ $test_name"
    ((++TESTS_PASSED))
  else
    echo "✗ $test_name"
    echo "  Expected: $expected"
    echo "  Got: $actual"
    ((++TESTS_FAILED))
  fi
}

# Test 1: squash-merge bullet where the PR's own title referenced the issue
# it closes, so RP renders BOTH numbers as "/issues/" links, issue first,
# real PR last (this is the exact regression from PR #1596/#1599).
squash_merge_line='* **all:** setup_files uses content hash for cache freshness ([#1596](https://github.com/elanthia-online/lich-5/issues/1596)) ([#1599](https://github.com/elanthia-online/lich-5/issues/1599)) ([4968e45](https://github.com/elanthia-online/lich-5/commit/4968e45e92a239a375677e0f4767a67085925089))'
assert_equals "1599" "$(harvest_last_ref "$squash_merge_line")" \
  "squash-merge bullet (issue + PR refs) selects the real PR number"

# Test 2: normal bullet with a single reference.
single_ref_line='* creatures registry housekeeping independent of Combat::Tracker ([#1603](https://github.com/elanthia-online/lich-5/issues/1603))'
assert_equals "1603" "$(harvest_last_ref "$single_ref_line")" \
  "single-reference bullet selects that reference"

# Test 3: reference followed by a trailing commit-SHA link. The SHA link has
# no leading "#" and must not be mistaken for (or shift) the selected number.
ref_plus_sha_line='* infomon - a spells start message refreshes a refreshable timer ([#1585](https://github.com/elanthia-online/lich-5/issues/1585)) ([abc1234](https://github.com/elanthia-online/lich-5/commit/abc1234def))'
assert_equals "1585" "$(harvest_last_ref "$ref_plus_sha_line")" \
  "reference + trailing commit-SHA bullet selects the reference, not the SHA"

echo
echo "Tests passed: $TESTS_PASSED/$TESTS_RUN"
echo "Tests failed: $TESTS_FAILED/$TESTS_RUN"

[[ $TESTS_FAILED -eq 0 ]]
