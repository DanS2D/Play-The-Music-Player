local sqlLib = require("libs.sql-lib")
local M = {
	--musicFunction = sqlLib.getMusicRowByTitle,
	musicSearch = nil,
	musicResultsLimit = 0,
	rowCreationTimers = {}
}
local mousecursor = require("plugin.mousecursor")
local audioLib = require("libs.audio-lib")
local desktopTableView = require("libs.ui.desktop-table-view")
local musicImporter = require("libs.music-importer")
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local tInsert = table.insert
local tableViewList = {}
local tableViewTarget = nil
local categoryList = {}
local categoryTarget = nil
local musicCount = 0
local musicSortAToZ = true
local musicSort = "title" -- todo: get saved sort from database
local prevIndex = 0
local rowFontSize = 18
local rowHeight = 40
local defaultRowColor = {default = {0.10, 0.10, 0.10, 1}, over = {0.38, 0.38, 0.38, 1}}
local defaultSecondRowColor = {default = {0.15, 0.15, 0.15, 1}, over = {0.28, 0.28, 0.28, 1}}
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local resizeCursor = mousecursor.newCursor("resize left right")
local musicData = {}
local currentRowCount = 0
local topPosition = 121

function M:getRow(rowIndex)
	local row = nil

	if (self.musicSearch) then
		-- get search row
		return sqlLib:getMusicRowBySearch(rowIndex, musicSortAToZ, self.musicSearch, 1)
	else
		-- get normal row
		if (musicSort == "album") then
			return sqlLib:getMusicRowByAlbum(rowIndex, musicSortAToZ)
		elseif (musicSort == "artist") then
			return sqlLib:getMusicRowByArtist(rowIndex, musicSortAToZ)
		elseif (musicSort == "duration") then
			return sqlLib:getMusicRowByDuration(rowIndex, musicSortAToZ)
		elseif (musicSort == "genre") then
			return sqlLib:getMusicRowByGenre(rowIndex, musicSortAToZ)
		elseif (musicSort == "title") then
			return sqlLib:getMusicRowByTitle(rowIndex, musicSortAToZ)
		end
	end

	return nil
end

function M:getSearchData()
	local mData = sqlLib:getMusicRowsBySearch(1, musicSortAToZ, musicSort, self.musicSearch, self.musicResultsLimit)
	-- reset the music data
	musicData = {}

	for i = 1, #mData do
		musicData[i] = mData[i]
	end
end

function M:getRowData(rowIndex)
	musicData[rowIndex] = self:getRow(rowIndex)
end

function M:createTableView(options)
	local tView =
		desktopTableView.new(
		{
			left = options.left,
			top = topPosition + rowHeight,
			width = options.width or display.contentWidth,
			height = display.contentHeight - 100,
			rowHeight = rowHeight,
			backgroundColor = {0.10, 0.10, 0.10, 1},
			rowColorDefault = defaultRowColor,
			rowColorAlternate = defaultSecondRowColor,
			onRowRender = function(event)
				local phase = event.phase
				local parent = event.parent
				local row = event.row
				local rowContentWidth = row.contentWidth
				local rowContentHeight = row.contentHeight
				local rowLimit = self.musicSearch ~= nil and sqlLib:searchCount() or sqlLib:musicCount()

				if (self.musicSearch) then
					-- clear the selected row
					parent:setRowSelected(0)
					self.musicResultsLimit = sqlLib:musicCount()
					parent:setRowLimit(rowLimit)
				else
					self.musicResultsLimit = 1
					parent:setRowLimit(rowLimit)

					if (parent._index == 1) then
						self:getRowData(row.index)
					end
				end

				if (row.index > rowLimit) then
					row.isVisible = false
				else
					row.isVisible = true
				end

				local rowTitleText =
					display.newText(
					{
						text = musicData and musicData[row.index] and musicData[row.index][options.rowTitle] or "",
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

				if (parent._index >= 5) then
					if (not self.musicSearch) then
						currentRowCount = currentRowCount + 1

						-- all rows in all columns have been loaded, reset the music data and currentRowCount
						if (currentRowCount >= parent:getMaxRows()) then
							--print("ROWRENDER: removing music data table")
							currentRowCount = 0
							--print("ROWRENDER: number of items in music data ", #musicData)
							musicData = {}
						--print("ROWRENDER: number of items in music data ", #musicData)
						end
					end
				end
			end,
			onRowClick = function(event)
				local phase = event.phase
				local numClicks = event.numClicks
				local row = event.row
				local parent = row.parent

				if (numClicks > 1) then
					local song = self:getRow(row.index)

					if (song == nil) then
						print("SONG IS NIL")
						return
					end

					print("row " .. row.index .. " clicked - playing song " .. song.title)
					parent:setRowSelected(row.index)

					audioLib.currentSongIndex = row.index
					audioLib.load(song)
					audioLib.play(song)
				end
			end
		}
	)
	tView.leftPos = options.left
	tView.topPos = topPosition + rowHeight
	tView.orderIndex = options.index
	tView._index = #tableViewList + 1

	function tView:populate()
		--print("Creating initial rows")
		musicCount = self.musicSearch ~= nil and sqlLib:searchCount() or sqlLib:musicCount()

		tView:createRows()
		tView:setRowLimit(musicCount)
	end

	return tView
end

local function moveColumns(event)
	local phase = event.phase

	if (musicCount <= 0) then
		return
	end

	if (tableViewTarget) then
		if (phase == "moved") then
			tableViewTarget.x = mFloor(event.x)
			categoryTarget.x = mFloor(event.x)
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

	if (musicCount <= 0) then
		return
	end

	if (eventType == "up") then
		if (tableViewTarget) then
			display.getCurrentStage():setFocus(nil)
		end
	end
end

Runtime:addEventListener("mouse", onMouseEvent)

function M.new()
	local categoryBar = display.newRect(0, 0, display.contentWidth, rowHeight)
	categoryBar.anchorX = 0
	categoryBar.anchorY = 0
	categoryBar.x = 0
	categoryBar.y = topPosition
	categoryBar:setFillColor(0.15, 0.15, 0.15)

	function categoryBar:mouse(event)
		local phase = event.type

		if (phase == "move") then
			resizeCursor:hide()
		end
	end

	categoryBar:addEventListener("mouse")

	local listOptions = {
		{
			index = 1,
			left = 0,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Title",
			rowTitle = "title"
		},
		{
			index = 2,
			left = 200,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Artist",
			rowTitle = "artist"
		},
		{
			index = 3,
			left = 400,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Album",
			rowTitle = "album"
		},
		{
			index = 4,
			left = 600,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Genre",
			rowTitle = "genre"
		},
		{
			index = 5,
			left = 750,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Duration",
			rowTitle = "duration"
		}
	}

	for i = 1, #listOptions do
		tableViewList[i] = M:createTableView(listOptions[i])
		categoryList[i] = display.newGroup()
		categoryList[i].x = listOptions[i].left
		categoryList[i].y = topPosition
		categoryList[i].index = i

		local seperatorText =
			display.newText(
			{
				text = "|",
				left = 0,
				y = categoryBar.contentHeight * 0.5,
				font = subTitleFont,
				fontSize = rowFontSize + 8,
				align = "left"
			}
		)
		seperatorText:setFillColor(0.8, 0.8, 0.8)
		categoryList[i]:insert(seperatorText)

		function seperatorText:mouse(event)
			local phase = event.type

			if (categoryList[i].index == 1) then
				return
			end

			if (phase == "move") then
				resizeCursor:show()
			elseif (phase == "down") then
				tableViewTarget = tableViewList[self.parent.index]
				display.getCurrentStage():setFocus(tableViewTarget)
				categoryTarget = categoryList[i]
			elseif (phase == "up") then
				tableViewTarget = nil
				display.getCurrentStage():setFocus(nil)
			end

			return true
		end

		seperatorText:addEventListener("mouse")

		local titleText =
			display.newText(
			{
				text = listOptions[i].categoryTitle,
				y = categoryBar.contentHeight * 0.5,
				font = titleFont,
				fontSize = rowFontSize,
				align = "left"
			}
		)
		titleText.anchorX = 0
		titleText.x = seperatorText.x + seperatorText.contentWidth
		titleText.sortAToZ = i == 1 or false -- TODO: read from database
		titleText:setFillColor(1, 1, 1)
		categoryList[i]:insert(titleText)

		local sortIndicator =
			display.newText(
			{
				text = "⌃",
				y = categoryBar.contentHeight * 0.5,
				font = titleFont,
				fontSize = rowFontSize,
				align = "left"
			}
		)
		sortIndicator.anchorX = 0
		sortIndicator.x = titleText.x + titleText.contentWidth + 2
		sortIndicator.isVisible = i == 1 -- TODO: read from database
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

			if (musicCount <= 0) then
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
				musicSortAToZ = self.sortAToZ

				if (self.text:lower() == "title") then
					musicSort = "title"
				elseif (self.text:lower() == "artist") then
					musicSort = "artist"
				elseif (self.text:lower() == "album") then
					musicSort = "album"
				elseif (self.text:lower() == "genre") then
					musicSort = "genre"
				elseif (self.text:lower() == "duration") then
					musicSort = "duration"
				end

				-- if we are searching, get the data again to re-order it
				if (M.musicSearch) then
					M:getSearchData()
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

function M:hasValidMusicData()
	return musicCount > 0
end

function M:getMusicCount()
	return musicCount
end

function M:setMusicCount(count)
	musicCount = count
end

function M:removeAllRows()
	-- reset the music search function
	self.musicSearch = nil

	for i = 1, #tableViewList do
		tableViewList[i]:deleteAllRows()
	end
end

function M:scrollToTop(rowIndex)
	for i = 1, #tableViewList do
		tableViewList[i]:scrollToTop()
	end
end

function M:scrollToBottom(rowIndex)
	for i = 1, #tableViewList do
		tableViewList[i]:scrollToBottom()
	end
end

function M:reloadData(hardReload)
	currentRowCount = 0

	-- if this isn't a search view reload, reset the music data
	if (not hardReload) then
		musicData = {}
	end

	for i = 1, #tableViewList do
		if (hardReload) then
			if (prevIndex == 0) then
				prevIndex = tableViewList[i]:getRealIndex()
			end

			-- clear the selected row
			tableViewList[i]:setRowSelected(0)
			tableViewList[i]:scrollToTop()
		else
			--print("previous index was: ", prevIndex)
			tableViewList[i]:scrollToIndex(prevIndex)
		end
	end

	if (not hardReload) then
		prevIndex = 0
	end
end

function M:setSelectedRow(rowIndex)
	for i = 1, #tableViewList do
		tableViewList[i]:setRowSelected(rowIndex)
	end
end

function M:populate()
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
