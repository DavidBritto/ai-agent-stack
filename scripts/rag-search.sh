#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# RAG Search — Semantic search over indexed codebase
# Usage: rag-search.sh <query> [collection] [top_k]
#
# Examples:
#   rag-search.sh "database connection pool"
#   rag-search.sh "authentication middleware" my-project 3
# ─────────────────────────────────────────────────────────────

set -euo pipefail

QUERY="${1:-}"
COLLECTION="${2:-default}"
TOP_K="${3:-5}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
EMBED_MODEL="${OLLAMA_EMBED_MODEL:-nomic-embed-text}"
SCORE_THRESHOLD="${SCORE_THRESHOLD:-0.4}"

# Load .env overrides
ENV_FILE="$HOME/.claude/infra/.env"
[ -f "$ENV_FILE" ] && set -a && source "$ENV_FILE" && set +a

if [ -z "$QUERY" ]; then
  echo "Usage: rag-search.sh <query> [collection] [top_k]"
  echo ""
  echo "Available collections:"
  curl -sf "$QDRANT_URL/collections" | jq -r '.result.collections[] | "  - \(.name)"' 2>/dev/null || echo "  (Qdrant not running)"
  exit 1
fi

# ── Check services ────────────────────────────────────────────
curl -sf --max-time 2 "$QDRANT_URL/health" > /dev/null \
  || { echo "ERROR: Qdrant not running. Start: docker compose -f ~/.claude/infra/docker-compose.yml up -d qdrant"; exit 1; }

# ── Embed query ───────────────────────────────────────────────
EMBEDDING=$(curl -sf --max-time 30 "$OLLAMA_URL/api/embed" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$EMBED_MODEL\",\"input\":$(echo "$QUERY" | jq -Rs .)}" \
  | jq -c '.embeddings[0]' 2>/dev/null)

if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
  echo "ERROR: Could not embed query. Is Ollama running with nomic-embed-text?"
  echo "Check: ollama list | grep nomic"
  echo "Fix:   ollama pull nomic-embed-text"
  exit 1
fi

# ── Search Qdrant ─────────────────────────────────────────────
RESULTS=$(curl -sf --max-time 10 \
  -X POST "$QDRANT_URL/collections/$COLLECTION/points/search" \
  -H "Content-Type: application/json" \
  -d "{
    \"vector\": $EMBEDDING,
    \"limit\": $TOP_K,
    \"with_payload\": true,
    \"score_threshold\": $SCORE_THRESHOLD
  }" 2>/dev/null)

if [ -z "$RESULTS" ]; then
  echo "ERROR: Search failed. Collection '$COLLECTION' may not exist."
  echo "Available: $(curl -sf "$QDRANT_URL/collections" | jq -r '[.result.collections[].name] | join(", ")' 2>/dev/null)"
  exit 1
fi

RESULT_COUNT=$(echo "$RESULTS" | jq '.result | length' 2>/dev/null || echo "0")

# ── Format output ─────────────────────────────────────────────
echo "## RAG Search Results"
echo "Query:      \"$QUERY\""
echo "Collection: $COLLECTION  |  Found: $RESULT_COUNT results"
echo ""

if [ "$RESULT_COUNT" = "0" ]; then
  echo "No results found. Try:"
  echo "  - Lowering threshold: SCORE_THRESHOLD=0.2 $(basename "$0") \"$QUERY\" $COLLECTION"
  echo "  - Re-indexing: ~/.claude/scripts/rag-index.sh <project-path> $COLLECTION"
  exit 0
fi

echo "$RESULTS" | jq -r '
  .result | to_entries[] |
  "### \(.key + 1). \(.value.payload.file) (score: \(.value.score | . * 100 | round / 100))\n```\n\(.value.payload.snippet[:350])\n```\n"
'
