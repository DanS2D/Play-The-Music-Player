local M = {}
local theme = require("libs.theme")
local uPack = unpack
local mMax = math.max
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"
local ratings = {
	["0"] = 0,
	["13"] = 0.5,
	["1"] = 1,
	["54"] = 1.5,
	["64"] = 2,
	["118"] = 2.5,
	["128"] = 3,
	["186"] = 3.5,
	["196"] = 4,
	["242"] = 4.5,
	["255"] = 5
}
local ratingsInverse = {
	["0"] = 0,
	["0.5"] = 13,
	["1"] = 1,
	["1.5"] = 54,
	["2"] = 64,
	["2.5"] = 118,
	["3"] = 128,
	["3.5"] = 186,
	["4"] = 196,
	["4.5"] = 242,
	["5"] = 255
}
local ratingStars = {
	["0"] = {
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["0.5"] = {
		{name = "star-half-alt", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["1"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["1.5"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star-half-alt", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["2"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["2.5"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star-half-alt", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["3"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["3.5"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star-half-alt", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["4"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont, isEmpty = true}
	},
	["4.5"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star-half-alt", font = fontAwesomeSolidFont}
	},
	["5"] = {
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont},
		{name = "star", font = fontAwesomeSolidFont}
	}
}

function M.new(options)
	local currentStars = {}
	local parent = options.parent or display.getCurrentStage()
	local starRating = ratingStars[tostring(options.rating)]
	local fontSize = options.fontSize or 10
	local x = options.x or 0
	local y = options.y or 0
	local isVisible = options.isVisible or false
	local onClick = options.onClick
	local group = display.newGroup()
	group.anchorX = 0.5
	group.anchorY = 0.5
	group.anchorChildren = true
	group.isVisible = isVisible
	group.rating = 0

	local function ratingClick(event)
		local phase = event.phase
		local target = event.target
		local eventX, eventY = target:contentToLocal(event.x, event.y)
		local fullWidth = target.contentWidth
		local currentIndex = target.index
		local quarter = fullWidth / 4
		local half = fullWidth / 2
		eventX = eventX + half

		if (phase == "began") then
			-- check which part of the star we clicked
			if (eventX > 0 and eventX < half) then
				target.rating = target.index == 1 and 0.5 or target.index - 1 + 0.5
			elseif (eventX > half + (quarter / 2)) then
				target.rating = target.index
			end

			if (type(onClick) == "function") then
				local starEvent = {
					rating = target.rating,
					parent = target.parent,
					mp3Rating = ratingsInverse[tostring(target.rating)]
				}
				onClick(starEvent)
			end
		end

		return true
	end

	for i = 1, #starRating do
		currentStars[i] =
			display.newText(
			{
				text = starRating[i].name,
				font = starRating[i].font,
				fontSize = fontSize,
				align = "center"
			}
		)

		currentStars[i].anchorX = 0
		currentStars[i].x = i == 1 and 0 or currentStars[i - 1].x + currentStars[i - 1].contentWidth
		currentStars[i].y = 0
		currentStars[i].index = i
		currentStars[i].rating = 0

		if (starRating[i].isEmpty) then
			currentStars[i]:setFillColor(uPack(theme:get().iconColor.highlighted))
		else
			currentStars[i]:setFillColor(uPack(theme:get().iconColor.primary))
		end
		currentStars[i]:addEventListener("touch", ratingClick)
		group:insert(currentStars[i])
	end

	group.x = x
	group.y = y
	parent:insert(group)

	function group:update(newRating)
		if (#currentStars > 0) then
			local currentRating = ratingStars[tostring(newRating)]

			for i = 1, #currentStars do
				currentStars[i].text = currentRating[i].name
				if (currentRating[i].isEmpty) then
					currentStars[i]:setFillColor(uPack(theme:get().iconColor.highlighted))
				else
					currentStars[i]:setFillColor(uPack(theme:get().iconColor.primary))
				end
			end
		end
	end

	function group:destroy()
		if (#currentStars > 0) then
			for i = 1, #currentStars do
				currentStars[i]:removeEventListener("touch", ratingClick)
				display.remove(currentStars[i])
				currentStars[i] = nil
			end

			currentStars = nil
		end
	end

	return group
end

function M:convert(rating)
	return ratings[tostring(rating)]
end

function M:convertBack(rating)
	return ratingsInverse[tostring(rating)]
end

return M
