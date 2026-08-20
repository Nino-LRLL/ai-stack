#!/usr/bin/env bash
# ai-stack · scan-secrets.sh — bloque tout push contenant une clé API.
# Usage: installé comme hook git pre-push (ou lancé manuellement).
# Exit 0 = propre, 1 = secret détecté (push refusé).

set -u

PATTERNS=(
  'gh[pousr]_[A-Za-z0-9]{20,}'
  'sk-[A-Za-z0-9]{20,}'
  'AKIA[0-9A-Z]{16}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  '-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----'
  'AIza[0-9A-Za-z_-]{30,}'
  'notion_[A-Za-z0-9]{20,}'
  'sk_live_[0-9a-zA-Z]{20,}'
  'xai-[A-Za-z0-9]{20,}'
  'hf_[A-Za-z0-9]{20,}'
)
IGNORE='secrets\.|GITHUB_TOKEN|NOTION_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY|API_KEY|environment|exemple|example|xxx|YOUR_|<|>'

PATTERN_RE="$(IFS='|'; echo "${PATTERNS[*]}")"
found=0

FILES=$(git diff --cached --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
FILES=$(echo "$FILES" | sort -u)

if [ -z "$FILES" ]; then
  echo "scan-secrets: rien à vérifier — OK"
  exit 0
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  case "$f" in
    *.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.zip|*.exe|*.dll|*.apkg|*.onnx|*.lock) continue ;;
    .venv/*|node_modules/*|.git/*|target/*|build/*|dist/*) continue ;;
  esac
  m=$(grep -nE "$PATTERN_RE" "$f" 2>/dev/null | grep -vE "$IGNORE")
  if [ -n "$m" ]; then
    echo "⛔ SECRET détecté dans $f :"
    echo "$m" | head -5
    found=1
  fi
done <<< "$FILES"

if [ "$found" -eq 1 ]; then
  echo ""
  echo "⛔ Push REFUSÉ : une clé API / un secret est en attente d'indexation."
  echo "   Retire-le du commit AVANT de pousser. Règle absolue : jamais de"
  echo "   secret dans un repo public."
  exit 1
fi

echo "scan-secrets: aucun secret détecté — OK"
exit 0
