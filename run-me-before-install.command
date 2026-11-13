#!/bin/sh
# ICST Ambi Reaper: 1) Quarantaene-Flag entfernen, 2) Plugin-Pfad in reaper.ini auf DIESEN Ordner setzen.
# 1) Remove the macOS quarantine flag, 2) point the plugin path in reaper.ini to THIS folder.
# Nach dem Verschieben des Ordners einfach nochmals ausfuehren. / Run again after moving the folder.
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
xattr -dr com.apple.quarantine . 2>/dev/null

# reaper.ini mit [reaper]-Abschnitt und Pfad-Schluesseln sicherstellen
[ -f reaper.ini ] || printf '[reaper]\n' > reaper.ini
grep -q '^\[reaper\]' reaper.ini || printf '\n[reaper]\n' >> reaper.ini
for key in vstpath_arm64 vstpath; do
  if ! grep -q "^$key=" reaper.ini; then
    awk -v k="$key" '{print} /^\[reaper\]/{print k"=x"}' reaper.ini > reaper.ini.tmp && mv reaper.ini.tmp reaper.ini
  fi
done
# Alle vstpath-Zeilen auf Effects/VST3 in diesem Ordner setzen
for key in vstpath_arm64 vstpath_x86_64 vstpath; do
  if grep -q "^$key=" reaper.ini 2>/dev/null; then
    esc=$(printf '%s' "$HERE/Effects/VST3" | sed 's/[&|\\]/\\&/g')
    sed "s|^$key=.*|$key=$esc|" reaper.ini > reaper.ini.tmp && mv reaper.ini.tmp reaper.ini
  fi
done

echo "Fertig / Done: $HERE"
echo "Plugin-Pfad / plugin path: $HERE/Effects/VST3"
if [ -d REAPER.app ]; then
  echo "Du kannst REAPER.app jetzt aus diesem Ordner starten. / You can now start REAPER.app from this folder."
else
  echo "REAPER.app fehlt: von https://www.reaper.fm laden und in diesen Ordner legen. / REAPER.app missing: download from reaper.fm and put it into this folder."
fi
