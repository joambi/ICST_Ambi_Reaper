# ICST_Ambi_Reaper v1.1.3

## Deutsch

Portabler REAPER-Ordner für ICST Ambisonics und den Animator Choreographer. Diese Version ersetzt v1.1.2. Plug-ins und Animator Choreographer 0.1.0 sind unverändert.

**Änderungen gegenüber v1.1.2**
- Motion Map GUI (`Scripts/ICST/JS_AmbiEncoder64_Motion_Map_GUI.lua`) von v2.4.3 auf v2.4.5:
  - v2.4.4: Preview-Transport unter *OSC PREVIEW* mit Speed-Faktor (frei und im Tempo), Richtung Fwd/Rev sowie Play/Stop. Stop hält die Animation in der Trajektorien-Vorschau und in der Live-OSC-Vorschau an. Die Einstellungen werden nicht in Presets gespeichert.
  - v2.4.5: Geschriebene Spuren stehen immer auf Latch; die Option *Track Latch* entfällt, ältere Presets werden dafür ignoriert. Neuer Button *Sync*: Die Vorschau folgt Play/Stop von REAPER, und Play/Stop in der GUI starten und stoppen den REAPER-Transport.
- Toolbar-Button, Action-ID und Icon der Motion Map GUI sind unverändert; der Button startet jetzt v2.4.5.
- Alle anderen Skripte, Konfigurationsdateien und die Doku sind gleich wie in v1.1.2.

**Downloads**
- `ICST_Ambi_Reaper_1.1.3_macOS.pkg`: Installer nach `/Applications/ICST_Ambi_Reaper` (macOS 12+, Apple Silicon empfohlen)
- `ICST_Ambi_Reaper_1.1.3_macOS.zip`: portabler Ordner, z. B. für eine externe SSD
- `ICST_Ambi_Reaper_1.1.3_scripts-only.zip`: nur Skripte, Toolbar, Konfiguration und Doku (für den Aufbau unter Windows)

REAPER ist nicht enthalten: <https://www.reaper.fm/download.php>

**Update einer bestehenden Installation**
Das PKG überschreibt in `/Applications/ICST_Ambi_Reaper` die Dateien `reaper.ini` (u. a. Audiogerät und Fensterpositionen), `reaper-kb.ini`, `reaper-menu.ini`, `reaper-mouse.ini` und `reapack.ini`. Wer eigene Einstellungen, Tastenbelegungen oder Menüs behalten will, kopiert diese Dateien vor der Installation an einen anderen Ort und legt sie danach zurück. Plug-in-Liste und übrige Einstellungsdateien bleiben erhalten. Von v1.1.2 aus genügt es, `Scripts/ICST/JS_AmbiEncoder64_Motion_Map_GUI.lua` aus `…_scripts-only.zip` in den bestehenden Ordner zu kopieren.

**macOS: unsignierte Dateien**
PKG und Skripte sind nicht mit einer Developer ID signiert. Blockiert macOS das Öffnen: Meldung schliessen, dann *Systemeinstellungen › Datenschutz & Sicherheit › Dennoch öffnen* und mit dem Passwort bestätigen (ab macOS 15; bis macOS 14 genügt Ctrl-Klick › Öffnen).

**Hinweise**
- Motion Map GUI v2.4.5 wurde vor der Aufnahme ins Bundle einzeln in REAPER verwendet; der Aufruf über die Toolbar dieses Pakets ist nicht eigens getestet. Für v1.1.2 getestet (REAPER 7.85, macOS, Apple Silicon): Auto-Route, Quick Start, Routing mit 64 Kanälen.
- Windows: Beta, nicht getestet (Aufbau aus Teilen, siehe README)
- Die REAPER-Erweiterungen in `UserPlugins` gibt es nur für Apple Silicon.
- ICST-Teile: GPL-3.0-or-later; Animator Choreographer: GPL-3.0; Drittkomponenten siehe `THIRD_PARTY_LICENSES.md`
- Dokumentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>

**SHA-256**
```
e511145834b084f767eddfca7496578a4f3a7f60eb8baef86224300fbd34fc0d  ICST_Ambi_Reaper_1.1.3_macOS.pkg
1b884fb461e211eef16a9131d96266c18584ff91b66c44c46027a4059a685169  ICST_Ambi_Reaper_1.1.3_macOS.zip
e63db68398281cc9ed62f661d9bafa8288ead72d48f9aed31f9cf1966c6998cc  ICST_Ambi_Reaper_1.1.3_scripts-only.zip
```

## English

A portable REAPER folder for ICST Ambisonics and the Animator Choreographer. This version replaces v1.1.2. The plug-ins and Animator Choreographer 0.1.0 are unchanged.

**Changes since v1.1.2**
- Motion Map GUI (`Scripts/ICST/JS_AmbiEncoder64_Motion_Map_GUI.lua`) updated from v2.4.3 to v2.4.5:
  - v2.4.4: preview transport under *OSC PREVIEW* with a speed factor (free-running and tempo-synced), Fwd/Rev direction and Play/Stop. Stop freezes the animation in the trajectory preview and in the live OSC preview. These settings are not stored in presets.
  - v2.4.5: written tracks are always set to Latch; the *Track Latch* option is gone, and older presets are ignored for this setting. New *Sync* button: the preview follows REAPER play/stop, and Play/Stop in the GUI start and stop the REAPER transport.
- The Motion Map GUI toolbar button, action ID and icon are unchanged; the button now starts v2.4.5.
- All other scripts, configuration files and documentation are the same as in v1.1.2.

**Downloads**
- `ICST_Ambi_Reaper_1.1.3_macOS.pkg`: installer for `/Applications/ICST_Ambi_Reaper` (macOS 12 or later, Apple Silicon recommended)
- `ICST_Ambi_Reaper_1.1.3_macOS.zip`: portable folder, e.g. for an external SSD
- `ICST_Ambi_Reaper_1.1.3_scripts-only.zip`: scripts, toolbar, configuration and documentation only (for setting up on Windows)

REAPER is not included: <https://www.reaper.fm/download.php>

**Updating an existing installation**
The PKG overwrites `reaper.ini` (including audio device and window positions), `reaper-kb.ini`, `reaper-menu.ini`, `reaper-mouse.ini` and `reapack.ini` in `/Applications/ICST_Ambi_Reaper`. To keep your own settings, key bindings or menus, copy these files to another location before installing and restore them afterwards. The plug-in list and all other settings files are preserved. Coming from v1.1.2, it is enough to copy `Scripts/ICST/JS_AmbiEncoder64_Motion_Map_GUI.lua` from `…_scripts-only.zip` into your existing folder.

**macOS: unsigned files**
The PKG and the scripts are not signed with a Developer ID. If macOS refuses to open a file, close the message, go to *System Settings › Privacy & Security*, click *Open Anyway* and confirm with your password (macOS 15 and later; on macOS 14 and earlier, Ctrl-click › *Open* is enough).

**Notes**
- Motion Map GUI v2.4.5 was used on its own in REAPER before it was added to the bundle; launching it from the toolbar of this package has not been tested separately. Tested for v1.1.2 (REAPER 7.85, macOS, Apple Silicon): Auto-Route, Quick Start, 64-channel routing.
- Windows: beta, untested (set up manually from the scripts-only package, see README).
- The REAPER extensions in `UserPlugins` are for Apple Silicon only.
- Licences: ICST components GPL-3.0-or-later; Animator Choreographer GPL-3.0; for third-party components see `THIRD_PARTY_LICENSES.md`.
- Documentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>

**SHA-256**
```
e511145834b084f767eddfca7496578a4f3a7f60eb8baef86224300fbd34fc0d  ICST_Ambi_Reaper_1.1.3_macOS.pkg
1b884fb461e211eef16a9131d96266c18584ff91b66c44c46027a4059a685169  ICST_Ambi_Reaper_1.1.3_macOS.zip
e63db68398281cc9ed62f661d9bafa8288ead72d48f9aed31f9cf1966c6998cc  ICST_Ambi_Reaper_1.1.3_scripts-only.zip
```
