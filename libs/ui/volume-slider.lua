local M = {}
local mFloor = math.floor
local mMin = math.min
local mMax = math.max

function M.new(options)
	local width = options.width
	local height = options.height or 12
	local handleWidth = options.handleWidth or 15
	local handleHeight = options.handleHeight or 18
	local outerColor = options.outerColor or {0.28, 0.28, 0.28, 1}
	local innerColor = options.innerColor or {0.6, 0.6, 0.6, 1}
	local handleColor = options.innerColor or {1, 1, 1, 0.8}
	local initialValue = options.value or 0
	local listener = options.listener
	local group = display.newGroup()
	local outerBox = nil
	local innerBox = nil
	local value = 0
	group.actualWidth = width

	local outerBox = display.newRoundedRect(0, 0, width, height, 2)
	outerBox.anchorX = 0
	outerBox.x = 0
	outerBox:setFillColor(unpack(outerColor))
	group:insert(outerBox)

	local innerBox = display.newRoundedRect(0, 0, 0, height, 2)
	innerBox.anchorX = 0
	innerBox.x = 0
	innerBox:setFillColor(unpack(innerColor))
	group:insert(innerBox)

	local handle = display.newRoundedRect(0, 0, handleWidth, handleHeight, 2)
	handle.anchorX = 0
	handle.x = 0
	handle:setFillColor(unpack(handleColor))
	group:insert(handle)

	function handle:touch(event)
		local phase = event.phase
		local target = event.target

		if (phase == "began") then
			display.getCurrentStage():setFocus(target)
			target.beganX = event.x - target.x
		elseif (phase == "moved") then
			target.x = event.x - target.beganX

			if (target.x + target.contentWidth * 0.5 <= 0) then
				target.x = -target.contentWidth * 0.5
			elseif (target.x + target.contentWidth * 0.5 >= width) then
				target.x = width - target.contentWidth * 0.5
			end

			if (type(listener) == "function") then
				local listenerEvent = {
					value = target.x + (target.contentWidth * 0.5)
				}
				listener(listenerEvent)
			end

			self.parent:setValue(target.x + target.contentWidth * 0.5)
		elseif (phase == "ended" or phase == "cancelled") then
			display.getCurrentStage():setFocus(nil)
		end

		return true
	end

	handle:addEventListener("touch")

	function group:touch(event)
		local phase = event.phase

		if (phase == "began") then
			local valueX, valueY = self:contentToLocal(event.x, event.y)
			self:setValue(valueX)
		end

		return true
	end

	group:addEventListener("touch")

	function group:setValue(newValue)
		value = (newValue / width)
		innerBox.width = mMin(width, (width / 100) * (value * 100))
		handle.x = innerBox.width - handle.contentWidth * 0.5
	end

	function group:getValue()
		return value
	end

	value = initialValue
	handle.x = value - handle.contentWidth
	group:setValue(value)

	return group
end

return M
