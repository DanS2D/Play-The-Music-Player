local M = {}
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
		{name = "star", font = fontAwesomeSolidFont},
		isEmpty = true,
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
local currentStars = {}

local function create(starList, fontSize, group)
	if (#currentStars > 0) then
		for i = 1, #currentStars do
			display.remove(currentStars[i])
			currentStars[i] = nil
		end

		currentStars = nil
		currentStars = {}
	end

	for i = 1, #starList do
		currentStars[i] =
			display.newText(
			{
				text = starList[i].name,
				font = starList[i].font,
				fontSize = fontSize,
				align = "center"
			}
		)

		currentStars[i].x = i == 1 and 0 or currentStars[i - 1].x + currentStars[i - 1].contentWidth
		currentStars[i].y = 0
		currentStars[i].alpha = starList[i].isEmpty and 0.5 or 0.8
		group:insert(currentStars[i])
	end
end

function M.new(options)
	local parent = options.parent or display.getCurrentStage()
	local starRating = ratingStars[tostring(options.rating)]
	local fontSize = options.fontSize or 8
	local x = options.x or 0
	local y = options.y or 0
	local group = display.newGroup()
	group.anchorX = 0.5
	group.anchorY = 0.5
	group.anchorChildren = true

	create(starRating, fontSize, group)

	function group:update(songRating)
		local newRating = ratingStars[tostring(songRating)]

		create(newRating, fontSize, self)

		self.isVisible = true
		self.anchorChildren = true
		self.x = x
		self.y = y
		parent:insert(self)
	end

	parent:insert(group)
	group.isVisible = false

	return group
end

function M:convert(rating)
	return ratings[tostring(rating)]
end

function M:convertBack(rating)
	return ratingsInverse[tostring(rating)]
end

return M
