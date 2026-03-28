#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# RAG Index — Embed codebase into Qdrant via Ollama
# Usage: rag-index.sh <project-path> <collection-name>
#
# Requirements:
#   - Qdrant running (docker compose -f ~/.claude/infra/docker-compose.yml up -d qdrant)
#   - Ollama running with nomic-embed-text (ollama pull nomic-embed-text)
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PROJECT_PATH="${1:-.}"
COLLECTION="${2:-default}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
EMBED_MODEL="${OLLAMA_EMBED_MODEL:-nomic-embed-text}"

# Load .env overrides
ENV_FILE="$HOME/.claude/infra/.env"
[ -f "$ENV_FILE" ] && set -a && source "$ENV_FILE" && set +a

echo "RAG Index: $PROJECT_PATH → collection '$COLLECTION'"
echo "Qdrant:    $QDRANT_URL"
echo "Ollama:    $OLLAMA_URL ($EMBED_MODEL)"
echo ""

# ── Check services ────────────────────────────────────────────
echo "Checking services..."
curl -sf --max-time 5 "$QDRANT_URL/health" > /dev/null \
  || { echo "ERROR: Qdrant not running at $QDRANT_URL"; echo "Start: docker compose -f ~/.claude/infra/docker-compose.yml up -d qdrant"; exit 1; }

curl -sf --max-time 5 "$OLLAMA_URL/api/tags" > /dev/null \
  || { echo "ERROR: Ollama not running at $OLLAMA_URL"; echo "Start: ollama serve"; exit 1; }

# Check nomic-embed-text is available
HAS_MODEL=$(curl -sf "$OLLAMA_URL/api/tags" | jq -r ".models[] | select(.name | contains(\"nomic\")) | .name" 2>/dev/null | head -1)
if [ -z "$HAS_MODEL" ]; then
  echo "ERROR: nomic-embed-text not found in Ollama"
  echo "Install: ollama pull nomic-embed-text"
  exit 1
fi
echo "Services OK. Model: $HAS_MODEL"
echo ""

# ── Create/recreate collection ────────────────────────────────
# nomic-embed-text produces 768-dimensional vectors
echo "Creating collection '$COLLECTION'..."
RESPONSE=$(curl -sf -X PUT "$QDRANT_URL/collections/$COLLECTION" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    },
    "optimizers_config": {
      "default_segment_number": 2
    }
  }')
echo "Collection ready: $(echo "$RESPONSE" | jq -r '.result' 2>/dev/null || echo 'ok')"
echo ""

# ── Index files ───────────────────────────────────────────────
POINT_ID=1
INDEXED=0
SKIPPED=0

# Find all code/doc files, excluding build artifacts
while IFS= read -r FILE; do
  # Read up to 3000 chars (enough for good embeddings, fast enough)
  CONTENT=$(head -c 3000 "$FILE" 2>/dev/null || true)
  [ -z "$CONTENT" ] && { SKIPPED=$((SKIPPED + 1)); continue; }

  # Get embedding from Ollama
  EMBEDDING=$(curl -sf --max-time 60 "$OLLAMA_URL/api/embed" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$EMBED_MODEL\",\"input\":$(echo "$CONTENT" | jq -Rs .)}" \
    | jq -c '.embeddings[0]' 2>/dev/null || echo "")

  if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Build payload
  RELATIVE_PATH="${FILE#$PROJECT_PATH/}"
  SNIPPET="${CONTENT:0:400}"
  PAYLOAD=$(jq -n \
    --arg file "$RELATIVE_PATH" \
    --arg project "$(basename "$PROJECT_PATH")" \
    --arg snippet "$SNIPPET" \
    --arg full_path "$FILE" \
    '{file: $file, project: $project, snippet: $snippet, path: $full_path}')

  # Upsert to Qdrant
  curl -sf --max-time 15 \
    -X PUT "$QDRANT_URL/collections/$COLLECTION/points" \
    -H "Content-Type: application/json" \
    -d "{\"points\":[{\"id\":$POINT_ID,\"vector\":$EMBEDDING,\"payload\":$PAYLOAD}]}" > /dev/null

  echo "  [${POINT_ID}] $RELATIVE_PATH"
  POINT_ID=$((POINT_ID + 1))
  INDEXED=$((INDEXED + 1))

done < <(find "$PROJECT_PATH" \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
    -o -name "*.kt" -o -name "*.swift" -o -name "*.rb" -o -name "*.php" \
    -o -name "*.md" -o -name "*.sh" -o -name "*.yaml" -o -name "*.yml" \
    -o -name "*.json" -o -name "*.toml" \) \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/dist/*" \
    ! -path "*/build/*" \
    ! -path "*/__pycache__/*" \
    ! -path "*/target/*" \
    ! -path "*/.next/*" \
    ! -path "*/coverage/*" \
    -type f 2>/dev/null)

echo ""
echo "Done!"
echo "  Indexed:  $INDEXED files"
echo "  Skipped:  $SKIPPED files"
echo "  Collection: $COLLECTION"
echo ""
echo "Search: ~/.claude/scripts/rag-search.sh \"your query\" $COLLECTION"
