/**
 * langfuse-tracer — OpenCode plugin
 *
 * Sends tool usage spans to local Langfuse for observability.
 * Mirrors the Claude Code PostToolUse hook but as an OpenCode plugin.
 *
 * Flow:
 *   OpenCode tool events → this plugin → HTTP POST → Langfuse :3001
 *
 * Non-blocking: all errors are swallowed. Observability never blocks work.
 */

import type { Plugin } from "@opencode-ai/plugin"

// ─── Configuration ───────────────────────────────────────────────────────────

const LANGFUSE_URL = process.env.LANGFUSE_URL ?? "http://localhost:3001"
const LANGFUSE_PUBLIC_KEY = process.env.LANGFUSE_PUBLIC_KEY ?? "pk-lf-local-orchestrator"
const LANGFUSE_SECRET_KEY = process.env.LANGFUSE_SECRET_KEY ?? "sk-lf-local-orchestrator"
const AUTH = Buffer.from(`${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}`).toString("base64")

// Tools to skip (too noisy or internal)
const SKIP_TOOLS = new Set([
  "mem_search", "mem_save", "mem_update", "mem_context",
  "mem_get_observation", "mem_session_start", "mem_session_end",
  "mem_suggest_topic_key",
])

// ─── Health check cache ───────────────────────────────────────────────────────

let langfuseAvailable: boolean | null = null
let lastHealthCheck = 0
const HEALTH_CHECK_TTL = 30_000 // 30s

async function isLangfuseUp(): Promise<boolean> {
  const now = Date.now()
  if (langfuseAvailable !== null && now - lastHealthCheck < HEALTH_CHECK_TTL) {
    return langfuseAvailable
  }
  try {
    const res = await fetch(`${LANGFUSE_URL}/api/public/health`, {
      signal: AbortSignal.timeout(1000),
    })
    langfuseAvailable = res.ok
  } catch {
    langfuseAvailable = false
  }
  lastHealthCheck = now
  return langfuseAvailable
}

// ─── Span ingestion ───────────────────────────────────────────────────────────

async function sendSpan(opts: {
  traceId: string
  spanId: string
  toolName: string
  input: unknown
  output: unknown
  startTime: string
  endTime: string
  userId?: string
}): Promise<void> {
  if (!(await isLangfuseUp())) return

  const body = {
    batch: [
      {
        id: `tr-${opts.traceId}`,
        type: "trace-create",
        timestamp: opts.startTime,
        body: {
          id: opts.traceId,
          name: `session:${opts.traceId.slice(0, 8)}`,
          userId: opts.userId ?? "opencode",
          tags: ["opencode"],
        },
      },
      {
        id: opts.spanId,
        type: "span-create",
        timestamp: opts.startTime,
        body: {
          id: opts.spanId,
          traceId: opts.traceId,
          name: opts.toolName,
          startTime: opts.startTime,
          endTime: opts.endTime,
          input: opts.input,
          // Truncate large outputs
          output: JSON.stringify(opts.output).length > 2000
            ? { truncated: true, preview: JSON.stringify(opts.output).slice(0, 500) }
            : opts.output,
          metadata: { tool: opts.toolName, source: "opencode" },
        },
      },
    ],
  }

  await fetch(`${LANGFUSE_URL}/api/public/ingestion`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${AUTH}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(3000),
  }).catch(() => {}) // never throw
}

// ─── Plugin export ────────────────────────────────────────────────────────────

export const LangfuseTracer: Plugin = {
  name: "langfuse-tracer",

  hooks: {
    "tool:after": async (input) => {
      const toolName: string = (input as any).tool ?? (input as any).toolName ?? "unknown"

      // Skip internal/noisy tools
      if (SKIP_TOOLS.has(toolName)) return

      const sessionId: string = (input as any).sessionID ?? (input as any).session_id ?? "no-session"
      const startTime: string = (input as any).startTime ?? new Date().toISOString()
      const endTime = new Date().toISOString()
      const spanId = `sp-${sessionId.slice(0, 8)}-${toolName}-${Date.now()}`

      await sendSpan({
        traceId: sessionId,
        spanId,
        toolName,
        input: (input as any).input ?? (input as any).tool_input ?? {},
        output: (input as any).output ?? (input as any).tool_response ?? {},
        startTime,
        endTime,
        userId: "opencode",
      })
    },
  },
}

export default LangfuseTracer
