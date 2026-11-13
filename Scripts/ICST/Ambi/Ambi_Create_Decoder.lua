-- @description ICST Ambi: Decoder-Spur mit ICST AmbiDecoder anlegen
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)   -- 1OA=4, 3OA=16, 5OA=36, 7OA=64

reaper.Undo_BeginBlock()
local tr = A.new_track("Ambi_Decoder", nch)
A.color_track(tr, "decoder")
local fx = A.add_fx(tr, A.FX_DECODER)
reaper.SetOnlyTrackSelected(tr)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: AmbiDecoder anlegen", -1)

if not fx then A.msg("ICST AmbiDecoder (VST3) nicht gefunden (FX-Liste neu scannen?).") end
