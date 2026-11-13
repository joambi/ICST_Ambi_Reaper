-- @description ICST Animator: Animator Choreographer starten (macOS und Windows)
-- macOS:   zuerst <REAPER-Ordner>/Animator/<Name>.app (portabel), dann installierte App (open -a).
-- Windows: zuerst <REAPER-Ordner>\Animator\<Name>.exe (portabel), dann installierte App
--          (%LOCALAPPDATA%\Programs\<Name>, %ProgramFiles%\<Name>).
-- App-Name ueber ExtState "ICST_Animator/app_name" aenderbar (Standard: Animator Choreographer)

local script_dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local C = dofile(script_dir .. "/lib/animator_common.lua")

local app = C.get_setting("app_name", C.DEFAULT_APP_NAME)
local res = reaper.GetResourcePath()
local is_win = reaper.GetOS():match("^Win") ~= nil

local function exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

if is_win then
  local candidates = { res .. "\\Animator\\" .. app .. ".exe",
                       res .. "\\Animator\\" .. app .. "\\" .. app .. ".exe" }
  for _, base in ipairs({ os.getenv("LOCALAPPDATA") and (os.getenv("LOCALAPPDATA") .. "\\Programs"),
                          os.getenv("ProgramFiles"), os.getenv("ProgramFiles(x86)") }) do
    if base then candidates[#candidates + 1] = base .. "\\" .. app .. "\\" .. app .. ".exe" end
  end
  local found
  for _, p in ipairs(candidates) do
    if exists(p) then found = p break end
  end
  if found then
    -- timeout -1: im Hintergrund starten, nicht auf das Ende der App warten
    reaper.ExecProcess('"' .. found .. '"', -1)
  else
    C.msg('App "' .. app .. '" nicht gefunden.\n\nGesucht in:\n' .. table.concat(candidates, "\n") ..
          '\n\nWindows-Version installieren (Animator-Choreographer-<Version>-Windows-Setup.exe) oder ' ..
          'als "' .. app .. '.exe" in den Ordner Animator im REAPER-Ordner legen.\n' ..
          'Siehe Dokumentation (Button 21), Kapitel 5.\n\n' ..
          'Anderer Name: reaper.SetExtState("ICST_Animator","app_name","<Name>",true)')
  end
  return
end

local bundled = res .. "/Animator/" .. app .. ".app"
local cmd
if exists(bundled .. "/Contents/Info.plist") then
  cmd = '/usr/bin/open "' .. bundled .. '"'
else
  cmd = '/usr/bin/open -a "' .. app .. '"'
end

local out = reaper.ExecProcess(cmd, 5000)
-- ExecProcess liefert "<exitcode>\n<output>"
local code = tonumber(tostring(out or ""):match("^(%-?%d+)"))
if code ~= 0 then
  C.msg('App "' .. app .. '" konnte nicht gestartet werden.\n\n' ..
        'Erwartet in: ' .. bundled .. '\noder installiert in /Applications.\n' ..
        'Siehe Dokumentation (Button 21), Kapitel 5.\n\n' ..
        'Anderer Name: reaper.SetExtState("ICST_Animator","app_name","<Name>",true)\n\n' ..
        tostring(out))
end
