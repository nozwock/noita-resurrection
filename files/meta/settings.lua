---@meta settings.lua
-- ##########################################################################################
-- ##########################				settings.lua				#####################
-- ##########################################################################################

MOD_SETTING_SCOPE_NEW_GAME = 0
MOD_SETTING_SCOPE_RUNTIME_RESTART = 1
MOD_SETTING_SCOPE_RUNTIME = 2
MOD_SETTING_SCOPE_ONLY_SET_DEFAULT = 3

mod_setting_group_x_offset = 0 --increases automatically

---@alias mod_setting_scopes
---| `MOD_SETTING_SCOPE_NEW_GAME` # 0 - setting change (that is the value that's visible when calling ModSettingGet()) is applied after a new run is started
---| `MOD_SETTING_SCOPE_RUNTIME_RESTART` # 1 - setting change is applied on next game exe restart
---| `MOD_SETTING_SCOPE_RUNTIME` # 2 - setting change is applied immediately
---| `MOD_SETTING_SCOPE_ONLY_SET_DEFAULT` # 3 - this tells us that no changes should be applied. shouldn't be used in mod setting definition.
---@alias mod_id string
---@alias mod_category_id string
---@alias setting_id string
---@alias setting_value string|number|boolean

---@class string_setting
---@field [1] string setting value
---@field [2] string ui name of value

---@class string_settings
---@field [number] string_setting

---@class mod_setting
---@field _version? number used to track setting version, not used in vanilla
---@field value_default setting_value default value
---@field id setting_id
---@field ui_name? string
---@field ui_description? string
---@field hidden? boolean
---@field ui_fn? fun(mod_id: mod_id, gui: gui, in_main_menu: boolean, im_id: number, setting: mod_setting)
---@field change_fn? fun(mod_id: mod_id, gui: gui, in_main_menu: boolean, setting: mod_setting, old_value: setting_value, new_value: setting_value)
---@field scope mod_setting_scopes

---@class (exact) not_a_setting
---@field not_setting boolean
---@field [string] any

---@class (exact) mod_setting_string:mod_setting
---@field value_default string default value
---@field values string_settings

---@class (exact) mod_setting_number:mod_setting
---@field value_default number
---@field value_min number
---@field value_max number
---@field value_display_multiplier number
---@field value_display_formatting string
--@field format string

---@class (exact) mod_setting_boolean:mod_setting
---@field value_default boolean

---@class mod_settings
---@field [number] not_a_setting|mod_setting_boolean|mod_setting_number|mod_setting_string|mod_setting_category

---@class mod_setting_category
---@field category_id mod_category_id
---@field ui_name string
---@field ui_description? string
---@field foldable boolean
---@field _folded boolean
---@field settings mod_settings

---@class mod_settings_global
---@field [number] mod_setting|mod_setting_category|{}

---@param mod_id mod_id
---@param setting mod_setting
---@return setting_id
function mod_setting_get_id(mod_id, setting) end

---@param mod_id string
---@param gui gui
---@param in_main_menu boolean
---@param setting mod_setting
---@param old_value setting_value
---@param new_value setting_value
function mod_setting_handle_change_callback(mod_id, gui, in_main_menu, setting, old_value, new_value) end

---@param mod_id string
---@param gui gui
---@param in_main_menu boolean
---@param setting mod_setting
function mod_setting_tooltip(mod_id, gui, in_main_menu, setting) end

---@param mod_id mod_id
---@return number
function mod_settings_get_version(mod_id) end

---this is called on init, new game, unpause and so on.<br>
---this function will take care of setting the settings visible to the game to correct values.
---@param mod_id mod_id
---@param settings mod_settings_global
---@param init_scope mod_setting_scopes
function mod_settings_update(mod_id, settings, init_scope) end

---counts settings amount (why?)
---@param mod_id mod_id
---@param settings mod_settings_global
---@return number
function mod_settings_gui_count(mod_id, settings) end

---main function for drawing settings
---@param mod_id mod_id
---@param settings mod_settings_global
---@param gui gui
---@param in_main_menu boolean
function mod_settings_gui(mod_id, settings, gui, in_main_menu) end

---@param mod_id mod_id
---@param gui gui
---@param in_main_menu boolean
---@param im_id number
---@param setting mod_setting
function mod_setting_vertical_spacing(mod_id, gui, in_main_menu, im_id, setting) end
