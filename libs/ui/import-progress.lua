local M = {}
local theme = require("libs.theme")
local progressView = require("libs.ui.progress-view")
local uPack = unpack
local dCenterX = display.contentCenterX
local dCenterY = display.contentCenterY
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local headingText = nil
local subHeadingText = nil
local logo = nil
local importProgressView = nil
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"

function M.new()
	local group = display.newGroup()

	headingText =
		display.newText(
		{
			text = "Welcome To Play!",
			font = titleFont,
			width = dWidth - 20,
			align = "center",
			fontSize = 24
		}
	)
	headingText.x = display.contentCenterX
	headingText.y = 240
	headingText:setFillColor(uPack(theme:get().textColor.primary))
	group:insert(headingText)

	subHeadingText =
		display.newText(
		{
			text = "To get started, click `file > add music folder` to import your music",
			font = subTitleFont,
			width = dWidth - 20,
			align = "center",
			fontSize = 20
		}
	)
	subHeadingText.x = display.contentCenterX
	subHeadingText.y = headingText.y + headingText.contentHeight + 5
	subHeadingText:setFillColor(uPack(theme:get().textColor.secondary))
	group:insert(subHeadingText)

	importProgressView =
		progressView.new(
		{
			width = (dWidth / 2) - 20,
			height = 12,
			allowTouch = false
		}
	)
	importProgressView.x = display.contentCenterX - importProgressView.contentWidth * 0.5
	importProgressView.y = subHeadingText.y + subHeadingText.contentHeight + 7
	importProgressView.isVisible = false
	group:insert(importProgressView)

	logo = display.newImageRect("img/icons/play.png", 60, 60)
	logo.x = display.contentCenterX
	logo.y = importProgressView.y + importProgressView.contentHeight + (logo.contentHeight * 0.5) + 8
	group:insert(logo)

	function group:updateHeading(text)
		headingText.text = text
	end

	function group:updateSubHeading(text)
		subHeadingText.text = text
	end

	function group:setTotalProgress(progress)
		importProgressView:setOverallProgress(progress)
	end

	function group:hide()
		self.isVible = false
	end

	function group:show()
		self.isVible = true
	end

	function group:hideProgressBar()
		importProgressView.isVisible = false
	end

	function group:showProgressBar()
		importProgressView.isVisible = true
	end

	function group:onResize()
		headingText.x = display.contentCenterX
		subHeadingText.x = display.contentCenterX
		importProgressView.x = display.contentCenterX - importProgressView.contentWidth * 0.5
		logo.x = display.contentCenterX
	end

	return group
end

return M
