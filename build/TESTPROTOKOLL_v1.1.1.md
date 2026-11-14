# Testprotokoll ICST_Ambi_Reaper v1.1.1 (macOS)

Getestet am 14.11.2026 von Johannes Schütt. Testgerät: Mac mit Apple Silicon, macOS, REAPER 7.85.

Paket: `ICST_Ambi_Reaper_1.1.1_macOS.pkg` aus dem Release [v1.1.1](https://github.com/joambi/ICST_Ambi_Reaper/releases/tag/v1.1.1), SHA-256 `265c39743b328b3a9112b1c5ed06bd7480f1ffec2d593b3e28e41a28489894e0`. Gebaut aus Commit `0807384`; die Hinweise aus PR #13 (Scan abbrechen) sind im Paket noch nicht enthalten.

## Ablauf

1. Vorhandenen Ordner `/Applications/ICST_Ambi_Reaper` nach `~/ICST_Ambi_Reaper_vor_Neuinstallation` verschoben.
2. PKG installiert, `REAPER.app` (7.85) in den Ordner gelegt.
3. Start mit `ICST_Ambi_Reaper starten.command`.

## Ergebnisse

| Prüfung | Ergebnis |
|---|---|
| Toolbar *ICST_Ambi_Automation* | erscheint beim ersten Start fest oben im Hauptfenster |
| Frage *New portable install detected …* | erschien nicht |
| Plug-in-Pfad beim ersten Start | REAPER hängte `/Library/Audio/Plug-Ins/VST3` und `~/Library/Audio/Plug-Ins/VST3` an und begann zu scannen |
| Scan abbrechen | im Fortschrittsfenster möglich |
| Plug-in-Pfad nach Neustart über `.command` | nur `Effects/VST3`, auch nach Cmd-Q und erneutem Start |
| Quick Start (Button 1), Vorgabe `4,n,n,j,j` | legt `Src_01`–`Src_04`, `Ambi_Encoder_64`, `HOA_MASTER`, Decoder und Binaural samt Routing an |
| Wiedergabe und Bewegung im AmbiEncoder_64 | in Ordnung |
| Quick Start mit HOA_Reverb `j` | Spur `HOA_Reverb` mit IEM FdnReverb wird angelegt |
| Animator (Button 16) | startet den Animator Choreographer |

## Verhalten des PKG bei vorhandenen Einstellungen

Das PKG überschreibt `reaper.ini`, `reaper-kb.ini`, `reaper-menu.ini`, `reaper-mouse.ini` und `reapack.ini` (alle im Payload). Im Test ging dadurch das eingestellte Audiogerät verloren. `reaper-extstate.ini`, der Plug-in-Cache und die übrigen Laufzeitdateien bleiben erhalten.

## Nicht getestet

- Bundle-ZIP (`…_macOS.zip`) mit `run-me-before-install.command`, z. B. auf einer externen SSD
- Intel-Mac
- Windows (`…_scripts-only.zip`)

## Folgerungen für v1.1.2

- PKG: `reaper.ini` nur installieren, wenn keine vorhanden ist; sonst nur `toolbar:header=0` und den Plug-in-Pfad setzen.
- Pakete aus dem aktuellen `main` bauen, damit Tag und Paketinhalt übereinstimmen.
