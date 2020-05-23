local M = {}
local theme = require("libs.theme")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local mMax = math.max
local uPack = unpack

function M.new(parent)
	local songContainerBox = display.newRoundedRect(0, 0, mMax(489, display.contentWidth / 2), common.barHeight, 2)
	songContainerBox.anchorX = 0
	songContainerBox.x = display.contentCenterX - songContainerBox.contentWidth * 0.5 - 38
	songContainerBox.y = (common.barHeight - 5)
	songContainerBox.strokeWidth = 1
	songContainerBox:setFillColor(uPack(theme:get().backgroundColor.primary))
	songContainerBox:setStrokeColor(uPack(theme:get().backgroundColor.outline))
	songContainerBox:addEventListener(
		"tap",
		function(event)
			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.close)

			return true
		end
	)
	parent:insert(songContainerBox)

	local songContainer = display.newContainer(songContainerBox.contentWidth - 140, common.barHeight - 14)
	songContainer.anchorX = 0
	songContainer.x = songContainerBox.x + 105
	songContainer.y = songContainerBox.y - 3
	parent:insert(songContainer)

	return songContainerBox, songContainer
end

return M
