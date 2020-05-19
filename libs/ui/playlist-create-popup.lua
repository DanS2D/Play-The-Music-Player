local M = {}
local sqlLib = require("libs.sql-lib")
local buttonLib = require("libs.ui.button")
local alertPopupLib = require("libs.ui.alert-popup")
local mMin = math.min
local mMax = math.max
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
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
					playlistTextField.isVisible = true
				end
			}
		)
		alertPopup:show()
		return
	end

	group:hide()
	sqlLib:createPlaylist(enteredPlaylistName)
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
		background:setFillColor(0.15, 0.15, 0.15)
		background:setStrokeColor(0.6, 0.6, 0.6, 0.5)
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
		titleText:setFillColor(1, 1, 1)
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
		messageText:setFillColor(1, 1, 1)
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
				iconName = "window-close No",
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
				iconName = "check-circle Yes",
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