-- @description ICST Animator: Regionen und Marker als CSV exportieren
-- Datei: <Projektordner>/Animator_<Projekt>_regions_markers.csv
-- Spalten: type,index,name,start_s,end_s,length_s  (Dezimalpunkt, Sekunden)

local script_dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local C = dofile(script_dir .. "/lib/animator_common.lua")

local items = C.collect_regions_markers()
if #items == 0 then
  C.msg("Keine Regionen oder Marker im Projekt.")
  return
end

local path = C.export_dir() .. "/Animator_" .. C.project_name() .. "_regions_markers.csv"
local f, err = io.open(path, "w")
if not f then
  C.msg("Datei konnte nicht geschrieben werden:\n" .. tostring(err))
  return
end

f:write("type,index,name,start_s,end_s,length_s\n")
for _, it in ipairs(items) do
  f:write(string.format("%s,%d,%s,%.6f,%.6f,%.6f\n",
    it.type, it.index, C.csv_escape(it.name), it.start, it.stop, it.stop - it.start))
end
f:close()

reaper.ClearConsole()
reaper.ShowConsoleMsg("Animator CSV: " .. path .. "  (" .. #items .. " Eintraege)\n")
C.set_setting("last_csv", path)
reaper.RecursiveCreateDirectory(path:match("^(.*)[/\\]"), 0)
