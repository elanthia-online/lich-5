#!/usr/bin/env bash
# =============================================================================
# strategies/conflict/ours.sh - Ours conflict resolution strategy
# =============================================================================
# Returns git flag for using "ours" strategy (prefer current branch)
# =============================================================================

get_strategy_flag_ours() {
  echo "-X ours"
}
