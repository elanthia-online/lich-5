#!/usr/bin/env bash
# =============================================================================
# strategies/syntax/ruby.sh - Ruby syntax validator
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"

validate_ruby_syntax() {
  local errors=0

  log_info "Validating Ruby syntax..."

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if ! ruby -c "$file" >/dev/null 2>&1; then
      echo "::error file=$file::Ruby syntax error in $file"
      ruby -c "$file" || true
      ((errors++))
    fi
  done < <(find . -name "*.rb" -not -path "./.git/*" -type f)

  if [[ $errors -gt 0 ]]; then
    log_warn "Found $errors Ruby syntax error(s)"
    return 1
  fi

  log_info "Ruby syntax validation passed"
  return 0
}
