#!/usr/bin/env bash
# =============================================================================
# test-bundle-default-scripts.sh - Tests for bundle_default_scripts.rb
# Builds a throwaway repository shaped like elanthia-online/scripts, then
# checks which version of each script is bundled for a given Lich release.
# Needs the repository's Ruby on PATH: the script loads lib/common/script.rb.
# Shell compatibility: macOS's default Bash 3.2 and newer.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLER="$SCRIPT_DIR/../scripts/bundle_default_scripts.rb"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/scripts-repo"
OUT="$WORK/out"
LOG="$WORK/log"

# Keep the throwaway repository independent of this machine's Git settings.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

PASSED=0
FAILED=0

# Write scripts/<name> with a marker line and an optional "required:" header.
write_script() {
  local name="$1" marker="$2" required="${3:-}"
  {
    echo "=begin"
    echo "  $name test fixture"
    if [[ -n "$required" ]]; then
      echo "  required: $required"
    fi
    echo "=end"
    echo "echo '$marker'"
  } > "$REPO/scripts/$name"
}

# Commit everything in the throwaway repository and print the new commit id.
commit() {
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "$1"
  git -C "$REPO" rev-parse HEAD
}

# Print a directory whose lib/version.rb declares the given Lich version.
lich_root() {
  local dir="$WORK/lich-$1"
  mkdir -p "$dir/lib"
  printf "LICH_VERSION = '%s' # x-release-please-version\n" "$1" > "$dir/lib/version.rb"
  echo "$dir"
}

# bundle LICH_VERSION [SCRIPT ...]: run the script into a fresh $OUT, log to $LOG.
bundle() {
  local version="$1"
  shift
  rm -rf "$OUT"
  ruby "$BUNDLER" --dest "$OUT" --repo "$REPO" --lich-root "$(lich_root "$version")" "$@" > "$LOG" 2>&1
}

# picks LICH_VERSION SCRIPT COMMIT FLOOR MARKER: the run succeeds, logs the
# chosen commit and floor, and writes that version's content.
picks() {
  local version="$1" name="$2" commit="$3" floor="$4" marker="$5"
  bundle "$version" "$name" || return 1
  grep -Fq "$name: commit $commit, floor $floor" "$LOG" || return 1
  grep -Fxq "echo '$marker'" "$OUT/$name"
}

# fails_with LICH_VERSION MESSAGE [SCRIPT ...]: the run fails, reports MESSAGE
# as an error, and writes nothing.
fails_with() {
  local version="$1" message="$2"
  shift 2
  if bundle "$version" "$@"; then
    return 1
  fi
  grep -Fq "::error::" "$LOG" || return 1
  grep -Fq -- "$message" "$LOG" || return 1
  [[ ! -e "$OUT" ]]
}

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "[PASS] $label"
    ((++PASSED))
  else
    echo "[FAIL] $label"
    if [[ -f "$LOG" ]]; then
      sed 's/^/    /' "$LOG"
    fi
    ((++FAILED))
  fi
}

echo "Testing default script bundling by Lich version floor..."
echo

# --- Repository history ------------------------------------------------------
git -c init.defaultBranch=master init -q "$REPO"
mkdir -p "$REPO/scripts"

write_script rising.lic "rising v1"
write_script steady.lic "steady v1"
write_script ancient.lic "ancient v1" "Lich >= 99.0.0"
write_script gone.lic "gone v1"
write_script restored.lic "restored v1"
write_script merged.lic "merged v1"
C_BASE="$(commit "add scripts")"

write_script rising.lic "rising v2" "Lich >= 5.13.0"
C_RISING_V2="$(commit "rising v2")"

write_script steady.lic "steady v2"
C_STEADY_V2="$(commit "steady v2")"

write_script rising.lic "rising v3" "Lich >= 5.26.0"
C_RISING_V3="$(commit "rising v3")"

git -C "$REPO" rm -q scripts/gone.lic scripts/restored.lic
commit "remove gone and restored" > /dev/null

write_script restored.lic "restored v2" "Lich >= 5.26.0"
C_RESTORED_V2="$(commit "restore restored")"

# A merged branch whose first commit never was the state of master.
git -C "$REPO" checkout -q -b side
write_script merged.lic "merged side-only" "Lich >= 5.13.0"
commit "merged side-only" > /dev/null
write_script merged.lic "merged v2" "Lich >= 5.26.0"
commit "merged v2" > /dev/null
git -C "$REPO" checkout -q master
git -C "$REPO" merge -q --no-ff -m "merge side" side
C_MERGE="$(git -C "$REPO" rev-parse HEAD)"

# --- A floor that rises over the script's history ------------------------------
check "5.25.0 gets the newest version it can run" \
  picks 5.25.0 rising.lic "$C_RISING_V2" "Lich >= 5.13.0" "rising v2"
check "5.25.0 run reports the tip version it held back" \
  grep -Fq "held back: branch tip needs Lich >= 5.26.0, 1 newer version(s) skipped" "$LOG"
check "5.26.0-beta.0 meets a 5.26.0 floor" \
  picks 5.26.0-beta.0 rising.lic "$C_RISING_V3" "Lich >= 5.26.0" "rising v3"
check "5.26.0 meets a 5.26.0 floor" \
  picks 5.26.0 rising.lic "$C_RISING_V3" "Lich >= 5.26.0" "rising v3"
check "5.12.0 falls back to the version with no floor" \
  picks 5.12.0 rising.lic "$C_BASE" "none" "rising v1"

# --- No floor ----------------------------------------------------------------
check "a script with no floor comes from the branch tip" \
  picks 5.25.0 steady.lic "$C_STEADY_V2" "none" "steady v2"

# --- History shapes ------------------------------------------------------------
check "a merged branch's intermediate commit is not a candidate" \
  picks 5.25.0 merged.lic "$C_BASE" "none" "merged v1"
check "the merge itself is the version master holds" \
  picks 5.26.0 merged.lic "$C_MERGE" "Lich >= 5.26.0" "merged v2"
check "a commit that removed the script is skipped" \
  picks 5.25.0 restored.lic "$C_BASE" "none" "restored v1"
check "a restored script is taken from its newest version when it runs" \
  picks 5.26.0 restored.lic "$C_RESTORED_V2" "Lich >= 5.26.0" "restored v2"

# --- Failures ----------------------------------------------------------------
check "a floor no version meets fails" \
  fails_with 5.25.0 "ancient.lic: none of the 1 version(s) on the branch runs on Lich 5.25.0 (lowest floor: Lich >= 99.0.0)" ancient.lic
check "one unbundleable script stops the others being written" \
  fails_with 5.25.0 "ancient.lic: none of the 1 version(s)" steady.lic ancient.lic
check "a script that never existed fails" \
  fails_with 5.25.0 "nosuch.lic: scripts/nosuch.lic is missing at the branch tip" nosuch.lic
check "a script removed from the branch tip fails" \
  fails_with 5.25.0 "gone.lic: scripts/gone.lic is missing at the branch tip" gone.lic

# With no names the default list is bundled; none of it is in this repository.
default_list_is_required() {
  local name
  if bundle 5.25.0; then
    return 1
  fi
  for name in alias autostart ewaggle go2 jinx lich5-update log map repository vars version; do
    grep -Fq "::error::$name.lic: scripts/$name.lic is missing at the branch tip" "$LOG" || return 1
  done
  [[ "$(grep -c "::error::" "$LOG")" -eq 11 ]]
}
check "every default script is required when no names are given" default_list_is_required

unreadable_repository_fails() {
  rm -rf "$OUT"
  if ruby "$BUNDLER" --dest "$OUT" --repo "$WORK/no-such-repo" --lich-root "$(lich_root 5.25.0)" steady.lic > "$LOG" 2>&1; then
    return 1
  fi
  grep -Fq "::error::git clone" "$LOG" && [[ ! -e "$OUT" ]]
}
check "an unreadable scripts repository fails" unreadable_repository_fails

missing_version_file_fails() {
  rm -rf "$OUT"
  mkdir -p "$WORK/empty-lich"
  if ruby "$BUNDLER" --dest "$OUT" --repo "$REPO" --lich-root "$WORK/empty-lich" steady.lic > "$LOG" 2>&1; then
    return 1
  fi
  grep -Fq "::error::" "$LOG" && grep -Fq "lib/version.rb not found" "$LOG" && [[ ! -e "$OUT" ]]
}
check "a tree with no lib/version.rb fails" missing_version_file_fails

TOTAL=$((PASSED + FAILED))
echo
echo "Tests passed: $PASSED/$TOTAL"
echo "Tests failed: $FAILED/$TOTAL"

[[ $FAILED -eq 0 ]]
