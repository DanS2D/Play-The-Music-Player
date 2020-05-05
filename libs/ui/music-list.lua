local sqlLib = require("libs.sql-lib")
local M = {
	musicFunction = sqlLib.getMusicRowByTitle,
	musicSortAToZ = true,
	rowCreationTimers = {}
}
local widget = require("widget")
local mousecursor = require("plugin.mousecursor")
local audioLib = require("libs.audio-lib")
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
local defaultRowColor = {default = {0.10, 0.10, 0.10, 1}, over = {0.38, 0.38, 0.38, 0}}
local defaultSecondRowColor = {default = {0.15, 0.15, 0.15, 1}, over = {0.28, 0.28, 0.28, 0}}
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local resizeCursor = mousecursor.newCursor("resize left right")

local function resetRowColors()
	local firstTableView = tableViewList[1]

	for i = 1, #tableViewList do
		for j = 1, firstTableView:getNumRows() do
			local list = tableViewList[i]._view._rows[j] and tableViewList[i]._view._rows[j]._view
			local rowColor = defaultRowColor

			if (j % 2 == 0) then
				rowColor = defaultSecondRowColor
			end

			if (list) then
				list._cell:setFillColor(unpack(rowColor.default))
			end
		end
	end
end

local function highlightPressedIndex()
	local pressedIndex = audioLib.currentSongIndex

	if (pressedIndex > 0 and #tableViewList > 0) then
		local firstTableView = tableViewList[1]

		for i = 1, #tableViewList do
			for j = 1, firstTableView:getNumRows() do
				local list = tableViewList[i]._view._rows[j] and tableViewList[i]._view._rows[j]._view
				local rowColor = defaultRowColor

				if (j % 2 == 0) then
					rowColor = defaultSecondRowColor
				end

				if (list) then
					list._cell:setFillColor(unpack(rowColor.default))
				end
			end

			if (tableViewList[i]._view._rows[pressedIndex]._view) then
				tableViewList[i]._view._rows[pressedIndex]._view._cell:setFillColor(0.5, 0.5, 0.5, 1)
			end
		end
	end
end

Runtime:addEventListener("enterFrame", highlightPressedIndex)

local function hasValidMusicData()
	return sqlLib.musicCount() > 0
end

local function createTableView(options)
	local tView =
		tableView.new(
		{
			left = options.left,
			top = 80 + rowHeight,
			width = options.width or (dWidth / 5),
			height = dHeight - 100,
			isLocked = true,
			noLines = true,
			rowTouchDelay = 0,
			backgroundColor = {0.10, 0.10, 0.10, 1},
			onRowRender = function(event)
				local phase = event.phase
				local row = event.row
				local rowContentWidth = row.contentWidth
				local rowContentHeight = row.contentHeight
				local realIndex = row.index
				local musicData = M.musicFunction(row.index, M.musicSortAToZ)

				local rowTitleText =
					display.newText(
					{
						text = musicData[options.rowTitle] or "",
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
				row:insert(rowTitleText)
			end,
			onRowTouch = function(event)
				local phase = event.phase
				local row = event.row

				if (phase == "press") then
					local musicData = M.musicFunction(row.index, M.musicSortAToZ)
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
		local indx = 60

		local function lazyCreateRows(event)
			local rowColor = defaultRowColor
			indx = indx + 1

			if (indx % 2 == 0) then
				rowColor = defaultSecondRowColor
			end

			tView:insertRow {
				isCategory = false,
				rowHeight = rowHeight,
				rowColor = rowColor
			}

			if (indx >= sqlLib.musicCount()) then
				timer.cancel(event.source)
				print("finished creating rows")
				return
			end

			M.rowCreationTimers[#M.rowCreationTimers + 1] = timer.performWithDelay(25, lazyCreateRows)
		end

		M.rowCreationTimers[#M.rowCreationTimers + 1] = timer.performWithDelay(1000, lazyCreateRows)

		for i = 1, 60 do
			local rowColor = defaultRowColor

			if (i % 2 == 0) then
				rowColor = defaultSecondRowColor
			end

			tView:insertRow {
				isCategory = false,
				rowHeight = rowHeight,
				rowColor = rowColor
			}
		end

		resetRowColors()
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
			tableViewTarget.x = mFloor(event.x + tableViewTarget.contentWidth * 0.5)
			categoryTarget.x = mFloor(event.x + categoryTarget.contentWidth * 0.5 - 20)
		end

		if (phase == "ended" or phase == "cancelled") then
			resizeCursor:hide()
			tableViewTarget = nil

			for i = 1, #tableViewList do
				tableViewList[i]:addListeners()
			end
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

	for j = 1, #tableViewList do
		tableViewList[j]:mouse(event)
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

function M.populate()
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
