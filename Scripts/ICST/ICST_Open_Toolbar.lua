-- @description ICST Ambi Reaper: Toolbar ICST_Ambi_Automation beim ersten Start oeffnen
-- Wird von Scripts/__startup.lua aufgerufen. Oeffnet "Floating toolbar 1" einmal pro REAPER-Ordner.
-- Danach merkt sich REAPER selbst, ob die Toolbar offen ist; wer sie schliesst, bekommt sie nicht wieder aufgedraengt.
local SECTION, KEY = "ICST_Ambi_Reaper", "toolbar_autoopen_done"
if reaper.GetExtState(SECTION, KEY) == "1" then return end

local CMD = 41679                                    -- Toolbar: Open/close toolbar 1
if (reaper.kbd_getTextFromCmd(CMD, 0) or "") == "" then return end
if reaper.GetToggleCommandState(CMD) ~= 1 then reaper.Main_OnCommand(CMD, 0) end
reaper.SetExtState(SECTION, KEY, "1", true)
