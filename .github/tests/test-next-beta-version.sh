#!/usr/bin/env bash
# =============================================================================
# test-next-beta-version.sh - Tests for the prerelease version pin
# (.github/scripts/next-beta-version.sh), run against throwaway repositories.
# =============================================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN_SCRIPT="${TEST_DIR}/../scripts/next-beta-version.sh"

# Keep the throwaway repositories independent of the machine's git setup.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.invalid"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Testing prerelease version pin..."
echo

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local expected="$1" actual="$2" test_name="$3"
  ((++TESTS_RUN))

  if [[ "$expected" == "$actual" ]]; then
    echo "[PASS] $test_name"
    ((++TESTS_PASSED))
  else
    echo "[FAIL] $test_name"
    echo "  Expected: $expected"
    echo "  Got: $actual"
    ((++TESTS_FAILED))
  fi
}

# Create a repository whose main branch has one commit.
# Args: $1 = repository path
new_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" symbolic-ref HEAD refs/heads/main
  git -C "$repo" commit -q --allow-empty -m "chore: initial commit"
}

# Add an empty commit to the checked-out branch.
# Args: $1 = repository path, $2 = commit subject
add_commit() {
  git -C "$1" commit -q --allow-empty -m "$2"
}

# Tag a commit that is not reachable from main or from the prerelease head,
# the way the tag of an earlier beta is left behind when its branch is rebuilt.
# Args: $1 = repository path, $2 = tag name
tag_off_branch() {
  local repo="$1" tag="$2" commit
  commit="$(git -C "$repo" commit-tree -m "chore: release ${tag}" "main^{tree}")"
  git -C "$repo" tag "$tag" "$commit"
}

# Print the pinned version for a repository (stable ref main, head ref HEAD).
pin_for() {
  (cd "$1" && bash "$PIN_SCRIPT" main HEAD)
}

# --- Minor base: a feat commit exists since the latest stable tag -------------
feat_repo="${WORK_DIR}/feat"
new_repo "$feat_repo"
git -C "$feat_repo" tag v5.24.0
add_commit "$feat_repo" "fix(all): something released"
git -C "$feat_repo" tag v5.25.0
git -C "$feat_repo" checkout -q -b pre/beta
add_commit "$feat_repo" "fix(all): a fix on the beta"
add_commit "$feat_repo" "feat(all): a feature on the beta"

assert_equals "v5.26.0-beta.0" "$(pin_for "$feat_repo")" \
  "no beta tags: pins beta.0"

for other_base in v5.25.1-beta.5 v5.27.0-beta.9 v5.2.0-beta.7 v15.26.0-beta.8 v5.26.1-beta.6; do
  tag_off_branch "$feat_repo" "$other_base"
done
assert_equals "v5.26.0-beta.0" "$(pin_for "$feat_repo")" \
  "beta tags of other versions are ignored"

tag_off_branch "$feat_repo" v5.26.0-beta.0
assert_equals "v5.26.0-beta.1" "$(pin_for "$feat_repo")" \
  "existing beta.0 not reachable from the head: pins beta.1"

tag_off_branch "$feat_repo" v5.26.0-beta.3
assert_equals "v5.26.0-beta.4" "$(pin_for "$feat_repo")" \
  "existing beta.0 and beta.3: pins beta.4"

tag_off_branch "$feat_repo" v5.26.0-beta.10
assert_equals "v5.26.0-beta.11" "$(pin_for "$feat_repo")" \
  "beta numbers compare numerically (beta.10 above beta.3)"

tag_off_branch "$feat_repo" v5.26.0-beta.12-rc
assert_equals "v5.26.0-beta.11" "$(pin_for "$feat_repo")" \
  "a tag with a non-numeric beta suffix is ignored"

# --- Patch base: no feat commit since the latest stable tag -------------------
fix_repo="${WORK_DIR}/fix"
new_repo "$fix_repo"
git -C "$fix_repo" tag v5.25.0
git -C "$fix_repo" checkout -q -b pre/beta
add_commit "$fix_repo" "fix(all): a fix on the beta"
add_commit "$fix_repo" "chore(all): features are mentioned, feat: not at the start"
tag_off_branch "$fix_repo" v5.26.0-beta.2

assert_equals "v5.25.1-beta.0" "$(pin_for "$fix_repo")" \
  "fixes only, no beta tags: pins the next patch at beta.0"

tag_off_branch "$fix_repo" v5.25.1-beta.0
assert_equals "v5.25.1-beta.1" "$(pin_for "$fix_repo")" \
  "fixes only, existing beta.0: pins the next patch at beta.1"

# --- Stable tag selection -----------------------------------------------------
# A feat commit released in the latest stable tag does not count again, and a
# stable tag that main does not contain is not used as the base.
released_repo="${WORK_DIR}/released"
new_repo "$released_repo"
git -C "$released_repo" tag v5.24.0
add_commit "$released_repo" "feat(all): a feature already released"
git -C "$released_repo" tag v5.25.0
git -C "$released_repo" checkout -q -b pre/beta
add_commit "$released_repo" "fix(all): a fix on the beta"
tag_off_branch "$released_repo" v6.0.0

assert_equals "v5.25.1-beta.0" "$(pin_for "$released_repo")" \
  "base comes from the latest stable tag main contains"

# --- No stable tag ------------------------------------------------------------
untagged_repo="${WORK_DIR}/untagged"
new_repo "$untagged_repo"
add_commit "$untagged_repo" "feat(all): a feature"
tag_off_branch "$untagged_repo" v5.26.0-beta.0

assert_equals "" "$(pin_for "$untagged_repo")" \
  "no stable tag: prints nothing"

echo
echo "Tests passed: $TESTS_PASSED/$TESTS_RUN"
echo "Tests failed: $TESTS_FAILED/$TESTS_RUN"

[[ $TESTS_FAILED -eq 0 ]]
