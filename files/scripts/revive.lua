local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local meta_leveling = dofile_once("mods/resurrection/files/scripts/meta_leveling.lua") ---@type meta_leveling
local shared_revive = dofile_once("mods/resurrection/files/scripts/shared/revive.lua") ---@type shared_revive

---@class revive
local revive = {
  shared = shared_revive,
  level_on_revive_gain = 0
}

---@param amount integer
function revive:_GainReviveOnLevelUp(amount)
  self.shared:AddRevive(amount)
  self.level_on_revive_gain = meta_leveling:current_level()
  utils:GlobalSetTypedValue(const.globals.level_on_revive_gain, self.level_on_revive_gain)
end

function revive:UpdateRevives()
  if self.shared.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
    local available_lv = meta_leveling:current_level() - self.level_on_revive_gain
    if available_lv >= utils:GetModSetting("ml_revive_levels") then
      self:_GainReviveOnLevelUp(1)
    end
  end
end

return revive
