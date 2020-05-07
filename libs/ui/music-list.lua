local sqlLib = require("libs.sql-lib")
local M = {
	musicFunction = sqlLib.getMusicRowByTitle,
	musicSortAToZ = true,
	musicSearch = nil,
	musicCount = 0,
	rowCreationTimers = {}
}
local widget = require("widget")
local mousecursor = require("plugin.mousecursor")
local audioLib = require("libs.audio-lib")
local desktopTableView = require("libs.ui.desktop-table-view")
local tableView = require("libs.ui.music-tableview")
local musicImporter = require("libs.music-importer")
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local tableViewList = {}
local tableViewTarget = nil
local categoryList = {}
local categoryTarget = nil
local rowFontSize = 10
local rowHeight = 20
local defaultRowColor = {default = {0.10, 0.10, 0.10, 1}, over = {0.38, 0.38, 0.38, 1}}
local defaultSecondRowColor = {default = {0.15, 0.15, 0.15, 1}, over = {0.28, 0.28, 0.28, 1}}
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local resizeCursor = mousecursor.newCursor("resize left right")

local function hasValidMusicData()
	return M.musicCount > 0
end

local function createTableView(options)
	local tView =
		desktopTableView.new(
		{
			left = options.left,
			top = 80 + rowHeight,
			width = options.width or (dWidth / 5),
			height = dHeight - 100,
			isLocked = true,
			noLines = true,
			rowTouchDelay = 0,
			backgroundColor = {0.10, 0.10, 0.10, 1},
			rowColorDefault = defaultRowColor,
			rowColorAlternate = defaultSecondRowColor,
			onRowRender = function(event)
				local phase = event.phase
				local parent = event.parent
				local row = event.row
				local rowContentWidth = row.contentWidth
				local rowContentHeight = row.contentHeight
				local musicData = M.musicFunction(row.index, M.musicSortAToZ, M.musicSearch)
				local rowLimit = M.musicSearch ~= nil and sqlLib.searchCount() or sqlLib.musicCount()
				parent:setRowLimit(rowLimit)

				--[[
				if (row.index > M.musicCount) then
					row.isVisible = false
				else
					row.isVisible = true

					if (M.musicSearch ~= nil) then
						M.musicCount = sqlLib.searchCount()
					end
				end--]]
				local rowTitleText =
					display.newText(
					{
						text = row.index <= M.musicCount and musicData and musicData[options.rowTitle] or "",
						font = subTitleFont,
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						width = rowContentWidth - 10,
						align = "left"
					}
				)
				rowTitleText.anchorX = 0
				rowTitleText.x = 10

				if (rowTitleText.text:lower() == "lady (hear me tonight)") then
					rowTitleText:setFillColor(1, 0, 0)
				end
				row:insert(rowTitleText)
			end,
			onRowClick = function(event)
				local phase = event.phase
				local numClicks = event.numClicks
				local parent = event.parent
				local row = event.row

				if (numClicks > 1) then
					local musicData = M.musicFunction(row.index, M.musicSortAToZ, M.musicSearch)

					if (musicData == nil) then
						return
					end

					parent:setRowSelected(row.index)

					audioLib.currentSongIndex = row.index
					audioLib.load(musicData)
					audioLib.play(musicData)
				end
			end
		}
	)
	tView.leftPos = options.left
	tView.topPos = 80
	tView.orderIndex = options.index

	function tView:populate()
		--print("Creating initial rows")
		M.musicCount = M.musicSearch ~= nil and sqlLib.searchCount() or sqlLib.musicCount()

		tView:createRows()
		tView:setRowLimit(M.musicCount)
	end

	return tView
end

local function moveColumns(event)
	local phase = event.phase

	if (not hasValidMusicData()) then
		return
	end

	if (tableViewTarget) then
		if (phase == "moved") then
			tableViewTarget.x = mFloor(event.x)
			categoryTarget.x = mFloor(event.x + categoryTarget.contentWidth * 0.5 - 20)
		end

		if (phase == "ended" or phase == "cancelled") then
			resizeCursor:hide()
			tableViewTarget = nil
		end
	end

	return true
end

Runtime:addEventListener("touch", moveColumns)

local function onMouseEvent(event)
	local eventType = event.type
	local y = event.y

	if (not hasValidMusicData()) then
		return
	end

	if (eventType == "move") then
		-- handle main menu buttons
		if (y >= 80 + rowHeight) then
			resizeCursor:hide()
		end
	elseif (eventType == "up") then
		resizeCursor:hide()
	end
end

Runtime:addEventListener("mouse", onMouseEvent)

function M.new()
	local categoryBar = display.newRect(0, 0, dWidth, rowHeight)
	categoryBar.anchorX = 0
	categoryBar.anchorY = 0
	categoryBar.x = 0
	categoryBar.y = 80
	categoryBar:setFillColor(0.15, 0.15, 0.15)

	local listOptions = {
		{
			index = 1,
			left = 0,
			width = dWidth,
			showSeperatorLine = true,
			categoryTitle = "Title",
			rowTitle = "title"
		},
		{
			index = 2,
			left = 200,
			width = dWidth,
			showSeperatorLine = true,
			categoryTitle = "Artist",
			rowTitle = "artist"
		},
		{
			index = 3,
			left = 400,
			width = dWidth,
			showSeperatorLine = true,
			categoryTitle = "Album",
			rowTitle = "album"
		},
		{
			index = 4,
			left = 600,
			width = dWidth,
			showSeperatorLine = true,
			categoryTitle = "Genre",
			rowTitle = "genre"
		},
		{
			index = 5,
			left = 750,
			width = dWidth,
			showSeperatorLine = true,
			categoryTitle = "Duration",
			rowTitle = "duration"
		}
	}

	for i = 1, #listOptions do
		tableViewList[i] = createTableView(listOptions[i])
		categoryList[i] = display.newGroup()
		categoryList[i].x = listOptions[i].left
		categoryList[i].y = 80
		categoryList[i].index = i
		--categoryList[i].isVisible = false -- REMOVE THIS WHEN THE NEW TABLEVIEW WORKS

		local seperatorText =
			display.newText(
			{
				text = "|",
				left = 0,
				y = categoryBar.contentHeight * 0.5,
				font = subTitleFont,
				fontSize = 18,
				align = "left"
			}
		)
		seperatorText:setFillColor(0.8, 0.8, 0.8)
		categoryList[i]:insert(seperatorText)

		function seperatorText:touch(event)
			local phase = event.phase

			if (phase == "began") then
				tableViewTarget = tableViewList[self.parent.index]
				categoryTarget = categoryList[i]
			elseif (phase == "ended" or phase == "cancelled") then
				tableViewTarget = nil
			end

			return true
		end

		function seperatorText:mouse(event)
			local phase = event.type
			local xStart = self.x
			local xEnd = self.x + self.contentWidth
			local yStart = self.y - self.contentHeight * 0.5
			local yEnd = self.y + self.contentHeight * 0.5
			local x, y = self:contentToLocal(event.x, event.y)

			if (phase == "move") then
				-- handle main menu buttons
				if (y >= yStart - 8 and y <= yStart + 8) then
					if (x >= xStart - 2 and x <= xEnd - 4) then
						resizeCursor:show()
					else
						resizeCursor:hide()
					end
				else
					resizeCursor:hide()
				end
			end
		end

		seperatorText:addEventListener("touch")
		seperatorText:addEventListener("mouse")

		local titleText =
			display.newText(
			{
				text = listOptions[i].categoryTitle,
				y = categoryBar.contentHeight * 0.5,
				font = titleFont,
				fontSize = 10,
				align = "left"
			}
		)
		titleText.anchorX = 0
		titleText.x = seperatorText.x + seperatorText.contentWidth
		titleText.sortAToZ = i == 1 or false
		titleText:setFillColor(1, 1, 1)
		categoryList[i]:insert(titleText)

		local sortIndicator =
			display.newText(
			{
				text = "⌃",
				y = categoryBar.contentHeight * 0.5,
				font = titleFont,
				fontSize = 10,
				align = "left"
			}
		)
		sortIndicator.anchorX = 0
		sortIndicator.x = titleText.x + titleText.contentWidth + 2
		sortIndicator.isVisible = i == 1
		titleText.sortIndicator = sortIndicator
		categoryList[i].sortIndicator = sortIndicator
		categoryList[i]:insert(sortIndicator)

		function titleText:touch(event)
			local phase = event.phase
			local target = event.target
			local xStart = target.x
			local xEnd = target.x + target.contentWidth
			local yStart = target.y - target.contentHeight * 0.5
			local yEnd = target.y + target.contentHeight * 0.5
			local x, y = event.x, event.y

			if (not hasValidMusicData()) then
				return
			end

			if (phase == "began") then
				local thisTableView = tableViewList[self.parent.index]
				local origIndex = tableViewList[thisTableView.orderIndex].orderIndex
				local buttons = {"Right", "Left", "Cancel"}

				if (tableViewList[thisTableView.orderIndex].orderIndex == 1) then
					buttons = {"Right", "Cancel"}
				elseif (tableViewList[thisTableView.orderIndex].orderIndex == #tableViewList) then
					buttons = {"Left", "Cancel"}
				end

				local function onComplete(event)
					local optionName = buttons[event.index]

					if (event.action == "clicked") then
						if (optionName == "Right") then
							local origList = tableViewList[origIndex]
							local origPreviousList = tableViewList[origIndex + 1]
							local origCategory = categoryList[origIndex]
							local origPreviousCategory = categoryList[origIndex + 1]
							local targetX = tableViewList[origIndex + 1].x
							local swapTargetX = tableViewList[origIndex].x
							local targetCategoryX = categoryList[origIndex + 1].x
							local swapTargetCategoryX = categoryList[origIndex].x

							-- swap positions
							tableViewList[origIndex].x = targetX
							tableViewList[origIndex + 1].x = swapTargetX
							categoryList[origIndex].x = targetCategoryX
							categoryList[origIndex + 1].x = swapTargetCategoryX

							-- set new indexes
							tableViewList[origIndex + 1].orderIndex = origIndex
							tableViewList[origIndex].orderIndex = origIndex + 1
							categoryList[origIndex + 1].index = origIndex
							categoryList[origIndex].index = origIndex + 1

							-- swap table items
							tableViewList[origIndex + 1] = origList
							tableViewList[origIndex] = origPreviousList
							categoryList[origIndex + 1] = origCategory
							categoryList[origIndex] = origPreviousCategory

							-- push moved (left) list to front
							tableViewList[origIndex]:toFront()

							for i = origIndex + 1, #tableViewList do
								tableViewList[i]:toFront()
							end
						elseif (optionName == "Left") then
							local origList = tableViewList[origIndex]
							local origPreviousList = tableViewList[origIndex - 1]
							local origCategory = categoryList[origIndex]
							local origPreviousCategory = categoryList[origIndex - 1]
							local targetX = tableViewList[origIndex - 1].x
							local swapTargetX = tableViewList[origIndex].x
							local targetCategoryX = categoryList[origIndex - 1].x
							local swapTargetCategoryX = categoryList[origIndex].x

							-- swap positions
							tableViewList[origIndex].x = targetX
							tableViewList[origIndex - 1].x = swapTargetX
							categoryList[origIndex].x = targetCategoryX
							categoryList[origIndex - 1].x = swapTargetCategoryX

							-- set new indexes
							tableViewList[origIndex - 1].orderIndex = origIndex
							tableViewList[origIndex].orderIndex = origIndex - 1
							categoryList[origIndex - 1].index = origIndex
							categoryList[origIndex].index = origIndex - 1

							-- swap table items
							tableViewList[origIndex - 1] = origList
							tableViewList[origIndex] = origPreviousList
							categoryList[origIndex - 1] = origCategory
							categoryList[origIndex] = origPreviousCategory

							-- push moved (right) list to front
							tableViewList[origIndex]:toFront()

							for i = origIndex + 1, #tableViewList do
								tableViewList[i]:toFront()
							end
						else
							print("cancel")
						end
					end
				end

				for i = 1, #categoryList do
					categoryList[i].sortIndicator.isVisible = false
				end

				self.sortAToZ = not self.sortAToZ
				self.sortIndicator.isVisible = true
				self.sortIndicator.text = self.sortAToZ and "⌃" or "⌄"
				M.musicSortAToZ = self.sortAToZ

				if (self.text:lower() == "title") then
					M.musicFunction = sqlLib.getMusicRowByTitle
				elseif (self.text:lower() == "artist") then
					M.musicFunction = sqlLib.getMusicRowByArtist
				elseif (self.text:lower() == "album") then
					M.musicFunction = sqlLib.getMusicRowByAlbum
				elseif (self.text:lower() == "genre") then
					M.musicFunction = sqlLib.getMusicRowByGenre
				elseif (self.text:lower() == "duration") then
					M.musicFunction = sqlLib.getMusicRowByDuration
				end

				for i = 1, #tableViewList do
					tableViewList[i]:reloadData()
				end

			--local alert = native.showAlert("Move Column", "Choose a direction to move this column to.", buttons, onComplete)
			end

			return true
		end

		titleText:addEventListener("touch")
	end

	return tableViewList
end

function M.removeAllRows()
	M.musicFunction = sqlLib.getMusicRowByTitle
	M.musicSortAToZ = true
	M.musicSearch = nil

	for i = 1, #tableViewList do
		--tableViewList[i]:deleteAllRows()
	end
end

local prevIndex = 0

function M.reloadData(hardReload)
	for i = 1, #tableViewList do
		if (hardReload) then
			if (prevIndex == 0) then
				prevIndex = tableViewList[i]:getRealIndex()
			end
			tableViewList[i]:scrollToIndex(1)
		else
			tableViewList[i]:scrollToIndex(prevIndex)
			print("previous index was: ", prevIndex)
		end
	end

	if (not hardReload) then
		prevIndex = 0
	end
end

function M.populate()
	--print("POPULATE CALLED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	local startSecond = os.date("*t").sec
	musicImporter.pushProgessToFront()
	musicImporter.showProgressBar()
	musicImporter.updateHeading("Loading music library")
	musicImporter.updateSubHeading("Give me a sec..")
	local listIndex = 0

	local function createLists()
		listIndex = listIndex + 1

		if (listIndex > #tableViewList) then
			musicImporter.hideProgress()

			for i = 1, #tableViewList do
				tableViewList[i]:toFront()
			end

			local endSecond = os.date("*t").sec
			print("render time = " .. math.abs(endSecond - startSecond))

			return
		end

		tableViewList[listIndex]:populate()
		musicImporter.setTotalProgress(listIndex / #tableViewList)
		timer.performWithDelay(25, createLists)
	end

	timer.performWithDelay(25, createLists)
end

return M
