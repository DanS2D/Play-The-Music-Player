local M = {}
local fontAwesomeSolidFont = "fonts/Font-Awesome-5-Free-Solid-900.otf"

function M.new(options)
	local x = options.x or 0
	local y = options.y or 0
	local buttonOptions =
		options.buttonOptions or error("multiButton.new() buttonOptions (string) expected, got", type(options.buttonOptions))
	local fontSize = options.fontSize or 14
	local fillColor = options.fillColor or {0.7, 0.7, 0.7}
	local parent = options.parent or display.getCurrentStage()
	local buttons = {}
	local group = display.newGroup()
	group.x = x
	group.y = y

	local function touch(event)
		local phase = event.phase
		local target = event.target
		local targetHalfWidth = (target.contentWidth * 0.5)
		local targetHalfHeight = (target.contentHeight * 0.5)
		local eventX, eventY = target:contentToLocal(event.x, event.y)

		if (phase == "began") then
			display.getCurrentStage():setFocus(target)

			if (not target.ignoreAlpha) then
				target.alpha = 0.6
			end
		elseif (phase == "ended" or phase == "cancelled") then
			if (not target.ignoreAlpha) then
				target.alpha = 1
			end

			if (eventX >= target.x - targetHalfWidth and eventX <= target.x + targetHalfWidth) then
				if (eventY >= target.y - targetHalfHeight and eventY <= target.y + targetHalfHeight) then
					local index = target.index + 1

					if (index > #buttons) then
						index = 1
					end

					group:setIsOn(index, true)

					if (type(target.onClick) == "function") then
						target.onClick(event)
					end
				end
			end

			display.getCurrentStage():setFocus(nil)
		end

		return true
	end

	for i = 1, #buttonOptions do
		buttons[i] =
			display.newText(
			{
				text = buttonOptions[i].iconName,
				font = fontAwesomeSolidFont,
				fontSize = fontSize,
				align = "center"
			}
		)
		buttons[i].alpha = buttonOptions[i].alpha or 1
		buttons[i].ignoreAlpha = buttons[i].alpha ~= 1
		buttons[i].name = buttonOptions[i].name
		buttons[i].index = i
		buttons[i].isOn = i == 1 and true or false
		buttons[i].isVisible = i == 1
		buttons[i].onClick = buttonOptions[i].onClick
		buttons[i]:setFillColor(unpack(fillColor))
		buttons[i]:addEventListener("touch", touch)
		group:insert(buttons[i])
	end

	function group:getIsOn(index)
		return buttons[index].isOn
	end

	function group:setIsOn(index, isOn)
		for i = 1, #buttons do
			buttons[i].isVisible = index == i and isOn
			buttons[i].isOn = index == i and isOn
		end
	end

	parent:insert(group)

	return group
end

return M
