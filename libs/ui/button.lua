local M = {}
local fontAwesomeSolidFont = "fonts/Font-Awesome-5-Free-Solid-900.otf"

function M.new(options)
	local x = options.x or 0
	local y = options.y or 0
	local iconName = options.iconName or error("button.new() iconName (string) expected, got", type(options.fontName))
	local fontSize = options.fontSize or 14
	local fillColor = options.fillColor or {0.7, 0.7, 0.7}
	local ignoreHitbox = options.ignoreHitbox or false
	local onClick = options.onClick
	local parent = options.parent or display.getCurrentStage()

	local button =
		display.newText(
		{
			text = iconName,
			font = fontAwesomeSolidFont,
			fontSize = fontSize,
			align = "center"
		}
	)
	button.x = x
	button.y = y
	button.ignoreHitbox = ignoreHitbox
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
			self.alpha = 0.6
		elseif (phase == "ended" or phase == "cancelled") then
			self.alpha = 1

			if (self.ignoreHitbox) then
				if (type(onClick) == "function") then
					onClick(event)
				end
			else
				if (eventX >= target.x - targetHalfWidth and eventX <= target.x + targetHalfWidth) then
					if (eventY >= target.y - targetHalfHeight and eventY <= target.y + targetHalfHeight) then
						if (type(onClick) == "function") then
							onClick(event)
						end
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
