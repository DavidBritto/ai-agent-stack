#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# ai-agent-stack — One-command installer
# Installs skills, hooks, scripts, and config for Claude Code + OpenCode
# ─────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[done]${NC} $1"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $1"; }

echo ""
echo "  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗"
echo "  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝"
echo "  ██████╔╝██║     ███████║██║     █████╔╝ "
echo "  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ "
echo "  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗"
echo "  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
echo "  AI Agent Stack — installer"
echo ""

# ── 1. Skills ─────────────────────────────────────────────────
info "Installing skills..."
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$REPO_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  target="$CLAUDE_DIR/skills/$skill_name"
  if [ -d "$target" ]; then
    warn "Skill '$skill_name' already exists — skipping (delete manually to reinstall)"
  else
    cp -r "$skill_dir" "$target"
    success "Skill: $skill_name"
  fi
done

# Symlink to OpenCode if installed
if [ -d "$OPENCODE_DIR/skills" ]; then
  for skill_dir in "$REPO_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    ln -sf "$CLAUDE_DIR/skills/$skill_name" "$OPENCODE_DIR/skills/$skill_name" 2>/dev/null
  done
  success "Skills symlinked to OpenCode"
fi

# ── 2. Hooks ──────────────────────────────────────────────────
info "Installing hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "$REPO_DIR/hooks"/*.sh; do
  name=$(basename "$hook")
  cp "$hook" "$CLAUDE_DIR/hooks/$name"
  chmod +x "$CLAUDE_DIR/hooks/$name"
  success "Hook: $name"
done

# ── 3. Scripts ────────────────────────────────────────────────
info "Installing scripts..."
mkdir -p "$CLAUDE_DIR/scripts"
for script in "$REPO_DIR/scripts"/*.sh; do
  name=$(basename "$script")
  cp "$script" "$CLAUDE_DIR/scripts/$name"
  chmod +x "$CLAUDE_DIR/scripts/$name"
  success "Script: $name"
done

# ── 4. Infrastructure ─────────────────────────────────────────
info "Setting up infrastructure config..."
mkdir -p "$CLAUDE_DIR/infra"

cp "$REPO_DIR/infra/docker-compose.yml" "$CLAUDE_DIR/infra/docker-compose.yml"
success "docker-compose.yml installed"

if [ ! -f "$CLAUDE_DIR/infra/.env" ]; then
  cp "$REPO_DIR/infra/.env.example" "$CLAUDE_DIR/infra/.env"
  # Auto-generate secrets
  if command -v openssl > /dev/null 2>&1; then
    SECRET=$(openssl rand -hex 32)
    SALT=$(openssl rand -hex 16)
    sed -i "s/replace-with-openssl-rand-hex-32/$SECRET/" "$CLAUDE_DIR/infra/.env"
    sed -i "s/replace-with-openssl-rand-hex-16/$SALT/" "$CLAUDE_DIR/infra/.env"
    success ".env created with auto-generated secrets"
  else
    warn ".env created from template — manually set LANGFUSE_NEXTAUTH_SECRET and LANGFUSE_SALT"
  fi
else
  warn ".env already exists — skipping (secrets preserved)"
fi

# ── 5. Config ─────────────────────────────────────────────────
info "Installing config..."
mkdir -p "$CLAUDE_DIR/config"
[ ! -f "$CLAUDE_DIR/config/budget.json" ] && \
  cp "$REPO_DIR/config/budget.example.json" "$CLAUDE_DIR/config/budget.json" && \
  success "budget.json created"

[ ! -f "$CLAUDE_DIR/config/model-stats.json" ] && \
  echo '{"models":["claude-sonnet-4-6","claude-haiku-4-5-20251001"],"stats":{},"last_updated":""}' \
  > "$CLAUDE_DIR/config/model-stats.json" && \
  success "model-stats.json created"

# ── 6. OpenCode plugin ────────────────────────────────────────
if [ -d "$OPENCODE_DIR/plugins" ]; then
  info "Installing OpenCode plugin..."
  cp "$REPO_DIR/opencode/plugins/langfuse-tracer.ts" "$OPENCODE_DIR/plugins/langfuse-tracer.ts"
  success "langfuse-tracer.ts installed for OpenCode"
fi

# ── 7. Register hooks in settings.json ───────────────────────
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
  if ! grep -q "langfuse-tracer" "$SETTINGS" 2>/dev/null; then
    warn "Add these hooks to $SETTINGS manually (see README → Hook Registration)"
  else
    success "Hooks already registered in settings.json"
  fi
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation complete!"
echo ""
echo "  Next steps:"
echo "  1. Start infrastructure:"
echo "     docker compose -f ~/.claude/infra/docker-compose.yml up -d"
echo ""
echo "  2. Install Ollama + embeddings:"
echo "     ollama pull nomic-embed-text"
echo ""
echo "  3. Open Langfuse dashboard:"
echo "     http://localhost:3001  (admin@local.dev / admin1234)"
echo ""
echo "  4. Index your first project:"
echo "     ~/.claude/scripts/rag-index.sh ~/git/my-project my-project"
echo ""
echo "  Full docs: README.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
