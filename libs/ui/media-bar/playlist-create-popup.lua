local M = {}
local sqlLib = require("libs.sql-lib")
local theme = require("libs.theme")
local settings = require("libs.settings")
local eventDispatcher = require("libs.event-dispatcher")
local buttonLib = require("libs.ui.button")
local alertPopupLib = require("libs.ui.alert-popup")
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local uPack = unpack
local titleFont = "fonts/Jost-500-Medium.ttf"
local subTitleFont = "fonts/Jost-400-Book.ttf"
local maxDisplayWidth = 825
local maxDisplayHeight = 500
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local enteredPlaylistName = nil
local playlistTextField = nil
local created = false

local function onPlaylistTextFieldInput(event)
	local phase = event.phase
	local target = event.target

	if (phase == "began") then
	elseif (phase == "editing") then
		enteredPlaylistName = event.text
	end

	return true
end

local function onConfirm()
	if (enteredPlaylistName == nil or enteredPlaylistName:len() < 3) then
		playlistTextField.isVisible = false
		alertPopup:onlyUseOkButton()
		alertPopup:setTitle("Name is too short.")
		alertPopup:setMessage("The name you entered is too short.\n\nPlease enter at least 3 characters.")
		alertPopup:setButtonCallbacks(
			{
				onOK = function()
					native.setKeyboardFocus(playlistTextField)
					playlistTextField.isVisible = true
				end
			}
		)
		alertPopup:show()
		return
	end

	group:hide()
	sqlLib:createPlaylist(enteredPlaylistName)
	sqlLib.currentMusicTable = sFormat("%sPlaylist", enteredPlaylistName)
	settings.lastView = sqlLib.currentMusicTable
	settings:save()
	eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
end

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local messageText = nil
	local cancelButton = nil
	local confirmButton = nil

	function group:show()
		eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)

		if (interactionDisableRect) then
			display.remove(interactionDisableRect)
			interactionDisableRect = nil
		end

		if (background) then
			display.remove(background)
			background = nil
		end

		if (titleText) then
			display.remove(titleText)
			titleText = nil
		end

		if (messageText) then
			display.remove(messageText)
			messageText = nil
		end

		if (playlistTextField) then
			display.remove(playlistTextField)
			playlistTextField = nil
		end

		if (cancelButton) then
			display.remove(cancelButton)
			cancelButton = nil
		end

		if (confirmButton) then
			display.remove(confirmButton)
			confirmButton = nil
		end

		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)

		interactionDisableRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
		interactionDisableRect.x = display.contentCenterX
		interactionDisableRect.y = display.contentCenterY
		interactionDisableRect.isVisible = false
		interactionDisableRect.isHitTestable = true
		interactionDisableRect:addEventListener(
			"tap",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"touch",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"mouse",
			function()
				return true
			end
		)
		self:insert(interactionDisableRect)

		background = display.newRoundedRect(0, 0, maxWidth * 0.5, maxHeight * 0.35, 2)
		background.x = display.contentCenterX
		background.y = display.contentCenterY
		background.strokeWidth = 1
		background:setFillColor(uPack(theme:get().backgroundColor.primary))
		background:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		self:insert(background)

		titleText =
			display.newText(
			{
				text = "Create New Playlist",
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.05,
				width = background.width - 20,
				align = "center"
			}
		)
		titleText.x = background.x
		titleText.y = background.y - background.contentHeight * 0.5 + titleText.contentHeight * 0.5 + 10
		titleText:setFillColor(uPack(theme:get().textColor.primary))
		self:insert(titleText)

		messageText =
			display.newText(
			{
				text = "Please enter the name for your new playlist.",
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				width = background.width - 20,
				align = "center"
			}
		)
		messageText.x = titleText.x
		messageText.y = titleText.y + titleText.contentHeight * 0.5 + messageText.contentHeight * 0.5
		messageText:setFillColor(uPack(theme:get().textColor.secondary))
		self:insert(messageText)

		playlistTextField = native.newTextField(display.contentWidth, -200, background.width - 60, 30)
		playlistTextField.anchorX = 0.5
		playlistTextField.anchorY = 0.5
		playlistTextField.x = display.contentCenterX
		playlistTextField.y = messageText.y + messageText.contentHeight + 15
		playlistTextField.placeholder = "My playlist name..."
		playlistTextField.align = "center"
		playlistTextField:addEventListener("userInput", onPlaylistTextFieldInput)

		cancelButton =
			buttonLib.new(
			{
				iconName = "window-close Cancel",
				fontSize = maxHeight * 0.04,
				parent = self,
				onClick = function(event)
					self:hide()
				end
			}
		)
		cancelButton.x = background.x - cancelButton.contentWidth
		cancelButton.y = background.y + background.contentHeight * 0.5 - cancelButton.contentHeight

		confirmButton =
			buttonLib.new(
			{
				iconName = "check-circle Confirm",
				fontSize = maxHeight * 0.04,
				parent = self,
				onClick = function(event)
					onConfirm()
				end
			}
		)
		confirmButton.x = background.x + confirmButton.contentWidth
		confirmButton.y = background.y + background.contentHeight * 0.5 - confirmButton.contentHeight

		self.isVisible = true
		native.setKeyboardFocus(playlistTextField)
		self:toFront()
	end

	function group:hide()
		if (interactionDisableRect) then
			display.remove(interactionDisableRect)
			interactionDisableRect = nil
		end

		if (background) then
			display.remove(background)
			background = nil
		end

		if (titleText) then
			display.remove(titleText)
			titleText = nil
		end

		if (messageText) then
			display.remove(messageText)
			messageText = nil
		end

		if (playlistTextField) then
			display.remove(playlistTextField)
			playlistTextField = nil
		end

		if (cancelButton) then
			display.remove(cancelButton)
			cancelButton = nil
		end

		if (confirmButton) then
			display.remove(confirmButton)
			confirmButton = nil
		end

		self.isVisible = false
	end

	created = true
	group:hide()

	function M:isOpen()
		return group.isVisible
	end

	return group
end

return M
