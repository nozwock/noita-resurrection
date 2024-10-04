---@class const
local const = {
  globals = {
    death_count = "death_count",
    revive_count = "revive_count",
    level_on_revive_gain = "level_on_revive_gain",
    respawn_position = "respawn_position",
    respawn_system = "respawn_system",
  },
  MOD_ID = "resurrection", -- This should match the name of your mod's folder.
  RESPAWN_SYSTEM = { UNLIMITED = 1, LIMITED = 2, META_LEVELING = 3 },
}

return const
