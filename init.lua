dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")
dofile("data/scripts/status_effects/status_list.lua")
dofile("mods/resurrection/files/scripts/locale.lua")
local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local input = dofile_once("mods/resurrection/files/scripts/input.lua") ---@type input
local tasks = dofile_once("mods/resurrection/files/scripts/tasks.lua") ---@type tasks
local respawn = dofile_once("mods/resurrection/files/scripts/respawn.lua") ---@type respawn
local meta_leveling = dofile_once("mods/resurrection/files/scripts/meta_leveling.lua") ---@type meta_leveling


local ONE_HP = 0.04
local respawn_position = {
  x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
  y = tonumber(MagicNumbersGetValue(
    "DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85

local deaths = 0
local gui = GuiCreate()
local draw_respawn_ui = false
local respawn_ui_update = nil

---@return fun():integer
local function IdFactory()
  local id = 100

  return function()
    id = id + 1
    return id
  end
end

---@param gui gui
---@param object_width number
local function CenteredX(gui, object_width)
  local w, _ = GuiGetScreenDimensions(gui)
  return math.floor((w / 2 - object_width / 2) / w * 100)
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param dont_focus? boolean
---@return boolean
---@nodiscard
function IsHoverBoxHovered(id, x, y, width, height, dont_focus)
  local empty = "data/ui_gfx/empty.png"
  if not dont_focus then
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.ForceFocusable)
  end
  GuiZSetForNextWidget(gui, -10000)
  GuiImageNinePiece(gui, id, x, y, width, height, 1, empty, empty)
  return select(3, GuiGetPreviousWidgetInfo(gui))
end

---@param gui gui
---@param new_id fun():integer
---@param x number
---@param y number
---@param death_count integer
local function DeathCounter(gui, new_id, x, y, death_count)
  local death_filename = "mods/resurrection/files/gfx/ui/icon_death.png"
  local tw, th = GuiGetTextDimensions(gui, tostring(death_count), 1, 2, "data/fonts/font_small_numbers.xml")
  local iw, _ = GuiGetImageDimensions(gui, death_filename)
  x = x - (tw + iw + 2) - 4

  GuiLayoutBeginHorizontal(gui, x, y, true)

  GuiImage(gui, new_id(), 0, 0, death_filename, 1, 1, 0, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiColorSetForNextWidget(gui, 1, 1, 1, 0.75)
  GuiText(gui, 2, 0, tostring(death_count), 1, "data/fonts/font_small_numbers.xml")
  if IsHoverBoxHovered(new_id(), x, y, tw + iw + 2, th) then
    GuiTooltip(gui, string.format(Locale("$deaths_tooltip"), death_count), "")
  end

  GuiLayoutEnd(gui)
  return x, y
end

---@param gui gui
---@param new_id fun():integer
---@param x number
---@param y number
---@param respawn_count integer
local function RespawnCounter(gui, new_id, x, y, respawn_count)
  local revive_filename = "mods/resurrection/files/gfx/ui/plus_with_angel_wings.png"
  local tw, th = GuiGetTextDimensions(gui, tostring(respawn_count), 1, 2, "data/fonts/font_small_numbers.xml")
  local iw, _ = GuiGetImageDimensions(gui, revive_filename, 1)
  x = x - (tw + iw + 2) - 4

  GuiLayoutBeginHorizontal(gui, x, y, true)

  GuiImage(gui, new_id(), 0, -1, revive_filename, 1, 1, 0, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiColorSetForNextWidget(gui, 1, 1, 1, 0.75)
  GuiText(gui, 1, 0, tostring(respawn_count), 1, "data/fonts/font_small_numbers.xml")
  if IsHoverBoxHovered(new_id(), x, y, tw + iw + 2, th) then
    GuiTooltip(gui, string.format(Locale("$revives_tooltip"), respawn_count), "")
  end

  GuiLayoutEnd(gui)
  return x, y
end

local function DrawStats(gui, new_id)
  local w, _ = GuiGetScreenDimensions(gui)
  local x, y = w - 38, 12
  if respawn.shared.respawn_system ~= const.RESPAWN_SYSTEM.UNLIMITED then
    x, y = RespawnCounter(gui, new_id, x, y, respawn.shared.GetRespawnCount(respawn.shared) - deaths)
    x = x - 1
  end
  DeathCounter(gui, new_id, x, y, deaths)
end

---`y` is percent based.
---@param gui gui
---@param new_id fun():integer
---@param y number
---@param title string
local function GuiDecoratedTitle(gui, new_id, y, title)
  title = string.upper(title)

  local edge_w, _ = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_left.png", 1)
  local middle_w, _ = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_middle.png", 1)
  local text_w, _ = GuiGetTextDimensions(gui, title, 1, 2, "data/fonts/font_pixel_huge.xml")

  local padding_scale = 6
  local middle_scale = text_w / middle_w
  local decor_w = edge_w * 2 + middle_w * (middle_scale + padding_scale * 2)

  local w, h = GuiGetScreenDimensions(gui)
  local decor_x = math.floor(w / 2 - decor_w / 2)
  local text_x = math.floor(w / 2 - text_w / 2)
  y = h * y / 100

  GuiLayoutBeginHorizontal(gui, decor_x, y, true, 0, 0)
  GuiImage(gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_left.png", 1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_middle.png", 1, middle_scale + padding_scale * 2,
    1, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_right.png",
    1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiLayoutEnd(gui)

  GuiLayoutBeginVertical(gui, text_x, y, true)
  GuiText(gui, 0, 5, title, 1, "data/fonts/font_pixel_huge.xml")
  GuiLayoutEnd(gui)
end

---@param gui gui
---@param disable_cessation function
---@param on_ok function
---@param on_cancel function
local function CreateRespawnGui(gui, disable_cessation, on_ok, on_cancel)
  local hovered = {}
  local hover_prefix = ">"

  return function(new_id)
    if not draw_respawn_ui then
      return
    end

    local id

    GuiAnimateBegin(gui)
    GuiAnimateAlphaFadeIn(gui, new_id(), 0.04, 0.1, false)

    GuiZSet(gui, -1000)
    GuiImage(gui, new_id(), 0, 0, "data/debug/ui_background.png", 1, 1000)
    GuiZSet(gui, -1100)

    local title_text = string.upper(Locale("$respawn_title"))
    GuiDecoratedTitle(gui, new_id, 70, title_text)

    local ok_text = Locale("  $respawn_ok")
    local cancel_text = Locale("  $respawn_cancel")
    local ok_text_w, _ = GuiGetTextDimensions(gui, ok_text)
    local cancel_text_w, _ = GuiGetTextDimensions(gui, cancel_text)

    local x_scale = CenteredX(gui, ok_text_w + cancel_text_w + 14 + 2) -- 2 is the spacing
    GuiLayoutBeginHorizontal(gui, x_scale, 78)

    id = new_id()
    if hovered[id] then
      GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1) -- Doesn't seem to be working
      ok_text = ok_text:gsub("^  *", hover_prefix)
    end

    if GuiButton(gui, id, 0, 0, ok_text) then
      disable_cessation()
      tasks:AddDeferredTask(0, on_ok)
      draw_respawn_ui = false
    end
    hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))

    id = new_id()
    if hovered[id] then
      GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1)
      cancel_text = cancel_text:gsub("^ *", hover_prefix)
    end

    if GuiButton(gui, id, 14, 0, cancel_text) then
      disable_cessation()
      tasks:AddDeferredTask(0, on_cancel)
      draw_respawn_ui = false
    end
    hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))

    GuiLayoutEnd(gui)
    GuiAnimateEnd(gui)
  end
end

---You must wait a frame after running the returned clousure to de-polymorph.
local function CessatePlayer()
  local player_id = EntityGetWithTag("player_unit")[1]
  if not player_id then return end
  --- Compatibility with mods that remove polymorphism for player
  local poly_compat = EntityHasTag(player_id, "polymorphable_NOT")
  EntityRemoveTag(player_id, "polymorphable_NOT")
  GetGameEffectLoadTo(player_id, "POLYMORPH_CESSATION", true)

  local poly_player_id = EntityGetWithTag("polymorphed_cessation")[1]
  if not poly_player_id then return end

  for _, id in ipairs(assert(EntityGetAllChildren(poly_player_id))) do
    if #EntityGetTags(id) == 0 then
      local effect = assert(EntityGetFirstComponent(id, "GameEffectComponent"))
      ComponentSetValue2(effect, "frames", 10 ^ 6) -- Not ideal
      GameAddFlagRun("msg_gods_looking")
      GameAddFlagRun("msg_gods_looking2")

      return function()
        if poly_compat then
          EntityAddTag(player_id, "polymorphable_NOT")
        end
        ComponentSetValue2(effect, "frames", 1)
        GameRemoveFlagRun("msg_gods_looking")
        GameRemoveFlagRun("msg_gods_looking2")
      end
    end
  end

  return nil
end

local function GetPlayer()
  return EntityGetWithTag("player_unit")[1] or EntityGetWithTag("polymorphed_player")[1]
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

local function PlayerShouldDie()
  if respawn.shared.respawn_system == const.RESPAWN_SYSTEM.UNLIMITED then
    return false
  else
    return math.floor(respawn.shared.GetRespawnCount(respawn.shared) - deaths) <= 0
  end
end

---@param damage_model component_id
local function KillPlayer(damage_model)
  ComponentSetValue2(damage_model, "hp", 0)
  ComponentSetValue2(damage_model, "kill_now", true)
end

local function PlayerDied()
  deaths = deaths + 1
end

function OnModInit()
  dofile_once("mods/resurrection/files/scripts/on_init/appends.lua")
end

function OnPausedChanged()
  utils:ClearModSettingsCache()
end

function OnWorldInitialized()
  ---@diagnostic disable:cast-local-type
  -- It might be fine to allow for changing respawn system on world load
  respawn.shared:Init()
  respawn_position = utils:GlobalGetTypedValue("respawn_position", respawn_position)
  deaths = utils:GlobalGetOrSetTypedValue("deaths", deaths)
  ---@diagnostic disable-next-line: assign-type-mismatch
  respawn.level_on_respawn_gain = utils:GlobalGetOrSetTypedValue("level_on_respawn_gain", respawn.level_on_respawn_gain)
  ---@diagnostic enable:cast-local-type

  if meta_leveling == nil then
    if respawn.shared.respawn_system == const.RESPAWN_SYSTEM.META_LEVELING then
      tasks:AddDeferredTask(60, function()
        GamePrint("Meta Leveling is not enabled, falling back to the Unlimited Respawn System.")
      end)
    end
    respawn.shared.respawn_system = const.RESPAWN_SYSTEM.UNLIMITED -- fallback
  end
end

---@diagnostic disable-next-line: param-type-mismatch
local hold_respawn_point_handler = input:CreateHoldKeyDownHandler(utils:GetModSetting("respawn_point"))

function OnWorldPreUpdate()
  GuiStartFrame(gui)

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

      utils:GlobalSetTypedValue("respawn_position", respawn_position)

      EntityLoad("mods/resurrection/files/entities/particles/image_emitters/small_effect.xml", x, y)
      GamePrint(Locale("$respawn_set_msg"))
    end
  end

  local new_id = IdFactory()

  local player_id = GetPlayer()
  if player_id then
    DrawStats(gui, new_id)
  end
  if respawn_ui_update ~= nil and draw_respawn_ui then
    respawn_ui_update(new_id)
    return
  end

  respawn:UpdateRespawns()

  if not player_id then return end
  local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
  if not damage_model then return end

  ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", true)
  if ComponentGetValue2(damage_model, "hp") >= ONE_HP or ComponentGetValue2(damage_model, "kill_now") then return end

  if PlayerShouldDie() then
    KillPlayer(damage_model)
    ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", false)
    return
  end
  PlayerDied()

  local disable_cessation = CessatePlayer()
  if not disable_cessation then
    utils:Log("Failed to cessate the player entity.")
    return
  end

  respawn_ui_update = CreateRespawnGui(gui, disable_cessation,
    function()
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
        ComponentGetValue2(damage_model, "max_hp") * utils:GetModSetting("respawn_health"))
      GameRegenItemActionsInPlayer(player_id)

      local player_x, player_y = EntityGetTransform(player_id)
      if not GameHasFlagRun("ending_game_completed") then
        EntitySetTransform(player_id, respawn_position.x, respawn_position.y)
        EntityLoad("data/entities/misc/matter_eater.xml", respawn_position.x, respawn_position.y) -- Not sure why this exists

        for _, effect in pairs(status_effects) do
          EntityRemoveStainStatusEffect(player_id, effect.id)
        end
        ComponentSetValue2(damage_model, "mIsOnFire", false)

        local wallet = assert(EntityGetFirstComponent(player_id, "WalletComponent"))
        local money = ComponentGetValue2(wallet, "money")
        local money_drop = math.floor(money * utils:GetModSetting("gold_drop"))

        if money_drop > 0 then
          tasks:AddDeferredTask(0, function()
            ComponentSetValue2(wallet, "money", money - money_drop)
            DropGold(money_drop, player_x, player_y)
            GamePrint(string.format(Locale("$gold_drop_msg"), money_drop))
          end)
        end
      else
        KillPlayer(damage_model)
      end
    end,
    function()
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

  draw_respawn_ui = true
end
