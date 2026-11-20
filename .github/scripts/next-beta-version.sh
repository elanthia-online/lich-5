#!/usr/bin/env bash
# =============================================================================
# next-beta-version.sh - Compute the prerelease version to pin (Release-As)
# =============================================================================
# Prints the next beta version, e.g. "v5.26.0-beta.1".
#
# Base version: taken from the latest stable tag (vX.Y.Z) reachable from the
# stable ref. It is the next minor (vX.Y+1.0) when a feat commit exists between
# that tag and the head ref, otherwise the next patch (vX.Y.Z+1).
#
# Beta number: one more than the highest existing v<base>-beta.N tag, or 0 when
# the base has no beta tag yet. Every tag in the repository is considered, not
# only tags reachable from the head ref, because a prerelease branch that is
# rebuilt from the stable branch does not contain the tags of earlier betas.
#
# Prints nothing and exits 0 when no stable tag is found.
#
# Usage: next-beta-version.sh [stable-ref] [head-ref]
#   stable-ref  Ref whose history holds the stable tags (default: origin/main)
#   head-ref    Tip of the prerelease branch (default: HEAD)
#
# Shell compatibility: runs under macOS's default Bash 3.2 and newer.
# =============================================================================

set -euo pipefail

# Print the latest stable tag (vX.Y.Z, no prerelease suffix) reachable from a ref.
latest_stable_tag() {
  local ref="$1"
  # awk reads every line so git never writes to a closed pipe.
  git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --merged "$ref" --sort=-version:refname |
    awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ && !found { print; found = 1 }'
}

# Print the next beta number for a base version (X.Y.Z).
next_beta_number() {
  local base="$1"
  local prefix="v${base}-beta."
  local tag n highest=-1

  while IFS= read -r tag; do
    n="${tag#"$prefix"}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    n=$((10#$n))
    if (( n > highest )); then
      highest="$n"
    fi
  done < <(git tag -l "${prefix}*")

  echo $((highest + 1))
}

main() {
  local stable_ref="${1:-origin/main}" head_ref="${2:-HEAD}"
  local stable subjects base

  stable="$(latest_stable_tag "$stable_ref")"
  if [[ ! "$stable" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    return 0
  fi
  local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"

  # A feat commit (feat:, feat(scope): or feat!:) since the stable tag starts
  # the next minor; fixes and chores alone start the next patch.
  subjects="$(git log --format=%s "${stable}..${head_ref}")"
  if grep -Eq '^feat[(:!]' <<< "$subjects"; then
    base="${major}.$((minor + 1)).0"
  else
    base="${major}.${minor}.$((patch + 1))"
  fi

  echo "v${base}-beta.$(next_beta_number "$base")"
}

main "$@"
