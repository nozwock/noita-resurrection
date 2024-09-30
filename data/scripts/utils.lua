local mod = {}

-- Recursive `pairs`.
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

return mod
