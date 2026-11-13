# Drittanbieter-Komponenten / Third-party components

Die ICST-eigenen Inhalte dieses Repositorys stehen unter GPL-3.0-or-later (`LICENSE`). Die folgenden Komponenten Dritter sind **nicht im Git-Repo**, sondern nur in den Release-Downloads (`…_macOS.zip`, `…_macOS.pkg`) enthalten bzw. werden auf Windows per Installer bezogen.

**Nicht enthalten:** REAPER (Cockos Inc., proprietär — <https://www.reaper.fm/download.php>; 60 Tage frei evaluierbar, danach Lizenz nötig), die REAPER-Standardthemes, -effekte und -icons (legt REAPER beim ersten Start selbst an), dearVR AMBI MICRO (Dear Reality, kommerziell).

## VST3-Plug-ins (`Effects/VST3`, nur Release)

| Plug-in | Autor | Lizenz | Quelle |
|---|---|---|---|
| AmbiEncoder_1ch, AmbiEncoder_64ch, AmbiDecoder_64ch (ICST Core) | ICST, ZHdK | GPL-3.0 | <https://github.com/schweizerweb/icst-ambisonics-plugins> |
| AmbiIRVerb, AmbiIRLayers, AmbiGran 16 (ICST Extended, Beta; AmbiGran = Port des BBDMI-Faust-Granulators) | ICST, ZHdK | Lizenz noch offen — Binaries unveraendert weitergegeben | <https://github.com/joambi/ICST-AmbiPlugins> |
| BinauralDecoder, SceneRotator, MultiEQ, ToolBox, DualDelay, FdnReverb, OmniCompressor, DirectionalCompressor, MultiBandCompressor, EnergyVisualizer, GranularEncoder | IEM, Kunstuniversität Graz | GPL-3.0 — Binaries unverändert weitergegeben, Quellcode öffentlich | <https://plugins.iem.at> · <https://git.iem.at/audioplugins/IEMPluginSuite> |

Lizenztext GPL-3.0: <https://www.gnu.org/licenses/gpl-3.0.html>

## REAPER-Erweiterungen (`UserPlugins`, nur Release)

| Erweiterung | Lizenz | Quelle |
|---|---|---|
| SWS/S&M Extension | MIT (Text: `licenses/SWS_LICENSE.txt`) | <https://github.com/reaper-oss/sws> |
| ReaImGui | LGPL-3.0 | <https://github.com/cfillion/reaimgui> |
| ReaPack | LGPL-3.0 | <https://github.com/cfillion/reapack> |
| js_ReaScriptAPI | MIT (Text: `licenses/js_ReaScriptAPI_LICENSE.txt`) | <https://github.com/juliansader/ReaExtensions> |
| GUtilities API | siehe Repo | <https://github.com/GuilhermeSBF/GUtilitiesAPI> |
| ReaBlink, ReaFab, ReaLlm, ReaMCULive, ReaSolotus | siehe jeweiliges Repo (ak5k) | <https://github.com/ak5k> |
| ReaStart | siehe Repo | ReaPack-Index |

## JSFX und Daten (im Repo)

| Komponente | Lizenz | Quelle |
|---|---|---|
| IRidesce (JSFX + Impulsantworten `Data/IRidesce`) | `Data/IRidesce/LICENSE-IRidesce.txt` | siehe Lizenzdatei |
| ICST JSFX (`Effects/ICST`) | GPL-3.0-or-later (`LICENSE`) | dieses Repo |

## Weitere Software (nur Release)

Animator Choreographer (`Animator/`): ICST, ZHdK.

Bitte Einträge mit „siehe Repo" vor einer öffentlichen Veröffentlichung einmal gegen die jeweilige Lizenzdatei prüfen.
