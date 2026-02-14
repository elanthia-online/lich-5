#!/usr/bin/env bash
# =============================================================================
# test-validation.sh - Unit tests for validation functions
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../../scripts/lib"

# Mock die() for testing (override before sourcing)
die() {
  echo "ERROR: $*" >&2
  return 1
}

# shellcheck source=.github/scripts/lib/validation.sh
source "${LIB_DIR}/validation.sh"

# Test framework
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local expected="$1" actual="$2" test_name="$3"
  ((TESTS_RUN++))

  if [[ "$expected" == "$actual" ]]; then
    echo "✓ $test_name"
    ((TESTS_PASSED++))
  else
    echo "✗ $test_name"
    echo "  Expected: $expected"
    echo "  Got: $actual"
    ((TESTS_FAILED++))
  fi
}

assert_dies() {
  local test_name="$1"
  shift
  ((TESTS_RUN++))

  if "$@" 2>/dev/null; then
    echo "✗ $test_name (should have failed)"
    ((TESTS_FAILED++))
  else
    echo "✓ $test_name"
    ((TESTS_PASSED++))
  fi
}

# Tests for validate_base
test_validate_base() {
  echo "Testing validate_base..."

  assert_equals "main" "$(validate_base "main")" "validate_base: accepts main"
  assert_equals "main" "$(validate_base "refs/heads/main")" "validate_base: strips refs/heads/"
  assert_equals "main" "$(validate_base "  main  ")" "validate_base: trims whitespace"
  assert_dies "validate_base: rejects non-main" validate_base "develop"
  assert_dies "validate_base: rejects pre/beta" validate_base "pre/beta"
}

# Tests for validate_destination
test_validate_destination() {
  echo "Testing validate_destination..."

  assert_equals "pre/beta" "$(validate_destination "pre/beta")" "validate_destination: accepts pre/beta"
  assert_equals "pre/beta/foo" "$(validate_destination "pre/beta/foo")" "validate_destination: accepts pre/beta/foo"
  assert_equals "pre/beta/my-feature" "$(validate_destination "my-feature")" "validate_destination: auto-prefixes slug"
  assert_equals "pre/beta/foo/bar" "$(validate_destination "foo/bar")" "validate_destination: auto-prefixes nested"

  assert_dies "validate_destination: rejects main" validate_destination "main"
  assert_dies "validate_destination: rejects path traversal" validate_destination "../evil"
  assert_dies "validate_destination: rejects whitespace" validate_destination "pre beta"
}

# Tests for validate_pr_list
test_validate_pr_list() {
  echo "Testing validate_pr_list..."

  assert_equals "42" "$(validate_pr_list "42")" "validate_pr_list: single PR"
  assert_equals "12,27,43" "$(validate_pr_list "12,27,43")" "validate_pr_list: multiple PRs"
  assert_equals "12,27,43" "$(validate_pr_list "12, 27, 43")" "validate_pr_list: strips spaces"
  assert_equals "12,27" "$(validate_pr_list "12,27,12")" "validate_pr_list: deduplicates"

  assert_dies "validate_pr_list: rejects empty" validate_pr_list ""
  assert_dies "validate_pr_list: rejects non-numeric" validate_pr_list "abc"
  assert_dies "validate_pr_list: rejects injection" validate_pr_list "12;rm -rf /"
}

# Tests for validate_mode
test_validate_mode() {
  echo "Testing validate_mode..."

  assert_equals "auto" "$(validate_mode "auto")" "validate_mode: accepts auto"
  assert_equals "merged" "$(validate_mode "merged")" "validate_mode: accepts merged"
  assert_equals "head" "$(validate_mode "head")" "validate_mode: accepts head"

  assert_dies "validate_mode: rejects invalid" validate_mode "invalid"
}

# Tests for validate_conflict_strategy
test_validate_conflict_strategy() {
  echo "Testing validate_conflict_strategy..."

  assert_equals "abort" "$(validate_conflict_strategy "abort")" "validate_conflict_strategy: accepts abort"
  assert_equals "ours" "$(validate_conflict_strategy "ours")" "validate_conflict_strategy: accepts ours"
  assert_equals "theirs" "$(validate_conflict_strategy "theirs")" "validate_conflict_strategy: accepts theirs"
  assert_equals "union" "$(validate_conflict_strategy "union")" "validate_conflict_strategy: accepts union"

  assert_dies "validate_conflict_strategy: rejects invalid" validate_conflict_strategy "invalid"
  assert_dies "validate_conflict_strategy: rejects both (old name)" validate_conflict_strategy "both"
}

# Tests for validate_bool
test_validate_bool() {
  echo "Testing validate_bool..."

  assert_equals "true" "$(validate_bool "true" "test")" "validate_bool: accepts true"
  assert_equals "false" "$(validate_bool "false" "test")" "validate_bool: accepts false"

  assert_dies "validate_bool: rejects yes" validate_bool "yes" "test"
  assert_dies "validate_bool: rejects 1" validate_bool "1" "test"
}

# Run all tests
main() {
  echo "=========================================="
  echo "Running validation tests"
  echo "=========================================="
  echo

  test_validate_base
  echo
  test_validate_destination
  echo
  test_validate_pr_list
  echo
  test_validate_mode
  echo
  test_validate_conflict_strategy
  echo
  test_validate_bool

  echo
  echo "=========================================="
  echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "FAILED: $TESTS_FAILED tests failed"
    exit 1
  else
    echo "SUCCESS: All tests passed"
    exit 0
  fi
}

main "$@"
