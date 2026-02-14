#!/usr/bin/env bash
# =============================================================================
# strategies/syntax/yaml.sh - YAML syntax validator
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"

validate_yaml_syntax() {
  local warnings=0

  log_info "Validating YAML syntax..."

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if ! ruby -e "require 'yaml'; YAML.load_file('$file')" >/dev/null 2>&1; then
      log_warn "file=$file::Potential YAML syntax issue in $file"
      ((warnings++))
    fi
  done < <(find . \( -name "*.yml" -o -name "*.yaml" \) -not -path "./.git/*" -type f)

  if [[ $warnings -gt 0 ]]; then
    log_warn "Found $warnings YAML warning(s)"
  else
    log_info "YAML syntax validation passed"
  fi

  return 0  # Warnings don't fail the build
}
