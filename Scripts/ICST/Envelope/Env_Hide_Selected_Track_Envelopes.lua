-- 06_Hide_Selected_Envelopes.lua (V4.1-Fix)
-- Blendet alle sichtbaren FX-Parameter-Envelopes der SELEKTIERTEN Tracks aus.
-- Die Envelope-Punkte bleiben erhalten - nur die Lanes verschwinden aus dem TCP.
-- Fix: SetEnvelopeInfo_Value existiert in dieser REAPER-Version nicht;
-- Sichtbarkeit wird deshalb ueber den Envelope-State-Chunk gesetzt.

if reaper.CountSelectedTracks(0) == 0 then
  reaper.ShowMessageBox("Bitte zuerst einen Track selektieren.", "HIDE ENV", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local hidden = 0
for t = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, t)
  for e = 0, reaper.CountTrackEnvelopes(tr) - 1 do
    local env = reaper.GetTrackEnvelope(tr, e)
    local ok, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
    -- nur FX-Parameter-Envelopes (<PARMENV), Volume/Pan/Send bleiben unangetastet
    if ok and chunk:match("^<PARMENV") and chunk:match("\nVIS 1") then
      chunk = chunk:gsub("\nVIS 1", "\nVIS 0", 1)
      reaper.SetEnvelopeStateChunk(env, chunk, false)
      hidden = hidden + 1
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock(("Hide FX envelopes on selected tracks (%d)"):format(hidden), -1)

if hidden == 0 then
  reaper.ShowMessageBox("Keine sichtbaren FX-Envelopes auf den selektierten Tracks gefunden.", "HIDE ENV", 0)
end
