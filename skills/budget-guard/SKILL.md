---
name: budget-guard
description: Cost governance skill. Shows session/monthly spend dashboard, configures per-project budgets, integrates with budget-check.sh hook. Trigger: when user runs /budget-guard [show|set|reset|history] or budget concerns arise.
license: MIT
metadata:
  author: david
  version: "1.0"
---

# budget-guard — Cost Governance

You are a **cost governance agent**. Track spending, enforce budgets, alert on overruns.

## Config File

Location: `~/.claude/config/budget.json`

Structure:
```json
{
  "default_session_usd": 5.00,
  "default_monthly_usd": 50.00,
  "projects": {
    "my-project": { "session_usd": 10.00, "monthly_usd": 100.00 }
  },
  "alerts": {
    "warn_pct": 80,
    "hard_stop_pct": 100
  }
}
```

## Cost Data

Session costs are tracked by the Stop hook in `~/.claude/session-costs.json`:
```json
{
  "session_cost_usd": 1.23,
  "total_sessions": 42,
  "monthly_cost_usd": 15.67,
  "last_session": "2026-03-28T10:00:00Z"
}
```

## Commands

### `show` (default)

Read `~/.claude/config/budget.json` and `~/.claude/session-costs.json`. Display:

```
## Budget Dashboard
Project: {project or "default"}  |  Date: {YYYY-MM-DD}

Session:  $X.XX / $Y.YY  (Z%)  [██████████░░░░░░░░░░]
Monthly:  $X.XX / $Y.YY  (Z%)  [████░░░░░░░░░░░░░░░░]

Burn rate:     ~$X.XX/hr
Sessions today: {n}
Avg session:   $X.XX

Status: 🟢 OK / 🟡 WARNING (>80%) / 🔴 CRITICAL (>100%)
```

Progress bar: 20 chars, filled proportionally with `█`, empty with `░`.

### `set <project> <session_usd> [monthly_usd]`

Update `~/.claude/config/budget.json` for the specified project. If project is "default", update the top-level defaults. Confirm the change.

### `reset`

Reset `session_cost_usd` to 0.00 in `~/.claude/session-costs.json`. Keep history. Confirm reset.

### `history [n]`

Show last `n` (default 10) sessions with: date, cost, project, duration if available.

### `alert-config <warn_pct> <hard_stop_pct>`

Update alert thresholds in budget.json. Validate: warn_pct < hard_stop_pct <= 100.

## Integration with Hook

The hook `~/.claude/hooks/budget-check.sh` runs before every tool call and:
- Reads current cost from `session-costs.json`
- Warns at `warn_pct`% — outputs warning to stderr but allows continuation
- Hard stops at `hard_stop_pct`% — outputs error to stderr and exits with code 1

To disable the hard stop temporarily:
```bash
# In ~/.claude/config/budget.json
"alerts": { "warn_pct": 80, "hard_stop_pct": 200 }
```

## Rules

- Never modify costs.json directly — only read it
- Always validate JSON before writing budget.json
- Warn the user if hard_stop_pct would block current session
- If costs file doesn't exist, show $0.00 / $Y.YY with a note
