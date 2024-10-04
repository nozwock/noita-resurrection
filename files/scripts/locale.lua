local const = dofile_once("mods/resurrection/files/scripts/const.lua") ---@type const

-- todo: If there's ever a demand for mod settings locale, then just use a csv parser-
-- https://github.com/FourierTransformer/ftcsv

---For local use only.
---@param text string
---@param sep string|nil
function Locale(text, sep)
  ---@param key string
  local function GetLocalText(key)
    return GameTextGetTranslatedOrNot(ResolveLocalKey(key, sep))
  end

  return text:gsub("%$%w[%w_]*", GetLocalText)
end

---@param key string
---@param sep string|nil
function ResolveLocalKey(key, sep)
  if sep == nil then
    sep = "_"
  end
  return "$" .. const.MOD_ID .. sep .. key:gsub("^%$", "")
end
