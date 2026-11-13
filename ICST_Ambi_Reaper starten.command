#!/bin/sh
# ICST Ambi Reaper starten: Plug-in-Pfad auf DIESEN Ordner setzen, dann REAPER.app aus diesem Ordner oeffnen.
# Start ICST Ambi Reaper: point the plug-in path to THIS folder, then open REAPER.app from this folder.
# Funktioniert auch auf externen Laufwerken mit wechselndem Namen (/Volumes/...). / Works on external drives too.
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
if [ ! -d REAPER.app ]; then
  echo "REAPER.app fehlt in $HERE (siehe README). / REAPER.app missing in $HERE (see README)."
  exit 1
fi
if pgrep -f "$HERE/REAPER.app/Contents/MacOS/REAPER" >/dev/null 2>&1; then
  echo "REAPER laeuft bereits aus diesem Ordner - bitte zuerst beenden. / REAPER is already running from this folder - quit it first."
  exit 1
fi
/bin/sh ./run-me-before-install.command >/dev/null 2>&1
echo "Plug-in-Pfad / plug-in path: $HERE/Effects/VST3"
open -n "$HERE/REAPER.app"
