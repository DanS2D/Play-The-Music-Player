local bass = require("plugin.bass")
local M = {}

function M.new(options)
	local width = options.width
	local height = options.height or 6
	local outerColor = options.innerColor or {0.28, 0.28, 0.28, 1}
	local innerColor = options.innerColor or {0.6, 0.6, 0.6, 1}
	local musicDuration = options.musicDuration
	local musicStreamHandle = options.musicStreamHandle
	local seekPosition = 0
	local progress = 0
	local group = display.newGroup()
	local outerBox = nil
	local innerBox = nil
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
			local duration = musicDuration
			seekPosition = ((currentPercent / 10) * musicDuration / 10)
			--print(seekPosition)

			if (bass.isChannelPlaying(musicStreamHandle)) then
				progress = seekPosition
				self:setOverallProgress(progress / duration)
				bass.seek(musicStreamHandle, progress / 1000)
			end
		end
	end
	group:addEventListener("touch")

	function group:updateHandles(duration, streamHandle)
		musicDuration = duration
		musicStreamHandle = streamHandle
	end

	function group:getElapsedProgress()
		return progress
	end

	function group:setElapsedProgress(newProgress)
		progress = newProgress
	end

	function group:setOverallProgress(newProgress)
		innerBox.width = (width / 100) * (newProgress * 100)
	end

	return group
end

return M
