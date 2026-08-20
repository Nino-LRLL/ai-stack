<div align="center">

# ⚡ ai-stack

### Ton écosystème IA de codage **100 % local**, en **UNE commande**.

*Zéro cloud · Zéro clé API · Zéro abonnement · Zéro `~/.bashrc` à bidouiller.*

[![Windows](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)]()
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=black)]()
[![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)]()
[![MIT](https://img.shields.io/badge/Licence-MIT-blue.svg?style=flat-square)]()
[![100% local](https://img.shields.io/badge/100%25-local-34d868?style=flat-square)]()
[![Sans clé](https://img.shields.io/badge/Aucune%20cl%C3%A9%20requise-58a6ff?style=flat-square)]()

</div>

---

## 🎬 Ça donne quoi ?

```text
$ bash install.sh

═══════════════════════════════════════════════════════════════
  ai-stack · écosystème IA de codage local — une commande
═══════════════════════════════════════════════════════════════

  Matériel détecté :
  ✓ OS : windows (x86_64)
  ✓ RAM : 8 Go
  ✓ GPU : intel
  ✓ Ollama : installé — serveur oui
  Modèles recommandés pour 8 Go : smollm2:1.7b qwen2.5:3b qwen2.5-coder:3b

── 1/4 · Ollama (moteur de modèles local) ────────────────────
  ✓ Ollama déjà installé : ollama version is 0.32.13

── 2/4 · Modèles adaptés à ta RAM (8 Go) ─────────────────────
  ✓ modèle qwen2.5-coder:3b déjà présent
  ✓ modèle qwen2.5:3b déjà présent

── 3/4 · Agents de codage branchés sur le local ──────────────
  ✓ Claude Code → Ollama local (settings.json mis à jour)
  ✓ OpenCode → petit modèle local (compaction active)
  ✓ Jcode → Ollama local (config.toml créé)

── 4/4 · Hook git anti-secrets (règle absolue) ───────────────
  ✓ hook pre-push anti-secrets installé dans ce repo

═══════════════════════════════════════════════════════════════
  Rapport final ai-stack
═══════════════════════════════════════════════════════════════
  ✓ Ollama : ollama version is 0.32.13 — serveur oui
  ✓ Modèles locaux : 3
    - qwen2.5:3b
    - qwen2.5-coder:3b
    - smollm2:1.7b
  ✓ Claude Code → local
  ✓ OpenCode → local
  ✓ Jcode → local

  Prêt. Ton IA de codage tourne 100 % local — sans clé, sans cloud.
```

## 🚀 Installation

**Une seule commande.** Ça détecte ton matériel, ça installe, ça configure, ça valide.

```bash
# Linux / macOS / Git Bash (Windows)
git clone https://github.com/Nino-LRLL/ai-stack.git && cd ai-stack
bash install.sh
```

Windows ? Double-clic sur **`install.bat`** — ou la même commande dans Git Bash.

```bash
bash install.sh --dry    # affiche le plan sans rien modifier
bash install.sh --force  # re-configure même si déjà présent
```

## 🧠 Pourquoi ?

Tu passes **2 heures** à configurer ton environnement IA de codage :
installer Ollama, choisir les bons modèles pour ta RAM, brancher Claude Code
sur le local, configurer OpenCode, Jcode… et oublier une clé API dans un
repo public par-dessus le marché.

**ai-stack fait tout ça en une commande** — avec détection matérielle réelle
(une machine à 8 Go ne reçoit pas les modèles d'une machine à 32 Go), et un
**hook anti-secrets** intégré pour que tu ne pousses jamais une clé.

## 📦 Ce que ça installe

| Brique | Rôle | Détection réelle |
|---|---|---|
| **Ollama** | Moteur de modèles local (llama3, qwen, etc.) | ✓ version + serveur |
| **Modèles** | Choisis selon ta **RAM réelle** (8→64 Go) | ✓ `ollama list` |
| **Claude Code** | Branché sur `127.0.0.1:11434` | ✓ `settings.json` |
| **OpenCode** | Petit modèle local pour compaction | ✓ `opencode.json` |
| **Jcode** | Harness Rust → Ollama | ✓ `config.toml` |
| **Hook anti-secrets** | Bloque tout push contenant une clé | ✓ `git pre-push` |

## 🔍 Modèles recommandés (selon RAM réelle)

| RAM | Modèles |
|---|---|
| 8 Go | `smollm2:1.7b` · `qwen2.5:3b` · `qwen2.5-coder:3b` |
| 12-16 Go | + `gemma3:4b` |
| 16-24 Go | `qwen2.5:7b` · `qwen2.5-coder:7b` |
| 32 Go+ | `qwen2.5:14b` · `qwen2.5-coder:14b` |

*Recommandation déterministe — jamais un modèle qui fait exploser ta RAM.*

## ⚖️ Honnête ?

**Oui, par design.** Chaque étape vérifie l'état réel :
- RAM/GPU lus sur le système (pas devinés) ;
- `ollama list` pour les modèles (pas supposés) ;
- `settings.json` / `opencode.json` / `config.toml` écrits seulement s'ils
  manquent (jamais écrasés sans `--force`) ;
- échec d'installation → message clair avec la commande officielle, jamais
  un faux succès.

## 🛡️ Sécurité (règle absolue)

`install.sh` installe un **hook git pre-push** qui scanne chaque push :
`ghp_` (GitHub), `sk-` (OpenAI), `AKIA` (AWS), clés privées, Notion,
Stripe, Google, xAI, HuggingFace… **Le push est refusé** si une clé est
détectée. Les placeholders légitimes (`${{ secrets.X }}`, noms de
variables) passent sans problème.

## 🗺️ Roadmap

- [x] Détection matérielle réelle (RAM/GPU/plateforme)
- [x] Ollama + modèles adaptés à la RAM
- [x] Config Claude Code / OpenCode / Jcode sur le local
- [x] Hook anti-secrets
- [x] Windows (Git Bash) + Linux + macOS
- [ ] `ai-stack doctor` — diagnostic complet en une commande
- [ ] Intégration MCP (pont Ollama ↔ serveurs MCP)
- [ ] Profils (coding / study / gaming) par type de RAM

## 📄 Licence

[MIT](LICENSE) — libre, gratuit, sans condition.

---

<div align="center">

**⭐ Si ce projet t'a fait gagner du temps : mets une étoile.**

*ai-stack — ton IA de codage, chez toi. Pas dans un cloud.*

</div>
