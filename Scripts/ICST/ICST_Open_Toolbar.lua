-- @description ICST Ambi Reaper: Toolbar ICST_Ambi_Automation beim ersten Start oben im Hauptfenster zeigen
-- Wird von Scripts/__startup.lua aufgerufen, einmal pro REAPER-Ordner.
-- reaper.ini im Bundle enthaelt toolbar:header=0 (Toolbar 1 sitzt oben im Hauptfenster).
-- Das Skript blendet diesen Bereich ein. Die Aktion 41679 (Open/close toolbar 1) wuerde die
-- Toolbar dagegen als schwebendes Fenster oeffnen; sie dient nur als Rueckfall.
-- Danach merkt sich REAPER selbst die Position; wer sie aendert oder schliesst, bekommt sie nicht wieder aufgedraengt.
local SECTION, KEY = "ICST_Ambi_Reaper", "toolbar_autoopen_done"
if reaper.GetExtState(SECTION, KEY) == "1" then return end

local function find_cmd(name)
  for id = 1, 65535 do
    if reaper.kbd_getTextFromCmd(id, 0) == name then return id end
  end
end

local TOP_NAME = "Toolbar: Show/hide toolbar at top of main window"
local TOP = 41297                                      -- REAPER 7.85
if reaper.kbd_getTextFromCmd(TOP, 0) ~= TOP_NAME then TOP = find_cmd(TOP_NAME) end
if TOP then
  if reaper.GetToggleCommandState(TOP) ~= 1 then reaper.Main_OnCommand(TOP, 0) end
else
  local CMD = 41679                                  -- Toolbar: Open/close toolbar 1
  if (reaper.kbd_getTextFromCmd(CMD, 0) or "") == "" then return end
  if reaper.GetToggleCommandState(CMD) ~= 1 then reaper.Main_OnCommand(CMD, 0) end
end
reaper.SetExtState(SECTION, KEY, "1", true)
