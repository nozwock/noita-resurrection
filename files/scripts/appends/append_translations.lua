local game_translation_file = "data/translations/common.csv"
local mod_translation_files = {
  "mods/resurrection/files/translations/common.csv",
}
local translations = ModTextFileGetContent(game_translation_file)
for i = 1, #mod_translation_files do
  translations = translations .. "\n" .. ModTextFileGetContent(mod_translation_files[i])
end

translations = translations:gsub("\r+", ""):gsub("\n\n+", "\n")

ModTextFileSetContent(game_translation_file, translations)
