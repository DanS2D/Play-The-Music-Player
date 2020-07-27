local M = {}
local sqlLib = require("libs.sql-lib")
local settings = require("libs.settings")
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
			iconName = _G.isLinux and "" or "radio",
			fontSize = common.mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local radioCount = sqlLib:radioCount()

				if (radioCount <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Radio Stations Added!")
					alertPopup:setMessage(
						"You haven't added any radio stations yet!\nYou can add a radio station by clicking the + button above the radio button."
					)
					alertPopup:show()
					return
				end

				if (sqlLib.currentMusicTable ~= "radio") then
					eventDispatcher:musicListEvent(eventDispatcher.musicList.events.setSelectedRow, 0)
				end

				sqlLib.currentMusicTable = "radio"
				settings.lastView = sqlLib.currentMusicTable
				settings:save()
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
			iconName = _G.isLinux and "" or "plus-square",
			fontSize = common.smallButtonFontSize,
			parent = group,
			onClick = function(event)
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
