---@diagnostic disable: lowercase-global
dofile("mods/resurrection/files/scripts/defs.lua")
dofile("data/scripts/lib/mod_settings.lua")
local input = dofile_once("mods/resurrection/files/scripts/input.lua") ---@type input

-- This is a magic global that can be used to migrate settings to new mod versions.
-- Call mod_settings_get_version() before mod_settings_update() to get the old value.
mod_settings_version = 1

local function CreateGuiSettingKeybind()
  local awaiting_input = false

  return function(mod_id, gui, in_main_menu, im_id, setting)
    local setting_id = mod_setting_get_id(mod_id, setting)
    local prev_value = ModSettingGetNextValue(setting_id) or setting.value_default

    GuiLayoutBeginHorizontal(gui, 0, 0)

    local value = nil
    local text
    if awaiting_input then
      text = "Press something"
      local key = input:ListenInputKeyGroup(input.KEYS)
      local control_key = input:ListenInputKeyGroup(input.CONTROL_KEYS)
      if control_key ~= nil then
        awaiting_input = false
      elseif key ~= nil then
        awaiting_input = false
        value = key
      end
    else
      text = input:NameForKey(prev_value)
    end

    if GuiButton(gui, im_id, 0, 0, setting.ui_name .. ": " .. text) then
      awaiting_input = true
    end

    GuiLayoutEnd(gui)

    if value ~= nil then
      ModSettingSetNextValue(setting_id, value, false)
    end
    mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, prev_value, value)
  end
end


mod_settings = {
  {
    id = "respawn_health",
    ui_name = "Respawn Health",
    ui_description = "Fraction of health to respawn with.",
    value_default = 0.5,
    value_min = 0.1,
    value_max = 1,
    value_display_multiplier = 100,
    value_display_formatting = " $0%",
    scope = MOD_SETTING_SCOPE_RUNTIME
  },
  {
    id = "gold_drop",
    ui_name = "Gold Drop",
    ui_description = "Fraction of gold to be dropped on death.",
    value_default = 0.2,
    value_min = 0,
    value_max = 1,
    value_display_multiplier = 100,
    value_display_formatting = " $0%",
    scope = MOD_SETTING_SCOPE_RUNTIME
  },
  {
    category_id = "keybinds",
    ui_name = "Keybinds",
    foldable = true,
    settings = {
      {
        id = "spawn_point",
        ui_name = "Spawn Point",
        value_default = input.KEYS.Key_t,
        ui_fn = CreateGuiSettingKeybind(),
        scope = MOD_SETTING_SCOPE_RUNTIME
      },
    }
  }
}

-- This function is called to ensure the correct setting values are visible to the game. your mod's settings don't work if you don't have a function like this defined in settings.lua.
function ModSettingsUpdate(init_scope)
  local old_version = mod_settings_get_version(MOD_ID) -- This can be used to migrate some settings between mod versions.
  mod_settings_update(MOD_ID, mod_settings, init_scope)
end

-- This function should return the number of visible setting UI elements.
-- Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
-- If your mod changes the displayed settings dynamically, you might need to implement custom logic for this function.
function ModSettingsGuiCount()
  return mod_settings_gui_count(MOD_ID, mod_settings)
end

-- This function is called to display the settings UI for this mod. your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
function ModSettingsGui(gui, in_main_menu)
  mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end
