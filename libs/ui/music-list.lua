local sqlLib = require("libs.sql-lib")
local M = {
	--musicFunction = sqlLib.getMusicRowByTitle,
	musicSearch = nil,
	musicResultsLimit = 0,
	rowCreationTimers = {}
}
--local mousecursor = require("plugin.mousecursor")
local audioLib = require("libs.audio-lib")
local desktopTableView = require("libs.ui.desktop-table-view")
local musicImporter = require("libs.music-importer")
local ratings = require("libs.ui.ratings")
local rightClickMenu = require("libs.ui.right-click-menu")
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local tInsert = table.insert
local sFormat = string.format
local tableViewList = {}
local tableViewTarget = nil
local categoryBar = nil
local categoryList = {}
local categoryTarget = nil
local musicCount = 0
local musicSortAToZ = true
local musicSort = "title" -- todo: get saved sort from database
local prevIndex = 0
local rowFontSize = 18
local rowHeight = 40
local defaultRowColor = {default = {0.10, 0.10, 0.10, 1}, over = {0.18, 0.18, 0.18, 1}}
local selectedRowIndex = 0
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"
--local resizeCursor = mousecursor.newCursor("resize left right")
local musicData = {}
local selectedCategoryTableView = nil
local musicListRightClickMenu = nil
local categoryListRightClickMenu = nil
local currentRowCount = 0
local allowCategoryDragLeft = true
local allowCategoryDragRight = true
local draggingCategoryRight = false
local topPosition = 121
local previousIndex = nil
local previousMaxRows = nil
local newMaxRows = nil

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
		elseif (musicSort == "rating") then
			return sqlLib:getMusicRowByRating(rowIndex, musicSortAToZ)
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

function M:createTableView(options, index)
	local tView =
		desktopTableView.new(
		{
			left = categoryList[index].x,
			top = topPosition + rowHeight,
			width = display.contentWidth,
			height = display.contentHeight - 100,
			rowHeight = rowHeight,
			useSelectedRowHighlighting = true,
			backgroundColor = {0.10, 0.10, 0.10, 1},
			rowColorDefault = defaultRowColor,
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

					if (parent.orderIndex == 1) then
						self:getRowData(row.index)
					end
				end

				if (row.index > rowLimit) then
					row.isVisible = false
				else
					row.isVisible = true
				end

				if (options[index].rowTitle == "rating") then
					local ratingStars =
						ratings.new(
						{
							x = 42,
							y = (rowContentHeight * 0.5),
							fontSize = 10,
							isVisible = true,
							rating = musicData and musicData[row.index] and musicData[row.index][options[index].rowTitle] or 0,
							parent = row,
							onClick = function(event)
								--print(event.rating)
								--print(event.mp3Rating)
								-- TODO: update database with new rating (also the mp3 file, if this is an mp3 file)
								event.parent:update(event.rating)
							end
						}
					)
				else
					local rowTitleText =
						display.newText(
						{
							text = musicData and musicData[row.index] and musicData[row.index][options[index].rowTitle] or "",
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
				end

				if (parent.orderIndex >= #options) then
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

				if (numClicks == 1) then
					musicListRightClickMenu:close()
					Runtime:dispatchEvent({name = "menuEvent", close = true})
				elseif (numClicks > 1) then
					local song = self:getRow(row.index)

					if (song == nil) then
						print("SONG IS NIL")
						return
					end

					print("row " .. row.index .. " clicked - playing song " .. song.title)
					--parent:setRowSelected(row.index)
					selectedRowIndex = row.index

					for i = 1, #tableViewList do
						tableViewList[i]:setRowSelected(selectedRowIndex)
					end

					audioLib.currentSongIndex = row.index
					audioLib.load(song)
					audioLib.play(song)
				end
			end,
			onRowMouseClick = function(event)
				local row = event.row

				if (event.isSecondaryButton) then
					categoryListRightClickMenu:close()
					musicListRightClickMenu:open(event.x, event.y)
				end
				--print("row " .. self:getRow(row.index).title .. button .. " button")
			end
		}
	)
	tView.leftPos = options[index].left
	tView.topPos = topPosition + rowHeight
	tView.orderIndex = index

	function tView:populate()
		--print("Creating initial rows")
		musicCount = self.musicSearch ~= nil and sqlLib:searchCount() or sqlLib:musicCount()

		tView:deleteAllRows()
		tView:createRows()
		tView:setRowLimit(musicCount)
	end

	return tView
end

local function createCategories()
	local extraSmallColumnSize = display.contentWidth / 15
	local smallColumnSize = display.contentWidth / 10
	local smallMediumColumnSize = display.contentWidth / 8
	local mediumColumnSize = display.contentWidth / 5
	local largeColumnSize = display.contentWidth / 3
	categoryBar = display.newRect(0, 0, display.contentWidth, rowHeight)
	categoryBar.anchorX = 0
	categoryBar.anchorY = 0
	categoryBar.x = 0
	categoryBar.y = topPosition
	categoryBar:setFillColor(0.15, 0.15, 0.15)

	local listOptions = {
		{
			index = 1,
			left = largeColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Title",
			rowTitle = "title"
		},
		{
			index = 2,
			left = mediumColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Artist",
			rowTitle = "artist"
		},
		{
			index = 3,
			left = mediumColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Album",
			rowTitle = "album"
		},
		{
			index = 4,
			left = smallMediumColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Genre",
			rowTitle = "genre"
		},
		{
			index = 5,
			left = extraSmallColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Rating",
			rowTitle = "rating"
		},
		{
			index = 6,
			left = extraSmallColumnSize,
			width = display.contentWidth,
			showSeperatorLine = true,
			categoryTitle = "Duration",
			rowTitle = "duration"
		}
	}

	for i = 1, #listOptions do
		categoryList[i] = display.newGroup()
		categoryList[i].x = i == 1 and 0 or categoryList[i - 1].x + listOptions[i - 1].left
		categoryList[i].y = topPosition
		categoryList[i].index = i
		tableViewList[i] = M:createTableView(listOptions, i)

		local categoryTouchRect = display.newRect(0, 0, display.contentWidth, rowHeight)
		categoryTouchRect.anchorX = 0
		categoryTouchRect.anchorY = 0
		categoryTouchRect.x = 0
		categoryTouchRect.y = 0
		categoryTouchRect.sortAToZ = i == 1 or false -- TODO: read from database
		categoryTouchRect:setFillColor(0.15, 0.15, 0.15)
		categoryTouchRect:addEventListener(
			"tap",
			function()
				categoryListRightClickMenu:close()
				return true
			end
		)
		categoryList[i]:insert(categoryTouchRect)

		function categoryTouchRect:mouse(event)
			local phase = event.type
			local target = event.target
			local xStart = target.x
			local xEnd = target.x + target.contentWidth
			local yStart = target.y - target.contentHeight * 0.5
			local yEnd = target.y + target.contentHeight * 0.5
			local x, y = event.x, event.y

			if (musicCount <= 0) then
				return
			end

			if (phase == "down") then
				if (event.isPrimaryButtonDown and not categoryListRightClickMenu:isOpen()) then
					Runtime:dispatchEvent({name = "menuEvent", close = true})

					for i = 1, #categoryList do
						categoryList[i].sortIndicator.isVisible = false
					end

					self.sortAToZ = not self.sortAToZ
					self.sortIndicator.isVisible = true
					self.sortIndicator.text = self.sortAToZ and "caret-up" or "caret-down"
					musicSortAToZ = self.sortAToZ

					if (self.text:lower() == "album") then
						musicSort = "album"
					elseif (self.text:lower() == "artist") then
						musicSort = "artist"
					elseif (self.text:lower() == "duration") then
						musicSort = "duration"
					elseif (self.text:lower() == "genre") then
						musicSort = "genre"
					elseif (self.text:lower() == "rating") then
						musicSort = "rating"
					elseif (self.text:lower() == "title") then
						musicSort = "title"
					end

					-- if we are searching, get the data again to re-order it
					if (M.musicSearch) then
						M:getSearchData()
					end

					for i = 1, #tableViewList do
						tableViewList[i]:reloadData()
					end
				end

				if (event.isSecondaryButtonDown) then
					selectedCategoryTableView = tableViewList[self.parent.index]

					musicListRightClickMenu:close()

					if (tableViewList[selectedCategoryTableView.orderIndex].orderIndex == 1) then
						categoryListRightClickMenu:disableOption(1)
						categoryListRightClickMenu:enableOption(2)
					elseif (tableViewList[selectedCategoryTableView.orderIndex].orderIndex == #tableViewList) then
						categoryListRightClickMenu:enableOption(1)
						categoryListRightClickMenu:disableOption(2)
					else
						categoryListRightClickMenu:enableOption(1)
						categoryListRightClickMenu:enableOption(2)
					end

					categoryListRightClickMenu:open(event.x, event.y)
					Runtime:dispatchEvent({name = "menuEvent", close = true})
				end
			elseif (phase == "move") then
			--resizeCursor:hide()
			end

			return true
		end

		categoryTouchRect:addEventListener("mouse")

		local seperatorText =
			display.newText(
			{
				text = "horizontal-rule",
				left = 0,
				y = rowHeight * 0.5 + 2,
				font = fontAwesomeSolidFont,
				fontSize = rowFontSize + 2,
				align = "left"
			}
		)
		seperatorText.rotation = 90
		seperatorText.isVisible = categoryList[i].index ~= 1
		seperatorText:setFillColor(0.8, 0.8, 0.8)
		categoryList[i]:insert(seperatorText)

		function seperatorText:mouse(event)
			local phase = event.type

			if (categoryList[i].index == 1 or sqlLib:musicCount() <= 0) then
				return
			end

			if (phase == "move") then
				--resizeCursor:show()
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
				font = subTitleFont,
				fontSize = rowFontSize,
				align = "left"
			}
		)
		titleText.anchorX = 0
		titleText.x = seperatorText.x + seperatorText.contentWidth * 0.35
		titleText.sortAToZ = i == 1 or false -- TODO: read from database
		categoryTouchRect.text = titleText.text
		categoryList[i].title = titleText
		titleText:setFillColor(1, 1, 1)
		categoryList[i]:insert(titleText)

		local sortIndicator =
			display.newText(
			{
				text = "caret-up",
				y = categoryBar.contentHeight * 0.5,
				font = fontAwesomeSolidFont,
				fontSize = rowFontSize,
				align = "left"
			}
		)
		sortIndicator.anchorX = 0
		sortIndicator.x = titleText.x + titleText.contentWidth + 4
		sortIndicator.isVisible = i == 1 -- TODO: read from database
		titleText.sortIndicator = sortIndicator
		categoryTouchRect.sortIndicator = sortIndicator
		categoryList[i].sortIndicator = sortIndicator
		categoryList[i]:insert(sortIndicator)
	end

	function categoryList:destroy()
		display.remove(categoryBar)
		categoryBar = nil

		for i = 1, #categoryList do
			for j = 1, categoryList[i].numChildren do
				display.remove(categoryList[i][j])
				categoryList[i][j] = nil
			end

			display.remove(categoryList[i])
			categoryList[i] = nil
		end
	end
end

local function moveColumns(event)
	local phase = event.phase

	if (musicCount <= 0) then
		return
	end

	if (tableViewTarget) then
		if (phase == "moved") then
			local oldX = tableViewTarget.x
			draggingCategoryRight = event.x > oldX

			if (allowCategoryDragRight and draggingCategoryRight) then
				local minPosition = display.contentWidth - categoryTarget.title.x - categoryTarget.title.contentWidth - 10

				if (categoryTarget.index < #categoryList) then
					minPosition =
						categoryList[tableViewTarget.orderIndex + 1].x - categoryTarget.title.x - categoryTarget.title.contentWidth - 10
				end

				tableViewTarget.x = mMin(minPosition, mFloor(event.x))
				categoryTarget.x = mMin(minPosition, mFloor(event.x))
				allowCategoryDragLeft = true
			end

			if (allowCategoryDragLeft and not draggingCategoryRight) then
				allowCategoryDragRight = true
				tableViewTarget.x =
					mMax(
					categoryList[tableViewTarget.orderIndex - 1].x + categoryList[tableViewTarget.orderIndex - 1].title.x +
						categoryList[tableViewTarget.orderIndex - 1].title.contentWidth +
						10,
					mFloor(event.x)
				)
				categoryTarget.x =
					mMax(
					categoryList[tableViewTarget.orderIndex - 1].x + categoryList[tableViewTarget.orderIndex - 1].title.x +
						categoryList[tableViewTarget.orderIndex - 1].title.contentWidth +
						10,
					mFloor(event.x)
				)
			end
		end

		if (phase == "ended" or phase == "cancelled") then
			--resizeCursor:hide()
			tableViewTarget = nil
			categoryTarget = nil
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

	--resizeCursor:hide()
end

Runtime:addEventListener("mouse", onMouseEvent)

local function onEnterFrame(event)
	if (#tableViewList > 0) then
		for i = 1, #tableViewList do
			tableViewList[i]:setRowSelected(selectedRowIndex)
		end
	end
end

Runtime:addEventListener("enterFrame", onEnterFrame)

local function handleCategorySwapping(optionName)
	local origIndex = tableViewList[selectedCategoryTableView.orderIndex].orderIndex

	if (optionName == "right") then
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
		categoryList[origIndex]:toFront()

		for i = origIndex + 1, #tableViewList do
			tableViewList[i]:toFront()
			categoryList[i]:toFront()
		end
	elseif (optionName == "left") then
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
		categoryList[origIndex]:toFront()

		for i = origIndex + 1, #tableViewList do
			tableViewList[i]:toFront()
			categoryList[i]:toFront()
		end
	end
end

function M.new()
	createCategories()

	categoryListRightClickMenu =
		rightClickMenu.new(
		{
			items = {
				{
					title = "Move Left",
					icon = "arrow-left",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						handleCategorySwapping("left")
					end
				},
				{
					title = "Move Right",
					icon = "arrow-right",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						handleCategorySwapping("right")
					end
				},
				{
					title = "Hide",
					icon = "eye",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Auto Size All Column",
					icon = "arrows-alt-h",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Close",
					icon = "times-circle",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				}
			}
		}
	)

	musicListRightClickMenu =
		rightClickMenu.new(
		{
			items = {
				{
					title = "Edit Metadata",
					icon = "edit",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Remove From Library",
					icon = "database",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Remove From Library & Disk",
					icon = "trash-alt",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Close",
					icon = "times-circle",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				}
			}
		}
	)

	return tableViewList
end

function M:hasValidMusicData()
	return musicCount > 0
end

function M:getCurrentIndex()
	return tableViewList[1]:getRealIndex()
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

function M:scrollToIndex(rowIndex)
	for i = 1, #tableViewList do
		tableViewList[i]:scrollToIndex(rowIndex)
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
			if (previousIndex ~= nil) then
				if (previousMaxRows == newMaxRows) then
					prevIndex = previousIndex
				elseif (previousMaxRows < newMaxRows) then
					prevIndex = previousIndex + (newMaxRows - previousMaxRows)
				elseif (previousMaxRows > newMaxRows) then
					prevIndex = previousIndex - (previousMaxRows - newMaxRows)
				end

				musicData = {}
				local p = prevIndex
				prevIndex = previousIndex + p
				previousIndex = nil
			end

			print("search: scrolling to index ", prevIndex)

			tableViewList[i]:scrollToIndex(prevIndex)
		end
	end

	if (not hardReload) then
		prevIndex = 0
	end
end

function M:setSelectedRow(rowIndex)
	selectedRowIndex = rowIndex
end

function M:populate()
	--print("POPULATE CALLED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	local startSecond = os.date("*t").sec
	musicImporter.pushProgessToFront()
	musicImporter.showProgressBar()
	musicImporter.updateHeading("Loading music library")
	musicImporter.updateSubHeading("Give me a sec..")

	for i = 1, #tableViewList do
		tableViewList[i]:populate()
		musicImporter.setTotalProgress(i / #tableViewList)
		tableViewList[i]:toFront()

		if (i == #tableViewList) then
			musicImporter.hideProgress()
		end
	end
end

function M:onResize()
	categoryBar.width = display.contentWidth

	if (sqlLib.musicCount() > 0) then
		for i = 1, #tableViewList do
			tableViewList[i]:resizeAllRowBackgrounds(display.contentWidth)
		end
	end
end

function M:recreateMusicList()
	if (musicCount > 0) then
		previousIndex = tableViewList[1]:getRealIndex()
		previousMaxRows = tableViewList[1]:getMaxRows()
		currentRowCount = 0

		print("previous index prior to reload: ", previousIndex)

		if (self.musicSearch == nil) then
			musicData = {}
		end

		categoryList:destroy()

		for i = 1, #tableViewList do
			tableViewList[i]:destroy()
			tableViewList[i] = nil
		end

		tableViewList = nil
		tableViewList = {}
		createCategories()
		self:populate()

		newMaxRows = tableViewList[1]:getMaxRows()

		--print("old max rows: ", previousMaxRows, " new max rows: ", newMaxRows)

		-- scroll to the correct index, factoring in the difference in row count

		if (self.musicSearch == nil) then
			if (previousMaxRows == newMaxRows) then
				self:scrollToIndex(previousIndex)
			elseif (previousMaxRows < newMaxRows) then
				self:scrollToIndex(previousIndex + (newMaxRows - previousMaxRows))
			elseif (previousMaxRows > newMaxRows) then
				self:scrollToIndex(previousIndex - (previousMaxRows - newMaxRows))
			end
		else
			--	self.musicResultsLimit = sqlLib:musicCount()
			--	self:getSearchData()
			--	self:setMusicCount(sqlLib:searchCount())
			--	self:reloadData(true)
		end
	end
end

return M
