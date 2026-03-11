#!/usr/bin/env bash
# =============================================================================
# run-tests.sh - Test runner for all tests
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Override GitHub Actions environment for testing
export GITHUB_ENV="${GITHUB_ENV:-/dev/null}"
export GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/null}"
export GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

TOTAL_PASSED=0
TOTAL_FAILED=0

run_test_suite() {
  local test_file="$1"
  local test_name
  test_name="$(basename "$test_file")"

  echo "=========================================="
  echo "Running: $test_name"
  echo "=========================================="

  if bash "$test_file"; then
    echo "✓ $test_name PASSED"
    echo
    ((TOTAL_PASSED++))
  else
    echo "✗ $test_name FAILED"
    echo
    ((TOTAL_FAILED++))
  fi
}

main() {
  echo "Starting test suite..."
  echo

  # Run all test files
  while IFS= read -r test_file; do
    run_test_suite "$test_file"
  done < <(find "$SCRIPT_DIR" -name "test-*.sh" -type f)

  echo "=========================================="
  echo "Test Summary"
  echo "=========================================="
  echo "Suites passed: $TOTAL_PASSED"
  echo "Suites failed: $TOTAL_FAILED"
  echo

  if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo "OVERALL: FAILED"
    exit 1
  else
    echo "OVERALL: SUCCESS"
    exit 0
  fi
}

main "$@"
