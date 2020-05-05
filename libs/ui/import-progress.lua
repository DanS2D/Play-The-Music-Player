local M = {}
local progressView = require("libs.ui.progress-view")
local dCenterX = display.contentCenterX
local dCenterY = display.contentCenterY
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local headingText = nil
local subHeadingText = nil
local importProgressView = nil
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"

function M.new()
	local group = display.newGroup()

	headingText =
		display.newText(
		{
			text = "Welcome To Play!",
			font = titleFont,
			width = dWidth - 20,
			align = "center",
			fontSize = 20
		}
	)
	headingText.x = dCenterX
	headingText.y = 200
	headingText:setFillColor(0.9, 0.9, 0.9)
	group:insert(headingText)

	subHeadingText =
		display.newText(
		{
			text = "To get started, click `file > add music folder` to import your music",
			font = subTitleFont,
			width = dWidth - 20,
			align = "center",
			fontSize = 16
		}
	)
	subHeadingText.x = dCenterX
	subHeadingText.y = headingText.y + headingText.contentHeight + 5
	subHeadingText:setFillColor(0.9, 0.9, 0.9)
	group:insert(subHeadingText)

	importProgressView =
		progressView.new(
		{
			width = (dWidth / 2) - 20,
			allowTouch = false
		}
	)
	importProgressView.x = dCenterX - importProgressView.contentWidth * 0.5
	importProgressView.y = subHeadingText.y + subHeadingText.contentHeight + 5
	importProgressView.isVisible = false
	group:insert(importProgressView)

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

	return group
end

return M
