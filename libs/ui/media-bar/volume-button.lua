local M = {}
local audioLib = require("libs.audio-lib")
local settings = require("libs.settings")
local switchLib = require("libs.ui.switch")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button = nil

	button =
		switchLib.new(
		{
			offIconName = "volume-slash",
			onIconName = "volume-up",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				local target = event.target
				eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.close)

				if (target.isOffButton) then
					audioLib.setVolume(audioLib.getPreviousVolume())
					local newVolume = audioLib.getVolume() * 100

					eventDispatcher:volumeSliderEvent(eventDispatcher.volumeSlider.events.setValue, newVolume)
					settings.volume = newVolume
					settings:save()
				else
					audioLib.setVolume(0)
					eventDispatcher:volumeSliderEvent(eventDispatcher.volumeSlider.events.setValue, 0)
					settings.volume = 0
					settings:save()
				end
			end
		}
	)

	local function volumeButtonEventHandler(event)
		local phase = event.phase
		local volumeButtonEvents = eventDispatcher.volumeButton.events

		if (phase == volumeButtonEvents.setOn) then
			button:setIsOn(true)
		elseif (phase == volumeButtonEvents.setOff) then
			button:setIsOn(false)
		end

		return true
	end

	Runtime:addEventListener(eventDispatcher.volumeButton.name, volumeButtonEventHandler)

	return button
end

return M
