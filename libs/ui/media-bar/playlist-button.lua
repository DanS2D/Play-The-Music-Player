local M = {}
local playlistDropdownLib = require("libs.ui.playlist-dropdown")
local musicList = require("libs.ui.music-list")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button =
		playlistDropdownLib.new(
		{
			parent = parent,
			onClick = function()
				musicList:closeRightClickMenus()
			end,
			onPlaylistClick = function()
				musicList:cleanDataReload()
			end
		}
	)

	return button
end

return M
