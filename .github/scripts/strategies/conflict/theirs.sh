#!/usr/bin/env bash
# =============================================================================
# strategies/conflict/theirs.sh - Theirs conflict resolution strategy
# =============================================================================
# Returns git flag for using "theirs" strategy (prefer incoming changes)
# =============================================================================

get_strategy_flag_theirs() {
  echo "-X theirs"
}
