#!/usr/bin/env bash
# Pixel & Rank Bild-Standard (tun-sein-ergotherapie)
#
# Erzeugt aus jedem Quellbild in assets/photos/<gruppe>/ responsive Varianten
# in WebP UND AVIF unter assets/photos/<gruppe>/generated/.
#
# Standard:
#   - Breiten: 480 / 800 / 1200 / 1600 px + native Breite (Schritte >= Quellbreite
#     werden übersprungen, nie Upscaling)
#   - WebP:  libwebp,    -quality 78, -compression_level 6
#   - AVIF:  libaom-av1, -crf 30, -cpu-used 6, yuv420p, still-picture
#   - Budget: jede einzelne Datei < 200 KB (harter Check, sonst Abbruch)
#
# usage: scripts/optimize-images.sh [QUELL_VERZEICHNIS] [AUSGABE_VERZEICHNIS]
#   Default: assets/photos/praxis -> assets/photos/praxis/generated
#
# Neue Bilder: Datei (webp/jpg/png) ins Quellverzeichnis legen, Script starten.
# Bereits erzeugte Varianten, die neuer als die Quelle sind, werden übersprungen.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${1:-$REPO_ROOT/assets/photos/praxis}"
OUT_DIR="${2:-$SRC_DIR/generated}"

WIDTHS=(480 800 1200 1600)
WEBP_QUALITY=78
AVIF_CRF=30
MAX_KB=200

command -v ffmpeg  >/dev/null 2>&1 || { echo "FEHLER: ffmpeg nicht gefunden." >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "FEHLER: ffprobe nicht gefunden." >&2; exit 1; }

mkdir -p "$OUT_DIR"

shopt -s nullglob nocaseglob
SOURCES=("$SRC_DIR"/*.webp "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg "$SRC_DIR"/*.png)
shopt -u nocaseglob nullglob

if [ "${#SOURCES[@]}" -eq 0 ]; then
  echo "FEHLER: keine Quellbilder in $SRC_DIR" >&2
  exit 1
fi

MANIFEST="$OUT_DIR/manifest.json"
SNIPPETS="$OUT_DIR/snippets.md"
echo "{" > "$MANIFEST"
: > "$SNIPPETS"

VIOLATIONS=0

for src in "${SOURCES[@]}"; do
  base="$(basename "$src")"
  base="${base%.*}"
  echo "==> $base"

  IFS=, read -r SW SH < <(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=p=0:s=, "$src")

  # Breitenstufen für dieses Bild (kein Upscaling, Obergrenze 1600 px fürs Budget).
  # Kleinere Quellen bekommen ihre native Breite als letzte Stufe.
  steps=()
  for w in "${WIDTHS[@]}"; do
    if [ "$w" -lt "$SW" ]; then steps+=("$w"); fi
  done
  if [ "$SW" -le 1600 ]; then steps+=("$SW"); fi

  # Fallback-Breite für <img src>: größte Stufe <= 800, sonst kleinste Stufe
  FALLBACK_W="${steps[0]}"
  for w in "${steps[@]}"; do
    if [ "$w" -le 800 ]; then FALLBACK_W="$w"; fi
  done
  FALLBACK_H=$(( SH * FALLBACK_W / SW ))
  FALLBACK_SRC=""

  echo "  \"${base}\": {\"source_width\": $SW, \"source_height\": $SH, \"variants\": [" >> "$MANIFEST"

  webp_srcset=""
  avif_srcset=""

  for w in "${steps[@]}"; do
    wout="$OUT_DIR/${base}-${w}w"
    webp_out="${wout}.webp"
    avif_out="${wout}.avif"

    if [ -e "$webp_out" ] && [ -e "$avif_out" ] \
       && [ "$webp_out" -nt "$src" ] && [ "$avif_out" -nt "$src" ]; then
      echo "  - ${w}w: aktuell, übersprungen"
    else
      ffmpeg -v error -y -i "$src" -vf "scale=${w}:-2" \
        -c:v libwebp -quality "$WEBP_QUALITY" -compression_level 6 "$webp_out"
      ffmpeg -v error -y -i "$src" -vf "scale=${w}:-2" \
        -c:v libaom-av1 -crf "$AVIF_CRF" -cpu-used 6 -pix_fmt yuv420p \
        -frames:v 1 -still-picture 1 "$avif_out"
      echo "  - ${w}w: kodiert"
    fi

    # Budget-Check (harter Fehler am Ende)
    for f in "$webp_out" "$avif_out"; do
      kb=$(( $(stat -c%s "$f") / 1024 ))
      if [ "$kb" -ge "$MAX_KB" ]; then
        echo "  FEHLER: $f ist ${kb} KB (>= ${MAX_KB} KB Budget)" >&2
        VIOLATIONS=1
      fi
    done

    rel="${wout#"$REPO_ROOT"/}"
    webp_srcset+="${webp_srcset:+, }${rel}.webp ${w}w"
    avif_srcset+="${avif_srcset:+, }${rel}.avif ${w}w"

    if [ "$w" -eq "$FALLBACK_W" ]; then FALLBACK_SRC="$rel"; fi

    wb=$(stat -c%s "$webp_out"); ab=$(stat -c%s "$avif_out")
    echo "    {\"width\": $w, \"webp_bytes\": $wb, \"avif_bytes\": $ab}," >> "$MANIFEST"
  done

  sed -i '$ s/,$//' "$MANIFEST"          # letztes Komma der variants entfernen
  echo "  ]}," >> "$MANIFEST"            # Eintrag schließen (Komma evtl. letzter)

  # Copy-paste-fertiges <picture>-Snippet (alt-Text und sizes ans Layout anpassen!)
  SIZES="(max-width: 700px) 100vw, 50vw"
  {
    echo "## ${base}"
    echo
    echo '```html'
    echo "<picture>"
    echo "  <source type=\"image/avif\""
    echo "    srcset=\"${avif_srcset}\""
    echo "    sizes=\"${SIZES}\">"
    echo "  <source type=\"image/webp\""
    echo "    srcset=\"${webp_srcset}\""
    echo "    sizes=\"${SIZES}\">"
    echo "  <img src=\"${FALLBACK_SRC}.webp\" width=\"${FALLBACK_W}\" height=\"${FALLBACK_H}\""
    echo "    alt=\"ALT_TEXT\" loading=\"lazy\" decoding=\"async\" sizes=\"${SIZES}\">"
    echo "</picture>"
    echo '```'
    echo
  } >> "$SNIPPETS"
done

sed -i '$ s/},$/}/' "$MANIFEST"          # Komma des letzten Eintrags entfernen
echo "}" >> "$MANIFEST"

if [ "$VIOLATIONS" -ne 0 ]; then
  echo "FEHLER: Budget von ${MAX_KB} KB verletzt – Qualität/Breite anpassen." >&2
  exit 1
fi

echo
echo "Fertig. Manifest: $MANIFEST"
echo "Snippets (picture-Markup): $SNIPPETS"
