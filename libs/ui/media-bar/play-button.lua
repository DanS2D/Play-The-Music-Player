local M = {}
local audioLib = require("libs.audio-lib")
local switchLib = require("libs.ui.switch")
local musicList = require("libs.ui.music-list")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local mRandom = math.random

function M.new(parent)
	local button = nil

	button =
		switchLib.new(
		{
			offIconName = "play",
			onIconName = "pause",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				local target = event.target

				if (target.isOffButton) then
					if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
						button:setIsOn(false)
						return
					end

					if (audioLib.isChannelHandleValid()) then
						if (audioLib.isChannelPlaying()) then
							return
						end

						if (audioLib.isChannelPaused()) then
							audioLib.resume()
							return
						end
					end
				else
					if (not musicList:hasValidMusicData()) then
						return
					end

					if (audioLib.isChannelHandleValid()) then
						if (audioLib.isChannelPlaying()) then
							audioLib.pause()
						end
					end
				end
			end
		}
	)

	local function playButtonEventHandler(event)
		local phase = event.phase
		local playButtonEvent = eventDispatcher.playButton.events

		if (phase == playButtonEvent.setOn) then
			button:setIsOn(true)
		end

		return true
	end

	Runtime:addEventListener(eventDispatcher.playButton.name, playButtonEventHandler)

	return button
end

return M
