#!/usr/bin/env bash
# =============================================================================
# test-curate-theirs.sh - Tests for squashing PRs with conflict_strategy=theirs
# (.github/scripts/curate-pre-branch.sh), run against throwaway repositories.
#
# The main fixture is a stack: three PRs where each head contains the layers
# below it. Squashing the layers in order onto the base they share must leave
# the tree of the top layer.
# =============================================================================

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURATE_SCRIPT="${TEST_DIR}/../scripts/curate-pre-branch.sh"

# Keep the throwaway repositories independent of the machine's git setup.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.invalid"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.invalid"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# The curate functions write temporary files and GitHub Actions state; keep
# both inside the work directory and away from a real runner's files.
export TMPDIR="$WORK_DIR"
export GITHUB_ENV=/dev/null GITHUB_OUTPUT=/dev/null GITHUB_STEP_SUMMARY=/dev/null

ORIGIN="${WORK_DIR}/origin.git"
SEED="${WORK_DIR}/seed"
LOG_FILE="${WORK_DIR}/curate.log"

# shellcheck source=.github/scripts/curate-pre-branch.sh
source "$CURATE_SCRIPT"

echo "Testing curate with conflict_strategy=theirs..."
echo

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  ((++TESTS_RUN))
  ((++TESTS_PASSED))
  echo "[PASS] $1"
}

# Report a failure with the captured curate output. The output is prefixed so
# a runner does not read its lines as workflow commands.
fail() {
  ((++TESTS_RUN))
  ((++TESTS_FAILED))
  echo "[FAIL] $1"
  shift
  if [[ $# -gt 0 ]]; then
    printf '  %s\n' "$@"
  fi
  sed 's/^/  | /' "$LOG_FILE"
}

assert_equals() {
  local expected="$1" actual="$2" test_name="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$test_name"
  else
    fail "$test_name" "Expected: $expected" "Got: $actual"
  fi
}

# Write a file in the seed repository, one argument per line.
# Args: $1 = path inside the repository, $2... = lines
put() {
  local path="${SEED}/$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# Commit every change in the seed repository.
# Args: $1 = commit subject
commit_all() {
  git -C "$SEED" add -A
  git -C "$SEED" commit -q -m "$1"
}

# Start a branch in the seed repository.
# Args: $1 = new branch, $2 = start point
branch_from() {
  git -C "$SEED" checkout -q -b "$1" "$2"
}

# Publish a seed branch on the origin as the head of a PR.
# Args: $1 = branch, $2 = PR number
publish_pr() {
  git -C "$SEED" push -q origin "$1:refs/pull/$2/head"
}

# Clone the origin and squash PRs onto a fresh pre/beta the way the curate
# does for open PRs.
# Args: $1 = clone path, $2 = conflict strategy, $3... = PR numbers
curate() {
  local clone="$1" pr
  STRAT_SAFE="$2"
  SQUASH_SAFE=true
  shift 2

  git clone -q "$ORIGIN" "$clone"
  cd "$clone"
  setup_conflict_strategy
  create_or_reset_branch pre/beta origin/main
  for pr in "$@"; do
    cherry_pick_open_pr "$pr" "feat(all): change ${pr} (#${pr})"
  done
}

# Clone the origin and sync an existing destination branch with its base.
# Args: $1 = clone path, $2 = conflict strategy, $3 = destination, $4 = base
sync_base() {
  local clone="$1"
  STRAT_SAFE="$2"
  DEST_SAFE="$3"
  BASE_SAFE="$4"
  RESET_SAFE=false

  git clone -q "$ORIGIN" "$clone"
  cd "$clone"
  setup_conflict_strategy
  prepare_branch
}

# Run a curate function in a subshell, as a script run would, and record its
# exit status in RUN_STATUS. Must not be called from a condition, or the
# subshell would ignore errexit.
# Args: $1 = function, $2... = its arguments
run() {
  : > "$LOG_FILE"
  set +e
  ( set -e; "$@" ) >> "$LOG_FILE" 2>&1
  RUN_STATUS=$?
  set -e
}

# Print the tree of a commit.
# Args: $1 = repository, $2 = commit
tree_of() {
  git -C "$1" rev-parse "$2^{tree}"
}

# -----------------------------------------------------------------------------
# Fixture
# -----------------------------------------------------------------------------

git init -q --bare "$ORIGIN"
git -C "$ORIGIN" symbolic-ref HEAD refs/heads/main
git init -q "$SEED"
git -C "$SEED" symbolic-ref HEAD refs/heads/main
git -C "$SEED" remote add origin "$ORIGIN"

put keep.txt "kept as it is"
put shared.txt "first line" "setting = base" "last line"
put lib/legacy_a.rb "class LegacyA" "  def call" "    :a" "  end" "end"
put lib/legacy_b.rb "module LegacyB" "  VALUE = :b" "end"
put lib/dropped.rb "DROPPED = %w[one two three].freeze"
commit_all "chore(all): base"
git -C "$SEED" push -q origin main

# Layer 1: edits the shared line, edits both legacy files, deletes dropped.rb.
branch_from layer1 main
put shared.txt "first line" "setting = layer one" "last line"
put lib/legacy_a.rb "class LegacyA" "  def call" "    :a_from_layer_one" "  end" "end"
put lib/legacy_b.rb "module LegacyB" "  VALUE = :b_from_layer_one" "end"
git -C "$SEED" rm -q lib/dropped.rb
put lib/layer_one.rb "# added by layer one" "LAYER_ONE = 1"
commit_all "feat(all): layer one"
publish_pr layer1 1

# Layer 2: edits the shared line again and deletes a file layer 1 edited.
branch_from layer2 layer1
put shared.txt "first line" "setting = layer two" "last line"
git -C "$SEED" rm -q lib/legacy_a.rb
put lib/layer_two.rb "# added by layer two" "LAYER_TWO = 2"
commit_all "feat(all): layer two"
publish_pr layer2 2

# Layer 3: deletes the other file layer 1 edited and brings back, with new
# content, the file layer 1 deleted.
branch_from layer3 layer2
git -C "$SEED" rm -q lib/legacy_b.rb
put lib/dropped.rb "RESTORED = %w[four five six seven].freeze" "RESTORED_BY = :layer_three"
put lib/layer_three.rb "# added by layer three" "LAYER_THREE = 3"
commit_all "feat(all): layer three"
publish_pr layer3 3

# Two independent PRs that rename the same file to different names.
branch_from rename_one main
git -C "$SEED" mv lib/legacy_b.rb lib/renamed_one.rb
commit_all "feat(all): rename one way"
publish_pr rename_one 11

branch_from rename_two main
git -C "$SEED" mv lib/legacy_b.rb lib/renamed_two.rb
commit_all "feat(all): rename another way"
publish_pr rename_two 12

# A destination branch that edited a file its base branch has since deleted.
branch_from pre/beta/sync main
put lib/legacy_a.rb "class LegacyA" "  def call" "    :a_from_the_destination" "  end" "end"
commit_all "feat(all): destination edit"
git -C "$SEED" push -q origin pre/beta/sync

branch_from sync-base main
git -C "$SEED" rm -q lib/legacy_a.rb
commit_all "feat(all): base deletion"
git -C "$SEED" push -q origin sync-base

# -----------------------------------------------------------------------------
# theirs: a stack is squashed layer by layer
# -----------------------------------------------------------------------------

stack="${WORK_DIR}/stack"
run curate "$stack" theirs 1 2 3

if [[ $RUN_STATUS -eq 0 ]]; then
  pass "theirs: a stack of three PRs is squashed without stopping"

  assert_equals "3" "$(git -C "$stack" rev-list --count origin/main..HEAD)" \
    "theirs: one squash commit per PR"
  assert_equals "$(tree_of "$SEED" layer1)" "$(tree_of "$stack" HEAD~2)" \
    "theirs: tree after layer 1 equals the layer 1 head"
  assert_equals "$(tree_of "$SEED" layer2)" "$(tree_of "$stack" HEAD~1)" \
    "theirs: tree after layer 2 equals the layer 2 head"
  assert_equals "$(tree_of "$SEED" layer3)" "$(tree_of "$stack" HEAD)" \
    "theirs: curated tree equals the top of the stack"
  assert_equals "" "$(git -C "$stack" status --porcelain)" \
    "theirs: nothing is left unmerged or uncommitted"

  assert_equals "setting = layer one" "$(git -C "$stack" show HEAD~2:shared.txt | sed -n 2p)" \
    "theirs: destination holds the layer 1 line before layer 2 is squashed"
  assert_equals "setting = layer two" "$(git -C "$stack" show HEAD~1:shared.txt | sed -n 2p)" \
    "theirs: a content conflict takes the PR's side"

  if git -C "$stack" cat-file -e HEAD~1:lib/legacy_a.rb 2>/dev/null; then
    fail "theirs: a file the destination edited and the PR deleted stays deleted"
  else
    pass "theirs: a file the destination edited and the PR deleted stays deleted"
  fi
  assert_equals "$(git -C "$SEED" show layer3:lib/dropped.rb)" \
    "$(git -C "$stack" show HEAD:lib/dropped.rb 2>/dev/null || true)" \
    "theirs: a file the destination deleted and the PR edited keeps the PR's version"
else
  fail "theirs: a stack of three PRs is squashed without stopping" "Exit status: $RUN_STATUS"
fi

# -----------------------------------------------------------------------------
# The rule belongs to theirs and to modify/delete conflicts only
# -----------------------------------------------------------------------------

run curate "${WORK_DIR}/abort" abort 1 2
if [[ $RUN_STATUS -ne 0 ]]; then
  pass "abort: the same stack stops on its first conflict"
else
  fail "abort: the same stack stops on its first conflict"
fi

run curate "${WORK_DIR}/ours" ours 1 2
if [[ $RUN_STATUS -ne 0 ]]; then
  pass "ours: a modify/delete conflict still stops the curate"
else
  fail "ours: a modify/delete conflict still stops the curate"
fi

run curate "${WORK_DIR}/renames" theirs 11 12
if [[ $RUN_STATUS -ne 0 ]]; then
  pass "theirs: a conflict of another kind still stops the curate"
else
  fail "theirs: a conflict of another kind still stops the curate"
fi

sync="${WORK_DIR}/sync"
run sync_base "$sync" theirs pre/beta/sync sync-base
if [[ $RUN_STATUS -ne 0 ]]; then
  pass "theirs: a base sync still stops on a modify/delete conflict"
else
  fail "theirs: a base sync still stops on a modify/delete conflict"
fi
assert_equals "$(git -C "$SEED" rev-parse pre/beta/sync)" "$(git -C "$sync" rev-parse pre/beta/sync)" \
  "theirs: a stopped base sync leaves the destination where it was"

echo
echo "Tests passed: $TESTS_PASSED/$TESTS_RUN"
echo "Tests failed: $TESTS_FAILED/$TESTS_RUN"

[[ $TESTS_FAILED -eq 0 ]]
