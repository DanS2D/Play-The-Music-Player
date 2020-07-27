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

	local podcastListButton =
		buttonLib.new(
		{
			iconName = _G.isLinux and "" or "podcast",
			fontSize = common.mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local radioCount = sqlLib:radioCount()

				if (radioCount <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Podcasts Added!")
					alertPopup:setMessage(
						"You haven't added any podcasts yet!\nYou can add a podcast by clicking the + button above the podcast button."
					)
					alertPopup:show()
					return
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
	podcastListButton.x = podcastListButton.contentWidth + 10
	podcastListButton.y = 0

	local addNewRadioButton =
		buttonLib.new(
		{
			iconName = _G.isLinux and "" or "plus-square",
			fontSize = common.smallButtonFontSize,
			parent = group,
			onClick = function(event)
				--radioCreatePopup:show()
			end
		}
	)
	addNewRadioButton.x = podcastListButton.x + podcastListButton.contentWidth * 0.5 + addNewRadioButton.contentWidth * 0.7
	addNewRadioButton.y = podcastListButton.y - podcastListButton.contentHeight * 0.5
	parent:insert(group)

	return group
end

return M
