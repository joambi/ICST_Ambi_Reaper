-- @description Ambi Motion Marker GUI
-- @author JS / Codex
-- @version 1.0
-- @about
--   GUI for sending or recording ICST AmbiEncoder_64 movements from marker pairs.
--
--   Marker examples:
--     ambi 1 a=-45 e=0 d=0.8
--     ambi 1 a=45 e=20 d=0.8

local SCRIPT_NAME = "Ambi Motion Marker GUI"
local EXPECTED_WORKER_VERSION = "5"

local state = {
  ambi_host = "127.0.0.1",
  ambi_port = "50001",
  python_cmd = "",
  steps_per_second = "40",
  marker_tolerance = "0.25",
  curve = "smoothstep",
  polyphonic = true,
  automation_mode = 4, -- 3 = Write, 4 = Latch
  restore_automation_mode = true,
  stop_at_selection_end = true,
  go_to_next_marker_on_stop = true,
  auto_arm_envelopes = true,
  stop_tail_sec = "0.15",
  console_enabled = true,
  focus = nil,
  status = "Ready. Set a time selection between two ambi markers.",
  recording = false,
  recording_started_at = 0,
  recording_seen_playing = false,
  selection_end = nil,
  original_modes = {},
  log_path = "",
  selected_start_marker = nil,
  selected_end_marker = nil,
  marker_scroll = 1,
  auto_follow_timeline = true,
  worker_state = "offline",
  worker_message = "Worker not started.",
  worker_sources = "",
  worker_segment = "",
  worker_last_poll = 0,
  worker_job_counter = 0,
  worker_started_at = 0,
  worker_version = "",
  worker_restart_pending = false,
  worker_restart_requested_at = 0,
  osc_preview_active = false,
  osc_preview_started_at = 0,
  osc_preview_start = 0,
  osc_preview_end = 0,
  osc_preview_progress = 0,
  osc_preview_delay = 0.05,
  osc_preview_track_modes = {},
  osc_preview_envelopes = {},
  recording_series = false,
}

local ui = {
  w = 780,
  h = 620,
  mx = 0,
  my = 0,
  mouse_down = false,
  last_mouse_down = false,
  char = 0,
}

local AMBI_FX_NAME_MATCH = "ambiencoder"
local PARAM_NAME_MATCHES = { "azim", "elev", "dist", "radius" }

local function msg(text)
  state.status = text
  if state.console_enabled then
    reaper.ShowConsoleMsg(tostring(text) .. "\n")
  end
end

local function clear_console()
  if state.console_enabled and reaper.ClearConsole then
    reaper.ClearConsole()
  end
end

local function close_console_window()
  if not reaper.JS_Window_Find then return false end
  local console = reaper.JS_Window_Find("ReaScript console output", true)
  if not console then return false end

  if reaper.JS_WindowMessage_Post then
    reaper.JS_WindowMessage_Post(console, "WM_CLOSE", 0, 0, 0, 0)
    return true
  end

  if reaper.JS_Window_Destroy then
    reaper.JS_Window_Destroy(console)
    return true
  end

  if reaper.JS_Window_Show then
    reaper.JS_Window_Show(console, "HIDE")
    return true
  end

  return false
end

local function toggle_console_logging()
  local next_enabled = not state.console_enabled
  if next_enabled and reaper.ClearConsole then
    reaper.ClearConsole()
  end
  state.console_enabled = next_enabled
  if state.console_enabled then
    msg("Console logging enabled.")
  else
    reaper.ShowConsoleMsg("Console logging disabled.\n")
    close_console_window()
    state.status = "Console logging disabled."
  end
end

local function parse_number(text)
  local normalized = (text or ""):gsub(",", ".")
  return tonumber(normalized)
end

local function parse_int(text)
  local value = tonumber(text)
  if not value then return nil end
  return math.floor(value)
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function join_path(left, right)
  local separator = package.config:sub(1, 1)
  if left:sub(-1) == "/" or left:sub(-1) == "\\" then
    return left .. right
  end
  return left .. separator .. right
end

-- ICST Ambi Reaper layout: everything lives next to this script (Scripts/ICST/Markers)
local function script_dir()
  local _, action_path = reaper.get_action_context()
  if not action_path or action_path == "" then
    action_path = debug.getinfo(1, "S").source:gsub("^@", "")
  end
  return dirname(action_path)
end

local function python_script_path()
  return join_path(script_dir(), "reaper_marker_ambi_motion.py")
end

local function import_csv_script_path()
  return join_path(script_dir(), "JS_Import_Ambi_Markers_From_CSV.lua")
end

local function temp_path(filename)
  local temp_dir = os.getenv("TMPDIR") or "/tmp"
  return join_path(temp_dir, filename)
end

local function worker_dir()
  return temp_path("reaper_ambi_motion_worker")
end

local function worker_path(filename)
  return join_path(worker_dir(), filename)
end

local function ensure_directory(path)
  os.execute("mkdir -p " .. shell_quote(path))
end

local function read_key_value_file(path)
  local values = {}
  local file = io.open(path, "r")
  if not file then return values end
  for line in file:lines() do
    local key, value = line:match("^([^\t]+)\t(.*)$")
    if key then values[key] = value end
  end
  file:close()
  return values
end

local function worker_status_is_fresh(status)
  local heartbeat = tonumber(status.heartbeat or "")
  if not heartbeat then return false end
  return math.abs(os.time() - heartbeat) < 3
end

local function poll_worker_status(force)
  local now = reaper.time_precise()
  if not force and now - state.worker_last_poll < 0.25 then return end
  state.worker_last_poll = now

  local status = read_key_value_file(worker_path("status.tsv"))
  if worker_status_is_fresh(status) then
    state.worker_state = status.state or "unknown"
    state.worker_message = status.message or ""
    state.worker_sources = status.sources or ""
    state.worker_segment = status.segment or ""
    state.worker_version = status.version or ""
  else
    if state.worker_state == "starting" and now - state.worker_started_at < 2.0 then
      state.worker_message = "Worker starting..."
    else
      state.worker_state = "offline"
      state.worker_message = "Worker unreachable."
      state.worker_sources = ""
      state.worker_segment = ""
      state.worker_version = ""
    end
  end
end

local function python_has_osc(cmd)
  -- true if this interpreter can import python-osc
  local f = io.popen('"' .. cmd .. '" -c "import pythonosc" 2>/dev/null && echo ok')
  if not f then msg("io.popen not available") return false end
  local out = f:read("*a") or ""
  f:close()
  return out:find("ok", 1, true) ~= nil
end

local function detect_python()
  local home = os.getenv("HOME") or ""
  local candidates = {
    "/opt/homebrew/bin/python3", "/usr/local/bin/python3",
    home .. "/.pyenv/shims/python3",
    "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
    "/usr/bin/python3",
  }
  -- pyenv versions (newest first)
  local ls = io.popen('ls -1r "' .. home .. '/.pyenv/versions" 2>/dev/null')
  if ls then
    for v in ls:lines() do
      table.insert(candidates, 1, home .. "/.pyenv/versions/" .. v .. "/bin/python3")
    end
    ls:close()
  end
  local first_existing = ""
  for _, c in ipairs(candidates) do
    if file_exists(c) then
      if first_existing == "" then first_existing = c end
      if python_has_osc(c) then return c end
    end
  end
  return first_existing
end

local function start_worker()
  local script_path = python_script_path()
  if state.python_cmd == nil or state.python_cmd == "" then
    state.python_cmd = detect_python()
    msg("Python auto-detected: " .. tostring(state.python_cmd))
  end
  if not file_exists(state.python_cmd) then
    msg("Python 3 not found. Install it (brew install python) and run: pip3 install python-osc  - or enter the path in the Python field.")
    return false
  end
  if not file_exists(script_path) then
    msg("Python script not found: " .. script_path)
    return false
  end

  ensure_directory(worker_dir())
  os.remove(worker_path("command.tsv"))
  os.remove(worker_path("command.tsv.tmp"))
  os.remove(worker_path("status.tsv"))
  local log_path = worker_path("worker.log")
  local command = table.concat({
    shell_quote(state.python_cmd),
    shell_quote(script_path),
    "--worker",
    "--command-dir", shell_quote(worker_dir()),
    ">>", shell_quote(log_path),
    "2>&1",
    "&",
  }, " ")
  os.execute(command)
  state.worker_state = "starting"
  state.worker_message = "Worker starting..."
  state.worker_started_at = reaper.time_precise()
  return true
end

local request_worker_restart
local function ensure_worker()
  poll_worker_status(true)
  if state.worker_state ~= "offline" then
    if state.worker_state == "error" and (state.worker_message or ""):find("pythonosc", 1, true) then
      -- stale worker started with a Python lacking python-osc: restart with re-detected interpreter
      state.python_cmd = ""
      request_worker_restart()
      return false
    end
    if state.worker_version ~= EXPECTED_WORKER_VERSION then
      state.worker_message = "Worker version outdated; restarting."
      return false
    end
    return true
  end
  return start_worker()
end

local function maintain_worker()
  if not state.worker_restart_pending then return end
  if reaper.time_precise() - state.worker_restart_requested_at < 0.2 then return end

  if not file_exists(worker_path("worker.pid")) then
    state.worker_restart_pending = false
    start_worker()
  end
end

local function next_worker_job_id()
  state.worker_job_counter = state.worker_job_counter + 1
  return string.format("%.6f-%d", reaper.time_precise(), state.worker_job_counter)
end

local function next_snapshot_path()
  local token = next_worker_job_id():gsub("[^%w%-]", "_")
  return temp_path("_marker_ambi_motion_snapshot_" .. token .. ".tsv")
end

local function write_worker_command(values)
  ensure_directory(worker_dir())
  local temporary_path = worker_path("command.tsv.tmp")
  local command_path = worker_path("command.tsv")
  local file = io.open(temporary_path, "w")
  if not file then
    msg("Worker command could not be written.")
    return false
  end

  for _, item in ipairs(values) do
    file:write(tostring(item[1]), "\t", tostring(item[2]):gsub("[\r\n\t]", " "), "\n")
  end
  file:close()

  local ok, err = os.rename(temporary_path, command_path)
  if not ok then
    msg("Worker command could not be activated: " .. tostring(err))
    return false
  end
  return true
end

local function run_csv_import()
  local script_path = import_csv_script_path()
  if not file_exists(script_path) then
    msg("CSV import script not found: " .. script_path)
    return false
  end

  _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS = {
    default_path = "markers_xyz.csv",
    replace_existing = true,
    show_summary = false,
    log_summary = false,
  }

  local chunk, err = loadfile(script_path)
  if not chunk then
    msg("Could not load CSV import script: " .. tostring(err))
    _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS = nil
    return false
  end

  local ok, runtime_err = pcall(chunk)
  if not ok then
    _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS = nil
    msg("CSV import failed: " .. tostring(runtime_err))
    return false
  end

  msg("CSV import finished. Existing matching markers were replaced.")
  return true
end

request_worker_restart = function()
  poll_worker_status(true)
  if state.worker_state ~= "offline" then
    write_worker_command({
      { "job_id", next_worker_job_id() },
      { "command", "shutdown" },
    })
  end
  state.worker_restart_pending = true
  state.worker_restart_requested_at = reaper.time_precise()
  state.worker_state = "restarting"
  state.worker_message = "Worker restarting with current version."
end

local function sanitize_marker_name(name)
  return (name or ""):gsub("\r", " "):gsub("\n", " "):gsub("\t", " ")
end

local function marker_is_ambi(name)
  return (name or ""):lower():match("^%s*ambi%s+[^%s]+") ~= nil
end

local function trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ambi_entries_from_marker_name(name)
  local entries = {}
  local normalized = name or ""
  normalized = normalized:gsub("\\r\\n", "\n")
  normalized = normalized:gsub("\\n", "\n")
  normalized = normalized:gsub("\r\n", "\n")
  normalized = normalized:gsub("\r", "\n")
  normalized = normalized:gsub(";", "\n")
  normalized = normalized:gsub("|", "\n")

  for line in (normalized .. "\n"):gmatch("([^\n]*)\n") do
    local remaining = trim(line):gsub("\t", " ")
    while remaining ~= "" do
      local lower = remaining:lower()
      local start_pos = lower:find("ambi%s+[^%s]+")
      if not start_pos then break end

      remaining = trim(remaining:sub(start_pos))
      local next_start = remaining:lower():find("%s+ambi%s+[^%s]+", 2)
      local entry
      if next_start then
        entry = trim(remaining:sub(1, next_start - 1))
        remaining = trim(remaining:sub(next_start + 1))
      else
        entry = remaining
        remaining = ""
      end

      if marker_is_ambi(entry) then
        entries[#entries + 1] = entry
      end
    end
  end

  return entries
end

local function parse_ambi_entry(entry)
  local normalized = (entry or ""):gsub(":", " ")
  local source = normalized:match("^%s*[Aa][Mm][Bb][Ii]%s+([^%s]+)")
  if not source then return nil end
  local source_key, source_value = source:match("^([^=]+)=(.+)$")
  if source_key and source_key:lower() == "source" then
    source = source_value
  end

  local values = {}
  for key, value in normalized:gmatch("([%a_]+)%s*=%s*([%+%-]?[%d%.]+)") do
    local lower_key = key:lower()
    local number = tonumber(value)
    if number then
      if lower_key == "a" or lower_key == "az" or lower_key == "azi" or lower_key == "azimuth" then
        values.azimuth = number
      elseif lower_key == "e" or lower_key == "el" or lower_key == "ele" or lower_key == "elevation" then
        values.elevation = number
      elseif lower_key == "d" or lower_key == "dist" or lower_key == "distance" or lower_key == "r" then
        values.distance = number
      end
    end
  end

  if not values.azimuth or not values.elevation or not values.distance then
    return nil
  end

  return {
    source = source,
    azimuth = values.azimuth,
    elevation = values.elevation,
    distance = values.distance,
  }
end

local function aed_to_xyz(point)
  local azimuth = math.rad(point.azimuth)
  local elevation = math.rad(point.elevation)
  local horizontal = point.distance * math.cos(elevation)
  return {
    source = point.source,
    x = horizontal * math.sin(azimuth),
    y = horizontal * math.cos(azimuth),
    z = point.distance * math.sin(elevation),
  }
end

local function get_ambi_markers()
  local markers = {}
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  local total_count = marker_count + region_count

  for i = 0, total_count - 1 do
    local ok, is_region, position, _, name, index = reaper.EnumProjectMarkers3(0, i)
    if ok then
      local entries = ambi_entries_from_marker_name(name)
      if #entries > 0 then
        local display_name = table.concat(entries, " | ")
        local points = {}
        for _, entry in ipairs(entries) do
          local point = parse_ambi_entry(entry)
          if point then
            points[point.source] = point
          end
        end
        markers[#markers + 1] = {
          position = position,
          index = index,
          is_region = is_region,
          name = display_name,
          voice_count = #entries,
          points = points,
        }
      end
    end
  end

  table.sort(markers, function(a, b) return a.position < b.position end)
  return markers
end

local function sorted_common_sources(start_marker, end_marker)
  local sources = {}
  for source in pairs(start_marker.points or {}) do
    if end_marker.points and end_marker.points[source] then
      sources[#sources + 1] = source
    end
  end
  table.sort(sources, function(a, b)
    local number_a = tonumber(a)
    local number_b = tonumber(b)
    if number_a and number_b then return number_a < number_b end
    if number_a then return true end
    if number_b then return false end
    return a < b
  end)
  return sources
end

local function find_track_by_name(name)
  for index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, index)
    local _, track_name_value = reaper.GetTrackName(track)
    if track_name_value == name then return track end
  end
  return nil
end

local function get_or_create_score_track()
  local track_name_value = "Ambi XYZ Score"
  local track = find_track_by_name(track_name_value)
  if track then return track end

  local insert_index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(insert_index, true)
  track = reaper.GetTrack(0, insert_index)
  if track then
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name_value, true)
    reaper.SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 120)
  end
  return track
end

local function clear_generated_score_items(track)
  for item_index = reaper.CountTrackMediaItems(track) - 1, 0, -1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local _, tag = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMBI_XYZ_SCORE", "", false)
    if tag == "1" then
      reaper.DeleteTrackMediaItem(track, item)
    end
  end
end

local function score_item_notes(segment_index, start_marker, end_marker)
  local lines = {
    string.format(
      "XYZ %02d  %.2fs -> %.2fs",
      segment_index,
      start_marker.position,
      end_marker.position
    ),
  }

  local sources = sorted_common_sources(start_marker, end_marker)
  for _, source in ipairs(sources) do
    local start_xyz = aed_to_xyz(start_marker.points[source])
    local end_xyz = aed_to_xyz(end_marker.points[source])
    lines[#lines + 1] = string.format(
      "%s: (%.3f, %.3f, %.3f) -> (%.3f, %.3f, %.3f)",
      source,
      start_xyz.x,
      start_xyz.y,
      start_xyz.z,
      end_xyz.x,
      end_xyz.y,
      end_xyz.z
    )
  end

  if #sources == 0 then
    lines[#lines + 1] = "No common sources"
  end
  return table.concat(lines, "\n")
end

local function build_xyz_score()
  local markers = get_ambi_markers()
  if #markers < 2 then
    msg("At least two ambi cues are required for the XYZ score.")
    return
  end

  local track = get_or_create_score_track()
  if not track then
    msg("Could not create XYZ score track.")
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  clear_generated_score_items(track)

  local created = 0
  for index = 1, #markers - 1 do
    local start_marker = markers[index]
    local end_marker = markers[index + 1]
    local length = end_marker.position - start_marker.position
    if length > 0 then
      local item = reaper.AddMediaItemToTrack(track)
      reaper.SetMediaItemInfo_Value(item, "D_POSITION", start_marker.position)
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
      reaper.GetSetMediaItemInfo_String(item, "P_NOTES", score_item_notes(index, start_marker, end_marker), true)
      reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMBI_XYZ_SCORE", "1", true)
      if reaper.ColorToNative then
        local color = reaper.ColorToNative(40, 126, 120) | 0x1000000
        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
      end
      created = created + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Build Ambi XYZ Score", -1)
  msg(string.format("XYZ score created: %d item(s) on '%s'.", created, "Ambi XYZ Score"))
end

local function marker_key(marker)
  if not marker then return nil end
  return (marker.is_region and "R" or "M") .. tostring(marker.index) .. "@" .. string.format("%.9f", marker.position)
end

local function find_marker_by_key(markers, key)
  if not key then return nil, nil end
  for i, marker in ipairs(markers) do
    if marker_key(marker) == key then
      return marker, i
    end
  end
  return nil, nil
end

local function ensure_marker_pair(markers)
  if #markers == 0 then
    state.selected_start_marker = nil
    state.selected_end_marker = nil
    return nil, nil
  end

  local start_marker = find_marker_by_key(markers, state.selected_start_marker)
  local end_marker = find_marker_by_key(markers, state.selected_end_marker)

  if not start_marker then
    start_marker = markers[1]
    state.selected_start_marker = marker_key(start_marker)
  end

  if not end_marker then
    end_marker = markers[math.min(2, #markers)] or start_marker
    state.selected_end_marker = marker_key(end_marker)
  end

  return start_marker, end_marker
end

local function nearest_marker(markers, position, tolerance)
  local best = nil
  local best_distance = nil
  for _, marker in ipairs(markers) do
    local distance = math.abs(marker.position - position)
    if distance <= tolerance and (not best_distance or distance < best_distance) then
      best = marker
      best_distance = distance
    end
  end
  return best
end

local function timeline_position()
  local play_state = reaper.GetPlayState()
  if (play_state & 1) == 1 then
    return reaper.GetPlayPosition()
  end
  return reaper.GetCursorPosition()
end

local function nearest_marker_index(markers, position)
  local best_index = nil
  local best_distance = nil
  for i, marker in ipairs(markers) do
    local distance = math.abs(marker.position - position)
    if not best_distance or distance < best_distance then
      best_index = i
      best_distance = distance
    end
  end
  return best_index
end

local function auto_follow_marker_scroll(markers, max_rows)
  if not state.auto_follow_timeline or #markers == 0 or max_rows <= 0 then return end

  local index = nearest_marker_index(markers, timeline_position())
  if not index then return end

  local half_rows = math.floor(max_rows / 2)
  state.marker_scroll = clamp(index - half_rows, 1, math.max(1, #markers - max_rows + 1))
end

local function set_time_selection_from_markers(start_marker, end_marker)
  if not start_marker or not end_marker then
    msg("Please choose a start and end marker.")
    return false
  end

  if marker_key(start_marker) == marker_key(end_marker) then
    msg("Start and end markers must be different.")
    return false
  end

  local start_pos = math.min(start_marker.position, end_marker.position)
  local end_pos = math.max(start_marker.position, end_marker.position)
  reaper.GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)
  reaper.SetEditCurPos(start_pos, true, false)
  reaper.UpdateArrange()
  msg(string.format("Selection: %s -> %s (%.3fs)", start_marker.name, end_marker.name, end_pos - start_pos))
  return true
end

local function select_pair_by_index(start_index, end_index)
  local markers = get_ambi_markers()
  if #markers == 0 then
    msg("No ambi markers found.")
    return
  end

  start_index = clamp(start_index, 1, #markers)
  end_index = clamp(end_index, 1, #markers)
  state.selected_start_marker = marker_key(markers[start_index])
  state.selected_end_marker = marker_key(markers[end_index])
  set_time_selection_from_markers(markers[start_index], markers[end_index])
end

local function shift_pair(delta)
  local markers = get_ambi_markers()
  local _, start_index = find_marker_by_key(markers, state.selected_start_marker)
  local _, end_index = find_marker_by_key(markers, state.selected_end_marker)
  if not start_index or not end_index then
    ensure_marker_pair(markers)
    _, start_index = find_marker_by_key(markers, state.selected_start_marker)
    _, end_index = find_marker_by_key(markers, state.selected_end_marker)
  end
  if not start_index or not end_index then return end
  select_pair_by_index(start_index + delta, end_index + delta)
end

local function advance_pair_after_stop()
  if not state.go_to_next_marker_on_stop then return false end

  local markers = get_ambi_markers()
  local _, start_index = find_marker_by_key(markers, state.selected_start_marker)
  local _, end_index = find_marker_by_key(markers, state.selected_end_marker)
  if not start_index or not end_index then return false end

  local next_start = start_index + 1
  local next_end = end_index + 1
  if next_start > #markers or next_end > #markers then
    msg("End of marker sequence reached.")
    return false
  end

  select_pair_by_index(next_start, next_end)
  return true
end

local function get_selection_preview()
  local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local tolerance = parse_number(state.marker_tolerance) or 0.25
  local markers = get_ambi_markers()
  local _, project_marker_count, project_region_count = reaper.CountProjectMarkers(0)
  return {
    start_pos = ts_start,
    end_pos = ts_end,
    duration = ts_end - ts_start,
    start_marker = nearest_marker(markers, ts_start, tolerance),
    end_marker = nearest_marker(markers, ts_end, tolerance),
    marker_count = #markers,
    project_marker_count = project_marker_count,
    project_region_count = project_region_count,
  }
end

local function write_snapshot(path, motion_start_marker, motion_end_marker)
  local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if ts_end <= ts_start then
    return false, "No valid loop/time selection.", nil, nil
  end

  local file = io.open(path, "w")
  if not file then
    return false, "Could not write snapshot file: " .. path, nil, nil
  end

  file:write(string.format("selection\t%.17g\t%.17g\n", ts_start, ts_end))
  if motion_start_marker and motion_end_marker then
    file:write(string.format("motion\t%.17g\t%.17g\n", motion_start_marker.position, motion_end_marker.position))
  end

  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  local total_count = marker_count + region_count
  for i = 0, total_count - 1 do
    local ok, _, position, _, name, index = reaper.EnumProjectMarkers3(0, i)
    if ok then
      local entries = ambi_entries_from_marker_name(name)
      for _, entry in ipairs(entries) do
        file:write(string.format("marker\t%.17g\t%d\t%s\n", position, index, sanitize_marker_name(entry)))
      end
    end
  end

  file:close()
  return true, nil, ts_start, ts_end
end

local function collect_selected_tracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
  end
  return tracks
end

local function collect_ambiencoder_tracks()
  local tracks = {}
  for track_index = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, track_index)
    for fx_index = 0, reaper.TrackFX_GetCount(track) - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
      if (fx_name or ""):lower():find(AMBI_FX_NAME_MATCH, 1, true) then
        tracks[#tracks + 1] = track
        break
      end
    end
  end
  return tracks
end

local function track_name(track)
  local _, name = reaper.GetTrackName(track)
  return name or ""
end

local function selected_track_summary()
  local tracks = collect_selected_tracks()
  if #tracks == 0 then return "No tracks selected" end
  if #tracks == 1 then return track_name(tracks[1]) end
  return tostring(#tracks) .. " Tracks selektiert"
end

local collect_ambiencoder_parameter_envelopes
local set_envelope_active_state

local function protect_preview_from_automation()
  local tracks = collect_ambiencoder_tracks()
  state.osc_preview_track_modes = {}
  state.osc_preview_envelopes = {}

  for _, track in ipairs(tracks) do
    state.osc_preview_track_modes[#state.osc_preview_track_modes + 1] = {
      track = track,
      mode = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE"),
    }
    reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", 1) -- Read
  end

  for _, env in ipairs(collect_ambiencoder_parameter_envelopes(tracks, false)) do
    local ok, previous_active = set_envelope_active_state(env, false)
    if ok then
      state.osc_preview_envelopes[#state.osc_preview_envelopes + 1] = {
        env = env,
        active = previous_active,
      }
    end
  end
end

local function restore_preview_automation_modes()
  for _, item in ipairs(state.osc_preview_envelopes) do
    if item.env then
      set_envelope_active_state(item.env, tonumber(item.active or 0) >= 0.5)
    end
  end
  state.osc_preview_envelopes = {}

  for _, item in ipairs(state.osc_preview_track_modes) do
    if item.track then
      reaper.SetMediaTrackInfo_Value(item.track, "I_AUTOMODE", item.mode)
    end
  end
  state.osc_preview_track_modes = {}
end

local function set_automation_mode(tracks, mode)
  state.original_modes = {}
  for _, track in ipairs(tracks) do
    state.original_modes[#state.original_modes + 1] = {
      track = track,
      mode = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE"),
    }
    reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", mode)
  end
end

local function restore_automation_modes()
  if not state.restore_automation_mode then return end
  for _, item in ipairs(state.original_modes) do
    if item.track then
      reaper.SetMediaTrackInfo_Value(item.track, "I_AUTOMODE", item.mode)
    end
  end
  state.original_modes = {}
end

local function name_matches_any(name, matches)
  local normalized = (name or ""):lower()
  for _, pattern in ipairs(matches) do
    if normalized:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

collect_ambiencoder_parameter_envelopes = function(tracks, create_if_missing)
  local envelopes = {}
  for _, track in ipairs(tracks) do
    for fx_index = 0, reaper.TrackFX_GetCount(track) - 1 do
      local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
      if (fx_name or ""):lower():find(AMBI_FX_NAME_MATCH, 1, true) then
        local param_count = reaper.TrackFX_GetNumParams(track, fx_index)
        for param_index = 0, param_count - 1 do
          local _, param_name = reaper.TrackFX_GetParamName(track, fx_index, param_index, "")
          if name_matches_any(param_name, PARAM_NAME_MATCHES) then
            local env = reaper.GetFXEnvelope(track, fx_index, param_index, create_if_missing and true or false)
            if env then
              envelopes[#envelopes + 1] = env
            end
          end
        end
      end
    end
  end
  return envelopes
end

set_envelope_active_state = function(env, active)
  if reaper.GetEnvelopeInfo_Value and reaper.SetEnvelopeInfo_Value then
    local previous = reaper.GetEnvelopeInfo_Value(env, "B_ACTIVE")
    reaper.SetEnvelopeInfo_Value(env, "B_ACTIVE", active and 1 or 0)
    return previous ~= nil, previous
  end

  if reaper.BR_EnvGetProperties and reaper.BR_EnvSetProperties then
    local active_now, visible, armed, in_lane, lane_height, default_shape, _, _, _, _, fader_scaling =
      reaper.BR_EnvGetProperties(env)
    reaper.BR_EnvSetProperties(
      env,
      active,
      visible,
      armed,
      in_lane,
      lane_height,
      default_shape,
      fader_scaling
    )
    return true, active_now and 1 or 0
  end

  return false, nil
end

local function set_envelope_record_ready(env)
  if reaper.SetEnvelopeInfo_Value then
    reaper.SetEnvelopeInfo_Value(env, "B_ACTIVE", 1)
    reaper.SetEnvelopeInfo_Value(env, "B_VISIBLE", 1)
    reaper.SetEnvelopeInfo_Value(env, "B_ARM", 1)
    return true
  end

  if reaper.BR_EnvGetProperties and reaper.BR_EnvSetProperties then
    local _, _, _, in_lane, lane_height, default_shape, _, _, _, _, fader_scaling = reaper.BR_EnvGetProperties(env)
    reaper.BR_EnvSetProperties(env, true, true, true, in_lane, lane_height, default_shape, fader_scaling)
    return true
  end

  return false
end

local function arm_ambiencoder_envelopes(tracks)
  if not state.auto_arm_envelopes then return 0 end

  local armed_count = 0
  local envelopes = collect_ambiencoder_parameter_envelopes(tracks, true)
  for _, env in ipairs(envelopes) do
    if set_envelope_record_ready(env) then
      armed_count = armed_count + 1
    end
  end
  return armed_count
end

local function validate_motion_settings()
  local port = parse_int(state.ambi_port)
  local steps = parse_number(state.steps_per_second)
  local tolerance = parse_number(state.marker_tolerance)

  if not port or port <= 0 then return nil, "Invalid OSC port." end
  if not steps or steps <= 0 then return nil, "Invalid steps/sec." end
  if not tolerance or tolerance < 0 then return nil, "Invalid marker tolerance." end
  return {
    port = port,
    steps = steps,
    tolerance = tolerance,
  }, nil
end

local function submit_worker_motion(snapshot_path, series)
  local settings, err = validate_motion_settings()
  if not settings then
    msg(err)
    return false
  end

  if not ensure_worker() then return false end

  local job_id = next_worker_job_id()
  local ok = write_worker_command({
    { "job_id", job_id },
    { "command", "start" },
    { "snapshot_file", snapshot_path },
    { "ambi_host", (tostring(state.ambi_host or ""):gsub("^%s+",""):gsub("%s+$","")) ~= "" and (tostring(state.ambi_host):gsub("^%s+",""):gsub("%s+$","")) or "127.0.0.1" },
    { "ambi_port", settings.port },
    { "steps_per_second", settings.steps },
    { "curve", state.curve },
    { "marker_tolerance", settings.tolerance },
    { "polyphonic", state.polyphonic and "1" or "0" },
    { "start_delay", "0.05" },
    { "series", series and "1" or "0" },
  })
  if ok then
    state.worker_state = "queued"
    state.worker_message = "Motion handed off to worker."
  end
  return ok
end

local function stop_worker_motion()
  poll_worker_status(true)
  if state.worker_state == "offline" then
    state.worker_message = "No active OSC motion."
    return true
  end
  local ok = write_worker_command({
    { "job_id", next_worker_job_id() },
    { "command", "stop" },
  })
  if ok then
    state.worker_state = "stopping"
    state.worker_message = "Stop sent to worker."
  end
  return ok
end

local function finish_osc_preview(completed)
  if not state.osc_preview_active then return end

  state.osc_preview_active = false
  restore_preview_automation_modes()
  state.osc_preview_progress = completed and 1 or state.osc_preview_progress
  if completed then
    reaper.SetEditCurPos(state.osc_preview_end, true, false)
    if state.go_to_next_marker_on_stop then
      if advance_pair_after_stop() then
        msg("OSC preview finished. Next marker pair prepared.")
      else
        msg("OSC preview finished. No further marker pair.")
      end
    else
      msg("OSC preview finished.")
    end
  else
    msg("OSC preview stopped.")
  end
end

local function start_osc_preview(selection_start, selection_end)
  protect_preview_from_automation()
  state.osc_preview_active = true
  state.osc_preview_started_at = reaper.time_precise() + state.osc_preview_delay
  state.osc_preview_start = selection_start
  state.osc_preview_end = selection_end
  state.osc_preview_progress = 0
  reaper.SetEditCurPos(selection_start, true, false)
end

local function monitor_osc_preview()
  if not state.osc_preview_active then return end

  if state.worker_state == "error" then
    state.osc_preview_active = false
    restore_preview_automation_modes()
    msg("OSC preview aborted: " .. state.worker_message)
    return
  end

  local duration = state.osc_preview_end - state.osc_preview_start
  if duration <= 0 then
    finish_osc_preview(false)
    return
  end

  local elapsed = math.max(0, reaper.time_precise() - state.osc_preview_started_at)
  local progress = clamp(elapsed / duration, 0, 1)
  state.osc_preview_progress = progress
  local cursor_position = state.osc_preview_start + duration * progress
  reaper.SetEditCurPos(cursor_position, true, false)

  if progress >= 1 then
    finish_osc_preview(true)
  end
end

local function send_only()
  if state.osc_preview_active then
    restore_preview_automation_modes()
    state.osc_preview_active = false
  end

  local markers = get_ambi_markers()
  local start_marker, end_marker = ensure_marker_pair(markers)
  if not start_marker or not end_marker then
    msg("No valid ambi markers/regions found.")
    return
  end
  if not set_time_selection_from_markers(start_marker, end_marker) then
    return
  end

  local snapshot_path = next_snapshot_path()
  local ok, err, selection_start, selection_end = write_snapshot(snapshot_path, start_marker, end_marker)
  if not ok then
    msg(err)
    return
  end

  if submit_worker_motion(snapshot_path, false) then
    state.log_path = worker_path("worker.log")
    start_osc_preview(selection_start, selection_end)
    clear_console()
    msg("OSC motion with timeline preview started.")
  end
end

local function resolve_series_range(markers)
  if #markers < 2 then
    return nil, nil, nil, "No valid ambi markers/regions found."
  end

  local start_marker, start_index = find_marker_by_key(markers, state.selected_start_marker)
  if not start_marker or not start_index then
    start_marker, start_index = ensure_marker_pair(markers)
    _, start_index = find_marker_by_key(markers, state.selected_start_marker)
  end
  if not start_marker or not start_index then
    return nil, nil, nil, "No valid start marker found for the series."
  end

  if start_index >= #markers then
    return nil, nil, nil, "The current start marker is already the last marker."
  end

  local end_marker = markers[#markers]
  state.selected_start_marker = marker_key(start_marker)
  state.selected_end_marker = marker_key(end_marker)
  return start_marker, end_marker, start_index, nil
end

local function send_series()
  if state.osc_preview_active then
    restore_preview_automation_modes()
    state.osc_preview_active = false
  end

  local markers = get_ambi_markers()
  local start_marker, end_marker, _, err = resolve_series_range(markers)
  if not start_marker or not end_marker then
    msg(err)
    return
  end
  if not set_time_selection_from_markers(start_marker, end_marker) then
    return
  end

  local snapshot_path = next_snapshot_path()
  local ok, err, selection_start, selection_end = write_snapshot(snapshot_path, start_marker, end_marker)
  if not ok then
    msg(err)
    return
  end

  if submit_worker_motion(snapshot_path, true) then
    state.log_path = worker_path("worker.log")
    start_osc_preview(selection_start, selection_end)
    clear_console()
    msg("OSC series with timeline preview started: from current start to last marker.")
  end
end

local function start_record()
  if state.recording then
    msg("Recording is already running.")
    return
  end
  if state.osc_preview_active then
    stop_worker_motion()
    finish_osc_preview(false)
  end

  local tracks = collect_selected_tracks()
  if #tracks == 0 then
    msg("Please select the AmbiEncoder track.")
    return
  end

  local mode = state.automation_mode == 3 and 3 or 4
  local markers = get_ambi_markers()
  local start_marker, end_marker = ensure_marker_pair(markers)
  if not start_marker or not end_marker then
    msg("No valid ambi markers/regions found.")
    return
  end
  if not set_time_selection_from_markers(start_marker, end_marker) then
    return
  end

  local snapshot_path = next_snapshot_path()
  local ok, err, selection_start, selection_end = write_snapshot(snapshot_path, start_marker, end_marker)
  if not ok then
    msg(err)
    return
  end

  reaper.Undo_BeginBlock()
  set_automation_mode(tracks, mode)
  local armed_count = arm_ambiencoder_envelopes(tracks)
  reaper.SetEditCurPos(selection_start, true, false)

  if not submit_worker_motion(snapshot_path, false) then
    restore_automation_modes()
    reaper.Undo_EndBlock(SCRIPT_NAME .. " failed", -1)
    return
  end
  reaper.OnPlayButton()

  state.recording = true
  state.recording_series = false
  state.recording_started_at = reaper.time_precise()
  state.recording_seen_playing = false
  state.selection_end = selection_end
  state.log_path = worker_path("worker.log")
  clear_console()
  msg("Recording: " .. tostring(#tracks) .. " track(s), " .. tostring(armed_count) .. " env(s) armed.")
  reaper.Undo_EndBlock(SCRIPT_NAME .. " record", -1)
end

local function start_record_series()
  if state.recording then
    msg("Recording is already running.")
    return
  end
  if state.osc_preview_active then
    stop_worker_motion()
    finish_osc_preview(false)
  end

  local tracks = collect_selected_tracks()
  if #tracks == 0 then
    msg("Please select the AmbiEncoder track.")
    return
  end

  local markers = get_ambi_markers()
  local start_marker, end_marker, start_index, err = resolve_series_range(markers)
  if not start_marker or not end_marker then
    msg(err)
    return
  end
  if not set_time_selection_from_markers(start_marker, end_marker) then
    return
  end

  local snapshot_path = next_snapshot_path()
  local ok, err, selection_start, selection_end = write_snapshot(snapshot_path, start_marker, end_marker)
  if not ok then
    msg(err)
    return
  end

  local mode = state.automation_mode == 3 and 3 or 4
  reaper.Undo_BeginBlock()
  set_automation_mode(tracks, mode)
  local armed_count = arm_ambiencoder_envelopes(tracks)
  reaper.SetEditCurPos(selection_start, true, false)

  if not submit_worker_motion(snapshot_path, true) then
    restore_automation_modes()
    reaper.Undo_EndBlock(SCRIPT_NAME .. " series failed", -1)
    return
  end
  reaper.OnPlayButton()

  state.recording = true
  state.recording_series = true
  state.recording_started_at = reaper.time_precise()
  state.recording_seen_playing = false
  state.selection_end = selection_end
  state.log_path = worker_path("worker.log")
  clear_console()
  msg(
    string.format(
      "Series recording: %d cues, %d segments, %d env(s) armed.",
      (#markers - start_index + 1),
      (#markers - start_index),
      armed_count
    )
  )
  reaper.Undo_EndBlock(SCRIPT_NAME .. " record series", -1)
end

local function finish_record()
  stop_worker_motion()
  if state.stop_at_selection_end then
    reaper.OnStopButton()
  end
  restore_automation_modes()
  state.recording = false
  state.recording_started_at = 0
  state.recording_seen_playing = false
  state.selection_end = nil
  local completed_series = state.recording_series
  state.recording_series = false
  if completed_series then
    msg("Series automation recording finished.")
  elseif state.go_to_next_marker_on_stop then
    if advance_pair_after_stop() then
      msg("Automation recording finished. Next marker pair prepared.")
    else
      msg("Automation recording finished. No further marker pair.")
    end
  else
    msg("Automation recording finished.")
  end
end

local function stop_record_now()
  if state.recording then
    finish_record()
  elseif state.osc_preview_active then
    stop_worker_motion()
    finish_osc_preview(false)
  else
    stop_worker_motion()
    reaper.OnStopButton()
    msg("Transport and OSC motion stopped.")
  end
end

local function monitor_record()
  if not state.recording then return end
  local play_state = reaper.GetPlayState()
  local is_playing = (play_state & 1) == 1
  local play_pos = reaper.GetPlayPosition()
  local tail = parse_number(state.stop_tail_sec) or 0.15
  local now = reaper.time_precise()
  local startup_grace = 0.75

  if is_playing then
    state.recording_seen_playing = true
  end

  if not is_playing then
    if not state.recording_seen_playing and (now - state.recording_started_at) < startup_grace then
      return
    end
    finish_record()
    return
  end

  if play_pos >= (state.selection_end + tail) then
    finish_record()
  end
end

local function rect_hit(x, y, w, h)
  return ui.mx >= x and ui.mx <= x + w and ui.my >= y and ui.my <= y + h
end

local function mouse_clicked(x, y, w, h)
  return ui.mouse_down and not ui.last_mouse_down and rect_hit(x, y, w, h)
end

local function draw_rect(x, y, w, h, r, g, b, a, filled)
  gfx.set(r, g, b, a or 1)
  gfx.rect(x, y, w, h, filled and 1 or 0)
end

local function draw_text(text, x, y, r, g, b)
  gfx.set(r or 0.88, g or 0.90, b or 0.92, 1)
  gfx.x = x
  gfx.y = y
  gfx.drawstr(text or "")
end

local function draw_text_sized(text, x, y, size, r, g, b)
  gfx.setfont(1, "Arial", size)
  draw_text(text, x, y, r, g, b)
  gfx.setfont(1, "Arial", 14)
end

local function fit_text_width(text, max_width)
  local shown = tostring(text or "")
  local width = gfx.measurestr(shown)
  if width <= max_width then return shown end
  while #shown > 3 do
    shown = shown:sub(1, -2)
    local candidate = shown .. "..."
    if gfx.measurestr(candidate) <= max_width then
      return candidate
    end
  end
  return "..."
end

local function wrap_text_lines(text, max_width, max_lines)
  local source = tostring(text or "")
  local lines = {}
  if source == "" then return { "" } end

  local current = ""
  for word in source:gmatch("%S+") do
    local candidate = current == "" and word or (current .. " " .. word)
    if gfx.measurestr(candidate) <= max_width then
      current = candidate
    else
      if current == "" then
        current = fit_text_width(word, max_width)
      end
      lines[#lines + 1] = current
      current = word
      if #lines >= max_lines - 1 then
        current = fit_text_width(current, max_width)
        break
      end
      if gfx.measurestr(current) > max_width then
        current = fit_text_width(current, max_width)
      end
    end
  end

  if current ~= "" then
    if #lines >= max_lines then
      lines[max_lines] = fit_text_width(current, max_width)
    else
      lines[#lines + 1] = fit_text_width(current, max_width)
    end
  end

  while #lines > max_lines do
    table.remove(lines)
  end
  if #lines == max_lines then
    lines[max_lines] = fit_text_width(lines[max_lines], max_width)
  end
  return lines
end

local function draw_wrapped_value(label, value, x, y, label_w, value_w, max_lines, r, g, b)
  draw_text_sized(label, x, y + 1, 13, 0.78, 0.82, 0.84)
  local lines = wrap_text_lines(value, value_w, max_lines)
  for i = 1, #lines do
    draw_text_sized(lines[i], x + label_w, y + ((i - 1) * 16), 13, r, g, b)
  end
end

local function draw_label(label, x, y)
  draw_text(label, x, y, 0.62, 0.66, 0.70)
end

local function draw_button(label, x, y, w, h, accent, disabled)
  local hover = rect_hit(x, y, w, h) and not disabled
  local r, g, b = 0.20, 0.24, 0.28
  if accent then r, g, b = 0.18, 0.38, 0.32 end
  if disabled then r, g, b = 0.14, 0.15, 0.17 end
  if hover then r, g, b = r + 0.06, g + 0.06, b + 0.06 end
  draw_rect(x, y, w, h, r, g, b, 1, true)
  draw_rect(x, y, w, h, 0.45, 0.50, 0.56, disabled and 0.45 or 1, false)
  local tw, th = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - th) / 2 + 1, disabled and 0.48 or 0.90, disabled and 0.50 or 0.92, disabled and 0.54 or 0.94)
  return not disabled and mouse_clicked(x, y, w, h)
end

local function draw_toggle(label, value, x, y)
  local size = 18
  local clicked = mouse_clicked(x, y, size, size) or mouse_clicked(x + 24, y - 2, 220, 22)
  if clicked then value = not value end
  draw_rect(x, y, size, size, 0.16, 0.18, 0.21, 1, true)
  draw_rect(x, y, size, size, 0.48, 0.52, 0.58, 1, false)
  if value then
    draw_rect(x + 4, y + 4, size - 8, size - 8, 0.35, 0.78, 0.58, 1, true)
  end
  draw_text(label, x + 26, y + 2)
  return value
end

local function draw_radio(label, current, value, x, y)
  local size = 18
  local clicked = mouse_clicked(x, y, size, size) or mouse_clicked(x + 24, y - 2, 130, 22)
  if clicked then current = value end
  draw_rect(x, y, size, size, 0.16, 0.18, 0.21, 1, true)
  draw_rect(x, y, size, size, 0.48, 0.52, 0.58, 1, false)
  if current == value then
    draw_rect(x + 4, y + 4, size - 8, size - 8, 0.35, 0.78, 0.58, 1, true)
  end
  draw_text(label, x + 26, y + 2)
  return current
end

local function draw_input(id, label, value, x, y, w)
  draw_label(label, x, y)
  local box_y = y + 18
  local active = state.focus == id
  if mouse_clicked(x, box_y, w, 28) then
    state.focus = id
    active = true
  end
  draw_rect(x, box_y, w, 28, active and 0.12 or 0.10, active and 0.16 or 0.12, active and 0.18 or 0.14, 1, true)
  draw_rect(x, box_y, w, 28, active and 0.35 or 0.36, active and 0.70 or 0.40, active and 0.58 or 0.45, 1, false)
  local shown = tostring(value or "")
  if active and math.floor(reaper.time_precise() * 2) % 2 == 0 then
    shown = shown .. "|"
  end
  draw_text(shown, x + 8, box_y + 7)
  return value
end

local function handle_text_input()
  if not state.focus then return end
  local char = ui.char
  if char == 0 then return end

  if char == 27 or char == 13 then
    state.focus = nil
    return
  end

  local key = state.focus
  local text = tostring(state[key] or "")
  if char == 8 then
    state[key] = text:sub(1, -2)
  elseif char >= 32 and char <= 126 then
    state[key] = text .. string.char(char)
  end
end

local function draw_status_bar()
  draw_rect(0, ui.h - 44, ui.w, 44, 0.08, 0.09, 0.10, 1, true)
  local button_w = 104
  local button_x = ui.w - button_w - 18
  local text_w = button_x - 32
  draw_text(fit_text_width(state.status, text_w), 18, ui.h - 32, 0.82, 0.86, 0.88)
  local worker_text = "Worker: " .. state.worker_state
  if state.worker_sources ~= "" then worker_text = worker_text .. " [" .. state.worker_sources .. "]" end
  if state.worker_segment ~= "" then worker_text = worker_text .. " Segment " .. state.worker_segment end
  if state.worker_message ~= "" then worker_text = worker_text .. " - " .. state.worker_message end
  local error_state = state.worker_state == "error"
  draw_text(fit_text_width(worker_text, text_w), 18, ui.h - 16, error_state and 0.92 or 0.54, error_state and 0.46 or 0.58, error_state and 0.44 or 0.62)
  if draw_button(state.console_enabled and "Console ON" or "Console OFF", button_x, ui.h - 34, button_w, 24, state.console_enabled, false) then
    toggle_console_logging()
  end
end

local function draw_preview(x, y, w, h)
  local preview = get_selection_preview()
  draw_rect(x, y, w, h, 0.12, 0.14, 0.16, 1, true)
  draw_rect(x, y, w, h, 0.30, 0.34, 0.38, 1, false)
  draw_text("Selection / Marker", x + 14, y + 12, 0.94, 0.96, 0.96)

  local valid_selection = preview.duration > 0
  local start_name = preview.start_marker and preview.start_marker.name or "-"
  local end_name = preview.end_marker and preview.end_marker.name or "-"
  local ok = valid_selection and preview.start_marker and preview.end_marker
  local value_x = x + 14
  local value_label_w = 56
  local value_w = w - 28 - value_label_w

  draw_text(string.format("Duration: %.3fs", math.max(0, preview.duration)), x + 14, y + 44, ok and 0.74 or 0.88, ok and 0.88 or 0.48, ok and 0.78 or 0.46)
  draw_wrapped_value("Start:", start_name, value_x, y + 68, value_label_w, value_w, 2, 0.88, 0.90, 0.92)
  draw_wrapped_value("End:", end_name, value_x, y + 100, value_label_w, value_w, 2, 0.88, 0.90, 0.92)
  draw_text(
    string.format(
      "Ambi-Cues: %d | Projektmarker: %d | Regionen: %d",
      preview.marker_count,
      preview.project_marker_count,
      preview.project_region_count
    ),
    x + 14,
    y + 128,
    0.62,
    0.66,
    0.70
  )
  draw_text_sized("Track: " .. fit_text_width(selected_track_summary(), w - 84), x + 14, y + 146, 13, 0.78, 0.82, 0.84)

  local progress = state.osc_preview_active and state.osc_preview_progress or 0
  local bar_x = x + 14
  local bar_y = y + h - 10
  local bar_w = w - 28
  draw_rect(bar_x, bar_y, bar_w, 4, 0.22, 0.25, 0.28, 1, true)
  if state.osc_preview_active or state.osc_preview_progress > 0 then
    draw_rect(bar_x, bar_y, bar_w * clamp(progress, 0, 1), 4, 0.35, 0.78, 0.58, 1, true)
    draw_text(string.format("Preview %.0f%%", progress * 100), x + w - 96, y + 12, 0.64, 0.86, 0.74)
  end
end

local function compact_marker_name(name, max_chars)
  local text = tostring(name or "")
  if #text <= max_chars then return text end
  return text:sub(1, max_chars - 3) .. "..."
end

local function format_compact_number(value)
  local rounded = math.floor((tonumber(value) or 0) * 1000 + 0.5) / 1000
  local text = string.format("%.3f", rounded)
  text = text:gsub("(%..-)0+$", "%1")
  text = text:gsub("%.$", "")
  return text
end

local function compact_marker_label(marker, max_chars)
  local points = marker and marker.points or nil
  if not points then
    return compact_marker_name(marker and marker.name or "", max_chars)
  end

  local sources = {}
  for source in pairs(points) do
    sources[#sources + 1] = source
  end
  table.sort(sources, function(left, right) return tostring(left) < tostring(right) end)

  if #sources == 0 then
    return compact_marker_name(marker and marker.name or "", max_chars)
  end

  local parts = {}
  for _, source in ipairs(sources) do
    local point = points[source]
    parts[#parts + 1] = string.format(
      "%s:%s/%s/%s",
      tostring(source),
      format_compact_number(point.azimuth),
      format_compact_number(point.elevation),
      format_compact_number(point.distance)
    )
  end

  return compact_marker_name(table.concat(parts, " | "), max_chars)
end

local function compact_marker_label_by_width(marker, max_width)
  return fit_text_width(compact_marker_label(marker, 120), max_width)
end

local function draw_marker_pair_list(x, y, w, h)
  local markers = get_ambi_markers()
  local start_marker, end_marker = ensure_marker_pair(markers)
  local start_key = marker_key(start_marker)
  local end_key = marker_key(end_marker)
  local cursor_pos = timeline_position()
  local cursor_marker_index = nearest_marker_index(markers, cursor_pos)

  draw_rect(x, y, w, h, 0.12, 0.14, 0.16, 1, true)
  draw_rect(x, y, w, h, 0.30, 0.34, 0.38, 1, false)
  draw_text("Ambi Markers", x + 14, y + 12, 0.94, 0.96, 0.96)
  if draw_button("Load CSV", x + 98, y + 8, 96, 24, false, false) then
    run_csv_import()
  end
  draw_text("Click left for S, right for E. Then set selection.", x + 14, y + 34, 0.58, 0.62, 0.66)
  if draw_button(state.auto_follow_timeline and "Follow ON" or "Follow OFF", x + w - 106, y + 8, 92, 24, state.auto_follow_timeline, false) then
    state.auto_follow_timeline = not state.auto_follow_timeline
  end

  if #markers == 0 then
    draw_text("No markers or regions with 'ambi ...' found.", x + 14, y + 68, 0.90, 0.50, 0.48)
    return
  end

  local row_h = 23
  local list_y = y + 60
  local max_rows = math.floor((h - 110) / row_h)
  local row_x = x + 10
  local row_w = w - 20
  local col_index_x = row_x + 8
  local col_time_x = row_x + 42
  local col_voices_x = row_x + row_w - 74
  local col_flag_s_x = row_x + row_w - 42
  local col_flag_e_x = row_x + row_w - 22
  local col_label_x = row_x + 102
  local col_label_w = col_voices_x - col_label_x - 10
  auto_follow_marker_scroll(markers, max_rows)
  state.marker_scroll = clamp(state.marker_scroll, 1, math.max(1, #markers - max_rows + 1))

  for row = 0, math.min(max_rows - 1, #markers - state.marker_scroll) do
    local index = state.marker_scroll + row
    local marker = markers[index]
    local key = marker_key(marker)
    local row_y = list_y + row * row_h
    local is_start = key == start_key
    local is_end = key == end_key
    local is_cursor = index == cursor_marker_index
    local is_hover = rect_hit(x + 10, row_y, w - 20, row_h - 2)

    local r, g, b = 0.10, 0.12, 0.14
    if is_start and is_end then r, g, b = 0.34, 0.22, 0.12
    elseif is_start then r, g, b = 0.16, 0.30, 0.24
    elseif is_end then r, g, b = 0.18, 0.22, 0.36
    elseif is_cursor then r, g, b = 0.24, 0.20, 0.12
    elseif is_hover then r, g, b = 0.16, 0.18, 0.21 end

    draw_rect(row_x, row_y, row_w, row_h - 2, r, g, b, 1, true)
    if is_cursor then
      draw_rect(row_x, row_y, 4, row_h - 2, 0.96, 0.74, 0.30, 1, true)
    end
    draw_text_sized(string.format("%02d", index), col_index_x, row_y + 5, 13, 0.66, 0.70, 0.74)
    draw_text_sized(string.format("%.2fs", marker.position), col_time_x, row_y + 5, 13, 0.58, 0.62, 0.66)
    draw_text_sized(compact_marker_label_by_width(marker, col_label_w), col_label_x, row_y + 5, 13, 0.88, 0.90, 0.92)
    if marker.voice_count and marker.voice_count > 1 then
      draw_text_sized("x" .. tostring(marker.voice_count), col_voices_x, row_y + 5, 13, 0.76, 0.80, 0.84)
    end

    if is_start then draw_text_sized("S", col_flag_s_x, row_y + 5, 13, 0.48, 0.92, 0.70) end
    if is_end then draw_text_sized("E", col_flag_e_x, row_y + 5, 13, 0.58, 0.72, 0.98) end

    if mouse_clicked(row_x, row_y, row_w, row_h - 2) then
      if ui.mx < x + (w / 2) then
        state.selected_start_marker = key
        msg("Start marker: " .. marker.name)
      else
        state.selected_end_marker = key
        msg("End marker: " .. marker.name)
      end
    end
  end

  local strip_x = x + 14
  local strip_y = y + h - 66
  local strip_w = w - 28
  local strip_h = 14
  local first_pos = markers[1].position
  local last_pos = markers[#markers].position
  local span = math.max(0.0001, last_pos - first_pos)
  draw_rect(strip_x, strip_y + 6, strip_w, 2, 0.30, 0.34, 0.38, 1, true)
  for i, marker in ipairs(markers) do
    local px = strip_x + ((marker.position - first_pos) / span) * strip_w
    local key = marker_key(marker)
    local is_selected = key == start_key or key == end_key
    draw_rect(px - 1, strip_y + (is_selected and 1 or 3), 2, is_selected and 12 or 8, is_selected and 0.42 or 0.62, is_selected and 0.86 or 0.66, is_selected and 0.62 or 0.70, 1, true)
  end
  local cursor_x = strip_x + clamp((cursor_pos - first_pos) / span, 0, 1) * strip_w
  draw_rect(cursor_x - 1, strip_y, 2, strip_h, 0.96, 0.74, 0.30, 1, true)
  draw_text(string.format("%.2fs", cursor_pos), strip_x, strip_y - 14, 0.58, 0.62, 0.66)

  local button_y = y + h - 40
  if draw_button("< Pair", x + 8, button_y, 62, 28, false, #markers < 2) then
    shift_pair(-1)
  end
  if draw_button("Set Selection", x + 76, button_y, 102, 28, true, #markers < 2) then
    set_time_selection_from_markers(start_marker, end_marker)
  end
  if draw_button("Pair >", x + 186, button_y, 62, 28, false, #markers < 2) then
    shift_pair(1)
  end
  if draw_button("1-3", x + 256, button_y, 52, 28, false, #markers < 3) then
    select_pair_by_index(1, 3)
  end
end

local function draw_settings()
  draw_input("ambi_host", "Ambi host", state.ambi_host, 24, 72, 170)
  draw_input("ambi_port", "Ambi port", state.ambi_port, 214, 72, 100)
  draw_input("steps_per_second", "Steps/sec", state.steps_per_second, 334, 72, 100)
  draw_input("marker_tolerance", "Marker tol", state.marker_tolerance, 454, 72, 100)
  draw_input("stop_tail_sec", "Stop tail", state.stop_tail_sec, 574, 72, 100)

  draw_label("Curve", 24, 132)
  state.curve = draw_radio("Smoothstep", state.curve, "smoothstep", 24, 154)
  state.curve = draw_radio("Linear", state.curve, "linear", 154, 154)
  state.curve = draw_radio("Parabol", state.curve, "parabolic", 24, 184)
  state.curve = draw_radio("Expon", state.curve, "exponential", 154, 184)
  state.curve = draw_radio("Polar", state.curve, "polar", 254, 184)
  state.polyphonic = draw_toggle("Polyphonic all indexes", state.polyphonic, 24, 254)

  draw_label("Automation", 394, 132)
  state.automation_mode = draw_radio("Latch", state.automation_mode, 4, 394, 154)
  state.automation_mode = draw_radio("Write", state.automation_mode, 3, 394, 184)

  state.auto_arm_envelopes = draw_toggle("Auto-arm AmbiEncoder envelopes", state.auto_arm_envelopes, 524, 150)
  state.restore_automation_mode = draw_toggle("Restore automation mode", state.restore_automation_mode, 524, 180)

  draw_input("python_cmd", "Python", state.python_cmd, 24, 204, 350)
  state.stop_at_selection_end = draw_toggle("Stop at selection end", state.stop_at_selection_end, 24, 282)
  state.go_to_next_marker_on_stop = draw_toggle("Next pair after stop", state.go_to_next_marker_on_stop, 24, 310)
end

local function draw_actions()
  if draw_button("Send pair", 24, 530, 110, 42, false, state.recording) then
    send_only()
  end
  if draw_button("Send series", 146, 530, 120, 42, false, state.recording) then
    send_series()
  end
  if draw_button("Record pair", 278, 530, 120, 42, true, state.recording) then
    start_record()
  end
  if draw_button("Record series", 410, 530, 130, 42, true, state.recording) then
    start_record_series()
  end
  local stop_label = "Stop transport"
  if state.recording then
    stop_label = state.recording_series and "Stop series" or "Stop recording"
  elseif state.osc_preview_active then
    stop_label = "Stop preview"
  end
  if draw_button(stop_label, 552, 530, 110, 42, false, false) then
    stop_record_now()
  end
  if draw_button("XYZ score", 674, 530, 82, 42, false, state.recording) then
    build_xyz_score()
  end
end

local function draw()
  draw_rect(0, 0, ui.w, ui.h, 0.07, 0.08, 0.09, 1, true)
  draw_text_sized("Ambi Motion Marker GUI", 24, 18, 18, 0.95, 0.96, 0.96)
  draw_text("Send marker pairs over OSC or record them as AmbiEncoder automation", 24, 46, 0.62, 0.66, 0.70)

  if state.recording then
    draw_rect(ui.w - 130, 20, 104, 26, 0.42, 0.16, 0.14, 1, true)
    draw_rect(ui.w - 130, 20, 104, 26, 0.70, 0.36, 0.32, 1, false)
    draw_text(state.recording_series and "SERIES REC" or "RECORDING", ui.w - 120, 26, 0.98, 0.86, 0.82)
  elseif state.osc_preview_active then
    draw_rect(ui.w - 130, 20, 104, 26, 0.18, 0.34, 0.32, 1, true)
    draw_rect(ui.w - 130, 20, 104, 26, 0.34, 0.70, 0.62, 1, false)
    draw_text("PREVIEW", ui.w - 106, 26, 0.82, 0.96, 0.90)
  end

  draw_settings()
  draw_preview(24, 342, 350, 164)
  draw_marker_pair_list(394, 204, 338, 242)
  draw_actions()
  draw_status_bar()
end

local function loop()
  ui.mx, ui.my = gfx.mouse_x, gfx.mouse_y
  ui.mouse_down = (gfx.mouse_cap & 1) == 1
  ui.char = gfx.getchar()

  if ui.char < 0 then
    if state.recording then
      finish_record()
    elseif state.osc_preview_active then
      stop_worker_motion()
      finish_osc_preview(false)
    else
      stop_worker_motion()
    end
    return
  end

  handle_text_input()
  maintain_worker()
  poll_worker_status(false)
  monitor_record()
  monitor_osc_preview()
  draw()

  ui.last_mouse_down = ui.mouse_down
  gfx.update()
  reaper.defer(loop)
end

ensure_worker()
poll_worker_status(true)
if state.worker_state ~= "offline" and state.worker_version ~= EXPECTED_WORKER_VERSION then
  request_worker_restart()
elseif state.worker_state == "error" then
  write_worker_command({
    { "job_id", next_worker_job_id() },
    { "command", "clear" },
  })
end
gfx.init(SCRIPT_NAME, ui.w, ui.h, 0)
gfx.setfont(1, "Arial", 14)
loop()
