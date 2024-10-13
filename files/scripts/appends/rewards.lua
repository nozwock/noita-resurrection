---@diagnostic disable: undefined-global
local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local shared_revive = dofile_once("mods/resurrection/files/scripts/shared/revive.lua") ---@type shared_revive
-- dofile_once("mods/meta_leveling/files/scripts/classes/private/rewards.lua")

local function ToAddOnSetting()
  local to_add = ModSettingGet(utils:ResolveModSettingId("ml_rewards"))
  if to_add and shared_revive.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
    return to_add
  end
  return false
end

---@param key string
---@param default number
local function CreateProbabilityFnFromSettings(key, default)
  return function()
    local chance = ModSettingGet(utils:ResolveModSettingId(key))
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
    border_color = ML.rewards_deck.borders.uncommon,
    probability = CreateProbabilityFnFromSettings("ml_reward_revive_chance", 0.3),
    custom_check = ToAddOnSetting,
    fn = function()
      shared_revive:AddRevive(1)
    end
  }
}

shared_revive:Init()

ML.rewards_deck:add_rewards(rewards)
