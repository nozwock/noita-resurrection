dofile("mods/resurrection/files/scripts/defs.lua")

---@class utils
local utils = {}

---Recursive `pairs`.
---@param t table
---@return fun():string|number, unknown
function utils:rpairs(t)
  return coroutine.wrap(
    function()
      for k, v in pairs(t) do
        if type(v) == "table" then
          local iter = self:rpairs(v)
          local k_, v_ = iter()
          while v_ ~= nil do
            coroutine.yield(k_, v_)
            k_, v_ = iter()
          end
        else
          coroutine.yield(k, v)
        end
      end
    end
  )
end

utils.mod_settings_cache = {}

---@param id string
function utils:GetModSetting(id)
  id = MOD_ID .. "." .. id
  local setting = self.mod_settings_cache[id]
  if setting ~= nil then
    return setting
  end

  setting = ModSettingGet(id)
  self.mod_settings_cache[id] = setting
  return setting
end

function utils:ClearModSettingsCache()
  self.mod_settings_cache = {}
end

return utils
