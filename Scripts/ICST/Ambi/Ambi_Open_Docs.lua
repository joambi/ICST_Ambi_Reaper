-- @description ICST Ambi: Dokumentation oeffnen
-- Oeffnet Docs/docs_url.txt (erste Zeile, z. B. https://...) falls vorhanden und nicht leer,
-- sonst die lokale Doku Docs/index.html. Pfad relativ zum REAPER-Ordner (portabel).

local res = reaper.GetResourcePath()
local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local url = ""
local f = io.open(res .. "/Docs/docs_url.txt", "r")
if f then
  url = trim((f:read("*l") or ""))
  f:close()
end

local target
if url:match("^https?://") then
  target = url
else
  local local_path = res .. "/Docs/index.html"
  local t = io.open(local_path, "r")
  if not t then
    reaper.MB("Dokumentation nicht gefunden:\n" .. local_path, "ICST Ambi Docs", 0)
    return
  end
  t:close()
  target = local_path
end

if reaper.CF_ShellExecute then
  reaper.CF_ShellExecute(target)
else
  reaper.ExecProcess('/usr/bin/open "' .. target .. '"', 5000)
end
