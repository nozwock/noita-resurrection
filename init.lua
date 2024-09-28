dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/debug/keycodes.lua")

local ONE_HP = 0.04

local respawn_position = {
	x = tonumber(MagicNumbersGetValue("DESIGN_PLAYER_START_POS_X")),
	y = tonumber(MagicNumbersGetValue(
		"DESIGN_PLAYER_START_POS_Y"))
} -- 227, -85

-- Why am I using different styling for function names? Don't think about it.

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

local function GuiDecoratedTitle(gui, id, y, title)
	title = string.upper(title)

	local edge_w, _ = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_left.png", 1)
	local middle_w, _ = GuiGetImageDimensions(gui, "data/ui_gfx/decorations/piece_small_middle.png", 1)
	local text_w, _ = GuiGetTextDimensions(gui, title, 1, 2, "data/fonts/font_pixel_huge.xml")

	local padding_scale = 6
	local middle_scale = math.ceil(text_w / middle_w)
	local decor_w = edge_w * 2 + middle_w * (middle_scale + padding_scale * 2)

	local w, _ = GuiGetScreenDimensions(gui)
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
	GuiText(gui, 0, 5, title, 1, "data/fonts/font_pixel_huge.xml")
	GuiLayoutEnd(gui)
end


local gui = GuiCreate()
local draw_respawn_ui = false
local respawn_ui_update = nil

local function CreateRespawnGui(gui, on_ok, on_cancel)
	local hovered = {}
	local hover_prefix = ">"

	return function()
		if not draw_respawn_ui then
			return
		end

		local id
		local new_id = IdFactory()
		GuiStartFrame(gui)

		GuiZSet(gui, -1000)
		GuiImage(gui, new_id(), 0, 0, "data/debug/ui_background.png", 1, 1000)
		GuiZSet(gui, -1100)

		local title_text = string.upper("Unthethered")
		GuiDecoratedTitle(gui, new_id(), 70, title_text)

		local ok_text = "  Wake Up"
		local cancel_text = "  Wisp Away"
		local ok_text_w, _ = GuiGetTextDimensions(gui, ok_text)
		local cancel_text_w, _ = GuiGetTextDimensions(gui, cancel_text)

		local x_scale = centered_x(gui, ok_text_w + cancel_text_w + 14 + 2) -- 2 is the spacing
		GuiLayoutBeginHorizontal(gui, x_scale, 78)

		id = new_id()
		if hovered[id] then
			GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1) -- doesn't seem to be working
			ok_text = ok_text:gsub("^  *", hover_prefix)
		end

		if GuiButton(gui, id, 0, 0, ok_text) then
			draw_respawn_ui = false
			on_ok()
		end
		hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))

		id = new_id()
		if hovered[id] then
			GuiColorSetForNextWidget(gui, 1, 1, 0.5, 1)
			cancel_text = cancel_text:gsub("^ *", hover_prefix)
		end

		if GuiButton(gui, id, 14, 0, cancel_text) then
			draw_respawn_ui = false
			on_cancel()
		end
		hovered[id] = select(3, GuiGetPreviousWidgetInfo(gui))

		GuiLayoutEnd(gui)
	end
end


function OnWorldPreUpdate()
	if respawn_ui_update ~= nil and draw_respawn_ui then
		respawn_ui_update()
		return
	end

	local player_id = EntityGetWithTag("player_unit")[1] or EntityGetWithTag("polymorphed_player")[1]
	if not player_id then return end

	local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
	if not damage_model then return end

	ComponentSetValue2(damage_model, "wait_for_kill_flag_on_death", true)

	if ComponentGetValue2(damage_model, "hp") >= ONE_HP then return end

	local controls = EntityGetFirstComponent(player_id, "ControlsComponent")
	if not controls then return end

	ComponentSetValue2(controls, "enabled", false)

	respawn_ui_update = CreateRespawnGui(gui,
		function()
			local game_effect = GetGameEffectLoadTo(player_id, "BLINDNESS", true)
			if game_effect then
				ComponentSetValue2(game_effect, "frames", 120)
			end

			ComponentSetValue2(damage_model, "hp",
				ComponentGetValue2(damage_model, "max_hp"))
			GameRegenItemActionsInPlayer(player_id)

			ComponentSetValue2(controls, "enabled", true)
			if not GameHasFlagRun("ending_game_completed") then
				EntitySetTransform(player_id, respawn_position.x, respawn_position.y)
				EntityLoad("data/entities/misc/matter_eater.xml", respawn_position.x, respawn_position.y) -- Not sure why this exists
			else
				ComponentSetValue2(damage_model, "kill_now", true)
			end
		end,
		function()
			ComponentSetValue2(controls, "enabled", true)
			ComponentSetValue2(damage_model, "kill_now", true)
		end)

	draw_respawn_ui = true
end
