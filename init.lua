local function is_list_empty(list)
	return list == nil or #list == 0
end

local ONE_HP = 0.04
local respawn_pos = { tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")), tonumber(MagicNumbersGetValue(
	"DESIGN_PLAYER_START_POS_Y")) } -- 227, -85
local respawn_messages = { "But you're better now.", "Let's get you fixed up.", "Take a deep breath.",
	"Oooh! What in blazes...?" }

function OnWorldPreUpdate()
	local players, damage_models, game_effect, found_workshop_guard, respawn_position_x, respawn_position_y, pos_x, pos_y, variable_storage_components, game_stats_component

	players = EntityGetWithTag("player_unit")
	if not is_list_empty(players) then
		for _, player_id in ipairs(players) do
			damage_models = EntityGetComponent(player_id, "DamageModelComponent")
			if damage_models == nil or #damage_models == 0 then
				GamePrintImportant("Error", "Missing DamageModelComponent")
			else
				for _, damage_model in ipairs(damage_models) do
					ComponentSetValue(damage_model, "wait_for_kill_flag_on_death", "1")
					if tonumber(ComponentGetValue(damage_model, "hp")) < ONE_HP then
						ComponentSetValue(damage_model, "hp",
							assert(ComponentGetValue(damage_model, "max_hp")))
						GameRegenItemActionsInPlayer(player_id)
						game_effect = GetGameEffectLoadTo(player_id, "BLINDNESS", true)
						if game_effect ~= nil then
							ComponentSetValue(game_effect, "frames", "120")
						end
						found_workshop_guard = false
						respawn_position_x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")) -- 227
						respawn_position_y = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_Y")) -- -85
						pos_x, pos_y = EntityGetTransform(player_id)
						SetRandomSeed(pos_x, pos_y)
						pos_y = pos_y - 4
						for _, enemy_id in pairs(EntityGetInRadiusWithTag(pos_x, pos_y, 96, "enemy")) do
							if EntityGetName(enemy_id) == "$animal_necromancer_shop" and not EntityHasTag(enemy_id, "polymorphable_NOT") then
								found_workshop_guard = true
							end
						end
						if not found_workshop_guard then
							variable_storage_components = EntityGetComponent(player_id, "VariableStorageComponent")
							if variable_storage_components ~= nil and #variable_storage_components ~= 0 then
								for _, variable_storage_component in ipairs(variable_storage_components) do
									if ComponentGetValue(variable_storage_component, "name") == "respawn_location" then
										pos_x = ComponentGetValue(variable_storage_component, "value_string")
										if pos_x ~= nil then respawn_position_x = tonumber(pos_x) end
										pos_y = ComponentGetValue(variable_storage_component, "value_int")
										if pos_y ~= nil then respawn_position_y = tonumber(pos_y) end
									end
								end
							end
						end
						if not GameHasFlagRun("ending_game_completed") then
							EntitySetTransform(player_id, respawn_position_x, respawn_position_y)
							EntityLoad("data/entities/misc/matter_eater.xml", respawn_position_x, respawn_position_y)
							GamePrintImportant("You have died.", respawn_messages[Random(1, #respawn_messages)])
						else
							ComponentSetValue(damage_model, "kill_now", "1")
						end
					end
				end
			end
		end
	else
		players = EntityGetWithTag("polymorphed")
		if players ~= nil and #players ~= 0 then
			for _, player_id in ipairs(players) do -- The guard above is unnecessary due to ipairs
				game_stats_component = EntityGetFirstComponent(player_id, "GameStatsComponent")
				if game_stats_component ~= nil and ComponentGetValue(game_stats_component, "is_player") == "1" then
					if EntityGetFirstComponent(player_id, "AnimalAIComponent") == nil and
						EntityGetFirstComponent(player_id, "PhysicsAIComponent") == nil and
						EntityGetFirstComponent(player_id, "WormAIComponent") == nil and
						EntityGetFirstComponent(player_id, "AdvancedFishAIComponent") == nil then
						damage_models = EntityGetComponent(player_id, "DamageModelComponent")
						if damage_models == nil or #damage_models == 0 then
							GamePrintImportant("Error", "Missing DamageModelComponent")
						else
							for _, damage_model_component in ipairs(damage_models) do
								ComponentSetValue(damage_model_component, "wait_for_kill_flag_on_death", "1")
								if tonumber(ComponentGetValue(damage_model_component, "hp")) < ONE_HP then
									ComponentSetValue(damage_model_component, "hp",
										ComponentGetValue(damage_model_component, "max_hp"))
									SetRandomSeed(EntityGetTransform(player_id))
									GamePrintImportant("Polymorph is garbage.",
										respawn_messages[Random(1, #respawn_messages)])
								end
							end
						end
					end
				end
			end
		end
	end
end
