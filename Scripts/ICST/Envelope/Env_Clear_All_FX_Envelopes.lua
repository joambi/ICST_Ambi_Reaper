-- 20_Clear_All_FX_Envelopes_On_Selected_Tracks.lua
-- Ambisonics Composer Toolbar V2
--
-- Iterates through every SELECTED track, walks each FX on the track, and
-- for each FX parameter deletes the associated FX-parameter envelope:
--   * removes all envelope points
--   * hides the envelope lane
--   * disarms it
--
-- REAPER's API cannot destroy the envelope record itself, but an empty,
-- hidden, disarmed lane is functionally equivalent to "gone".
--
-- Order: track selection order -> FX order (0..N) -> param order (0..N).

local r = reaper

local sel_count = r.CountSelectedTracks(0)
if sel_count == 0 then
  r.ShowMessageBox("Bitte mindestens einen Track selektieren.", "Clear FX Envelopes", 0)
  return
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local total_tracks   = 0
local total_fx       = 0
local total_envs     = 0
local total_points   = 0

for t = 0, sel_count - 1 do
  local tr = r.GetSelectedTrack(0, t)
  total_tracks = total_tracks + 1

  local fx_count = r.TrackFX_GetCount(tr)
  for fx = 0, fx_count - 1 do
    total_fx = total_fx + 1

    local param_count = r.TrackFX_GetNumParams(tr, fx)
    for p = 0, param_count - 1 do
      -- create=false: only touch envelopes that already exist
      local env = r.GetFXEnvelope(tr, fx, p, false)
      if env then
        local pts = r.CountEnvelopePoints(env)
        if pts > 0 then
          for idx = pts - 1, 0, -1 do
            r.DeleteEnvelopePointEx(env, -1, idx)
          end
          total_points = total_points + pts
        end
        -- Hide + disarm via the state chunk (works on every REAPER version).
        -- SetEnvelopeInfo_Value only exists on REAPER >= 6.28, so we don't use it.
        local ok, chunk = r.GetEnvelopeStateChunk(env, "", false)
        if ok and chunk then
          local c = chunk:gsub("\nVIS %d+ %d+ %d+", "\nVIS 0 0 0", 1)
                         :gsub("\nARM %d+",         "\nARM 0",     1)
          r.SetEnvelopeStateChunk(env, c, false)
        end
        total_envs = total_envs + 1
      end
    end
  end

  r.TrackList_AdjustWindows(false)
end

r.PreventUIRefresh(-1)
r.UpdateArrange()
r.Undo_EndBlock(
  ("Clear FX envelopes: %d track(s), %d FX, %d env, %d pts")
    :format(total_tracks, total_fx, total_envs, total_points), -1)

r.ShowConsoleMsg(
  ("[Clear FX Envelopes] tracks=%d  fx=%d  envelopes=%d  points_removed=%d\n")
    :format(total_tracks, total_fx, total_envs, total_points))
