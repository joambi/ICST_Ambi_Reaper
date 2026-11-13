-- @description ICST Ambi: Binaural-Monitor-Spur mit IEM BinauralDecoder (VST3, bis 7. Ordnung); sonst dearVR; sonst ICST AmbiDecoder + Open Binaural Renderer
-- Reihenfolge: IEM BinauralDecoder > dearVR AMBI MICRO > dearVR AMBI > dearVR MICRO > dearVR PRO.
-- Die Ambisonics-Spuren werden anschliessend auf diese Spur geroutet (Send oder Ordner).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)   -- 1OA=4, 3OA=16, 5OA=36, 7OA=64

reaper.Undo_BeginBlock()
local tr = A.new_track("Binaural_Monitor", nch)
A.color_track(tr, "binaural")
local fx, name = A.add_fx(tr, A.FX_IEM_BIN)
if not fx then fx, name = A.add_fx(tr, A.FX_DEARVR) end
local note
if not fx then
  -- Fallback: ICST-Decoder + Open Binaural Renderer
  local d = A.add_fx(tr, A.FX_DECODER)
  local b = A.add_fx(tr, A.FX_OBR)
  note = "Weder IEM BinauralDecoder noch dearVR gefunden (VST3, ggf. FX-Liste neu scannen).\n" ..
         (d and "ICST AmbiDecoder eingefuegt. " or "ICST AmbiDecoder fehlt. ") ..
         (b and "Open Binaural Renderer eingefuegt." or "Kein Binaural-Plugin gefunden.")
elseif name:lower():find("micro", 1, true) and not name:lower():find("ambi", 1, true) then
  note = "Gefunden: " .. name .. " (kein Ambisonics-Decoder). Ambisonics zuerst mit ICST AmbiDecoder auf Lautsprecher decodieren."
end
reaper.SetOnlyTrackSelected(tr)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: Binaural-Monitor anlegen", -1)
if note then A.msg(note) end
