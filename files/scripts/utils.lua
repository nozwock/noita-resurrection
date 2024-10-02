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

utils._TYPES = {
  boolean = 1,
  string = 2,
  number = 3,
  table = 4,
  ["nil"] = 5
}

---@alias GlobalValues boolean|string|number|nil|{[number|string]:GlobalValues}

---Keep keys simple ([\w_]+), otherwise the code might explode.
---There are no checks for the param types, don't mess up.
---@param key string
---@param value GlobalValues
function utils:GlobalSetTypedValue(key, value)
  if type(value) == "table" then
    local table_keys = ""
    for k, v in pairs(value) do
      local table_key = key .. "$" .. self._TYPES[type(k)] .. k
      table_keys = table_keys .. table_key .. ","
      self:GlobalSetTypedValue(table_key, v)
    end
    key = MOD_ID .. "." .. key
    print("Setting: " .. key .. ": " .. self._TYPES.table .. table_keys)
    GlobalsSetValue(key, self._TYPES.table .. table_keys)
  else
    key = MOD_ID .. "." .. key
    value = self._TYPES[type(value)] .. tostring(value)
    print("Setting: " .. key .. ": " .. value)
    GlobalsSetValue(key, value)
  end
end

---@param key string
---@return GlobalValues
function utils:GlobalGetTypedValue(key)
  ---@param keys string
  local function GetTable(keys)
    local t = {}
    for key in string.gmatch(keys, "[^,]+") do
      local t_key = key:gsub(".*%$", "")
      local t_key_type = tonumber(string.sub(t_key, 1, 1))
      t_key = string.sub(t_key, 2, #t_key)

      local value = utils:GlobalGetTypedValue(key)
      if t_key_type == self._TYPES.string then
        t[t_key] = value
      elseif t_key_type == self._TYPES.number then
        t[tonumber(t_key)] = value
      end
    end

    return t
  end

  key = MOD_ID .. "." .. key
  local value = GlobalsGetValue(key)
  print("Getting: " .. key .. ": " .. tostring(value))
  if not value or string.find(value, "^%d") == nil then
    return nil
  end

  local type = tonumber(string.sub(value, 1, 1))
  value = string.sub(value, 2, #value)
  if type == self._TYPES.boolean then
    return tonumber(value) ~= 0
  elseif type == self._TYPES.number then
    return tonumber(value)
  elseif type == self._TYPES.string then
    return value
  elseif type == self._TYPES.table then
    return GetTable(value)
  elseif type == self._TYPES["nil"] then
    return nil
  end

  return nil
end

return utils
