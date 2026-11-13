--[[
  ICST AmbiEncoder_64 — Dump Parameter Names
  ------------------------------------------
  Diagnostic: prints the first 40 VST parameter names of the ICST
  AmbiEncoder_64 on the selected track, so we can see the exact
  spelling (e.g. "X 1" vs "X1" vs "Point 1: X").

  Usage: select the encoder track, run this script, open View → Console.
--]]

local track = reaper.GetSelectedTrack(0, 0)
if not track then reaper.ShowConsoleMsg('No track selected.\n'); return end

local fx = -1
local fx_count = reaper.TrackFX_GetCount(track)
for i = 0, fx_count - 1 do
  local _, name = reaper.TrackFX_GetFXName(track, i, '')
  if name:lower():find('ambiencoder') then fx = i; break end
end
if fx < 0 then reaper.ShowConsoleMsg('No AmbiEncoder found on track.\n'); return end

local _, fxname = reaper.TrackFX_GetFXName(track, fx, '')
reaper.ShowConsoleMsg('FX: ' .. fxname .. '\n')

local n = reaper.TrackFX_GetNumParams(track, fx)
reaper.ShowConsoleMsg(string.format('Total params: %d\n', n))
reaper.ShowConsoleMsg('--- first 40 params ---\n')
for p = 0, math.min(n - 1, 39) do
  local _, name = reaper.TrackFX_GetParamName(track, fx, p, '')
  reaper.ShowConsoleMsg(string.format('%3d: [%s]\n', p, name or ''))
end
