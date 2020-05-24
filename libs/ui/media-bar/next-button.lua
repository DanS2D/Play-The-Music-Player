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

				if (audioLib.shuffle) then
					repeat
						audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
					until audioLib.currentSongIndex ~= currentSongIndex
				else
					if (audioLib.currentSongIndex + 1 <= musicList:getMusicCount()) then
						audioLib.currentSongIndex = audioLib.currentSongIndex + 1
					else
						canPlay = false
					end
				end

				if (canPlay) then
					local nextSong = musicList:getRow(audioLib.currentSongIndex)

					eventDispatcher:playButtonEvent(eventDispatcher.playButton.events.setOn)
					eventDispatcher:musicListEvent(eventDispatcher.musicList.events.setSelectedRow, audioLib.currentSongIndex)

					if (nextSong.url) then
						eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.loadingUrl, nextSong)
						timer.performWithDelay(
							50,
							function()
								audioLib.load(nextSong)
								audioLib.play(nextSong)
							end
						)
					else
						audioLib.load(nextSong)
						audioLib.play(nextSong)
					end
				end
			end
		}
	)

	return button
end

return M
