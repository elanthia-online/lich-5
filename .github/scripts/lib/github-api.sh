#!/usr/bin/env bash
# =============================================================================
# github-api.sh - GitHub API client
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Make authenticated API request
api_request() {
  require_env GITHUB_TOKEN
  curl -sS \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

# Fetch PR metadata
fetch_pr() {
  local repo="$1" pr_number="$2"
  api_request "https://api.github.com/repos/${repo}/pulls/${pr_number}"
}

# Extract PR field using jq
pr_field() {
  local pr_json="$1" field="$2"
  echo "$pr_json" | jq -r ".${field}"
}

# Get PR state (open/closed)
pr_state() {
  pr_field "$1" "state"
}

# Check if PR is merged
pr_is_merged() {
  local merged
  merged="$(pr_field "$1" "merged")"
  [[ "$merged" == "true" ]]
}

# Get PR merge commit SHA
pr_merge_sha() {
  pr_field "$1" "merge_commit_sha"
}

# Get PR title
pr_title() {
  pr_field "$1" "title"
}

# Get PR number
pr_number() {
  pr_field "$1" "number"
}

# Get PR head SHA
pr_head_sha() {
  pr_field "$1" "head.sha"
}

# Fetch PR head as local branch
fetch_pr_head() {
  local pr_number="$1" local_branch="$2"
  log_debug "Fetching PR #${pr_number} head to ${local_branch}"
  git fetch origin "pull/${pr_number}/head:${local_branch}"
}
