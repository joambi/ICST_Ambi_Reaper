-- REAPER fuehrt diese Datei beim Start aus. ICST: Plug-in-Pfad des portablen Ordners pruefen.
local ok, err = pcall(dofile, reaper.GetResourcePath() .. "/Scripts/ICST/ICST_Startup_Check.lua")
if not ok then reaper.ShowConsoleMsg("ICST Startup-Check: " .. tostring(err) .. "\n") end
