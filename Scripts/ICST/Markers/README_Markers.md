# ICST Ambi Motion Markers Bundle

This bundle contains the files needed for the `ICST Ambi Motion Markers`
workflow in REAPER.

## Included

- `JS_Ambi_Motion_Marker_GUI.lua`
- `JS_Import_Ambi_Markers_From_CSV.lua`
- `reaper_marker_ambi_motion.py`
- `ambi_markers_aed_example.csv`
- `ambi_markers_xyz_example.csv`
- `ICST_Ambi_Motion_Markers_Handbook.md`

## Installation

1. Import `JS_Ambi_Motion_Marker_GUI.lua` into REAPER
2. Import `JS_Import_Ambi_Markers_From_CSV.lua` into REAPER
3. Install Python dependency:

```bash
pip install python-osc
```

4. Set your Python path in the GUI
5. Enable OSC input in `AmbiEncoder_64`
6. Match the OSC port, typically `50001`
