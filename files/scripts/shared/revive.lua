local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils

---@class shared_revive
local revive = {
  _count = nil,
  respawn_system = nil
}

function revive:Init()
  self.respawn_system = utils:GlobalGetOrSetTypedValue(const.globals.respawn_system,
    utils:GetModSetting("respawn_system"))
  if self.respawn_system == const.RESPAWN_SYSTEM.LIMITED then
    self:_SetReviveCount(math.floor(utils:GetModSetting("limited_revives")))
  elseif self.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
    self:_SetReviveCount(math.floor(utils:GetModSetting("ml_starting_revives")))
  end
end

---@param value integer|nil
function revive:_SetReviveCount(value)
  self._count = value
  utils:GlobalSetTypedValue(const.globals.revive_count, self._count)
end

---@param amount integer
function revive:AddRevive(amount)
  self._count = self:GetReviveCount() + amount
  utils:GlobalSetTypedValue(const.globals.revive_count, self._count)
end

---@return integer|nil
function revive:GetReviveCount()
  return math.floor(utils:GlobalGetOrSetTypedValue(const.globals.revive_count, self._count))
end

return revive
