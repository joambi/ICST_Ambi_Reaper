-- @description ICST Ambi Reaper: Startpruefung des Plug-in-Pfads (portabler Ordner)
-- Wird von Scripts/__startup.lua aufgerufen. Prueft nur, schreibt nichts:
-- 1) zeigt der VST-Pfad auf <dieser Ordner>/Effects/VST3?  2) hat REAPER AmbiEncoder_64 schon eingelesen?
local res = reaper.GetResourcePath()
local ini = reaper.get_ini_file()
if ini ~= res .. "/reaper.ini" then return end                      -- nur portable Installation
local want = res .. "/Effects/VST3"
local probe = io.open(want .. "/AmbiEncoder_64ch.vst3/Contents/Info.plist", "r")
if not probe then return end                                         -- kein ICST-Bundle
probe:close()

local arm = reaper.GetAppVersion():find("arm64", 1, true) ~= nil
local key = arm and "vstpath_arm64" or "vstpath"
local cache = res .. (arm and "/reaper-vstplugins_arm64.ini" or "/reaper-vstplugins64.ini")

local function read(p) local f = io.open(p, "r"); if not f then return nil end; local t = f:read("a"); f:close(); return t end
local txt = read(ini) or ""
local cur = txt:match("\n" .. key .. "=([^\r\n]*)") or txt:match("^" .. key .. "=([^\r\n]*)") or ""

local function contains(list, path)
  for p in (list .. ";"):gmatch("([^;]*);") do
    if p:gsub("/+$", "") == path then return true end
  end
  return false
end

if not contains(cur, want) then
  reaper.MB("Der Plug-in-Pfad zeigt nicht auf diesen Ordner:\n\n  " .. (cur ~= "" and cur or "(leer)") ..
    "\n\nErwartet:\n  " .. want ..
    "\n\nDer Ordner wurde vermutlich verschoben oder das Laufwerk umbenannt. REAPER beenden und " ..
    "'ICST_Ambi_Reaper starten.command' in diesem Ordner verwenden (setzt den Pfad und startet REAPER).",
    "ICST Ambi Reaper", 0)
  return
end

local c = read(cache) or ""
if not c:lower():find("ambiencoder_64ch.vst3", 1, true) then
  reaper.MB("Die ICST-Plug-ins sind noch nicht eingelesen (AmbiEncoder_64 fehlt in der Plug-in-Liste).\n\n" ..
    "Preferences > Plug-ins > VST > Re-scan... > 'Clear cache and re-scan' ausfuehren.\n" ..
    "Falls sie danach weiter fehlen: 'ICST_Ambi_Reaper starten.command' (entfernt das Quarantaene-Flag) verwenden.",
    "ICST Ambi Reaper", 0)
end
