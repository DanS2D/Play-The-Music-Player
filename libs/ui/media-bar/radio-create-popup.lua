local M = {}
local sqlLib = require("libs.sql-lib")
local theme = require("libs.theme")
local settings = require("libs.settings")
local eventDispatcher = require("libs.event-dispatcher")
local buttonLib = require("libs.ui.button")
local alertPopupLib = require("libs.ui.alert-popup")
local mMin = math.min
local mMax = math.max
local uPack = unpack
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local maxDisplayWidth = 825
local maxDisplayHeight = 500
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local enteredPlaylistName = nil
local titleTextField = nil
local urlTextField = nil
local genreTextField = nil
local created = false

local function onConfirm()
	if (titleTextField.text:len() < 3) then
		titleTextField.isVisible = false
		urlTextField.isVisible = false
		genreTextField.isVisible = false
		alertPopup:onlyUseOkButton()
		alertPopup:setTitle("Title is too short.")
		alertPopup:setMessage("The title you entered is too short.\n\nPlease enter at least 3 characters.")
		alertPopup:setButtonCallbacks(
			{
				onOK = function()
					native.setKeyboardFocus(titleTextField)
					titleTextField.isVisible = true
					urlTextField.isVisible = true
					genreTextField.isVisible = true
				end
			}
		)
		alertPopup:show()
		return
	end

	if (urlTextField.text:len() < 7) then
		titleTextField.isVisible = false
		urlTextField.isVisible = false
		alertPopup:onlyUseOkButton()
		alertPopup:setTitle("Url is too short.")
		alertPopup:setMessage("The Url you entered is too short.\n\nPlease enter at least 7 characters.")
		alertPopup:setButtonCallbacks(
			{
				onOK = function()
					native.setKeyboardFocus(titleTextField)
					titleTextField.isVisible = true
					urlTextField.isVisible = true
					genreTextField.isVisible = true
				end
			}
		)
		alertPopup:show()
		return
	end

	group:hide()
	sqlLib:insertRadio(
		{
			url = urlTextField.text:stripLeadingAndTrailingSpaces(),
			title = titleTextField.text:stripLeadingAndTrailingSpaces(),
			genre = genreTextField.text:stripLeadingAndTrailingSpaces(),
			rating = 0,
			playCount = 0
		}
	)
	sqlLib.currentMusicTable = "radio"
	settings.lastView = sqlLib.currentMusicTable
	settings:save()
	eventDispatcher:mainLuaEvent(eventDispatcher.mainEvent.events.populateTableViews)
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

	function group:cleanup()
		for i = self.numChildren, 1, -1 do
			display.remove(self[i])
			self[i] = nil
		end
	end

	function group:show()
		self:cleanup()
		eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)

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

		background = display.newRoundedRect(0, 0, maxWidth * 0.5, maxHeight * 0.6, 2)
		background.x = display.contentCenterX
		background.y = display.contentCenterY
		background.strokeWidth = 1
		background:setFillColor(uPack(theme:get().backgroundColor.primary))
		background:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		self:insert(background)

		titleText =
			display.newText(
			{
				text = "Create New Radio station/podcast",
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
				text = "Please enter the title, url & genre (optional) for your new radio station/podcast.",
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

		titleTextField = native.newTextField(display.contentWidth, -200, background.width - 60, 30)
		titleTextField.anchorX = 0.5
		titleTextField.anchorY = 0.5
		titleTextField.x = display.contentCenterX
		titleTextField.y = messageText.y + messageText.contentHeight + 15
		titleTextField.placeholder = "Radio/Podcast title..."
		titleTextField.align = "center"
		self:insert(titleTextField)

		urlTextField = native.newTextField(display.contentWidth, -200, background.width - 60, 30)
		urlTextField.anchorX = 0.5
		urlTextField.anchorY = 0.5
		urlTextField.x = display.contentCenterX
		urlTextField.y = titleTextField.y + titleTextField.contentHeight + 10
		urlTextField.placeholder = "Radio/Podcast url..."
		urlTextField.align = "center"
		self:insert(urlTextField)

		genreTextField = native.newTextField(display.contentWidth, -200, background.width - 60, 30)
		genreTextField.anchorX = 0.5
		genreTextField.anchorY = 0.5
		genreTextField.x = display.contentCenterX
		genreTextField.y = urlTextField.y + urlTextField.contentHeight + 10
		genreTextField.placeholder = "Radio/Podcast genre..."
		genreTextField.align = "center"
		self:insert(genreTextField)

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
		native.setKeyboardFocus(titleTextField)
		self:toFront()
	end

	function group:hide()
		self:cleanup()
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
