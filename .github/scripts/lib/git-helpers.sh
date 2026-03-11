#!/usr/bin/env bash
# =============================================================================
# git-helpers.sh - Git operations and utilities
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Normalize branch name (remove refs/heads/, whitespace, trailing slashes)
normalize_branch() {
  local branch="$1"
  branch="${branch#refs/heads/}"
  branch="$(echo "$branch" | tr -d '[:space:]')"
  branch="${branch%/}"
  echo "$branch"
}

# Configure git bot identity
configure_git_bot() {
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Fetch branch from remote
fetch_branch() {
  local branch="$1"
  log_debug "Fetching branch: $branch"
  git fetch origin "$branch"
}

# Fetch all tags
fetch_tags() {
  log_debug "Fetching tags"
  git fetch --tags origin
}

# Check if branch exists on remote
remote_branch_exists() {
  local branch="$1"
  git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1
}

# Create or reset branch to commit
create_or_reset_branch() {
  local branch="$1" commit="$2"
  log_info "Creating/resetting branch $branch to $commit"
  git checkout -B "$branch" "$commit"
}

# Checkout existing branch
checkout_branch() {
  local branch="$1"
  log_debug "Checking out branch: $branch"
  git checkout "$branch"
}

# Get conflicted files
get_conflicted_files() {
  git diff --name-only --diff-filter=U 2>/dev/null || true
}

# Stage file
stage_file() {
  local file="$1"
  git add "$file"
}

# Resolve commit SHA from ref
resolve_sha() {
  local ref="$1"
  git rev-parse "$ref"
}

# Create annotated tag
create_tag() {
  local tag="$1" commit="$2"
  git tag -f "$tag" "$commit"
}

# Push tag with force
push_tag_force() {
  local tag="$1"
  git push -f origin "refs/tags/$tag"
}

# Push branch
push_branch() {
  local branch="$1"
  git push origin "$branch"
}

# Push branch with force-with-lease
push_branch_force_lease() {
  local branch="$1"
  git push --force-with-lease origin "$branch"
}

# Cherry-pick commit
cherry_pick() {
  local commit="$1"
  shift
  git cherry-pick -x "$@" "$commit"
}

# Continue cherry-pick after conflict resolution
cherry_pick_continue() {
  git cherry-pick --continue
}

# Abort cherry-pick
cherry_pick_abort() {
  git cherry-pick --abort 2>/dev/null || true
}

# Merge with strategy
merge_with_strategy() {
  local branch="$1"
  shift
  git merge --no-ff --no-edit "$@" "$branch"
}

# Squash merge
squash_merge() {
  local branch="$1"
  shift
  git merge --squash "$@" "$branch"
}

# Abort merge
merge_abort() {
  git merge --abort 2>/dev/null || true
}

# Amend commit message
amend_commit_message() {
  local subject="$1" body="${2:-}"
  if [[ -n "$body" ]]; then
    git commit --amend -m "$subject" -m "$body"
  else
    git commit --amend -m "$subject"
  fi
}

# Get commit body
get_commit_body() {
  git log -1 --pretty=%b HEAD 2>/dev/null || true
}

# Create commit
create_commit() {
  local message="$1"
  git commit -m "$message"
}

# List commits in range
list_commits() {
  local range="$1"
  # Don't quote $range to allow multiple arguments (e.g., "^HEAD branch")
  # shellcheck disable=SC2086
  git rev-list --reverse --no-merges $range
}

# Show git object at stage
git_show_stage() {
  local stage="$1" file="$2"
  git show ":${stage}:${file}" 2>/dev/null || true
}

# Check if stage exists for file
git_stage_exists() {
  local stage="$1" file="$2"
  git show ":${stage}:${file}" >/dev/null 2>&1
}

# Checkout file from stage
checkout_stage() {
  local stage="$1" file="$2"
  case "$stage" in
    ours)   git checkout --ours "$file" 2>/dev/null || true ;;
    theirs) git checkout --theirs "$file" 2>/dev/null || true ;;
    *) die "Invalid stage: $stage" ;;
  esac
}
