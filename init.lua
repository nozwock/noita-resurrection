local ONE_HP = 0.04

local respawn_position = {
	x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
	y = tonumber(MagicNumbersGetValue(
		"DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85
local respawn_messages = { "But you're better now.", "Let's get you fixed up.", "Take a deep breath.",
	"Oooh! What in blazes...?" }

function OnWorldPreUpdate()
	local players = EntityGetWithTag("player_unit")
	if not (players == nil or #players == 0) then
		for _, player_id in ipairs(players) do
			local damage_models = EntityGetComponent(player_id, "DamageModelComponent")
			if damage_models == nil or #damage_models == 0 then
				GamePrint(string.format("Error: Missing DamageModelComponent for entity %d", player_id))
			else
				for _, damage_model in ipairs(damage_models) do
					ComponentSetValue(damage_model, "wait_for_kill_flag_on_death", "1")
					if tonumber(ComponentGetValue(damage_model, "hp")) < ONE_HP then
						ComponentSetValue(damage_model, "hp",
							assert(ComponentGetValue(damage_model, "max_hp")))
						GameRegenItemActionsInPlayer(player_id)
						local game_effect = GetGameEffectLoadTo(player_id, "BLINDNESS", true)
						if game_effect ~= nil then
							ComponentSetValue(game_effect, "frames", "120")
						end
						if not GameHasFlagRun("ending_game_completed") then
							EntitySetTransform(player_id, respawn_position.x, respawn_position.y)
							EntityLoad("data/entities/misc/matter_eater.xml", respawn_position.x, respawn_position.y) -- not sure why this
							GamePrintImportant("You Have Died", respawn_messages[Random(1, #respawn_messages)])
						else
							ComponentSetValue(damage_model, "kill_now", "1")
						end
					end
				end
			end
		end
	else
		players = EntityGetWithTag("polymorphed")
		if players ~= nil then
			for _, player_id in ipairs(players) do
				if IsPlayer(player_id) and (
						EntityGetFirstComponent(player_id, "AnimalAIComponent") == nil and
						EntityGetFirstComponent(player_id, "PhysicsAIComponent") == nil and
						EntityGetFirstComponent(player_id, "WormAIComponent") == nil and
						EntityGetFirstComponent(player_id, "AdvancedFishAIComponent") == nil
					) then
					local damage_models = EntityGetComponent(player_id, "DamageModelComponent")
					if damage_models == nil or #damage_models == 0 then
						GamePrint(string.format("Error: Missing DamageModelComponent for entity %d", player_id))
					else
						for _, damage_model in ipairs(damage_models) do
							ComponentSetValue(damage_model, "wait_for_kill_flag_on_death", "1")
							if tonumber(ComponentGetValue(damage_model, "hp")) < ONE_HP then
								ComponentSetValue(damage_model, "hp",
									assert(ComponentGetValue(damage_model, "max_hp")))
								SetRandomSeed(EntityGetTransform(player_id))
								GamePrintImportant("Polymorph Is Garbage",
									respawn_messages[Random(1, #respawn_messages)])
							end
						end
					end
				end
			end
		end
	end
end
