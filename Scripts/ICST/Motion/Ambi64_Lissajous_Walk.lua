--[[
  ICST AmbiEncoder_64 Lissajous Walk
  ----------------------------------
  Generates 2D or 3D Lissajous trajectories for the X/Y/Z parameters
  of the VST3 "ICST AmbiEncoder_64" in REAPER.

  Analogous in structure to the ICST Spiral Walk script:
  - ReaImGui GUI
  - Preset save/load/delete (JSON)
  - Writes point envelopes across the current time selection
  - Uses each point's start position as the Lissajous centre
  - Per-source phase offset for shifted/interleaved figures

  Formula per point i, normalized time t in [0,1]:
    x(t) = x0 + Sx * sin(2*pi * a * t + phi_x + i * dPhi_x)
    y(t) = y0 + Sy * sin(2*pi * b * t + phi_y + i * dPhi_y)
    z(t) = z0 + Sz * sin(2*pi * c * t + phi_z + i * dPhi_z)   (optional)

  Requirements:
    - REAPER
    - VST3 "ICST AmbiEncoder_64" on the selected track
    - ReaImGui extension (https://github.com/cfillion/reaimgui)

  Author: generated for Johannes Schuett
--]]

------------------------------------------------------------
-- Dependencies
------------------------------------------------------------
if not reaper.ImGui_CreateContext then
  reaper.ShowMessageBox(
    "ReaImGui extension not found.\nInstall it via ReaPack: cfillion/reaimgui.",
    "ICST Lissajous Walk", 0)
  return
end

local ctx = reaper.ImGui_CreateContext('ICST Lissajous Walk')
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()

------------------------------------------------------------
-- Helpers: JSON (minimal, safe for our flat preset schema)
------------------------------------------------------------
local json = {}
function json.encode(v)
  local t = type(v)
  if t == 'nil'     then return 'null' end
  if t == 'boolean' then return tostring(v) end
  if t == 'number'  then return tostring(v) end
  if t == 'string'  then
    return '"' .. v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n') .. '"'
  end
  if t == 'table' then
    -- object only (our schema is flat maps)
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts+1] = '"' .. tostring(k) .. '":' .. json.encode(val)
    end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  return 'null'
end

function json.decode(s)
  -- Very small JSON parser — sufficient for our own preset format.
  local i = 1
  local function skip_ws() while i <= #s and s:sub(i,i):match('%s') do i = i + 1 end end
  local parse_value
  local function parse_string()
    assert(s:sub(i,i) == '"'); i = i + 1
    local out = {}
    while i <= #s do
      local c = s:sub(i,i)
      if c == '"' then i = i + 1; return table.concat(out) end
      if c == '\\' then
        local n = s:sub(i+1,i+1)
        if n == 'n' then out[#out+1] = '\n'
        elseif n == 't' then out[#out+1] = '\t'
        else out[#out+1] = n end
        i = i + 2
      else
        out[#out+1] = c; i = i + 1
      end
    end
    error('unterminated string')
  end
  local function parse_number()
    local j = i
    while j <= #s and s:sub(j,j):match('[%-%+%d%.eE]') do j = j + 1 end
    local n = tonumber(s:sub(i, j-1)); i = j; return n
  end
  local function parse_object()
    assert(s:sub(i,i) == '{'); i = i + 1
    local o = {}
    skip_ws()
    if s:sub(i,i) == '}' then i = i + 1; return o end
    while true do
      skip_ws()
      local k = parse_string()
      skip_ws(); assert(s:sub(i,i) == ':'); i = i + 1
      skip_ws()
      o[k] = parse_value()
      skip_ws()
      local c = s:sub(i,i)
      if c == ',' then i = i + 1
      elseif c == '}' then i = i + 1; return o
      else error('expected , or }') end
    end
  end
  parse_value = function()
    skip_ws()
    local c = s:sub(i,i)
    if c == '{' then return parse_object() end
    if c == '"' then return parse_string() end
    if c == 't' then i = i + 4; return true end
    if c == 'f' then i = i + 5; return false end
    if c == 'n' then i = i + 4; return nil end
    return parse_number()
  end
  local ok, res = pcall(parse_value)
  if ok then return res end
  return nil
end

------------------------------------------------------------
-- Preset store (JSON on disk, keyed by preset name)
------------------------------------------------------------
local resource_path = reaper.GetResourcePath()
-- Audit 2026-11-11: Presets neben dem Script statt fest in Scripts/ICST_AMBI
local preset_dir   = (({reaper.get_action_context()})[2]:match('^(.*)[/\\][^/\\]+$')) or (resource_path .. '/Scripts/ICST/Motion')
local preset_path  = preset_dir .. '/lissajous_walk_presets.json'
reaper.RecursiveCreateDirectory(preset_dir, 0)

local function load_all_presets()
  local f = io.open(preset_path, 'r')
  if not f then return {} end
  local txt = f:read('*a'); f:close()
  local t = json.decode(txt or '') or {}
  return t
end

local function save_all_presets(t)
  local f = io.open(preset_path, 'w')
  if not f then return false end
  f:write(json.encode(t)); f:close(); return true
end

------------------------------------------------------------
-- State (defaults)
------------------------------------------------------------
local S = {
  -- Which sources to process
  src_start   = 1,    -- 1..64
  src_count   = 8,    -- how many sources to move
  -- Envelope resolution across the time selection
  steps       = 400,  -- number of envelope points
  -- Lissajous parameters
  ratio_a     = 3,    -- x frequency multiplier
  ratio_b     = 2,    -- y frequency multiplier
  ratio_c     = 1,    -- z frequency multiplier
  cycles      = 1.0,  -- number of full "base" cycles across selection
  phi_x       = 0.0,  -- radians
  phi_y       = math.pi/2, -- radians (pi/2 gives circles for a=b)
  phi_z       = 0.0,  -- radians
  -- Per-source phase drift so sources trace shifted figures
  dphi_x_deg  = 0.0,
  dphi_y_deg  = 0.0,
  dphi_z_deg  = 0.0,
  -- Amplitudes in METERS (final radius per axis).
  -- Mapped to encoder XYZ [-1..+1] via encoder_ref_m.
  amp_x_m     = 5.0,
  amp_y_m     = 5.0,
  amp_z_m     = 3.0,
  -- Distance scaler (meters) — must match the AmbiEncoder's
  -- distance-scaler / reference radius so 1.0 in XYZ == this many meters.
  encoder_ref_m = 5.0,
  -- Global multiplier on amplitudes (1.0 = as configured above)
  dist_scale  = 1.0,
  -- 3D / palindrome / time curve
  enable_z    = false,
  palindrome  = false,  -- play forward then backward within selection
  time_curve  = 1.0,    -- exponent >1 = ease-in, <1 = ease-out, 1 = linear
  -- Use current point positions as centres, or a user-defined centre
  use_start_pos = true,
  centre_x    = 0.0,
  centre_y    = 0.0,
  centre_z    = 0.0,
  -- Clamp final XYZ to [-1, 1] (encoder domain)
  clamp_unit  = true,
  -- Preset
  preset_name = 'default',
  presets     = load_all_presets(),
  status      = '',
}

------------------------------------------------------------
-- Parameter mapping (name-based, robust across plugin builds)
--
-- The AmbiEncoder_64 exposes its per-source parameters as VST params
-- named "X 1", "Y 1", "Z 1", "Gain1", "Mute1", "X 2", ... — preceded
-- by a header block (MasterGain, Encoding Mode, dB Unit, Distance
-- Attenuation, Advanced Factor, Advanced Exponent, Air Absorbtion,
-- ...). Instead of assuming fixed offsets we scan the parameter list
-- and match names.
--
-- Fallback constants (used only when name matching fails). These
-- mirror the Motion Map Writer defaults: X1 is API param 10 (== UI
-- param 11), stride 5.
------------------------------------------------------------
local FALLBACK_FIRST_X_API = 10  -- 0-based API index of the first source's X
local FALLBACK_STRIDE      = 5   -- X,Y,Z,Gain,Mute per source

local function _norm_name(name)
  return (name or ''):lower():gsub('%s+', '')
end

-- Returns two tables keyed by source index (1..64):
--   idx_x[i], idx_y[i], idx_z[i]  -> API param indices for that source
-- Falls back to arithmetic mapping if names cannot be matched.
local function build_param_map(track, fx)
  local idx_x, idx_y, idx_z = {}, {}, {}
  local count = reaper.TrackFX_GetNumParams(track, fx)
  for p = 0, count - 1 do
    local _, raw = reaper.TrackFX_GetParamName(track, fx, p, '')
    local n = _norm_name(raw)
    -- Match patterns like "x1", "x12", "x 1" (whitespace already stripped)
    local axis, num = n:match('^([xyz])(%d+)$')
    if axis and num then
      local i = tonumber(num)
      if i and i >= 1 and i <= 64 then
        if     axis == 'x' then idx_x[i] = p
        elseif axis == 'y' then idx_y[i] = p
        else                    idx_z[i] = p end
      end
    end
  end
  -- Fallback fill for any source that didn't get all three axes matched
  for i = 1, 64 do
    if not (idx_x[i] and idx_y[i] and idx_z[i]) then
      local base = FALLBACK_FIRST_X_API + (i - 1) * FALLBACK_STRIDE
      if base + 2 < count then
        idx_x[i] = idx_x[i] or base
        idx_y[i] = idx_y[i] or (base + 1)
        idx_z[i] = idx_z[i] or (base + 2)
      end
    end
  end
  -- V4.1: kein Konventions-Tausch mehr. ICST-Konvention wie im ganzen Workshop:
  -- X = links/rechts, Y = vorne/hinten, Z = oben/unten. Eine X/Y-Lissajous
  -- liegt damit in der horizontalen Ebene; "Use Z motion" bewegt die Hoehe.
  return idx_x, idx_y, idx_z
end

------------------------------------------------------------
-- Track / FX discovery
------------------------------------------------------------
local function find_encoder_fx(track)
  if not track then return -1 end
  local fx_count = reaper.TrackFX_GetCount(track)
  for fx = 0, fx_count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, fx, '')
    if name:lower():find('ambiencoder') and name:find('64') then
      return fx
    end
  end
  -- fallback: any ICST AmbiEncoder
  for fx = 0, fx_count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, fx, '')
    if name:lower():find('ambiencoder') then return fx end
  end
  return -1
end

------------------------------------------------------------
-- Envelope writer
------------------------------------------------------------
local function get_or_create_param_envelope(track, fx, param)
  -- Just create it if missing. Setting VIS/ARM via SetEnvelopeStateChunk
  -- turned out to clobber the points block on some builds, so we do NOT
  -- rewrite the chunk here. Users can arm/show lanes via Envelope Manager.
  return reaper.GetFXEnvelope(track, fx, param, true)
end

------------------------------------------------------------
-- Housekeeping: delete envelopes on header params (0..9) or on any
-- non X/Y/Z parameter of the AmbiEncoder. Fixes tracks polluted by an
-- older, wrongly-mapped version of this script.
------------------------------------------------------------
-- V4.1: SetEnvelopeInfo_Value existiert in dieser REAPER-Version nicht -
-- sicher aufrufen; Sichtbarkeit/Arm werden zusaetzlich ueber den State-Chunk gesetzt.
local function set_env_info(env, parm, val)
  if reaper.SetEnvelopeInfo_Value then
    set_env_info(env, parm, val)
  end
end

local function cleanup_wrong_envelopes(track, fx)
  -- Build set of API param indices that ARE our x/y/z targets, so we spare them.
  local keep = {}
  local n = reaper.TrackFX_GetNumParams(track, fx)
  for p = 0, n - 1 do
    local _, name = reaper.TrackFX_GetParamName(track, fx, p, '')
    if _norm_name(name):match('^[xyz]%d+$') then keep[p] = true end
  end
  -- Iterate all envelopes actually present on the track (like the user's snippet).
  local removed = 0
  local env_count = reaper.CountTrackEnvelopes(track)
  for e = env_count - 1, 0, -1 do
    local env = reaper.GetTrackEnvelope(track, e)
    -- Envelope_GetParentTrack returns (MediaTrack, fxidx, parmidx). fxidx is
    -- -1 for track envelopes that are not FX param envelopes.
    local _, target_fx, target_param = reaper.Envelope_GetParentTrack(env)
    if target_fx == fx and target_param and target_param >= 0
       and not keep[target_param] then
      -- Delete all points, then hide + disarm via API (not chunk).
      local cnt = reaper.CountEnvelopePoints(env)
      for idx = cnt - 1, 0, -1 do
        reaper.DeleteEnvelopePointEx(env, -1, idx)
      end
      set_env_info(env, 'B_VISIBLE', 0)
      set_env_info(env, 'I_TCPY',    0) -- collapse lane
      set_env_info(env, 'I_TCPH',    0)
      -- Also strip the ARM/VIS flags in the chunk so REAPER accepts the changes.
      local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
      if ok and chunk then
        chunk = chunk:gsub('\nVIS %d+ %d+ %d+', '\nVIS 0 0 0', 1)
        chunk = chunk:gsub('\nARM %d+',         '\nARM 0',     1)
        reaper.SetEnvelopeStateChunk(env, chunk, false)
      end
      removed = removed + 1
    end
  end
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(false)
  return removed
end

local function clear_env_range(env, t0, t1)
  -- Delete all existing points inside [t0, t1]
  local cnt = reaper.CountEnvelopePoints(env)
  for idx = cnt - 1, 0, -1 do
    local ok, time = reaper.GetEnvelopePoint(env, idx)
    if ok and time >= t0 and time <= t1 then
      reaper.DeleteEnvelopePointEx(env, -1, idx)
    end
  end
end

local function write_env_points(env, t0, t1, values_at_step, steps)
  -- values_at_step[k] is the value at normalized time (k-1)/(steps-1)
  local dur = t1 - t0
  reaper.PreventUIRefresh(1)
  local batch = 0
  for k = 1, steps do
    local u = (k - 1) / math.max(1, steps - 1)
    local t = t0 + u * dur
    local v = values_at_step[k]
    if v < 0 then v = 0 elseif v > 1 then v = 1 end -- envelopes normalized 0..1
    reaper.InsertEnvelopePoint(env, t, v, 0, 0, false, true) -- shape=linear, noSort
    batch = batch + 1
    if batch >= 200 then
      reaper.Envelope_SortPoints(env)
      batch = 0
    end
  end
  reaper.Envelope_SortPoints(env)
  reaper.PreventUIRefresh(-1)
end

-- Show the envelope lane in the TCP and arm it via the API (does NOT touch
-- the points section).
local function show_and_arm_env(env)
  if not env then return end
  set_env_info(env, 'B_VISIBLE', 1)
  set_env_info(env, 'B_ARM',     1)
  -- Fallback ueber den State-Chunk (noetig, wenn die API-Funktion fehlt)
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
  if ok and chunk then
    chunk = chunk:gsub('\nVIS %d+', '\nVIS 1', 1)
    chunk = chunk:gsub('\nARM %d+', '\nARM 1', 1)
    chunk = chunk:gsub('\nACT %d+', '\nACT 1', 1)
    reaper.SetEnvelopeStateChunk(env, chunk, false)
  end
end

------------------------------------------------------------
-- Core: generate Lissajous
------------------------------------------------------------
local function generate()
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then
    S.status = 'ERROR: no track selected.'
    return
  end
  local fx = find_encoder_fx(track)
  if fx < 0 then
    S.status = 'ERROR: ICST AmbiEncoder_64 not found on selected track.'
    return
  end

  local t0, t1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if t1 <= t0 then
    S.status = 'ERROR: set a time selection first.'
    return
  end

  local steps       = math.max(4, math.floor(S.steps))
  local ratio_a     = S.ratio_a
  local ratio_b     = S.ratio_b
  local ratio_c     = S.ratio_c
  local cycles      = math.max(0.01, S.cycles)
  local phi_x       = S.phi_x
  local phi_y       = S.phi_y
  local phi_z       = S.phi_z
  local dphi_x      = math.rad(S.dphi_x_deg)
  local dphi_y      = math.rad(S.dphi_y_deg)
  local dphi_z      = math.rad(S.dphi_z_deg)
  -- Convert meter amplitudes to normalized encoder units and apply the scaler
  local ref = math.max(0.001, S.encoder_ref_m)
  local k   = S.dist_scale
  local Ax  = (S.amp_x_m * k) / ref
  local Ay  = (S.amp_y_m * k) / ref
  local Az  = (S.amp_z_m * k) / ref
  local enable_z    = S.enable_z
  local palindrome  = S.palindrome
  local tc          = math.max(0.01, S.time_curve)
  local clamp_unit  = S.clamp_unit

  -- Map AmbiEncoder normalized XYZ [-1..1] to REAPER envelope [0..1]
  local function enc_to_env(v)
    if clamp_unit then
      if v < -1 then v = -1 elseif v > 1 then v = 1 end
    end
    return (v + 1) * 0.5
  end

  reaper.Undo_BeginBlock()

  local src_start = math.max(1, math.min(64, math.floor(S.src_start)))
  local src_end   = math.min(64, src_start + math.max(1, math.floor(S.src_count)) - 1)

  local idx_x, idx_y, idx_z = build_param_map(track, fx)

  for i = src_start, src_end do
    local pX, pY, pZ = idx_x[i], idx_y[i], idx_z[i]
    if not (pX and pY and (pZ or not enable_z)) then
      S.status = string.format('ERROR: could not locate X/Y/Z params for source %d.', i)
      reaper.Undo_EndBlock('ICST Lissajous Walk (aborted)', -1)
      return
    end
    local envX = get_or_create_param_envelope(track, fx, pX)
    local envY = get_or_create_param_envelope(track, fx, pY)
    local envZ = enable_z and get_or_create_param_envelope(track, fx, pZ) or nil

    -- centre for this source
    local x0, y0, z0
    if S.use_start_pos then
      local vx = reaper.TrackFX_GetParamNormalized(track, fx, pX)
      local vy = reaper.TrackFX_GetParamNormalized(track, fx, pY)
      local vz = reaper.TrackFX_GetParamNormalized(track, fx, pZ)
      x0 = vx * 2 - 1
      y0 = vy * 2 - 1
      z0 = vz * 2 - 1
    else
      x0, y0, z0 = S.centre_x, S.centre_y, S.centre_z
    end

    local vals_x, vals_y, vals_z = {}, {}, {}
    for k = 1, steps do
      local u = (k - 1) / math.max(1, steps - 1)   -- 0..1
      -- palindrome remaps u so it goes 0 -> 1 -> 0
      local u2 = palindrome and (1 - math.abs(2*u - 1)) or u
      -- time curve
      local ut = u2 ^ tc
      local theta = 2 * math.pi * cycles * ut
      local px = x0 + Ax * math.sin(ratio_a * theta + phi_x + (i - src_start) * dphi_x)
      local py = y0 + Ay * math.sin(ratio_b * theta + phi_y + (i - src_start) * dphi_y)
      local pz = z0
      if enable_z then
        pz = z0 + Az * math.sin(ratio_c * theta + phi_z + (i - src_start) * dphi_z)
      end
      vals_x[k] = enc_to_env(px)
      vals_y[k] = enc_to_env(py)
      if enable_z then vals_z[k] = enc_to_env(pz) end
    end

    clear_env_range(envX, t0, t1); write_env_points(envX, t0, t1, vals_x, steps)
    clear_env_range(envY, t0, t1); write_env_points(envY, t0, t1, vals_y, steps)
    if enable_z then
      clear_env_range(envZ, t0, t1); write_env_points(envZ, t0, t1, vals_z, steps)
    end
    -- Make lanes visible + armed AFTER points are in (regex only touches header)
    show_and_arm_env(envX)
    show_and_arm_env(envY)
    if enable_z then show_and_arm_env(envZ) end
  end

  reaper.Undo_EndBlock('ICST Lissajous Walk', -1)
  reaper.UpdateArrange()
  S.status = string.format(
    'OK: wrote %d source(s), %d steps, ratio %g:%g%s over %.2fs.',
    (src_end - src_start + 1), steps, ratio_a, ratio_b,
    enable_z and (':' .. tostring(ratio_c)) or '',
    (t1 - t0))
end

------------------------------------------------------------
-- Preset ops
------------------------------------------------------------
local PRESET_KEYS = {
  'src_start','src_count','steps',
  'ratio_a','ratio_b','ratio_c','cycles',
  'phi_x','phi_y','phi_z',
  'dphi_x_deg','dphi_y_deg','dphi_z_deg',
  'amp_x_m','amp_y_m','amp_z_m',
  'encoder_ref_m','dist_scale',
  'enable_z','palindrome','time_curve',
  'use_start_pos','centre_x','centre_y','centre_z',
  'clamp_unit',
}

local function snapshot_state()
  local out = {}
  for _, k in ipairs(PRESET_KEYS) do out[k] = S[k] end
  return out
end

local function apply_state(t)
  if type(t) ~= 'table' then return end
  for _, k in ipairs(PRESET_KEYS) do
    if t[k] ~= nil then S[k] = t[k] end
  end
end

local function preset_save()
  local name = (S.preset_name or ''):gsub('^%s+',''):gsub('%s+$','')
  if name == '' then S.status = 'ERROR: preset name empty.'; return end
  S.presets[name] = snapshot_state()
  if save_all_presets(S.presets) then
    S.status = 'Saved preset "' .. name .. '".'
  else
    S.status = 'ERROR: could not write presets file.'
  end
end

local function preset_load()
  local name = S.preset_name or ''
  if not S.presets[name] then S.status = 'Preset not found: ' .. name; return end
  apply_state(S.presets[name])
  S.status = 'Loaded preset "' .. name .. '".'
end

local function preset_delete()
  local name = S.preset_name or ''
  if not S.presets[name] then S.status = 'Preset not found: ' .. name; return end
  S.presets[name] = nil
  save_all_presets(S.presets)
  S.status = 'Deleted preset "' .. name .. '".'
end

------------------------------------------------------------
-- Simple UI helpers
------------------------------------------------------------
local function slider_int(label, key, mn, mx)
  local rv, v = reaper.ImGui_SliderInt(ctx, label, S[key], mn, mx)
  if rv then S[key] = v end
end
local function slider_num(label, key, mn, mx, fmt)
  local rv, v = reaper.ImGui_SliderDouble(ctx, label, S[key], mn, mx, fmt or '%.3f')
  if rv then S[key] = v end
end
local function checkbox(label, key)
  local rv, v = reaper.ImGui_Checkbox(ctx, label, S[key])
  if rv then S[key] = v end
end

------------------------------------------------------------
-- Main loop
------------------------------------------------------------
local function frame()
  reaper.ImGui_SetNextWindowSize(ctx, 520, 640, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'ICST AmbiEncoder_64 — Lissajous Walk', true)
  if visible then
    reaper.ImGui_TextWrapped(ctx,
      'Select a track with ICST AmbiEncoder_64 loaded and set a time selection. '
   .. 'Adjust parameters, then press "Generate Lissajous". Envelopes inside the '
   .. 'time selection will be overwritten.')

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Sources')
    slider_int('First source (1..64)', 'src_start', 1, 64)
    slider_int('Number of sources',    'src_count', 1, 64)

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Envelope resolution')
    slider_int('Steps', 'steps', 8, 4000)

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Lissajous ratio and phase')
    slider_num('Ratio a (X freq)', 'ratio_a', 1, 12, '%.0f')
    slider_num('Ratio b (Y freq)', 'ratio_b', 1, 12, '%.0f')
    checkbox('Enable Z (3D Lissajous)', 'enable_z')
    if S.enable_z then
      slider_num('Ratio c (Z freq)', 'ratio_c', 1, 12, '%.0f')
    end
    slider_num('Cycles across selection', 'cycles', 0.1, 20, '%.2f')
    slider_num('Phase X (rad)', 'phi_x', -math.pi, math.pi, '%.3f')
    slider_num('Phase Y (rad)', 'phi_y', -math.pi, math.pi, '%.3f')
    if S.enable_z then
      slider_num('Phase Z (rad)', 'phi_z', -math.pi, math.pi, '%.3f')
    end

    reaper.ImGui_Text(ctx, 'Per-source phase drift (degrees)')
    slider_num('dPhi X / source', 'dphi_x_deg', -180, 180, '%.1f')
    slider_num('dPhi Y / source', 'dphi_y_deg', -180, 180, '%.1f')
    if S.enable_z then
      slider_num('dPhi Z / source', 'dphi_z_deg', -180, 180, '%.1f')
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Amplitudes in meters (per axis)')
    slider_num('Amp X (m)', 'amp_x_m', 0.0, 30.0, '%.2f')
    slider_num('Amp Y (m)', 'amp_y_m', 0.0, 30.0, '%.2f')
    if S.enable_z then slider_num('Amp Z (m)', 'amp_z_m', 0.0, 30.0, '%.2f') end
    reaper.ImGui_Text(ctx, 'Distance scaler')
    slider_num('Encoder reference (m) = XYZ 1.0', 'encoder_ref_m', 1.0, 30.0, '%.2f')
    slider_num('Global scale', 'dist_scale', 0.0, 3.0, '%.2f')
    reaper.ImGui_TextWrapped(ctx,
      'Encoder reference must match the AmbiEncoder\'s distance scaler. '
   .. 'XYZ is normalized to [-1..+1] where 1.0 = reference radius (m). '
   .. 'To reach 30 m, set the encoder\'s distance scaler to 30 m and encoder reference here to 30.')

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Timing')
    checkbox('Palindrome (forward then backward)', 'palindrome')
    slider_num('Time curve (1 = linear)', 'time_curve', 0.1, 4.0, '%.2f')

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Centres')
    checkbox('Use each source\'s current position as centre', 'use_start_pos')
    if not S.use_start_pos then
      slider_num('Centre X', 'centre_x', -1, 1)
      slider_num('Centre Y', 'centre_y', -1, 1)
      if S.enable_z then slider_num('Centre Z', 'centre_z', -1, 1) end
    end
    checkbox('Clamp XYZ to unit cube', 'clamp_unit')

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, 'Presets')
    local rv, name = reaper.ImGui_InputText(ctx, 'Preset name', S.preset_name)
    if rv then S.preset_name = name end
    if reaper.ImGui_Button(ctx, 'Save') then preset_save() end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Load') then preset_load() end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Delete') then preset_delete() end

    -- list available presets
    if reaper.ImGui_BeginCombo(ctx, 'Available', S.preset_name) then
      for k in pairs(S.presets) do
        local sel = (k == S.preset_name)
        if reaper.ImGui_Selectable(ctx, k, sel) then S.preset_name = k end
      end
      reaper.ImGui_EndCombo(ctx)
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_Button(ctx, 'Generate Lissajous', 200, 32) then
      generate()
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Close', 100, 32) then open = false end

    if reaper.ImGui_Button(ctx, 'Cleanup wrong envelopes on this track', 320, 24) then
      local track = reaper.GetSelectedTrack(0, 0)
      if not track then
        S.status = 'ERROR: no track selected.'
      else
        local fx = find_encoder_fx(track)
        if fx < 0 then
          S.status = 'ERROR: ICST AmbiEncoder_64 not found on selected track.'
        else
          reaper.Undo_BeginBlock()
          local n = cleanup_wrong_envelopes(track, fx)
          reaper.Undo_EndBlock('ICST Lissajous — cleanup wrong envelopes', -1)
          reaper.UpdateArrange()
          S.status = string.format('Removed %d non-XYZ envelope(s).', n)
        end
      end
    end

    if S.status ~= '' then
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_TextWrapped(ctx, S.status)
    end

    reaper.ImGui_End(ctx)
  end
  if open then reaper.defer(frame) end
end

reaper.defer(frame)
