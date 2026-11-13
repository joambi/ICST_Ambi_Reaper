-- 17_Clear_AmbiEncoder_Envelopes_Selected_Tracks.lua (V4.1 - neu erstellt,
-- Original lag im geloeschten Desktop-Ordner ICST_Ambi_Demo)
-- Loescht alle Envelope-Punkte der ICST-AmbiEncoder-FX auf den selektierten Tracks.
if reaper.CountSelectedTracks(0) == 0 then
  reaper.ShowMessageBox("Bitte zuerst einen Track selektieren.", "Clear AmbiEncoder Envelopes", 0)
  return
end
reaper.Undo_BeginBlock()
local cleared = 0
for t = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, t)
  for e = reaper.CountTrackEnvelopes(tr) - 1, 0, -1 do
    local env = reaper.GetTrackEnvelope(tr, e)
    local _, fxidx = reaper.Envelope_GetParentTrack(env)
    if fxidx and fxidx >= 0 then
      local _, fxname = reaper.TrackFX_GetFXName(tr, fxidx, "")
      if fxname:lower():find("ambiencoder") then
        local n = reaper.CountEnvelopePoints(env)
        for i = n - 1, 0, -1 do reaper.DeleteEnvelopePointEx(env, -1, i) end
        reaper.Envelope_SortPoints(env)
        cleared = cleared + 1
      end
    end
  end
end
reaper.UpdateArrange()
reaper.Undo_EndBlock(("Clear AmbiEncoder envelopes (%d)"):format(cleared), -1)
