-- @description ICST Ambi: neue Spur (64 Kanaele) mit AmbiEncoder anlegen
-- 2026-11-11: legt immer eine neue Spur an (nicht mehr auf selektierte Spuren), 64 Kanaele.
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)   -- 1OA=4, 3OA=16, 5OA=36, 7OA=64

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local targets = { A.new_track("Ambi_Encoder", nch) }   -- immer neue Spur

local failed = 0
for _, tr in ipairs(targets) do
  reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", nch)
  A.color_track(tr, "encoder")
  local fx = A.add_fx(tr, A.FX_ENCODER, A.not_64)   -- _64-Variante hat eigenes Script
  if not fx then failed = failed + 1 end
end
reaper.SetOnlyTrackSelected(targets[1])
reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: AmbiEncoder anlegen", -1)

if failed > 0 then
  A.msg("AmbiEncoder wurde auf " .. failed .. " Spur(en) nicht gefunden (VST3 nicht installiert/gescannt oder nur _64 vorhanden).")
end
