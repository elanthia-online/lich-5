#!/usr/bin/env bash
# =============================================================================
# curate-pre-branch.sh - Curate prerelease branch with PR cherry-picks
# =============================================================================
# Orchestrates the curation of a prerelease branch by cherry-picking selected
# PRs with configurable conflict resolution strategies.
#
# Environment variables required:
#   DESTINATION, BASE, PRS, MODE, SQUASH, CONFLICT_STRATEGY,
#   RESET_DESTINATION, DRY_RUN, GITHUB_TOKEN, GITHUB_REPOSITORY
# =============================================================================

set -euo pipefail

# ===========================================================================
# SETUP
# ===========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=.github/scripts/lib/core.sh
source "${SCRIPT_DIR}/lib/core.sh"
# shellcheck source=.github/scripts/lib/git-helpers.sh
source "${SCRIPT_DIR}/lib/git-helpers.sh"
# shellcheck source=.github/scripts/lib/github-api.sh
source "${SCRIPT_DIR}/lib/github-api.sh"
# shellcheck source=.github/scripts/lib/validation.sh
source "${SCRIPT_DIR}/lib/validation.sh"

# ===========================================================================
# VALIDATION
# ===========================================================================

validate_inputs() {
  log_group "Validating inputs"

  require_env DESTINATION
  require_env BASE
  require_env PRS
  require_env MODE
  require_env SQUASH
  require_env CONFLICT_STRATEGY
  require_env RESET_DESTINATION
  require_env DRY_RUN
  require_env GITHUB_TOKEN
  require_env GITHUB_REPOSITORY

  # Validate and normalize each input
  DEST_SAFE="$(validate_destination "$DESTINATION")"
  BASE_SAFE="$(validate_base "$BASE")"
  PRS_SAFE="$(validate_pr_list "$PRS")"
  MODE_SAFE="$(validate_mode "$MODE")"
  SQUASH_SAFE="$(validate_bool "$SQUASH" "squash")"
  STRAT_SAFE="$(validate_conflict_strategy "$CONFLICT_STRATEGY")"
  RESET_SAFE="$(validate_bool "$RESET_DESTINATION" "reset_destination")"
  DRY_RUN_SAFE="$(validate_bool "$DRY_RUN" "dry_run")"

  # Export sanitized values
  export_env "DEST_SAFE" "$DEST_SAFE"
  export_env "BASE_SAFE" "$BASE_SAFE"
  export_env "PRS_SAFE" "$PRS_SAFE"
  export_env "MODE_SAFE" "$MODE_SAFE"
  export_env "SQUASH_SAFE" "$SQUASH_SAFE"
  export_env "STRAT_SAFE" "$STRAT_SAFE"
  export_env "RESET_SAFE" "$RESET_SAFE"
  export_env "DRY_RUN_SAFE" "$DRY_RUN_SAFE"

  export_output "dest_safe" "$DEST_SAFE"
  export_output "base_safe" "$BASE_SAFE"

  log_info "Destination: $DEST_SAFE"
  log_info "Base: $BASE_SAFE"
  log_info "PRs: $PRS_SAFE"
  log_info "Conflict strategy: $STRAT_SAFE"

  log_endgroup
}

# ===========================================================================
# CONFLICT STRATEGY SETUP
# ===========================================================================

setup_conflict_strategy() {
  log_group "Loading conflict strategy: $STRAT_SAFE"

  case "$STRAT_SAFE" in
    ours)
      # shellcheck source=.github/scripts/strategies/conflict/ours.sh
      source "${SCRIPT_DIR}/strategies/conflict/ours.sh"
      GIT_STRATEGY_FLAG="$(get_strategy_flag_ours)"
      USE_UNION=false
      ;;
    theirs)
      # shellcheck source=.github/scripts/strategies/conflict/theirs.sh
      source "${SCRIPT_DIR}/strategies/conflict/theirs.sh"
      GIT_STRATEGY_FLAG="$(get_strategy_flag_theirs)"
      USE_UNION=false
      ;;
    union)
      # shellcheck source=.github/scripts/strategies/conflict/union.sh
      source "${SCRIPT_DIR}/strategies/conflict/union.sh"
      GIT_STRATEGY_FLAG=""
      USE_UNION=true
      ;;
    abort)
      # shellcheck source=.github/scripts/strategies/conflict/abort.sh
      source "${SCRIPT_DIR}/strategies/conflict/abort.sh"
      GIT_STRATEGY_FLAG="$(get_strategy_flag_abort)"
      USE_UNION=false
      ;;
  esac

  export GIT_STRATEGY_FLAG USE_UNION

  # Initialize conflict tracking
  CONFLICT_LOG_FILE="$(make_temp_file CONFLICT_LOG_FILE)"
  export_env "HAD_CONFLICTS" "false"

  log_endgroup
}

# ===========================================================================
# BRANCH PREPARATION
# ===========================================================================

prepare_branch() {
  log_group "Preparing destination branch: $DEST_SAFE"

  configure_git_bot
  fetch_branch "$BASE_SAFE"

  if [[ "$RESET_SAFE" == "true" ]]; then
    # Force-create branch from base
    create_or_reset_branch "$DEST_SAFE" "origin/$BASE_SAFE"
  else
    # Incremental: preserve or create
    if remote_branch_exists "$DEST_SAFE"; then
      fetch_branch "$DEST_SAFE"
      checkout_branch "$DEST_SAFE"

      # Sync with base
      if ! merge_with_strategy "origin/$BASE_SAFE" $GIT_STRATEGY_FLAG; then
        handle_base_sync_conflicts
      fi
    else
      create_or_reset_branch "$DEST_SAFE" "origin/$BASE_SAFE"
    fi
  fi

  log_endgroup
}

handle_base_sync_conflicts() {
  local conflicts
  conflicts="$(get_conflicted_files)"

  if [[ -n "$conflicts" ]]; then
    log_warn "Conflicts during base sync"

    if [[ "$USE_UNION" == "true" ]]; then
      resolve_conflicts_union "base sync"
      create_commit "chore: sync base (union merge)"
    else
      merge_abort
      die "Merge conflicts with base. Use conflict_strategy=union or fix manually."
    fi
  else
    merge_abort
    die "Merge failed without conflicts (possible git issue)"
  fi
}

# ===========================================================================
# PRERELEASE TAGGING
# ===========================================================================

create_prerelease_tag() {
  log_group "Creating prerelease base tag"

  fetch_tags
  local base_sha
  base_sha="$(resolve_sha "origin/${BASE_SAFE}")"
  local tag="prebeta-base/${DEST_SAFE}"

  log_info "Tagging $tag at $base_sha"
  create_tag "$tag" "$base_sha"

  if [[ "$DRY_RUN_SAFE" == "false" ]]; then
    push_tag_force "$tag"
  else
    log_info "[DRY-RUN] Would push tag: $tag"
  fi

  log_endgroup
}

# ===========================================================================
# PR PROCESSING
# ===========================================================================

process_prs() {
  log_group "Cherry-picking PRs"

  IFS=',' read -ra PR_ARRAY <<< "$PRS_SAFE"

  for pr_num in "${PR_ARRAY[@]}"; do
    pr_num="$(echo "$pr_num" | xargs)"
    process_single_pr "$pr_num"
  done

  log_endgroup
}

process_single_pr() {
  local pr_num="$1"
  log_group "PR #${pr_num}"

  # Instrumenting to see where failures might occur
  log_info "DEBUG: HEAD ref = $(git rev-parse --abbrev-ref HEAD)"
  log_info "DEBUG: Last 10 commits on HEAD:"
  git log --format='%h %s' -10 HEAD | sed 's/^/DEBUG:   /'

  # Detect whether this PR has already been curated into DEST_SAFE
  local pr_already_curated=false
  # Proper behavior through process would be to provide fixes in new PRs
  # to any feature PRs that are being beta tested.  For now, we will make
  # the call that if a PR is added to beta, at any point in the beta train,
  # any changes brought back through the curate process need to be 'update'
  # type changes, and the merge strategy must be '-X theirs' to avoid
  # duplicating code into syntax errors from the Hinterlands. So always check
  # against the 'origin/${DEST_SAFE}' to avoid branch merge shinanigans.
  # Also taking out the color / formatting commands.
  if git log --no-color --format=%s "origin/${DEST_SAFE}" \
     | grep -qE "\(#${pr_num}\)[[:space:]]*$"; then
    pr_already_curated=true
    log_info "PR #${pr_num} already present in origin/${DEST_SAFE}; treating as update."
  else
    log_info "DEBUG: did NOT detect prior curated commit for #${pr_num} in origin/${DEST_SAFE}"
  fi

  local pr_json
  pr_json="$(fetch_pr "$GITHUB_REPOSITORY" "$pr_num")"

  local title merge_sha
  title="$(pr_title "$pr_json")"
  merge_sha="$(pr_merge_sha "$pr_json")"

  # Add PR trailer if missing
  if ! echo "$title" | grep -Eq '\(#?[0-9]+\)$'; then
    title="${title} (#${pr_num})"
  fi
  # Save current conflict strategy
  local prev_git_strategy_flag="$GIT_STRATEGY_FLAG"
  local prev_use_union="$USE_UNION"

  if [[ "$pr_already_curated" == "true" && "$STRAT_SAFE" == "union" ]]; then
    # For already-in-train PRs, prefer incoming changes (-X theirs)
    # shellcheck source=.github/scripts/strategies/conflict/theirs.sh
    source "${SCRIPT_DIR}/strategies/conflict/theirs.sh"
    GIT_STRATEGY_FLAG="$(get_strategy_flag_theirs)"
    USE_UNION=false
    log_info "Using -X theirs strategy for updated PR #${pr_num}"
  fi

  # and more logging
  log_info "DEBUG: strategy for PR #${pr_num}: STRAT_SAFE=$STRAT_SAFE GIT_STRATEGY_FLAG='${GIT_STRATEGY_FLAG:-<none>}' USE_UNION=${USE_UNION}"

  # Determine cherry-pick mode
  if [[ "$MODE_SAFE" == "merged" ]] || { [[ "$MODE_SAFE" == "auto" ]] && pr_is_merged "$pr_json" && [[ "$merge_sha" != "null" ]]; }; then
    cherry_pick_merged_pr "$pr_num" "$merge_sha" "$title"
  else
    cherry_pick_open_pr "$pr_num" "$title"
  fi

  # Restore previous conflict strategy for the next PR
  GIT_STRATEGY_FLAG="$prev_git_strategy_flag"
  USE_UNION="$prev_use_union"

  log_endgroup
}

cherry_pick_merged_pr() {
  local pr_num="$1" merge_sha="$2" title="$3"
  log_info "Cherry-picking merged PR #${pr_num}: $merge_sha"

  if ! cherry_pick "$merge_sha" $GIT_STRATEGY_FLAG; then
    handle_cherry_pick_conflict "PR #${pr_num}"
    cherry_pick_continue
  fi

  # Amend commit message
  local body
  body="$(get_commit_body)"
  amend_commit_message "$title" "$body"
}

cherry_pick_open_pr() {
  local pr_num="$1" title="$2"
  log_info "Cherry-picking open PR #${pr_num}"

  local pr_branch="pr-${pr_num}"
  fetch_pr_head "$pr_num" "$pr_branch"

  if [[ "$SQUASH_SAFE" == "true" ]]; then
    # Squash merge
    if ! squash_merge "$pr_branch" $GIT_STRATEGY_FLAG; then
      if ! handle_merge_conflict "PR #${pr_num}"; then
        log_warn "Skipping empty squash merge for PR #${pr_num}"
        return 0
      fi
    fi
    create_commit "$title"
  else
    # Preserve history: cherry-pick each commit
    local commits
    commits="$(list_commits "^HEAD ${pr_branch}")"

    while IFS= read -r commit_sha; do
      [[ -z "$commit_sha" ]] && continue

      if ! cherry_pick "$commit_sha" $GIT_STRATEGY_FLAG; then
        if handle_cherry_pick_conflict "PR #${pr_num}"; then
          cherry_pick_continue
        else
          log_warn "Skipping empty cherry-pick for PR #${pr_num}"
        fi
      fi
    done <<< "$commits"
  fi
}

# Check if union merge produced any changes to commit
# Args: $1 = operation type ("cherry-pick" or "merge")
# Returns: 0 if changes exist, 1 if empty (also aborts the operation)
check_union_merge_has_changes() {
  local operation="$1"

  if git diff --cached --quiet; then
    log_warn "No changes after union merge (resolved files identical to HEAD)"

    if [[ "$operation" == "cherry-pick" ]]; then
      cherry_pick_abort
    else
      merge_abort
    fi

    return 1
  fi

  return 0
}

handle_cherry_pick_conflict() {
  local context="$1"

  if [[ "$USE_UNION" == "true" ]]; then
    log_warn "Resolving conflicts for $context"
    resolve_conflicts_union "$context"
    check_union_merge_has_changes "cherry-pick"
  else
    cherry_pick_abort
    die "Cherry-pick conflicts for $context. Use conflict_strategy=union or fix manually."
  fi
}

handle_merge_conflict() {
  local context="$1"

  if [[ "$USE_UNION" == "true" ]]; then
    log_warn "Resolving merge conflicts for $context"
    resolve_conflicts_union "$context"

    # After resolving conflicts in a squash merge, stage ALL modified files
    # git merge --squash doesn't stage anything when it fails with conflicts
    git add -u

    check_union_merge_has_changes "merge"
  else
    merge_abort
    die "Merge conflicts for $context. Use conflict_strategy=union or fix manually."
  fi
}

# ===========================================================================
# SYNTAX VALIDATION
# ===========================================================================

validate_syntax() {
  if [[ "$(cat "${GITHUB_ENV}" | grep -c 'HAD_CONFLICTS=true')" -eq 0 ]]; then
    log_info "No conflicts resolved, skipping syntax validation"
    return 0
  fi

  log_group "Validating syntax after conflict resolution"

  local exit_code=0

  # Load and run validators
  # shellcheck source=.github/scripts/strategies/syntax/ruby.sh
  source "${SCRIPT_DIR}/strategies/syntax/ruby.sh"
  validate_ruby_syntax || exit_code=$?

  # shellcheck source=.github/scripts/strategies/syntax/yaml.sh
  source "${SCRIPT_DIR}/strategies/syntax/yaml.sh"
  validate_yaml_syntax || exit_code=$?

  # shellcheck source=.github/scripts/strategies/syntax/json.sh
  source "${SCRIPT_DIR}/strategies/syntax/json.sh"
  validate_json_syntax || exit_code=$?

  # Run Rubocop only when union merge was used
  if [[ "$USE_UNION" == "true" ]]; then
    # shellcheck source=.github/scripts/strategies/syntax/rubocop.sh
    source "${SCRIPT_DIR}/strategies/syntax/rubocop.sh"
    validate_rubocop || exit_code=$?
  fi

  log_endgroup

  return $exit_code
}

# ===========================================================================
# PUSH
# ===========================================================================

push_destination_branch() {
  log_group "Pushing branch"

  if [[ "$DRY_RUN_SAFE" == "true" ]]; then
    log_info "[DRY-RUN] Would push to: $DEST_SAFE"
    git log --oneline -10
  else
    if [[ "$RESET_SAFE" == "true" ]]; then
      push_branch_force_lease "$DEST_SAFE"
    else
      # Call git-helpers function (not recursive)
      push_branch "$DEST_SAFE"
    fi
  fi

  log_endgroup
}

# ===========================================================================
# REPORTING
# ===========================================================================

generate_report() {
  if [[ "$(cat "${GITHUB_ENV}" | grep -c 'HAD_CONFLICTS=true')" -gt 0 ]] && [[ "$STRAT_SAFE" == "union" ]]; then
    {
      echo ""
      echo "---"
      echo "# ⚠️ MANUAL REVIEW REQUIRED"
      echo ""
      echo "Union merge was used to auto-resolve conflicts."
      echo "**Review all changes before deploying.**"
      echo ""
      cat "$CONFLICT_LOG_FILE"
    } | append_summary

    log_warn "Union merge used - manual review required!"
  fi

  # Summary
  {
    echo "### ✅ Curation Complete"
    echo ""
    echo "- **Destination:** \`$DEST_SAFE\`"
    echo "- **Base:** \`$BASE_SAFE\`"
    echo "- **PRs:** $PRS_SAFE"
    echo "- **Strategy:** $STRAT_SAFE"
    echo ""
    if [[ "$DRY_RUN_SAFE" == "true" ]]; then
      echo "**Mode:** Dry-run (no changes pushed)"
    else
      echo "**Next:** Run prepare-prerelease workflow targeting \`$DEST_SAFE\`"
    fi
  } | append_summary
}

# ===========================================================================
# MAIN
# ===========================================================================

main() {
  log_info "Starting pre-branch curation"

  validate_inputs
  setup_conflict_strategy
  prepare_branch
  create_prerelease_tag
  process_prs
  validate_syntax
  push_destination_branch
  generate_report

  log_info "Curation complete"
}

main "$@"
