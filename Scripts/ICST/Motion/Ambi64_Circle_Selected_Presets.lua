-- AmbiEncoder_64: Auswählbare Punkte + Kreis-Presets + Export/Import + Visualisierung
-- V2.0: Live-Vorschau nach Haus-Standard (Envelopes werden während der
--       Vorschau temporär deaktiviert, Positionen beim Stop wiederhergestellt)
--       + "Write": Bewegung (Rotation + RandomWalk) als Automation in die
--       Time-Selection schreiben (eine Undo-Stufe, Zielbereich wird ersetzt).
-- benoetigt ReaImGui (ReaPack)

if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox(
    "ReaImGui extension not found.\nInstall it via ReaPack: cfillion/reaimgui.",
    "Kreis+Walk", 0)
  return
end

-- === Parameter ===
local circle_radius = 0.5
local circle_points = 64
local circle_startAngle = 0.0
local circle_clockwise = true
local angle_step = 1.0
local offset_per_point = 0.0
local rot_speed = 0.1
local random_speed = 0.01
local random_range = 1.0
local include_z = false
local write_pps = 20        -- Punkte pro Sekunde beim Schreiben
local write_replace = true  -- Zielbereich vorher raeumen
local live_restore = true   -- Positionen beim Stop wiederherstellen
local status_msg = ''

local LIVE_FPS_REF = 30     -- Referenz-Framerate: RandomWalk-Schrittweite Live vs. Write

-- === Track/FX aufloesen ===
local track, fx_index = nil, -1
local function find_encoder_fx(tr)
  local n = reaper.TrackFX_GetCount(tr)
  for fx = 0, n - 1 do
    local _, name = reaper.TrackFX_GetFXName(tr, fx, '')
    if name:lower():find('ambiencoder') and name:find('64') then return fx end
  end
  for fx = 0, n - 1 do
    local _, name = reaper.TrackFX_GetFXName(tr, fx, '')
    if name:lower():find('ambiencoder') then return fx end
  end
  return -1
end

local function resolve_track()
  local sel = reaper.GetSelectedTrack(0, 0)
  if not sel then
    status_msg = 'Bitte zuerst den ICST AmbiEncoder-Track selektieren!'
    return false
  end
  local fx = find_encoder_fx(sel)
  if fx < 0 then
    status_msg = 'Kein ICST AmbiEncoder auf dem selektierten Track!'
    return false
  end
  track, fx_index = sel, fx
  return true
end

-- === Parameter-Map (namensbasiert, Fallback X1=10 / Schrittweite 5) ===
local pmap = nil  -- pmap[i] = {x=,y=,z=}
local function build_param_map()
  pmap = {}
  local by_name = {}
  local n = reaper.TrackFX_GetNumParams(track, fx_index)
  for p = 0, n - 1 do
    local _, pname = reaper.TrackFX_GetParamName(track, fx_index, p, '')
    pname = (pname or ''):lower():gsub('%s+', '')
    local axis, idx = pname:match('^([xyz])(%d+)$')
    if axis and idx then by_name[axis .. idx] = p end
  end
  for i = 1, 64 do
    local x, y, z = by_name['x' .. i], by_name['y' .. i], by_name['z' .. i]
    if x and y then
      pmap[i] = { x = x, y = y, z = z or (x + 2) }
    else
      pmap[i] = { x = 10 + (i - 1) * 5, y = 11 + (i - 1) * 5, z = 12 + (i - 1) * 5 }
    end
  end
end

-- === Daten ===
local points = {}
for i = 1, 64 do
  points[i] = { pos = {x=0,y=0,z=0}, offset = {x=0,y=0,z=0}, base = {x=0,y=0,z=0} }
end
local gp = {x=0,y=0,z=0}
local selectedPoints = {}
for i = 1, 64 do selectedPoints[i] = false end

local function any_selected()
  for i = 1, 64 do if selectedPoints[i] then return true end end
  return false
end

-- === Helper ===
local function setParam(idx, v)
  if not track then return end
  reaper.TrackFX_SetParamNormalized(track, fx_index, idx,
    math.max(0, math.min(1, (v + 1) / 2)))
end
local function getParam(idx)
  if not track then return 0 end
  local v = reaper.TrackFX_GetParamNormalized(track, fx_index, idx)
  return (v * 2) - 1
end

-- === Kreis setzen ===
local function applyCircle()
  for i = 1, circle_points do
    if selectedPoints[i] then
      local angle = circle_startAngle + (i-1) * (2*math.pi/circle_points) * angle_step
      if circle_clockwise then angle = -angle end
      local radius = circle_radius + (i-1) * offset_per_point
      setParam(pmap[i].x, math.cos(angle) * radius)
      setParam(pmap[i].y, math.sin(angle) * radius)
      setParam(pmap[i].z, 0.0)
    end
  end
  status_msg = 'Kreis gesetzt.'
end

-- === Positionen einlesen (Basis fuer Bewegung) ===
local function readBasePositions()
  local cx, cy, cz, count = 0, 0, 0, 0
  for i, p in ipairs(points) do
    if selectedPoints[i] then
      p.pos.x, p.pos.y, p.pos.z = getParam(pmap[i].x), getParam(pmap[i].y), getParam(pmap[i].z)
      p.base.x, p.base.y, p.base.z = p.pos.x, p.pos.y, p.pos.z
      cx, cy, cz = cx + p.pos.x, cy + p.pos.y, cz + p.pos.z
      count = count + 1
    end
  end
  if count > 0 then
    gp.x, gp.y, gp.z = cx/count, cy/count, cz/count
    for i, p in ipairs(points) do
      if selectedPoints[i] then
        p.offset.x = p.pos.x - gp.x
        p.offset.y = p.pos.y - gp.y
        p.offset.z = p.pos.z - gp.z
      end
    end
  end
  return count
end

-- === Bewegungsformel (gemeinsam fuer Live-Vorschau und Write) ===
-- t: Zeit seit Start; g: Gruppenzentrum-Tabelle {x,y,z}
-- liefert pro Quelle i die Position
local function motion_pos(i, t, g)
  local ca = math.cos(t * rot_speed * 2 * math.pi)
  local sa = math.sin(t * rot_speed * 2 * math.pi)
  local p = points[i]
  local rx = p.offset.x * ca - p.offset.y * sa
  local ry = p.offset.x * sa + p.offset.y * ca
  return g.x + rx, g.y + ry, g.z + p.offset.z
end

local function randomWalkStep(g, scale)
  g.x = math.max(-random_range, math.min(random_range, g.x + (math.random()*2-1) * random_speed * scale))
  g.y = math.max(-random_range, math.min(random_range, g.y + (math.random()*2-1) * random_speed * scale))
  if include_z then
    g.z = math.max(-random_range, math.min(random_range, g.z + (math.random()*2-1) * random_speed * scale))
  end
end

-- === Live-Vorschau (Haus-Standard) ===
-- Aktive Envelopes auf den Ziel-Parametern wuerden die Live-Werte sofort
-- ueberschreiben (Read-Mode) -> waehrend der Vorschau ACT 0, beim Stop ACT 1.
local live_running = false
local live_t0 = 0
local live_susp = {}

local function live_suspend_envs()
  live_susp = {}
  for i = 1, 64 do
    if selectedPoints[i] then
      local params = { pmap[i].x, pmap[i].y, include_z and pmap[i].z or nil }
      for _, p in ipairs(params) do
        local env = reaper.GetFXEnvelope(track, fx_index, p, false)
        if env then
          local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
          if ok and chunk and chunk:find('\nACT 1') then
            reaper.SetEnvelopeStateChunk(env, chunk:gsub('\nACT %d', '\nACT 0', 1), false)
            live_susp[#live_susp + 1] = env
          end
        end
      end
    end
  end
end

local function live_restore_envs()
  for _, env in ipairs(live_susp) do
    if reaper.ValidatePtr2(0, env, 'TrackEnvelope*') then
      local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
      if ok and chunk then
        reaper.SetEnvelopeStateChunk(env, chunk:gsub('\nACT %d', '\nACT 1', 1), false)
      end
    end
  end
  live_susp = {}
end

local function live_stop(restore)
  live_running = false
  if restore and track and reaper.ValidatePtr2(0, track, 'MediaTrack*') then
    for i, p in ipairs(points) do
      if selectedPoints[i] then
        setParam(pmap[i].x, p.base.x)
        setParam(pmap[i].y, p.base.y)
        setParam(pmap[i].z, p.base.z)
        p.pos.x, p.pos.y, p.pos.z = p.base.x, p.base.y, p.base.z
      end
    end
  end
  live_restore_envs()
  status_msg = 'Live-Vorschau gestoppt.'
end

local function live_start()
  if not resolve_track() then return end
  if not any_selected() then
    status_msg = 'Bitte zuerst Punkte auswählen!'
    return
  end
  build_param_map()
  if readBasePositions() == 0 then
    status_msg = 'Keine selektierten Punkte gefunden.'
    return
  end
  live_suspend_envs()
  live_t0 = reaper.time_precise()
  live_running = true
  status_msg = (#live_susp > 0)
    and string.format('Live-Vorschau läuft… (%d Envelope(s) temporär deaktiviert)', #live_susp)
    or  'Live-Vorschau läuft…'
end

local function live_update()
  if not (track and reaper.ValidatePtr2(0, track, 'MediaTrack*')) then
    live_running = false; track = nil; live_susp = {}
    return
  end
  randomWalkStep(gp, 1.0)
  local t = reaper.time_precise() - live_t0
  for i, p in ipairs(points) do
    if selectedPoints[i] then
      local x, y, z = motion_pos(i, t, gp)
      setParam(pmap[i].x, x)
      setParam(pmap[i].y, y)
      setParam(pmap[i].z, z)
      p.pos.x, p.pos.y, p.pos.z = x, y, z
    end
  end
end

-- === Write: Bewegung als Automation in die Time-Selection schreiben ===
local function get_or_create_env(param)
  return reaper.GetFXEnvelope(track, fx_index, param, true)
end

local function write_automation()
  local t0, t1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if t1 <= t0 then
    status_msg = 'Bitte zuerst eine Time-Selection setzen!'
    return
  end
  if not resolve_track() then return end
  if not any_selected() then
    status_msg = 'Bitte zuerst Punkte auswählen!'
    return
  end
  if live_running then live_stop(live_restore) end
  build_param_map()
  if readBasePositions() == 0 then
    status_msg = 'Keine selektierten Punkte gefunden.'
    return
  end

  local len = t1 - t0
  local dt = 1.0 / math.max(1, write_pps)
  local steps = math.max(1, math.floor(len / dt + 0.5))
  -- RandomWalk-Schrittweite an die Schreib-Rate anpassen, damit die
  -- Bewegung wie in der Live-Vorschau wirkt (Referenz ~30 fps)
  local rw_scale = dt * LIVE_FPS_REF

  -- Simulation laeuft auf einer Kopie des Gruppenzentrums
  local g = { x = gp.x, y = gp.y, z = gp.z }

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Envelopes holen/erzeugen und Zielbereich raeumen
  local envs = {}   -- envs[i] = {x=env,y=env,z=env|nil}
  local n_env = 0
  for i = 1, 64 do
    if selectedPoints[i] then
      envs[i] = {
        x = get_or_create_env(pmap[i].x),
        y = get_or_create_env(pmap[i].y),
        z = include_z and get_or_create_env(pmap[i].z) or nil,
      }
      for _, env in pairs(envs[i]) do
        n_env = n_env + 1
        if write_replace then
          reaper.DeleteEnvelopePointRange(env, t0, t1)
        end
      end
    end
  end

  -- Punkte schreiben (Shape 0 = linear)
  local written = 0
  for k = 0, steps do
    local t = math.min(k * dt, len)
    if k > 0 then randomWalkStep(g, rw_scale) end
    for i = 1, 64 do
      if selectedPoints[i] then
        local x, y, z = motion_pos(i, t, g)
        reaper.InsertEnvelopePoint(envs[i].x, t0 + t, math.max(0, math.min(1, (x+1)/2)), 0, 0, false, true)
        reaper.InsertEnvelopePoint(envs[i].y, t0 + t, math.max(0, math.min(1, (y+1)/2)), 0, 0, false, true)
        written = written + 2
        if envs[i].z then
          reaper.InsertEnvelopePoint(envs[i].z, t0 + t, math.max(0, math.min(1, (z+1)/2)), 0, 0, false, true)
          written = written + 1
        end
      end
    end
  end
  for i = 1, 64 do
    if envs[i] then
      for _, env in pairs(envs[i]) do reaper.Envelope_SortPoints(env) end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock('Kreis+Walk: Bewegung als Automation schreiben', -1)

  status_msg = string.format(
    'Write: %d Punkt(e) in %d Envelope(s) geschrieben (%.2f s, %d Pkt/s).',
    written, n_env, len, write_pps)
end

-- === Export / Import Auswahl ===
local function exportSelection(path)
  local f = io.open(path, 'w'); if not f then return end
  for i = 1, 64 do f:write(selectedPoints[i] and '1' or '0'); if i < 64 then f:write(',') end end
  f:close()
end
local function importSelection(path)
  local f = io.open(path, 'r'); if not f then return end
  local data = f:read('*a'); f:close()
  local idx = 1
  for val in string.gmatch(data, '[^,]+') do selectedPoints[idx] = (val == '1'); idx = idx + 1 end
end

-- === Presets ===
local presetDir = reaper.GetResourcePath() .. '/AmbiPresets'
reaper.RecursiveCreateDirectory(presetDir, 0)

local function listPresets()
  local list = {}
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(presetDir, i)
    if not fname then break end
    if fname:sub(-4) == '.txt' then list[#list + 1] = fname:gsub('%.txt$', '') end
    i = i + 1
  end
  return list
end

local function saveCirclePreset(name)
  if not name or name == '' then return end
  local f = io.open(presetDir .. '/' .. name .. '.txt', 'w'); if not f then return end
  f:write(string.format('%f;%d;%f;%d;%f;%f\n', circle_radius, circle_points,
    circle_startAngle, circle_clockwise and 1 or 0, angle_step, offset_per_point))
  f:close()
  status_msg = "Preset '" .. name .. "' gespeichert."
end

local function loadCirclePreset(name)
  if not name or name == '' then return end
  local f = io.open(presetDir .. '/' .. name .. '.txt', 'r'); if not f then return end
  local line = f:read('*l'); f:close()
  if line then
    local r, p, a, c, as, off = line:match('([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)')
    circle_radius = tonumber(r) or circle_radius
    circle_points = tonumber(p) or circle_points
    circle_startAngle = tonumber(a) or circle_startAngle
    circle_clockwise = (tonumber(c) == 1)
    angle_step = tonumber(as) or angle_step
    offset_per_point = tonumber(off) or offset_per_point
    status_msg = "Preset '" .. name .. "' geladen."
  end
end

-- === Visualisierung ===
local function drawFigure(ctx)
  local draw = reaper.ImGui_GetWindowDrawList(ctx)
  local cx, cy = reaper.ImGui_GetWindowPos(ctx)
  local w, h = reaper.ImGui_GetWindowSize(ctx)
  local centerX, centerY = cx + w/2, cy + h/2
  local scale = (math.min(w, h) / 2) * 0.8
  reaper.ImGui_DrawList_AddCircle(draw, centerX, centerY, scale * random_range, 0x44FFFFFF, 64, 1.0)
  local px, py, prevX, prevY
  for i, p in ipairs(points) do
    if selectedPoints[i] then
      px, py = centerX + p.pos.x * scale, centerY - p.pos.y * scale
      if prevX then reaper.ImGui_DrawList_AddLine(draw, prevX, prevY, px, py, 0xFF00FF00, 1.5) end
      reaper.ImGui_DrawList_AddCircleFilled(draw, px, py, 3, 0xFFFFFFFF)
      prevX, prevY = px, py
    end
  end
end

-- === GUI ===
local ctx = reaper.ImGui_CreateContext('AmbiEncoder64 Kreis+Walk (Presets)')
reaper.ImGui_SetNextWindowSize(ctx, 700, 980, reaper.ImGui_Cond_FirstUseEver())

local presetName = ''
local presets = listPresets()
local selectedPresetIndex = 0

local function loop()
  local visible, open = reaper.ImGui_Begin(ctx, 'AmbiEncoder64 Kreis+Walk (Presets)', true)
  if visible then
    reaper.ImGui_Text(ctx, 'Punkte auswählen:')
    if reaper.ImGui_Button(ctx, 'Alle auswählen') then for i = 1, 64 do selectedPoints[i] = true end end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Alle abwählen') then for i = 1, 64 do selectedPoints[i] = false end end
    for i = 1, 64 do
      local changed
      changed, selectedPoints[i] = reaper.ImGui_Checkbox(ctx, tostring(i), selectedPoints[i])
      if (i % 8) ~= 0 then reaper.ImGui_SameLine(ctx) end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Kreis-Offsets setzen')
    _, circle_radius = reaper.ImGui_SliderDouble(ctx, 'Kreis-Radius', circle_radius, 0.1, 1.0, '%.2f')
    _, circle_points = reaper.ImGui_SliderInt(ctx, 'Punkte-Anzahl', circle_points, 1, 64)
    _, circle_startAngle = reaper.ImGui_SliderDouble(ctx, 'Startwinkel', circle_startAngle, 0.0, math.pi * 2, '%.2f')
    _, circle_clockwise = reaper.ImGui_Checkbox(ctx, 'Uhrzeigersinn', circle_clockwise)
    _, angle_step = reaper.ImGui_SliderDouble(ctx, 'Winkel-Abstand', angle_step, 0.1, 3.0, '%.2f')
    _, offset_per_point = reaper.ImGui_SliderDouble(ctx, 'Abstandszuwachs', offset_per_point, -0.05, 0.05, '%.3f')
    if reaper.ImGui_Button(ctx, 'Apply Kreis') and resolve_track() then
      build_param_map()
      applyCircle()
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Preset-Name:')
    local ch; ch, presetName = reaper.ImGui_InputText(ctx, '##PresetName', presetName)
    if reaper.ImGui_Button(ctx, 'Preset speichern') then
      saveCirclePreset(presetName)
      presets = listPresets()
    end

    if #presets > 0 then
      local comboItems = table.concat(presets, '\0') .. '\0'
      local changedIdx
      changedIdx, selectedPresetIndex = reaper.ImGui_Combo(ctx, '##PresetList', selectedPresetIndex, comboItems)
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Preset laden') then
        loadCirclePreset(presets[selectedPresetIndex + 1])
      end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Export /  Import Punkte')
    if reaper.ImGui_Button(ctx, 'Punkte exportieren') then
      local exportPath = reaper.GetResourcePath() .. '/points_export.txt'
      exportSelection(exportPath)
      status_msg = 'Exportiert nach: ' .. exportPath
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Punkte importieren') then
      local ok, path = reaper.GetUserFileNameForRead(
        reaper.GetResourcePath() .. '/points_export.txt', 'Punkte Importieren', 'txt')
      if ok then importSelection(path) end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Bewegung')
    _, rot_speed = reaper.ImGui_SliderDouble(ctx, 'Rotationsgeschw.', rot_speed, 0.0, 2.0, '%.3f')
    _, random_speed = reaper.ImGui_SliderDouble(ctx, 'RandomWalk Speed', random_speed, 0.0, 0.1, '%.4f')
    _, random_range = reaper.ImGui_SliderDouble(ctx, 'Random Range', random_range, 0.1, 1.0, '%.2f')
    _, include_z = reaper.ImGui_Checkbox(ctx, 'Z-Achse', include_z)

    -- Live-Vorschau
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Live-Vorschau')
    local chr, nr = reaper.ImGui_Checkbox(ctx, 'Positionen bei Stop wiederherstellen', live_restore)
    if chr then live_restore = nr end
    if reaper.ImGui_Button(ctx,
        live_running and 'Live-Vorschau stoppen' or 'Live-Vorschau starten', 220, 30) then
      if live_running then live_stop(live_restore) else live_start() end
    end

    -- Write
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Write: Bewegung als Automation')
    _, write_pps = reaper.ImGui_SliderInt(ctx, 'Punkte pro Sekunde', write_pps, 2, 60)
    local chw, nw = reaper.ImGui_Checkbox(ctx, 'Zielbereich ersetzen', write_replace)
    if chw then write_replace = nw end
    if reaper.ImGui_Button(ctx, 'Write → Automation (Time-Selection)', 280, 32) then
      write_automation()
    end

    if status_msg ~= '' then
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_TextWrapped(ctx, status_msg)
    end

    drawFigure(ctx)
    reaper.ImGui_End(ctx)
  end

  if live_running then live_update() end

  if open then
    reaper.defer(loop)
  else
    if live_running then live_stop(live_restore) end
  end
end

reaper.defer(loop)
