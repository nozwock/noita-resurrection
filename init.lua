dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")
dofile("data/scripts/status_effects/status_list.lua")
local utils = dofile_once("mods/resurrection/data/scripts/utils.lua") ---@type utils


local ONE_HP = 0.04

local respawn_position = {
  x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
  y = tonumber(MagicNumbersGetValue(
    "DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85

local gui = GuiCreate()
local draw_respawn_ui = false
local respawn_ui_update = nil

-- Why am I using different styling for function names? Don't think about it.

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


local function centered_x(gui, object_width)
  local w, _ = GuiGetScreenDimensions(gui)
  return math.floor((w / 2 - object_width / 2) / w * 100)
end

--- `y` is percent based.
local function GuiDecoratedTitle(gui, id, y, title)
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
  -- print(string.format("w:%.2f decor_w:%.2f text_w:%.2f decor_scale:%.2f text_scale:%.2f", w, decor_w, text_w,
  -- 	decor_x_scale, text_x_scale))

  GuiLayoutBeginHorizontal(gui, decor_x, y, true, 0, 0)
  GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_left.png", 1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_middle.png", 1, middle_scale + padding_scale * 2,
    1, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_right.png",
    1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiLayoutEnd(gui)

  GuiLayoutBeginVertical(gui, text_x, y, true)
  GuiText(gui, 0, 5, title, 1, "data/fonts/font_pixel_huge.xml")
  GuiLayoutEnd(gui)
end

local function CreateRespawnGui(gui, disable_cessation, on_ok, on_cancel)
  local cessUpdateFrames = 0
  local hovered = {}
  local clicked = {}
  local hover_prefix = ">"

  return function()
    if not draw_respawn_ui then
      return
    end

    local id
    local new_id = IdFactory()
    GuiStartFrame(gui)

    GuiZSet(gui, -1000)
    GuiImage(gui, new_id(), 0, 0, "data/debug/ui_background.png", 1, 1000)
    GuiZSet(gui, -1100)

    local title_text = string.upper("Unthethered")
    GuiDecoratedTitle(gui, new_id(), 70, title_text)

    local ok_text = "  Wake Up"
    local cancel_text = "  Wisp Away"
    local ok_text_w, _ = GuiGetTextDimensions(gui, ok_text)
    local cancel_text_w, _ = GuiGetTextDimensions(gui, cancel_text)

    local x_scale = centered_x(gui, ok_text_w + cancel_text_w + 14 + 2) -- 2 is the spacing
    GuiLayoutBeginHorizontal(gui, x_scale, 78)

    id = new_id()
    if hovered[id] then
      GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1) -- Doesn't seem to be working
      ok_text = ok_text:gsub("^  *", hover_prefix)
    end

    if GuiButton(gui, id, 0, 0, ok_text) then
      clicked[id] = true
      disable_cessation()
      cessUpdateFrames = cessUpdateFrames + 1
    end
    hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))
    if clicked[id] and cessUpdateFrames > 1 then
      on_ok()
      draw_respawn_ui = false
    end

    id = new_id()
    if hovered[id] then
      GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1)
      cancel_text = cancel_text:gsub("^ *", hover_prefix)
    end

    if GuiButton(gui, id, 14, 0, cancel_text) then
      clicked[id] = true
      disable_cessation()
      cessUpdateFrames = cessUpdateFrames + 1 -- todo: Use the DeferredTask API for this instead
    end
    hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))
    if clicked[id] and cessUpdateFrames > 1 then
      on_cancel()
      draw_respawn_ui = false
    end

    GuiLayoutEnd(gui)

    if cessUpdateFrames > 0 then
      cessUpdateFrames = cessUpdateFrames + 1
    end
  end
end

--- You must wait a frame after running the returned clousure to de-polymorph.
local function CessatePlayer()
  local player_id = EntityGetWithTag("player_unit")[1]
  if not player_id then return end
  GetGameEffectLoadTo(player_id, "POLYMORPH_CESSATION", true)

  local poly_player_id = EntityGetWithTag("polymorphed_cessation")[1]
  if not poly_player_id then return end
  -- if not assert(IsPlayer(poly_player_id)) then return end

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

local function CreateHoldKeyDownHandler(key_code)
  local handler = { key_code = key_code, frames_held = 0 }

  function handler:Update()
    if InputIsKeyDown(self.key_code) then
      self.frames_held = self.frames_held + 1
    else
      self.frames_held = 0
    end
  end

  function handler:HeldFor(frames)
    return self.frames_held >= frames
  end

  function handler:HeldOnceFor(frames)
    return self:HeldFor(frames) and self.frames_held % frames == 0
  end

  return handler
end

local function GetPlayer()
  return EntityGetWithTag("player_unit")[1] or EntityGetWithTag("polymorphed_player")[1]
end

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

local hold_spawn_point_handler = CreateHoldKeyDownHandler(ModSettingGet(utils:GetModSettingId("spawn_point")))

function OnWorldPreUpdate()
  ProcessDeferredTasks()
  hold_spawn_point_handler:Update()

  if hold_spawn_point_handler:HeldOnceFor(120) then
    local player_id = GetPlayer()
    if player_id ~= nil then
      local x, y, _ = EntityGetTransform(player_id)
      respawn_position.x = x
      respawn_position.y = y

      EntityLoad("mods/resurrection/data/entities/particles/image_emitters/small_effect.xml", x, y)
      GamePrint("Tethered Once More")
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
  if ComponentGetValue2(damage_model, "hp") >= ONE_HP then return end

  local disable_cessation = CessatePlayer()
  if not disable_cessation then return end

  respawn_ui_update = CreateRespawnGui(gui, disable_cessation,
    function()
      local player_id = GetPlayer()
      if not player_id then
        print("failed to get player_id during respawn")
        return
      end
      local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
      if not damage_model then
        print("failed to get DamageModelComponent during respawn")
        return
      end

      local game_effect = GetGameEffectLoadTo(player_id, "BLINDNESS", true)
      if game_effect then
        ComponentSetValue2(game_effect, "frames", 120)
      end

      ComponentSetValue2(damage_model, "hp",
        ComponentGetValue2(damage_model, "max_hp") * ModSettingGet(utils:GetModSettingId("respawn_health")))
      GameRegenItemActionsInPlayer(player_id)

      local player_x, player_y = EntityGetTransform(player_id)
      if not GameHasFlagRun("ending_game_completed") then
        EntitySetTransform(player_id, respawn_position.x, respawn_position.y)
        EntityLoad("data/entities/misc/matter_eater.xml", respawn_position.x, respawn_position.y) -- Not sure why this exists

        for _, effect in pairs(status_effects) do
          EntityRemoveStainStatusEffect(player_id, effect.id)
        end

        local wallet = assert(EntityGetFirstComponent(player_id, "WalletComponent"))
        local money = ComponentGetValue2(wallet, "money")
        local money_drop = math.floor(money * ModSettingGet(utils:GetModSettingId("gold_drop")))

        if money_drop > 0 then
          AddDeferredTask(0, function()
            ComponentSetValue2(wallet, "money", money - money_drop)
            DropGold(money_drop, player_x, player_y)
            GamePrint(string.format("Lost %d Gold", money_drop))
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
        print("failed to get player_id during game over")
        return
      end
      local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
      if not damage_model then
        print("failed to get DamageModelComponent during game over")
        return
      end

      ComponentSetValue2(damage_model, "hp", 0)
      ComponentSetValue2(damage_model, "kill_now", true)
    end)

  draw_respawn_ui = true
end
