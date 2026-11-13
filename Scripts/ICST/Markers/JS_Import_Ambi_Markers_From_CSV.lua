-- @description Import Ambi markers from XYZ CSV
-- @author JS / Codex
-- @version 1.0
-- @about
--   Imports project markers from a CSV file and converts XYZ or AED
--   coordinates into Ambi marker names in the existing
--   "ambi <source> a=<az> e=<el> d=<dist>" format used by the OSC Ambi
--   workflow.
--
--   Supported CSV formats:
--     time,index,x,y,z
--     time,index,source,x,y,z
--     time,index,source,azimuth,elevation,distance
--     #,Name,Start
--
--   Optional header names:
--     time | position | seconds
--     index | marker | marker_index
--     source | src
--     x, y, z
--
--   Rows with the same time/index are merged into one REAPER marker and
--   written as multiple ambi entries separated by " | ".

local SCRIPT_NAME = "Import Ambi Markers From CSV"

local function msg(text)
  reaper.ShowConsoleMsg(tostring(text) .. "\n")
end

local function trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_csv_line(line, separator)
  local result = {}
  local current = {}
  local in_quotes = false

  local index = 1
  while index <= #line do
    local char = line:sub(index, index)
    if char == '"' then
      local next_char = line:sub(index + 1, index + 1)
      if in_quotes and next_char == '"' then
        current[#current + 1] = '"'
        index = index + 1
      else
        in_quotes = not in_quotes
      end
    elseif char == separator and not in_quotes then
      result[#result + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = char
    end
    index = index + 1
  end

  result[#result + 1] = table.concat(current)
  for i = 1, #result do
    result[i] = trim(result[i])
  end
  return result
end

local function normalize_header(value)
  local normalized = trim(value):lower():gsub("[%s%-]+", "_")
  if normalized == "position" or normalized == "seconds" then return "time" end
  if normalized == "marker" or normalized == "marker_index" then return "index" end
  if normalized == "src" then return "source" end
  return normalized
end

local function detect_separator(header_line)
  local comma_count = select(2, header_line:gsub(",", ""))
  local semicolon_count = select(2, header_line:gsub(";", ""))
  if semicolon_count > comma_count then
    return ";"
  end
  return ","
end

local function xyz_to_aed(source, x, y, z)
  local distance = math.sqrt((x * x) + (y * y) + (z * z))
  if distance <= 0.000001 then
    return {
      source = source,
      azimuth = 0.0,
      elevation = 0.0,
      distance = 0.0,
    }
  end

  local azimuth = math.deg(math.atan2(x, y))
  local elevation = math.deg(math.asin(math.max(-1.0, math.min(1.0, z / distance))))
  return {
    source = source,
    azimuth = azimuth,
    elevation = elevation,
    distance = distance,
  }
end

local function marker_entry_from_xyz(source, x, y, z)
  local point = xyz_to_aed(source, x, y, z)
  return string.format(
    "ambi %s a=%.3f e=%.3f d=%.3f",
    tostring(point.source),
    point.azimuth,
    point.elevation,
    point.distance
  )
end

local function marker_entry_from_aed(source, azimuth, elevation, distance)
  return string.format(
    "ambi %s a=%.3f e=%.3f d=%.3f",
    tostring(source),
    tonumber(azimuth) or 0,
    tonumber(elevation) or 0,
    tonumber(distance) or 0
  )
end

local function parse_start_time(value)
  local normalized = trim(value or "")
  if normalized == "" then return nil end

  local direct = tonumber(normalized)
  if direct then return direct end

  local parts = {}
  for part in normalized:gmatch("[^%.]+") do
    parts[#parts + 1] = part
  end

  if #parts >= 2 then
    local merged = parts[1] .. "." .. table.concat(parts, "", 2)
    local as_seconds = tonumber(merged)
    if as_seconds then return as_seconds end
  end

  return nil
end

local function parse_marker_index(value)
  local digits = tostring(value or ""):match("(%d+)")
  if not digits then return nil end
  return tonumber(digits)
end

local function finalize_legacy_marker_row(markers, row)
  if not row then return end
  local marker_index = parse_marker_index(row.id)
  local time = parse_start_time(row.start)
  local name = trim((row.name_lines or ""):gsub("[\r\n]+", " | "):gsub("%s*|%s*", " | "))

  if marker_index and time and name ~= "" then
    markers[#markers + 1] = {
      time = time,
      index = marker_index,
      name = name,
    }
  end
end

local function parse_legacy_marker_csv(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "CSV konnte nicht geoeffnet werden:\n" .. tostring(path)
  end

  local header_line = file:read("*l")
  if not header_line or trim(header_line) == "" then
    file:close()
    return nil, "CSV ist leer."
  end

  local markers = {}
  local current = nil

  for line in file:lines() do
    local trimmed = trim(line)
    if trimmed ~= "" then
      local start_id, first_name = line:match("^([Mm]%d+),(.*)$")
      local trailing_name, trailing_start = line:match("^(.*),([^,]+)$")

      if start_id then
        local inline_name = trim(first_name)
        local inline_start = ""
        local maybe_name, maybe_start = first_name:match("^(.*),([^,]+)$")
        if maybe_start and parse_start_time(maybe_start) then
          inline_name = trim(maybe_name)
          inline_start = trim(maybe_start)
        end

        finalize_legacy_marker_row(markers, current)
        current = {
          id = trim(start_id),
          name_lines = inline_name,
          start = inline_start,
        }
      elseif current and trailing_name and trailing_start and parse_start_time(trailing_start) then
        if trim(trailing_name) ~= "" then
          current.name_lines = (current.name_lines ~= "" and (current.name_lines .. "\n") or "") .. trim(trailing_name)
        end
        current.start = trim(trailing_start)
      elseif current then
        current.name_lines = (current.name_lines ~= "" and (current.name_lines .. "\n") or "") .. trimmed
      end
    end
  end

  finalize_legacy_marker_row(markers, current)
  file:close()

  table.sort(markers, function(left, right)
    if math.abs(left.time - right.time) > 0.000001 then
      return left.time < right.time
    end
    return left.index < right.index
  end)

  return markers, nil
end

local function parse_csv(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "CSV konnte nicht geoeffnet werden:\n" .. tostring(path)
  end

  local header_line = file:read("*l")
  if not header_line or trim(header_line) == "" then
    file:close()
    return nil, "CSV ist leer."
  end

  local separator = detect_separator(header_line)
  local header_values = split_csv_line(header_line, separator)
  local header_map = {}
  for column_index, header in ipairs(header_values) do
    header_map[normalize_header(header)] = column_index
  end

  if header_map["#"] and header_map.name and header_map.start then
    file:close()
    return parse_legacy_marker_csv(path)
  end

  local has_time = header_map.time ~= nil
  local has_index = header_map.index ~= nil
  local has_x = header_map.x ~= nil
  local has_y = header_map.y ~= nil
  local has_z = header_map.z ~= nil
  local has_azimuth = header_map.azimuth ~= nil or header_map.a ~= nil or header_map.az ~= nil
  local has_elevation = header_map.elevation ~= nil or header_map.e ~= nil or header_map.el ~= nil
  local has_distance = header_map.distance ~= nil or header_map.d ~= nil or header_map.dist ~= nil or header_map.radius ~= nil

  local is_xyz_format = has_time and has_index and has_x and has_y and has_z
  local is_aed_format = has_time and has_index and has_azimuth and has_elevation and has_distance
  if not (is_xyz_format or is_aed_format) then
    file:close()
    return nil, "CSV must contain either time,index,x,y,z or time,index,source,azimuth,elevation,distance or #,Name,Start"
  end

  local azimuth_column = header_map.azimuth or header_map.a or header_map.az
  local elevation_column = header_map.elevation or header_map.e or header_map.el
  local distance_column = header_map.distance or header_map.d or header_map.dist or header_map.radius

  local grouped = {}
  local order = {}
  local line_number = 1

  for line in file:lines() do
    line_number = line_number + 1
    if trim(line) ~= "" then
      local values = split_csv_line(line, separator)
      local time = tonumber(values[header_map.time] or "")
      local marker_index = tonumber(values[header_map.index] or "")
      local source = trim(values[header_map.source] or "")
      if source == "" then source = "1" end

      local entry = nil
      if is_xyz_format then
        local x = tonumber(values[header_map.x] or "")
        local y = tonumber(values[header_map.y] or "")
        local z = tonumber(values[header_map.z] or "")
        if time and marker_index and x and y and z then
          entry = marker_entry_from_xyz(source, x, y, z)
        end
      elseif is_aed_format then
        local azimuth = tonumber(values[azimuth_column] or "")
        local elevation = tonumber(values[elevation_column] or "")
        local distance = tonumber(values[distance_column] or "")
        if time and marker_index and azimuth and elevation and distance then
          entry = marker_entry_from_aed(source, azimuth, elevation, distance)
        end
      end

      if time and marker_index and entry then
        local key = string.format("%.9f|%d", time, math.floor(marker_index + 0.5))
        if not grouped[key] then
          grouped[key] = {
            time = time,
            index = math.floor(marker_index + 0.5),
            entries = {},
          }
          order[#order + 1] = key
        end
        grouped[key].entries[#grouped[key].entries + 1] = entry
      else
        file:close()
        return nil, string.format("Invalid CSV row %d:\n%s", line_number, line)
      end
    end
  end

  file:close()

  table.sort(order, function(left_key, right_key)
    local left = grouped[left_key]
    local right = grouped[right_key]
    if math.abs(left.time - right.time) > 0.000001 then
      return left.time < right.time
    end
    return left.index < right.index
  end)

  local markers = {}
  for _, key in ipairs(order) do
    local marker = grouped[key]
    markers[#markers + 1] = {
      time = marker.time,
      index = marker.index,
      name = table.concat(marker.entries, " | "),
    }
  end
  return markers, nil
end

local function find_marker_at(time, index)
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  local total_count = marker_count + region_count
  for marker_i = 0, total_count - 1 do
    local ok, is_region, position, _, _, marker_index = reaper.EnumProjectMarkers3(0, marker_i)
    if ok and not is_region then
      if marker_index == index and math.abs(position - time) <= 0.0005 then
        return marker_i
      end
    end
  end
  return nil
end

local function import_markers(markers, replace_existing)
  local created = 0
  local updated = 0

  for _, marker in ipairs(markers) do
    local existing_enum_index = find_marker_at(marker.time, marker.index)
    if existing_enum_index ~= nil and replace_existing then
      reaper.DeleteProjectMarkerByIndex(0, existing_enum_index)
    end
    local ok = reaper.AddProjectMarker2(0, false, marker.time, 0, marker.name, marker.index, 0)
    if ok >= 0 then
      if existing_enum_index ~= nil and replace_existing then
        updated = updated + 1
      else
        created = created + 1
      end
    end
  end

  return created, updated
end

local function choose_csv_path(default_path)
  local file_ok, csv_path = reaper.GetUserFileNameForRead(default_path, "Import Ambi Markers From CSV", ".csv")
  if not file_ok then return nil end
  csv_path = trim(csv_path)
  if csv_path == "" then return nil end
  return csv_path
end

local function import_csv_file(csv_path, replace_existing)
  local markers, err = parse_csv(csv_path)
  if not markers then
    return false, err
  end

  if #markers == 0 then
    return false, "No valid markers found in the CSV."
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if not replace_existing then
    for _, marker in ipairs(markers) do
      if find_marker_at(marker.time, marker.index) ~= nil then
        marker.index = -1
      end
    end
  end

  local created, updated = import_markers(markers, replace_existing)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Import Ambi markers from CSV", -1)

  return true, string.format("Ambi markers imported: %d new, %d replaced.", created, updated)
end

local function main()
  local default_path = "markers_xyz.csv"
  if reaper.GetProjectPathEx then
    local project_path = reaper.GetProjectPathEx(0, "")
    if project_path and project_path ~= "" then
      default_path = project_path .. "/markers_xyz.csv"
    end
  end

  local csv_path = choose_csv_path(default_path)
  if not csv_path then return end

  local ok, replace_value = reaper.GetUserInputs(
    SCRIPT_NAME,
    1,
    "Replace same index/time yes/no",
    "yes"
  )
  if not ok then return end

  local replace_existing = trim(replace_value):lower():match("^y") ~= nil
  local success, summary = import_csv_file(csv_path, replace_existing)
  if not success then
    reaper.MB(summary, SCRIPT_NAME, 0)
    return
  end

  msg(summary)
  reaper.MB(summary, SCRIPT_NAME, 0)
end

if _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS then
  local options = _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS
  local csv_path = options.csv_path or choose_csv_path(options.default_path or "markers_xyz.csv")
  if csv_path then
    local success, summary = import_csv_file(csv_path, options.replace_existing ~= false)
    if options.show_summary ~= false then
      if success then
        reaper.MB(summary, SCRIPT_NAME, 0)
      else
        reaper.MB(summary, SCRIPT_NAME, 0)
      end
    end
    if options.log_summary ~= false then
      msg(summary)
    end
  end
  _G.JS_IMPORT_AMBI_MARKERS_FROM_CSV_OPTIONS = nil
else
  main()
end
