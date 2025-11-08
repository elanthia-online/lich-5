#!/usr/bin/env bash
# =============================================================================
# strategies/syntax/json.sh - JSON syntax validator
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"

validate_json_syntax() {
  local errors=0

  log_info "Validating JSON syntax..."

  # Ensure jq is available
  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not found, skipping JSON validation"
    return 0
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if ! jq empty "$file" >/dev/null 2>&1; then
      echo "::error file=$file::JSON syntax error in $file"
      jq empty "$file" || true
      ((errors++))
    fi
  done < <(find . -name "*.json" -not -path "./.git/*" -type f)

  if [[ $errors -gt 0 ]]; then
    log_warn "Found $errors JSON syntax error(s)"
    return 1
  fi

  log_info "JSON syntax validation passed"
  return 0
}
