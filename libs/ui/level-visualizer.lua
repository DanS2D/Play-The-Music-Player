local M = {}
local audioLib = require("libs.audio-lib")
local mFloor = math.floor
local leftChannel = {}
local rightChannel = {}
local isEnabled = true

local function updateVisualization()
	if (isEnabled and audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		if (#leftChannel > 1) then
			local leftLevel, rightLevel = audioLib.getLevel()
			local minLevel = 0
			local maxLevel = 32768
			local chunk = 2520

			for i = 1, #leftChannel do
				if (leftLevel > chunk * (14 - i)) then
					leftChannel[i].height = leftChannel[i].origHeight
				else
					leftChannel[i].height = 1
				end

				if (rightLevel > chunk * (1 + (i - 1))) then
					rightChannel[i].height = rightChannel[i].origHeight
				else
					rightChannel[i].height = 1
				end
			end
		end
	end
end

Runtime:addEventListener("enterFrame", updateVisualization)

function M.new()
	local group = display.newGroup()
	group.anchorX = 0
	group.anchorY = 0
	group.anchorChildren = false

	for i = 1, 13 do
		leftChannel[i] = display.newRect(50, 0, 2, 30)
		rightChannel[i] = display.newRect(50, 0, 2, 30)

		if (i == 1) then
			leftChannel[i].x = 50
			leftChannel[i].origHeight = mFloor(28 - (i * 2))
			rightChannel[i].x = 104
			rightChannel[i].origHeight = 2
		else
			leftChannel[i].x = mFloor(leftChannel[i - 1].x + 4)
			leftChannel[i].origHeight = mFloor(28 - (i * 2))
			rightChannel[i].x = mFloor(rightChannel[i - 1].x + 4)
			rightChannel[i].origHeight = mFloor(rightChannel[i - 1].origHeight + 2)
		end

		leftChannel[i]:setFillColor((255 - (21 * i - 1)) / 255, (21 * i - 1) / 255, 0)
		rightChannel[i]:setFillColor((21 * i - 1) / 255, (255 - (21 * i - 1)) / 255, 0)

		leftChannel[i].anchorY = 1
		rightChannel[i].anchorY = 1
		rightChannel[i].height = 1
		leftChannel[i].height = 1
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
