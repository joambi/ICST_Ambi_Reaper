#!/bin/bash
# Erzeugt die Release-Dateien fuer GitHub Releases (auf dem Mac ausfuehren):
#   ICST_Ambi_Reaper_<ver>_macOS.zip          portabler Ordner (ohne REAPER.app, ohne persoenliche Daten)
#   ICST_Ambi_Reaper_<ver>_scripts-only.zip   nur versionierte, plattformneutrale Teile (Windows / bestehende Installation)
# Aufruf:  build/make_release.sh [version] [zielordner]
#   version     Standard: git-Tag (v1.2.3 -> 1.2.3), sonst Datum
#   zielordner  Standard: ../ICST_Ambi_Reaper_releases
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="ICST_Ambi_Reaper"
VER="${1:-}"
if [ -z "$VER" ]; then
  VER="$(git -C "$ROOT" describe --tags --always 2>/dev/null | sed 's/^v//' || true)"
  [ -n "$VER" ] || VER="$(date +%Y%m%d)"
fi
OUT="${2:-$(dirname "$ROOT")/${NAME}_releases}"
mkdir -p "$OUT"
TMP="$(mktemp -d)"; STAGE="$TMP/$NAME"; mkdir -p "$STAGE"
trap 'rm -rf "$TMP"' EXIT

echo "== Staging ($VER)"
rsync -a --filter="merge $ROOT/build/release-excludes.txt" "$ROOT/" "$STAGE/"
printf '[reaper]\nvstpath_arm64=x\nvstpath=x\ntoolbar:header=0\n' > "$STAGE/reaper.ini"    # run-me-before-install setzt den Pfad; toolbar:header=0 = Toolbar oben im Hauptfenster
echo "$VER" > "$STAGE/VERSION"
chmod +x "$STAGE/run-me-before-install.command"
chmod +x "$STAGE/ICST_Ambi_Reaper starten.command"
if [ -d "$STAGE/REAPER.app" ] || find "$STAGE" -name 'dearVR*' | grep -q .; then
  echo "FEHLER: REAPER.app oder dearVR im Staging — Abbruch." >&2; exit 1
fi
du -sh "$STAGE" | awk '{print "   Groesse:", $1}'

echo "== ZIP"
ZIP="$OUT/${NAME}_${VER}_macOS.zip"; rm -f "$ZIP"
(cd "$TMP" && zip -r -q -y "$ZIP" "$NAME")

if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "== scripts-only ZIP (git archive HEAD)"
  git -C "$ROOT" archive --format=zip --prefix="$NAME/" -o "$OUT/${NAME}_${VER}_scripts-only.zip" HEAD
fi

echo "== Fertig:"
ls -lh "$OUT" | awk 'NR>1{print "  ", $5, $9}'
echo "Hochladen:  gh release upload v$VER \"$OUT\"/${NAME}_${VER}_* --clobber"
