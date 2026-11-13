-- 18_Toggle_Envelope_Shape_Expo_Linear.lua (V4.1 - neu erstellt, Original lag
-- im geloeschten Desktop-Ordner ICST_Ambi_Demo)
-- Schaltet die Punkt-Form der SELEKTIERTEN Envelope um: Linear <-> Bezier.
-- Mit Time-Selection: nur Punkte darin; ohne: alle Punkte der Envelope.
local env = reaper.GetSelectedEnvelope(0)
if not env then
  reaper.ShowMessageBox("Bitte zuerst eine Envelope selektieren (Lane anklicken).", "Envelope Shape", 0)
  return
end
local ts, te = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
local use_ts = te > ts
reaper.Undo_BeginBlock()
local cnt = reaper.CountEnvelopePoints(env)
local changed, to_bezier = 0, nil
for i = 0, cnt - 1 do
  local ok, t, v, shape, tens, sel = reaper.GetEnvelopePoint(env, i)
  if ok and (not use_ts or (t >= ts and t <= te)) then
    if to_bezier == nil then to_bezier = (shape == 0) end -- Richtung vom ersten Punkt ableiten
    reaper.SetEnvelopePoint(env, i, t, v, to_bezier and 5 or 0, 0, sel, true)
    changed = changed + 1
  end
end
reaper.Envelope_SortPoints(env)
reaper.UpdateArrange()
reaper.Undo_EndBlock(("Toggle envelope shape (%d points -> %s)"):format(changed, to_bezier and "Bezier" or "Linear"), -1)
