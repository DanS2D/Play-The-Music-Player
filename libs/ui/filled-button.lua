local M = {}
local theme = require("libs.theme")
local uPack = unpack
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"

function M.new(options)
	local x = options.x or 0
	local y = options.y or 0
	local iconName =
		options.iconName or error("filled-button.new() buttonLabel (string) expected, got " .. type(options.iconName))
	local buttonLabel = options.labelText
	local fontSize = options.fontSize or 14
	local font = options.font or subTitleFont
	local fillColor = options.fillColor or theme:get().iconColor.primary
	local onClick = options.onClick
	local parent = options.parent or display.getCurrentStage()
	local group = display.newGroup()
	local label = nil

	local icon =
		display.newText(
		{
			text = iconName,
			font = fontAwesomeSolidFont,
			fontSize = fontSize,
			align = "center"
		}
	)
	icon:setFillColor(unpack(fillColor))
	group:insert(icon)

	if (buttonLabel) then
		label =
			display.newText(
			{
				text = buttonLabel,
				font = font,
				fontSize = fontSize,
				align = "center"
			}
		)
		label.x = icon.x + icon.contentWidth + label.contentWidth * 0.5
		label:setFillColor(uPack(theme:get().textColor.primary))
		group:insert(label)
	end

	local background = display.newRoundedRect(0, 0, group.contentWidth * 1.5, group.contentHeight, 2)
	background.x = (buttonLabel) and icon.x + icon.contentWidth + label.contentWidth * 0.25 or icon.x
	background:setFillColor(uPack(theme:get().backgroundColor.primary))
	group:insert(1, background)

	function group:touch(event)
		local phase = event.phase
		local target = event.target
		local targetHalfWidth = (target.contentWidth * 0.5)
		local targetHalfHeight = (target.contentHeight * 0.5)
		local eventX, eventY = target:contentToLocal(event.x, event.y)

		if (phase == "began") then
			display.getCurrentStage():setFocus(target)
			target.alpha = 0.6
		elseif (phase == "ended" or phase == "cancelled") then
			target.alpha = 1.0

			if (eventX + targetHalfWidth >= 0 and eventX + targetHalfWidth <= target.contentWidth) then
				if (eventY + targetHalfHeight >= 0 and eventY + targetHalfHeight <= target.contentHeight) then
					if (type(onClick) == "function") then
						onClick(event)
					end
				end
			end

			display.getCurrentStage():setFocus(nil)
		end

		return true
	end

	group:addEventListener("touch")

	group.anchorX = 0
	group.x = x
	group.y = y
	parent:insert(group)

	return group
end

return M
