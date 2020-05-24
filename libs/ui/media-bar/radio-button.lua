local M = {}
local sqlLib = require("libs.sql-lib")
local buttonLib = require("libs.ui.button")
local musicList = require("libs.ui.music-list")
local alertPopupLib = require("libs.ui.alert-popup")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local alertPopup = alertPopupLib.create()
local radioCreatePopupLib = require("libs.ui.media-bar.radio-create-popup")
local radioCreatePopup = radioCreatePopupLib.create()

function M.new(parent)
	local group = display.newGroup()

	local radioListButton =
		buttonLib.new(
		{
			iconName = "signal-stream",
			fontSize = common.mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local radioCount = sqlLib:radioCount()

				if (sqlLib:totalMusicCount() <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Music Added!")
					alertPopup:setMessage(
						"You haven't added any music yet!\nYou can't add a radio/podcast until you've added some music to your library."
					)
					alertPopup:show()
					return
				end

				if (radioCount <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Radio/Podcasts Created!")
					alertPopup:setMessage(
						"You haven't created any radio/podcasts yet!\nYou can add a radio/podcast by clicking the + button above the radio button."
					)
					alertPopup:show()
					return
				end

				sqlLib.currentMusicTable = "radio"
				musicList.musicSearch = nil
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.closeRightClickMenus)
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
			end
		}
	)
	radioListButton.x = radioListButton.contentWidth + 10
	radioListButton.y = 0

	local addNewRadioButton =
		buttonLib.new(
		{
			iconName = "plus-square",
			fontSize = common.smallButtonFontSize,
			parent = group,
			onClick = function(event)
				if (sqlLib:totalMusicCount() <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Music Added!")
					alertPopup:setMessage(
						"You haven't added any music yet!\nYou can create radio/podcast after you have imported some music to your library."
					)
					alertPopup:show()
					return
				end

				radioCreatePopup:show()
			end
		}
	)
	addNewRadioButton.x = radioListButton.x + radioListButton.contentWidth * 0.5 + addNewRadioButton.contentWidth * 0.7
	addNewRadioButton.y = radioListButton.y - radioListButton.contentHeight * 0.5
	parent:insert(group)

	return group
end

return M
