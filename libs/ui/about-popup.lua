local M = {}
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local filledButtonLib = require("libs.ui.filled-button")
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"
local maxDisplayWidth = 1024
local maxDisplayHeight = 768
local group = display.newGroup()
local created = false

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local logo = nil
	local separatorLine = nil
	local credits = {
		{title = "Programming", attribution = "Danny Glover"},
		{title = "Art/Design", attribution = "Danny Glover"},
		{title = "UX", attribution = "Danny Glover"},
		{title = "Libraries", attribution = "Solar2D, BASS, Taglib, TinyFileDialogs"},
		{
			title = "Program Icon",
			attribution = "Freepik @ Flaticon",
			onClick = function()
				system.openURL("https://www.flaticon.com/authors/freepik")
			end
		},
		{title = "UI Elements", attribution = "Jost Font, FontAwesome"},
		{title = "Testing", attribution = "Steve Johnson, Simon Barber"},
		{title = "Special Thanks", attribution = "Steve Johnson, Rick Grant, My Wife & Kids"}
	}
	local creditTitles = {}
	local creditAtributions = {}
	local closeButton = nil

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

	function group:show(song)
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
		background:setFillColor(0.15, 0.15, 0.15)
		background:setStrokeColor(0.6, 0.6, 0.6, 0.5)
		background:addEventListener(
			"tap",
			function()
				native.setKeyboardFocus(nil)
			end
		)
		self:insert(background)

		titleText =
			display.newText(
			{
				text = "Play - The Audio Connoisseurs Music Player",
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				align = "center"
			}
		)
		titleText.x = background.x
		titleText.y = background.y - background.contentHeight * 0.5 + titleText.contentHeight * 0.5 + 10
		titleText:setFillColor(1, 1, 1)
		self:insert(titleText)

		logo = display.newImageRect("img/icons/play.png", 30, 30)
		logo.x = titleText.x - titleText.contentWidth * 0.5 - logo.contentWidth
		logo.y = titleText.y
		group:insert(logo)

		separatorLine = display.newRoundedRect(0, 0, background.contentWidth - 40, 1, 1)
		separatorLine.x = background.x
		separatorLine.y = titleText.y + titleText.contentHeight * 0.5
		separatorLine:setFillColor(0.7, 0.7, 0.7)
		self:insert(separatorLine)

		for i = 1, #credits do
			creditTitles[i] =
				display.newText(
				{
					text = credits[i].title,
					font = titleFont,
					x = 0,
					y = 0,
					fontSize = maxHeight * 0.03,
					width = background.width - 20,
					align = "center"
				}
			)
			creditTitles[i].x = titleText.x

			if (i == 1) then
				creditTitles[i].y = titleText.y + titleText.contentHeight
			else
				creditTitles[i].y = creditTitles[i - 1].y + creditTitles[i - 1].contentHeight + 30
			end

			creditTitles[i]:setFillColor(1, 1, 1)
			self:insert(creditTitles[i])

			creditAtributions[i] =
				display.newText(
				{
					text = credits[i].attribution,
					font = subTitleFont,
					x = 0,
					y = 0,
					fontSize = maxHeight * 0.025,
					width = background.width - 20,
					align = "center"
				}
			)
			creditAtributions[i].x = titleText.x
			creditAtributions[i].y =
				creditTitles[i].y + creditTitles[i].contentHeight * 0.5 + creditAtributions[i].contentHeight * 0.5
			creditAtributions[i]:setFillColor(1, 1, 1)
			self:insert(creditAtributions[i])

			if (type(credits[i].onClick) == "function") then
				creditAtributions[i]:addEventListener(
					"tap",
					function()
						credits[i].onClick()
					end
				)
			end
		end

		closeButton =
			filledButtonLib.new(
			{
				iconName = "window-close",
				labelText = "Close",
				fontSize = maxHeight * 0.04,
				parent = group,
				onClick = function(event)
					self:hide()
				end
			}
		)
		closeButton.x = background.x - closeButton.contentWidth * 0.25
		closeButton.y = background.y + background.contentHeight * 0.5 - closeButton.contentHeight * 0.5 - 5

		self.isVisible = true
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
