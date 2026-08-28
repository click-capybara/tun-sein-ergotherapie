# Bild-Standard (Pixel & Rank)

Alle Fotos auf dieser Website folgen diesem Standard. Ziel: schnelle Ladezeiten
auf Mobilgeräten, moderne Formate, responsive Auflösung, hartes Größenbudget.

## Regeln

1. **Formate:** Jedes Bild wird als **WebP** (Fallback, ~95 % Browser) und
   **AVIF** (moderne Browser, ~30 % kleiner bei gleicher Qualität) ausgeliefert.
   Ein `<picture>`-Element wählt automatisch das beste Format.
2. **Responsive Srcsets:** Breitenstufen **480 / 800 / 1200 / 1600 px**,
   Obergrenze 1600 px (größere Quellen werden heruntergerechnet, nie Upscaling;
   kleinere Quellen behalten ihre native Breite als letzte Stufe).
3. **Budget:** **Jede einzelne Datei < 200 KB.** Das Script prüft das hart und
   bricht mit Fehler ab, wenn eine Variante das Budget reißt.
4. **Qualität:** WebP `-quality 78`, AVIF `-crf 30` (libaom, yuv420p).
   Kalibriert am 28.08.2026 an den Praxis-Fotos: keine sichtbaren Artefakte
   bei Display-Größe, AVIF 1600w ≈ 60 KB, WebP 1600w ≈ 130 KB.
5. **Markup:** `<img>` immer mit `width`/`height` (kein Layout-Shift, CLS),
   `loading="lazy"` unterhalb des ersten Viewports, `decoding="async"`,
   aussagekräftiger deutscher `alt`-Text (BFSG/WCAG).

## Neue Bilder hinzufügen

1. Quelldatei (webp/jpg/png) in das passende Verzeichnis legen,
   z. B. `assets/photos/praxis/`. Dateiname semantisch wählen
   (`empfang.webp`, nicht `PXL_2026….webp`).
2. Script aus dem Repo-Root starten:

   ```bash
   bash scripts/optimize-images.sh
   ```

   Das Script erzeugt `assets/photos/<gruppe>/generated/` mit allen Varianten,
   einem `manifest.json` (Größen pro Variante) und `snippets.md` mit
   copy-paste-fertigem `<picture>`-Markup pro Bild.
3. Snippet aus `generated/snippets.md` ins HTML übernehmen, `alt`-Text und
   `sizes` ans Layout anpassen.
4. **Quellbilder bleiben im Repo** (Single Source of Truth für spätere
   Neukodierung). Wer Repo-Schlankheit will, kann sie später in ein
   Archiv-Repo auslagern – Entscheidung offen, bewusst nicht jetzt.

## Bestehende Varianten

Das Script überspringt Varianten, die neuer als ihre Quelle sind (inkrementell).
Nach Änderung der Qualitätsparameter: `generated/` löschen und neu laufen lassen.

## Tooling

Benötigt wird nur **ffmpeg ≥ 5 mit libwebp und libaom-av1** (auf dem Pi
vorhanden; `ffmpeg -encoders | grep -E 'webp|av1'` prüfen).
Hinweis: `libsvtav1` ist auf ARM ohne NEON-ASM zu langsam – deshalb libaom.

## Warum kein Node-Build-Tool?

Die Site ist statisches HTML ohne Build-Schritt; GitHub Pages serviert direkt.
Ein bash+ffmpeg-Script hält die Pipeline dependency-frei, auf dieser Maschine
laufbar und in 2 Minuten lesbar. Sobald ein SSG eingeführt wird, kann das
Script 1:1 in einen Build-Step wandern.
