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
			text = "HELLO",
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
			text = "HAI",
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

	return group
end

return M
