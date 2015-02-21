quests = {}
quests.registered_quests = {}
quests.hud = {}

local show_max = 10 -- the maximum visible quests.

-- reading previous quests
local file = io.open(minetest.get_worldpath().."/quests", "r")
if file then
	print "Reading quests..."
	quests = minetest.deserialize(file:read("*all"))
	file:close()
end
quests.formspec_lists = {}

-- call this function to enable the HUD for the player that shows his quests
-- the HUD can only show up to show_max quests
function quests.show_hud(playername) 
	if (quests.hud[playername] ~= nil) then
		return
	end
	local hud = {
		hud_elem_type = "text",
		position = {x = 1, y = 0.3},
		offset = {x = -150, y = 0},
		scale = {x = 100, y = -50},
		number = 0xCACA00,
		text = "Open Quests:" }



	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end
	quests.hud[playername] = player:hud_add(hud)
	minetest.after(0, quests.update_hud, playername)
end

-- call this method to hide the hud
function quests.hide_hud(playername)
	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end
	player:hud_remove(quests.hud[playername])
	quests.hud[playername] = nil
end

local function round(num, n) 
	local mult = 10^(n or 0)
	return math.floor(num * mult + .5) / mult
end

-- only for internal use
-- updates the hud
function quests.update_hud(playername) 
	if (quests.hud[playername] == nil) then 
		return
	end
	local player = minetest.get_player_by_name(playername)
	if (player == nil) then
		return
	end
	local counter = 0
	local text = "Open Quests:\n\n"
	if (quests.registered_quests[playername] ~= nil) then
		for questname,questspecs in pairs(quests.registered_quests[playername]) do
			text = text .. questspecs["title"] .. "\n"
			if (questspecs["max"] ~= 1) then
				text = text .."                (" .. round(questspecs["value"], 2) .. "/" .. questspecs["max"] .. ")\n"
			end
			counter = counter + 1
			if (counter >= show_max) then
				break
			end
		end
	end
	player:hud_change(quests.hud[playername], "text", text)
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



-- registers a quest for the specified player
--
-- playername is the name of the player, who gets the quest
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
function quests.register_quest(playername, questname, quest)
	if (quests.registered_quests[playername] == nil) then
		quests.registered_quests[playername] = {}
	end
	if (quests.registered_quests[playername][questname] ~=nil) then
		return false -- The quest was not registered since there already a quest with that name
	end
	quests.registered_quests[playername][questname] = 
		{ value       = 0,
		  title       = quest.title,
		  description = quest.description,
		  max         = quest.max or 1,
		  autoaccept  = quest.autoaccept,
		  callback    = quest.callback, }
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
	if (quests.registered_quests[playername] == nil) then
		quests.registered_quests[playername] = {}
	end
	if (quests.registered_quests[playername][questname] == nil) then
		return false -- there is no such quest
	end
	if (value == nil) then
		return false -- no value given
	end
	quests.registered_quests[playername][questname]["value"] = quests.registered_quests[playername][questname]["value"] + value
	if (quests.registered_quests[playername][questname]["value"] >= quests.registered_quests[playername][questname]["max"]) then
		quests.registered_quests[playername][questname]["value"] = quests.registered_quests[playername][questname]["max"]
		if (quests.registered_quests[playername][questname]["autoaccept"]) then
			if (quests.registered_quests[playername][questname]["callback"] ~= nil) then
				quests.registered_quests[playername][questname]["callback"](playername, questname)
			end
			quests.registered_quests[playername][questname] = nil
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
	if (quests.registered_quests[playername][questname]) then
		quests.registered_quests[playername][questname] = nil
		quests.update_hud(playername)
		return true -- the quest is finished, the mod can give a reward
	end
	return false -- the quest hasn't finished
end

-- call this method, when you want to end a quest even when it was not finished
-- example: the player failed
function quests.abort_quest(playername, questname) 
	if (questname == nil) then
		return
	end
	quests.registered_quests[playername][questname] = nil
	quests.update_hud(playername)
end

-- construct the questlog
function quests.create_formspec(playername)
	local questlist = {}
	quests.formspec_lists[playername] = {}
	quests.formspec_lists[playername].id = 1
	quests.formspec_lists[playername].list = {}
	for questname,questspecs in pairs(quests.registered_quests[playername]) do
		local queststring = questspecs["title"]
		if (questspecs["max"] ~= 1) then
			local queststring = questring .. " - (" .. round(questspecs["value"], 2) .. "/" .. questspecs["max"] .. ")"
		end
		table.insert(questlist, queststring)
		table.insert(quests.formspec_lists[playername].list, questname)
	end
	local formspec = "size[7,9]"..
			"textlist[0.25,0.25;6.5,7.5;questlist;"..table.concat(questlist, ",") .. ";1;false]" ..
			"button[0.25,8;3,.7;abort;Abort quest]" ..
			"button[3.75,8;3,.7;config;Configure]"
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
			"button[.25,1.25;3,.7;return;Return"
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
end)

-- write the quests to file
minetest.register_on_shutdown(function() 
	print "Writing quests to file"
	local file = io.open(minetest.get_worldpath().."/quests", "w")
	if (file) then
		file:write(minetest.serialize({registered_quests = quests.registered_quests,
						hud 		 = quests.hud}))
		file:close()
	end
end)
