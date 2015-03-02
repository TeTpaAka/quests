unified_inventory.register_button("quests", {
	type = "image",
	image = "quests_ui_button.png",
	tooltip = "Show the questlog",
	action = function(player)
		quests.show_formspec(player:get_player_name())
	end
})

--unified_inventory.register_page("quests", {
--	get_formspec = function(player, formspec) 
--		local playername = player:get_player_name()
--		local formspec = quests.create_formspec(playername)
--		return {formspec = formspec, draw_inventory=false}
--	end
--})
