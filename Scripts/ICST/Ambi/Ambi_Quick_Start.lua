-- @description ICST Ambi: Quick-Start — komplette Ambisonics-Session mit einem Klick anlegen
-- Legt an (alle 64 Kanaele, Farben nach Rolle) und routet fertig:
--   Src_01..n (mono)  ->  Ambi_Encoder_64  ->  [HOA_FX seriell]  ->  [HOA_Reverb parallel]  ->  HOA_MASTER  ->  Decoder + Binaural
-- Dialog: Anzahl Mono-Quellen, HOA_FX (j/n), Reverb (j/n), Decoder (j/n), Binaural (j/n).
-- Danach: Audiodateien auf die Src-Spuren ziehen, Quellen im Encoder bewegen, Motion Map / Kristall fuer Automation.
-- Hinweis: das Script baut in das aktuelle Projekt (am besten ein leeres, neues Projekt).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local MONO = 1024
local function nchan(tr) return math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")) end
local function chan_code(n) if n <= 2 then return 0 end return (n // 2) << 10 end
local function send_multi(src, dst)
  local n = math.min(nchan(src), nchan(dst))
  local i = reaper.CreateTrackSend(src, dst)
  reaper.SetTrackSendInfo_Value(src, 0, i, "I_SRCCHAN", chan_code(n))
  reaper.SetTrackSendInfo_Value(src, 0, i, "I_DSTCHAN", 0)   -- Ziel ab Kanal 1, Kanalzahl folgt der Quelle
  return n
end
local function send_mono(src, dst, ch)
  local i = reaper.CreateTrackSend(src, dst)
  reaper.SetTrackSendInfo_Value(src, 0, i, "I_SRCCHAN", MONO)
  reaper.SetTrackSendInfo_Value(src, 0, i, "I_DSTCHAN", MONO + ch)
end

-- Dialog (Werte werden gemerkt)
local defaults = A.get("qs_last", "4,n,n,j,j")
local ok, input = reaper.GetUserInputs("ICST Quick-Start", 5,
  "Mono-Quellen (0-64):,HOA_FX-Spur (j/n):,HOA_Reverb (j/n):,Decoder (j/n):,Binaural (j/n):,extrawidth=40", defaults)
if not ok then return end
local f = {}
for v in input:gmatch("[^,]*") do f[#f + 1] = v end
local n_src = math.floor(tonumber(f[1]) or 4)
if n_src < 0 or n_src > 64 then A.msg("Mono-Quellen: 0 bis 64."); return end
local function yes(v) return (v or ""):lower():sub(1, 1) == "j" end
local want_fx, want_rv, want_dec, want_bin = yes(f[2]), yes(f[3]), yes(f[4]), yes(f[5])
A.set("qs_last", input)

if reaper.CountTracks(0) > 0 then
  local r = reaper.MB("Das Projekt enthaelt bereits " .. reaper.CountTracks(0) .. " Spur(en). Quick-Start-Spuren trotzdem anhaengen?",
                      "ICST Quick-Start", 4)
  if r ~= 6 then return end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local missing, report = {}, {}

-- Quellen
local srcs = {}
for i = 1, n_src do
  local tr = A.new_track(string.format("Src_%02d", i), 2)
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
  reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", reaper.ColorToNative(200, 200, 200) | 0x1000000)
  srcs[#srcs + 1] = tr
end

-- Encoder_64
local enc = A.new_track("Ambi_Encoder_64", 64)
A.color_track(enc, "encoder_64")
reaper.SetMediaTrackInfo_Value(enc, "B_MAINSEND", 0)
if not A.add_fx(enc, A.FX_ENCODER_64) then missing[#missing + 1] = "AmbiEncoder_64" end
for i, tr in ipairs(srcs) do send_mono(tr, enc, i - 1) end
if n_src > 0 then report[#report + 1] = string.format("Src_01..%02d -> Encoder Eingang 1..%d (mono)", n_src, n_src) end

-- HOA_FX (seriell) — Standardkette SceneRotator + MultiEQ
local fx
if want_fx then
  fx = A.new_track("HOA_FX", 64)
  A.color_track(fx, "fx")
  reaper.SetMediaTrackInfo_Value(fx, "B_MAINSEND", 0)
  for _, k in ipairs({ "SceneRotator", "MultiEQ" }) do
    if not A.add_fx(fx, { "VST3: " .. k .. " (IEM)", "VST3: " .. k }) then missing[#missing + 1] = k .. " (IEM)" end
  end
  A.set("hoafx_sel", "SceneRotator,MultiEQ")
end

-- Reverb (parallel) — IEM FdnReverb (VST3)
local rv
if want_rv then
  rv = A.new_track("HOA_Reverb", 64)
  A.color_track(rv, "reverb")
  reaper.SetMediaTrackInfo_Value(rv, "B_MAINSEND", 0)
  if not A.add_fx(rv, A.FX_FDN_REVERB) then missing[#missing + 1] = "FdnReverb (IEM)" end
end

-- Master
local master = A.new_track(A.MASTER_NAME, 64)
A.color_track(master, "master")
reaper.SetMediaTrackInfo_Value(master, "B_MAINSEND", 0)

-- Ausgaenge
local sinks = {}
if want_dec then
  local d = A.new_track("Ambi_Decoder", 64)
  A.color_track(d, "decoder")
  if not A.add_fx(d, A.FX_DECODER) then missing[#missing + 1] = "AmbiDecoder" end
  sinks[#sinks + 1] = d
end
if want_bin then
  local b = A.new_track("Binaural_Monitor", 64)
  A.color_track(b, "binaural")
  local ok1 = A.add_fx(b, A.FX_IEM_BIN) or A.add_fx(b, A.FX_DEARVR)
  if not ok1 then missing[#missing + 1] = "BinauralDecoder (IEM) / dearVR" end
  sinks[#sinks + 1] = b
end

-- Routing
local stage = fx or enc            -- Ausgang der Quellenstufe
if fx then report[#report + 1] = string.format("Encoder -> HOA_FX (%d ch, seriell)", send_multi(enc, fx)) end
if rv then report[#report + 1] = string.format("%s -> HOA_Reverb (%d ch, parallel)", fx and "HOA_FX" or "Encoder", send_multi(stage, rv)) end
report[#report + 1] = string.format("%s -> HOA_MASTER (%d ch)", fx and "HOA_FX" or "Encoder", send_multi(stage, master))
if rv then report[#report + 1] = string.format("HOA_Reverb -> HOA_MASTER (%d ch)", send_multi(rv, master)) end
for _, sk in ipairs(sinks) do
  local _, sn = reaper.GetTrackName(sk)
  report[#report + 1] = string.format("HOA_MASTER -> %s (%d ch)", sn, send_multi(master, sk))
end
if #sinks == 0 then report[#report + 1] = "Kein Ausgang gewaehlt — spaeter Decoder/Binaural anlegen und Auto-Route klicken." end

reaper.SetOnlyTrackSelected(srcs[1] or enc)
reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ICST Ambi: Quick-Start", -1)

local msg = "Quick-Start angelegt (64 Kanaele):\n\n" .. table.concat(report, "\n") ..
  "\n\nNaechste Schritte: Audiodateien auf die Src-Spuren ziehen, Quellen im AmbiEncoder_64 setzen/bewegen, " ..
  "Bewegungen mit Motion Map oder Kristall schreiben."
if #missing > 0 then
  msg = msg .. "\n\nNicht gefunden (FX-Liste neu scannen?): " .. table.concat(missing, ", ")
end
A.msg(msg)
