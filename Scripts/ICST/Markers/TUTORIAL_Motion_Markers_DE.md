# Motion Markers – Schritt für Schritt

Bewegungen zwischen zwei Ambi-Markern über OSC an den ICST AmbiEncoder senden oder als Automation aufnehmen.

## 0. Einmalige Vorbereitung

1. **Python 3 + python-osc** installieren (Terminal):
   `python3 -m pip install python-osc`
2. **REAPER Web-Interface aktivieren** (nur für „Record"): Einstellungen (Cmd+,) → Control/OSC/web → Add → *Web browser interface* → Port **8080**.
3. Im Projekt eine Spur mit dem **ICST AmbiEncoder** anlegen. Seine OSC-In-Einstellung muss auf Port **50001** stehen (Host 127.0.0.1).

## 1. Marker setzen

Marker oder Projektmarker mit Namen nach dem Muster
`ambi <Index> a=<Azimut> e=<Elevation> d=<Distanz>`
anlegen, z. B. `ambi 1 a=-45 e=0 d=0.8`.
Alternative: CSV importieren – Toolbar-Icon *Import Ambi Markers From CSV* (Beispiele im Ordner `examples/`).

## 2. GUI starten

Toolbar-Icon *Motion Markers* klicken (oder Actions → `JS_Ambi_Motion_Marker_GUI.lua`).
Läuft schon eine Instanz: im Dialog **Terminate instances** wählen und neu starten.

## 3. Felder prüfen

| Feld | Wert |
|---|---|
| Ambi host | `127.0.0.1` (keine Leerzeichen!) |
| Ambi port | `50001` |
| Steps/sec | `40` |
| Python | leer lassen (automatische Erkennung); sonst vollen Pfad, z. B. `/Users/<name>/.pyenv/versions/3.11.8/bin/python3` |

## 4. Markerpaar wählen

1. In der Liste **Ambi Markers** linksklicken = Start (S), rechtsklicken = Ende (E). Oder mit **< Pair / Pair >** blättern.
2. **Set Selection** setzt die Zeitauswahl zwischen S und E. Unten steht die Dauer und Start/Ende der Bewegung.
3. Kurve wählen (Smoothstep, Linear, …).

## 5. Abspielen oder aufnehmen

- **Send pair**: Bewegung live per OSC an den AmbiEncoder, Cursor läuft mit.
- **Send series**: alle Paare nacheinander.
- **Record pair / Record series**: schreibt die Bewegung als Automation auf die AmbiEncoder-Spur (braucht Web-Interface, Port 8080).
- **Stop transport**: bricht ab.

## 6. Fehlerbehebung

| Meldung | Lösung |
|---|---|
| `No module named 'pythonosc'` | `python3 -m pip install python-osc`; Skript neu starten (Terminate instances) |
| `[Errno 8] nodename nor servname` | Leerzeichen im Feld *Ambi host* entfernen |
| Record tut nichts | Web-Interface (Port 8080) aktivieren |
| Bewegung zu hören fehlt | AmbiEncoder OSC-In auf 50001, Spur nicht stummgeschaltet |
| Alte Meldungen bleiben | Script beenden (*Terminate instances*) und neu starten |

Tipp: **Console ON** zeigt Meldungen im ReaScript-Konsolenfenster.
