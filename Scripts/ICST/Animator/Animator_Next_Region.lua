-- @description ICST Animator: zur naechsten Region springen
local script_dir = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local C = dofile(script_dir .. "/lib/animator_common.lua")

local cur = reaper.GetCursorPosition()
for _, it in ipairs(C.collect_regions_markers()) do
  if it.type == "region" and it.start > cur + 0.001 then
    reaper.SetEditCurPos(it.start, true, false)
    return
  end
end
