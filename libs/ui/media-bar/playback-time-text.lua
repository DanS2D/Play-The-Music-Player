local M = {}
local audioLib = require("libs.audio-lib")
local theme = require("libs.theme")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local sFormat = string.format
local uPack = unpack

function M.new(parent)
	local playbackTimeText =
		display.newText(
		{
			text = "00:00/00:00",
			font = common.subTitleFont,
			fontSize = 14,
			align = "right"
		}
	)
	playbackTimeText:setFillColor(uPack(theme:get().textColor.primary))
	parent:insert(playbackTimeText)

	function playbackTimeText:update(song)
		local playbackTime = audioLib.getPlaybackTime()

		if (playbackTime) then
			local pbElapsed = playbackTime.elapsed
			local pbDuration = playbackTime.duration

			if (song and song.url) then
				playbackTimeText.text = sFormat("%02d:%02d", pbElapsed.minutes, pbElapsed.seconds)
			else
				playbackTimeText.text =
					sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds)
			end
		end
	end

	return playbackTimeText
end

return M
