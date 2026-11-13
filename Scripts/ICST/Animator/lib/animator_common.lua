-- @description ICST Animator Choreographer: gemeinsame Funktionen
-- Alle Pfade relativ zum REAPER-Resource-Path (portabel). Einstellungen via ExtState.

local M = {}

M.EXT_SECTION = "ICST_Animator"
M.DEFAULT_APP_NAME = "Animator Choreographer"
M.ENCODER_FX = "VST3: AmbiEncoder_64 (ICST)"   -- Substring-Match, nur VST3
M.ENCODER_PREFIX = "Encoder_"
M.ENCODER_COLOR = { 230, 95, 60 }   -- wie AmbiEncoder_64 in den Ambi-Scripts

function M.resource_path()
  return reaper.GetResourcePath()
end

function M.get_setting(key, default)
  local v = reaper.GetExtState(M.EXT_SECTION, key)
  if v == nil or v == "" then return default end
  return v
end

function M.set_setting(key, value)
  reaper.SetExtState(M.EXT_SECTION, key, tostring(value), true)
end

function M.msg(text)
  reaper.ShowMessageBox(text, "ICST Animator", 0)
end

-- Ordner fuer Exporte: neben dem Projekt, sonst <Resource>/Exports
function M.export_dir()
  local _, proj_path = reaper.EnumProjects(-1, "")
  local dir
  if proj_path and proj_path ~= "" then
    dir = proj_path:match("^(.*)[/\\][^/\\]*$")
  end
  if not dir or dir == "" then
    dir = M.resource_path() .. "/Exports"
  end
  reaper.RecursiveCreateDirectory(dir, 0)
  return dir
end

function M.project_name()
  local _, proj_path = reaper.EnumProjects(-1, "")
  local name = proj_path and proj_path:match("([^/\\]+)%.[Rr][Pp][Pp]$")
  return name or "Untitled"
end

function M.csv_escape(s)
  s = tostring(s or "")
  if s:find('[",\n\r]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end

-- Gibt sortierte Liste {type, index, name, start, end} zurueck (Regionen + Marker)
function M.collect_regions_markers()
  local list = {}
  local i = 0
  while true do
    local ret, isrgn, pos, rgnend, name, idx = reaper.EnumProjectMarkers3(0, i)
    if ret == 0 then break end
    list[#list + 1] = {
      type = isrgn and "region" or "marker",
      index = idx, name = name or "",
      start = pos, stop = isrgn and rgnend or pos,
    }
    i = i + 1
  end
  table.sort(list, function(a, b)
    if a.start == b.start then return a.index < b.index end
    return a.start < b.start
  end)
  return list
end

return M
