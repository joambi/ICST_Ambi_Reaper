-- @description ICST Animator: Encoder-Spuren (Encoder_01 ...) mit AmbiEncoder_64 anlegen

local script_dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local C = dofile(script_dir .. "/lib/animator_common.lua")

-- Ordnung (1/3/5/7) wie bei Ambi_Create_Encoder_64: 4/16/36/64 Kanaele
local A = dofile(script_dir .. "/../Ambi/lib/ambi_common.lua")

-- 2026-11-11: Spuren immer mit 64 Kanaelen (A.ALWAYS_64); Ordnungsdialog nur noch bei ALWAYS_64 = false
local n, order
if A.ALWAYS_64 then
  local ok, input = reaper.GetUserInputs("Encoder-Spuren anlegen", 1, "Anzahl Spuren:,extrawidth=80", "8")
  if not ok then return end
  n = math.floor(tonumber(input) or 0)
  order = 7
else
  local ok, input = reaper.GetUserInputs("Encoder-Spuren anlegen", 2,
    "Anzahl Spuren:,Ordnung (1 / 3 / 5 / 7):,extrawidth=80", "8," .. A.get("order", "3"))
  if not ok then return end
  local cnt, ord = input:match("^([^,]*),([^,]*)")
  n = math.floor(tonumber(cnt) or 0)
  order = math.floor(tonumber(ord) or 0)
  if not A.ORDERS[order] then
    C.msg("Bitte Ordnung 1, 3, 5 oder 7 eingeben.")
    return
  end
end
if n < 1 or n > 64 then
  C.msg("Bitte eine Zahl zwischen 1 und 64 eingeben.")
  return
end
A.set("order", order)
local nch = A.nchan(order)   -- 1OA=4, 3OA=16, 5OA=36, 7OA=64

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local missing_fx = false
local start = reaper.CountTracks(0)
-- Nummerierung fortsetzen: hoechste vorhandene Encoder_NN finden
local maxnum = 0
for t = 0, start - 1 do
  local _, nm = reaper.GetSetMediaTrackInfo_String(reaper.GetTrack(0, t), "P_NAME", "", false)
  local num = nm:match("^" .. C.ENCODER_PREFIX .. "(%d+)$")
  if num and tonumber(num) > maxnum then maxnum = tonumber(num) end
end
for i = 1, n do
  reaper.InsertTrackAtIndex(start + i - 1, true)
  local tr = reaper.GetTrack(0, start + i - 1)
  reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", nch)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", string.format("%s%02d", C.ENCODER_PREFIX, maxnum + i), true)
  local col = C.ENCODER_COLOR
  reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", reaper.ColorToNative(col[1], col[2], col[3]) | 0x1000000)
  local fx = reaper.TrackFX_AddByName(tr, C.ENCODER_FX, false, -1)
  if fx < 0 then missing_fx = true end
end
reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ICST Animator: Encoder-Spuren anlegen", -1)

if missing_fx then
  C.msg("Spuren angelegt, aber das Plugin '" .. C.ENCODER_FX ..
        "' wurde nicht gefunden (FX-Liste neu scannen?).")
end
