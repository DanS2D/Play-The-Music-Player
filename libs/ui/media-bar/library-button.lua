local M = {}
local sqlLib = require("libs.sql-lib")
local buttonLib = require("libs.ui.button")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button =
		buttonLib.new(
		{
			iconName = "album-collection",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				if (sqlLib:totalMusicCount() <= 0) then
					return
				end

				eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)
				sqlLib.currentMusicTable = "music"
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.closeRightClickMenus)
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
			end
		}
	)

	return button
end

return M
