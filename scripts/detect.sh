#!/usr/bin/env bash
# ai-stack — détection matérielle réelle (RAM, CPU, GPU, plateforme).
# Usage: source scripts/detect.sh   (définit les variables AI_STACK_*)
# Ne lève jamais : chaque valeur a un repli « inconnu » honnête.

detect_platform() {
  case "$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
    linux*)  AI_STACK_OS="linux" ;;
    darwin*) AI_STACK_OS="macos" ;;
    msys*|mingw*|cygwin*) AI_STACK_OS="windows" ;;
    *)       AI_STACK_OS="unknown" ;;
  esac
  # Architecture CPU (x86_64 / arm64 / armv7...)
  AI_STACK_ARCH="$(uname -m 2>/dev/null || echo 'inconnu')"
}

detect_ram_gb() {
  local ram=0
  if [ "$AI_STACK_OS" = "linux" ] && [ -r /proc/meminfo ]; then
    ram=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null)
  elif [ "$AI_STACK_OS" = "macos" ]; then
    ram=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $1/1024/1024/1024}')
  elif [ "$AI_STACK_OS" = "windows" ]; then
    # wmic est déprécié mais présent partout ; repli powershell.
    ram=$(wmic ComputerSystem get TotalPhysicalMemory //value 2>/dev/null | \
          grep -i '=' | cut -d= -f2 | awk '{printf "%.0f", $1/1024/1024/1024}')
    if [ -z "$ram" ] || [ "$ram" = "0" ]; then
      ram=$(powershell -NoProfile -Command \
        '[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)' 2>/dev/null)
    fi
  fi
  [ "$ram" -lt 1 ] 2>/dev/null && ram=""
  AI_STACK_RAM_GB="${ram:-inconnu}"
}

detect_gpu() {
  local vendor="inconnu"
  if [ "$AI_STACK_OS" = "linux" ]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
      vendor="nvidia"
      AI_STACK_GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    elif lspci 2>/dev/null | grep -qi "vga.*amd\|advanced micro"; then
      vendor="amd"
    elif lspci 2>/dev/null | grep -qi "intel.*vga\|intel.*graphic"; then
      vendor="intel"
    fi
  elif [ "$AI_STACK_OS" = "macos" ]; then
    # Apple Silicon vs Intel (Metal disponible partout sur macOS moderne).
    if [ "$AI_STACK_ARCH" = "arm64" ]; then vendor="apple-silicon"; else vendor="intel"; fi
  elif [ "$AI_STACK_OS" = "windows" ]; then
    if wmic path win32_VideoController get name //value 2>/dev/null | grep -qi "nvidia"; then
      vendor="nvidia"
    elif wmic path win32_VideoController get name //value 2>/dev/null | grep -qi "radeon\|amd"; then
      vendor="amd"
    elif wmic path win32_VideoController get name //value 2>/dev/null | grep -qi "intel"; then
      vendor="intel"
    fi
  fi
  AI_STACK_GPU="$vendor"
  AI_STACK_GPU_VRAM="${AI_STACK_GPU_VRAM:-inconnu}"
}

detect_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    AI_STACK_OLLAMA="installé"
    AI_STACK_OLLAMA_VER="$(ollama --version 2>/dev/null | head -1)"
  else
    AI_STACK_OLLAMA="absent"
    AI_STACK_OLLAMA_VER=""
  fi
  # Serveur joignable ?
  if curl -s -m 3 -o /dev/null http://127.0.0.1:11434/api/tags 2>/dev/null; then
    AI_STACK_OLLAMA_UP="oui"
  else
    AI_STACK_OLLAMA_UP="non"
  fi
}

# Recommandation de modèles selon la RAM réelle (8/12/16/32/64 Go).
recommend_models() {
  local ram="$AI_STACK_RAM_GB"
  case "$ram" in
    8|9)   AI_STACK_MODELS="smollm2:1.7b qwen2.5:3b qwen2.5-coder:3b" ;;
    10|11|12|13|14|15) AI_STACK_MODELS="smollm2:1.7b qwen2.5:3b qwen2.5-coder:3b gemma3:4b" ;;
    16|17|18|19|20|21|22|23) AI_STACK_MODELS="qwen2.5:7b qwen2.5-coder:7b gemma3:4b" ;;
    24|25|26|27|28|29|30|31|32) AI_STACK_MODELS="qwen2.5:14b qwen2.5-coder:14b" ;;
    *)     AI_STACK_MODELS="qwen2.5:3b" ;;  # inconnu → prudent
  esac
}

detect_all() {
  detect_platform
  detect_ram_gb
  detect_gpu
  detect_ollama
  recommend_models
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  # Exécution directe : affiche un rapport lisible.
  detect_all
  echo "===== ai-stack · détection matérielle ====="
  echo "OS          : $AI_STACK_OS ($AI_STACK_ARCH)"
  echo "RAM         : ${AI_STACK_RAM_GB} Go"
  echo "GPU         : $AI_STACK_GPU (VRAM: ${AI_STACK_GPU_VRAM})"
  echo "Ollama      : $AI_STACK_OLLAMA ($AI_STACK_OLLAMA_VER) — serveur: $AI_STACK_OLLAMA_UP"
  echo "Modèles rec.: $AI_STACK_MODELS"
  echo "==========================================="
fi
