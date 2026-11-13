# ICST_Ambi_Reaper v1.1.0

## Deutsch

Portabler REAPER-Ordner für ICST Ambisonics und den Animator Choreographer. Diese Version ersetzt v1.0.0.

**Änderungen gegenüber v1.0.0**
- AmbiIRVerb, AmbiGran 16 und das IRidesce-Material (Impulsantworten, Doku-Bilder) sind nicht mehr enthalten.
- Quick Start legt die Hall-Spur `HOA_Reverb` mit IEM FdnReverb (VST3) an.
- Neu: `ICST_Ambi_Reaper starten.command` setzt den Plug-in-Pfad bei jedem Start auf den aktuellen Ort (auch auf externen Laufwerken) und startet REAPER aus dem Ordner. Beim Start prüft REAPER Pfad und Plug-in-Liste und meldet, was zu tun ist.
- Animator Choreographer 0.1.0 (Evaluationsbeta, [Release](https://github.com/joambi/animator-choreographer/releases/tag/v0.1.0)) liegt im Ordner `Animator/`; Toolbar-Button 16 startet die App.
- Doku und README: Toolbar mit 21 Buttons, macOS-Hinweis für unsignierte Dateien (*Dennoch öffnen*), Windows-Installer-Name des Animator Choreographer.
- PKG: Die mitgelieferte App wird immer in den Ordner installiert, auch wenn eine gleichnamige App an anderer Stelle liegt.
- `…_scripts-only.zip` enthält jetzt die Animator-Skripte (`Scripts/ICST/Animator`, Buttons 16–20); in v1.0.0 fehlten sie dort.

**Downloads**
- `ICST_Ambi_Reaper_1.1.0_macOS.pkg`: Installer nach `/Applications/ICST_Ambi_Reaper` (macOS 12+, Apple Silicon empfohlen)
- `ICST_Ambi_Reaper_1.1.0_macOS.zip`: portabler Ordner, z. B. für eine externe SSD
- `ICST_Ambi_Reaper_1.1.0_scripts-only.zip`: nur Skripte, Toolbar, Konfiguration und Doku (für den Aufbau unter Windows)

REAPER ist nicht enthalten: <https://www.reaper.fm/download.php>

**macOS: unsignierte Dateien**
PKG und Skripte sind nicht mit einer Developer ID signiert. Blockiert macOS das Öffnen: Meldung schliessen, dann *Systemeinstellungen › Datenschutz & Sicherheit › Dennoch öffnen* und mit dem Passwort bestätigen (ab macOS 15; bis macOS 14 genügt Ctrl-Klick › Öffnen).

**Hinweise**
- Windows: Beta, nicht getestet (Aufbau aus Teilen, siehe README)
- v1.0.0 wurde mit REAPER 7.85 auf macOS getestet. Die Änderungen in v1.1.0 sind auf einem Mac noch nicht vollständig durchgespielt.
- Die REAPER-Erweiterungen in `UserPlugins` gibt es nur für Apple Silicon.
- ICST-Teile: GPL-3.0-or-later; Animator Choreographer: GPL-3.0; Drittkomponenten siehe `THIRD_PARTY_LICENSES.md`
- Dokumentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>

## English

Portable REAPER folder for ICST Ambisonics and the Animator Choreographer. This version replaces v1.0.0.

**Changes since v1.0.0**
- AmbiIRVerb, AmbiGran 16 and the IRidesce material (impulse responses, doc images) are no longer included.
- Quick Start creates the reverb track `HOA_Reverb` with IEM FdnReverb (VST3).
- New: `ICST_Ambi_Reaper starten.command` points the plug-in path to the current location on every start (also on external drives) and starts REAPER from the folder. On startup REAPER checks the path and the plug-in list and reports what to do.
- Animator Choreographer 0.1.0 (evaluation beta, [release](https://github.com/joambi/animator-choreographer/releases/tag/v0.1.0)) is in the `Animator/` folder; toolbar button 16 starts the app.
- Docs and README: toolbar with 21 buttons, macOS note for unsigned files (*Open Anyway*), Windows installer name of the Animator Choreographer.
- PKG: the bundled app is always installed into the folder, even if an app with the same name exists elsewhere.
- `…_scripts-only.zip` now contains the Animator scripts (`Scripts/ICST/Animator`, buttons 16–20); they were missing there in v1.0.0.

**Downloads**
- `ICST_Ambi_Reaper_1.1.0_macOS.pkg`: installer to `/Applications/ICST_Ambi_Reaper` (macOS 12+, Apple Silicon recommended)
- `ICST_Ambi_Reaper_1.1.0_macOS.zip`: portable folder, e.g. for an external SSD
- `ICST_Ambi_Reaper_1.1.0_scripts-only.zip`: scripts, toolbar, configuration and docs only (for building on Windows)

REAPER is not included: <https://www.reaper.fm/download.php>

**macOS: unsigned files**
The PKG and the scripts are not signed with a Developer ID. If macOS blocks opening: close the message, then *System Settings › Privacy & Security › Open Anyway* and confirm with your password (macOS 15 and later; up to macOS 14, Ctrl-click › Open is enough).

**Notes**
- Windows: beta, untested (assembled from parts, see README)
- v1.0.0 was tested with REAPER 7.85 on macOS. The changes in v1.1.0 have not yet been fully run through on a Mac.
- The REAPER extensions in `UserPlugins` are available for Apple Silicon only.
- ICST parts: GPL-3.0-or-later; Animator Choreographer: GPL-3.0; third-party components see `THIRD_PARTY_LICENSES.md`
- Documentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>
