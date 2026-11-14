# ICST_Ambi_Reaper v1.1.2

## Deutsch

Portabler REAPER-Ordner für ICST Ambisonics und den Animator Choreographer. Diese Version ersetzt v1.1.1. Plug-ins und Animator Choreographer 0.1.0 sind unverändert.

**Änderungen gegenüber v1.1.1**
- Auto-Route und Quick Start: In den Ja/Nein-Feldern gelten jetzt `j`, `ja`, `y`, `yes` und `1` als ja. Bisher galt nur `j`; ein `y` wurde ohne Meldung als nein gewertet. Dadurch sortierte Auto-Route die Spuren nicht, und Quick Start legte mit `y` keine HOA_FX- oder HOA_Reverb-Spur an.
- README: Der *Erste Durchlauf* beginnt mit Quick Start (Button 1, Vorgabe `4, n, n, j, j`); der Weg Schritt für Schritt bleibt als Variante B.
- README: Der Plug-in-Scan, den REAPER beim ersten Start beginnen kann, lässt sich im Fortschrittsfenster abbrechen.
- Tag und Paketinhalt stimmen wieder überein: Alle drei Pakete sind aus dem getaggten Stand gebaut.

**Downloads**
- `ICST_Ambi_Reaper_1.1.2_macOS.pkg`: Installer nach `/Applications/ICST_Ambi_Reaper` (macOS 12+, Apple Silicon empfohlen)
- `ICST_Ambi_Reaper_1.1.2_macOS.zip`: portabler Ordner, z. B. für eine externe SSD
- `ICST_Ambi_Reaper_1.1.2_scripts-only.zip`: nur Skripte, Toolbar, Konfiguration und Doku (für den Aufbau unter Windows)

REAPER ist nicht enthalten: <https://www.reaper.fm/download.php>

**Update einer bestehenden Installation**
Das PKG überschreibt in `/Applications/ICST_Ambi_Reaper` die Dateien `reaper.ini` (u. a. Audiogerät und Fensterpositionen), `reaper-kb.ini`, `reaper-menu.ini`, `reaper-mouse.ini` und `reapack.ini`. Wer eigene Einstellungen, Tastenbelegungen oder Menüs behalten will, kopiert diese Dateien vor der Installation an einen anderen Ort und legt sie danach zurück. Plug-in-Liste und übrige Einstellungsdateien bleiben erhalten. Wer nur die Skript-Korrektur braucht, kann aus `…_scripts-only.zip` die Dateien `Scripts/ICST/Ambi/Ambi_Auto_Route.lua`, `Scripts/ICST/Ambi/Ambi_Quick_Start.lua` und `Scripts/ICST/Ambi/lib/ambi_common.lua` in den bestehenden Ordner kopieren.

**macOS: unsignierte Dateien**
PKG und Skripte sind nicht mit einer Developer ID signiert. Blockiert macOS das Öffnen: Meldung schliessen, dann *Systemeinstellungen › Datenschutz & Sicherheit › Dennoch öffnen* und mit dem Passwort bestätigen (ab macOS 15; bis macOS 14 genügt Ctrl-Klick › Öffnen).

**Hinweise**
- Getestet mit REAPER 7.85 auf macOS (Apple Silicon) mit den Skripten dieser Version: Auto-Route mit `y` sortiert die Spuren (Player, Mono-Quellen, Encoder, HOA_FX, HOA_Reverb, HOA_MASTER, Decoder, Binaural; Spuren ohne Ambi-Rolle am Ende). Quick Start mit `4,y,y,j,j` legt HOA_FX (SceneRotator, MultiEQ) und HOA_Reverb (IEM FdnReverb, parallel) an und verbindet alles mit 64 Kanälen. Die frische Installation per PKG wurde zuletzt mit v1.1.1 durchgespielt (Toolbar oben, Quick Start, Button 16); der ZIP-Weg ist nicht erneut getestet.
- Windows: Beta, nicht getestet (Aufbau aus Teilen, siehe README)
- Die REAPER-Erweiterungen in `UserPlugins` gibt es nur für Apple Silicon.
- ICST-Teile: GPL-3.0-or-later; Animator Choreographer: GPL-3.0; Drittkomponenten siehe `THIRD_PARTY_LICENSES.md`
- Dokumentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>

## English

Portable REAPER folder for ICST Ambisonics and the Animator Choreographer. This version replaces v1.1.1. The plug-ins and Animator Choreographer 0.1.0 are unchanged.

**Changes since v1.1.1**
- Auto-Route and Quick Start: the yes/no fields now accept `j`, `ja`, `y`, `yes` and `1` as yes. Before, only `j` counted; a `y` was silently taken as no. As a result Auto-Route did not sort the tracks, and Quick Start did not create the HOA_FX or HOA_Reverb track when `y` was entered.
- README: the *First run* starts with Quick Start (button 1, default `4, n, n, j, j`); the step-by-step route remains as option B.
- README: the plug-in scan REAPER may start on the first launch can be cancelled in its progress window.
- Tag and package contents match again: all three packages are built from the tagged state.

**Downloads**
- `ICST_Ambi_Reaper_1.1.2_macOS.pkg`: installer to `/Applications/ICST_Ambi_Reaper` (macOS 12+, Apple Silicon recommended)
- `ICST_Ambi_Reaper_1.1.2_macOS.zip`: portable folder, e.g. for an external SSD
- `ICST_Ambi_Reaper_1.1.2_scripts-only.zip`: scripts, toolbar, configuration and docs only (for building on Windows)

REAPER is not included: <https://www.reaper.fm/download.php>

**Updating an existing installation**
The PKG overwrites `reaper.ini` (audio device, window positions etc.), `reaper-kb.ini`, `reaper-menu.ini`, `reaper-mouse.ini` and `reapack.ini` in `/Applications/ICST_Ambi_Reaper`. To keep your own settings, key bindings or menus, copy these files elsewhere before installing and put them back afterwards. The plug-in list and the other settings files are kept. If you only need the script fix, copy `Scripts/ICST/Ambi/Ambi_Auto_Route.lua`, `Scripts/ICST/Ambi/Ambi_Quick_Start.lua` and `Scripts/ICST/Ambi/lib/ambi_common.lua` from `…_scripts-only.zip` into your existing folder.

**macOS: unsigned files**
The PKG and the scripts are not signed with a Developer ID. If macOS blocks opening: close the message, then *System Settings › Privacy & Security › Open Anyway* and confirm with your password (macOS 15 and later; up to macOS 14, Ctrl-click › Open is enough).

**Notes**
- Tested with REAPER 7.85 on macOS (Apple Silicon) with the scripts of this version: Auto-Route with `y` sorts the tracks (player, mono sources, encoder, HOA_FX, HOA_Reverb, HOA_MASTER, decoder, binaural; tracks without an Ambi role at the end). Quick Start with `4,y,y,j,j` creates HOA_FX (SceneRotator, MultiEQ) and HOA_Reverb (IEM FdnReverb, parallel) and connects everything with 64 channels. The fresh PKG installation was last run through with v1.1.1 (toolbar at the top, Quick Start, button 16); the ZIP route has not been tested again.
- Windows: beta, untested (assembled from parts, see README)
- The REAPER extensions in `UserPlugins` are available for Apple Silicon only.
- ICST parts: GPL-3.0-or-later; Animator Choreographer: GPL-3.0; third-party components see `THIRD_PARTY_LICENSES.md`
- Documentation: <https://ambisonics.ch/icst-ambisonics-plugins/19_icst_ambi_reaper/docs/>
