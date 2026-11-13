-- @description Ambi64 Zug-Vorbeifahrt (langsam / schnell / Vergleich)
-- @author ICST / JS — konsolidiert aus icst_ambi_zug_langsam/schnell/vergleich (Audit 2026-11-11)
-- @version 2.0
-- @about
--   Schreibt die Vorbeifahrt eines Zuges als X/Y/Z-Automation fuer EINEN Punkt des
--   ICST AmbiEncoder_64 ab der Edit-Cursor-Position (Physik: gerade Strecke, Azimut
--   und Distanz aus der Zugposition, Distanz-Kurve ueber den Abstand).
--
--   Korrektur gegenueber V1: Die alten Scripts schrieben die Parameter 11/12/13 als
--   "Azimut/Elevation/Distanz" — das sind beim AmbiEncoder_64 aber Y 1 / Z 1 / Gain1.
--   Der Encoder arbeitet kartesisch (X/Y/Z je Punkt, 0..1 mit 0.5 = Mitte); die
--   Vorbeifahrt wird deshalb in X/Y/Z umgerechnet. Achsen-Konvention (AmbiX / ICST):
--   X = vorne, Y = links, Z = oben — unten in CFG anpassbar.
--
--   Dialog: Punkt (1-64), Variante (1 = langsam 30 s, 2 = schnell 4 s, 3 = Vergleich:
--   Pause, langsam, Pause, schnell), Richtung (1 = rechts→links, 2 = links→rechts).

local CFG = {
  AXIS_FRONT = "x",      -- Achse, die nach vorne zeigt
  AXIS_LEFT  = "y",      -- Achse, die nach links zeigt
  AXIS_UP    = "z",
  FIRST_PARAM = 10, STRIDE = 5,   -- X 1 = Param 10, dann +5 je Punkt
  LANGSAM = { dauer = 30.0, punkte = 120, abstand = 0.30, breite = 1.40, nah = 0.20, fern = 0.90, hoehe = 0.0 },
  SCHNELL = { dauer =  4.0, punkte =  80, abstand = 0.12, breite = 1.90, nah = 0.08, fern = 0.95, hoehe = 0.0 },
  PAUSE   = 3.0,         -- Pause im Vergleichs-Modus (s)
}

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

-- Zugposition: liefert (links, vorne, oben, distanz_norm) in Einheiten des Lautsprecherradius
local function zug_pos(t, P, rechts_nach_links)
  local halb = P.breite * 0.5
  local links = rechts_nach_links and (-halb + P.breite * t) or (halb - P.breite * t)
  local vorne = P.abstand
  -- Distanz ueber den euklidischen Abstand auf [nah, fern] abbilden
  local d_roh  = math.sqrt(links * links + vorne * vorne)
  local d_max  = math.sqrt(halb * halb + vorne * vorne)
  local d_norm = (d_roh - vorne) / math.max(1e-6, d_max - vorne)
  local dist   = P.nah + (P.fern - P.nah) * d_norm
  -- Richtungsvektor * Distanz → kartesisch
  local nx, ny = links / d_roh, vorne / d_roh
  return nx * dist, ny * dist, P.hoehe * math.sin(math.pi * t), dist
end

-- Track / FX finden
local track = reaper.GetSelectedTrack(0, 0)
if not track then
  reaper.ShowMessageBox("Bitte zuerst den Track mit dem ICST AmbiEncoder_64 selektieren.", "Zug-Vorbeifahrt", 0)
  return
end
local fx = -1
for i = 0, reaper.TrackFX_GetCount(track) - 1 do
  local _, name = reaper.TrackFX_GetFXName(track, i, "")
  if name:find("AmbiEncoder_64", 1, true) then fx = i break end
end
if fx < 0 then
  reaper.ShowMessageBox("Auf dem selektierten Track ist kein AmbiEncoder_64.", "Zug-Vorbeifahrt", 0)
  return
end

-- Dialog
local last = reaper.GetExtState("ICST_Zug", "last")
local defaults = (last ~= "") and last or "1,1,1"
local ok, input = reaper.GetUserInputs("Zug-Vorbeifahrt (AmbiEncoder_64)", 3,
  "Punkt (1-64),Variante (1 langsam / 2 schnell / 3 Vergleich),Richtung (1 rechts>links / 2 links>rechts)", defaults)
if not ok then return end
local p_str, v_str, r_str = input:match("^([^,]*),([^,]*),([^,]*)$")
local punkt   = clamp(math.floor(tonumber(p_str) or 1), 1, 64)
local variante = clamp(math.floor(tonumber(v_str) or 1), 1, 3)
local rnl     = (tonumber(r_str) or 1) ~= 2
reaper.SetExtState("ICST_Zug", "last", string.format("%d,%d,%d", punkt, variante, rnl and 1 or 2), true)

-- Parameter-Indizes des Punkts (per Name verifiziert, Fallback Stride)
local base = CFG.FIRST_PARAM + (punkt - 1) * CFG.STRIDE
local idx = { x = base, y = base + 1, z = base + 2 }
local _, pname = reaper.TrackFX_GetParamName(track, fx, base, "")
if not pname:match("^X%s*" .. punkt .. "$") then
  -- Namenssuche "X <punkt>"
  for p = 0, reaper.TrackFX_GetNumParams(track, fx) - 1 do
    local _, n = reaper.TrackFX_GetParamName(track, fx, p, "")
    if n == "X " .. punkt then idx = { x = p, y = p + 1, z = p + 2 } break end
  end
end
local env = {}
for _, ax in ipairs({ "x", "y", "z" }) do
  env[ax] = reaper.GetFXEnvelope(track, fx, idx[ax], true)
  if not env[ax] then
    reaper.ShowMessageBox("Envelope fuer Parameter " .. idx[ax] .. " konnte nicht angelegt werden.", "Zug-Vorbeifahrt", 0)
    return
  end
end

-- Segmente zusammenstellen
local segments = {}
if variante == 1 then segments = { { P = CFG.LANGSAM } }
elseif variante == 2 then segments = { { P = CFG.SCHNELL } }
else segments = { { pause = CFG.PAUSE }, { P = CFG.LANGSAM }, { pause = CFG.PAUSE }, { P = CFG.SCHNELL } } end

reaper.Undo_BeginBlock()
local t0 = reaper.GetCursorPosition()
local total = 0
for _, s in ipairs(segments) do total = total + (s.pause or s.P.dauer) end
for _, ax in ipairs({ "x", "y", "z" }) do
  reaper.DeleteEnvelopePointRange(env[ax], t0 - 0.01, t0 + total + 0.01)
end

local function write_point(time, links, vorne, oben)
  local cart = { [CFG.AXIS_LEFT] = links, [CFG.AXIS_FRONT] = vorne, [CFG.AXIS_UP] = oben }
  for _, ax in ipairs({ "x", "y", "z" }) do
    reaper.InsertEnvelopePoint(env[ax], time, clamp(0.5 + 0.5 * (cart[ax] or 0), 0, 1), 0, 0, false, true)
  end
end

local time = t0
local n_written = 0
for _, s in ipairs(segments) do
  if s.pause then
    -- Pause: Position am Rand halten (weit entfernt, Richtung Startseite)
    time = time + s.pause
  else
    local P = s.P
    for i = 0, P.punkte do
      local t = i / P.punkte
      local l, v, o = zug_pos(t, P, rnl)
      write_point(time + t * P.dauer, l, v, o)
      n_written = n_written + 1
    end
    time = time + P.dauer
  end
end
for _, ax in ipairs({ "x", "y", "z" }) do reaper.Envelope_SortPoints(env[ax]) end

local labels = { "Langsamer Zug", "Schnellzug", "Zug-Vergleich" }
reaper.Undo_EndBlock("ICST Ambi: " .. labels[variante] .. " Punkt " .. punkt, -1)
reaper.UpdateArrange()
reaper.ShowMessageBox(string.format(
  "%s — Automation geschrieben\n\nPunkt: %d  (Params X/Y/Z = %d/%d/%d)\nStart: %.2f s   Dauer: %.1f s   Punkte: %d\nAchsen: vorne=%s  links=%s  oben=%s",
  labels[variante], punkt, idx.x, idx.y, idx.z, t0, total, n_written,
  CFG.AXIS_FRONT:upper(), CFG.AXIS_LEFT:upper(), CFG.AXIS_UP:upper()), "Zug-Vorbeifahrt", 0)
