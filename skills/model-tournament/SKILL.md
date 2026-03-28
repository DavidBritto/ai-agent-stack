---
name: model-tournament
description: Multi-model competition skill. Run same task on 2 models in parallel, LLM-as-judge evaluates, winner is declared and stats updated. Trigger: when user invokes /model-tournament or orchestrator needs to pick best model for a task.
license: MIT
metadata:
  author: david
  version: "1.0"
---

# model-tournament — Multi-Model Competition

Run the same task against two models simultaneously. Pick the best output. Learn over time which model wins for which task type.

## When to Use

- Uncertain which model handles a task better
- High-stakes tasks where quality matters most
- Building model preference data for the router (`sdd-model-router`)
- User explicitly requests `/model-tournament`

## Config File

`~/.claude/config/model-stats.json`:
```json
{
  "models": ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"],
  "stats": {
    "claude-sonnet-4-6": { "wins": 0, "losses": 0, "by_type": {} },
    "claude-haiku-4-5-20251001": { "wins": 0, "losses": 0, "by_type": {} }
  },
  "last_updated": ""
}
```

## Invocation

```
/model-tournament
task: {description of what you want done}
criteria: {comma-separated evaluation criteria}
model_a: claude-sonnet-4-6        (optional, default)
model_b: claude-haiku-4-5-20251001 (optional, default)
task_type: {code|writing|analysis|planning|debug}
```

## Execution Steps

### Step 1: Validate Inputs
- task and criteria are required
- If models not specified, use defaults from model-stats.json
- If task_type not specified, infer from task description

### Step 2: Prepare Identical Prompts
Build a prompt for both models with:
- The exact task description
- Any context provided
- No model-specific hints

### Step 3: Launch Parallel Sub-Agents
Launch 2 sub-agents simultaneously (use `run_in_background: true`):
- Sub-agent A: model = model_a, prompt = prepared prompt
- Sub-agent B: model = model_b, prompt = prepared prompt
Wait for both to complete.

### Step 4: Evaluate (LLM-as-Judge)

For each criterion, score both outputs 0-10:

```
Criteria scoring:
- Correctness:    Does it accurately address the task?
- Completeness:   Does it cover all aspects of the task?
- Clarity:        Is the output clear and well-structured?
- Conciseness:    Is it appropriately concise (not verbose)?
- Edge cases:     Does it handle edge cases or mention limitations?
{+ any user-specified criteria}
```

Sum scores. Calculate percentage. Declare winner.

### Step 5: Update Stats

Update `~/.claude/config/model-stats.json`:
- Increment wins/losses for each model
- Update `by_type.{task_type}` win/loss counts
- Set `last_updated` to current timestamp

### Step 6: Recommend

Based on accumulated stats in model-stats.json, add a recommendation:
> "Based on {n} tournaments, {model} wins {X}% of {task_type} tasks. Consider updating sdd-model-router."

## Output Format

```markdown
## Tournament Result

**Task**: {task_description}
**Task type**: {task_type}
**Criteria**: {criteria list}

---

### Model A: {model_a}
Score: {score}/100

{Output from Model A (first 500 chars if long)}

---

### Model B: {model_b}
Score: {score}/100

{Output from Model B (first 500 chars if long)}

---

### Verdict

🏆 **Winner: {model}** (+{margin} pts)

| Criterion | Model A | Model B |
|-----------|---------|---------|
| {crit 1}  | {n}/10  | {n}/10  |
| {crit 2}  | {n}/10  | {n}/10  |
| **Total** | **{n}** | **{n}** |

**Why {winner} won**: {1-2 sentence explanation}

**Recommendation**: {insight for future routing}

Stats updated: `~/.claude/config/model-stats.json`
```

## Rules

- Score objectively — you are the judge, not an advocate
- If scores are within 5 pts, declare a tie and recommend based on cost (cheaper model wins ties)
- Never reveal which output is which BEFORE scoring (prevent bias)
- Always save stats even on ties
- If a sub-agent fails, report failure and declare the other model winner by default
