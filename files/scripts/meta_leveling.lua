if not ModIsEnabled("meta_leveling") then
  return nil
end

local MLP = dofile_once("mods/meta_leveling/files/scripts/meta_leveling_public.lua")

---@class meta_leveling
local meta_leveling = { public = MLP }

---@return number
function meta_leveling:current_exp()
  return self.public.exp:current()
end

---You gain levels on picking a reward.
---@return integer
function meta_leveling:current_level()
  return self.public.get:global_number(MLP.const.globals.current_level, 1)
end

return meta_leveling
