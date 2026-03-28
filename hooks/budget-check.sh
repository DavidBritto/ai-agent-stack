#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Budget Guard Hook — PreToolUse
# Warns at 80% of session budget, hard-stops at 100%
# ─────────────────────────────────────────────────────────────

set -euo pipefail

BUDGET_CONFIG="$HOME/.claude/config/budget.json"
COSTS_FILE="$HOME/.claude/session-costs.json"

# If no budget config exists, allow all tool calls
[ -f "$BUDGET_CONFIG" ] || exit 0

# Read budget limits
DEFAULT_LIMIT=$(jq -r '.default_session_usd // 5.00' "$BUDGET_CONFIG" 2>/dev/null || echo "5.00")
WARN_PCT=$(jq -r '.alerts.warn_pct // 80' "$BUDGET_CONFIG" 2>/dev/null || echo "80")
HARD_STOP_PCT=$(jq -r '.alerts.hard_stop_pct // 100' "$BUDGET_CONFIG" 2>/dev/null || echo "100")

# Read current session cost from costs file
CURRENT_COST="0"
if [ -f "$COSTS_FILE" ]; then
  CURRENT_COST=$(jq -r '.session_cost_usd // 0' "$COSTS_FILE" 2>/dev/null || echo "0")
fi

# Skip if cost is 0 (nothing spent yet)
[ "$CURRENT_COST" = "0" ] && exit 0

# Calculate percentage (requires bc)
if command -v bc > /dev/null 2>&1; then
  PCT=$(echo "scale=1; ($CURRENT_COST / $DEFAULT_LIMIT) * 100" | bc 2>/dev/null || echo "0")
else
  # Fallback: integer math only
  PCT=$(awk "BEGIN {printf \"%.1f\", ($CURRENT_COST / $DEFAULT_LIMIT) * 100}" 2>/dev/null || echo "0")
fi

# Hard stop check (>= hard_stop_pct)
IS_OVER=$(awk "BEGIN {print ($PCT >= $HARD_STOP_PCT) ? 1 : 0}" 2>/dev/null || echo "0")
if [ "$IS_OVER" = "1" ]; then
  echo "BUDGET EXCEEDED: \$$CURRENT_COST / \$$DEFAULT_LIMIT (${PCT}%). Run /budget-guard reset to continue or increase limit in ~/.claude/config/budget.json" >&2
  exit 1
fi

# Warning check (>= warn_pct)
IS_WARN=$(awk "BEGIN {print ($PCT >= $WARN_PCT) ? 1 : 0}" 2>/dev/null || echo "0")
if [ "$IS_WARN" = "1" ]; then
  echo "Budget warning: \$$CURRENT_COST / \$$DEFAULT_LIMIT (${PCT}%)" >&2
fi

exit 0
