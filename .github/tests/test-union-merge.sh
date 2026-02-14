#!/usr/bin/env bash
# =============================================================================
# test-union-merge.sh - Tests for union merge conflict resolution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

echo "Testing union merge conflict resolution..."
echo

# Extract parse function for standalone testing
parse_and_resolve_conflicts() {
  local file="$1"
  local temp_resolved temp_audit
  temp_resolved="$(mktemp)"
  temp_audit="$(mktemp)"

  local in_conflict=false
  local ours_lines=()
  local theirs_lines=()
  local reading_theirs=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\<\<\<\<\<\<\<\  ]]; then
      in_conflict=true
      ours_lines=()
      theirs_lines=()
      reading_theirs=false
      echo "$line" >> "$temp_audit"
    elif [[ "$line" =~ ^\=\=\=\=\=\=\=$ ]] && [[ "$in_conflict" == "true" ]]; then
      echo "$line" >> "$temp_audit"
      reading_theirs=true
    elif [[ "$line" =~ ^\>\>\>\>\>\>\>\  ]] && [[ "$in_conflict" == "true" ]]; then
      echo "$line" >> "$temp_audit"

      local seen=""
      for ours_line in "${ours_lines[@]}"; do
        echo "$ours_line" >> "$temp_resolved"
        seen="${seen}${ours_line}
"
      done

      for theirs_line in "${theirs_lines[@]}"; do
        if ! echo "$seen" | grep -Fx "$theirs_line" >/dev/null 2>&1; then
          echo "$theirs_line" >> "$temp_resolved"
        fi
      done

      in_conflict=false
      reading_theirs=false
      ours_lines=()
      theirs_lines=()
    elif [[ "$in_conflict" == "true" ]]; then
      echo "$line" >> "$temp_audit"
      if [[ "$reading_theirs" == "true" ]]; then
        theirs_lines+=("$line")
      else
        ours_lines+=("$line")
      fi
    else
      echo "$line" >> "$temp_resolved"
    fi
  done < "$file"

  if [[ "$in_conflict" == "true" ]]; then
    rm -f "$temp_resolved" "$temp_audit"
    return 1
  fi

  # Use cat instead of mv to match actual implementation
  cat "$temp_resolved" > "$file" || { rm -f "$temp_resolved" "$temp_audit"; return 1; }
  rm -f "$temp_resolved"

  cat "$temp_audit" > "${file}.union-merge" || { rm -f "$temp_audit"; return 1; }
  rm -f "$temp_audit"

  return 0
}

# Test counters
PASSED=0
FAILED=0

# Test 1: Simple conflict
test_file="$(mktemp)"
cp "$FIXTURES_DIR/conflict-simple.txt" "$test_file"
if parse_and_resolve_conflicts "$test_file" &&\
   grep -q "new_feature_from_pr6.rb" "$test_file" &&\
   grep -q "other_feature_from_pr12.rb" "$test_file"; then
  echo "✓ Simple conflict resolution"
  ((PASSED++))
else
  echo "✗ Simple conflict resolution"
  ((FAILED++))
fi
rm -f "$test_file" "${test_file}.union-merge"

# Test 2: Duplicate detection
test_file="$(mktemp)"
cp "$FIXTURES_DIR/conflict-duplicate.txt" "$test_file"
if parse_and_resolve_conflicts "$test_file" &&\
   [[ $(grep -c "same_feature.rb" "$test_file") -eq 1 ]]; then
  echo "✓ Duplicate line detection"
  ((PASSED++))
else
  echo "✗ Duplicate line detection"
  ((FAILED++))
fi
rm -f "$test_file" "${test_file}.union-merge"

# Test 3: Multiple conflicts
test_file="$(mktemp)"
cp "$FIXTURES_DIR/conflict-multiple.txt" "$test_file"
if parse_and_resolve_conflicts "$test_file" &&\
   grep -q "feature_a.rb" "$test_file" &&\
   grep -q "feature_b.rb" "$test_file" &&\
   grep -q "feature_c.rb" "$test_file" &&\
   grep -q "feature_d.rb" "$test_file"; then
  echo "✓ Multiple conflict regions"
  ((PASSED++))
else
  echo "✗ Multiple conflict regions"
  ((FAILED++))
fi
rm -f "$test_file" "${test_file}.union-merge"

# Test 4: Incomplete markers
test_file="$(mktemp)"
cp "$FIXTURES_DIR/conflict-incomplete.txt" "$test_file"
if ! parse_and_resolve_conflicts "$test_file" 2>/dev/null; then
  echo "✓ Incomplete marker detection"
  ((PASSED++))
else
  echo "✗ Incomplete marker detection"
  ((FAILED++))
fi
rm -f "$test_file" "${test_file}.union-merge"

echo
echo "Tests passed: $PASSED/4"
echo "Tests failed: $FAILED/4"

[[ $FAILED -eq 0 ]]
