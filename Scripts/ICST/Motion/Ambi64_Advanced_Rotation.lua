-- AmbiEncoder_64 Advanced Rotation
-- V4.1: gleiche Bedienung wie das Line-Tool — selektierter Track, Anzahl Sourcen,
--       Tempoverlauf (Accelerando/Ritardando, auch zur Mitte), Delay pro Source (Kanon),
--       Clamping, ehrliche Fehlermeldungen.
-- Bugfix: vorher wurden Winkel UND Zeit mit demselben Faktor verzerrt, dadurch blieb
--         die Rotation hoerbar konstant (Accelerando-Faktor/Kurve wirkten nur auf die
--         Keyframe-Dichte). Jetzt: Zeit uniform, Tempo-Kurve wirkt auf den Winkel.
-- benoetigt ReaImGui (ReaPack)

local ctx = reaper.ImGui_CreateContext('AmbiEncoder Advanced Rotation')
local fx_index = 0
local source_count = 8   -- wie viele Sourcen des Encoders rotiert werden (1-64)
local step_points = 64   -- Keyframes pro Achse und Source

local rotation_dir = 0
local start_angle_deg = 0.0
local end_angle_deg = 360.0
local radius_scale = 1.0
local use_z = false
local point_offset_deg = 0.0 -- zusaetzlicher Winkel-Offset pro Source (raeumliche Spreizung)
local tempo_mode = 0    -- 0 konstant, 1 Accel zum Ende, 2 Rit zum Ende, 3 Accel->Mitte->Rit, 4 Rit->Mitte->Accel
local tempo_k = 2.0     -- Intensitaet der Tempo-Kurve (1 = kaum, 4 = stark)
local src_delay = 0.0   -- Sekunden Versatz pro Source (0 = alle gleichzeitig)

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

function create_rotation()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false,false,0,0,false)
  if start_time == end_time then
    reaper.ShowMessageBox("Bitte zuerst eine Time-Selection setzen!","Advanced Rotation",0)
    return
  end
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then
    reaper.ShowMessageBox("Bitte zuerst den ICST AmbiEncoder-Track selektieren!","Advanced Rotation",0)
    return
  end
  if reaper.TrackFX_GetCount(track) <= fx_index then
    reaper.ShowMessageBox("Auf dem selektierten Track liegt kein FX.\nBitte den Track mit dem ICST AmbiEncoder selektieren.","Advanced Rotation",0)
    return
  end

  local sel_len = end_time - start_time
  local total_delay = (source_count - 1) * src_delay
  local motion_len = sel_len - total_delay
  if motion_len <= 0.05 then
    reaper.ShowMessageBox(
      ("Delay zu gross fuer die Time-Selection:\n%d Sourcen x %.2f s Versatz = %.2f s,\nSelection ist aber nur %.2f s lang.")
        :format(source_count, src_delay, total_delay, sel_len),
      "Advanced Rotation", 0)
    return
  end

  local direction = (rotation_dir==0) and 1 or -1
  local start_rad = math.rad(start_angle_deg)
  local angle_span = (math.rad(end_angle_deg) - start_rad) * direction
  local offset_rad = math.rad(point_offset_deg)

  local written = 0
  for i=1,source_count do
    local x = (reaper.TrackFX_GetParamNormalized(track,fx_index,x_params[i])*2)-1
    local y = (reaper.TrackFX_GetParamNormalized(track,fx_index,y_params[i])*2)-1
    local z = (reaper.TrackFX_GetParamNormalized(track,fx_index,z_params[i])*2)-1
    local envX = reaper.GetFXEnvelope(track,fx_index,x_params[i],true)
    local envY = reaper.GetFXEnvelope(track,fx_index,y_params[i],true)
    local envZ = use_z and reaper.GetFXEnvelope(track,fx_index,z_params[i],true) or nil
    if envX and envY then
      reaper.DeleteEnvelopePointRange(envX,start_time,end_time)
      reaper.DeleteEnvelopePointRange(envY,start_time,end_time)
      if envZ then reaper.DeleteEnvelopePointRange(envZ,start_time,end_time) end

      local baseAngle = math.atan(y,x) + ((i-1)*offset_rad)
      local radius = math.sqrt(x*x+y*y)*radius_scale
      local t0 = start_time + (i-1) * src_delay

      local function write_point(t, progress)
        local ang = baseAngle + start_rad + angle_span * tempo_warp(progress)
        reaper.InsertEnvelopePoint(envX, t, clamp01((math.cos(ang)*radius+1)/2), 0,0,false,true)
        reaper.InsertEnvelopePoint(envY, t, clamp01((math.sin(ang)*radius+1)/2), 0,0,false,true)
        if envZ then reaper.InsertEnvelopePoint(envZ, t, clamp01((z+1)/2), 0,0,false,true) end
      end

      -- Anker: Source haelt ihre Startposition, bis ihr Delay abgelaufen ist
      if t0 > start_time + 0.0005 then write_point(start_time, 0) end

      for s=0, step_points-1 do
        local lin = s / (step_points-1)
        write_point(t0 + lin * motion_len, lin)
      end

      reaper.Envelope_SortPoints(envX)
      reaper.Envelope_SortPoints(envY)
      if envZ then reaper.Envelope_SortPoints(envZ) end
      written = written + 1
    end
  end

  reaper.UpdateArrange()
  if written == 0 then
    reaper.ShowMessageBox(
      "Es konnten keine Envelopes angelegt werden.\n"..
      "Ist der ICST AmbiEncoder der erste FX auf dem selektierten Track?",
      "Advanced Rotation", 0)
  end
end

local open = true
function loop()
  if not open then return end
  local visible
  visible, open = reaper.ImGui_Begin(ctx,'AmbiEncoder Advanced Rotation',true,reaper.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    local ch, nv = reaper.ImGui_InputInt(ctx,'Anzahl Sourcen',source_count)
    if ch and nv then source_count = math.max(1, math.min(64, nv)) end
    ch, nv = reaper.ImGui_InputInt(ctx,'Keyframes pro Achse',step_points)
    if ch and nv and nv >= 2 then step_points = nv end
    local chd, dv
    chd, dv = reaper.ImGui_InputDouble(ctx,'Startwinkel (Grad)',start_angle_deg)
    if chd and dv then start_angle_deg = dv end
    chd, dv = reaper.ImGui_InputDouble(ctx,'Endwinkel (Grad)',end_angle_deg)
    if chd and dv then end_angle_deg = dv end
    chd, dv = reaper.ImGui_SliderDouble(ctx,'Radius-Skalierung',radius_scale,0.1,2.0)
    if chd and dv then radius_scale = dv end
    local _
    _, rotation_dir = reaper.ImGui_Combo(ctx,'Drehrichtung',rotation_dir,'Uhrzeigersinn\0Gegenuhrzeigersinn\0')
    local chz, uz = reaper.ImGui_Checkbox(ctx,'Z-Achse beibehalten',use_z)
    if chz then use_z = uz end
    chd, dv = reaper.ImGui_InputDouble(ctx,'Offset pro Source (Grad)',point_offset_deg)
    if chd and dv then point_offset_deg = dv end
    _, tempo_mode = reaper.ImGui_Combo(ctx,'Tempoverlauf',tempo_mode,
      'Konstant\0Accelerando (zum Ende)\0Ritardando (zum Ende)\0Accelerando zur Mitte, dann Ritardando\0Ritardando zur Mitte, dann Accelerando\0')
    if tempo_mode > 0 then
      local chk, nk = reaper.ImGui_InputDouble(ctx,'Tempo-Intensitaet (1-4)',tempo_k)
      if chk and nk then tempo_k = math.max(1.0, math.min(4.0, nk)) end
    end
    chd, dv = reaper.ImGui_InputDouble(ctx,'Delay pro Source (s)',src_delay)
    if chd and dv then src_delay = math.max(0.0, dv) end
    if src_delay > 0 then
      reaper.ImGui_TextWrapped(ctx, ('Source 1 startet sofort, Source %d nach %.2f s. Alle enden innerhalb der Selection.'):format(source_count, (source_count-1)*src_delay))
    end
    reaper.ImGui_TextWrapped(ctx,'Encoder-Track selektieren, Time-Selection setzen, dann:')
    if reaper.ImGui_Button(ctx,'Rotation erstellen') then
      create_rotation()
    end
    reaper.ImGui_End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
