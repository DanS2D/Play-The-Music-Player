local bass = require("plugin.bass")
local audioLib = require("libs.audio-lib")
local M = {}

function M.new(options)
	local width = options.width
	local height = options.height or 6
	local allowTouch = options.allowTouch or nil
	local outerColor = options.innerColor or {0.28, 0.28, 0.28, 1}
	local innerColor = options.innerColor or {0.6, 0.6, 0.6, 1}
	local seekPosition = 0
	local group = display.newGroup()
	local outerBox = nil
	local innerBox = nil
	local progress = 0
	group.actualWidth = width

	local outerBox = display.newRect(0, 0, width, height)
	outerBox.anchorX = 0
	outerBox.x = 0
	outerBox:setFillColor(unpack(outerColor))
	group:insert(outerBox)

	local innerBox = display.newRect(0, 0, 0, height)
	innerBox.anchorX = 0
	innerBox.x = 0
	innerBox:setFillColor(unpack(innerColor))
	group:insert(innerBox)

	function group:touch(event)
		local phase = event.phase

		if (phase == "began") then
			local valueX, valueY = self:contentToLocal(event.x, event.y)
			local onePercent = width / 100
			local currentPercent = valueX / onePercent
			local duration = audioLib.getDuration() * 1000
			seekPosition = ((currentPercent / 10) * duration / 10)
			--print(seekPosition)

			if (audioLib.isChannelPlaying()) then
				progress = seekPosition
				self:setOverallProgress(progress / duration)
				audioLib.seek(seekPosition / 1000)
			end
		end
	end

	if (allowTouch) then
		group:addEventListener("touch")
	end

	function group:setOverallProgress(newProgress)
		innerBox.width = (width / 100) * (newProgress * 100)
	end

	function group:getElapsedProgress()
		return progress
	end

	function group:setElapsedProgress(newProgress)
		progress = newProgress
	end

	return group
end

return M
