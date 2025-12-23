#!/usr/bin/env bash
# =============================================================================
# strategies/conflict/union.sh - Union merge conflict resolution strategy
# =============================================================================
# Automatically resolves conflicts by concatenating BOTH sides.
#
# WARNING: This is EXPERIMENTAL and may produce broken code!
#   - No semantic understanding of code structure
#   - Creates duplicates (methods, variables, imports)
#   - Works well for: CHANGELOG, independent config additions
#   - Breaks for: code conflicts, configuration values
# =============================================================================

# shellcheck source=.github/scripts/lib/core.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
# shellcheck source=.github/scripts/lib/git-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/git-helpers.sh"


# Attempt a narrow, low-risk Ruby repair for common union-merge breakage:
# duplicate standalone terminators like ")", "},", etc. This does NOT attempt
# semantic merges; it only removes consecutive duplicate terminator-only lines.
# Args: $1 = file path
# Returns: 0 if repair produced valid Ruby, 1 otherwise
attempt_ruby_union_repair() {
  local file="$1"

  # Only run for Ruby-ish files
  [[ "$file" =~ \.rb(w)?$ ]] || return 1

  ruby -e '
    path = ARGV[0]
    lines = File.read(path, mode: "r:BOM|UTF-8").lines

    out = []
    prev_term = nil

    lines.each do |ln|
      raw = ln
      s = ln.strip

      # "terminator-only" lines we are willing to de-dupe if repeated back-to-back
      term = case s
             when ")", "),"
               s
             when "}", "},"
               s
             else
               nil
             end

      if term && prev_term == term
        # drop consecutive duplicate terminator line
        next
      end

      out << raw
      prev_term = term
    end

    File.write(path, out.join)
  ' "$file" > /dev/null 2>&1

  # Validate Ruby syntax after the narrow repair
  if ruby -c "$file" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}


# Parse and intelligently resolve conflict markers with union strategy
# Args: $1 = file path
# Returns: 0 on success
parse_and_resolve_conflicts() {
  local file="$1"
  local temp_resolved temp_audit
  temp_resolved="$(mktemp)"
  temp_audit="$(mktemp)"

  # Read the file with git's conflict markers and parse it
  local in_conflict=false
  local conflict_num=0
  local ours_lines=()
  local theirs_lines=()
  local reading_theirs=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\<\<\<\<\<\<\<\  ]]; then
      # Start of conflict
      in_conflict=true
      ((conflict_num++))
      ours_lines=()
      theirs_lines=()
      reading_theirs=false
      echo "$line" >> "$temp_audit"
    elif [[ "$line" =~ ^\=\=\=\=\=\=\=$ ]] && [[ "$in_conflict" == "true" ]]; then
      # Separator between ours and theirs
      echo "$line" >> "$temp_audit"
      reading_theirs=true
    elif [[ "$line" =~ ^\>\>\>\>\>\>\>\  ]] && [[ "$in_conflict" == "true" ]]; then
      # End of conflict - apply union merge
      echo "$line" >> "$temp_audit"

      # Union merge: output ours, then theirs (removing duplicates)
      # Associative array fails on GH runner, so moving to membership check
      for ours_line in "${ours_lines[@]}"; do
        echo "$ours_line" >> "$temp_resolved"
      done
      
      # Add theirs lines (skip if duplicate of any ours line)
      for theirs_line in "${theirs_lines[@]}"; do
        local dup=false
        for ours_line in "${ours_lines[@]}"; do
          if [[ "$theirs_line" == "$ours_line" ]]; then
            dup=true
            break
          fi
        done
        [[ "$dup" == "true" ]] || echo "$theirs_line" >> "$temp_resolved"
      done

      # Reset state
      in_conflict=false
      reading_theirs=false
      ours_lines=()
      theirs_lines=()
    elif [[ "$in_conflict" == "true" ]]; then
      # Inside conflict region
      echo "$line" >> "$temp_audit"

      if [[ "$reading_theirs" == "true" ]]; then
        theirs_lines+=("$line")
      else
        ours_lines+=("$line")
      fi
    else
      # Normal line (not in conflict)
      echo "$line" >> "$temp_resolved"
    fi
  done < "$file"

  # Validate that all conflicts were properly closed
  if [[ "$in_conflict" == "true" ]]; then
    log_warn "Malformed conflict markers in $file (unclosed conflict region)"
    rm -f "$temp_resolved" "$temp_audit"
    return 1
  fi

  # Replace original file with resolved version
  # Use cat instead of mv to preserve file tracking
  cat "$temp_resolved" > "$file"
  rm -f "$temp_resolved"

  # Save audit trail
  cat "$temp_audit" > "${file}.union-merge"
  rm -f "$temp_audit"

  return 0
}

# Resolve conflicts using union merge strategy
# Args: $1 = context (e.g., "PR #42" or "base sync")
# Sets: HAD_CONFLICTS=true in env if conflicts found
# Returns: 0 (always succeeds, caller validates result)
resolve_conflicts_union() {
  local context="${1:-unknown}"
  local conflicts

  conflicts="$(get_conflicted_files)"

  if [[ -z "$conflicts" ]]; then
    log_debug "No conflicts detected for $context"
    return 0
  fi

  log_warn "Resolving conflicts for $context using union merge"
  export_env "HAD_CONFLICTS" "true"

  # Log conflict header
  require_env CONFLICT_LOG_FILE
  {
    echo ""
    echo "## 🔀 Union Merge: $context"
    echo ""
    echo "### Files resolved:"
  } >> "$CONFLICT_LOG_FILE"

  # Process each conflicted file
  local file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    log_debug "Union merging: $file"
    echo "- \`$file\`" >> "$CONFLICT_LOG_FILE"

    # Annotate file in GitHub UI
    log_warn "file=$file::Conflict auto-resolved via union merge"

    # Lossless evidence capture (when stages exist): dump BOTH sides verbatim.
    # These are critical for reconstructing "what got clipped out" when we later
    # fall back to theirs due to ruby -c failures.
    if git_stage_exists 1 "$file"; then
      {
        git_show_stage 2 "$file" || true
      } > "${file}.union-merge.stage2-ours"
      {
        git_show_stage 3 "$file" || true
      } > "${file}.union-merge.stage3-theirs"
    fi

    # Git already created the file with conflict markers
    # We parse those markers to find minimal conflict regions
    if git_stage_exists 1 "$file"; then
      # Three-way merge: parse conflict markers intelligently
      if ! parse_and_resolve_conflicts "$file"; then
        log_warn "Failed to parse conflicts in $file, falling back to theirs"
        checkout_stage theirs "$file"

        # Create audit trail showing fallback
        {
          echo "<<<<<<< OURS"
          echo "(parse failed - used theirs)"
          echo "======="
          git_show_stage 3 "$file"
          echo ">>>>>>> THEIRS"
        } > "${file}.union-merge"
      fi
    else
      # No merge base: fallback to theirs
      log_debug "No merge base for $file, using theirs"
      checkout_stage theirs "$file"

      # Create audit trail showing we used theirs
      {
        echo "<<<<<<< OURS"
        echo "(no merge base)"
        echo "======="
        git_show_stage 3 "$file"
        echo ">>>>>>> THEIRS"
      } > "${file}.union-merge"
    fi

    # Snapshot the union result (or the immediate post-parse state) before any
    # Ruby repair/fallback logic mutates the file again.
    cp "$file" "${file}.union-merge.union-result" 2>/dev/null || true

    # If union produced Ruby, ensure it's syntactically valid. Union can easily create
    # invalid Ruby (e.g., duplicated terminators in hashes/arrays/Regexp.union blocks).
    # If syntax is invalid, fall back to 'theirs' for this file as a deterministic escape hatch.
    if [[ "$file" =~ \.rb(w)?$ ]]; then
      if ! ruby -c "$file" >/dev/null 2>&1; then
        # Try a narrow, low-risk repair first (keeps both sides, just de-dupes
        # consecutive terminator-only lines). If it works, keep the repaired file.
        if attempt_ruby_union_repair "$file"; then
          log_warn "Union merge produced invalid Ruby in $file; repaired common terminators and kept union result"
          log_warn "file=$file::Union merge invalid Ruby; repaired terminators; kept union result"
          {
            echo ""
            echo "# NOTE: union output failed ruby -c; applied terminator de-dupe repair; kept union result"
          } >> "${file}.union-merge"
        else
          log_warn "Union merge produced invalid Ruby in $file; falling back to theirs"
          log_warn "file=$file::Union merge invalid Ruby; fell back to theirs"
          checkout_stage theirs "$file"
  
          # Annotate audit trail with fallback reason (keep existing conflict context)
          {
            echo ""
            echo "# NOTE: union output failed ruby -c; used theirs for this file"
          } >> "${file}.union-merge"
  
          # If theirs is also invalid, stop early with a clear error.
          if ! ruby -c "$file" >/dev/null 2>&1; then
            log_warn "Fallback to theirs still invalid Ruby for $file"
            return 1
          fi
        fi
      fi
    fi

    # Snapshot the final file we actually chose (union, repaired-union, or theirs).
    cp "$file" "${file}.union-merge.final" 2>/dev/null || true

    # Stage the resolved file
    git add "$file"

    # Analyze and log conflict details
    log_conflict_summary "$file"

  done <<< "$conflicts"

  local count
  count="$(echo "$conflicts" | wc -l)"
  log_info "Union merged $count file(s) for $context"
  return 0
}

# Generate concise, human-readable conflict summary
# Args: $1 = file path
log_conflict_summary() {
  local file="$1"
  local audit_file="${file}.union-merge"

  if [[ ! -f "$audit_file" ]]; then
    return 0
  fi

  # Count conflicts and analyze changes
  local num_conflicts
  num_conflicts=$(grep -c "^<<<<<<< " "$audit_file" || echo "0")

  local total_lines
  total_lines=$(wc -l < "$audit_file")

  {
    echo ""
    echo "<details><summary>📋 Conflict summary: $num_conflicts region(s)</summary>"
    echo ""

    if [[ $total_lines -le 50 ]]; then
      # Small conflict - show everything
      echo '```diff'
      cat "$audit_file"
      echo '```'
    else
      # Large conflict - show summary and key parts
      echo '```diff'
      echo "# Conflict regions found: $num_conflicts"
      echo "# Total conflicted lines: ~$total_lines"
      echo ""

      # Show first conflict in detail
      echo "## First conflict region:"
      sed -n '1,/^>>>>>>>/p' "$audit_file" | head -30

      if [[ $num_conflicts -gt 1 ]]; then
        echo ""
        echo "... $((num_conflicts - 1)) more conflict region(s) omitted"
        echo ""
        echo "## Last conflict region:"
        # Show last conflict
        local last_conflict_start
        last_conflict_start=$(grep -n "^<<<<<<< " "$audit_file" | tail -1 | cut -d: -f1)
        tail -n +$last_conflict_start "$audit_file" | head -30
      fi

      echo '```'
      echo ""
      echo "**💡 Tip:** Review the full diff with:"
      echo "\`\`\`bash"
      echo "git show HEAD:$file > before.tmp && diff -u before.tmp $file"
      echo "\`\`\`"
    fi

    echo ""
    echo "</details>"
    echo ""
  } >> "$CONFLICT_LOG_FILE"
}
