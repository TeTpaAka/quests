if (core.global_exists("cmsg")) then
	function quests.show_message(t, playername, text)
		if (quests.hud[playername].central_message_enabled) then
			local player = core.get_player_by_name(playername)
			cmsg.push_message_player(player, text, quests.colors[t])
			core.sound_play("quests_" .. t, {to_player = playername})
		end
	end
else
	function quests.show_message(...)
	end
end
