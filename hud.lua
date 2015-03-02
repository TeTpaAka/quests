local show_max = 10 -- the maximum visible quests.

local hud_config = { position = {x = 1, y = 0.2},
			offset = { x = -200, y = 0},
			number = 0xAAAA00 }

-- call this function to enable the HUD for the player that shows his quests
-- the HUD can only show up to show_max quests
function quests.show_hud(playername) 
	if (quests.hud[playername] ~= nil) then
		return
	end
	local hud = {
		hud_elem_type = "text",
		alignment = {x=1, y=1},
		position = {x = hud_config.position.x, y = hud_config.position.y},
		offset = {x = hud_config.offset.x, y = hud_config.offset.y},
		number = hud_config.number,
		text = "Quests:" }



	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end
	quests.hud[playername] = {}
	table.insert(quests.hud[playername], { value=0, id=player:hud_add(hud) })
	minetest.after(0, quests.update_hud, playername)
end

-- call this method to hide the hud
function quests.hide_hud(playername)
	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end
	for _,quest in pairs(quests.hud[playername]) do
		player:hud_remove(quest.id)
		if (quest.id_background ~= nil) then
			player:hud_remove(quest.id_background)
		end
		if (quest.id_bar ~= nil) then
			player:hud_remove(quest.id_bar)
		end
	end
	quests.hud[playername] = nil
end


local function get_quest_hud_string(questname, quest) 
	local quest_string = quests.registered_quests[questname].title 
	if (quests.registered_quests[questname].max ~= 1) then
		quest_string = quest_string .. "\n               ("..quests.round(quest.value, 2).."/"..quests.registered_quests[questname].max..")"
	end
	return quest_string
end

-- only for internal use
-- updates the hud
function quests.update_hud(playername) 
	if (quests.hud[playername] == nil or quests.active_quests[playername] == nil) then
		return
	end
	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end

	-- Check for changes in the hud
	local i = 2 -- the first element is the title
	local change = false
	local visible = {}
	local remove = {}
	for j,hud_element in ipairs(quests.hud[playername]) do
		if (hud_element.name ~= nil) then
			if (quests.active_quests[playername][hud_element.name] ~= nil) then
				if (hud_element.value ~= quests.active_quests[playername][hud_element.name].value) then
					hud_element.value = quests.active_quests[playername][hud_element.name].value
					if (hud_element.value == quests.registered_quests[hud_element.name].max) then
						player:hud_change(hud_element.id, "number", 0x00BB00)
					end
					player:hud_change(hud_element.id, "text", get_quest_hud_string(hud_element.name, quests.active_quests[playername][hud_element.name]))
					if (hud_element.id_bar ~= nil) then
						player:hud_change(hud_element.id_bar, "number", math.floor(40 * hud_element.value / quests.registered_quests[hud_element.name].max))
					end
				end
				if (i ~= j) then
					player:hud_change(hud_element.id, "offset", { x= hud_config.offset.x, y=hud_config.offset.y + (i-1) *40})
					if (hud_element.id_background ~= nil) then
						player:hud_change(hud_element.id_background, "offset", { x= hud_config.offset.x, y=hud_config.offset.y + (i-1) *40 + 22})
					end
					if (hud_element.id_bar ~= nil) then
						player:hud_change(hud_element.id_bar, "offset", { x= hud_config.offset.x, y=hud_config.offset.y + (i-1) *40 + 24})
					end

				end
				visible[hud_element.name] = true
				i = i + 1
			else 
				player:hud_remove(hud_element.id)
				if (hud_element.id_background ~= nil) then
					player:hud_remove(hud_element.id_background)
				end
				if (hud_element.id_bar ~= nil) then
					player:hud_remove(hud_element.id_bar)
				end
				table.insert(remove, j)
			end
		end
	end
	--remove ended quests
	if (remove[1] ~= nil) then
		for _,j in ipairs(remove) do
			table.remove(quests.hud[playername], j)
			i = i - 1
		end
	end
	
	if (i >= show_max + 1) then
		return
	end
	-- add new quests
	local counter = i - 1
	for questname,questspecs in pairs(quests.active_quests[playername]) do
		if (not visible[questname]) then
			local id = player:hud_add({	hud_elem_type = "text",
							alignment = { x=1, y= 1 },
							position = {x = hud_config.position.x, y = hud_config.position.y},
							offset = {x = hud_config.offset.x, y = hud_config.offset.y + counter * 40},
							number = hud_config.number,
							text = get_quest_hud_string(questname, questspecs) })
			local id_background
			local id_bar
			if (quests.registered_quests[questname].max ~= 1) then
				id_background = player:hud_add({ hud_elem_type = "image",
								 scale = { x = 1, y = 1 },
								 alignment = { x = 1, y = 1 },
								 position = { x = hud_config.position.x, y = hud_config.position.y },
								 offset = { x = hud_config.offset.x, y = hud_config.offset.y + counter * 40 + 22 },
								 text = "quests_questbar_background.png" })
				id_bar = player:hud_add({hud_elem_type = "statbar",
							 scale = { x = 1, y = 1 },
							 alignment = { x = 1, y = 1 },
							 position = { x = hud_config.position.x, y = hud_config.position.y },
							 offset = { x = hud_config.offset.x + 2, y = hud_config.offset.y + counter * 40 + 24 },
							 number = math.floor(40 * questspecs.value / quests.registered_quests[questname].max),
							 text = "quests_questbar.png" })
			end

			table.insert(quests.hud[playername], {  name          = questname, 
								id            = id,
								id_background = id_background,
								id_bar        = id_bar,
								value         = questspecs.value })
			counter = counter + 1
			if (counter >= show_max + 1) then
				break
			end
		end
	end
end



-- show the HUDs
for playername,id in pairs(quests.hud) do
	if (id ~= nil) then
		quests.hud[playername] = nil
		minetest.after(10, function(playername)
			quests.show_hud(playername)
			quests.update_hud(playername)
		end, playername)
	end
end


