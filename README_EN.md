# ICST_Ambi_Reaper (installation and quick start)

Portable REAPER resource folder for ICST Ambisonics and the Animator Choreographer (7 November 2026).
Deutsche Fassung mit Toolbar-Tabelle: [README.md](README.md)

## 1. What is this?
A preconfigured [REAPER](https://www.reaper.fm) folder with toolbar, scripts, [VST3](https://steinbergmedia.github.io/vst3_dev_portal/) plug-ins (ICST, IEM) and documentation. It creates, connects, moves and decodes Ambisonics tracks (orders 1–7) with one click each. The full manual is `Docs/index.html` (toolbar button *Documentation*).

| | macOS | Windows |
|---|---|---|
| Status | complete, shipped as is | **beta, untested**; assembled from parts (see 3) |
| Plug-ins in the folder | yes (`Effects/VST3`, universal) | no, installers needed |
| REAPER extensions ([SWS](https://www.sws-extension.org), [js_ReaScriptAPI](https://forum.cockos.com/showthread.php?t=212174), [ReaPack](https://reapack.com)) | in the folder (`UserPlugins`, Apple Silicon only) | install yourself |
| Animator Choreographer (button 16) | yes (`Animator/`) | yes (installed app or `Animator\Animator Choreographer.exe`) |

## 2. Installation and quick start: macOS

**Download:** [GitHub Releases](https://github.com/joambi/ICST_Ambi_Reaper/releases) — `ICST_Ambi_Reaper_<version>_macOS.pkg` (installer to `/Applications/ICST_Ambi_Reaper`; copies an existing `/Applications/REAPER.app` into the folder and sets the plug-in path — then continue at step 4) or `…_macOS.zip` (portable, e.g. for an external SSD — steps 1–6). `…_scripts-only.zip` contains only the platform-neutral parts (Windows, section 3). **REAPER itself is not included for licensing reasons.** Unsigned PKG: double-click, close the message, then System Settings › Privacy & Security › **Open Anyway** and confirm with your password (macOS 15 and later; up to macOS 14, Ctrl-click › Open is enough).

**Requirements:** macOS 12 or newer, Apple Silicon recommended (on Intel Macs the extensions in `UserPlugins` are missing), REAPER 7 (tested with 7.85). Optional for the Motion Map tools: Python 3 (`xcode-select --install` in Terminal).

1. **Copy the folder** `ICST_Ambi_Reaper` to a fixed location (external SSD or `~/Music`). Spaces in the path are fine.
2. **Check REAPER.app.** If `REAPER.app` is not in the folder, download REAPER for macOS from [reaper.fm](https://www.reaper.fm) (same major version) and put it **inside `ICST_Ambi_Reaper`**, next to `reaper.ini`. This is what makes REAPER run portably from this folder.
3. **Setup script.** Double-click `run-me-before-install.command`. After a download macOS blocks it: close the message, then System Settings › Privacy & Security › **Open Anyway** and confirm with your password (macOS 15 and later; up to macOS 14, Ctrl-click › **Open** is enough). The script removes the macOS quarantine flag and points the plug-in path in `reaper.ini` to the current location. From then on, preferably always open REAPER with `ICST_Ambi_Reaper starten.command`: it points the plug-in path to the current location on every start (also on external drives with a different name) and starts `REAPER.app` from the folder. On startup REAPER additionally checks the path and the plug-in list and tells you what to do.
4. **Start REAPER** using the `REAPER.app` **from this folder**. If macOS warns: use the same **Open Anyway** path. Check: *Options › Show REAPER resource path in explorer/finder* must open `ICST_Ambi_Reaper`.
5. **Scan plug-ins.** *Options › Preferences › Plug-ins › VST*: the path ends in `Effects/VST3`; click **Re-scan** (if needed *Clear cache and re-scan*).
6. **Toolbar.** On the first start REAPER opens the toolbar *ICST_Ambi_Automation* by itself. Later, if it was closed: *View › Toolbars › Floating toolbar 1*.

**Do not install twice:** if the same plug-ins are also installed from the `.pkg` installers into `/Library/Audio/Plug-Ins/VST3`, REAPER may load the old copy from there. Use either the folder or the `.pkg` plug-ins, not both.

### First run (10 minutes)
1. Add a new track with a mono audio file. Click **Encoder 64** (red-orange) on that track: AmbiEncoder_64 is inserted.
2. Click **Decoder** (blue) for loudspeakers or **Binaural** (violet) for headphones.
3. Optional: **HOA FX** for IEM effects.
4. Click **Auto-Route**: the 16-channel sends sources › HOA FX › decoder/binaural are created.
5. Play and move the source in the encoder. To write movements use **[Motion Map GUI](https://ambisonics.ch/icst-ambisonics-plugins/15_icst_ambi_motion_map/)** / **Spat Motion Automation** (chapter 6 of the manual).

## 3. Installation and quick start: Windows (beta, untested)

The folder is a macOS bundle: the plug-ins in `Effects/VST3`, the files in `UserPlugins` and `Animator/` run on macOS only. On Windows only the platform-independent parts are taken over (scripts, icons, menu, docs) and the plug-ins are installed with installers. The scripts are mostly platform neutral (path and shell calls account for Windows); a full run on Windows is still pending.

**Requirements:** Windows 10/11 (64 bit), REAPER 7 (64 bit; only tested on macOS with 7.85), Python 3 from [python.org](https://www.python.org) (tick *Add python.exe to PATH*; only for Motion Map, [Motion Markers](https://ambisonics.ch/icst-ambisonics-plugins/14_icst_ambi_motion_markers/) and [Kristall Motion Map](https://ambisonics.ch/icst-ambisonics-plugins/18_kristall_motion_map/)).

1. **Install REAPER portable.** Run the REAPER installer, choose **Portable install** and a new folder, e.g. `C:\ICST_Ambi_Reaper`. Start REAPER there once and close it (it creates `reaper.ini`).
2. **Install extensions.** Install the *SWS Extension* ([sws-extension.org](https://www.sws-extension.org)) and *ReaPack* ([reapack.com](https://reapack.com)); in ReaPack *Browse packages* › install **js_ReaScriptAPI** (repository *ReaTeam Extensions*); restart REAPER.
3. **Copy the ICST parts** from the macOS folder into the new Windows folder (overwrite existing files):
   - `Scripts\ICST` (all of it)
   - `Data\toolbar_icons`
   - `Docs`, `OSC`, `ICST_Player_Presets`
   - `reaper-menu.ini` and `reaper-kb.ini` (toolbar and actions; harmless in a fresh portable install, in an existing install they replace your own toolbars)
   Do not copy: `Effects\VST3`, `UserPlugins`, `Animator`, `REAPER.app`, `run-me-before-install.command`, `ICST_Ambi_Reaper starten.command`, the other `.ini` files.
4. **Install the plug-ins** (into `C:\Program Files\Common Files\VST3`, which REAPER scans automatically):
   - *AmbiEncoder*, *AmbiEncoder_64*, *AmbiDecoder*: [ICST Ambisonics Plugins](https://ambisonics.ch/icst-ambisonics-plugins/) ([ambisonics.ch](https://ambisonics.ch))
   - *IEM Plug-in Suite* incl. BinauralDecoder: [plugins.iem.at](https://plugins.iem.at)
   The scripts find plug-ins by name, e.g. `AmbiEncoder_64 (ICST)`, `BinauralDecoder (IEM)`; REAPER must list them the same way on Windows.
5. **Start REAPER**, *Options › Preferences › Plug-ins › VST › Re-scan*, then *View › Toolbars › Floating toolbar 1*.
6. Continue with the **First run** in section 2.

**Notes for Windows:** button 16 (*Open Animator*) starts the installed Windows version of the app (`Animator-Choreographer-<version>-Windows-Setup.exe`) or `Animator\Animator Choreographer.exe` in the REAPER folder.

## 4. Troubleshooting

| Problem | Solution |
|---|---|
| Plug-ins missing (macOS) | Quit REAPER and restart it with `ICST_Ambi_Reaper starten.command`; otherwise Preferences › Plug-ins › VST › *Re-scan* › *Clear cache and re-scan* |
| Plug-in crashes or wrong version | Remove old copies in `/Library/Audio/Plug-Ins/VST3` or `~/Library/…`; copy the plug-in again and run `xattr -cr` / `codesign --force --deep --sign -` |
| Toolbar empty | *Options › Customize menus/toolbars*, check *Floating toolbar 1*; `reaper-menu.ini` and `reaper-kb.ini` must be in the resource folder |
| Script reports a missing function (`JS_…`, `BR_…`, `CF_…`) | Install SWS and js_ReaScriptAPI (Windows) or check `UserPlugins` (macOS) |
| Motion Map: “python3 not found” | Install Python 3 (see requirements) |
| Auto-Route does not find a track | The track needs a recognizable plug-in or “Player” in its name (chapter 4 of the manual) |

The binaural script (`Ambi_Create_Binaural_dearVR.lua`) uses dearVR AMBI MICRO only if dearVR is installed; otherwise it uses the IEM BinauralDecoder.

VST is a trademark of Steinberg Media Technologies GmbH. REAPER is a product of Cockos Incorporated.

