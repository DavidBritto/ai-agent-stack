#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# log-langfuse.sh — Log a task/event to Langfuse
# Usable from OpenCode (Anya), Claude Code, or any shell script
#
# Usage:
#   log-langfuse.sh <task-name> <input> <output> [cost_usd] [model] [tags]
#
# Examples:
#   log-langfuse.sh "fix auth bug" "JWT expired error" "Fixed token refresh logic" 0.003
#   log-langfuse.sh "rag-search" "query: auth middleware" "Found 5 results" 0 "local"
# ─────────────────────────────────────────────────────────────

set -euo pipefail

TASK_NAME="${1:-unnamed-task}"
INPUT_TEXT="${2:-}"
OUTPUT_TEXT="${3:-}"
COST_USD="${4:-0}"
MODEL="${5:-unknown}"
TAGS="${6:-opencode}"

LANGFUSE_URL="${LANGFUSE_URL:-http://localhost:3001}"
LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-local-orchestrator}"
LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-local-orchestrator}"

# Load .env
ENV_FILE="$HOME/.claude/infra/.env"
[ -f "$ENV_FILE" ] && set -a && source "$ENV_FILE" && set +a

# Quick health check
curl -sf --max-time 1 "$LANGFUSE_URL/api/public/health" > /dev/null 2>&1 \
  || { echo "Langfuse not running — skipping log"; exit 0; }

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
TRACE_ID="oc-$(date +%s)-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | cut -c1-8 || echo $RANDOM)"
SPAN_ID="sp-$TRACE_ID"

# Escape strings for JSON
INPUT_JSON=$(echo "$INPUT_TEXT" | jq -Rs .)
OUTPUT_JSON=$(echo "$OUTPUT_TEXT" | jq -Rs .)
TAGS_JSON=$(echo "$TAGS" | jq -Rs 'split(",")')

# Create trace + generation in one batch
curl -sf --max-time 5 \
  -X POST "$LANGFUSE_URL/api/public/ingestion" \
  -H "Content-Type: application/json" \
  -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  -d "{
    \"batch\": [
      {
        \"id\": \"ev-trace-$TRACE_ID\",
        \"type\": \"trace-create\",
        \"timestamp\": \"$TIMESTAMP\",
        \"body\": {
          \"id\": \"$TRACE_ID\",
          \"name\": \"$TASK_NAME\",
          \"userId\": \"anya\",
          \"tags\": $TAGS_JSON,
          \"metadata\": {
            \"source\": \"opencode\",
            \"model\": \"$MODEL\"
          }
        }
      },
      {
        \"id\": \"$SPAN_ID\",
        \"type\": \"generation-create\",
        \"timestamp\": \"$TIMESTAMP\",
        \"body\": {
          \"id\": \"$SPAN_ID\",
          \"traceId\": \"$TRACE_ID\",
          \"name\": \"$TASK_NAME\",
          \"model\": \"$MODEL\",
          \"startTime\": \"$TIMESTAMP\",
          \"input\": $INPUT_JSON,
          \"output\": $OUTPUT_JSON,
          \"calculatedTotalCost\": $COST_USD
        }
      }
    ]
  }" > /dev/null 2>&1

echo "Logged to Langfuse: '$TASK_NAME' → http://localhost:3001"
