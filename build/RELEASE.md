# Release-Ablauf

Repo = Quellen (Scripts, Icons, Doku, JSFX, Konfiguration). Binaries (`Effects/VST3`, `UserPlugins`, `Animator`) sind per `.gitignore` ausgeschlossen und werden nur als Release-Dateien verteilt. REAPER.app wird nie mitgegeben.

1. Release-Notizen als `build/RELEASE_NOTES_v<Version>.md` anlegen, committen, Version taggen und pushen:
   `git tag -a v1.1.0 -m "ICST_Ambi_Reaper v1.1.0" && git push origin v1.1.0`
   → GitHub Actions prueft die Lua-Syntax, baut `…_scripts-only.zip` und legt einen **Release-Entwurf** (Pre-release) mit diesen Notizen an. Ein Entwurf ist nicht oeffentlich.
2. Auf dem Mac die macOS-Dateien bauen (im Ordner, der die Binaries enthaelt):
   `build/make_release.sh 1.1.0`
   → `../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.1.0_macOS.zip`
3. Hochladen, Entwurf pruefen, dann veroeffentlichen:
   `gh release upload v1.1.0 ../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.1.0_macOS.* --clobber`
   `gh release edit v1.1.0 --draft=false`

Schritte 2 und 3 in einem: `bash build/do_release.sh 1.1.0` (veroeffentlicht nicht).
