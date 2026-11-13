#!/bin/bash
# Einmal-Release: bash build/do_release.sh 1.0.0   (auf dem Mac, im Ordner ICST_Ambi_Reaper)
# Voraussetzung: gh installiert und angemeldet (gh auth login), Xcode Command Line Tools.
set -euo pipefail
VER="${1:?Version angeben, z. B. 1.0.0}"
REPO="joambi/ICST_Ambi_Reaper"
cd "$(dirname "$0")/.."

command -v gh >/dev/null || { echo "gh fehlt: brew install gh && gh auth login"; exit 1; }
gh auth status >/dev/null

# 1. Git-Repo + Remote
[ -d .git ] || { git init -b main; git add -A; git commit -m "ICST_Ambi_Reaper $VER"; }
if ! gh repo view "$REPO" >/dev/null 2>&1; then
  gh repo create "$REPO" --public --source=. --remote=origin --description "Portable REAPER folder for ICST Ambisonics and the Animator Choreographer"
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
git push -u origin main

# 2. Tag -> CI baut scripts-only.zip und legt Draft an
git tag -a "v$VER" -m "ICST_Ambi_Reaper v$VER" 2>/dev/null || true
git push origin "v$VER"

# 3. macOS-Dateien bauen
build/make_release.sh "$VER"
OUT="../ICST_Ambi_Reaper_releases"

# 4. Draft sicherstellen, Notes setzen, Dateien hochladen (Veroeffentlichen bleibt manuell)
for i in 1 2 3 4 5 6; do gh release view "v$VER" -R "$REPO" >/dev/null 2>&1 && break; sleep 10; done
gh release view "v$VER" -R "$REPO" >/dev/null 2>&1 || gh release create "v$VER" -R "$REPO" --draft --title "ICST_Ambi_Reaper v$VER"
NOTES="build/RELEASE_NOTES_v$VER.md"
[ -f "$NOTES" ] || { echo "$NOTES fehlt"; exit 1; }
gh release edit "v$VER" -R "$REPO" --title "ICST_Ambi_Reaper v$VER" --prerelease -F "$NOTES"
gh release upload "v$VER" -R "$REPO" "$OUT"/ICST_Ambi_Reaper_${VER}_macOS.* --clobber
echo "Draft fertig: https://github.com/$REPO/releases  -> pruefen, dann: gh release edit v$VER -R $REPO --draft=false"
