dofile("mods/resurrection/files/scripts/defs.lua")

---@class utils
local mod = {}

---Recursive `pairs`.
---@param t table
---@return fun():string|number, unknown
function mod:rpairs(t)
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

---@param id string
function mod:GetModSettingId(id)
  return MOD_ID .. "." .. id
end

return mod
