#!/usr/bin/env bash
# Basic smoke tests for modular architecture

set -euo pipefail

echo "Testing modular architecture..."

# Test 1: All lib files are valid bash
echo "✓ Testing lib files syntax..."
for file in .github/scripts/lib/*.sh; do
  bash -n "$file" || { echo "✗ Syntax error in $file"; exit 1; }
done

# Test 2: All strategies are valid bash  
echo "✓ Testing strategy files syntax..."
for file in .github/scripts/strategies/*/*.sh; do
  bash -n "$file" || { echo "✗ Syntax error in $file"; exit 1; }
done

# Test 3: Main script is valid bash
echo "✓ Testing main script syntax..."
bash -n .github/scripts/curate-pre-branch.sh

# Test 4: Can source lib files without errors
echo "✓ Testing lib files can be sourced..."
bash -c "source .github/scripts/lib/core.sh && echo 'core.sh OK'" >/dev/null
bash -c "source .github/scripts/lib/git-helpers.sh && echo 'git-helpers.sh OK'" >/dev/null

echo ""
echo "=========================================="
echo "All basic tests passed!"
echo "=========================================="
