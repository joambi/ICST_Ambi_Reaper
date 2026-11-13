-- @description ICST Ambi: Routing-Check — analysiert das aktuelle Projekt und prueft den Signalfluss
-- Player / AmbiGran / Encoder -> [HOA_FX seriell] -> [Reverb parallel] -> [HOA_MASTER] -> Decoder / Binaural
-- Ergebnis als Dialog und in Scripts/ICST/_audit/route_check.txt
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/../Ambi/lib/ambi_common.lua")

local function name_of(tr) local _, n = reaper.GetTrackName(tr); return n end
local function nchan(tr) return math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")) end
local function role_of(tr)
  local tl = name_of(tr):lower()
  local fx = {}
  for i = 0, reaper.TrackFX_GetCount(tr) - 1 do local _, n = reaper.TrackFX_GetFXName(tr, i, ""); fx[#fx + 1] = n end
  local j = table.concat(fx, "|"):lower()
  local role
  if     name_of(tr) == A.MASTER_NAME then role = "master"
  elseif j:find("dearvr", 1, true) or j:find("binauraldecoder", 1, true) then role = "binaural"
  elseif j:find("ambidecoder", 1, true) then role = "decoder"
  elseif j:find("ambiirverb", 1, true)  then role = "reverb"
  elseif j:find("ambiencoder", 1, true) then role = "encoder"
  elseif j:find("ambigran", 1, true)    then role = "source"
  elseif j:find("(iem)", 1, true)       then role = "fx"
  elseif tl:find("player", 1, true)     then role = "player" end
  return role, fx
end
local function send_dest(src, i)
  if reaper.BR_GetMediaTrackSendInfo_Track then return reaper.BR_GetMediaTrackSendInfo_Track(src, 0, i, 1) end
  return reaper.GetSetTrackSendInfo(src, 0, i, "P_DESTTRACK", 0)
end
local function chans(code) if code == 0 then return 2 end if code & 1024 ~= 0 and code < 2048 then return 1 end return (code >> 10) * 2 end
local function dst_valid(code) return code >= 0 and code < 2048 end   -- Index (+1024 mono); Mehrkanal-Code im Ziel ist ungueltig

local T, idx = {}, {}
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  local role, fx = role_of(tr)
  local e = { tr = tr, name = name_of(tr), role = role or "-", fx = fx, nch = nchan(tr),
              mainsend = reaper.GetMediaTrackInfo_Value(tr, "B_MAINSEND") == 1, sends = {} }
  for s = 0, reaper.GetTrackNumSends(tr, 0) - 1 do
    local dst = send_dest(tr, s)
    e.sends[#e.sends + 1] = { dst = dst,
      src_ch = chans(math.floor(reaper.GetTrackSendInfo_Value(tr, 0, s, "I_SRCCHAN"))),
      dst_raw = math.floor(reaper.GetTrackSendInfo_Value(tr, 0, s, "I_DSTCHAN")),
      mute = reaper.GetTrackSendInfo_Value(tr, 0, s, "B_MUTE") == 1,
      vol = reaper.GetTrackSendInfo_Value(tr, 0, s, "D_VOL") }
  end
  T[#T + 1] = e; idx[tr] = e
end

local out, problems = {}, {}
local function P(s) problems[#problems + 1] = s end
out[#out + 1] = "Spuren:"
for _, e in ipairs(T) do
  out[#out + 1] = string.format("  %-9s %-22s %2d ch  FX: %s  MainSend: %s", e.role, e.name, e.nch,
    #e.fx > 0 and table.concat(e.fx, ", "):gsub("VST3: ", "") or "-", e.mainsend and "AN" or "aus")
  for _, s in ipairs(e.sends) do
    local d = idx[s.dst]
    out[#out + 1] = string.format("      -> %-22s %d ch ab Ziel-Kanal %s%s", d and d.name or "?", s.src_ch,
      dst_valid(s.dst_raw) and tostring((s.dst_raw & 1023) + 1) or "UNGUELTIG (" .. s.dst_raw .. ")", s.mute and "  MUTE" or "")
    if not dst_valid(s.dst_raw) then P(string.format("%s -> %s: Zielkanal ungueltig (%d) — Auto-Route erneut ausfuehren.", e.name, d and d.name or "?", s.dst_raw)) end
  end
end

-- Regeln
local by = {}
for _, e in ipairs(T) do by[e.role] = by[e.role] or {}; table.insert(by[e.role], e) end
local master = by.master and by.master[1]
local sinks = {}
for _, r in ipairs({ "decoder", "binaural" }) do for _, e in ipairs(by[r] or {}) do sinks[#sinks + 1] = e end end
local function has_send(src, dst) for _, s in ipairs(src.sends) do if s.dst == dst.tr and not s.mute then return s end end end

if #sinks == 0 then P("Kein Decoder / Binaural vorhanden — nichts hoerbar.") end
if master then
  if #master.fx > 0 then out[#out + 1] = "Hinweis: HOA_MASTER hat FX (" .. #master.fx .. ") — ok, wenn gewollt (Summenbearbeitung)." end
  if master.nch < 64 then P("HOA_MASTER hat nur " .. master.nch .. " Kanaele (erwartet 64).") end
  if master.mainsend then P("HOA_MASTER: Master-Send ist AN (muss aus sein, geht ueber Sends).") end
  for _, sk in ipairs(sinks) do if not has_send(master, sk) then P("HOA_MASTER sendet nicht an " .. sk.name .. ".") end end
end
local fxs = by.fx or {}
for _, r in ipairs({ "player", "source", "encoder" }) do
  for _, e in ipairs(by[r] or {}) do
    if e.mainsend then P(e.name .. ": Master-Send AN (Direktweg am Decoder vorbei).") end
    if #fxs > 0 then
      for _, f in ipairs(fxs) do if not has_send(e, f) then P(e.name .. " sendet nicht an HOA-FX " .. f.name .. ".") end end
      if master and has_send(e, master) then P(e.name .. " sendet direkt an HOA_MASTER UND an HOA-FX (trockener Doppelweg).") end
    else
      local tgt = master or nil
      if tgt and not has_send(e, tgt) then P(e.name .. " sendet nicht an HOA_MASTER.") end
      if not tgt then for _, sk in ipairs(sinks) do if not has_send(e, sk) then P(e.name .. " sendet nicht an " .. sk.name .. ".") end end end
    end
    if master then for _, sk in ipairs(sinks) do if has_send(e, sk) then P(e.name .. " sendet direkt an " .. sk.name .. " (am Master vorbei).") end end end
    for _, s in ipairs(e.sends) do
      if s.src_ch < math.min(e.nch, idx[s.dst] and idx[s.dst].nch or 64) then
        P(string.format("%s -> %s nur %d Kanaele (Spur hat %d).", e.name, idx[s.dst] and idx[s.dst].name or "?", s.src_ch, e.nch))
      end
    end
  end
end
for _, f in ipairs(fxs) do
  if f.mainsend then P(f.name .. ": Master-Send AN.") end
  local tgt = master
  if tgt and not has_send(f, tgt) then P(f.name .. " (HOA-FX) sendet nicht an HOA_MASTER.") end
end
for _, rv in ipairs(by.reverb or {}) do
  if rv.mainsend then P(rv.name .. ": Master-Send AN.") end
  if master and not has_send(rv, master) then P(rv.name .. " (Reverb) sendet nicht an HOA_MASTER.") end
end
for _, sk in ipairs(sinks) do
  if not sk.mainsend then P(sk.name .. ": Master-Send AUS — Decoder/Binaural muss auf den Master-Bus.") end
end
for _, e in ipairs(T) do
  if e.role ~= "-" and e.role ~= "binaural" and e.nch < 64 and e.role ~= "source" then
    out[#out + 1] = string.format("Hinweis: %s hat %d Kanaele (ALWAYS_64 → 64 erwartet; bei 3. Ordnung 16 ok).", e.name, e.nch)
  end
end

local verdict = (#problems == 0) and "ROUTING OK" or (#problems .. " Problem(e)")
local text = "ICST Routing-Check — " .. verdict .. "\n\n" .. table.concat(out, "\n")
if #problems > 0 then text = text .. "\n\nProbleme:\n  - " .. table.concat(problems, "\n  - ") end
local f = io.open(dir .. "/route_check.txt", "w"); if f then f:write(text, "\n"); f:close() end
reaper.ShowConsoleMsg(text .. "\n")
A.msg(text)
