local M = {}
local tfd = require("plugin.tinyFileDialogs")
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local fileUtils = require("libs.file-utils")
local theme = require("libs.theme")
local eventDispatcher = require("libs.event-dispatcher")
local tag = require("plugin.taglib")
local albumArt = require("libs.album-art")
local buttonLib = require("libs.ui.button")
local filledButtonLib = require("libs.ui.filled-button")
local alertPopupLib = require("libs.ui.alert-popup")
local ratings = require("libs.ui.ratings")
local activityIndicator = require("libs.ui.activity-indicator")
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local sSub = string.sub
local uPack = unpack
local titleFont = "fonts/Jost-500-Medium.ttf"
local subTitleFont = "fonts/Jost-400-Book.ttf"
local maxDisplayWidth = 1024
local maxDisplayHeight = 768
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.ttf"
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or os.getenv("HOME")
local documentsPath = system.pathForFile(nil, system.DocumentsDirectory)
local created = false

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local separatorLine = nil
	local buttonGroup = nil
	local cancelButton = nil
	local confirmButton = nil

	function group:hideChildren()
		for i = self.numChildren, 1, -1 do
			self[i].isVisible = false
		end
	end

	function group:showChildren()
		for i = self.numChildren, 1, -1 do
			if (not self[i].ignoreVisibilityChange) then
				self[i].isVisible = true
			end
		end
	end

	function group:cleanup()
		for i = self.numChildren, 1, -1 do
			display.remove(self[i])
			self[i] = nil
		end
	end

	function group:show()
		self:cleanup()

		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)

		interactionDisableRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
		interactionDisableRect.x = display.contentCenterX
		interactionDisableRect.y = display.contentCenterY
		interactionDisableRect.ignoreVisibilityChange = true
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

		background = display.newRoundedRect(0, 0, maxWidth * 0.95, maxHeight * 0.85, 2)
		background.x = display.contentCenterX
		background.y = display.contentCenterY
		background.strokeWidth = 1
		background:setFillColor(uPack(theme:get().backgroundColor.primary))
		background:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		background:addEventListener(
			"tap",
			function()
				native.setKeyboardFocus(nil)
				return true
			end
		)
		self:insert(background)

		titleText =
			display.newText(
			{
				text = "Preferences",
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				width = background.width - 20,
				align = "center"
			}
		)
		titleText.x = background.x
		titleText.y = background.y - background.contentHeight * 0.5 + titleText.contentHeight * 0.5 + 10
		titleText:setFillColor(uPack(theme:get().textColor.primary))
		self:insert(titleText)

		separatorLine = display.newRoundedRect(0, 0, background.contentWidth - 40, 1, 1)
		separatorLine.x = background.x
		separatorLine.y = titleText.y + titleText.contentHeight * 0.5
		separatorLine:setFillColor(uPack(theme:get().textColor.secondary))
		self:insert(separatorLine)

		buttonGroup = display.newGroup()

		cancelButton =
			filledButtonLib.new(
			{
				iconName = "window-close",
				labelText = "Cancel",
				fontSize = maxHeight * 0.030,
				parent = buttonGroup,
				onClick = function(event)
					self:hide()
				end
			}
		)
		cancelButton.x = -cancelButton.contentWidth * 0.5 - 10

		confirmButton =
			filledButtonLib.new(
			{
				iconName = "save",
				labelText = "Confirm",
				fontSize = maxHeight * 0.030,
				parent = buttonGroup,
				onClick = function(event)
					self:hide()
				end
			}
		)
		confirmButton.x = confirmButton.contentWidth * 0.5 + 10
		self:insert(buttonGroup)

		buttonGroup.anchorChildren = true
		buttonGroup.anchorX = 0.5
		buttonGroup.x = background.x
		buttonGroup.y = background.y + background.contentHeight * 0.5 - buttonGroup.contentHeight

		self.isVisible = true
		self:toFront()
	end

	function group:hide()
		self:cleanup()

		albumArt.customEventName = nil
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
