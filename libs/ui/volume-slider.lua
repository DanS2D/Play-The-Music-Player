local M = {}
local theme = require("libs.theme")
local mFloor = math.floor
local mMin = math.min
local mMax = math.max

function M.new(options)
	local width = options.width
	local height = options.height or 12
	local handleWidth = options.handleWidth or 15
	local handleHeight = options.handleHeight or 20
	local outerColor = options.outerColor or theme:get().iconColor.highlighted
	local innerColor = options.innerColor or theme:get().iconColor.primary
	local handleColor = options.handleColor or theme:get().textColor.secondary
	local initialValue = options.value or 0
	local listener = options.listener
	local onTouchEnded = options.onTouchEnded
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
	handle.beganX = 0
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

			self.parent:setValue(target.x + target.contentWidth * 0.5)

			if (type(listener) == "function") then
				local listenerEvent = {
					value = group:getValue() * 100
				}

				listener(listenerEvent)
			end
		elseif (phase == "ended" or phase == "cancelled") then
			if (type(onTouchEnded) == "function") then
				local listenerEvent = {
					value = group:getValue() * 100
				}

				onTouchEnded(listenerEvent)
			end
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

			if (type(onTouchEnded) == "function") then
				local listenerEvent = {
					value = valueX
				}

				onTouchEnded(listenerEvent)
			end
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
