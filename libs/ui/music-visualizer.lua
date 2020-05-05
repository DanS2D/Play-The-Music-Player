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

		emitter.radialAcceleration = (leftLevel / 1000) * (rightLevel / 1000)
		emitter.startParticleSize = 1
		emitter.finishParticleSizeVariance = emitter.startParticleSize
		emitter.startColorAlpha = 0
		emitter.finishColorAlpha = 1
	--emitter.startColorRed = 1
	--emitter.startColorBlue = 1
	--emitter.startColorGreen = 1
	--emitter.startColorVarianceAlpha = (leftLevel / 100000 * 2)
	--emitter.startColorVarianceRed = (leftLevel / 100000 * 3)
	--emitter.startColorVarianceBlue = (leftLevel / 100000 * 3)
	--emitter.startColorVarianceGreen = (leftLevel / 100000 * 3)
	--emitter.gravityx = leftLevel / 100
	--emitter.gravityy = leftLevel / 100
	--emitter.sourcePositionVariancex = leftLevel / 200
	--emitter.sourcePositionVariancey = -(leftLevel / 200)
	--emitter.speedVariance = leftLevel / 50
	--emitter.startParticleSize = leftLevel / 3200
	--emitter.radialAccelVariance = leftLevel / 300
	end

	return true
end

Runtime:addEventListener("enterFrame", updateVisualizer)

function M.new(options)
	local fileName = options.fileName or "galaxy.json"
	local emitterParams = fileUtils:loadTable(sFormat("%s%s", visualizerDataPath, fileName), system.ResourceDirectory)
	emitter = display.newEmitter(emitterParams)
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
