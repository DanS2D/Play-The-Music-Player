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

	function playbackTimeText:update(song, elapsed, duration)
		if (song and song.url) then
			playbackTimeText.text = sFormat("%02d:%02d", elapsed % 60, elapsed / 60)
		else
			playbackTimeText.text = sFormat("%02d:%02d/%02d:%02d", elapsed / 60, elapsed % 60, duration / 60, duration % 60)
		end
	end

	return playbackTimeText
end

return M
