# AI Agent Stack

> The most complete open-source AI orchestration stack for Claude Code and OpenCode. Self-hosted, observable, and self-improving.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Works with Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-blueviolet)](https://claude.ai/code)
[![Works with OpenCode](https://img.shields.io/badge/OpenCode-compatible-blue)](https://opencode.ai)
[![Self-hosted](https://img.shields.io/badge/100%25-self--hosted-green)]()

```
┌─────────────────────────────────────────────────────────────────┐
│               YOUR AI ORCHESTRATOR                              │
│   Claude Code / OpenCode  ←→  Engram (memory)  ←→  Skills      │
└──────────────────────┬──────────────────────────────────────────┘
                       │ delegates work to sub-agents
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  sdd-eval  │  budget-guard  │  model-tournament  │  ci-watcher  │
│  worktree-agent             │  rag-search                       │
└──────────────────────┬──────────────────────────────────────────┘
                       │ full observability + infrastructure
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Langfuse :3001  │  Qdrant :6333  │  Redis :6380  │  NATS :4222 │
└─────────────────────────────────────────────────────────────────┘
```

## What is this?

6 new AI agent skills + full self-hosted observability infrastructure for [Claude Code](https://claude.ai/code) and [OpenCode](https://opencode.ai). Everything runs locally. No subscriptions. No data leaving your machine.

| Layer | What it does |
|-------|-------------|
| **Skills** | 6 new agent protocols: eval loops, cost control, git isolation, model comparison, CI healing, semantic search |
| **Observability** | Langfuse self-hosted — every tool call traced, costs tracked, sessions visualized |
| **RAG** | Qdrant + Ollama nomic-embed-text — semantic search over your codebase |
| **Messaging** | NATS JetStream — inter-agent pub/sub with persistence |
| **Budget Guard** | Pre-tool hook that warns at 80% and hard-stops at 100% of your session budget |

## Skills

### `sdd-eval` — Auto-evaluator with feedback loop

Scores your implementation 0–100 against the spec. Loops back to `sdd-apply` with specific feedback if score < 80. No more "looks good to me" commits.

```
Score: 73/100 → FAILED

Tests:   21/24 (87%) — 29/40 pts
Spec:    4/5 requirements — 32/40 pts
Quality: 2 TODOs found — 12/20 pts

Feedback for next iteration:
- src/auth/middleware.ts:47 — REQ-03 (token blacklist) not implemented
- Remove TODO on line 89 before shipping
```

### `budget-guard` — Cost governance

Know exactly what you're spending. Block runaway sessions automatically.

```
Session:  $2.31 / $5.00  (46%)  [█████████░░░░░░░░░░░]
Monthly:  $18.50 / $50.00 (37%) [███████░░░░░░░░░░░░░]
Burn rate: ~$1.15/hr
Status: 🟢 OK
```

### `worktree-agent` — Git isolation

Every coding sub-agent gets its own `git worktree` + branch. Changes automatically become PRs. No more agents overwriting each other's work.

```bash
# What happens automatically:
git worktree add /tmp/wt-a3f92b1 -b agent/auth-refactor-a3f92b1
# ... sub-agent does its work ...
git commit -m "agent: auth-refactor"
git push && gh pr create --title "agent: auth-refactor"
git worktree remove /tmp/wt-a3f92b1
```

### `model-tournament` — Pick the best model

Run the same task on two models in parallel. LLM-as-judge picks the winner. Stats accumulate over time to feed the model router.

```
Tournament Result

Model A (claude-sonnet-4-6):    87/100
Model B (claude-haiku-4-5):     74/100

Winner: claude-sonnet-4-6 (+13 pts)

Criteria: correctness=9/7, completeness=8/7, production-readiness=8/7
Stats saved → ~/.claude/config/model-stats.json
```

### `ci-watcher` — Self-healing CI

GitHub Actions failed? ci-watcher reads the logs, classifies the error, fixes it, and opens a PR. Automatically.

```
CI Watcher Report

Run: #98765 | CI | my-org/my-repo
Root cause: test-failure — JWTExpiredError in auth.test.ts:89

Fix applied:
- src/auth/middleware.ts: Updated token expiry check
- tests/auth.test.ts: Fixed test setup to use non-expired fixture

PR opened: https://github.com/my-org/my-repo/pull/142
```

### `rag-search` — Semantic code search

"Find where we handle rate limiting" — returns the actual files, even if they don't contain the words "rate limiting". Powered by Qdrant + Ollama (local, no API key).

```
RAG Search Results
Query: "rate limiting middleware"

1. src/middleware/throttle.ts (score: 0.94)
   > export const rateLimit = (max: number, window: number) => ...

2. src/api/routes.ts (score: 0.87)
   > router.use('/api', throttle({ max: 100, window: 60 }))
```

## Infrastructure

All services run locally via Docker Compose. Zero cloud dependencies.

| Service | Port | Role |
|---------|------|------|
| [Langfuse](https://langfuse.com) | 3001 | Observability — traces, costs, sessions |
| [Qdrant](https://qdrant.tech) | 6333 | Vector DB for RAG |
| Redis | 6380 | Budget tracking + pub/sub |
| [NATS](https://nats.io) | 4222 | Inter-agent messaging (JetStream) |

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/YOUR_USERNAME/ai-agent-stack
cd ai-agent-stack
chmod +x install.sh && ./install.sh
```

### 2. Start infrastructure

```bash
docker compose -f ~/.claude/infra/docker-compose.yml up -d
```

### 3. Install Ollama embeddings

```bash
# Install Ollama: https://ollama.com/install
ollama serve &
ollama pull nomic-embed-text
```

### 4. Register hooks in Claude Code

Add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "",
      "hooks": [{"type": "command", "command": "~/.claude/hooks/langfuse-tracer.sh", "timeout": 5}]
    }],
    "PreToolUse": [{
      "matcher": "",
      "hooks": [{"type": "command", "command": "~/.claude/hooks/budget-check.sh", "timeout": 5}]
    }]
  }
}
```

### 5. Open the dashboard

```
http://localhost:3001
Login: admin@local.dev / admin1234
```

### 6. Index your first project

```bash
~/.claude/scripts/rag-index.sh ~/git/my-project my-project
```

**That's it.** Every Claude Code session now appears in Langfuse. Every tool call is traced. Your budget is protected.

## Compatibility

Skills use the [Agent Skills open standard](https://opencode.ai/docs/skills/) and work across:

| Tool | Skills | Observability | RAG | Budget |
|------|--------|--------------|-----|--------|
| Claude Code | ✅ Native | ✅ PostToolUse hook | ✅ Script | ✅ PreToolUse hook |
| OpenCode | ✅ Symlinked | ✅ TypeScript plugin | ✅ Script | ✅ Script |

## Requirements

- Docker + Docker Compose
- Claude Code or OpenCode
- [Ollama](https://ollama.com) (for RAG embeddings — local, free)
- `jq`, `curl`, `bash`
- Optional: `gh` CLI (for `ci-watcher` and `worktree-agent`)

## Project Structure

```
ai-agent-stack/
├── install.sh                   # One-command installer
├── skills/                      # Agent skill protocols
│   ├── sdd-eval/SKILL.md        # Auto-evaluator
│   ├── budget-guard/SKILL.md    # Cost governance
│   ├── worktree-agent/SKILL.md  # Git isolation
│   ├── model-tournament/SKILL.md # Model comparison
│   ├── ci-watcher/SKILL.md      # Self-healing CI
│   └── rag-search/SKILL.md      # Semantic search
├── hooks/                       # Claude Code hooks
│   ├── langfuse-tracer.sh       # PostToolUse → Langfuse
│   └── budget-check.sh          # PreToolUse → budget enforcement
├── scripts/                     # Utility scripts
│   ├── rag-index.sh             # Index codebase → Qdrant
│   ├── rag-search.sh            # Semantic search
│   └── log-langfuse.sh          # Log any event to Langfuse
├── opencode/
│   └── plugins/
│       └── langfuse-tracer.ts   # OpenCode TypeScript plugin
├── infra/
│   ├── docker-compose.yml       # All services
│   └── .env.example             # Config template
└── config/
    └── budget.example.json      # Budget config template
```

## How it fits with SDD

If you're using [Spec-Driven Development](https://github.com/Gentleman-Programming/engram) (SDD), this stack plugs in at every phase:

```
sdd-explore → rag-search (find existing patterns)
sdd-apply   → worktree-agent (isolated branch) → sdd-eval (auto-score)
sdd-verify  → all traces visible in Langfuse
any phase   → budget-guard (never overspend)
CI fails    → ci-watcher (auto-fix + PR)
```

## Observability

Every session in Langfuse shows:

- **Traces** — one per session, spans for each tool call
- **Costs** — per session, per model, per agent phase
- **Latency** — which tools/phases take longest
- **History** — full audit trail

## Contributing

PRs welcome. Skills follow the [Agent Skills standard](https://opencode.ai/docs/skills/) — if you build a new skill that works across Claude Code and OpenCode, open a PR.

New skills should:
- Have a `SKILL.md` with YAML frontmatter (`name`, `description`, `license`)
- Work with at least one of: Claude Code, OpenCode
- Not require external API keys to function (local-first)

## License

MIT — use it, fork it, build on it.

---

Built with [Claude Code](https://claude.ai/code) · Observability by [Langfuse](https://langfuse.com) · Vector search by [Qdrant](https://qdrant.tech) · Embeddings by [Ollama](https://ollama.com)
