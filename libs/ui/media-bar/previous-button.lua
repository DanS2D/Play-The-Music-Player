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
			iconName = "step-backward",
			fontSize = common.mainButtonFontSize,
			parent = parent,
			onClick = function(event)
				local canPlay = true
				local currentSongIndex = audioLib.currentSongIndex
				audioLib.previousSongIndex = currentSongIndex

				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				if (audioLib.shuffle) then
					repeat
						audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
					until audioLib.currentSongIndex ~= currentSongIndex
				else
					if (audioLib.currentSongIndex - 1 > 0) then
						audioLib.currentSongIndex = audioLib.currentSongIndex - 1
					else
						canPlay = false
					end
				end

				if (canPlay) then
					local previousSong = musicList:getRow(audioLib.currentSongIndex)

					eventDispatcher:playButtonEvent(eventDispatcher.playButton.events.setOn)
					musicList:setSelectedRow(audioLib.currentSongIndex)
					audioLib.load(previousSong)
					audioLib.play(previousSong)
				end
			end
		}
	)

	return button
end

return M
