local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils

---@class shared_revive
local revive = {
  _count = nil, -- Important to keep it nil, only nil values are not written to global with the GetOrSet func
  respawn_system = nil
}

function revive:Init()
  self.respawn_system = utils:GlobalGetOrSetTypedValue(const.globals.respawn_system,
    utils:GetModSetting("respawn_system"))

  local revive_count = self:GetReviveCount()
  if not revive_count then
    -- Make sure mod settings is returning integers
    if self.respawn_system == const.RESPAWN_SYSTEM.LIMITED then
      self:_SetReviveCount(utils:GetModSetting("limited_revives"))
    elseif self.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
      self:_SetReviveCount(utils:GetModSetting("ml_starting_revives"))
    end
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
  local ret = utils:GlobalGetOrSetTypedValue(const.globals.revive_count, self._count)
  if ret then
    return ret
  end
  return ret
end

return revive
