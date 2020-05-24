local M = {}
local sqlLib = require("libs.sql-lib")
local settings = require("libs.settings")
local buttonLib = require("libs.ui.button")
local alertPopupLib = require("libs.ui.alert-popup")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local alertPopup = alertPopupLib.create()

function M.new(parent)
	local button =
		buttonLib.new(
		{
			iconName = "album-collection",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				if (sqlLib:totalMusicCount() <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Music Added!")
					alertPopup:setMessage(
						"You haven't added any music yet!\nYou can create playlists after you have imported some music to your library."
					)
					alertPopup:show()
					return
				end

				eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)
				sqlLib.currentMusicTable = "music"
				settings.lastView = sqlLib.currentMusicTable
				settings:save()
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.closeRightClickMenus)
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
			end
		}
	)

	return button
end

return M
