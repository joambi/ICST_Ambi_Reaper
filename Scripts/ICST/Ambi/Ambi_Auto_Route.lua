-- @description ICST Ambi: Offene Spuren nach FX analysieren und automatisch routen
-- Signalfluss:  Player / AmbiGran / Encoder  ->  [HOA_FX seriell]  ->  [HOA_Reverb parallel]  ->  [HOA_MASTER]  ->  Decoder  und  Binaural
-- HOA_FX-Spuren (IEM-Effekte) liegen SERIELL im Signalweg: die Quellen gehen nur dorthin, der FX-Ausgang weiter zu Reverb/Master.
-- Reverb (Spur "HOA_Reverb", IEM FdnReverb) bleibt PARALLEL (Aux): trockenes Signal und Hall treffen sich am Master bzw. an den Zielen.
-- Gibt es eine Spur "HOA_MASTER" (Ambi_Create_HOA_Master), laufen ALLE B-Format-Streams dort zusammen und nur der
-- Master speist Decoder und Binaural. Ohne Master: Quellen/Reverb direkt auf Decoder und Binaural (wie bisher).
-- Erkennung ueber FX-Namen (AmbiEncoder, AmbiEncoder_64, AmbiGran, AmbiDecoder, BinauralDecoder (IEM), dearVR);
-- Reverb ueber den Spurnamen "HOA_Reverb" (sonst wuerde FdnReverb als serielle IEM-FX-Spur gelten)
-- bzw. Spurname "BFormat_Player...". Bestehende Sends zu den Zielspuren werden ersetzt (idempotent).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local ORDER = { player = 1, source = 2, mono = 3, encoder = 4, fx = 5, reverb = 6, master = 7, decoder = 8, binaural = 9 }
local LABEL = { player = "Player", source = "Quelle", mono = "Mono", encoder = "Encoder", fx = "HOA-FX", reverb = "Reverb",
                master = "Master", decoder = "Decoder", binaural = "Binaural" }

local function classify(tr)
  local _, tname = reaper.GetTrackName(tr)
  local tl = tname:lower()
  local fx = {}
  for i = 0, reaper.TrackFX_GetCount(tr) - 1 do
    local _, n = reaper.TrackFX_GetFXName(tr, i, "")
    fx[#fx + 1] = n:lower()
  end
  local j = table.concat(fx, "|")
  local role
  if     tname == A.MASTER_NAME                 then role = "master"
  elseif j:find("dearvr", 1, true) or j:find("binauraldecoder", 1, true) then role = "binaural"
  elseif j:find("ambidecoder", 1, true)  then role = "decoder"
  elseif tname == A.REVERB_NAME          then role = "reverb"
  elseif j:find("ambiencoder", 1, true)  then role = "encoder"   -- schliesst _64 ein
  elseif j:find("ambigran", 1, true)     then role = "source"
  elseif j:find("(iem)", 1, true)        then role = "fx"        -- HOA-FX-Spur (IEM): seriell Quelle -> FX -> Reverb/Master
  elseif tl:find("player", 1, true)      then role = "player"
  end
  return role, tname
end

local function nchan(tr) return math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")) end
local function chan_code(n) if n <= 2 then return 0 end return (n // 2) << 10 end

local function send_dest(src, i)
  if reaper.BR_GetMediaTrackSendInfo_Track then
    return reaper.BR_GetMediaTrackSendInfo_Track(src, 0, i, 1)
  end
  return reaper.GetSetTrackSendInfo(src, 0, i, "P_DESTTRACK", 0)
end

local function remove_sends_to(src, set)
  for i = reaper.GetTrackNumSends(src, 0) - 1, 0, -1 do
    if set[send_dest(src, i)] then reaper.RemoveTrackSend(src, 0, i) end
  end
end

local function add_send(src, dst)
  local n = math.min(nchan(src), nchan(dst))
  local idx = reaper.CreateTrackSend(src, dst)
  reaper.SetTrackSendInfo_Value(src, 0, idx, "I_SRCCHAN", chan_code(n))
  -- Ziel: nur der Startkanal (0 = ab Kanal 1); die Kanalzahl ergibt sich aus der Quelle.
  -- (Fix 2026-11-11: der Mehrkanal-Code im Ziel war ungueltig -> leeres Zielfeld, kein Audio.)
  reaper.SetTrackSendInfo_Value(src, 0, idx, "I_DSTCHAN", 0)
  return n
end

-- Analyse
local by = { player = {}, source = {}, mono = {}, encoder = {}, fx = {}, reverb = {}, master = {}, decoder = {}, binaural = {} }
local all, unknown, pending = {}, 0, {}
for i = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, i)
  local role, name = classify(tr)
  if role then
    table.insert(by[role], tr)
    all[#all + 1] = { tr = tr, role = role, name = name }
  else
    pending[#pending + 1] = { tr = tr, name = name }
  end
end
-- Zweiter Durchgang: Mono-Quellspuren = Spuren ohne Ambi-FX mit einem Mono-Send in einen Encoder
local enc_set = {}
for _, t in ipairs(by.encoder) do enc_set[t] = true end
for _, e in ipairs(pending) do
  local mono_key
  for sidx = 0, reaper.GetTrackNumSends(e.tr, 0) - 1 do
    local dst = send_dest(e.tr, sidx)
    local dch = math.floor(reaper.GetTrackSendInfo_Value(e.tr, 0, sidx, "I_DSTCHAN"))
    if enc_set[dst] and (dch & 1024) ~= 0 then
      mono_key = reaper.GetMediaTrackInfo_Value(dst, "IP_TRACKNUMBER") * 1000 + (dch & 1023)
      break
    end
  end
  if mono_key then
    table.insert(by.mono, e.tr)
    all[#all + 1] = { tr = e.tr, role = "mono", name = e.name, key = mono_key }
  else
    unknown = unknown + 1
  end
end

-- Spurfarben nach Rolle setzen (immer sichtbar, was Quelle / FX / Master / Ausgang ist)
local COLOR_KEY = { player = "player", source = "gran", mono = "mono", fx = "fx", reverb = "reverb",
                    master = "master", decoder = "decoder", binaural = "binaural" }
reaper.Undo_BeginBlock()
for _, e in ipairs(all) do
  local key = COLOR_KEY[e.role]
  if e.role == "encoder" then
    local is64 = false
    for i = 0, reaper.TrackFX_GetCount(e.tr) - 1 do
      local _, n = reaper.TrackFX_GetFXName(e.tr, i, "")
      if n:find("_64", 1, true) then is64 = true end
    end
    key = is64 and "encoder_64" or "encoder"
  end
  if key then A.color_track(e.tr, key) end
end
reaper.Undo_EndBlock("ICST Ambi: Spurfarben nach Rolle", -1)

local sinks = {}
for _, t in ipairs(by.decoder)  do sinks[#sinks + 1] = t end
for _, t in ipairs(by.binaural) do sinks[#sinks + 1] = t end
if #sinks == 0 then
  A.msg("Keine Zielspur gefunden (AmbiDecoder, IEM BinauralDecoder oder dearVR). Zuerst Decoder oder Binaural anlegen.")
  return
end

local sources = {}
for _, r in ipairs({ "player", "source", "encoder" }) do
  for _, t in ipairs(by[r]) do sources[#sources + 1] = t end
end
if #sources == 0 and #by.reverb == 0 and #by.fx == 0 then
  A.msg("Keine Quellspuren (Player, Encoder, AmbiGran) gefunden.")
  return
end

-- Dialog: Sortieren + Modus fuer HOA-FX-Spuren
--   seriell  (s): Quellen -> HOA_FX -> Master   (Insert: Rotation, EQ, Kompressor auf der ganzen Szene)
--   parallel (p): Quellen -> HOA_FX und Quellen -> Master, HOA_FX -> Master (Send/Aux wie beim Reverb)
local ok, ans = reaper.GetUserInputs("Auto-Routing", 2,
  "Spuren sortieren (j/n):,HOA_FX seriell (s) / parallel (p):,extrawidth=60",
  A.get("route_sort", "n") .. "," .. A.get("route_fxmode", "s"))
if not ok then return end
local a1, a2 = ans:match("^([^,]*),([^,]*)")
local do_sort = (a1 or ""):lower():sub(1, 1) == "j"
local fx_parallel = (a2 or ""):lower():sub(1, 1) == "p"
A.set("route_sort", do_sort and "j" or "n")
A.set("route_fxmode", fx_parallel and "p" or "s")

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local master = by.master[1]   -- hoechstens eine Sammelspur wird benutzt
local targets = {}   -- alle Tracks, deren eingehende Sends neu gesetzt werden
for _, t in ipairs(sinks) do targets[t] = true end
for _, t in ipairs(by.reverb) do targets[t] = true end
for _, t in ipairs(by.fx) do targets[t] = true end
if master then targets[master] = true end
-- Mit Master: Quellen und Reverb enden am Master; nur der Master speist Decoder/Binaural
local src_sinks = master and { master } or sinks

local report = {}
local function name_of(tr) local _, n = reaper.GetTrackName(tr); return n end

-- Stufe nach den Quellen: HOA-FX (seriell) oder direkt Reverb + Master/Ziele
local function route_dry(src)
  for _, rv in ipairs(by.reverb) do
    local n = add_send(src, rv)
    report[#report + 1] = string.format("%s -> %s (%d ch)", name_of(src), name_of(rv), n)
  end
  for _, dst in ipairs(src_sinks) do
    local n = add_send(src, dst)
    report[#report + 1] = string.format("%s -> %s (%d ch)", name_of(src), name_of(dst), n)
  end
end

-- Quellen -> HOA-FX (seriell) bzw. -> Reverb + Master/Ziele
for _, src in ipairs(sources) do
  remove_sends_to(src, targets)
  reaper.SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)
  for _, fx in ipairs(by.fx) do
    local n = add_send(src, fx)
    report[#report + 1] = string.format("%s -> %s (%d ch)", name_of(src), name_of(fx), n)
  end
  if #by.fx == 0 or fx_parallel then
    route_dry(src)          -- ohne HOA_FX oder im Parallel-Modus: direkt zu Reverb + Master/Zielen
  end
end

-- HOA-FX -> Reverb (parallel) + Master/Ziele
for _, fx in ipairs(by.fx) do
  remove_sends_to(fx, targets)
  reaper.SetMediaTrackInfo_Value(fx, "B_MAINSEND", 0)
  route_dry(fx)
end

-- Reverb -> Master bzw. Ziele
for _, rv in ipairs(by.reverb) do
  remove_sends_to(rv, targets)
  reaper.SetMediaTrackInfo_Value(rv, "B_MAINSEND", 0)
  for _, dst in ipairs(src_sinks) do
    local n = add_send(rv, dst)
    report[#report + 1] = string.format("%s -> %s (%d ch)", name_of(rv), name_of(dst), n)
  end
end

-- Master -> Decoder und Binaural
if master then
  remove_sends_to(master, targets)
  reaper.SetMediaTrackInfo_Value(master, "B_MAINSEND", 0)
  for _, dst in ipairs(sinks) do
    local n = add_send(master, dst)
    report[#report + 1] = string.format("%s -> %s (%d ch)", name_of(master), name_of(dst), n)
  end
  if #by.master > 1 then report[#report + 1] = "Hinweis: mehrere HOA_MASTER-Spuren, nur die erste wird benutzt." end
end

-- Optional sortieren: Player, Quelle, Encoder, Reverb, Decoder, Binaural
if do_sort then
  -- Mono-Quellen direkt vor ihren Encoder (Reihenfolge = Eingang), sonst nach Rolle
  local enc_order = {}
  for i, e in ipairs(all) do if e.role == "encoder" then enc_order[e.tr] = i end end
  local function sortkey(e)
    if e.role == "mono" then
      local enc_num = math.floor(e.key / 1000)
      return ORDER.encoder * 1e6 + enc_num * 1000 - 0.5 + (e.key % 1000) / 1000   -- knapp vor dem Encoder
    end
    local pos = reaper.GetMediaTrackInfo_Value(e.tr, "IP_TRACKNUMBER")
    if e.role == "encoder" then return ORDER.encoder * 1e6 + pos * 1000 end
    return ORDER[e.role] * 1e6 + pos
  end
  table.sort(all, function(a, b) return sortkey(a) < sortkey(b) end)
  for i, e in ipairs(all) do
    reaper.SetOnlyTrackSelected(e.tr)
    reaper.ReorderSelectedTracks(i - 1, 0)
  end
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ICST Ambi: Auto-Routing", -1)

local head = {}
for _, e in ipairs(all) do head[#head + 1] = string.format("%-9s %s", LABEL[e.role], e.name) end
A.msg("Erkannt:\n" .. table.concat(head, "\n") ..
      (unknown > 0 and ("\n\n" .. unknown .. " Spur(en) ohne Ambi-Rolle ignoriert.") or "") ..
      "\n\nSends:\n" .. table.concat(report, "\n") ..
      "\n\nHOA_FX: " .. (fx_parallel and "parallel (Send)" or "seriell (Insert)") ..
      "\nMaster-Send der Quellen, HOA-FX, Reverbs" .. (master and " und des HOA_MASTER" or "") .. " ist aus.")
