local show_max = 10 -- the maximum visible quests.

-- reading previous quests
local file = io.open(minetest.get_worldpath().."/quests", "r")
if file then
	print "Reading quests..."
	quests = minetest.deserialize(file:read("*all"))
	file:close()
end
quests = quests or {}
quests.registered_quests = {}
quests.active_quests = quests.active_quests or {}
quests.successfull_quests = quests.successfull_quests or {}
quests.failed_quests = quests.failed_quests or {}
quests.hud = quests.hud or {}


quests.formspec_lists = {}

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

local function round(num, n) 
	local mult = 10^(n or 0)
	return math.floor(num * mult + .5) / mult
end

local function get_quest_hud_string(questname, quest) 
	local quest_string = quests.registered_quests[questname].title 
	if (quests.registered_quests[questname].max ~= 1) then
		quest_string = quest_string .. "\n               ("..round(quest.value, 2).."/"..quests.registered_quests[questname].max..")"
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



-- registers a quest for later use
--
-- questname is the name of the quest to identify it later
-- 	it should follow the naming conventions: "modname:questname"
-- quest is a table in the following format
-- 	{
--	  title, 		-- is shown to the player and should contain usefull information about the quest.
--	  description, 		-- a small description of the mod.
-- 	  max,			-- is the desired maximum. If max is 1, no maximum is displayed. defaults to 1
-- 	  autoaccept, 		-- is true or false, wether the result of the quest should be dealt by this mode or the registering mod.
-- 	  callback 		-- when autoaccept is true, at the end of the quest, it gets removed and callback is called.
--	}
--
-- returns true, when the quest was successfully registered
-- returns falls, when there was already such a quest
function quests.register_quest(questname, quest)
	if (quests.registered_quests[questname] ~= nil) then
		return false -- The quest was not registered since there already a quest with that name
	end
	quests.registered_quests[questname] = 
		{ title       = quest.title or "missing title",
		  description = quest.description or "missing description",
		  max         = quest.max or 1,
		  autoaccept  = quest.autoaccept or false,
		  callback    = quest.callback, }
	return true
end

-- starts a quest for a specified player
--
-- playername - the name of the player
-- questname  - the name of the quest, which was registered with quests.register_quest
--
-- returns false on failure
-- returns true if the quest was started
function quests.start_quest(playername, questname) 
	if (quests.registered_quests[questname] == nil) then
		return false
	end
	if (quests.active_quests[playername] == nil) then
		quests.active_quests[playername] = {}
	end
	if (quests.active_quests[playername][questname] ~= nil) then
		return false -- the player has already this quest
	end
	quests.active_quests[playername][questname] = {value = 0}

	quests.update_hud(playername)
	return true
end

-- when something happens that has effect on a quest, a mod should call this method
-- playername is the name of the player
-- questname is the quest which gets updated
-- the quest gets updated by value
-- this method calls a previously specified callback if autoaccept is true
-- returns true if the quest is finished
-- returns false if there is no such quest or the quest continues
function quests.update_quest(playername, questname, value) 
	if (quests.active_quests[playername] == nil) then
		quests.active_quests[playername] = {}
	end
	if (quests.active_quests[playername][questname] == nil) then
		return false -- there is no such quest
	end
	if (quests.active_quests[playername][questname].finished) then
		return false -- the quest is already finished
	end
	if (value == nil) then
		return false -- no value given
	end
	quests.active_quests[playername][questname]["value"] = quests.active_quests[playername][questname]["value"] + value
	if (quests.active_quests[playername][questname]["value"] >= quests.registered_quests[questname]["max"]) then
		quests.active_quests[playername][questname]["value"] = quests.registered_quests[questname]["max"]
		if (quests.registered_quests[questname]["autoaccept"]) then
			if (quests.registered_quests[questname]["callback"] ~= nil) then
				quests.registered_quests[questname]["callback"](playername, questname)
			end
			quests.accept_quest(playername,questname)
			quests.update_hud(playername)
		end
		return true -- the quest is finished
	end
	quests.update_hud(playername)
	return false -- the quest continues
end

-- When the mod handels the end of quests himself, e.g. you have to talk to somebody to finish the quest,
-- you have to call this method to end a quest
-- returns true, when the quest is completed
-- returns false, when the quest is still ongoing
function quests.accept_quest(playername, questname)
	if (quests.active_quests[playername][questname] and not quests.active_quests[playername][questname].finished) then
		if (quests.successfull_quests[playername] == nil) then
			quests.successfull_quests[playername] = {}
		end
		if (quests.successfull_quests[playername][questname] ~= nil) then
			quests.successfull_quests[playername][questname].count = quests.successfull_quests[playername][questname].count + 1
		else
			quests.successfull_quests[playername][questname] = {count = 1}
		end
		quests.active_quests[playername][questname].finished = true
		minetest.after(3, function(playername, questname)
			quests.active_quests[playername][questname] = nil
			minetest.after(1,quests.update_hud,playername)
		end, playername, questname)
		return true -- the quest is finished, the mod can give a reward
	end
	return false -- the quest hasn't finished
end

-- call this method, when you want to end a quest even when it was not finished
-- example: the player failed
--
-- returns false if the quest was not aborted
-- returns true when the quest was aborted
function quests.abort_quest(playername, questname) 
	if (questname == nil) then
		return false
	end	
	if (quests.failed_quests[playername] == nil) then
		quests.failed_quests[playername] = {}
	end
	if (quests.active_quests[playername][questname] == nil) then
		return false
	end
	if (quests.failed_quests[playername][questname] ~= nil) then
		quests.failed_quests[playername][questname].count = quests.failed_quests[playername][questname].count + 1
	else
		quests.failed_quests[playername][questname] = { count = 1 }
	end

	quests.active_quests[playername][questname].finished = true
	for _,quest in ipairs(quests.hud[playername]) do
		if (quest.name == questname) then
			local player = minetest.get_player_by_name(playername)
			player:hud_change(quest.id, "number", 0xAD0000)
		end
	end
	minetest.after(3, function(playername, questname)
		quests.active_quests[playername][questname] = nil
		minetest.after(1,quests.update_hud,playername)
	end, playername, questname)
end

-- construct the questlog
function quests.create_formspec(playername, tab)
	local queststringlist = {}
	local questlist = {}
	quests.formspec_lists[playername] = quests.formspec_lists[playername] or {}
	quests.formspec_lists[playername].id = 1
	quests.formspec_lists[playername].list = {}
	tab = tab or quests.formspec_lists[playername].tab or "1"
	if (tab == "1") then
		questlist = quests.active_quests[playername] or {}
	elseif (tab == "2") then
		questlist = quests.successfull_quests[playername] or {}
	elseif (tab == "3") then
		questlist = quests.failed_quests[playername] or {}
	end
	quests.formspec_lists[playername].tab = tab
		
	for questname,questspecs in pairs(questlist) do
		if (questspecs.finished == nil) then
			local queststring = quests.registered_quests[questname]["title"]
			if (questspecs["count"] and questspecs["count"] > 1) then
				queststring = queststring .. " - " .. questspecs["count"]
			elseif(not questspecs["count"] and quests.registered_quests[questname]["max"] ~= 1) then
				queststring = queststring .. " - (" .. round(questspecs["value"], 2) .. "/" .. quests.registered_quests[questname]["max"] .. ")"
			end
			table.insert(queststringlist, queststring)
			table.insert(quests.formspec_lists[playername].list, questname)
		end
	end
	local formspec = "size[7,10]"..
			"tabheader[0,0;header;Open quests,Finished quests,Failed quests;" .. tab .. "]"..
			"textlist[0.25,0.25;6.5,7.5;questlist;"..table.concat(queststringlist, ",") .. ";1;false]"
	if (quests.formspec_lists[playername].tab == "1") then
		formspec = formspec .."button[0.25,8;3,.7;abort;Abort quest]"
	end
	formspec = formspec .. "button[3.75,8;3,.7;config;Configure]"..
			"button[.25,9;3,.7;info;Info]"..
			"button_exit[3.75,9;3,.7;exit;Exit]"
	return formspec
end

-- construct the configuration
function quests.create_config(playername)
	local formspec = "size[7,3]" .. 
			"checkbox[.25,.25;enable;Enable HUD;" 
	if(quests.hud[playername] ~= nil) then 
		formspec = formspec .. "true"
	else
		formspec = formspec ..  "false"
	end 
	formspec = formspec .. "]"..
			"button[.25,1.25;3,.7;return;Return]"
	return formspec
end

-- construct the info formspec
function quests.create_info(playername, questname)
	local formspec = "size[7,6.5]" ..
			 "label[0.5,0.5;" 

	if (questname) then
		formspec = formspec .. quests.registered_quests[questname].title .. "]" ..
				 "textarea[.5,1.5;6,4.5;description;;" .. quests.registered_quests[questname].description .. "]"

		if (quests.formspec_lists[playername].tab == "1") then
			formspec = formspec .. "button[.5,6;3,.7;abort;Abort quest]"
		end
	else
		formspec = formspec .. "No quest specified.]"
	end
	formspec = formspec .. "button[3.25,6;3,.7;return;Return]"
	return formspec
end

-- chatcommand to see a full list of quests:
minetest.register_chatcommand("quests", {
	params = "",
	description = "Show all open quests",
	func = function(name, param)
		minetest.show_formspec(name, "quests:questlog", quests.create_formspec(name))
		return true
	end
})

-- Handle the return fields of the questlog
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if (player == nil) then
		return
	end
	local playername = player:get_player_name();
	if (playername == "") then
		return
	end
	if (formname == "quests:questlog") then
		if (fields["header"]) then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername, fields["header"]))
			return
		end
		if (fields["questlist"]) then
			local event = minetest.explode_textlist_event(fields["questlist"])
			if (event.type == "CHG") then
				quests.formspec_lists[playername].id = event.index
			end
		end
		if (fields["abort"]) then
			if (quests.formspec_lists[playername].id == nil) then
				return
			end
			quests.abort_quest(playername, quests.formspec_lists[playername]["list"][quests.formspec_lists[playername].id]) 
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		end
		if (fields["config"]) then
			minetest.show_formspec(playername, "quests:config", quests.create_config(playername))
		end
		if (fields["info"]) then
			minetest.show_formspec(playername, "quests:info", quests.create_info(playername, quests.formspec_lists[playername].list[quests.formspec_lists[playername].id]))
		end
	end
	if (formname == "quests:config") then
		if (fields["enable"]) then
			if (fields["enable"] == "true") then	
				quests.show_hud(playername)
			else
				quests.hide_hud(playername)
			end
		end
		if (fields["return"]) then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		end
	end
	if (formname == "quests:info") then
		if (fields["abort"]) then
			if (quests.formspec_lists[playername].id == nil) then
				return
			end
			quests.abort_quest(playername, quests.formspec_lists[playername]["list"][quests.formspec_lists[playername].id]) 
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		end
		if (fields["return"]) then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		end
	end
end)

-- write the quests to file
minetest.register_on_shutdown(function() 
	print "Writing quests to file"
	for playername, quest in pairs(quests.active_quests) do
		for questname, questspecs in pairs(quest) do
			if (questspecs.finished) then
				quests.active_quests[playername][questname] = nil -- make sure no finished quests are saved as unfinished
			end
		end
	end
	local file = io.open(minetest.get_worldpath().."/quests", "w")
	if (file) then
		file:write(minetest.serialize({ --registered_quests  = quests.registered_quests,
						active_quests      = quests.active_quests,
						successfull_quests = quests.successfull_quests,
						failed_quests	   = quests.failed_quests,
						hud 		   = quests.hud}))
		file:close()
	end
end)
