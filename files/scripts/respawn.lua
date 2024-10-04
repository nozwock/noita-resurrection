local defs = dofile_once("mods/resurrection/files/scripts/defs.lua") ---@type defs
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local meta_leveling = dofile_once("mods/resurrection/files/scripts/meta_leveling.lua") ---@type meta_leveling
local shared_respawn = dofile_once("mods/resurrection/files/scripts/shared/respawn.lua") ---@type shared_respawn

---@class respawn
local respawn = {
  shared = shared_respawn,
  level_on_respawn_gain = 1
}

---@param amount integer
function respawn:GainRespawnOnLevelUp(amount)
  self.shared:AddRespawn(amount)
  self.level_on_respawn_gain = meta_leveling:current_level()
  utils:GlobalSetTypedValue("level_on_respawn_gain", self.level_on_respawn_gain)
end

function respawn:UpdateRespawns()
  if self.shared.respawn_system == defs.RESPAWN_SYSTEM.META_LEVELING then
    local available_lv = meta_leveling:current_level() - self.level_on_respawn_gain
    if available_lv >= utils:GetModSetting("ml_respawn_levels") then
      self:GainRespawnOnLevelUp(1)
    end
  end
end

return respawn
