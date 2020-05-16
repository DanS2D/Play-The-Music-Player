local M = {}
local audioLib = require("libs.audio-lib")
local fileUtils = require("libs.file-utils")
local settings = require("libs.settings")
local sFormat = string.format
local mRandom = math.random
local mRandomSeed = math.randomseed
local osTime = os.time
local emitter = nil
local visualizerDataPath = "data/visualizers/"
local visualizerImagePath = "img/particles/"

local function updateVisualizer()
	if (toboolean(settings.showVisualizer)) then
		if (emitter and audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
			local leftLevel, rightLevel = audioLib.getLevel()
			local minLevel = 0
			local maxLevel = 32768
			local chunk = 2520

			if (emitter.name == "firebar") then
				emitter.x = display.contentCenterX
				emitter.y = 20
				emitter.gravityy = (leftLevel / 1500) * (rightLevel / 1500)
			elseif (emitter.name == "pixies") then
				emitter.x = display.contentCenterX
				emitter.startColorVarianceRed = (leftLevel / 100000 * 3)
				emitter.gravityx = -((leftLevel / 2000) * (rightLevel / 2000))
			end
		end
	end

	return true
end

--Runtime:addEventListener("enterFrame", updateVisualizer)

function M.new(options)
	--[[
	if (toboolean(settings.showVisualizer)) then
		local visualizerList = settings.selectedVisualizers
		local visualizers = {}

		for k, v in pairs(visualizerList) do
			if (visualizerList[k].enabled) then
				visualizers[#visualizers + 1] = {
					name = visualizerList[k].name
				}
			end
		end

		if (#visualizers > 0) then
			mRandomSeed(osTime())

			local visualizerName = visualizers[mRandom(1, #visualizers)].name
			local emitterParams =
				fileUtils:loadTable(sFormat("%s%s.json", visualizerDataPath, visualizerName), system.ResourceDirectory)
			emitter = display.newEmitter(emitterParams)
			emitter.x = display.contentCenterX
			emitter.y = 0
			emitter.name = visualizerName:lower()

			if (options and options.group) then
				options.group:insert(emitter, true)
			end

			emitterParams = nil
			emitter:toBack()
			emitter:stop()

			if (audioLib.isChannelPlaying()) then
				emitter:start()
			end
		end
	end--]]
	return emitter
end

function M:pause()
	--[[
	if (toboolean(settings.showVisualizer)) then
		if (emitter) then
			emitter:pause()
		end
	end--]]
end

function M:start()
	--[[
	if (toboolean(settings.showVisualizer)) then
		if (emitter) then
			emitter:start()
		end
	end--]]
end

function M:restart()
	--[[
	if (toboolean(settings.showVisualizer)) then
		self:remove()
		self.new({})
	else
		self:remove()
	end--]]
end

function M:remove()
	--[[
	if (emitter) then
		emitter:stop()
		display.remove(emitter)
		emitter = nil
	end--]]
end

return M
