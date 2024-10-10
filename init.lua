dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")
dofile("data/scripts/status_effects/status_list.lua")
dofile("mods/resurrection/files/scripts/locale.lua")
local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local input = dofile_once("mods/resurrection/files/scripts/input.lua") ---@type input
local tasks = dofile_once("mods/resurrection/files/scripts/tasks.lua") ---@type tasks
local revive = dofile_once("mods/resurrection/files/scripts/revive.lua") ---@type revive
local gui = dofile_once("mods/resurrection/files/scripts/gui.lua") ---@type gui_mod
local meta_leveling = dofile_once("mods/resurrection/files/scripts/meta_leveling.lua") ---@type meta_leveling


local ONE_HP = 0.04
local respawn_position = {
  x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
  y = tonumber(MagicNumbersGetValue(
    "DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85

local death_count = 0
local final_kill_player_flag = false
local out_of_revives = false


local function GetPlayer()
  return EntityGetWithTag("player_unit")[1] or EntityGetWithTag("polymorphed_player")[1]
end

---@param id entity_id
local function GetFirstPolyGameEffect(id)
  local ids = EntityGetAllChildren(id)
  if not ids then return end
  for _, id_ in ipairs(ids) do
    if #EntityGetTags(id_) == 0 and EntityGetFirstComponent(id_, "GameEffectComponent") then
      return EntityGetFirstComponent(id_, "GameEffectComponent")
    end
  end
end

local CessatePlayerInfo = {
  DEFER_REPEAT = 1
}

---You must wait a frame after running the returned clousure to de-polymorph.
local function CessatePlayer()
  local poly_player_id = EntityGetWithTag("polymorphed_player")[1]
  if poly_player_id then
    local effect = GetFirstPolyGameEffect(poly_player_id)
    if not effect then return end
    if ComponentGetValue2(effect, "frames") == -1 then return end -- Ignore if perma polymorphed_player
    ComponentSetValue2(effect, "frames", 1)
    return nil, CessatePlayerInfo.DEFER_REPEAT
  end

  -- local player_id = GetPlayer()
  local player_id = EntityGetWithTag("player_unit")[1]
  if not player_id then return end
  --- Compatibility with mods that remove polymorphism for player
  local poly_compat = EntityHasTag(player_id, "polymorphable_NOT")
  EntityRemoveTag(player_id, "polymorphable_NOT")
  GetGameEffectLoadTo(player_id, "POLYMORPH_CESSATION", true)

  poly_player_id = EntityGetWithTag("polymorphed_cessation")[1]
  if not poly_player_id then return end

  local effect = GetFirstPolyGameEffect(poly_player_id)
  if not effect then return end

  ComponentSetValue2(effect, "frames", -2) -- Any -ve value but not -1 for infinite duration with perma polymorph
  GameAddFlagRun("msg_gods_looking")
  GameAddFlagRun("msg_gods_looking2")

  return function()
    if poly_compat then
      tasks:AddDeferredTask(0, function()
        local player_id = GetPlayer()
        EntityAddTag(player_id, "polymorphable_NOT")
      end)
    end
    ComponentSetValue2(effect, "frames", 1)
    GameRemoveFlagRun("msg_gods_looking")
    GameRemoveFlagRun("msg_gods_looking2")
  end
end

---@param amount integer
---@param x integer
---@param y integer
local function DropGold(amount, x, y)
  local gold_nugget_amounts = { 200000, 10000, 1000, 200, 50, 10, 1 }
  local gold_nuggets = {
    [200000] = "data/entities/items/pickup/goldnugget_200000.xml",
    [10000] = "data/entities/items/pickup/goldnugget_10000.xml",
    [1000] = "data/entities/items/pickup/goldnugget_1000.xml",
    [200] = "data/entities/items/pickup/goldnugget_200.xml",
    [50] = "data/entities/items/pickup/goldnugget_50.xml",
    [10] = "data/entities/items/pickup/goldnugget_10.xml",
    [1] = "data/entities/items/pickup/goldnugget.xml",
  }
  local to_drop = {}

  while amount ~= 0 do
    for _, v in ipairs(gold_nugget_amounts) do
      if v <= amount then
        table.insert(to_drop, v)
        amount = amount - v
        break
      end
    end
  end

  for _, v in ipairs(to_drop) do
    EntityLoad(gold_nuggets[v], x, y)
  end
end

local function IsReviveAvailable()
  if revive.shared.respawn_system == const.RESPAWN_SYSTEM.UNLIMITED then
    return true
  else
    return math.floor(revive.shared:GetReviveCount() - death_count) > 0
  end
end

---@param damage_model component_id
local function KillPlayer(damage_model)
  ComponentSetValue2(damage_model, "hp", 0)
  ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", true)
  ComponentSetValue2(damage_model, "kill_now", true)
  final_kill_player_flag = true
end

---@param damage_model component_id
local function RemoveArtificialDeathFlags(damage_model)
  ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", false)
  ComponentSetValue2(damage_model, "kill_now", false)
end

local function PlayerDied()
  death_count = death_count + 1
  utils:GlobalSetTypedValue(const.globals.death_count, death_count)
end

function OnModInit()
  dofile_once("mods/resurrection/files/scripts/on_init/appends.lua")
end

function OnPausedChanged()
  utils:ClearModSettingsCache()
end

function OnWorldInitialized()
  ---@diagnostic disable:cast-local-type,assign-type-mismatch
  -- It might be fine to allow for changing respawn system on world load, and not just per run
  revive.shared:Init()
  respawn_position = utils:GlobalGetTypedValue(const.globals.respawn_position, respawn_position) ---@type table
  death_count = utils:GlobalGetOrSetTypedValue(const.globals.death_count, death_count)
  revive.level_on_revive_gain = utils:GlobalGetOrSetTypedValue(const.globals.level_on_revive_gain,
    revive.level_on_revive_gain)
  ---@diagnostic enable:cast-local-type,assign-type-mismatch

  if meta_leveling == nil and revive.shared.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
    tasks:AddDeferredTask(60, function()
      GamePrint("Meta Leveling is not enabled, falling back to the Unlimited Respawn System.")
    end)
    revive.shared.respawn_system = const.RESPAWN_SYSTEM.UNLIMITED -- fallback
  end

  gui.respawn_gui = gui:CreateRespawnGui(nil, function()
    local player_id = GetPlayer()
    if not player_id then
      utils:ErrLog("failed to get player_id during respawn")
      return
    end
    local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
    if not damage_model then
      utils:ErrLog("failed to get DamageModelComponent during respawn")
      return
    end

    local game_effect = GetGameEffectLoadTo(player_id, "BLINDNESS", true)
    if game_effect then
      ComponentSetValue2(game_effect, "frames", 120)
    end

    ComponentSetValue2(damage_model, "hp",
      ComponentGetValue2(damage_model, "max_hp") * utils:GetModSetting("respawn_health") / 100)
    GameRegenItemActionsInPlayer(player_id)

    local player_x, player_y = EntityGetTransform(player_id)
    EntitySetTransform(player_id, respawn_position.x, respawn_position.y)
    -- For clearing some area around the respawn point
    EntityLoad("data/entities/misc/matter_eater.xml", respawn_position.x, respawn_position.y)

    for _, effect in pairs(status_effects) do
      EntityRemoveStainStatusEffect(player_id, effect.id)
    end
    ComponentSetValue2(damage_model, "mIsOnFire", false)

    local wallet = EntityGetFirstComponent(player_id, "WalletComponent")
    local money, money_drop = 0, 0
    if wallet then
      money = ComponentGetValue2(wallet, "money")
      money_drop = math.floor(money * utils:GetModSetting("gold_drop"))
    end

    if wallet and money_drop > 0 then
      tasks:AddDeferredTask(0, function()
        ComponentSetValue2(wallet, "money", money - money_drop)
        DropGold(money_drop, player_x, player_y)
        GamePrint(string.format(Locale("$gold_drop_msg"), money_drop))
      end)
    end

    if not IsReviveAvailable() then
      RemoveArtificialDeathFlags(damage_model)
      out_of_revives = true
    end
  end, function()
    local player_id = GetPlayer()
    if not player_id then
      utils:ErrLog("failed to get player_id during game over")
      return
    end
    local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
    if not damage_model then
      utils:ErrLog("failed to get DamageModelComponent during game over")
      return
    end

    KillPlayer(damage_model)
  end)
end

---@diagnostic disable-next-line: param-type-mismatch
local hold_respawn_point_handler = input:CreateHoldKeyDownHandler(utils:GetModSetting("respawn_point"))

function OnWorldPreUpdate()
  gui:StartFrame()

  tasks:ProcessDeferredTasks()
  hold_respawn_point_handler:Update()

  hold_respawn_point_handler.key_code = utils:GetModSetting("respawn_point")
  ---@diagnostic disable-next-line: param-type-mismatch
  if hold_respawn_point_handler:HeldOnceFor(math.floor(utils:GetModSetting("respawn_point_hold_time"))) then
    local player_id = GetPlayer()
    if player_id ~= nil then
      local x, y, _ = EntityGetTransform(player_id)
      respawn_position.x = x
      respawn_position.y = y

      utils:GlobalSetTypedValue(const.globals.respawn_position, respawn_position)

      EntityLoad("mods/resurrection/files/entities/particles/image_emitters/small_effect.xml", x, y)
      GamePrint(Locale("$respawn_set_msg"))
    end
  end

  local new_id = gui:IdFactory()

  local player_id = GetPlayer()
  if player_id then
    gui:DrawHUDStats(new_id, death_count)
  end
  if gui.draw_respawn_gui then
    gui.respawn_gui:Draw(new_id)
    return
  end

  if not player_id then return end
  local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
  if not damage_model then return end

  revive:UpdateRevives()

  -- Revives get modified on the ML side too
  if revive.shared.respawn_system ~= const.RESPAWN_SYSTEM.UNLIMITED and not final_kill_player_flag then
    if IsReviveAvailable() then
      if out_of_revives then
        ComponentSetValue2(damage_model, "kill_now", false)
        out_of_revives = false
      end
    elseif not out_of_revives then
      RemoveArtificialDeathFlags(damage_model)
      out_of_revives = true
    end
  end

  if GameHasFlagRun("ending_game_completed") then
    RemoveArtificialDeathFlags(damage_model)
    final_kill_player_flag = true
  end

  if not out_of_revives and not final_kill_player_flag then
    ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", true)
  end
  if ComponentGetValue2(damage_model, "hp") >= ONE_HP or ComponentGetValue2(damage_model, "kill_now") or final_kill_player_flag or out_of_revives then return end

  PlayerDied()

  local remove_cessation, info = CessatePlayer()
  if info == CessatePlayerInfo.DEFER_REPEAT then
    tasks:AddDeferredTask(0, function()
      local remove_cessation = CessatePlayer()
      gui.respawn_gui.remove_cessation = remove_cessation
    end)
  elseif not remove_cessation then
    utils:ErrLog("Failed to cessate the player entity.")
  end
  gui.respawn_gui.remove_cessation = remove_cessation

  gui.draw_respawn_gui = true
end
