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
local common = require("libs.ui.media-bar.common")
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local sSub = string.sub
local uPack = unpack
local maxDisplayWidth = 1024
local maxDisplayHeight = 768
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.ttf"
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or os.getenv("HOME")
local documentsPath = system.pathForFile(nil, system.DocumentsDirectory)
local created = false

local function showHandCursor()
	native.setProperty("mouseCursor", "pointingHand")
	return true
end

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local separatorLineTitle = nil
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
		background:addEventListener(
			"mouse",
			function(event)
				native.setProperty("mouseCursor", "arrow")
				return true
			end
		)
		self:insert(background)

		titleText =
			display.newText(
			{
				text = "Preferences",
				font = common.titleFont,
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

		separatorLineTitle = display.newRoundedRect(0, 0, background.contentWidth - 40, 1, 1)
		separatorLineTitle.x = background.x
		separatorLineTitle.y = titleText.y + titleText.contentHeight * 0.5
		separatorLineTitle:setFillColor(uPack(theme:get().textColor.secondary))
		self:insert(separatorLineTitle)

		local separatorLineCategories = display.newRoundedRect(0, 0, 1, background.contentHeight - 64, 1)
		separatorLineCategories.anchorY = 0
		separatorLineCategories.x = background.x - (background.contentWidth / 4)
		separatorLineCategories.y = separatorLineTitle.y + separatorLineTitle.contentHeight + 5
		separatorLineCategories:setFillColor(uPack(theme:get().textColor.secondary))
		self:insert(separatorLineCategories)

		-- preference categories
		local generalPreferences =
			buttonLib.new(
			{
				iconName = "General",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		generalPreferences.anchorX = 0
		generalPreferences.x = separatorLineTitle.x - separatorLineTitle.contentWidth * 0.5 + 10
		generalPreferences.y = separatorLineTitle.y + separatorLineTitle.contentHeight + generalPreferences.contentHeight
		generalPreferences:addEventListener("mouse", showHandCursor)

		local audioPreferences =
			buttonLib.new(
			{
				iconName = "Audio",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		audioPreferences.anchorX = 0
		audioPreferences.x = generalPreferences.x
		audioPreferences.y = generalPreferences.y + generalPreferences.contentHeight + audioPreferences.contentHeight * 0.5
		audioPreferences:addEventListener("mouse", showHandCursor)

		local musicListPreferences =
			buttonLib.new(
			{
				iconName = "Music List",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		musicListPreferences.anchorX = 0
		musicListPreferences.x = generalPreferences.x
		musicListPreferences.y =
			audioPreferences.y + audioPreferences.contentHeight + musicListPreferences.contentHeight * 0.5
		musicListPreferences:addEventListener("mouse", showHandCursor)

		local playlistPreferences =
			buttonLib.new(
			{
				iconName = "Playlists",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		playlistPreferences.anchorX = 0
		playlistPreferences.x = generalPreferences.x
		playlistPreferences.y =
			musicListPreferences.y + musicListPreferences.contentHeight + playlistPreferences.contentHeight * 0.5
		playlistPreferences:addEventListener("mouse", showHandCursor)

		local radioPreferences =
			buttonLib.new(
			{
				iconName = "Radio",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		radioPreferences.anchorX = 0
		radioPreferences.x = generalPreferences.x
		radioPreferences.y = playlistPreferences.y + playlistPreferences.contentHeight + radioPreferences.contentHeight * 0.5
		radioPreferences:addEventListener("mouse", showHandCursor)

		local podcastPreferences =
			buttonLib.new(
			{
				iconName = "Podcasts",
				font = common.titleFont,
				fontSize = maxHeight * 0.025,
				parent = self,
				onClick = function(event)
				end
			}
		)
		podcastPreferences.anchorX = 0
		podcastPreferences.x = generalPreferences.x
		podcastPreferences.y = radioPreferences.y + radioPreferences.contentHeight + podcastPreferences.contentHeight * 0.5
		podcastPreferences:addEventListener("mouse", showHandCursor)

		buttonGroup = display.newGroup()

		cancelButton =
			filledButtonLib.new(
			{
				iconName = _G.isLinux and "" or "window-close",
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
				iconName = _G.isLinux and "" or "save",
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
		buttonGroup.x = background.x + (background.contentWidth / 8)
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
