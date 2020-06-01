local M = {}
local audioLib = require("libs.audio-lib")
local buttonLib = require("libs.ui.button")
local musicList = require("libs.ui.music-list")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local mRandom = math.random

function M.new(parent)
	local button =
		buttonLib.new(
		{
			iconName = "step-forward",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				local canPlay = true
				local currentSongIndex = audioLib.currentSongIndex
				audioLib.previousSongIndex = currentSongIndex

				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				Runtime:dispatchEvent({name = "playAudio", phase = "ended"})
			end
		}
	)

	return button
end

return M
