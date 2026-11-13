# ICST_Ambi_Reaper

Portabler REAPER-Resource-Ordner für ICST Ambisonics und den Animator Choreographer (Stand 7. November 2026).
English version: [README_EN.md](README_EN.md)

## 1. Was ist das?
Ein vorkonfigurierter [REAPER](https://www.reaper.fm)-Ordner mit Toolbar, Skripten, [VST3](https://steinbergmedia.github.io/vst3_dev_portal/)-Plug-ins (ICST, IEM) und Dokumentation, mit dem sich Ambisonics-Spuren (1.–7. Ordnung) per Knopfdruck anlegen, verbinden, bewegen und dekodieren lassen. Die ausführliche Anleitung steht in `Docs/index.html` (Toolbar-Button *Dokumentation*).

| | macOS | Windows |
|---|---|---|
| Status | vollständig, so ausgeliefert | **Beta, noch nicht getestet**; Aufbau aus Teilen (siehe 3) |
| Plug-ins im Ordner | ja (`Effects/VST3`, universal) | nein, Installer nötig |
| REAPER-Erweiterungen ([SWS](https://www.sws-extension.org), [js_ReaScriptAPI](https://forum.cockos.com/showthread.php?t=212174), [ReaPack](https://reapack.com)) | im Ordner (`UserPlugins`, nur Apple Silicon) | selbst installieren |
| Animator Choreographer (Button 16) | ja (`Animator/`) | ja (installierte App oder `Animator\Animator Choreographer.exe`) |

## 2. Installation und Quick Start: macOS

**Download:** [GitHub Releases](https://github.com/joambi/ICST_Ambi_Reaper/releases) — `ICST_Ambi_Reaper_<Version>_macOS.pkg` (Installer nach `/Applications/ICST_Ambi_Reaper`; kopiert eine vorhandene `/Applications/REAPER.app` hinein und setzt den Plug-in-Pfad — danach direkt zu Schritt 4) oder `…_macOS.zip` (portabel, z. B. für eine externe SSD — Schritte 1–6). `…_scripts-only.zip` enthält nur die plattformneutralen Teile (Windows, Abschnitt 3). **REAPER selbst ist aus Lizenzgründen nicht enthalten.** Unsigniertes PKG: Rechtsklick › Öffnen (macOS 15: Systemeinstellungen › Datenschutz & Sicherheit › *Trotzdem öffnen*).

**Voraussetzungen:** macOS 12 oder neuer, Apple Silicon empfohlen (auf Intel-Macs fehlen die Erweiterungen in `UserPlugins`), REAPER 7 (getestet mit 7.85). Optional für die Motion-Map-Werkzeuge: Python 3 (`xcode-select --install` im Terminal).

1. **Ordner kopieren.** `ICST_Ambi_Reaper` an einen festen Ort legen, z. B. auf die externe SSD oder nach `~/Music`. Leerzeichen im Pfad sind erlaubt.
2. **REAPER.app prüfen.** Liegt `REAPER.app` nicht im Ordner, von [reaper.fm](https://www.reaper.fm) laden (macOS, gleiche Hauptversion) und **in den Ordner `ICST_Ambi_Reaper`** legen, neben `reaper.ini`. Nur so arbeitet REAPER portabel mit diesem Ordner.
3. **Einrichtungsskript.** `run-me-before-install.command` mit Rechtsklick › **Öffnen** starten (Doppelklick wird nach einem Download blockiert). Es entfernt das macOS-Quarantäne-Flag und setzt den Plug-in-Pfad in `reaper.ini` auf den aktuellen Speicherort. Danach REAPER am besten immer mit `ICST_Ambi_Reaper starten.command` öffnen: Es setzt den Plug-in-Pfad bei jedem Start auf den aktuellen Ort (auch auf externen Laufwerken mit anderem Namen) und startet `REAPER.app` aus dem Ordner. Beim Start prüft REAPER zusätzlich Pfad und Plug-in-Liste und meldet, was zu tun ist.
4. **REAPER starten**, und zwar die `REAPER.app` **aus diesem Ordner**. Warnt macOS: Rechtsklick auf die App › **Öffnen**. Kontrolle: *Options › Show REAPER resource path in explorer/finder* muss auf den Ordner `ICST_Ambi_Reaper` zeigen.
5. **Plug-ins scannen.** *Options › Preferences › Plug-ins › VST*: Pfad endet auf `Effects/VST3`; **Re-scan** klicken (bei Bedarf *Clear cache and re-scan*).
6. **Toolbar zeigen.** *View › Toolbars › Floating toolbar 1* (Toolbar *ICST_Ambi_Automation*).

**Nicht doppelt installieren:** Sind dieselben Plug-ins zusätzlich aus den `.pkg`-Installern in `/Library/Audio/Plug-Ins/VST3` installiert, lädt REAPER unter Umständen die alte Kopie von dort. Entweder nur den Ordner benutzen oder die `.pkg`-Plug-ins entfernen.

### Erster Durchlauf (10 Minuten)
1. Neue Spur, Audiodatei (mono) einfügen. Auf der Spur **Encoder 64** klicken (rot-orange): AmbiEncoder_64 wird eingefügt.
2. **Decoder** (blau) für Lautsprecher oder **Binaural** (violett) für Kopfhörer anklicken.
3. Optional **HOA FX** für Effekte (IEM).
4. **Auto-Route** klicken: die Sends (16 Kanäle) Quellen › HOA FX › Decoder/Binaural werden gelegt.
5. Abspielen, im Encoder die Quelle bewegen. Bewegungen schreiben: **[Motion Map GUI](https://ambisonics.ch/icst-ambisonics-plugins/15_icst_ambi_motion_map/)** / **Spat Motion Automation** (Kapitel 6 der Doku).

## 3. Installation und Quick Start: Windows (Beta, ungetestet)

Der Ordner ist ein macOS-Bundle: die Plug-ins in `Effects/VST3`, die Dateien in `UserPlugins` und `Animator/` laufen nur auf macOS. Auf Windows werden deshalb nur die plattformunabhängigen Teile übernommen (Skripte, Icons, Menü, Doku, Impulsantworten) und die Plug-ins per Installer eingerichtet. Die Skripte sind überwiegend plattformneutral geschrieben (Pfad- und Shell-Aufrufe berücksichtigen Windows); ein vollständiger Durchlauf auf Windows steht noch aus.

**Voraussetzungen:** Windows 10/11 (64 Bit), REAPER 7 (64 Bit, getestet wurde nur unter macOS mit 7.85), Python 3 von [python.org](https://www.python.org) (bei der Installation *Add python.exe to PATH* anhaken; nur für Motion Map, [Motion Markers](https://ambisonics.ch/icst-ambisonics-plugins/14_icst_ambi_motion_markers/) und [Kristall Motion Map](https://ambisonics.ch/icst-ambisonics-plugins/18_kristall_motion_map/)).

1. **Portable REAPER installieren.** REAPER-Installer starten, **Portable install** wählen und einen neuen Ordner angeben, z. B. `C:\ICST_Ambi_Reaper`. REAPER dort einmal starten und wieder schließen (es legt `reaper.ini` an).
2. **Erweiterungen installieren.** *SWS Extension* ([sws-extension.org](https://www.sws-extension.org)) und *ReaPack* ([reapack.com](https://reapack.com)) installieren; in ReaPack *Browse packages* › **js_ReaScriptAPI** (Repository *ReaTeam Extensions*) installieren; REAPER neu starten.
3. **ICST-Teile kopieren.** Aus `ICST_Ambi_Reaper_<Version>_scripts-only.zip` (GitHub Releases) oder aus dem macOS-Ordner in den neuen Windows-Ordner (vorhandene Dateien überschreiben):
   - `Scripts\ICST` (komplett)
   - `Data\toolbar_icons`
   - `Docs`, `OSC`, `ICST_Player_Presets`
   - `reaper-menu.ini` und `reaper-kb.ini` (Toolbar und Aktionen; in einer frischen portablen Installation unkritisch, in einer bestehenden Installation überschreibt das eigene Toolbars)
   Nicht kopieren: `Effects\VST3`, `UserPlugins`, `Animator`, `REAPER.app`, `run-me-before-install.command`, `ICST_Ambi_Reaper starten.command`, die übrigen `.ini`-Dateien.
4. **Plug-ins installieren** (nach `C:\Program Files\Common Files\VST3`, das REAPER automatisch scannt):
   - *AmbiEncoder*, *AmbiEncoder_64*, *AmbiDecoder*: [ICST Ambisonics Plugins](https://ambisonics.ch/icst-ambisonics-plugins/) ([ambisonics.ch](https://ambisonics.ch))
   - *IEM Plug-in Suite* inkl. BinauralDecoder: [plugins.iem.at](https://plugins.iem.at)
   Die Skripte suchen die Plug-ins an ihren Namen, z. B. `AmbiEncoder_64 (ICST)`, `BinauralDecoder (IEM)`; unter Windows muss REAPER sie genauso anzeigen.
5. **REAPER starten**, *Options › Preferences › Plug-ins › VST › Re-scan*, dann *View › Toolbars › Floating toolbar 1*.
6. Weiter mit dem **Ersten Durchlauf** in Abschnitt 2.

**Hinweise Windows:** Button 16 (*Animator öffnen*) startet die installierte Windows-Version der App (`Animator-Choreographer-<Version>-Windows-Setup.exe`) oder `Animator\Animator Choreographer.exe` im REAPER-Ordner.

## 4. Wenn etwas nicht geht

| Problem | Lösung |
|---|---|
| Plug-ins erscheinen nicht (macOS) | REAPER beenden und mit `ICST_Ambi_Reaper starten.command` neu starten; sonst Preferences › Plug-ins › VST › *Re-scan* › *Clear cache and re-scan* |
| Plug-in stürzt ab oder falsche Version | Alte Kopie in `/Library/Audio/Plug-Ins/VST3` oder `~/Library/…` entfernen; Plug-in neu kopieren und `xattr -cr` / `codesign --force --deep --sign -` |
| Toolbar leer | *Options › Customize menus/toolbars*, Toolbar *Floating toolbar 1* prüfen; `reaper-menu.ini` und `reaper-kb.ini` müssen im Ressourcenordner liegen |
| Skript meldet fehlende Funktion (`JS_…`, `BR_…`, `CF_…`) | SWS und js_ReaScriptAPI installieren (Windows) bzw. `UserPlugins` prüfen (macOS) |
| Motion Map: „python3 not found“ | Python 3 installieren (siehe Voraussetzungen) |
| Auto-Route findet eine Spur nicht | Spur braucht ein erkennbares Plug-in oder „Player“ im Namen (Kapitel 4 der Doku) |

---

## Toolbar (links nach rechts / left to right)
| Button | Script | Funktion / Function |
|---|---|---|
| Quick Start | `Ambi_Quick_Start.lua` | Komplette Session mit einem Klick: Quellen, Encoder, optional HOA FX, Decoder, Binaural, Routing |
| B-Format Player | `Ambi_Create_BFormat_Player.lua` | Spur für B-Format-Datei, Ordnung 1/3/5/7 (4/16/36/64 ch) |
| Encoder 64 | `Ambi_Create_Encoder_64.lua` | AmbiEncoder_64 auf gewählte Spuren oder neue Spur |
| Encoder | `Ambi_Create_Encoder.lua` | AmbiEncoder (1 ch Quelle) |
| HOA FX | `Ambi_Create_HOA_FX.lua` | Spur `HOA_FX` mit IEM-Effekten (SceneRotator, MultiEQ, FdnReverb, DualDelay, …), Auswahl per Menü |
| HOA Master | `Ambi_Create_HOA_Master.lua` | Sammelspur `HOA_MASTER` (64 ch, ohne FX, Master-Send aus) |
| Mono Sources | `Ambi_Create_Mono_Sources.lua` | `Src_01 …` anlegen und mono auf die Eingänge des AmbiEncoder_64 routen |
| Decoder | `Ambi_Create_Decoder.lua` | AmbiDecoder |
| Binaural | `Ambi_Create_Binaural_dearVR.lua` | IEM BinauralDecoder (bis 7. Ordnung), sonst dearVR AMBI MICRO (16 ch), sonst Fallback |
| Auto-Route | `Ambi_Auto_Route.lua` | Erkennt Quelle/Encoder/HOA FX/Master/Decoder/Binaural, legt Sends, sortiert |
| [Motion Map GUI](https://ambisonics.ch/icst-ambisonics-plugins/15_icst_ambi_motion_map/) | `JS_AmbiEncoder64_Motion_Map_GUI.lua` | Bewegungsformen pro Quelle |
| Spat Motion Automation | `JS_Write_AmbiEncoder64_Spat_Motion_Automation.lua` | Schreibt XYZ-Automation + Region |
| [Kristall Motion Map](https://ambisonics.ch/icst-ambisonics-plugins/18_kristall_motion_map/) | `JS_ICST_Kristall_Motion_Map.lua` | Kristall-Gitter-Bewegung |
| [Motion Markers GUI](https://ambisonics.ch/icst-ambisonics-plugins/14_icst_ambi_motion_markers/) | `Markers/JS_Ambi_Motion_Marker_GUI.lua` | Bewegung zwischen Markern (Cues), Vorschau per OSC und Aufnahme als Automation; braucht `pip3 install python-osc` und das REAPER-Webinterface (Port 8080) |
| Motion Markers: CSV-Import | `Markers/JS_Import_Ambi_Markers_From_CSV.lua` | Importiert Cue-Listen aus CSV als Marker |
| Animator: Open | `Animator_Open_Choreographer.lua` | Startet die App |
| Animator: Prev / Next Region | `Animator_Prev_Region.lua` / `Animator_Next_Region.lua` | Cursor zu Region-Anfängen |
| Animator: Encoder-Spuren | `Animator_Create_Encoder_Tracks.lua` | `Encoder_01 …`, AmbiEncoder_64, orange |
| Animator: CSV-Export | `Animator_Export_Regions_CSV.lua` | Regionen/Marker als CSV |
| Dokumentation | `Ambi_Open_Docs.lua` | Öffnet `Docs/index.html` (oder die URL in `Docs/docs_url.txt`) |

## Farben / Colors
Encoder orange · Encoder_64 rot-orange · Decoder blau · Binaural violett · Player grün.

## Typischer Ablauf / Typical workflow
1. Quellen (Player / Encoder-Spuren) anlegen, optional HOA FX.
2. Decoder und/oder Binaural anlegen.
3. **Auto-Route** klicken: Sends (16 ch) Quellen → HOA FX → Decoder/Binaural.
4. Regionen im Projekt setzen → **CSV-Export** → in der App "Import regions (CSV)".
5. Animator-Szene in der App bauen (XML) → Animator in REAPER; Bewegung per Motion Map / Spat Automation.

## Hinweise / Notes
- Nur VST3 (kein AU). Plugin-Namen: AmbiEncoder, AmbiEncoder_64, AmbiDecoder (ICST), BinauralDecoder (IEM, [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html), mitgeliefert); optional [dearVR AMBI MICRO](https://www.dear-reality.com/products/dearvr-ambi-micro) (nicht mitgeliefert).
- Das Binaural-Skript (`Ambi_Create_Binaural_dearVR.lua`) nutzt dearVR AMBI MICRO nur, wenn dearVR installiert ist; sonst verwendet es den IEM BinauralDecoder.
- dearVR AMBI MICRO verarbeitet nur 16 ch (3. Ordnung), der IEM BinauralDecoder bis 7. Ordnung.
- Gemeinsame Funktionen: `Scripts/ICST/Ambi/lib/ambi_common.lua`, `Scripts/ICST/Animator/lib/animator_common.lua`.
- CSV-Spalten: `type,index,name,start_s,end_s,length_s` (Sekunden, Dezimalpunkt).

VST ist eine Marke der Steinberg Media Technologies GmbH. REAPER ist ein Produkt von Cockos Incorporated.

