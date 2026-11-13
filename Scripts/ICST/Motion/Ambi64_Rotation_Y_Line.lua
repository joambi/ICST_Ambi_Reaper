-- AmbiEncoder_64 Rotation + Y-Achsen-Bewegung
-- V4.2: gleiche Bedienung wie Line/Advanced Rotation — selektierter Track,
--       Anzahl Sourcen, Y Start/Ziel frei waehlbar, Y-Form (Fahrt/Pendel),
--       Tempoverlauf, Delay pro Source (Kanon), Clamping, ehrliche Fehlermeldungen.
-- benoetigt ReaImGui (ReaPack)

local ctx = reaper.ImGui_CreateContext('AmbiEncoder Rotation/Y-Move')
local fx_index = 0
local source_count = 8   -- wie viele Sourcen des Encoders bewegt werden (1-64)
local step_points = 64   -- Keyframes pro Achse und Source

local mode = 0           -- 0 = nur Rotation, 1 = nur Y-Fahrt, 2 = Rotation+Y
local rotation_dir = 0   -- 0 = Uhrzeigersinn, 1 = Gegenuhrzeigersinn
local speed = 1.0        -- Rotationen pro Selection

local y_start = 1.0      -- von wo (vorne = 1)
local y_end = -1.0       -- bis wo (hinten = -1)
local y_form = 0         -- 0 = Einmalige Fahrt, 1 = Pendel weich, 2 = Pendel linear
local y_cycles = 1.0     -- Pendelzyklen (nur Pendel)

local tempo_mode = 0     -- 0 konstant, 1 Accel zum Ende, 2 Rit zum Ende, 3 Accel->Mitte->Rit, 4 Rit->Mitte->Accel
local tempo_k = 2.0      -- Intensitaet der Tempo-Kurve (1 = kaum, 4 = stark)
local src_delay = 0.0    -- Sekunden Versatz pro Source (0 = alle gleichzeitig)

local x_params = {10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,
                  90,95,100,105,110,115,120,125,130,135,140,145,150,155,
                  160,165,170,175,180,185,190,195,200,205,210,215,220,225,230,235,
                  240,245,250,255,260,265,270,275,280,285,290,295,300,305,310,315,320,325}
local y_params = {11,16,21,26,31,36,41,46,51,56,61,66,71,76,81,86,
                  91,96,101,106,111,116,121,126,131,136,141,146,151,156,
                  161,166,171,176,181,186,191,196,201,206,211,216,221,226,231,236,
                  241,246,251,256,261,266,271,276,281,286,291,296,301,306,311,316,321,326}

local function clamp01(v)
  if v < 0 then return 0 elseif v > 1 then return 1 end
  return v
end
local function clamp11(v)
  if v < -1 then return -1 elseif v > 1 then return 1 end
  return v
end

local function tempo_warp(p)
  if tempo_mode == 0 or tempo_k <= 1.0 then return p end
  local k = tempo_k
  if tempo_mode == 1 then      -- Accelerando: langsam starten, schnell enden
    return p^k
  elseif tempo_mode == 2 then  -- Ritardando: schnell starten, langsam enden
    return 1 - (1-p)^k
  elseif tempo_mode == 3 then  -- Accelerando zur Mitte, dann Ritardando
    if p < 0.5 then return 0.5 * (2*p)^k
    else return 1 - 0.5 * (2*(1-p))^k end
  else                         -- Ritardando zur Mitte, dann Accelerando
    if p < 0.5 then return 0.5 * (1 - (1-2*p)^k)
    else return 0.5 + 0.5 * ((2*p-1)^k) end
  end
end

-- Position auf der Y-Strecke 0..1 (0 = Y Start, 1 = Y Ziel)
local function y_path(progress)
  local v
  if y_form == 0 then
    v = -1 + progress * 2
  elseif y_form == 1 then
    v = -math.cos(progress * math.pi * 2 * y_cycles)  -- startet bei Y Start
  else
    local phase = (progress * 2 * y_cycles) % 2
    if phase < 1 then v = -1 + phase * 2 else v = 1 - (phase - 1) * 2 end
  end
  return (v + 1) / 2
end

function create_motion()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if start_time == end_time then
    reaper.ShowMessageBox("Bitte zuerst eine Time-Selection setzen!", "Rotation/Y-Move", 0)
    return
  end
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then
    reaper.ShowMessageBox("Bitte zuerst den ICST AmbiEncoder-Track selektieren!", "Rotation/Y-Move", 0)
    return
  end
  if reaper.TrackFX_GetCount(track) <= fx_index then
    reaper.ShowMessageBox("Auf dem selektierten Track liegt kein FX.\nBitte den Track mit dem ICST AmbiEncoder selektieren.", "Rotation/Y-Move", 0)
    return
  end

  local sel_len = end_time - start_time
  local total_delay = (source_count - 1) * src_delay
  local motion_len = sel_len - total_delay
  if motion_len <= 0.05 then
    reaper.ShowMessageBox(
      ("Delay zu gross fuer die Time-Selection:\n%d Sourcen x %.2f s Versatz = %.2f s,\nSelection ist aber nur %.2f s lang.")
        :format(source_count, src_delay, total_delay, sel_len),
      "Rotation/Y-Move", 0)
    return
  end

  local dirRot = (rotation_dir == 0) and 1 or -1
  local written = 0

  for i=1,source_count do
    local bx = (reaper.TrackFX_GetParamNormalized(track, fx_index, x_params[i])*2)-1
    local by = (reaper.TrackFX_GetParamNormalized(track, fx_index, y_params[i])*2)-1
    local envX = reaper.GetFXEnvelope(track, fx_index, x_params[i], true)
    local envY = reaper.GetFXEnvelope(track, fx_index, y_params[i], true)
    if envX and envY then
      reaper.DeleteEnvelopePointRange(envX, start_time, end_time)
      reaper.DeleteEnvelopePointRange(envY, start_time, end_time)

      local baseAngle = math.atan(by, bx)
      local radius = math.sqrt(bx*bx + by*by)
      local t0 = start_time + (i-1) * src_delay

      local function write_point(t, progress)
        local prog = tempo_warp(progress)
        local ang = baseAngle + (prog * math.pi * 2 * dirRot * speed)
        local rotX = math.cos(ang) * radius
        local rotY = math.sin(ang) * radius
        local linY = y_start + (y_end - y_start) * y_path(prog)
        local outX, outY
        if mode == 0 then
          outX, outY = rotX, rotY
        elseif mode == 1 then
          outX, outY = bx, linY
        else
          outX, outY = rotX, rotY + linY
        end
        reaper.InsertEnvelopePoint(envX, t, clamp01((clamp11(outX)+1)/2), 0,0,false,true)
        reaper.InsertEnvelopePoint(envY, t, clamp01((clamp11(outY)+1)/2), 0,0,false,true)
      end

      -- Anker: Source haelt ihre Startposition, bis ihr Delay abgelaufen ist
      if t0 > start_time + 0.0005 then write_point(start_time, 0) end

      for s=0, step_points-1 do
        local lin = s / (step_points-1)
        write_point(t0 + lin * motion_len, lin)
      end

      reaper.Envelope_SortPoints(envX)
      reaper.Envelope_SortPoints(envY)
      written = written + 1
    end
  end

  reaper.UpdateArrange()
  if written == 0 then
    reaper.ShowMessageBox(
      "Es konnten keine Envelopes angelegt werden.\n"..
      "Ist der ICST AmbiEncoder der erste FX auf dem selektierten Track?",
      "Rotation/Y-Move", 0)
  end
end

local open = true
function loop()
  if not open then return end
  local visible
  visible, open = reaper.ImGui_Begin(ctx, 'AmbiEncoder Rotation/Y-Move', true,
    reaper.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    local ch, nv = reaper.ImGui_InputInt(ctx, 'Anzahl Sourcen', source_count)
    if ch and nv then source_count = math.max(1, math.min(64, nv)) end
    ch, nv = reaper.ImGui_InputInt(ctx, 'Keyframes pro Achse', step_points)
    if ch and nv and nv >= 2 then step_points = nv end
    local _
    _, mode = reaper.ImGui_Combo(ctx, 'Modus', mode,
      'Nur Rotation\0Nur Y-Fahrt\0Rotation + Y-Fahrt\0')
    if mode ~= 1 then
      _, rotation_dir = reaper.ImGui_Combo(ctx, 'Drehrichtung', rotation_dir,
        'Uhrzeigersinn\0Gegenuhrzeigersinn\0')
      local chs, sv = reaper.ImGui_InputDouble(ctx, 'Speed (Rotationen)', speed)
      if chs and sv then speed = sv end
    end
    if mode ~= 0 then
      local chd, dv
      chd, dv = reaper.ImGui_InputDouble(ctx, 'Y Start (1 = vorne)', y_start)
      if chd and dv then y_start = clamp11(dv) end
      chd, dv = reaper.ImGui_InputDouble(ctx, 'Y Ziel (-1 = hinten)', y_end)
      if chd and dv then y_end = clamp11(dv) end
      _, y_form = reaper.ImGui_Combo(ctx, 'Y-Form', y_form,
        'Einmalige Fahrt\0Pendel weich\0Pendel linear\0')
      if y_form > 0 then
        local chc, cv = reaper.ImGui_InputDouble(ctx, 'Pendelzyklen', y_cycles)
        if chc and cv then y_cycles = math.max(0.1, cv) end
      end
    end
    _, tempo_mode = reaper.ImGui_Combo(ctx, 'Tempoverlauf', tempo_mode,
      'Konstant\0Accelerando (zum Ende)\0Ritardando (zum Ende)\0Accelerando zur Mitte, dann Ritardando\0Ritardando zur Mitte, dann Accelerando\0')
    if tempo_mode > 0 then
      local chk, nk = reaper.ImGui_InputDouble(ctx, 'Tempo-Intensitaet (1-4)', tempo_k)
      if chk and nk then tempo_k = math.max(1.0, math.min(4.0, nk)) end
    end
    local chd2, nd = reaper.ImGui_InputDouble(ctx, 'Delay pro Source (s)', src_delay)
    if chd2 and nd then src_delay = math.max(0.0, nd) end
    if src_delay > 0 then
      reaper.ImGui_TextWrapped(ctx, ('Source 1 startet sofort, Source %d nach %.2f s. Alle enden innerhalb der Selection.'):format(source_count, (source_count-1)*src_delay))
    end
    reaper.ImGui_TextWrapped(ctx, 'Encoder-Track selektieren, Time-Selection setzen, dann:')
    if reaper.ImGui_Button(ctx, 'Bewegung erstellen') then
      create_motion()
    end
    reaper.ImGui_End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
