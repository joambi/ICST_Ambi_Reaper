-- @description ICST Ambi: HOA-FX-Spur mit IEM-Effekten (SceneRotator, MultiEQ, FdnReverb, DualDelay, ...)
-- Menue: Effekte anklicken (Reihenfolge der Klicks = Reihenfolge in der Kette), dann "Spur anlegen".
-- Die Spur hat (Ordnung+1)^2 Kanaele. Danach mit Auto-Route verbinden.
local dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local A = dofile(dir .. "/lib/ambi_common.lua")

-- key, Anzeigename, Hinweis
local FX = {
  { "SceneRotator",          "SceneRotator (Szene drehen / kippen)" },
  { "MultiEQ",               "MultiEQ (Equalizer)" },
  { "GranularEncoder",       "GranularEncoder (Granular, Mono/Stereo -> Ambisonics)" },
  { "FdnReverb",             "FdnReverb (Hall)" },
  { "DualDelay",             "DualDelay (Delay)" },
  { "OmniCompressor",        "OmniCompressor" },
  { "MultiBandCompressor",   "MultiBandCompressor" },
  { "DirectionalCompressor", "DirectionalCompressor" },
  { "EnergyVisualizer",      "EnergyVisualizer (Anzeige)" },
  { "ToolBox",               "ToolBox (Flip / Gewichtung / Mono)" },
}
local PRESETS = {
  { "Preset: Rotation + EQ",                { "SceneRotator", "MultiEQ" } },
  { "Preset: Hall + EQ",                    { "FdnReverb", "MultiEQ" } },
  { "Preset: Raum-Effekte (Rot, EQ, Delay, Hall, Kompressor)",
                                            { "SceneRotator", "MultiEQ", "DualDelay", "FdnReverb", "OmniCompressor" } },
}

local order = A.ask_order(); if not order then return end
local nch = A.nchan(order)

-- gespeicherte Auswahl (Komma-Liste)
local sel = {}
for k in A.get("hoafx_sel", "SceneRotator,MultiEQ"):gmatch("[^,]+") do sel[#sel + 1] = k end

local function index_of(k) for i, v in ipairs(sel) do if v == k then return i end end end

local function build_menu()
  local m, map = {}, {}
  local function add(label, action) m[#m + 1] = label; map[#map + 1] = action end
  for _, p in ipairs(PRESETS) do add(p[1], { preset = p[2] }) end
  add("Auswahl leeren", { clear = true })
  m[#m + 1] = ""   -- Trenner (zaehlt nicht als Eintrag)
  for _, f in ipairs(FX) do
    local i = index_of(f[1])
    add((i and "!" or "") .. f[2] .. (i and ("  [" .. i .. "]") or ""), { toggle = f[1] })
  end
  m[#m + 1] = ""
  add("Spur anlegen (" .. #sel .. " Effekte)", { go = true })
  add("Abbrechen", { cancel = true })
  return table.concat(m, "|"), map
end

local function show(menu)
  local x, y = reaper.GetMousePosition()
  gfx.init("ICST HOA FX", 0, 0, 0, x, y)

  gfx.x, gfx.y = 0, 0
  local r = gfx.showmenu(menu)
  gfx.quit()
  return r
end

while true do
  local menu, map = build_menu()
  local r = show(menu)
  local act = map[r]
  if not act or act.cancel then return end
  if act.preset then sel = {}; for _, k in ipairs(act.preset) do sel[#sel + 1] = k end
  elseif act.clear then sel = {}
  elseif act.toggle then
    local i = index_of(act.toggle)
    if i then table.remove(sel, i) else sel[#sel + 1] = act.toggle end
  elseif act.go then
    if #sel == 0 then A.msg("Bitte mindestens einen Effekt waehlen.") else break end
  end
end

A.set("hoafx_sel", table.concat(sel, ","))

reaper.Undo_BeginBlock()
local tr = A.new_track("HOA_FX", nch)
A.color_track(tr, "fx")
local missing, gran = {}, false
for _, k in ipairs(sel) do
  local fx = A.add_fx(tr, { "VST3: " .. k .. " (IEM)", "VST3: " .. k })
  if not fx then missing[#missing + 1] = k end
  if k == "GranularEncoder" then gran = true end
end
reaper.SetOnlyTrackSelected(tr)
reaper.TrackList_AdjustWindows(false)
reaper.Undo_EndBlock("ICST Ambi: HOA-FX-Spur anlegen", -1)

local note = {}
if #missing > 0 then
  note[#note + 1] = "Nicht gefunden: " .. table.concat(missing, ", ") ..
    "\nIEM-Plugins liegen in Effects/VST3. Ggf. REAPER neu starten oder die VST-Liste neu scannen (Optionen > Einstellungen > Plug-ins > VST)."
end
if gran then
  note[#note + 1] = "GranularEncoder erzeugt Ambisonics aus einem Mono-/Stereosignal. Er gehoert an den Anfang einer Kette mit normaler Quelle."
end
if #note > 0 then A.msg(table.concat(note, "\n\n")) end
