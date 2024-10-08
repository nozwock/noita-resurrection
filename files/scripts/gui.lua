dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/status_effects/status_list.lua")
dofile("mods/resurrection/files/scripts/locale.lua")
local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const
local utils = dofile_once("mods/resurrection/files/scripts/utils.lua") ---@type utils
local tasks = dofile_once("mods/resurrection/files/scripts/tasks.lua") ---@type tasks
local revive = dofile_once("mods/resurrection/files/scripts/revive.lua") ---@type revive

---@class gui_mod
local gui = {
  gui = GuiCreate(),
  respawn_gui = nil, ---@type RespawnGui?
  draw_respawn_gui = false
}

function gui:StartFrame()
  GuiStartFrame(self.gui)
end

---@return fun():integer
function gui:IdFactory()
  local id = 100

  return function()
    id = id + 1
    return id
  end
end

---@param object_width number
function gui:CenteredX(object_width)
  local w, _ = GuiGetScreenDimensions(self.gui)
  return math.floor((w / 2 - object_width / 2) / w * 100)
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param dont_focus? boolean
---@return boolean
---@nodiscard
function gui:IsHoverBoxHovered(id, x, y, width, height, dont_focus)
  local empty = "data/ui_gfx/empty.png"
  if not dont_focus then
    GuiOptionsAddForNextWidget(self.gui, GUI_OPTION.ForceFocusable)
  end
  GuiZSetForNextWidget(self.gui, -10000)
  GuiImageNinePiece(self.gui, id, x, y, width, height, 1, empty, empty)
  return select(3, GuiGetPreviousWidgetInfo(self.gui))
end

---`x` is with width of widget as offset.
---@param new_id fun():integer
---@param x number
---@param y number
---@param death_count integer
function gui:DeathStatCounter(new_id, x, y, death_count)
  local death_filename = "mods/resurrection/files/gfx/ui/icon_death.png"
  local tw, th = GuiGetTextDimensions(self.gui, tostring(death_count), 1, 2, "data/fonts/font_small_numbers.xml")
  local iw, _ = GuiGetImageDimensions(self.gui, death_filename)
  x = x - (tw + iw + 2) - 4

  GuiLayoutBeginHorizontal(self.gui, x, y, true)

  GuiImage(self.gui, new_id(), 0, 0, death_filename, 1, 1, 0, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiColorSetForNextWidget(self.gui, 1, 1, 1, 0.75)
  GuiText(self.gui, 2, 0, tostring(death_count), 1, "data/fonts/font_small_numbers.xml")
  if self:IsHoverBoxHovered(new_id(), x, y, tw + iw + 2, th) then
    GuiTooltip(self.gui, string.format(Locale("$deaths_tooltip"), death_count), "")
  end

  GuiLayoutEnd(self.gui)
  return x, y
end

---`x` is with width of widget as offset.
---@param new_id fun():integer
---@param x number
---@param y number
---@param revive_count integer
function gui:ReviveStatCounter(new_id, x, y, revive_count)
  local revive_filename = "mods/resurrection/files/gfx/ui/plus_with_angel_wings.png"
  local tw, th = GuiGetTextDimensions(self.gui, tostring(revive_count), 1, 2, "data/fonts/font_small_numbers.xml")
  local iw, _ = GuiGetImageDimensions(self.gui, revive_filename, 1)
  x = x - (tw + iw + 2) - 4

  GuiLayoutBeginHorizontal(self.gui, x, y, true)

  GuiImage(self.gui, new_id(), 0, -1, revive_filename, 1, 1, 0, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiColorSetForNextWidget(self.gui, 1, 1, 1, 0.75)
  GuiText(self.gui, 1, 0, tostring(revive_count), 1, "data/fonts/font_small_numbers.xml")
  if self:IsHoverBoxHovered(new_id(), x, y, tw + iw + 2, th) then
    GuiTooltip(self.gui, string.format(Locale("$revives_tooltip"), revive_count), "")
  end

  GuiLayoutEnd(self.gui)
  return x, y
end

---@param new_id fun():integer
---@param death_count integer
function gui:DrawHUDStats(new_id, death_count)
  local w, _ = GuiGetScreenDimensions(self.gui)
  local x, y = w - 38 - utils:GetModSetting("stat_hud_offset"), 12
  if revive.shared.respawn_system ~= const.RESPAWN_SYSTEM.UNLIMITED then
    x, y = self:ReviveStatCounter(new_id, x, y, revive.shared:GetReviveCount() - death_count)
    x = x - 1
  end
  self:DeathStatCounter(new_id, x, y, death_count)
end

---`y` is percent based.
---@param new_id fun():integer
---@param y number
---@param title string
function gui:GuiDecoratedTitle(new_id, y, title)
  title = string.upper(title)

  local edge_w, _ = GuiGetImageDimensions(self.gui, "data/ui_gfx/decorations/piece_small_left.png", 1)
  local middle_w, _ = GuiGetImageDimensions(self.gui, "data/ui_gfx/decorations/piece_small_middle.png", 1)
  local text_w, _ = GuiGetTextDimensions(self.gui, title, 1, 2, "data/fonts/font_pixel_huge.xml")

  local padding_scale = 6
  local middle_scale = text_w / middle_w
  local decor_w = edge_w * 2 + middle_w * (middle_scale + padding_scale * 2)

  local w, h = GuiGetScreenDimensions(self.gui)
  local decor_x = math.floor(w / 2 - decor_w / 2)
  local text_x = math.floor(w / 2 - text_w / 2)
  y = h * y / 100

  GuiLayoutBeginHorizontal(self.gui, decor_x, y, true, 0, 0)
  GuiImage(self.gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_left.png", 1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(self.gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_middle.png", 1,
    middle_scale + padding_scale * 2,
    1, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiImage(self.gui, new_id(), 0, 0, "data/ui_gfx/decorations/piece_small_right.png",
    1, 1, 0, 0,
    GUI_RECT_ANIMATION_PLAYBACK.Loop)
  GuiLayoutEnd(self.gui)

  GuiLayoutBeginVertical(self.gui, text_x, y, true)
  GuiText(self.gui, 0, 5, title, 1, "data/fonts/font_pixel_huge.xml")
  GuiLayoutEnd(self.gui)
end

---@param remove_cessation? function
---@param on_ok function
---@param on_cancel function
function gui:CreateRespawnGui(remove_cessation, on_ok, on_cancel)
  ---@class RespawnGui
  local state = {
    remove_cessation = remove_cessation,
    on_ok = on_ok,
    on_cancel = on_cancel,
    hovered = {},
    hover_prefix = ">"
  }

  ---@param state RespawnGui
  ---@param new_id fun():integer
  function state.Draw(state, new_id)
    if not self.draw_respawn_gui then
      return
    end

    local id

    GuiAnimateBegin(self.gui)
    GuiAnimateAlphaFadeIn(self.gui, new_id(), 0.04, 0.1, false)

    GuiZSet(self.gui, -1000)
    GuiImage(self.gui, new_id(), 0, 0, "data/debug/ui_background.png", 1, 1000)
    GuiZSet(self.gui, -1100)

    local title_text = string.upper(Locale("$respawn_title"))
    self:GuiDecoratedTitle(new_id, 70, title_text)

    local ok_text = Locale("  $respawn_ok")
    local cancel_text = Locale("  $respawn_cancel")
    local ok_text_w, _ = GuiGetTextDimensions(self.gui, ok_text)
    local cancel_text_w, _ = GuiGetTextDimensions(self.gui, cancel_text)

    local x_scale = self:CenteredX(ok_text_w + cancel_text_w + 14 + 2) -- 2 is the spacing
    GuiLayoutBeginHorizontal(self.gui, x_scale, 78)

    id = new_id()
    if state.hovered[id] then
      GuiColorSetForNextWidget(self.gui, 1, 1, 0.5, 1) -- Doesn't seem to be working
      ok_text = ok_text:gsub("^  *", state.hover_prefix)
    end

    if GuiButton(self.gui, id, 0, 0, ok_text) then
      if state.remove_cessation then
        state.remove_cessation()
      end
      tasks:AddDeferredTask(0, state.on_ok)
      self.draw_respawn_gui = false
    end
    state.hovered[id] = select(3, GuiGetPreviousWidgetInfo(self.gui))

    id = new_id()
    if state.hovered[id] then
      GuiColorSetForNextWidget(self.gui, 1, 1, 0.5, 1)
      cancel_text = cancel_text:gsub("^ *", state.hover_prefix)
    end

    if GuiButton(self.gui, id, 14, 0, cancel_text) then
      if state.remove_cessation then
        state.remove_cessation()
      end
      tasks:AddDeferredTask(0, state.on_cancel)
      self.draw_respawn_gui = false
    end
    state.hovered[id] = select(3, GuiGetPreviousWidgetInfo(self.gui))

    GuiLayoutEnd(self.gui)
    GuiAnimateEnd(self.gui)
  end

  return state
end

return gui
