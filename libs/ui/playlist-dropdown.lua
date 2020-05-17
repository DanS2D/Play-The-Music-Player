local M = {}
local desktopTableView = require("libs.ui.desktop-table-view")
local buttonLib = require("libs.ui.button")
local smallButtonFontSize = 16
local mainButtonFontSize = 28

function M.new(options)
	local group = display.newGroup()

	local playListButton =
		buttonLib.new(
		{
			iconName = "list-music",
			fontSize = mainButtonFontSize,
			parent = group,
			onClick = function(event)
			end
		}
	)
	playListButton.x = playListButton.contentWidth + 10
	playListButton.y = 0

	local addNewPlaylistButton =
		buttonLib.new(
		{
			iconName = "plus-square",
			fontSize = smallButtonFontSize,
			parent = group,
			onClick = function(event)
			end
		}
	)
	addNewPlaylistButton.x = playListButton.x + playListButton.contentWidth * 0.5 + addNewPlaylistButton.contentWidth * 0.7
	addNewPlaylistButton.y = playListButton.y - playListButton.contentHeight * 0.5

	group.x = options.x
	group.y = options.y
	return group
end

return M
