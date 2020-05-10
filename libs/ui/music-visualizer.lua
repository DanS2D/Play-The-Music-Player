local M = {}
local audioLib = require("libs.audio-lib")
local fileUtils = require("libs.file-utils")
local sFormat = string.format
local emitter = nil
local visualizerDataPath = "data/visualizers/"
local visualizerImagePath = "img/particles/"

local function updateVisualizer()
	if (emitter and audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		local leftLevel, rightLevel = audioLib.getLevel()
		local minLevel = 0
		local maxLevel = 32768
		local chunk = 2520

		if (emitter.name == "firebar" or emitter.name == "waterfall") then
			emitter.y = 8
			emitter.gravityy = (leftLevel / 1500) * (rightLevel / 1500)
		elseif (emitter.name == "pixies") then
			emitter.startColorVarianceRed = (leftLevel / 100000 * 3)
			emitter.gravityx = -((leftLevel / 2000) * (rightLevel / 2000))
		end
	end

	return true
end

Runtime:addEventListener("enterFrame", updateVisualizer)

function M.new(options)
	local fileName = options and options.fileName or "pixies"
	local emitterParams = fileUtils:loadTable(sFormat("%s%s.json", visualizerDataPath, fileName), system.ResourceDirectory)
	emitter = display.newEmitter(emitterParams)
	emitter.name = options and options.name or "pixies"
	emitter.name = emitter.name:lower()
	emitterParams = nil
	emitter:stop()

	return emitter
end

function M.pause()
	emitter:pause()
end

function M.start()
	emitter:start()
end

function M.stop()
	emitter:stop()
end

function M.remove()
	display.remove(emitter)
	emitter = nil
end

return M
