local M = {}
local playlistDropdownLib = require("libs.ui.media-bar.playlist-dropdown")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button =
		playlistDropdownLib.new(
		{
			parent = parent,
			onClick = function()
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.closeRightClickMenus)
			end,
			onPlaylistClick = function()
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
			end
		}
	)

	return button
end

return M
