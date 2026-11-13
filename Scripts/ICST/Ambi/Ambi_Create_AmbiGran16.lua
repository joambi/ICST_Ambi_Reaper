-- @description ICST Ambi: neue Spur "AmbiGran_16" mit AmbiGran 16 (Granular, VST3) anlegen
-- AmbiGran 16 arbeitet fest mit 16 Kanaelen (3. Ordnung, TOA). Kein Ordnungsdialog.
-- Ambi_Auto_Route behandelt die Spur als Quelle (-> Reverb / Decoder / Binaural).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local nch = 16

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
-- Immer eine neue Spur (nie auf eine bestehende Spur, z.B. Reverb, setzen)
local targets = { A.new_track("AmbiGran_16", nch) }

local failed = 0
for _, tr in ipairs(targets) do
  reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", nch)
  A.color_track(tr, "gran")
  local fx = A.add_fx(tr, A.FX_GRAN)
  if not fx then failed = failed + 1 end
end
reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: AmbiGran 16 anlegen", -1)

if failed > 0 then
  A.msg("AmbiGran 16 (VST3) wurde auf " .. failed .. " Spur(en) nicht gefunden (FX-Liste neu scannen?).")
end
