---@diagnostic disable: lowercase-global
dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "resurrection" -- This should match the name of your mod's folder.
-- This is a magic global that can be used to migrate settings to new mod versions.
-- Call mod_settings_get_version() before mod_settings_update() to get the old value.
mod_settings_version = 1

mod_settings = {
  {
    id = "respawn_health",
    ui_name = "Respawn Health",
    ui_description = "Fraction of health to respawn with.",
    value_default = 0.5,
    value_min = 0.1,
    value_max = 1,
    value_display_multiplier = 100,
    value_display_formatting = "$0%",
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
    value_display_formatting = "$0%",
    scope = MOD_SETTING_SCOPE_RUNTIME
  }
}

-- This function is called to ensure the correct setting values are visible to the game. your mod's settings don't work if you don't have a function like this defined in settings.lua.
function ModSettingsUpdate(init_scope)
  local old_version = mod_settings_get_version(mod_id) -- This can be used to migrate some settings between mod versions.
  mod_settings_update(mod_id, mod_settings, init_scope)
end

-- This function should return the number of visible setting UI elements.
-- Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
-- If your mod changes the displayed settings dynamically, you might need to implement custom logic for this function.
function ModSettingsGuiCount()
  return mod_settings_gui_count(mod_id, mod_settings)
end

-- This function is called to display the settings UI for this mod. your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
function ModSettingsGui(gui, in_main_menu)
  mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
