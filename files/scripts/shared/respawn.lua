local defs = dofile_once("mods/resurrection/files/scripts/defs.lua") ---@type defs
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils

---@class shared_respawn
local respawn = {
  count = nil,
  respawn_system = nil
}

function respawn:Init()
  self.respawn_system = utils:GlobalGetOrSetTypedValue("respawn_system", utils:GetModSetting("respawn_system"))
  if self.respawn_system == defs.RESPAWN_SYSTEM.LIMITED then
    self:_SetRespawnCount(math.floor(utils:GetModSetting("limited_respawns")))
  elseif self.respawn_system == defs.RESPAWN_SYSTEM.META_LEVELING then
    self:_SetRespawnCount(math.floor(utils:GetModSetting("ml_starting_respawns")))
  end
end

---@param value integer|nil
function respawn:_SetRespawnCount(value)
  self.count = value
  utils:GlobalSetTypedValue("respawns", self.count)
end

---@param amount integer
function respawn:AddRespawn(amount)
  self.count = self:GetRespawnCount() + amount
  utils:GlobalSetTypedValue("respawns", self.count)
end

---@return integer|nil
function respawn:GetRespawnCount()
  return math.floor(utils:GlobalGetOrSetTypedValue("respawns", self.count))
end

return respawn
