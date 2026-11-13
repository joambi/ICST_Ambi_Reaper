-- JS_Delete_Ambisonics_Automation_In_TimeSelection.lua
-- Loescht Envelope-Punkte innerhalb der Time-Selection auf allen
-- FX-PARAMETER-Envelopes (z.B. ICST AmbiEncoder X/Y/Z) der selektierten Tracks.
-- Volume/Pan/Mute/Send-Envelopes bleiben unangetastet.
--
-- V4.1-Fix: die alte Version filterte mit GetEnvelopeInfo_Value("B_VISIBLE"/"B_ARM");
-- diese Parameter existieren in der API nicht (liefern immer 0), daher wurde nie
-- etwas geloescht. Jetzt werden FX-Envelopes am Chunk-Typ (<PARMENV) erkannt.

local start_t, end_t = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
if end_t <= start_t then
  reaper.ShowMessageBox("Bitte zuerst eine Time Selection erstellen.", "Delete Ambi Auto", 0)
  return
end

if reaper.CountSelectedTracks(0) == 0 then
  reaper.ShowMessageBox("Bitte zuerst den Encoder-Track selektieren.", "Delete Ambi Auto", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local touched, points = 0, 0
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  for e = 0, reaper.CountTrackEnvelopes(tr) - 1 do
    local env = reaper.GetTrackEnvelope(tr, e)
    local ok, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
    -- nur FX-Parameter-Envelopes (<PARMENV ...), keine Volume/Pan/Mute/Send
    if ok and chunk:match("^<PARMENV") then
      local before = reaper.CountEnvelopePoints(env)
      reaper.DeleteEnvelopePointRange(env, start_t, end_t)
      reaper.Envelope_SortPoints(env)
      local after = reaper.CountEnvelopePoints(env)
      if after < before then
        touched = touched + 1
        points = points + (before - after)
      end
    end
  end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(("Delete Ambisonics automation in time selection (%d env, %d points)"):format(touched, points), -1)

if touched == 0 then
  reaper.ShowMessageBox(
    "Keine FX-Automation im gewaehlten Bereich gefunden.\n\n"..
    "Pruefen: Ist der richtige Track (ICST AmbiEncoder) selektiert\n"..
    "und liegt die Automation innerhalb der Time-Selection?",
    "Delete Ambi Auto", 0)
end
