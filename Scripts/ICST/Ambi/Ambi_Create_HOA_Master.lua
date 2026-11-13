-- @description ICST Ambi: HOA_MASTER-Spur anlegen (Sammelspur aller B-Format-Streams, 64 Kanaele)
-- Signalfluss mit Master:  Player / AmbiGran / Encoder  ->  [AmbiIRVerb / HOA-FX]  ->  HOA_MASTER  ->  Decoder und Binaural
-- Die Spur hat keine FX (hier koennen z.B. SceneRotator, MultiEQ oder OmniCompressor fuer die Summe eingesetzt werden).
-- Master-Send ist aus; Ambi_Auto_Route legt die Sends Quellen -> HOA_MASTER -> Decoder/Binaural.
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)

-- Bestehende HOA_MASTER-Spur wiederverwenden (nur eine Sammelspur pro Projekt)
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  local _, name = reaper.GetTrackName(tr)
  if name == A.MASTER_NAME then
    reaper.SetOnlyTrackSelected(tr)
    A.msg("Es gibt bereits eine Spur \"" .. A.MASTER_NAME .. "\" (Spur " .. (i + 1) .. "). Sie wurde selektiert.")
    return
  end
end

reaper.Undo_BeginBlock()
local tr = A.new_track(A.MASTER_NAME, nch)
A.color_track(tr, "master")
reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)   -- geht ueber Sends an Decoder / Binaural
reaper.SetOnlyTrackSelected(tr)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: HOA_MASTER anlegen", -1)
