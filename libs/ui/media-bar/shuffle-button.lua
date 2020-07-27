local M = {}
local audioLib = require("libs.audio-lib")
local switchLib = require("libs.ui.switch")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button = nil

	button =
		switchLib.new(
		{
			offIconName = _G.isLinux and "" or "random",
			onIconName = _G.isLinux and "" or "random",
			offAlpha = 0.6,
			fontSize = common.smallButtonFontSize,
			parent = parent,
			onClick = function(event)
				audioLib.shuffle = event.target.isOffButton
			end
		}
	)

	return button
end

return M
