#!/usr/bin/env python3
"""Génère le GIF de démo d'ai-stack.

Rejoue le VRAI output de `bash install.sh --dry` dans un terminal stylisé
(typing effect caractère par caractère + curseur clignotant), puis exporte
un GIF animé.

Usage:
    python scripts/make_demo_gif.py [--fps 20] [--out demo.gif]
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Polices monospace : Consolas (Windows), sinon repli Pillow.
# ---------------------------------------------------------------------------
def find_font(size: int):
    for path in [
        r"C:\Windows\Fonts\consola.ttf",
        r"C:\Windows\Fonts\CascadiaMono.ttf",
        r"C:\Windows\Fonts\cour.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ]:
        if Path(path).is_file():
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()

# Palette (sombre, style terminal moderne GitHub dark).
BG        = (13, 17, 23)
FG        = (201, 209, 217)
GREEN     = (63, 185, 80)
CYAN      = (88, 166, 255)
YELLOW    = (210, 153, 34)
RED       = (248, 81, 73)
DIM       = (110, 118, 129)
CURSOR    = (88, 166, 255)
TITLE_BAR = (22, 27, 34)
DOT_RED   = (248, 81, 73)
DOT_YEL   = (255, 184, 108)
DOT_GRN   = (63, 185, 80)

TITLE_ROW_H = 34


def ansi_strip(line: str) -> str:
    """Retire les codes ANSI (couleurs de install.sh)."""
    return re.sub(r"\x1b\[[0-9;]*m", "", line).replace("\x1b", "")


def run_script(repo_root: Path) -> list[str]:
    """Exécute install.sh --dry et retourne les lignes de sortie réelles."""
    proc = subprocess.run(
        ["bash", "install.sh", "--dry"],
        cwd=str(repo_root),
        capture_output=True, text=True, timeout=60,
        encoding="utf-8", errors="replace",
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    lines = []
    for raw in out.splitlines():
        line = ansi_strip(raw).rstrip()
        if line.strip():
            lines.append(line)
    return lines


def colorize(line: str) -> str:
    """Couleur d'une ligne selon son contenu (heuristique simple)."""
    s = line.strip()
    if s.startswith("✓"):
        return GREEN
    if s.startswith("⚠") or "Mode --dry" in s or "introuvable" in s:
        return YELLOW
    if s.startswith("✗") or "échec" in s:
        return RED
    if s.startswith("──") or s.startswith("═"):
        return CYAN
    if ("Matériel détecté" in s or "Rapport final" in s
            or s.startswith("ai-stack")):
        return CYAN
    return FG


def make_frames(lines: list[str], font, width: int, height: int,
                pad: int, mono_h: int, fps: int) -> list[Image.Image]:
    """Construit les frames du GIF (frappe caractère par caractère)."""
    col_w = font.getbbox("M")[2] or 9
    img = Image.new("RGB", (width, height), BG)

    # Séquence complète (char, couleur) avec retours à la ligne réels.
    seq: list[tuple[str, tuple]] = []
    for line in lines:
        color = colorize(line)
        for ch in line:
            seq.append((ch, color))
        seq.append(("\n", FG))

    def render_at(position: int) -> Image.Image:
        visible = seq[:position]
        f = img.copy()
        d = ImageDraw.Draw(f)
        d.rectangle([0, 0, width, height], fill=BG)
        d.rectangle([0, 0, width, TITLE_ROW_H], fill=TITLE_BAR)
        for i, (cx, cy) in enumerate([(18, 17), (36, 17), (54, 17)]):
            c = DOT_RED if i == 0 else (DOT_YEL if i == 1 else DOT_GRN)
            d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=c)
        d.text((78, 8), "ai-stack — bash install.sh", font=font, fill=DIM)

        y = TITLE_ROW_H + pad
        buf = ""
        buf_color = FG
        last_color = FG

        def flush() -> None:
            nonlocal buf, buf_color
            if buf:
                d.text((pad, y), buf, font=font, fill=buf_color)
            buf = ""
            buf_color = FG

        for ch, color in visible:
            if ch == "\n":
                flush()
                y += mono_h
                continue
            if buf and d.textlength(buf, font=font) + col_w > width - pad * 2:
                flush()
                y += mono_h
            buf += ch
            buf_color = color
        flush()

        # Curseur à la position courante (si texte restant).
        if position < len(seq):
            cy = y + mono_h - 7
            cx = pad + (d.textlength(buf, font=font) if buf else 0)
            d.rectangle([cx, cy, cx + 10, cy + 4], fill=CURSOR)
        return f

    # Positions de frappe (échantillonnées pour garder le GIF < 1 Mo).
    total = len(seq)
    max_frames = 200
    if total > 0:
        step = max(1, total // max_frames)
        positions = list(range(0, total, step))
        if positions[-1] != total:
            positions.append(total)
    else:
        positions = []

    frames = [render_at(p) for p in positions]

    # Pause finale : curseur clignotant 4×.
    last = frames[-1]
    for i in range(4):
        frames.append(last.copy())
        blink = last.copy()
        d2 = ImageDraw.Draw(blink)
        # Efface le curseur de la copie (fond sur la zone curseur).
        # Simple : on re-rend sans curseur via position == total.
        frames.append(render_at(total))
    return frames


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--out", default="demo.gif")
    ap.add_argument("--width", type=int, default=860)
    ap.add_argument("--font-size", type=int, default=15)
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    lines = run_script(repo_root)
    if not lines:
        print("ERREUR : aucune sortie capturée de install.sh --dry",
              file=sys.stderr)
        return 1

    font = find_font(args.font_size)
    mono_h = 22
    pad = 22
    height = TITLE_ROW_H + pad * 2 + mono_h * min(len(lines) + 1, 26)

    frames = make_frames(lines, font, args.width, height, pad, mono_h, args.fps)
    delay_ms = max(1, int(1000 / args.fps))

    out = repo_root / args.out
    frames[0].save(
        out, save_all=True, append_images=frames[1:], duration=delay_ms,
        loop=0, optimize=True,
    )
    duration_s = len(frames) * delay_ms / 1000
    print(f"GIF genere : {out} ({len(frames)} frames, "
          f"{out.stat().st_size // 1024} Ko, ~{duration_s:.1f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
