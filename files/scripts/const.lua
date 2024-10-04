---@class const
local const = {
  globals = {
    deaths = "deaths",
    respawns = "respawns",
    level_on_respawn_gain = "level_on_respawn_gain",
    respawn_position = "respawn_position",
    respawn_system = "respawn_system",
  },
  MOD_ID = "resurrection", -- This should match the name of your mod's folder.
  RESPAWN_SYSTEM = { UNLIMITED = 1, LIMITED = 2, META_LEVELING = 3 },
}

return const
