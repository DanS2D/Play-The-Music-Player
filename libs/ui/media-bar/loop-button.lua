local M = {}
local audioLib = require("libs.audio-lib")
local multiButtonLib = require("libs.ui.multi-button")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")

function M.new(parent)
	local button = nil

	button =
		multiButtonLib.new(
		{
			fontSize = common.smallButtonFontSize,
			buttonOptions = {
				{
					iconName = _G.isLinux and "" or "repeat",
					name = "off",
					alpha = 0.6,
					onClick = function(event)
						audioLib.loopAll = true
						audioLib.loopOne = false
					end
				},
				{
					iconName = _G.isLinux and "" or "repeat",
					name = "repeatAll",
					onClick = function(event)
						audioLib.loopOne = true
						audioLib.loopAll = false
					end
				},
				{
					iconName = _G.isLinux and "" or "repeat-1",
					name = "repeatOne",
					onClick = function(event)
						audioLib.loopAll = false
						audioLib.loopOne = false
					end
				}
			}
		}
	)

	return button
end

return M
