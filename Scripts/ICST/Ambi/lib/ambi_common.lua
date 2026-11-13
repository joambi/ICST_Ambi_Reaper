-- @description ICST Ambi: gemeinsame Funktionen (Encoder / Decoder / Binaural)
local M = {}

M.EXT = "ICST_Ambi"
-- Spurfarben je Effekt (RGB), passend zu den Toolbar-Icons
M.COLORS = {
  -- Farbfamilien (2026-11-11): Quellen = warm (rot/orange/gelb/magenta), Bearbeitung = gruen/cyan,
  -- Master = weiss/neutral, Ausgaenge = blau/violett. Ambi_Auto_Route setzt die Farben nach Rolle neu.
  mono       = { 200, 200, 200 },   -- hellgrau   Mono-Quellspur (Send in einen Encoder_64-Eingang)
  encoder_64 = { 235,  70,  60 },   -- rot        AmbiEncoder_64      (Quelle)
  encoder    = { 255, 150,  40 },   -- orange     AmbiEncoder (1ch)   (Quelle)
  player     = { 250, 210,  60 },   -- gelb       B-Format-Player     (Quelle)
  gran       = { 225,  70, 180 },   -- magenta    AmbiGran 16         (Quelle)
  fx         = {  90, 200,  90 },   -- gruen      HOA-FX (IEM, seriell)
  reverb     = {  40, 190, 220 },   -- cyan       HOA-Reverb (AmbiIRVerb, parallel)
  master     = { 235, 235, 235 },   -- weiss      HOA_MASTER (Sammelspur)
  decoder    = {  60, 130, 255 },   -- blau       AmbiDecoder         (Ausgang)
  binaural   = { 160, 100, 240 },   -- violett    Binaural / dearVR   (Ausgang)
}

function M.color_track(tr, key)
  local c = M.COLORS[key]
  if not c then return end
  reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", reaper.ColorToNative(c[1], c[2], c[3]) | 0x1000000)
end

M.ORDERS = { [1] = true, [3] = true, [5] = true, [7] = true }   -- erlaubte Ordnungen
-- 2026-11-11: Spuren werden immer mit 64 Kanaelen (7. Ordnung) angelegt, ohne Ordnungsdialog.
-- Auf false setzen, um den Dialog (1/3/5/7) wieder zu bekommen.
M.ALWAYS_64 = true
M.MASTER_NAME = "HOA_MASTER"   -- Name der Sammelspur; Ambi_Auto_Route erkennt sie am Namen

-- FX-Kandidaten: nur VST3 (Substring-Match gegen die REAPER-FX-Liste, Reihenfolge = Prioritaet)
-- Namen laut REAPER-Plugin-Cache: "AmbiEncoder (ICST)", "AmbiEncoder_64 (ICST)", "AmbiDecoder (ICST)".
M.FX_ENCODER = { "VST3: AmbiEncoder (ICST)", "VST3: AmbiEncoder (ICST" }
M.FX_REVERB = { "VST3: AmbiIRVerb (Independent)", "VST3: AmbiIRVerb" }
M.FX_GRAN = { "VST3: AmbiGran 16 (ICST)", "VST3: AmbiGran 16" }
M.FX_ENCODER_64 = { "VST3: AmbiEncoder_64 (ICST)", "VST3: AmbiEncoder_64" }
M.FX_DECODER = { "VST3: AmbiDecoder (ICST)", "VST3: AmbiDecoder (ICST" }
M.FX_DEARVR  = { "VST3: dearVR AMBI MICRO", "VST3: dearVR AMBI", "VST3: dearVR MICRO", "VST3: dearVR PRO", "VST3: dearVR" }
M.FX_IEM_BIN = { "VST3: BinauralDecoder (IEM)", "VST3: BinauralDecoder" }
M.FX_OBR     = { "VST3: Open Binaural Renderer" }

function M.msg(t) reaper.ShowMessageBox(t, "ICST Ambi", 0) end

function M.get(key, default)
  local v = reaper.GetExtState(M.EXT, key)
  if v == nil or v == "" then return default end
  return v
end

function M.set(key, val) reaper.SetExtState(M.EXT, key, tostring(val), true) end

-- Fragt die Ambisonics-Ordnung ab (1-3), merkt sich den letzten Wert
function M.ask_order()
  if M.ALWAYS_64 then M.set("order", 7); return 7 end
  local ok, input = reaper.GetUserInputs("Ambisonics-Ordnung", 1, "Ordnung (1 / 3 / 5 / 7):", M.get("order", "3"))
  if not ok then return nil end
  local n = math.floor(tonumber(input) or 0)
  if not M.ORDERS[n] then M.msg("Bitte 1, 3, 5 oder 7 eingeben."); return nil end
  M.set("order", n)
  return n
end

-- Kanalzahl, auf gerade Zahl aufgerundet (REAPER verlangt gerade I_NCHAN)
function M.nchan(order)
  local n = (order + 1) ^ 2
  if n % 2 == 1 then n = n + 1 end
  return math.floor(n)
end

function M.new_track(name, nchan)
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  if nchan then reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", nchan) end
  return tr
end

-- Fuegt das erste passende Plugin hinzu. reject(name) -> true verwirft den Treffer.
-- Gibt (fxIndex, fxName) oder (nil, nil) zurueck.
function M.add_fx(tr, candidates, reject)
  for _, cand in ipairs(candidates) do
    local fx = reaper.TrackFX_AddByName(tr, cand, false, -1)
    if fx >= 0 then
      local _, name = reaper.TrackFX_GetFXName(tr, fx, "")
      if not name:find("VST3", 1, true) or (reject and reject(name)) then
        reaper.TrackFX_Delete(tr, fx)
      else
        return fx, name
      end
    end
  end
  return nil, nil
end

function M.not_64(name) return name:find("_64", 1, true) ~= nil end

return M
