---
name: ci-watcher
description: Self-healing CI skill. Detects GitHub Actions failures, identifies root cause, auto-fixes via sub-agent, opens PR. Trigger: when user invokes /ci-watcher [repo] [run-id] or CI failure detected.
license: MIT
metadata:
  author: david
  version: "1.0"
---

# ci-watcher — Self-Healing CI

Detect CI failures → identify root cause → fix automatically → open PR. Zero manual intervention for routine failures.

## Prerequisites

- `gh` CLI authenticated: `gh auth status`
- Repository with GitHub Actions
- Optional: Trigger.dev webhook for automatic triggering

## Invocation

```
/ci-watcher [repo] [run-id]
```
- `repo`: `owner/repo` format. Defaults to current repo (`gh repo view --json nameWithOwner`)
- `run-id`: specific run ID. Defaults to latest failed run

## Step 1: Identify Failed Run

```bash
# If run-id not provided, find latest failure:
gh run list --repo {repo} --status failure --limit 1 --json databaseId,name,conclusion,createdAt
```

## Step 2: Fetch Failure Details

```bash
# Get overall run info
gh run view {run-id} --repo {repo} --json status,conclusion,name,jobs

# Get failed job logs only
gh run view {run-id} --repo {repo} --log-failed
```

Parse the logs to extract:
- Workflow name
- Job name that failed
- Step that failed
- Error messages (last 50 lines of failed step)

## Step 3: Classify Root Cause

Classify into one of these categories:

| Category | Symptoms | Auto-fixable? |
|----------|----------|---------------|
| `test-failure` | Test assertions failed, specific test names in output | ✅ Yes |
| `build-error` | Compilation error, type error, syntax error | ✅ Yes |
| `lint-error` | ESLint, flake8, clippy errors | ✅ Yes |
| `dependency-error` | Package not found, version conflict | ✅ Yes |
| `flaky-test` | Same test passes/fails randomly, timing issues | ❌ No |
| `infrastructure` | Runner OOM, network timeout, Docker failure | ❌ No |
| `security-scan` | Vulnerability alert, secrets detected | ❌ No — Escalate |
| `unknown` | Cannot determine cause | ❌ No — Escalate |

## Step 4: Auto-Fix (for fixable categories)

For auto-fixable failures:

1. **Setup worktree** (follow worktree-agent protocol):
   ```bash
   WID=$(cat /proc/sys/kernel/random/uuid | cut -c1-8)
   BRANCH="fix/ci-${run-id}-${WID}"
   git worktree add "/tmp/wt-${WID}" -b "$BRANCH"
   ```

2. **Clone repo context** into worktree (or use existing checkout)

3. **Launch fix sub-agent** with:
   - Full error logs
   - Root cause classification
   - Category-specific instructions:
     - `test-failure`: Fix the code to make the test pass. Do NOT change the test unless it's clearly wrong.
     - `build-error`: Fix the compilation/type errors.
     - `lint-error`: Fix lint violations. Run lint locally to verify.
     - `dependency-error`: Update lockfile or add missing dependency.

4. **Verify fix locally** before pushing:
   ```bash
   # For test failures:
   {test_command} --testPathPattern "{failed_test}" 2>&1 | tail -20
   ```

5. **Commit and push**:
   ```bash
   git add -A
   git commit -m "fix: CI failure in {workflow} — {root_cause_summary}"
   git push -u origin "$BRANCH"
   ```

6. **Open PR**:
   ```bash
   gh pr create \
     --title "fix: CI #{run-id} — {root_cause}" \
     --body "Auto-fix by ci-watcher\n\nFailed run: {run-url}\nRoot cause: {category}\n\n## Changes\n{diff summary}" \
     --base main
   ```

## Step 5: Save to Engram

```
mem_save(
  title: "ci-watcher/{repo}/run-{run-id}",
  topic_key: "ci-watcher/{repo}/run-{id}",
  type: "bugfix",
  project: "{project}",
  content: "CI fix: {root_cause}. PR: {pr_url}"
)
```

## Escalation (non-fixable)

When auto-fix is not possible, report to user:

```markdown
## CI Watcher — Escalation Required

Run: #{id} | {workflow} | {repo}
Category: {flaky-test | infrastructure | security-scan | unknown}

**Why I can't auto-fix**:
{Explanation specific to category}

**Recommended action**:
- Flaky test: Add retry logic or fix timing dependency
- Infrastructure: Check runner limits in GitHub settings
- Security: Review alert at {link}, rotate if secret exposed

**Raw error**:
{last 20 lines of error}
```

## Webhook Trigger Setup

To trigger ci-watcher automatically from GitHub Actions:

1. In your repo's `.github/workflows/`, add a workflow that posts to your Trigger.dev webhook on failure
2. Or use GitHub Actions `workflow_run` event to detect failures

See `/trigger-tasks` for Trigger.dev webhook setup.

## Output Format

```markdown
## CI Watcher Report

Run: #{id} | {workflow} | {repo}
Status: ❌ FAILED → 🔍 Analyzing...

**Root cause**: {category} — {description}

**Fix applied**:
- {file 1}: {what changed}
- {file 2}: {what changed}

**Verification**: {test command output — pass/fail}

**PR**: {url}
**Branch**: {branch}
```
