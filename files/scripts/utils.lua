local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const

---@class utils
local utils = {}

function utils:ErrLog(...)
  print("[Error] [Resurrection]: ", ...)
end

function utils:Log(...)
  print("[Resurrection]: ", ...)
end

---@param t table
function utils:SerializeTable(t)
  local s = { "\n{\n" }
  for k, v in pairs(t) do
    table.insert(s, "\t{ " .. tostring(k) .. "=" .. tostring(v) .. " },\n")
  end
  table.insert(s, "}")
  return table.concat(s)
end

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
  id = const.MOD_ID .. "." .. id
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

---@alias GlobalValues boolean|string|number|nil|{[number]:GlobalValues, [string]:GlobalValues}

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
    key = const.MOD_ID .. "." .. key
    -- self:Log("set: " .. key .. ": " .. self._TYPES.table .. table_keys)
    GlobalsSetValue(key, self._TYPES.table .. table_keys)
  else
    key = const.MOD_ID .. "." .. key
    value = self._TYPES[type(value)] .. tostring(value)
    -- self:Log("set: " .. key .. ": " .. value)
    GlobalsSetValue(key, value)
  end
end

---@param key string
---@param default any
---@return GlobalValues
function utils:GlobalGetTypedValue(key, default)
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

  key = const.MOD_ID .. "." .. key
  local value = GlobalsGetValue(key)
  -- self:Log("get: " .. key .. ": " .. tostring(value))
  if not value or string.find(value, "^%d") == nil then
    return default
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

  return default
end

---Set value if it doesn't exist in the globals.
---@param key string
---@param default any
---@return GlobalValues
function utils:GlobalGetOrSetTypedValue(key, default)
  local value = self:GlobalGetTypedValue(key)

  -- utils:Log("GetOrSet:", key, tostring(value), tostring(default))

  if value ~= nil then
    return value
  elseif default ~= nil then
    self:GlobalSetTypedValue(key, default)
  end

  return default
end

return utils
