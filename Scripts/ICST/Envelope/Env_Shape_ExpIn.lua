-- @description Ambi Env Shape: Fast start (exponential in)
-- @author jsambi / Claude
-- @version 1.0
-- @about
--   Setzt die Kurvenform der Punkte des aktiven (selektierten) Envelopes.
--   Priorität: selektierte Punkte > Punkte in der Time Selection > alle Punkte.
--   Automation Items auf dem Envelope werden mitbehandelt.
--   Fallback ohne selektierten Envelope: Envelope unter der Maus (SWS/BR).

local SHAPE = 3          -- 0 lin, 1 square, 2 slow start/end, 3 fast start, 4 fast end, 5 bezier
local LABEL = "Fast start (exponential in)"
local TENSION = 0.0          -- nur für Bezier relevant (-1 .. 1)

local env = reaper.GetSelectedEnvelope(0)
if not env and reaper.BR_GetMouseCursorContext then
  reaper.BR_GetMouseCursorContext()
  env = reaper.BR_GetMouseCursorContext_Envelope()
end
if not env then
  reaper.MB("Kein Envelope aktiv.\nEnvelope anklicken (oder Maus darüber halten) und erneut ausführen.", "Ambi Env Shape", 0)
  return
end

local ts0, ts1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
local has_ts = ts1 > ts0

local function process(ai)
  local n = reaper.CountEnvelopePointsEx(env, ai)
  if n == 0 then return 0 end
  local any_sel = false
  for i = 0, n - 1 do
    local _, _, _, _, _, sel = reaper.GetEnvelopePointEx(env, ai, i)
    if sel then any_sel = true break end
  end
  local changed = 0
  for i = 0, n - 1 do
    local _, t, v, _, _, sel = reaper.GetEnvelopePointEx(env, ai, i)
    local hit
    if any_sel then hit = sel
    elseif has_ts then hit = (t >= ts0 and t <= ts1)
    else hit = true end
    if hit then
      reaper.SetEnvelopePointEx(env, ai, i, t, v, SHAPE, TENSION, sel, true)
      changed = changed + 1
    end
  end
  reaper.Envelope_SortPointsEx(env, ai)
  return changed
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local total = process(-1)
for ai = 0, reaper.CountAutomationItems(env) - 1 do
  total = total + process(ai)
end
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Envelope shape -> " .. LABEL .. " (" .. total .. " Punkte)", -1)
