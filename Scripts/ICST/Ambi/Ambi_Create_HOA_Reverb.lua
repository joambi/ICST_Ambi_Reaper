-- @description ICST Ambi: HOA-Reverb-Spur mit IEM FdnReverb (VST3) anlegen
-- Ordnung 1/3/5/7 -> 4/16/36/64 Kanaele. Ambi_Auto_Route routet Quellen automatisch auf diese Spur.
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)   -- 1OA=4, 3OA=16, 5OA=36, 7OA=64

reaper.Undo_BeginBlock()
local tr = A.new_track(A.REVERB_NAME, nch)
A.color_track(tr, "reverb")
local fx = A.add_fx(tr, A.FX_REVERB)
reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)   -- Reverb geht ueber Sends an Decoder/Binaural
reaper.SetOnlyTrackSelected(tr)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: HOA-Reverb-Spur anlegen", -1)

if not fx then A.msg("FdnReverb (IEM, VST3) nicht gefunden (FX-Liste neu scannen?).") end
