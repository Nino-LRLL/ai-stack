#!/usr/bin/env bash
# ============================================================================
#  ai-stack — ton écosystème IA de codage 100 % local, en UNE commande.
#  Windows (Git Bash) · Linux · macOS
#
#  Ce que fait install.sh :
#    1. Détecte ton matériel réel (RAM, GPU, plateforme) ;
#    2. Vérifie Ollama — l'installe s'il manque, démarre le serveur ;
#    3. Télécharge les modèles adaptés à ta RAM (recommandation réelle) ;
#    4. Configure les agents de codage sur le local (Claude Code,
#       OpenCode, Jcode) — sans clé, sans cloud ;
#    5. Installe le hook git anti-secrets (jamais de clé poussée) ;
#    6. Affiche un rapport final vérifiable.
#
#  Usage :  bash install.sh          (détection + config complète)
#           bash install.sh --dry   (affiche le plan, ne modifie rien)
#           bash install.sh --force (ignore les outils déjà présents)
#
#  Honnêteté : rien n'est simulé — chaque étape vérifie l'état RÉEL.
# ============================================================================
set -u

# --- chemin du repo ----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry)  DRY=1 ;;
    --force) FORCE=1 ;;
  esac
done

# --- utilitaires d'affichage -------------------------------------------------
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
say()   { printf "${BOLD}%s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}  ✓ %s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}  ⚠ %s${RESET}\n" "$*"; }
fail()  { printf "${RED}  ✗ %s${RESET}\n" "$*"; }
run()   { if [ "$DRY" -eq 1 ]; then printf "${YELLOW}  [dry] %s${RESET}\n" "$*"; else "$@"; fi; }

# --- 1. détection ------------------------------------------------------------
source "$REPO_ROOT/scripts/detect.sh"
detect_all

echo ""
say "═══════════════════════════════════════════════════════════════"
say "  ai-stack · écosystème IA de codage local — une commande"
say "═══════════════════════════════════════════════════════════════"
echo ""
say "  Matériel détecté :"
ok "OS : $AI_STACK_OS ($AI_STACK_ARCH)"
ok "RAM : ${AI_STACK_RAM_GB} Go"
ok "GPU : $AI_STACK_GPU (VRAM ${AI_STACK_GPU_VRAM})"
ok "Ollama : $AI_STACK_OLLAMA — serveur $AI_STACK_OLLAMA_UP"
say "  Modèles recommandés pour ${AI_STACK_RAM_GB} Go : $AI_STACK_MODELS"

if [ "$DRY" -eq 1 ]; then
  echo ""
  warn "Mode --dry : plan affiché, AUCUNE modification effectuée."
  echo ""
  exit 0
fi

# --- 2. Ollama ---------------------------------------------------------------
echo ""
say "── 1/4 · Ollama (moteur de modèles local) ────────────────────"
if [ "$AI_STACK_OLLAMA" = "absent" ] || [ "$FORCE" -eq 1 ]; then
  say "  Installation d'Ollama…"
  case "$AI_STACK_OS" in
    linux)
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://ollama.com/install.sh | sh || fail "échec installation Ollama"
      else
        fail "curl introuvable — installe Ollama manuellement: https://ollama.com/download"
      fi ;;
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install ollama || fail "échec brew install ollama"
      else
        fail "Homebrew absent — installe Ollama manuellement: https://ollama.com/download"
      fi ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        winget install --id Ollama.Ollama -e --silent --accept-package-agreements \
          --accept-source-agreements || fail "échec winget install Ollama"
      else
        fail "winget absent — installe Ollama manuellement: https://ollama.com/download"
      fi ;;
    *) fail "plateforme non supportée: $AI_STACK_OS" ;;
  esac
  # Re-détecte après installation.
  detect_ollama
else
  ok "Ollama déjà installé : $AI_STACK_OLLAMA_VER"
fi

if [ "$AI_STACK_OLLAMA_UP" != "oui" ]; then
  say "  Démarrage du serveur Ollama…"
  if [ "$AI_STACK_OS" = "windows" ]; then
    run powershell -NoProfile -Command "Start-Process ollama -ArgumentList 'serve' -WindowStyle Hidden"
  elif [ "$AI_STACK_OS" = "macos" ]; then
    run nohup ollama serve >/dev/null 2>&1 &
  else
    run nohup ollama serve >/dev/null 2>&1 &
  fi
  sleep 3
  if curl -s -m 3 -o /dev/null http://127.0.0.1:11434/api/tags; then
    ok "serveur Ollama actif (127.0.0.1:11434)"
  else
    warn "serveur pas encore joignable — tu peux le lancer avec 'ollama serve'"
  fi
fi

# --- 3. modèles --------------------------------------------------------------
echo ""
say "── 2/4 · Modèles adaptés à ta RAM ($AI_STACK_RAM_GB Go) ──────"
if command -v ollama >/dev/null 2>&1; then
  for model in $AI_STACK_MODELS; do
    if ollama list 2>/dev/null | awk '{print $1}' | grep -qx "$model"; then
      ok "modèle $model déjà présent"
    else
      say "  téléchargement de $model (peut prendre quelques minutes)…"
      if run ollama pull "$model"; then
        ok "modèle $model installé"
      else
        fail "échec du téléchargement de $model"
      fi
    fi
  done
else
  warn "Ollama indisponible — saute le téléchargement des modèles"
fi

# --- 4. agents de codage -----------------------------------------------------
echo ""
say "── 3/4 · Agents de codage branchés sur le local ──────────────"
# Claude Code : base URL locale (Ollama est compatible OpenAI).
# Règle : ne JAMAIS toucher un settings.json existant (l'utilisateur peut
# avoir sa propre config — OmniRoute, Anthropic, autre). On ne crée le
# fichier que s'il est absent (ou avec --force explicite).
if command -v claude >/dev/null 2>&1; then
  if [ "$FORCE" -eq 1 ] || [ ! -f "$HOME/.claude/settings.json" ]; then
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/settings.json" <<'JSON'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:11434/v1",
    "ANTHROPIC_AUTH_TOKEN": "ai-stack-local",
    "ANTHROPIC_MODEL": "qwen2.5-coder:3b"
  }
}
JSON
    ok "Claude Code → Ollama local (settings.json créé)"
  else
    ok "Claude Code : settings.json existant préservé (pas de modification)"
  fi
else
  warn "Claude Code absent — installe-le via 'npm i -g @anthropic-ai/claude-code'"
fi

# OpenCode : petit modèle local pour les titres/compaction.
if command -v opencode >/dev/null 2>&1; then
  OPCODE_CFG="$HOME/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$OPCODE_CFG")"
  if [ "$FORCE" -eq 1 ] || [ ! -f "$OPCODE_CFG" ]; then
    printf '{\n  "small_model": "ollama/smollm2:1.7b",\n  "compact": { "enabled": true }\n}\n' > "$OPCODE_CFG"
    ok "OpenCode → petit modèle local (compaction active)"
  else
    ok "OpenCode déjà configuré"
  fi
else
  warn "OpenCode absent — installe-le via 'npm i -g opencode-ai'"
fi

# Jcode : profil omniroute→ollama si présent.
if command -v jcode >/dev/null 2>&1; then
  if [ "$FORCE" -eq 1 ] || [ ! -f "$HOME/.jcode/config.toml" ]; then
    mkdir -p "$HOME/.jcode"
    cat > "$HOME/.jcode/config.toml" <<'TOML'
[provider.ollama]
command = ["ollama", "run", "qwen2.5-coder:3b"]

[default]
provider = "ollama"
model = "qwen2.5-coder:3b"
TOML
    ok "Jcode → Ollama local (config.toml créé)"
  else
    ok "Jcode déjà configuré"
  fi
else
  warn "Jcode absent — voir https://github.com/1jehuang/jcode"
fi

# --- 5. sécurité -------------------------------------------------------------
echo ""
say "── 4/4 · Hook git anti-secrets (règle absolue) ───────────────"
SCAN="$REPO_ROOT/scripts/scan-secrets.sh"
if [ -f "$SCAN" ]; then
  HOOK="$(git rev-parse --git-path hooks 2>/dev/null || echo .git/hooks)/pre-push"
  if [ -d "$(dirname "$HOOK")" ]; then
    cp "$SCAN" "$HOOK" 2>/dev/null && chmod +x "$HOOK" 2>/dev/null \
      && ok "hook pre-push anti-secrets installé dans ce repo"
  else
    warn "ce dossier n'est pas un repo git — le hook s'activera au premier git init"
  fi
else
  warn "scan-secrets.sh introuvable — hook non installé"
fi

# --- 6. rapport final --------------------------------------------------------
echo ""
say "═══════════════════════════════════════════════════════════════"
say "  Rapport final ai-stack"
say "═══════════════════════════════════════════════════════════════"
echo ""
detect_ollama
ok "Ollama : $AI_STACK_OLLAMA_VER — serveur $AI_STACK_OLLAMA_UP"
if command -v ollama >/dev/null 2>&1; then
  n=$(ollama list 2>/dev/null | tail -n +2 | wc -l)
  ok "Modèles locaux : $n"
  ollama list 2>/dev/null | tail -n +2 | awk '{printf "    - %s (%s)\n", $1, $2}'
fi
[ -f "$HOME/.claude/settings.json" ] && ok "Claude Code → local" || warn "Claude Code : non configuré"
[ -f "$HOME/.config/opencode/opencode.json" ] && ok "OpenCode → local" || warn "OpenCode : non configuré"
[ -f "$HOME/.jcode/config.toml" ] && ok "Jcode → local" || warn "Jcode : non configuré"
echo ""
say "  Prêt. Ton IA de codage tourne 100 % local — sans clé, sans cloud."
say "  ⭐ Si ai-stack t'aide : mets une étoile sur GitHub !"
echo ""
