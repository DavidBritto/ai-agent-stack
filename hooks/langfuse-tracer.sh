#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Langfuse Tracer Hook — PostToolUse
# Sends tool usage spans to local Langfuse for observability
# ─────────────────────────────────────────────────────────────

set -euo pipefail

LANGFUSE_URL="${LANGFUSE_URL:-http://localhost:3001}"
LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-local-orchestrator}"
LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-local-orchestrator}"

# Load .env overrides if present
ENV_FILE="$HOME/.claude/infra/.env"
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

# Read hook input from stdin (Claude Code passes JSON)
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null || echo '{}')
# Truncate output to 1000 chars to avoid huge payloads
TOOL_OUTPUT=$(echo "$INPUT" | jq -c '.tool_response // {}' 2>/dev/null | head -c 1000 || echo '{}')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "no-session"' 2>/dev/null || echo "no-session")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
SPAN_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$RANDOM-$RANDOM-$RANDOM")

# Quick health check — skip silently if Langfuse is not running
if ! curl -sf --max-time 1 "$LANGFUSE_URL/api/public/health" > /dev/null 2>&1; then
  exit 0
fi

# Send span to Langfuse ingestion API
curl -sf --max-time 3 \
  -X POST "$LANGFUSE_URL/api/public/ingestion" \
  -H "Content-Type: application/json" \
  -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  -d "{
    \"batch\": [{
      \"id\": \"$SPAN_ID\",
      \"type\": \"span-create\",
      \"timestamp\": \"$TIMESTAMP\",
      \"body\": {
        \"id\": \"$SPAN_ID\",
        \"traceId\": \"$SESSION_ID\",
        \"name\": \"$TOOL_NAME\",
        \"startTime\": \"$TIMESTAMP\",
        \"input\": $TOOL_INPUT,
        \"output\": $TOOL_OUTPUT,
        \"metadata\": {
          \"tool\": \"$TOOL_NAME\",
          \"session\": \"$SESSION_ID\"
        }
      }
    }]
  }" > /dev/null 2>&1 || true  # Never fail the hook — observability is non-blocking

exit 0
