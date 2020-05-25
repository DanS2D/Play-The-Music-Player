local M = {}
local audioLib = require("libs.audio-lib")
local settings = require("libs.settings")
local volumeSliderLib = require("libs.ui.volume-slider")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local slider =
		volumeSliderLib.new(
		{
			width = 60,
			value = 100,
			listener = function(event)
				local convertedValue = event.value / 100
				local volumeButtonPhase =
					(convertedValue > 0) and eventDispatcher.volumeButton.events.setOn or eventDispatcher.volumeButton.events.setOff

				audioLib.setVolume(convertedValue)
				eventDispatcher:volumeButtonEvent(volumeButtonPhase)
			end,
			onTouchEnded = function(event)
				local convertedValue = event.value / 100
				local volumeButtonPhase =
					(convertedValue > 0) and eventDispatcher.volumeButton.events.setOn or eventDispatcher.volumeButton.events.setOff

				settings.volume = convertedValue
				audioLib.setVolume(convertedValue)
				eventDispatcher:volumeButtonEvent(volumeButtonPhase)
				settings:save()
			end
		}
	)

	local function volumeSliderEventHandler(event)
		local phase = event.phase

		if (phase == eventDispatcher.volumeSlider.events.setValue) then
			slider:setValue(event.value)
		end

		return true
	end

	Runtime:addEventListener(eventDispatcher.volumeSlider.name, volumeSliderEventHandler)

	return slider
end

return M
