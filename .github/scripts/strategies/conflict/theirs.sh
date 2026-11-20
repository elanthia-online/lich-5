#!/usr/bin/env bash
# =============================================================================
# strategies/conflict/theirs.sh - Theirs conflict resolution strategy
# =============================================================================
# Returns git flag for using "theirs" strategy (prefer incoming changes), and
# resolves the modify/delete conflicts that flag leaves unmerged.
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
# shellcheck source=.github/scripts/lib/git-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/git-helpers.sh"

get_strategy_flag_theirs() {
  echo "-X theirs"
}

# Resolve modify/delete conflicts in favor of the incoming side. "-X theirs"
# settles content conflicts only and leaves these unmerged.
#   - Deleted by the incoming side, modified here: the file stays deleted.
#   - Deleted here, modified by the incoming side: the incoming version is kept.
# Any other kind of conflict is left unmerged.
# Returns: 0 if no conflicted file remains, 1 otherwise
resolve_modify_delete_theirs() {
  local file

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # A modify/delete conflict has a common ancestor and exactly one side.
    git_stage_exists 1 "$file" || continue

    if git_stage_exists 2 "$file" && ! git_stage_exists 3 "$file"; then
      log_info "Modify/delete conflict in $file: deleted by the incoming side, removing it"
      git rm -q -- "$file"
    elif git_stage_exists 3 "$file" && ! git_stage_exists 2 "$file"; then
      log_info "Modify/delete conflict in $file: deleted here, keeping the incoming version"
      checkout_stage theirs "$file"
      stage_file "$file"
    fi
  done <<< "$(get_conflicted_files)"

  [[ -z "$(get_conflicted_files)" ]]
}
