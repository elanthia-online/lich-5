#!/usr/bin/env bash
# =============================================================================
# core.sh - Core utilities for GitHub Actions workflows
# =============================================================================

set -euo pipefail

# Logging level default. Keep this compatible with macOS Bash 3.2 and GitHub runners.
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Die with error message and GitHub annotation
die() {
  echo "::error::$*" >&2
  exit 1
}

# Log informational message
log_info() {
  echo "::notice::$*" >&2
}

# Log debug message (only if DEBUG enabled)
log_debug() {
  [[ "${LOG_LEVEL}" == "DEBUG" ]] && echo "::debug::$*" >&2 || true
}

# Log warning with GitHub annotation
log_warn() {
  echo "::warning::$*" >&2
}

# Create collapsible group in GitHub Actions logs
log_group() {
  echo "::group::$1" >&2
}

# End collapsible group
log_endgroup() {
  echo "::endgroup::" >&2
}

# Export value to GitHub environment
export_env() {
  local name="$1" value="$2"
  printf '%s=%s\n' "$name" "$value" >> "${GITHUB_ENV:-/dev/null}"
}

# Export value to step output
export_output() {
  local name="$1" value="$2"
  printf '%s=%s\n' "$name" "$value" >> "${GITHUB_OUTPUT:-/dev/null}"
}

# Append to GitHub step summary
append_summary() {
  cat >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Check if running in GitHub Actions
is_github_actions() {
  [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Require environment variable or die
require_env() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    die "Required environment variable not set: $var"
  fi
}

# Create temporary file and export path to env var
make_temp_file() {
  local var_name="$1"
  local temp_file
  temp_file="$(mktemp)"
  export_env "$var_name" "$temp_file"
  echo "$temp_file"
}
