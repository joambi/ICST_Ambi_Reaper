-- AmbiEncoder_64 LINE - lineare Gruppenbewegung mit Formwahl
-- V4.1: echtes Line-Tool (war vorher faelschlich eine Kopie von Advanced Rotation)
-- Features: Tempoverlauf (Accelerando/Ritardando zur Mitte), Source-Delay (Kanon),
--           Pfad-Modus: relativ zur aktuellen Position ODER absolut Start -> Ziel (XYZ)
-- Arbeitet auf dem AUSGEWAEHLTEN Track (Encoder-Track selektieren), wie das Circle-Tool.
-- benoetigt ReaImGui (ReaPack)

local ctx = reaper.ImGui_CreateContext('AmbiEncoder Line')
local fx_index = 0
local source_count = 8  -- wie viele Sourcen des Encoders bewegt werden (1-64)
local step_points = 64  -- Keyframes pro Achse und Source

local path_mode = 1     -- 0 = relativ zur aktuellen Position, 1 = absolut Start -> Ziel
local move_mode = 0     -- nur relativ: 0 = XY, 1 = Z
local form_mode = 0     -- 0 = Einmalige Fahrt, 1 = Pendel weich (Sinus), 2 = Pendel linear (Dreieck)
local speed = 1.0
local dir_mode = 0      -- 0 = normal, 1 = invertiert
local tempo_mode = 0    -- 0 = konstant, 1 = Accelerando zur Mitte / Ritardando danach, 2 = umgekehrt
local tempo_k = 2.0     -- Intensitaet der Tempo-Kurve (1 = kaum, 4 = stark)
local src_delay = 0.0   -- Sekunden Versatz pro Source (0 = alle gleichzeitig)

-- Absoluter Pfad (Koordinaten -1..+1 wie im ICST AmbiEncoder)
local sx, sy, sz = -1.0, 0.0, 0.0   -- Start (links)
local tx, ty, tz =  1.0, 0.0, 0.0   -- Ziel  (rechts)

local x_params = {10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,
                  90,95,100,105,110,115,120,125,130,135,140,145,150,155,
                  160,165,170,175,180,185,190,195,200,205,210,215,220,225,230,235,
                  240,245,250,255,260,265,270,275,280,285,290,295,300,305,310,315,320,325}
local y_params = {11,16,21,26,31,36,41,46,51,56,61,66,71,76,81,86,
                  91,96,101,106,111,116,121,126,131,136,141,146,151,156,
                  161,166,171,176,181,186,191,196,201,206,211,216,221,226,231,236,
                  241,246,251,256,261,266,271,276,281,286,291,296,301,306,311,316,321,326}
local z_params = {12,17,22,27,32,37,42,47,52,57,62,67,72,77,82,87,
                  92,97,102,107,112,117,122,127,132,137,142,147,152,157,
                  162,167,172,177,182,187,192,197,202,207,212,217,222,227,232,237,
                  242,247,252,257,262,267,272,277,282,287,292,297,302,307,312,317,322,327}

local function clamp01(v)
  if v < 0 then return 0 elseif v > 1 then return 1 end
  return v
end
local function clamp11(v)
  if v < -1 then return -1 elseif v > 1 then return 1 end
  return v
end

-- Zeit-Verzerrung: 1 = langsam starten, zur Mitte am schnellsten, weich auslaufen
--                  2 = schnell starten, zur Mitte am langsamsten, schnell enden
local function tempo_warp(p)
  if tempo_mode == 0 or tempo_k <= 1.0 then return p end
  local k = tempo_k
  if tempo_mode == 1 then
    if p < 0.5 then return 0.5 * (2*p)^k
    else return 1 - 0.5 * (2*(1-p))^k end
  else
    if p < 0.5 then return 0.5 * (1 - (1-2*p)^k)
    else return 0.5 + 0.5 * ((2*p-1)^k) end
  end
end

-- Bewegungsform: liefert -1..+1 ueber den Zeitverlauf
local function shape_value(progress)
  local v
  if form_mode == 0 then
    v = -1 + progress * 2
  elseif form_mode == 1 then
    v = -math.cos(progress * math.pi * 2 * speed)  -- startet am Startpunkt, nicht in der Mitte
  else
    local phase = (progress * 2 * speed) % 2
    if phase < 1 then v = -1 + phase * 2 else v = 1 - (phase - 1) * 2 end
  end
  if dir_mode == 1 then v = -v end
  return v
end

-- Position auf dem Pfad 0..1 (0 = Start, 1 = Ziel)
local function path_pos(progress)
  return (shape_value(tempo_warp(progress)) + 1) / 2
end

local function create_motion()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if start_time == end_time then
    reaper.ShowMessageBox("Bitte vorher eine Region/Time-Selection setzen!", "AmbiEncoder Line", 0)
    return
  end
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then
    reaper.ShowMessageBox("Bitte zuerst den ICST AmbiEncoder-Track selektieren!", "AmbiEncoder Line", 0)
    return
  end

  local sel_len = end_time - start_time
  local total_delay = (source_count - 1) * src_delay
  local motion_len = sel_len - total_delay
  if motion_len <= 0.05 then
    reaper.ShowMessageBox(
      ("Delay zu gross fuer die Time-Selection:\n%d Sourcen x %.2f s Versatz = %.2f s,\nSelection ist aber nur %.2f s lang.")
        :format(source_count, src_delay, total_delay, sel_len),
      "AmbiEncoder Line", 0)
    return
  end

  -- Welche Achsen schreiben?
  local wantX, wantY, wantZ
  if path_mode == 1 then
    wantX = sx ~= tx; wantY = sy ~= ty; wantZ = sz ~= tz
    if not (wantX or wantY or wantZ) then
      reaper.ShowMessageBox("Start und Ziel sind identisch - keine Bewegung.", "AmbiEncoder Line", 0)
      return
    end
  else
    wantX = move_mode == 0; wantY = move_mode == 0; wantZ = move_mode == 1
  end

  local basesX, basesY, basesZ = {}, {}, {}
  for i=1,source_count do
    basesX[i] = (reaper.TrackFX_GetParamNormalized(track, fx_index, x_params[i]) * 2) - 1
    basesY[i] = (reaper.TrackFX_GetParamNormalized(track, fx_index, y_params[i]) * 2) - 1
    basesZ[i] = (reaper.TrackFX_GetParamNormalized(track, fx_index, z_params[i]) * 2) - 1
  end

  for i=1,source_count do
    local envX = wantX and reaper.GetFXEnvelope(track, fx_index, x_params[i], true) or nil
    local envY = wantY and reaper.GetFXEnvelope(track, fx_index, y_params[i], true) or nil
    local envZ = wantZ and reaper.GetFXEnvelope(track, fx_index, z_params[i], true) or nil

    if envX then reaper.DeleteEnvelopePointRange(envX, start_time, end_time) end
    if envY then reaper.DeleteEnvelopePointRange(envY, start_time, end_time) end
    if envZ then reaper.DeleteEnvelopePointRange(envZ, start_time, end_time) end

    local t0 = start_time + (i-1) * src_delay

    local function write_point(t, progress)
      local px, py, pz
      if path_mode == 1 then
        local pp = path_pos(progress)
        px = sx + pp * (tx - sx)
        py = sy + pp * (ty - sy)
        pz = sz + pp * (tz - sz)
      else
        local offset = shape_value(tempo_warp(progress))
        px = basesX[i] + offset
        py = basesY[i] + offset
        pz = basesZ[i] + offset
      end
      if envX then reaper.InsertEnvelopePoint(envX, t, clamp01((clamp11(px)+1)/2), 0,0,false,true) end
      if envY then reaper.InsertEnvelopePoint(envY, t, clamp01((clamp11(py)+1)/2), 0,0,false,true) end
      if envZ then reaper.InsertEnvelopePoint(envZ, t, clamp01((clamp11(pz)+1)/2), 0,0,false,true) end
    end

    -- Anker: Source haelt ihre Startposition, bis ihr Delay abgelaufen ist
    if t0 > start_time + 0.0005 then
      write_point(start_time, 0)
    end

    for s=0, step_points-1 do
      local lin = s / (step_points-1)
      write_point(t0 + lin * motion_len, lin)
    end

    if envX then reaper.Envelope_SortPoints(envX) end
    if envY then reaper.Envelope_SortPoints(envY) end
    if envZ then reaper.Envelope_SortPoints(envZ) end
  end

  reaper.UpdateArrange()
end

local function coord_input(label, v)
  local ch, nv = reaper.ImGui_InputDouble(ctx, label, v)
  if ch and nv then return clamp11(nv) end
  return v
end

local open = true
local function loop()
  if not open then return end
  local visible
  visible, open = reaper.ImGui_Begin(ctx, 'AmbiEncoder Line', true,
    reaper.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    local ch, nv = reaper.ImGui_InputInt(ctx, 'Anzahl Sourcen', source_count)
    if ch and nv then source_count = math.max(1, math.min(64, nv)) end
    ch, nv = reaper.ImGui_InputInt(ctx, 'Keyframes pro Achse', step_points)
    if ch and nv and nv >= 2 then step_points = nv end
    local _
    _, path_mode = reaper.ImGui_Combo(ctx, 'Pfad', path_mode, 'Relativ zur Position\0Absolut: Start -> Ziel\0')
    if path_mode == 1 then
      reaper.ImGui_Text(ctx, 'Koordinaten -1..+1 (X: li/re, Y: hinten/vorne, Z: unten/oben)')
      sx = coord_input('Start X', sx); sy = coord_input('Start Y', sy); sz = coord_input('Start Z', sz)
      tx = coord_input('Ziel X', tx);  ty = coord_input('Ziel Y', ty);  tz = coord_input('Ziel Z', tz)
    else
      _, move_mode = reaper.ImGui_Combo(ctx, 'Bewegung', move_mode, 'XY Ebene\0Z Achse\0')
    end
    _, form_mode = reaper.ImGui_Combo(ctx, 'Form', form_mode, 'Einmalige Fahrt\0Pendel weich\0Pendel linear\0')
    _, speed = reaper.ImGui_InputDouble(ctx, 'Pendelzyklen (nur Pendel)', speed)
    _, dir_mode = reaper.ImGui_Combo(ctx, 'Richtung', dir_mode, 'Normal\0Invertiert\0')
    _, tempo_mode = reaper.ImGui_Combo(ctx, 'Tempoverlauf', tempo_mode, 'Konstant\0Accelerando zur Mitte, dann Ritardando\0Ritardando zur Mitte, dann Accelerando\0')
    if tempo_mode > 0 then
      local chk, nk = reaper.ImGui_InputDouble(ctx, 'Tempo-Intensitaet (1-4)', tempo_k)
      if chk and nk then tempo_k = math.max(1.0, math.min(4.0, nk)) end
    end
    local chd, nd = reaper.ImGui_InputDouble(ctx, 'Delay pro Source (s)', src_delay)
    if chd and nd then src_delay = math.max(0.0, nd) end
    if src_delay > 0 then
      reaper.ImGui_TextWrapped(ctx, ('Source 1 startet sofort, Source %d nach %.2f s. Alle enden innerhalb der Selection.'):format(source_count, (source_count-1)*src_delay))
    end
    reaper.ImGui_TextWrapped(ctx, 'Encoder-Track selektieren, Time-Selection setzen, dann:')
    if reaper.ImGui_Button(ctx, 'Linie erstellen') then
      create_motion()
    end
    reaper.ImGui_End(ctx)
  end
  if open then reaper.defer(loop) end
end
loop()
