dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")
dofile("data/scripts/status_effects/status_list.lua")
dofile("mods/resurrection/files/scripts/locale.lua")
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local input = dofile_once("mods/resurrection/files/scripts/input.lua") ---@type input


local ONE_HP = 0.04

local respawn_position = {
  x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
  y = tonumber(MagicNumbersGetValue(
    "DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85

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

---@type DeferredTask[]
local deferred_tasks = {}

---@param frames number
---@param fn function
local function AddDeferredTask(frames, fn)
  ---@param frames number
  ---@param fn function
  local function CreateDeferredTask(frames, fn)
    ---@class DeferredTask
    local state = { done = false, wait_frames = frames, task = fn }

    function state:Update()
      if self.wait_frames <= 0 and not self.done then
        self.task()
        self.done = true
      else
        self.wait_frames = self.wait_frames - 1
      end
    end

    return state
  end

  table.insert(deferred_tasks, CreateDeferredTask(frames, fn))
end

local function ProcessDeferredTasks()
  local i = 1
  while i <= #deferred_tasks do
    deferred_tasks[i]:Update()
    if deferred_tasks[i].done then
      table.remove(deferred_tasks, i)
    else
      i = i + 1
    end
  end
end

---@param gui gui
---@param object_width number
local function CenteredX(gui, object_width)
  local w, _ = GuiGetScreenDimensions(gui)
  return math.floor((w / 2 - object_width / 2) / w * 100)
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

  return function()
    if not draw_respawn_ui then
      return
    end

    local id
    local new_id = IdFactory()

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
      AddDeferredTask(0, on_ok)
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
      AddDeferredTask(0, on_cancel)
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

function OnModInit()
  dofile_once("mods/resurrection/files/scripts/on_init/appends.lua")
end

function OnPausedChanged()
  utils:ClearModSettingsCache()
end

function OnWorldInitialized()
  local respawn_position_ = utils:GlobalGetTypedValue("respawn_position")
  if respawn_position_ ~= nil then
    ---@diagnostic disable-next-line: cast-local-type
    respawn_position = respawn_position_
  end
end

---@diagnostic disable-next-line: param-type-mismatch
local hold_respawn_point_handler = input:CreateHoldKeyDownHandler(utils:GetModSetting("respawn_point"))

function OnWorldPreUpdate()
  GuiStartFrame(gui)

  ProcessDeferredTasks()
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

  if respawn_ui_update ~= nil and draw_respawn_ui then
    respawn_ui_update()
    return
  end

  local player_id = GetPlayer()
  if not player_id then return end
  local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
  if not damage_model then return end

  ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", true)
  if ComponentGetValue2(damage_model, "hp") >= ONE_HP or ComponentGetValue2(damage_model, "kill_now") then return end

  local disable_cessation = CessatePlayer()
  if not disable_cessation then return end

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
          AddDeferredTask(0, function()
            ComponentSetValue2(wallet, "money", money - money_drop)
            DropGold(money_drop, player_x, player_y)
            GamePrint(string.format(Locale("$gold_drop_msg"), money_drop))
          end)
        end
      else
        ComponentSetValue2(damage_model, "hp", 0)
        ComponentSetValue2(damage_model, "kill_now", true)
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

      ComponentSetValue2(damage_model, "hp", 0)
      ComponentSetValue2(damage_model, "kill_now", true)
    end)

  draw_respawn_ui = true
end
