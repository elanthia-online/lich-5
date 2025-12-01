#!/usr/bin/env bash
# =============================================================================
# validation.sh - Input validation functions
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
# shellcheck source=.github/scripts/lib/git-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/git-helpers.sh"

# Validate base branch (must be 'main')
validate_base() {
  local base="$1"
  base="$(normalize_branch "$base")"

  case "$base" in
    main) echo "$base" ;;
    *) die "Invalid base '$base'. Only 'main' is allowed." ;;
  esac
}

# Validate and normalize destination branch
validate_destination() {
  local dest="$1"
  dest="$(normalize_branch "$dest")"

  # Guard: no path traversal or whitespace
  if [[ "$dest" =~ (\.\.|[[:space:]]) ]]; then
    die "Destination '$dest' contains illegal sequences (.. or whitespace)"
  fi

  # Guard: cannot target main
  if [[ "$dest" == "main" ]]; then
    die "Cannot curate into 'main' branch"
  fi

  # Normalize: auto-prefix with pre/beta/ if needed
  if [[ "$dest" != pre/beta && "$dest" != pre/beta/* ]]; then
    if [[ "$dest" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]]; then
      log_info "Auto-prefixing: '$dest' => 'pre/beta/$dest'"
      dest="pre/beta/$dest"
    else
      die "Destination '$dest' must be 'pre/beta' or 'pre/beta/<slug>'"
    fi
  fi

  echo "$dest"
}

# Validate PR list format and normalize
validate_pr_list() {
  local raw_prs="$1"

  if [[ -z "$raw_prs" ]]; then
    die "PR list is required"
  fi

  # Must be comma-separated digits only
  if ! printf '%s' "$raw_prs" | grep -Eq '^[0-9]+( *[,]+ *[0-9]+)*$'; then
    die "PR list must be comma-separated numbers (e.g., '12,27,43')"
  fi

  # Normalize: remove spaces and deduplicate
  local normalized
  normalized="$(printf '%s' "$raw_prs" | tr -d ' ' | awk -F, '{
    n=split($0,a,","); delete seen; out="";
    for(i=1;i<=n;i++){
      if(!(a[i] in seen)){
        seen[a[i]]=1;
        out=(out?out",":"");
        out=out a[i];
      }
    }
    print out
  }')"

  echo "$normalized"
}

# Validate mode parameter
validate_mode() {
  local mode="$1"
  case "$mode" in
    auto|merged|head) echo "$mode" ;;
    *) die "Invalid mode '$mode'. Must be: auto, merged, or head" ;;
  esac
}

# Validate boolean parameter
validate_bool() {
  local value="$1" name="$2"
  case "$value" in
    true|false) echo "$value" ;;
    *) die "Invalid $name '$value'. Must be: true or false" ;;
  esac
}

# Validate conflict strategy
validate_conflict_strategy() {
  local strategy="$1"
  case "$strategy" in
    abort|ours|theirs|union) echo "$strategy" ;;
    *) die "Invalid conflict_strategy '$strategy'. Must be: abort, ours, theirs, or union" ;;
  esac
}
