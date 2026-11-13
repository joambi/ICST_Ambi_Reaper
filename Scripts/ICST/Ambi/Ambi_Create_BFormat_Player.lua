-- @description ICST Ambi: B-Format-Player-Spur (1/3/5/7. Ordnung) mit optionaler Datei
-- Legt Spur "BFormat_Player_<n>OA" mit passender Kanalzahl an (1OA=4, 3OA=16, 5OA=36, 7OA=64)
-- und fuegt auf Wunsch eine Mehrkanal-Datei am Edit-Cursor ein (Abbrechen = leere Spur).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)

reaper.Undo_BeginBlock()
local tr = A.new_track("BFormat_Player_" .. order .. "OA", nch)
A.color_track(tr, "player")
reaper.SetOnlyTrackSelected(tr)

local ok, file = reaper.GetUserFileNameForRead("", "B-Format-Datei waehlen (Abbrechen = leere Spur)", ".wav")
local note
if ok and file ~= "" then
  reaper.InsertMedia(file, 0)   -- 0 = auf ausgewaehlte Spur am Edit-Cursor
  local item = reaper.GetTrackMediaItem(tr, reaper.CountTrackMediaItems(tr) - 1)
  local take = item and reaper.GetActiveTake(item)
  local src = take and reaper.GetMediaItemTake_Source(take)
  local fch = src and reaper.GetMediaSourceNumChannels(src)
  if fch and fch > nch then
    note = "Die Datei hat " .. fch .. " Kanaele, die Spur nur " .. nch .. "."
  end
end
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ICST Ambi: B-Format-Player-Spur anlegen", -1)
if note then A.msg(note) end
