-- REAPER fuehrt diese Datei beim Start aus. ICST: Plug-in-Pfad des portablen Ordners pruefen.
local ok, err = pcall(dofile, reaper.GetResourcePath() .. "/Scripts/ICST/ICST_Startup_Check.lua")
if not ok then reaper.ShowConsoleMsg("ICST Startup-Check: " .. tostring(err) .. "\n") end
-- ICST: Toolbar ICST_Ambi_Automation beim ersten Start oeffnen
local ok2, err2 = pcall(dofile, reaper.GetResourcePath() .. "/Scripts/ICST/ICST_Open_Toolbar.lua")
if not ok2 then reaper.ShowConsoleMsg("ICST Toolbar: " .. tostring(err2) .. "\n") end
