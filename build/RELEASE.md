# Release-Ablauf

Repo = Quellen (Scripts, Icons, Doku, JSFX, Konfiguration). Binaries (`Effects/VST3`, `UserPlugins`, `Animator`) sind per `.gitignore` ausgeschlossen und werden nur als Release-Dateien verteilt. REAPER.app wird nie mitgegeben.

1. Aenderungen committen, Version taggen und pushen:
   `git tag v1.0.0 && git push --tags`
   → GitHub Actions prueft die Lua-Syntax, baut `…_scripts-only.zip` und legt einen **Release-Entwurf** an.
2. Auf dem Mac die macOS-Dateien bauen (im Ordner, der die Binaries enthaelt):
   `build/make_release.sh 1.0.0`
   → `../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.0.0_macOS.zip` und `…_macOS.pkg`
3. Hochladen und Entwurf veroeffentlichen:
   `gh release upload v1.0.0 ../ICST_Ambi_Reaper_releases/ICST_Ambi_Reaper_1.0.0_macOS.* --clobber`
   `gh release edit v1.0.0 --draft=false`

## Signieren / Notarisieren (optional, empfohlen fuer Workshops)

Mit einem Apple-Developer-ID-Zertifikat (ZHdK) entfaellt die Gatekeeper-Warnung:

```
PKG_SIGN_IDENTITY="Developer ID Installer: Zuercher Hochschule der Kuenste (TEAMID)" build/make_release.sh 1.0.0
xcrun notarytool submit ICST_Ambi_Reaper_1.0.0_macOS.pkg --keychain-profile "zhdk-notary" --wait
xcrun stapler staple ICST_Ambi_Reaper_1.0.0_macOS.pkg
```

Ohne Signatur: Empfaenger oeffnen das PKG mit Rechtsklick › Oeffnen (macOS 15: Systemeinstellungen › Datenschutz & Sicherheit › „Trotzdem oeffnen").

## Was das PKG tut

Installiert nach `/Applications/ICST_Ambi_Reaper`, kopiert eine vorhandene `/Applications/REAPER.app` hinein (ditto), setzt den VST3-Pfad in `reaper.ini`, uebergibt den Ordner dem angemeldeten Benutzer. Dateien aus einem PKG tragen kein Quarantaene-Flag — die Plug-ins laden ohne Gatekeeper-Dialoge.
