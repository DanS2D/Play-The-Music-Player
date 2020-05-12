local M = {}
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"

function M.new(options)
	local x = options.x or 0
	local y = options.y or 0
	local iconName = options.iconName or error("button.new() iconName (string) expected, got", type(options.fontName))
	local fontSize = options.fontSize or 14
	local font = options.font or fontAwesomeSolidFont
	local fillColor = options.fillColor or {0.7, 0.7, 0.7}
	local onClick = options.onClick
	local parent = options.parent or display.getCurrentStage()

	local button =
		display.newText(
		{
			text = iconName,
			font = font,
			fontSize = fontSize,
			align = "center"
		}
	)
	button.x = x
	button.y = y
	button:setFillColor(unpack(fillColor))
	parent:insert(button)

	function button:touch(event)
		local phase = event.phase
		local target = event.target
		local targetHalfWidth = (target.contentWidth * 0.5)
		local targetHalfHeight = (target.contentHeight * 0.5)
		local eventX = event.x
		local eventY = event.y

		if (phase == "began") then
			display.getCurrentStage():setFocus(target)
			target.alpha = 0.6
		elseif (phase == "ended" or phase == "cancelled") then
			target.alpha = 1

			local xCheck = (eventX >= target.x - targetHalfWidth and eventX <= target.x + targetHalfWidth)

			if (target.anchorX == 0) then
				xCheck = (eventX >= target.x and eventX <= target.x + target.contentWidth)
			end

			if (xCheck) then
				if (eventY >= target.y - targetHalfHeight and eventY <= target.y + targetHalfHeight) then
					if (type(onClick) == "function") then
						onClick(event)
					end
				end
			end

			display.getCurrentStage():setFocus(nil)
		end

		return true
	end

	button:addEventListener("touch")

	return button
end

return M
