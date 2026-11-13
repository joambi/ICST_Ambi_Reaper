-- ICST AmbiEncoder_64 Spiral Walk GUI mit JSON Load/Save, Speed Kontrolle, Radius-Limit und Z-Achsen-Scaler
-- Startpositionen der Punkte werden übernommen und starten exakt am Beginn der Zeitauswahl

local ctx = reaper.ImGui_CreateContext('ICST AmbiEncoder_64 Spiral Walk')
local visible = true

-- Default Settings
local steps = 200
local spiralSpread = 1.0
local maxRadius = 1.0
local minRadius = 0.1
local accelerando = 1.0
local reverseAccel = false
local includeZ = true
local numPointsToProcess = 8
local randomSeed = os.time()
local spiralOutward = true
local holdEnd = true
local speed = 1.0
local zScale = 1.0
-- V4.1: Perlenkette - alle Punkte folgen derselben Spirale mit Delay
local pearlMode = false
local pearlDelay = 0.25
local palindrome = false  -- Spirale einwaerts und wieder auswaerts (bzw. umgekehrt)
local rotPalindrome = false -- im Palindrom auch die Drehrichtung auf dem Rueckweg umkehren
local radiusMode = 1        -- 0 = relativ (ab aktueller Position), 1 = absolut Start -> Ziel
local radiusStart = 0.9     -- absoluter Startradius (0..1)
local radiusEnd = 0.15      -- absoluter Zielradius (0..1)

local presets = {}
local script_path = ({reaper.get_action_context()})[2]:match("^(.*[/\\])")
local presetDir = script_path
local presetFileName = "spiralwalk_presets.json"
local presetFilePath = presetDir .. presetFileName
local presetInput = ""
local presetDirInput = presetDir

-- JSON Helper
local json = {}
function json.encode(val)
  local t = type(val)
  if t == "table" then
    local isArray = (#val > 0)
    local out = {}
    if isArray then
      for i,v in ipairs(val) do table.insert(out,json.encode(v)) end
      return "["..table.concat(out,",").."]"
    else
      for k,v in pairs(val) do table.insert(out,string.format("%q:%s",k,json.encode(v))) end
      return "{"..table.concat(out,",").."}"
    end
  elseif t=="string" then
    return string.format("%q",val)
  elseif t=="number" or t=="boolean" then
    return tostring(val)
  else
    return "null"
  end
end
function json.decode(str)
  local f = load("return "..str,"json","t",{})
  if not f then return {} end
  local ok,res = pcall(f)
  if ok and type(res)=="table" then return res else return {} end
end

local function savePresetsToDisk()
  local f = io.open(presetFilePath,"w")
  if f then f:write(json.encode(presets)) f:close() end
end

local function loadPresetsFromDisk()
  local f = io.open(presetFilePath,"r")
  if f then
    local content = f:read("*a")
    f:close()
    local loaded = json.decode(content)
    if type(loaded)=="table" then presets = loaded end
  end
end

local function buildSourceParamMap()
  local map = {}
  local firstSourceIndex = 10
  local blockSize = 5
  for p = 1, 64 do
    local base = firstSourceIndex + (p-1)*blockSize
    map[p] = {x = base, y = base+1, z = base+2}
  end
  return map
end
local sourceParamMap = buildSourceParamMap()

local function safeGetParamNormalized(track, fxIdx, paramIdx)
  local v = reaper.TrackFX_GetParamNormalized(track, fxIdx, paramIdx)
  return v or 0.0
end

local function generateSpiralWalk(startX, startY, steps, outward, spread, accel)
  local xVals, yVals = {}, {}
  local angle = math.random() * math.pi * 2
  local baseRadius = math.sqrt(startX * startX + startY * startY)
  local angleStepBase = (math.pi * 2 / steps)
  for i = 1, steps do
    local prog = i / steps
    if palindrome then prog = 1 - math.abs(1 - 2 * prog) end  -- 0 -> 1 -> 0
    local rRaw
    if radiusMode == 1 then
      rRaw = radiusStart + prog * (radiusEnd - radiusStart)
    else
      local t = prog * spread
      rRaw = outward and (baseRadius + t) or (baseRadius - t)
    end
    if rRaw < minRadius then rRaw = minRadius end
    local r = math.max(-maxRadius, math.min(maxRadius, rRaw))
    if r < minRadius then r = minRadius end
    local accelFactor = accel
    if reverseAccel then accelFactor = -accel end
    -- normiert, damit "Umdrehungen" unabhaengig vom Accelerando exakt stimmt
    local norm = 1 + accelFactor / 2
    if math.abs(norm) < 0.1 then norm = 1 end
    local dynamicAngleStep = angleStepBase * speed * (1 + accelFactor * (i / steps)) / norm
    if palindrome and rotPalindrome and (i / steps) > 0.5 then
      angle = angle - dynamicAngleStep
    else
      angle = angle + dynamicAngleStep
    end
    xVals[i] = math.max(-1, math.min(1, r * math.cos(angle)))
    yVals[i] = math.max(-1, math.min(1, r * math.sin(angle)))
  end
  return xVals, yVals
end

-- Schreibt die Werte in [t0, t0+len]; loescht den Bereich [selStart, selEnd].
-- Startet der Punkt verzoegert (t0 > selStart), haelt ein Anker-Keyframe die
-- Startposition bis zum Delay-Ende. Kein Punkt hinter dem Selection-Ende.
local function createEnvelopeAndItem(track, fxIdx, paramIdx, values, selStart, selEnd, t0, len)
  local env = reaper.GetFXEnvelope(track, fxIdx, paramIdx, true)
  if not env then return end
  reaper.DeleteEnvelopePointRange(env, selStart, selEnd)
  t0 = t0 or selStart
  len = len or (selEnd - selStart)
  if t0 > selStart + 0.0005 then
    reaper.InsertEnvelopePoint(env, selStart, (values[1] + 1) / 2, 0, 0, false, true)
  end
  for i, val in ipairs(values) do
    local t = t0 + ((i - 1) / (#values - 1)) * len
    reaper.InsertEnvelopePoint(env, t, (val + 1) / 2, 0, 0, false, true)
  end
  reaper.Envelope_SortPoints(env)
end

function applySpiralWalk()
  local ts, te = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if te <= ts then reaper.ShowMessageBox('Bitte Zeitbereich wählen', 'Fehler', 0) return end
  local trackCount = reaper.CountSelectedTracks(0)
  if trackCount == 0 then reaper.ShowMessageBox('Bitte Track auswählen', 'Fehler', 0) return end
  reaper.Undo_BeginBlock()
  for t = 0, trackCount-1 do
    local track = reaper.GetSelectedTrack(0, t)
    for fx = 0, reaper.TrackFX_GetCount(track)-1 do
      local _, name = reaper.TrackFX_GetFXName(track, fx, '')
      if name:match('AmbiEncoder_64') then
        if pearlMode then
          -- PERLENKETTE: eine Leitspirale (von Punkt 1 aus), alle Punkte
          -- laufen dieselbe Bahn, jeder um pearlDelay spaeter. Alle enden
          -- innerhalb der Selection.
          local totalDelay = (numPointsToProcess - 1) * pearlDelay
          local motionLen = (te - ts) - totalDelay
          if motionLen <= 0.05 then
            reaper.ShowMessageBox(
              ('Delay zu gross fuer die Time-Selection:\n%d Punkte x %.2f s = %.2f s,\nSelection ist aber nur %.2f s lang.')
                :format(numPointsToProcess, pearlDelay, totalDelay, te - ts),
              'Spiral Walk', 0)
            return
          end
          local m1 = sourceParamMap[1]
          local startX = (safeGetParamNormalized(track, fx, m1.x) * 2) - 1
          local startY = (safeGetParamNormalized(track, fx, m1.y) * 2) - 1
          local startZ = (safeGetParamNormalized(track, fx, m1.z) * 2) - 1
          local xs, ys = generateSpiralWalk(startX, startY, steps, spiralOutward, spiralSpread, accelerando)
          local zVals = nil
          if includeZ then
            zVals = {}
            for i = 1, steps do zVals[i] = math.max(-1, math.min(1, startZ * zScale)) end
          end
          for p = 1, numPointsToProcess do
            local m = sourceParamMap[p]
            local t0 = ts + (p - 1) * pearlDelay
            createEnvelopeAndItem(track, fx, m.x, xs, ts, te, t0, motionLen)
            createEnvelopeAndItem(track, fx, m.y, ys, ts, te, t0, motionLen)
            if zVals then createEnvelopeAndItem(track, fx, m.z, zVals, ts, te, t0, motionLen) end
          end
        else
        for p = 1, numPointsToProcess do
          local m = sourceParamMap[p]
          -- Startposition wird zum Startzeitpunkt ts übernommen
          local startX = (safeGetParamNormalized(track, fx, m.x) * 2) - 1
          local startY = (safeGetParamNormalized(track, fx, m.y) * 2) - 1
          local startZ = (safeGetParamNormalized(track, fx, m.z) * 2) - 1
          local xs, ys = generateSpiralWalk(startX, startY, steps, spiralOutward, spiralSpread, accelerando)
          createEnvelopeAndItem(track, fx, m.x, xs, ts, te)
          createEnvelopeAndItem(track, fx, m.y, ys, ts, te)
          if includeZ then
            local zVals = {}
            for i = 1, steps do
              zVals[i] = math.max(-1, math.min(1, startZ * zScale))
            end
            createEnvelopeAndItem(track, fx, m.z, zVals, ts, te)
          end
        end
        end
      end
    end
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock('Spiral Walk', -1)
end


-- === V4.2: Live-Modus - endlose Spirale ohne Time-Selection und ohne Envelopes ===
local liveRunning = false
local livePassDur = 8.0
local liveTrack, liveFx = nil, -1
local liveStartTime = 0
local livePoints = {}

local function liveResolveTrack()
  local sel = reaper.GetSelectedTrack(0,0)
  if not sel then
    reaper.ShowMessageBox('Bitte den ICST AmbiEncoder-Track selektieren!','Spiral Walk',0)
    return false
  end
  for fx = 0, reaper.TrackFX_GetCount(sel)-1 do
    local _, name = reaper.TrackFX_GetFXName(sel, fx, '')
    if name:match('AmbiEncoder_64') then liveTrack, liveFx = sel, fx return true end
  end
  reaper.ShowMessageBox('Kein AmbiEncoder_64 auf dem selektierten Track!','Spiral Walk',0)
  return false
end

local function liveStart()
  if not liveResolveTrack() then return end
  livePoints = {}
  for p = 1, numPointsToProcess do
    local m = sourceParamMap[p]
    local x = (safeGetParamNormalized(liveTrack, liveFx, m.x)*2)-1
    local y = (safeGetParamNormalized(liveTrack, liveFx, m.y)*2)-1
    livePoints[p] = { radius = math.sqrt(x*x+y*y), angle0 = math.atan(y,x) }
  end
  if pearlMode then
    for p = 2, numPointsToProcess do
      livePoints[p].radius = livePoints[1].radius
      livePoints[p].angle0 = livePoints[1].angle0
    end
  end
  liveStartTime = reaper.time_precise()
  liveRunning = true
end

local function liveUpdate()
  if liveTrack and not reaper.ValidatePtr2(0, liveTrack, 'MediaTrack*') then
    liveRunning = false; liveTrack = nil; return
  end
  local now = reaper.time_precise() - liveStartTime
  local af = reverseAccel and -accelerando or accelerando
  for p = 1, numPointsToProcess do
    local pt = livePoints[p]
    if not pt then break end
    local tau = now - (pearlMode and (p-1)*pearlDelay or 0)
    if tau < 0 then tau = 0 end
    local n = math.floor(tau / livePassDur)
    local u = (tau / livePassDur) - n
    -- Winkel: normal laeuft er endlos weiter (Accelerando pro Durchlauf);
    -- im Rotations-Palindrom dreht er vor und wieder zurueck (jeder Durchlauf
    -- endet am Startwinkel - nahtlose Endlosschleife)
    local angle
    local fwd1 = 1 + af/2
    if math.abs(fwd1) < 0.1 then fwd1 = 1 end
    local function fwd(x) return (x + af*x*x/2) / fwd1 end
    if palindrome and rotPalindrome then
      local a = (u <= 0.5) and fwd(u) or fwd(1 - u)
      angle = pt.angle0 + 2*math.pi*speed*a
    else
      angle = pt.angle0 + 2*math.pi*speed*(n + fwd(u))
    end
    local prog
    if palindrome then
      prog = 1 - math.abs(1 - 2*u)       -- endlos rein und raus
    else
      prog = (n > 0) and 1 or u          -- nach einem Durchlauf Zielweite halten
    end
    local rRaw
    if radiusMode == 1 then
      rRaw = radiusStart + prog * (radiusEnd - radiusStart)
    else
      rRaw = spiralOutward and (pt.radius + prog*spiralSpread) or (pt.radius - prog*spiralSpread)
    end
    if rRaw < minRadius then rRaw = minRadius end
    local r = math.max(-maxRadius, math.min(maxRadius, rRaw))
    if r < minRadius then r = minRadius end
    local m = sourceParamMap[p]
    reaper.TrackFX_SetParamNormalized(liveTrack, liveFx, m.x, math.max(0, math.min(1, (r*math.cos(angle)+1)/2)))
    reaper.TrackFX_SetParamNormalized(liveTrack, liveFx, m.y, math.max(0, math.min(1, (r*math.sin(angle)+1)/2)))
  end
end

function loop()
  if not visible then return end
  reaper.ImGui_SetNextWindowSize(ctx, 500, 780, reaper.ImGui_Cond_FirstUseEver())
  local draw, open = reaper.ImGui_Begin(ctx, 'ICST AmbiEncoder_64 Spiral Walk', true)
  if draw then
    _, steps = reaper.ImGui_InputInt(ctx, 'Schritte', steps)
    _, spiralSpread = reaper.ImGui_InputDouble(ctx, 'Spiral Spread', spiralSpread)
    _, maxRadius = reaper.ImGui_InputDouble(ctx, 'Max Radius', maxRadius)
    _, minRadius = reaper.ImGui_InputDouble(ctx, 'Min Radius', minRadius)
    if minRadius < 0.1 then minRadius = 0.1 end
    _, radiusMode = reaper.ImGui_Combo(ctx, 'Radius-Verlauf', radiusMode, 'Relativ (ab aktueller Position)\0Absolut: Start -> Ziel\0')
    if radiusMode == 1 then
      local chr, nr = reaper.ImGui_InputDouble(ctx, 'Radius Start (0-1)', radiusStart)
      if chr and nr then radiusStart = math.max(0.0, math.min(1.0, nr)) end
      chr, nr = reaper.ImGui_InputDouble(ctx, 'Radius Ziel (0-1)', radiusEnd)
      if chr and nr then radiusEnd = math.max(0.0, math.min(1.0, nr)) end
    end
    _, accelerando = reaper.ImGui_InputDouble(ctx, 'Accelerando (Drehgeschw.)', accelerando)
    _, reverseAccel = reaper.ImGui_Checkbox(ctx, 'Accelerando umkehren', reverseAccel)
    _, spiralOutward = reaper.ImGui_Checkbox(ctx, 'Spiral nach außen bewegen', spiralOutward)
    _, palindrome = reaper.ImGui_Checkbox(ctx, 'Palindrom (hin und wieder zurück)', palindrome)
    if palindrome then
      _, rotPalindrome = reaper.ImGui_Checkbox(ctx, 'Palindrom: Drehrichtung auf dem Rückweg umkehren', rotPalindrome)
    end
    _, includeZ = reaper.ImGui_Checkbox(ctx, 'Z-Achse aktivieren', includeZ)
    _, zScale = reaper.ImGui_InputDouble(ctx, 'Z-Achse Skalierung (-1 bis 1)', zScale)
    if zScale > 1.0 then zScale = 1.0 end
    if zScale < -1.0 then zScale = -1.0 end
    _, speed = reaper.ImGui_InputDouble(ctx, 'Umdrehungen (Schnecken)', speed)
    _, numPointsToProcess = reaper.ImGui_InputInt(ctx, 'Anzahl Punkte', numPointsToProcess)
    _, pearlMode = reaper.ImGui_Checkbox(ctx, 'Perlenkette (Punkte folgen mit Delay)', pearlMode)
    if pearlMode then
      local chd, nd = reaper.ImGui_InputDouble(ctx, 'Delay pro Punkt (s)', pearlDelay)
      if chd and nd then pearlDelay = math.max(0.0, nd) end
      reaper.ImGui_TextWrapped(ctx, ('Alle Punkte laufen dieselbe Spirale (ab Punkt 1). Punkt %d startet %.2f s nach Punkt 1.')
        :format(numPointsToProcess, (numPointsToProcess - 1) * pearlDelay))
    end

    if reaper.ImGui_Button(ctx, 'Spiral Walk ausführen') then
      applySpiralWalk()
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Live-Modus (endlos, ohne Envelopes):')
    local chl, nl = reaper.ImGui_InputDouble(ctx, 'Dauer pro Durchlauf (s)', livePassDur)
    if chl and nl and nl > 0.1 then livePassDur = nl end
    if reaper.ImGui_Button(ctx, liveRunning and 'Live Stop' or 'Live Start') then
      if liveRunning then liveRunning = false else liveStart() end
    end
    if liveRunning then
      reaper.ImGui_SameLine(ctx)
      reaper.ImGui_Text(ctx, '● läuft')
    end
    reaper.ImGui_TextWrapped(ctx, 'Schreibt die Positionen direkt in den Encoder - keine Time-Selection, keine Envelopes. Mit Palindrom pendelt der Radius endlos rein und raus; ohne hält er nach einem Durchlauf die Zielweite und rotiert weiter. Perlenkette und Delay wirken auch hier. Tipp: Track auf Latch = die Live-Fahrt wird als Automation aufgezeichnet.')

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Preset Verwaltung:')
    _, presetInput = reaper.ImGui_InputText(ctx, 'Preset-Name', presetInput)
    if reaper.ImGui_Button(ctx, 'Preset speichern') then
      presets[presetInput] = {
        steps=steps, spiralSpread=spiralSpread, maxRadius=maxRadius, accelerando=accelerando,
        reverseAccel=reverseAccel, spiralOutward=spiralOutward, includeZ=includeZ, speed=speed,
        numPointsToProcess=numPointsToProcess, minRadius=minRadius, zScale=zScale,
        pearlMode=pearlMode, pearlDelay=pearlDelay, palindrome=palindrome, rotPalindrome=rotPalindrome,
        radiusMode=radiusMode, radiusStart=radiusStart, radiusEnd=radiusEnd
      }
      savePresetsToDisk()
    end

    for name, data in pairs(presets) do
      if reaper.ImGui_Button(ctx, 'Laden: '..name) then
        steps = data.steps
        spiralSpread = data.spiralSpread
        maxRadius = data.maxRadius
        accelerando = data.accelerando
        reverseAccel = data.reverseAccel
        spiralOutward = data.spiralOutward
        includeZ = data.includeZ
        speed = data.speed
        numPointsToProcess = data.numPointsToProcess
        minRadius = data.minRadius or 0.1
        zScale = data.zScale or 1.0
        pearlMode = data.pearlMode or false
        pearlDelay = data.pearlDelay or 0.25
        palindrome = data.palindrome or false
        rotPalindrome = data.rotPalindrome or false
        radiusMode = data.radiusMode or 0
        radiusStart = data.radiusStart or 0.9
        radiusEnd = data.radiusEnd or 0.15
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Löschen##'..name) then
        presets[name] = nil
        savePresetsToDisk()
      end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Speicherort für Presets:')
    _, presetDirInput = reaper.ImGui_InputText(ctx, 'Ordnerpfad', presetDirInput)
    if reaper.ImGui_Button(ctx, 'Speicherort übernehmen') then
      if not presetDirInput:match("[/\\]$") then
        presetDirInput = presetDirInput .. "/"
      end
      presetDir = presetDirInput
      presetFilePath = presetDir .. presetFileName
      savePresetsToDisk()
    end

    reaper.ImGui_End(ctx)
  end
  if liveRunning then liveUpdate() end
  if open then reaper.defer(loop) else visible = false end
end

loadPresetsFromDisk()
reaper.defer(loop)


