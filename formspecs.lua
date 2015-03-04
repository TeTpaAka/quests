-- Boilerplate to support localized strings if intllib mod is installed.
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	-- If you don't use insertions (@1, @2, etc) you can use this:
	S = function(s) return s end
end


-- construct the questlog
function quests.create_formspec(playername, tab, integrated)
	print(tab)
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
		
	local no_quests = true
	for questname,questspecs in pairs(questlist) do
		if (questspecs.finished == nil) then
			local queststring = quests.registered_quests[questname]["title"]
			if (questspecs["count"] and questspecs["count"] > 1) then
				queststring = queststring .. " - " .. questspecs["count"]
			elseif(not questspecs["count"] and quests.registered_quests[questname]["max"] ~= 1) then
				queststring = queststring .. " - (" .. quests.round(questspecs["value"], 2) .. "/" .. quests.registered_quests[questname]["max"] .. ")"
			end
			table.insert(queststringlist, queststring)
			table.insert(quests.formspec_lists[playername].list, questname)
			no_quests = false
		end
	end
	local formspec = ""
	if (not integrated) then
		formspec = formspec .. "size[7,9]"
	end
	formspec = formspec .. "tabheader[0,0;quests_header;" .. S("Open quests") .. "," .. S("Finished quests") .. "," .. S("Failed quests") .. ";" .. tab .. "]"
	if (no_quests) then
		formspec = formspec .. "label[0.25,0.25;" .. S("There are no quests in this category.") .. "]"
	else
		formspec = formspec .. "textlist[0.25,0.25;6.5,6.5;quests_questlist;"..table.concat(queststringlist, ",") .. ";1;false]"
	end
	if (quests.formspec_lists[playername].tab == "1") then
		formspec = formspec .."button[0.25,7;3,.7;quests_abort;" .. S("Abort quest") .. "]"
	end
	formspec = formspec .. "button[3.75,7;3,.7;quests_config;" .. S("Configure") .. "]"..
			"button[.25,8;3,.7;quests_info;" .. S("Info") .. "]"..
			"button_exit[3.75,8;3,.7;quests_exit;" .. S("Exit") .. "]"
	return formspec
end

-- construct the configuration
function quests.create_config(playername, integrated)
	local formspec = ""
	if (not integrated) then
		formspec = formspec .. "size[7,3]"
	end 
	formspec = formspec .. "checkbox[.25,.25;quests_config_enable;" .. S("Enable HUD") .. ";" 
	if(quests.hud[playername] ~= nil) then 
		formspec = formspec .. "true"
	else
		formspec = formspec ..  "false"
	end 
	formspec = formspec .. "]"..
			"button[.25,1.25;3,.7;quests_config_return;" .. S("Return") .. "]"
	return formspec
end

-- construct the info formspec
function quests.create_info(playername, questname, integrated)
	local formspec = ""
	if (not integrated) then
		formspec = formspec .. "size[7,6.5]"
	end
	formspec = formspec .. "label[0.5,0.5;" 

	if (questname) then
		formspec = formspec .. quests.registered_quests[questname].title .. "]" ..
				 "textarea[.5,1.5;6,4.5;quests_info_description;;" .. quests.registered_quests[questname].description .. "]"

		if (quests.formspec_lists[playername].tab == "1") then
			formspec = formspec .. "button[.5,6;3,.7;quests_info_abort;" .. S("Abort quest") .. "]"
		end
	else
		formspec = formspec .. S("No quest specified.") .. "]"
	end
	formspec = formspec .. "button[3.25,6;3,.7;quests_info_return;" .. S("Return") .. "]"
	return formspec
end

-- show the player playername his/her questlog
function quests.show_formspec(playername) 
	minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
end

-- chatcommand to see a full list of quests:
minetest.register_chatcommand("quests", {
	params = "",
	description = S("Show all open quests"),
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

--	questlog
	if (fields["quests_header"]) then
		if (formname == "quests:questlog") then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername, fields["quests_header"]))
		else
			if (fields["quests_header"] == "1") then
				unified_inventory.set_inventory_formspec(player, "quests")
			elseif (fields["quests_header"] == "2") then
				unified_inventory.set_inventory_formspec(player, "quests_successfull")
				return
			else
				unified_inventory.set_inventory_formspec(player, "quests_failed")
				return
			end
		end
		return
	end
	if (fields["quests_questlist"]) then
		local event = minetest.explode_textlist_event(fields["quests_questlist"])
		if (event.type == "CHG") then
			quests.formspec_lists[playername].id = event.index
		end
	end
	if (fields["quests_abort"]) then
		if (quests.formspec_lists[playername].id == nil) then
			return
		end
		quests.abort_quest(playername, quests.formspec_lists[playername]["list"][quests.formspec_lists[playername].id]) 
		if (formname == "quests:questlog") then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		else
			unified_inventory.set_inventory_formspec(player, "quests")
		end
	end
	if (fields["quests_config"]) then
		if (formname == "quests:questlog") then
			minetest.show_formspec(playername, "quests:config", quests.create_config(playername))
		else
			unified_inventory.set_inventory_formspec(player, "quests_config")
		end
	end
	if (fields["quests_info"]) then
		if (formname == "quests:questlog") then
			minetest.show_formspec(playername, "quests:info", quests.create_info(playername, quests.formspec_lists[playername].list[quests.formspec_lists[playername].id]))
		else
			unified_inventory.set_inventory_formspec(player, "quests_info")
		end
	end

-- config
	if (fields["quests_config_enable"]) then
		if (fields["quests_config_enable"] == "true") then	
			quests.show_hud(playername)
		else
			quests.hide_hud(playername)
		end
	end
	if (fields["quests_config_return"]) then
		if (formname == "quests:config") then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		else 
			unified_inventory.set_inventory_formspec(player, "quests")
		end
	end

-- info
	if (fields["quests_info_abort"]) then
		if (quests.formspec_lists[playername].id == nil) then
			return
		end
		quests.abort_quest(playername, quests.formspec_lists[playername]["list"][quests.formspec_lists[playername].id]) 
		if (formname == "quests:info") then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		else 
			unified_inventory.set_inventory_formspec(player, "quests")
		end
	end
	if (fields["quests_info_return"]) then
		if (formname == "quests:info") then
			minetest.show_formspec(playername, "quests:questlog", quests.create_formspec(playername))
		else 
			unified_inventory.set_inventory_formspec(player, "quests")
		end
	end
end)
