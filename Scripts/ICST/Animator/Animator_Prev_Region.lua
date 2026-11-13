-- @description ICST Animator: zur vorherigen Region springen
local script_dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local C = dofile(script_dir .. "/lib/animator_common.lua")

local cur = reaper.GetCursorPosition()
local target
for _, it in ipairs(C.collect_regions_markers()) do
  if it.type == "region" and it.start < cur - 0.001 then target = it.start end
end
if target then
  reaper.SetEditCurPos(target, true, false)
else
  reaper.SetEditCurPos(0, true, false)
end
