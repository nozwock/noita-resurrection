---@diagnostic disable: undefined-global
local defs = dofile_once("mods/resurrection/files/scripts/defs.lua") ---@type defs
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local shared_respawn = dofile_once("mods/resurrection/files/scripts/shared/respawn.lua") ---@type shared_respawn
-- dofile_once("mods/meta_leveling/files/scripts/classes/private/rewards.lua")

local function ToAddOnSetting()
  local to_add = utils:GetModSetting("ml_rewards")
  utils:Log("ToAddOnSetting:", tostring(to_add),
    tostring(shared_respawn.respawn_system == defs.RESPAWN_SYSTEM.META_LEVELING))
  if to_add and shared_respawn.respawn_system == defs.RESPAWN_SYSTEM.META_LEVELING then
    return to_add
  end
  return false
end

---@param key string
---@param default number
local function CreateProbabilityFnFromSettings(key, default)
  return function()
    local chance = utils:GetModSetting(key)
    utils:Log(key, tostring(chance))
    if chance then
      return chance
    end
    return default
  end
end

---@type ml_rewards
local rewards = {
  {
    id = "resurrection_revive",
    ui_name = "$resurrection_revive_reward",
    description = "$resurrection_revive_reward_desc",
    ui_icon = "mods/resurrection/files/gfx/rewards/plus_with_angel_wings.png",
    sound = MLP.const.sounds.refresh,
    probability = CreateProbabilityFnFromSettings("ml_reward_revive_chance", 0.6),
    custom_check = ToAddOnSetting,
    fn = function()
      shared_respawn:AddRespawn(1)
    end
  }
}

shared_respawn:Init()

ML.rewards_deck:add_rewards(rewards)
