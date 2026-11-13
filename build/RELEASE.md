# Release-Ablauf

Repo = Quellen (Scripts, Icons, Doku, JSFX, Konfiguration). Binaries (`Effects/VST3`, `UserPlugins`, `Animator`) sind per `.gitignore` ausgeschlossen und werden nur als Release-Dateien verteilt. REAPER.app wird nie mitgegeben.

1. Release-Notizen als `build/RELEASE_NOTES_v<Version>.md` anlegen, committen, Version taggen und pushen:
   `git tag -a v1.1.0 -m "ICST_Ambi_Reaper v1.1.0" && git push origin v1.1.0`
   → GitHub Actions prueft die Lua-Syntax, baut `…_scripts-only.zip` und legt einen **Release-Entwurf** (Pre-release) mit diesen Notizen an. Ein Entwurf ist nicht oeffentlich.
2. Auf dem Mac die macOS-Dateien bauen (im Ordner, der die Binaries enthaelt):
   `build/make_release.sh 1.1.0`
   → `../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.1.0_macOS.zip` und `…_macOS.pkg`
3. Hochladen, Entwurf pruefen, dann veroeffentlichen:
   `gh release upload v1.1.0 ../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.1.0_macOS.* --clobber`
   `gh release edit v1.1.0 --draft=false`

Schritte 2 und 3 in einem: `bash build/do_release.sh 1.1.0` (veroeffentlicht nicht).

## Signieren / Notarisieren (optional, empfohlen fuer Workshops)

Mit einem Apple-Developer-ID-Zertifikat (ZHdK) entfaellt die Gatekeeper-Warnung:

```
PKG_SIGN_IDENTITY="Developer ID Installer: Zuercher Hochschule der Kuenste (TEAMID)" build/make_release.sh 1.1.0
xcrun notarytool submit ICST_Ambi_Reaper_1.1.0_macOS.pkg --keychain-profile "zhdk-notary" --wait
xcrun stapler staple ICST_Ambi_Reaper_1.1.0_macOS.pkg
```

Ohne Signatur: Empfaenger oeffnen das PKG per Doppelklick, schliessen die Meldung und bestaetigen unter Systemeinstellungen › Datenschutz & Sicherheit › „Dennoch oeffnen" mit dem Passwort (ab macOS 15; bis macOS 14 genuegt Ctrl-Klick › Oeffnen).

## Was das PKG tut

Installiert nach `/Applications/ICST_Ambi_Reaper`, kopiert eine vorhandene `/Applications/REAPER.app` hinein (ditto), setzt den VST3-Pfad in `reaper.ini`, uebergibt den Ordner dem angemeldeten Benutzer. Dateien aus einem PKG tragen kein Quarantaene-Flag — die Plug-ins laden ohne Gatekeeper-Dialoge. Mitgelieferte `.app`-Bundles sind im PKG als nicht relozierbar markiert (`BundleIsRelocatable=false`), damit der Installer sie immer in den Ordner legt.
