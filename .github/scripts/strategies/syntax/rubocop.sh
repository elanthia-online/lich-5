#!/usr/bin/env bash
# =============================================================================
# strategies/syntax/rubocop.sh - Rubocop linter for union-merged files
# =============================================================================
# Runs Rubocop style checks on Ruby files changed by union merge.
# Returns 0 (warning only) to avoid blocking workflow on style issues.
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"

validate_rubocop() {
  # Check if Rubocop is available
  if ! bundle exec rubocop --version >/dev/null 2>&1; then
    log_warn "Rubocop not available via bundler, skipping linter check"
    return 0
  fi

  log_info "Running Rubocop on changed Ruby files..."

  # Get Ruby files that were modified in HEAD commit
  local files
  files="$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep '\.rb$' || true)"

  if [[ -z "$files" ]]; then
    log_info "No Ruby files changed"
    return 0
  fi

  log_debug "Checking files: $files"

  # Run Rubocop (respects .rubocop.yml)
  # Output goes to logs, warnings shown in GitHub UI
  if ! bundle exec rubocop $files 2>&1; then
    log_warn "Rubocop found style issues in union-merged files - review recommended"
  else
    log_info "Rubocop validation passed"
  fi

  # Always return 0 (warning only, don't fail workflow)
  # Rationale: union merge is experimental, style issues are advisory
  return 0
}
