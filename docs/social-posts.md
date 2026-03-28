# Social Media Posts — AI Agent Stack

Usuario GitHub: **DavidBritto**

---

## REDDIT — r/ClaudeAI · r/LocalLLaMA · r/selfhosted

**Título:**
```
[Open Source] AI Agent Stack — 6 new skills + full observability for Claude Code & OpenCode
```

**Cuerpo:**
```
I built an open-source stack that adds what I think Claude Code and OpenCode are missing:

**6 new agent skills:**
- `sdd-eval` — auto-scores your implementation 0-100 against the spec, loops back if score < 80
- `budget-guard` — warns at 80%, hard-stops at 100% of your session budget
- `worktree-agent` — every sub-agent gets its own git branch, changes auto-become PRs
- `model-tournament` — run same task on 2 models in parallel, LLM judges the winner
- `ci-watcher` — GitHub Actions fails → agent reads logs, fixes it, opens PR automatically
- `rag-search` — semantic search over your codebase (Qdrant + Ollama, 100% local)

**Full self-hosted observability:**
- Langfuse (traces every tool call)
- Qdrant (vector DB)
- Redis + NATS
- All via Docker Compose, no cloud required

Works with both Claude Code and OpenCode. One command install.

GitHub: https://github.com/DavidBritto/ai-agent-stack

Happy to answer questions about any of the components.
```

---

## TWITTER / X

```
Just open-sourced my AI agent stack 🧵

6 new skills for Claude Code + OpenCode:
• auto-eval loop (scores impl 0-100, re-runs if < 80)
• budget guard (hard-stops at 100% of session limit)
• git worktree isolation per agent
• model tournament (2 models in parallel, LLM judges)
• self-healing CI (reads logs, fixes, opens PR)
• semantic code search (local, no API key)

+ Langfuse, Qdrant, Redis, NATS — all self-hosted

github.com/DavidBritto/ai-agent-stack

#ClaudeCode #OpenCode #AI #OpenSource
```

---

## HACKER NEWS — Show HN

**Título:**
```
Show HN: AI Agent Stack – self-hosted observability and 6 new skills for Claude Code
```

**Cuerpo:**
```
I've been using Claude Code heavily and kept hitting the same gaps: no visibility
into what agents are doing, no cost control, agents clobbering each other's work.
This project fills those gaps.

What it adds:
- Langfuse self-hosted: every tool call is a traced span, costs visible per session
- RAG over your codebase via Qdrant + Ollama (local embeddings, no API key)
- sdd-eval: scores implementation against spec 0-100, auto-loops if below threshold
- budget-guard: pre-tool hook that hard-stops at your session budget limit
- worktree-agent: each coding sub-agent gets its own git branch, auto-creates PRs
- model-tournament: run same task on two models in parallel, LLM-as-judge picks winner
- ci-watcher: reads GitHub Actions failure logs, fixes root cause, opens PR

All services run locally via Docker Compose. Compatible with Claude Code (bash hooks)
and OpenCode (TypeScript plugin). One-command install.

https://github.com/DavidBritto/ai-agent-stack
```

---

## DISCORD — servidores de OpenCode / Claude Code / AI

```
hey, just released something that might be useful here 👋

**ai-agent-stack** — adds 6 skills + full observability to Claude Code and OpenCode

the main things it solves:
→ you can't see what your agents are actually doing (Langfuse fixes this)
→ sessions can get expensive with no warning (budget-guard fixes this)
→ multiple agents overwriting each other (worktree-agent fixes this)
→ "does this even implement the spec?" (sdd-eval scores it 0-100 and re-loops if needed)
→ CI fails at 2am (ci-watcher reads logs and opens a fix PR automatically)

100% self-hosted, works with both Claude Code and OpenCode, one-command install

https://github.com/DavidBritto/ai-agent-stack

lmk if you run into anything
```

---

## LINKEDIN

```
Acabo de publicar AI Agent Stack en GitHub — un stack open-source que añade
observabilidad completa y 6 nuevos protocolos de agentes para Claude Code y OpenCode.

El problema que resuelve: cuando usás agentes de IA intensivamente, no tenés
visibilidad de lo que hacen, los costos se van de control, y múltiples agentes
pueden pisarse entre sí.

Lo que incluye:
→ Langfuse self-hosted: cada tool call trazada, costos por sesión visibles
→ RAG semántico sobre tu codebase (Qdrant + Ollama, 100% local)
→ sdd-eval: puntúa la implementación 0-100 contra el spec, re-ejecuta si es < 80
→ budget-guard: hook que para todo al llegar al límite de presupuesto
→ worktree-agent: cada sub-agente trabaja en su propio branch, crea PR automático
→ model-tournament: compara dos modelos en paralelo, LLM elige el ganador
→ ci-watcher: CI roto → lee logs → arregla → abre PR. Solo.

Todo corre local con Docker Compose. Compatible con Claude Code y OpenCode.
Instalación en un comando.

https://github.com/DavidBritto/ai-agent-stack

#AI #OpenSource #ClaudeCode #DevTools #SelfHosted
```

---

## ORDEN RECOMENDADO DE PUBLICACIÓN

1. GitHub (ya hecho ✅)
2. Reddit r/ClaudeAI — mayor audiencia inmediata
3. Reddit r/LocalLLaMA — comunidad self-hosted
4. Twitter/X — para distribución rápida
5. Discord de OpenCode + Claude Code
6. Reddit r/selfhosted
7. Hacker News Show HN — mayor impacto pero más exigente
8. LinkedIn — más tardío, audiencia diferente
