local M = {}
local audioLib = require("libs.audio-lib")
local mFloor = math.floor
local leftChannel = {}
local rightChannel = {}
local isEnabled = true
local numBars = 10
local minLevel = 0
local maxLevel = 32768
local chunk = maxLevel / numBars
local leftLevel, rightLevel = 0, 0
local numberOfBarsPerSide = 10
local getProperty = native.getProperty

local function updateVisualization()
	if (getProperty("windowMode") ~= "minimized" and isEnabled and audioLib.isChannelPlaying()) then
		leftLevel, rightLevel = audioLib.getLevel()

		for i = 1, #leftChannel do
			leftChannel[i].height = (leftLevel > chunk * (#leftChannel + 1 - i) and leftChannel[i].origHeight) or 1
			rightChannel[i].height = (rightLevel > (chunk * i) and rightChannel[i].origHeight) or 1
		end
	end
end

timer.performWithDelay(20, updateVisualization, 0)

function M.new()
	local group = display.newGroup()
	group.anchorX = 0
	group.anchorY = 0
	group.anchorChildren = false
	local barWidth = 2
	local barHeight = 2

	for i = 1, numBars do
		leftChannel[i] = display.newRect(0, 0, barWidth, 1)
		rightChannel[i] = display.newRect(0, 0, barWidth, 1)

		if (i == 1) then
			leftChannel[i].x = 0
			rightChannel[i].x = (2 * (numBars * 1.5)) + 1
			leftChannel[i].origHeight = (2 * numBars)
			rightChannel[i].origHeight = 2
		else
			leftChannel[i].x = mFloor(leftChannel[i - 1].x + barWidth) + 1
			rightChannel[i].x = mFloor(rightChannel[i - 1].x + barWidth) + 1
			leftChannel[i].origHeight = leftChannel[i - 1].origHeight - 2
			rightChannel[i].origHeight = (barHeight * i)
		end

		leftChannel[i]:setFillColor((255 - (21 * i - 1)) / 255, (21 * i - 1) / 255, 0)
		rightChannel[i]:setFillColor((21 * i - 1) / 255, (255 - (21 * i - 1)) / 255, 0)

		leftChannel[i].anchorY = 1
		rightChannel[i].anchorY = 1
		group:insert(leftChannel[i])
		group:insert(rightChannel[i])
	end

	function group:setEnabled(enabled)
		isEnabled = enabled
	end

	function group:isEnabled()
		return isEnabled
	end

	return group
end

return M
