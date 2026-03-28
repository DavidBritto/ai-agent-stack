---
name: rag-search
description: Semantic search over indexed codebase using Qdrant + Ollama. Find relevant code by meaning, not keywords. Trigger: when orchestrator needs semantic context before launching coding sub-agents, or user invokes /rag-search.
license: MIT
metadata:
  author: david
  version: "1.0"
---

# rag-search — Semantic Code Search

Search your codebase by meaning. "How is authentication handled?" finds the auth middleware even if you don't know its filename.

## Prerequisites

- Qdrant running: `curl -s http://localhost:6333/health`
- Ollama running with nomic-embed-text: `ollama list | grep nomic`
- At least one collection indexed via `~/.claude/scripts/rag-index.sh`

## Quick Start

```bash
# Check services
curl -s http://localhost:6333/health
curl -s http://localhost:11434/api/tags | jq '.models[].name'

# List available collections
curl -s http://localhost:6333/collections | jq '.result.collections[].name'

# Search
~/.claude/scripts/rag-search.sh "database connection pooling" my-project 5
```

## Invocation

```
/rag-search <query> [collection] [top_k]
```
- `query`: natural language description of what you're looking for
- `collection`: Qdrant collection name (default: "default")
- `top_k`: number of results (default: 5, max: 20)

## Execution

### Step 1: Health Check

```bash
# Qdrant
QDRANT_STATUS=$(curl -sf --max-time 2 http://localhost:6333/health | jq -r '.status' 2>/dev/null)
[ "$QDRANT_STATUS" = "ok" ] || { echo "ERROR: Qdrant not running. Start with: docker compose -f ~/.claude/infra/docker-compose.yml up -d qdrant"; exit 1; }

# Ollama
OLLAMA_OK=$(curl -sf --max-time 2 http://localhost:11434/api/tags | jq '.models | length' 2>/dev/null)
[ "${OLLAMA_OK:-0}" -gt 0 ] || { echo "ERROR: Ollama not running. Start with: ollama serve"; exit 1; }
```

### Step 2: If Collection Not Specified

```bash
# List available collections for user to choose
curl -s http://localhost:6333/collections | jq -r '.result.collections[] | "  - \(.name) (\(.vectors_count) vectors)"'
```

### Step 3: Run Search

Use `~/.claude/scripts/rag-search.sh`:
```bash
~/.claude/scripts/rag-search.sh "{query}" "{collection}" {top_k}
```

Or call directly if needed:
```bash
# Embed query
EMBEDDING=$(curl -sf http://localhost:11434/api/embed \
  -d "{\"model\":\"nomic-embed-text\",\"input\":\"$QUERY\"}" \
  | jq -c '.embeddings[0]')

# Search
curl -sf -X POST http://localhost:6333/collections/{collection}/points/search \
  -H "Content-Type: application/json" \
  -d "{\"vector\":$EMBEDDING,\"limit\":$TOP_K,\"with_payload\":true,\"score_threshold\":0.5}"
```

### Step 4: Format and Return

Present results with file path, relevance score, and snippet. Recommend top 3 as context for sub-agents.

## How Orchestrators Should Use This

Before launching a coding sub-agent:

```
1. Run: /rag-search "{task description}" {project-collection}
2. Take top 3 results
3. Include in sub-agent prompt:
   "Relevant existing code found:
   - {file1}: {snippet1}
   - {file2}: {snippet2}
   - {file3}: {snippet3}
   Consider this context when implementing."
```

This reduces hallucination and helps sub-agents find existing patterns.

## Indexing a Project

```bash
# Index a project (first time or after major changes)
~/.claude/scripts/rag-index.sh ~/git/my-project my-project

# Re-index specific files after changes
# (full re-index is simplest — Qdrant upserts handle duplicates)
~/.claude/scripts/rag-index.sh ~/git/my-project my-project
```

## Output Format

```markdown
## RAG Search Results
Query: "{query}"
Collection: {collection} | {n} results

### 1. {file_path} (score: 0.94)
```{language}
{code snippet — first 300 chars}
```

### 2. {file_path} (score: 0.89)
```{language}
{code snippet}
```

### 3. {file_path} (score: 0.84)
```{language}
{code snippet}
```

---
*Powered by Qdrant + Ollama nomic-embed-text*
*To index a project: `~/.claude/scripts/rag-index.sh <path> <collection>`*
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Qdrant not running" | `docker compose -f ~/.claude/infra/docker-compose.yml up -d qdrant` |
| "Ollama not running" | `ollama serve` (or check if running: `ps aux \| grep ollama`) |
| "Collection not found" | Run `rag-index.sh` first |
| "nomic-embed-text not found" | `ollama pull nomic-embed-text` |
| Empty results | Lower score_threshold to 0.3, or re-index with more files |
