dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")

local ONE_HP = 0.04

local respawn_position = {
	x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
	y = tonumber(MagicNumbersGetValue(
		"DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85
local respawn_messages = { "But you're better now.", "Let's get you fixed up.", "Take a deep breath.",
	"Oooh! What in blazes...?" }

local function IdFactory()
	local id_ = 0

	return function()
		id_ = id_ + 1
		return id_
	end
end

local function centered_x(gui, object_width)
	local w, _ = GuiGetScreenDimensions(gui)
	return math.floor((w / 2 - object_width / 2) / w * 100)
end

local function GuiDecoratedText(gui, id, y, title)
	title = string.upper(title)

	local edge_w, edge_h = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_left.png", 1)
	local middle_w, middle_h = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_middle.png", 1)
	local text_w, _ = GuiGetTextDimensions(gui, title, 2)

	local padding_scale = 6
	local middle_scale = math.ceil(text_w / middle_w)
	local decor_w = edge_w * 2 + middle_w * (middle_scale + padding_scale * 2)

	local w, h = GuiGetScreenDimensions(gui)
	local decor_x_scale = math.floor((w / 2 - decor_w / 2) / w * 100)
	local text_x_scale = math.floor((w / 2 - text_w / 2) / w * 100)

	GuiLayoutBeginHorizontal(gui, decor_x_scale, y, false, 0, 0)
	GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_left.png", 1, 1, 0, 0,
		GUI_RECT_ANIMATION_PLAYBACK.Loop)
	GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_middle.png", 1, middle_scale + padding_scale * 2,
		1, 0, GUI_RECT_ANIMATION_PLAYBACK.Loop)
	GuiImage(gui, id, 0, 0, "data/ui_gfx/decorations/piece_small_right.png",
		1, 1, 0, 0,
		GUI_RECT_ANIMATION_PLAYBACK.Loop)
	GuiLayoutEnd(gui)

	GuiLayoutBeginVertical(gui, text_x_scale, y)
	GuiText(gui, 0, 2, title, 2)
	GuiLayoutEnd(gui)
end


local gui = GuiCreate()
local draw_ui = false

local function CreateRespawnGui(gui, on_ok, on_cancel)
	return function()
		if not draw_ui then
			return
		end

		local newid = IdFactory()
		GuiStartFrame(gui)

		local title_text = string.upper("Unthethered")
		GuiDecoratedText(gui, newid(), 70, title_text)

		local ok_text = "Wake Up"
		local ok_text_w, _ = GuiGetTextDimensions(gui, ok_text)
		local cancel_text = "Wake Up"
		local cancel_text_w, _ = GuiGetTextDimensions(gui, cancel_text)

		local x_scale = centered_x(gui, ok_text_w + cancel_text_w + 14 + 2)
		GuiLayoutBeginHorizontal(gui, x_scale, 80)
		if GuiButton(gui, newid(), 0, 0, "Wake Up") then
			on_ok()
			-- draw_ui = not draw_ui
		end
		if GuiButton(gui, newid(), 14, 0, "Wisp Away") then
			on_cancel()
			-- draw_ui = not draw_ui
		end
		GuiLayoutEnd(gui)
	end
end

local respawn_ui_update = CreateRespawnGui(gui, function()
	print("a-ok")
end, function()
	print("no revives for you")
end)

function OnWorldPreUpdate()
	if InputIsKeyJustUp(Key_k) then
		GamePrintImportant("Title blablablablablablablabla", "Bruh")
	end
	if InputIsKeyJustUp(Key_p) then
		draw_ui = not draw_ui
	end

	respawn_ui_update()

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
