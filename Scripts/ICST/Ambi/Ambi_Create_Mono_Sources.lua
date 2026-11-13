-- @description ICST Ambi: Mono-Quellspuren anlegen und auf die Eingaenge des gewaehlten AmbiEncoder_64 routen
-- Legt n Spuren "Src_01 ..." an und sendet jede (mono) auf Eingang 1..64 des selektierten Encoder_64-Tracks
-- (Punkt 1 = Kanal 1 usw.). Belegte Eingaenge werden uebersprungen, Nummerierung laeuft weiter.
-- Alle Mono-Quellen (auch manuell angelegte) werden direkt vor den Encoder sortiert (Reihenfolge = Eingang).
-- Master-Send der Quellspuren ist aus (Signal geht nur in den Encoder).
-- Ist kein Encoder_64-Track selektiert, wird einer angelegt (64 Kanaele).
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

local function find_encoder64(tr)
  for i = 0, reaper.TrackFX_GetCount(tr) - 1 do
    local _, n = reaper.TrackFX_GetFXName(tr, i, "")
    if n:find("AmbiEncoder_64", 1, true) then return i end
  end
end

-- Encoder-Track: selektierter Track mit AmbiEncoder_64, sonst erster im Projekt, sonst neu
local enc
for i = 0, reaper.CountSelectedTracks(0) - 1 do
  local tr = reaper.GetSelectedTrack(0, i)
  if find_encoder64(tr) then enc = tr break end
end
if not enc then
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    if find_encoder64(tr) then enc = tr break end
  end
end

local ok, input = reaper.GetUserInputs("Mono-Quellen -> AmbiEncoder_64", 2,
  "Anzahl Quellspuren (1-64):,Namenspraefix:,extrawidth=80", A.get("src_count", "8") .. "," .. A.get("src_prefix", "Src"))
if not ok then return end
local cnt_s, prefix = input:match("^([^,]*),(.*)$")
local n = math.floor(tonumber(cnt_s) or 0)
if n < 1 or n > 64 then A.msg("Bitte 1 bis 64 Quellspuren angeben."); return end
prefix = (prefix ~= "" and prefix or "Src"):gsub("[^%w_%-]", "")
A.set("src_count", n); A.set("src_prefix", prefix)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local created_enc = false
if not enc then
  enc = A.new_track("Ambi_Encoder_64", 64)
  A.color_track(enc, "encoder_64")
  if not A.add_fx(enc, A.FX_ENCODER_64) then
    reaper.PreventUIRefresh(-1)
    A.msg("AmbiEncoder_64 (VST3) nicht gefunden (FX-Liste neu scannen?).")
    reaper.Undo_EndBlock("ICST Ambi: Mono-Quellen (abgebrochen)", -1)
    return
  end
  created_enc = true
end
reaper.SetMediaTrackInfo_Value(enc, "I_NCHAN", 64)
reaper.SetMediaTrackInfo_Value(enc, "B_MAINSEND", 0)   -- Encoder geht ueber Auto-Route weiter

-- Belegte Encoder-Eingaenge ermitteln (Receives des Encoders, Zielkanal).
-- I_DSTCHAN: Index, &1024 = mono (Spur-Ziel), sonst Stereo-Paar ab Index.
local MONO = 1024
local used, broken = {}, {}
for r = 0, reaper.GetTrackNumSends(enc, -1) - 1 do
  local dst = math.floor(reaper.GetTrackSendInfo_Value(enc, -1, r, "I_DSTCHAN"))
  local ch = dst & 1023
  if dst >= 0 and ch < 64 then
    used[ch] = true
    if dst & MONO == 0 then used[ch + 1] = true end   -- Stereo-Ziel belegt zwei Kanaele
  elseif dst >= 0 then
    broken[#broken + 1] = r                            -- ungueltiges Ziel (z.B. aus V1 des Scripts)
  end
end
-- Hoechste vorhandene Nummer mit diesem Praefix (Nummerierung fortsetzen)
local maxnum = 0
for t = 0, reaper.CountTracks(0) - 1 do
  local _, nm = reaper.GetTrackName(reaper.GetTrack(0, t))
  local num = nm:match("^" .. prefix .. "_(%d+)$")
  if num and tonumber(num) > maxnum then maxnum = tonumber(num) end
end

-- Reparatur: Receives mit ungueltigem Zielkanal auf freie Eingaenge legen (nur Mono-Quellen)
local repaired = {}
for _, r in ipairs(broken) do
  local src = reaper.GetTrackSendInfo_Value(enc, -1, r, "P_SRCTRACK")
  local c = 0
  while used[c] and c < 64 do c = c + 1 end
  if c < 64 then
    reaper.SetTrackSendInfo_Value(enc, -1, r, "I_SRCCHAN", MONO)
    reaper.SetTrackSendInfo_Value(enc, -1, r, "I_DSTCHAN", MONO + c)
    used[c] = true
    local _, sn = reaper.GetTrackName(src)
    repaired[#repaired + 1] = string.format("%s -> Encoder Eingang %d (repariert)", sn, c + 1)
  end
end

-- Quellspuren direkt vor dem Encoder einfuegen
local enc_idx = math.floor(reaper.GetMediaTrackInfo_Value(enc, "IP_TRACKNUMBER")) - 1
local ch, made, report, dbg = 0, 0, {}, {}
for i = 1, n do
  while used[ch] and ch < 64 do ch = ch + 1 end
  if ch >= 64 then break end
  local pos = enc_idx + made
  reaper.InsertTrackAtIndex(pos, true)
  local tr = reaper.GetTrack(0, pos)
  local name = string.format("%s_%02d", prefix, maxnum + i)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", 2)
  reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
  reaper.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", reaper.ColorToNative(200, 200, 200) | 0x1000000)  -- hellgrau = Mono-Quelle
  local s = reaper.CreateTrackSend(tr, enc)
  local ok1 = reaper.SetTrackSendInfo_Value(tr, 0, s, "I_SRCCHAN", MONO)        -- mono, Kanal 1 der Quelle
  local ok2 = reaper.SetTrackSendInfo_Value(tr, 0, s, "I_DSTCHAN", MONO + ch)   -- mono auf Encoder-Eingang ch+1
  -- Kontrolle: zurueckgelesene Werte (Diagnose in _audit/mono_sources_log.txt)
  local rs = math.floor(reaper.GetTrackSendInfo_Value(tr, 0, s, "I_SRCCHAN"))
  local rd = math.floor(reaper.GetTrackSendInfo_Value(tr, 0, s, "I_DSTCHAN"))
  dbg[#dbg + 1] = string.format("%s: send idx %s set ok=%s/%s  src=%d (erwartet %d)  dst=%d (erwartet %d)",
    name, tostring(s), tostring(ok1), tostring(ok2), rs, MONO, rd, MONO + ch)
  local okrt = (rs == MONO and rd == MONO + ch)
  report[#report + 1] = string.format("%s -> Encoder Eingang %d (Punkt %d)%s", name, ch + 1, ch + 1, okrt and "" or "  !! Routing nicht uebernommen")
  used[ch] = true
  made = made + 1
end

-- Alle Mono-Quellen (auch manuell angelegte) direkt vor den Encoder legen, sortiert nach Eingang
do
  local list = {}
  for r = 0, reaper.GetTrackNumSends(enc, -1) - 1 do
    local dst = math.floor(reaper.GetTrackSendInfo_Value(enc, -1, r, "I_DSTCHAN"))
    local st  = reaper.GetTrackSendInfo_Value(enc, -1, r, "P_SRCTRACK")
    if st and dst >= 0 and (dst & MONO) ~= 0 and (dst & 1023) < 64 then
      list[#list + 1] = { tr = st, ch = dst & 1023 }
    end
  end
  table.sort(list, function(a, b) return a.ch < b.ch end)
  for _, e in ipairs(list) do
    local enc_pos = math.floor(reaper.GetMediaTrackInfo_Value(enc, "IP_TRACKNUMBER")) - 1
    reaper.SetOnlyTrackSelected(e.tr)
    reaper.ReorderSelectedTracks(enc_pos, 0)   -- vor den Encoder; Reihenfolge = Eingangsnummer
  end
  reaper.SetOnlyTrackSelected(enc)
end

reaper.PreventUIRefresh(-1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.Undo_EndBlock("ICST Ambi: " .. made .. " Mono-Quellen -> AmbiEncoder_64", -1)

-- Diagnose-Log
do
  local f = io.open(dir .. "/../_audit/mono_sources_log.txt", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S"), "  n=", n, "  enc receives vorher: ", table.concat((function() local t = {} for k in pairs(used) do t[#t+1] = k + 1 end table.sort(t) return t end)(), ","), "\n")
    for _, l in ipairs(dbg) do f:write("  ", l, "\n") end
    for r = 0, reaper.GetTrackNumSends(enc, -1) - 1 do
      local st = reaper.GetTrackSendInfo_Value(enc, -1, r, "P_SRCTRACK")
      local _, sn = reaper.GetTrackName(st)
      f:write(string.format("  recv %d von %-12s src=%d dst=%d\n", r, sn,
        math.floor(reaper.GetTrackSendInfo_Value(enc, -1, r, "I_SRCCHAN")),
        math.floor(reaper.GetTrackSendInfo_Value(enc, -1, r, "I_DSTCHAN"))))
    end
    for r = 0, reaper.GetTrackNumSends(enc, 0) - 1 do
      f:write(string.format("  send %d: src=%d dst=%d\n", r,
        math.floor(reaper.GetTrackSendInfo_Value(enc, 0, r, "I_SRCCHAN")),
        math.floor(reaper.GetTrackSendInfo_Value(enc, 0, r, "I_DSTCHAN"))))
    end
    f:close()
  end
end
local _, encname = reaper.GetTrackName(enc)
A.msg(string.format("%d Mono-Quellspur(en) angelegt%s und auf \"%s\" geroutet:\n\n%s%s%s",
  made, created_enc and " (Encoder_64 neu angelegt)" or "", encname, table.concat(report, "\n"),
  #repaired > 0 and ("\n\n" .. table.concat(repaired, "\n")) or "",
  made < n and "\n\nHinweis: nur " .. made .. " freie Encoder-Eingaenge." or ""))
