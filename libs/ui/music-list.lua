local M = {
	musicSearch = nil,
	rowCreationTimers = {}
}
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local fileUtils = require("libs.file-utils")
local theme = require("libs.theme")
local eventDispatcher = require("libs.event-dispatcher")
local desktopTableView = require("libs.ui.desktop-table-view")
local ratings = require("libs.ui.ratings")
local rightClickMenu = require("libs.ui.right-click-menu")
local alertPopupLib = require("libs.ui.alert-popup")
local playlistCreatePopupLib = require("libs.ui.media-bar.playlist-create-popup")
local editMetadataPopupLib = require("libs.ui.edit-metadata-popup")
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local tInsert = table.insert
local sFormat = string.format
local uPack = unpack
local nSetProperty = native.setProperty
local tableViewList = {}
local tableViewTarget = nil
local categoryBar = nil
local categoryList = {}
local categoryTarget = nil
local musicCount = 0
local musicSortAToZ = true
local musicSort = "title" -- todo: get saved sort from database
local prevIndex = 0
local prevSearchIndex = 1
local rowFontSize = 18
local rowHeight = 40
local selectedRowIndex = 0
local selectedRowRealIndex = 0
local rightClickRowIndex = 0
local titleFont = "fonts/Jost-500-Medium.ttf"
local subTitleFont = "fonts/Jost-400-Book.ttf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.ttf"
local musicData = {}
local selectedCategoryTableView = nil
local musicListRightClickMenu = nil
local categoryListRightClickMenu = nil
local alertPopup = alertPopupLib.create()
local playlistCreatePopup = playlistCreatePopupLib.create()
local editMetadataPopup = editMetadataPopupLib.create()
local currentRowCount = 0
local allowCategoryDragLeft = true
local allowCategoryDragRight = true
local draggingCategoryRight = false
local topPosition = 121
local previousIndex = nil
local previousMaxRows = nil
local newMaxRows = nil

local function lockScrolling(lock)
	for i = 1, #tableViewList do
		tableViewList[i]:lockScroll(lock)
	end
end

local function closeRightClickMenus()
	categoryListRightClickMenu:close()
	musicListRightClickMenu:close()
	lockScrolling(false)
end

local function createCategories()
	local extraSmallColumnSize = display.contentWidth / 15
	local smallColumnSize = display.contentWidth / 10
	local smallMediumColumnSize = display.contentWidth / 8
	local mediumColumnSize = display.contentWidth / 5
	local largeColumnSize = display.contentWidth / 3
	local categoryHeight = (rowHeight - 10)

	categoryBar = display.newRect(0, 0, display.contentWidth, categoryHeight)
	categoryBar.anchorX = 0
	categoryBar.anchorY = 0
	categoryBar.x = 0
	categoryBar.y = topPosition
	categoryBar:setFillColor(uPack(theme:get().backgroundColor.secondary))

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

		local categoryTouchRect = display.newRect(0, 0, display.contentWidth, categoryHeight)
		categoryTouchRect.anchorX = 0
		categoryTouchRect.anchorY = 0
		categoryTouchRect.x = 0
		categoryTouchRect.y = 0
		categoryTouchRect.sortAToZ = i == 1 or false -- TODO: read from database
		categoryTouchRect:setFillColor(uPack(theme:get().backgroundColor.secondary))
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
					eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.close)

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
					eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)
					eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.close)
				end
			elseif (phase == "up") then
				display.getCurrentStage():setFocus(nil)
				lockScrolling(false)
			elseif (phase == "move") then
				nSetProperty("mouseCursor", "arrow")
			end

			return true
		end

		categoryTouchRect:addEventListener("mouse")

		local seperatorText =
			display.newText(
			{
				text = _G.isLinux and "" or "horizontal-rule",
				left = 0,
				y = categoryHeight * 0.5 + 2,
				font = fontAwesomeSolidFont,
				fontSize = rowFontSize + 2,
				align = "left"
			}
		)
		seperatorText.rotation = 90
		seperatorText:setFillColor(uPack(theme:get().textColor.secondary))
		categoryList[i]:insert(seperatorText)

		function seperatorText:mouse(event)
			local phase = event.type

			if (tableViewList[self.parent.index].orderIndex == 1 or sqlLib:currentMusicCount() <= 0) then
				return
			end

			if (phase == "move") then
				nSetProperty("mouseCursor", "resizeLeftRight")
			elseif (phase == "down") then
				lockScrolling(true)
				tableViewTarget = tableViewList[self.parent.index]
				display.getCurrentStage():setFocus(tableViewTarget)
				categoryTarget = categoryList[self.parent.index]
			elseif (phase == "up") then
				tableViewTarget = nil
				display.getCurrentStage():setFocus(nil)
				lockScrolling(false)
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
		titleText:setFillColor(uPack(theme:get().textColor.primary))
		categoryList[i]:insert(titleText)

		local sortIndicator =
			display.newText(
			{
				text = _G.isLinux and "" or "caret-up",
				y = categoryBar.contentHeight * 0.5,
				font = fontAwesomeSolidFont,
				fontSize = rowFontSize,
				align = "left"
			}
		)
		sortIndicator.anchorX = 0
		sortIndicator.x = titleText.x + titleText.contentWidth + 4
		sortIndicator.isVisible = i == 1 -- TODO: read from database
		sortIndicator:setFillColor(uPack(theme:get().iconColor.primary))
		titleText.sortIndicator = sortIndicator
		categoryTouchRect.sortIndicator = sortIndicator
		categoryList[i].sortIndicator = sortIndicator
		categoryList[i]:insert(sortIndicator)
	end

	function categoryList:destroy()
		display.remove(categoryBar)
		categoryBar = nil

		for i = 1, #categoryList do
			for j = categoryList[i].numChildren, 1, -1 do
				display.remove(categoryList[i][j])
				categoryList[i][j] = nil
			end

			display.remove(categoryList[i])
			categoryList[i] = nil
		end
	end
end

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

local function moveColumns(event)
	local phase = event.phase

	if (musicCount <= 0) then
		return
	end

	if (tableViewTarget) then
		if (phase == "moved") then
			local oldX = tableViewTarget.x
			draggingCategoryRight = event.x > oldX

			nSetProperty("mouseCursor", "resizeLeftRight")

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
			nSetProperty("mouseCursor", "arrow")
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
			lockScrolling(false)
		end
	end

	for i = 1, #tableViewList do
		tableViewList[i]:mouse(event)
	end

	nSetProperty("mouseCursor", "arrow")
end

Runtime:addEventListener("mouse", onMouseEvent)

local function refreshPlaylistData()
	local playLists = sqlLib:getPlaylists()
	local playlistData = {
		{
			title = "Create New Playlist",
			icon = _G.isLinux and "" or "list-music",
			iconFont = fontAwesomeSolidFont,
			font = titleFont,
			closeOnClick = true,
			onClick = function(event)
				playlistCreatePopup:show()
			end
		}
	}

	for i = 1, #playLists do
		playlistData[#playlistData + 1] = {
			title = playLists[i].name,
			icon = _G.isLinux and "" or "list-music",
			iconFont = fontAwesomeSolidFont,
			font = titleFont,
			closeOnClick = true,
			onClick = function(event)
				local song = M:getRow(rightClickRowIndex)
				sqlLib:insertMusic(song, sFormat("%sPlaylist", event.playlistName))
			end
		}
	end

	return playlistData
end

function M:createTableView(options, index)
	local tView = nil
	local defaultRowColor = {default = theme:get().rowColor.primary, over = theme:get().rowColor.over}

	tView =
		desktopTableView.new(
		{
			left = categoryList[index].x,
			top = topPosition + rowHeight - 10,
			width = display.contentWidth,
			height = display.contentHeight - 100,
			rowHeight = rowHeight,
			useSelectedRowHighlighting = true,
			rowColorDefault = defaultRowColor,
			onRowRender = function(event)
				local phase = event.phase
				local parent = event.parent
				local row = event.row
				local rowContentWidth = row.contentWidth
				local rowContentHeight = row.contentHeight
				local rowLimit = self.musicSearch ~= nil and sqlLib.searchCount or musicCount
				local nowPlayingIcon = nil
				local songExists = false
				parent:setRowLimit(rowLimit)

				if (parent.orderIndex == 1) then
					self:getRowData(row.index)
				end

				if (row.index > rowLimit) then
					row.isVisible = false
				else
					row.isVisible = true

					if (musicData[row.index]) then
						songExists =
							fileUtils:fileExistsAtRawPath(
							sFormat("%s%s%s", musicData[row.index].filePath, string.pathSeparator, musicData[row.index].fileName)
						)
					end
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
					if (parent.orderIndex == 1) then
						if (songExists and row.index == selectedRowIndex) then
							nowPlayingIcon =
								display.newText(
								{
									text = _G.isLinux and "" or "volume",
									font = fontAwesomeSolidFont,
									x = 0,
									y = (rowContentHeight * 0.5),
									fontSize = rowFontSize,
									align = "left"
								}
							)
							nowPlayingIcon:setFillColor(uPack(theme:get().iconColor.primary))
							nowPlayingIcon.anchorX = 0
							nowPlayingIcon.x = 8
							row:insert(nowPlayingIcon)
						end

						if (not songExists) then
							nowPlayingIcon =
								display.newText(
								{
									text = _G.isLinux and "" or "exclamation-circle",
									font = fontAwesomeSolidFont,
									x = 0,
									y = (rowContentHeight * 0.5),
									fontSize = rowFontSize,
									align = "left"
								}
							)
							nowPlayingIcon:setFillColor(uPack(theme:get().iconColor.primary))
							nowPlayingIcon.anchorX = 0
							nowPlayingIcon.x = 8
							row:insert(nowPlayingIcon)
						end
					end

					local rowTitleText =
						display.newText(
						{
							text = musicData and musicData[row.index] and musicData[row.index][options[index].rowTitle] or "",
							font = titleFont,
							x = 0,
							y = (rowContentHeight * 0.5),
							fontSize = rowFontSize,
							width = rowContentWidth - 10,
							align = "left"
						}
					)
					rowTitleText.anchorX = 0
					rowTitleText.x = 10

					if (nowPlayingIcon) then
						rowTitleText.x = 35
					end

					rowTitleText:setFillColor(uPack(theme:get().textColor.primary))
					row:insert(rowTitleText)
				end

				if (parent.orderIndex >= #options) then
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
			end,
			onRowClick = function(event)
				local phase = event.phase
				local numClicks = event.numClicks
				local row = event.row
				local parent = row.parent

				if (numClicks == 1) then
					closeRightClickMenus()
					eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.closePlaylists)
					eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.close)
				elseif (numClicks >= 2 and row.isVisible) then
					local song = self:getRow(row.index)
					local songExists =
						fileUtils:fileExistsAtRawPath(sFormat("%s%s%s", song.filePath, string.pathSeparator, song.fileName))

					if (not songExists) then
						print("not playing as the file doesn't exist")
						return
					end

					if (song == nil) then
						print("SONG IS NIL")
						return
					end

					audioLib.previousSongIndex = selectedRowIndex
					selectedRowIndex = row.index
					selectedRowRealIndex = tableViewList[1]:getRowRealIndex(audioLib.previousSongIndex)

					if (selectedRowRealIndex > 0) then
						tableViewList[1]:reloadRow(selectedRowRealIndex)
					end

					--print("row " .. row.index .. " clicked - playing song " .. song.title)

					tableViewList[1]:reloadRow(row.realIndex)
					audioLib.currentSongIndex = row.index

					if (song.url) then
						eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.loadingUrl, song)
						timer.performWithDelay(
							50,
							function()
								audioLib.load(song)
								audioLib.play(song)
							end
						)
					else
						audioLib.load(song)
						audioLib.play(song)
					end
				end
			end,
			onRowMouseClick = function(event)
				local row = event.row

				if (row.isVisible) then
					if (event.isSecondaryButton) then
						rightClickRowIndex = row.index

						lockScrolling(true)
						eventDispatcher:playlistDropdownEvent(eventDispatcher.playlistDropdown.events.close)
						categoryListRightClickMenu:close()
						musicListRightClickMenu:open(event.x, event.y)
					end
				end
			end,
			onRowScroll = function(event)
				if (tView.orderIndex == 1) then
					for i = 1, #tableViewList do
						--tableViewList[i]:setRowSelected(selectedRowIndex)
					end
				end
			end
		}
	)
	tView.leftPos = options[index].left
	tView.topPos = topPosition + rowHeight
	tView.orderIndex = index

	function tView:populate()
		--print("Creating initial rows")
		tView:deleteAllRows()
		tView:createRows()
		tView:setRowLimit(musicCount)
	end

	function tView:update()
		if (musicCount <= 550) then
			if (tView.orderIndex == 1) then
			--print("music count <= 550, recreating rows")
			end
			tView:deleteAllRows()
			tView:createRows()
			tView:setRowLimit(musicCount)
		end

		if (tView.orderIndex == 1) then
		--print("updating music list")
		end

		tView:setRowLimit(musicCount)
	end

	return tView
end

function M:destroy()
	currentRowCount = 0
	musicData = {}
	self.musicSearch = nil

	for i = 1, #tableViewList do
		tableViewList[i]:destroy()
		tableViewList[i] = nil
	end

	tableViewList = nil
	tableViewList = {}
end

function M:getRow(rowIndex)
	local row = nil

	if (self.musicSearch) then
		-- get search row
		if (sqlLib.currentMusicTable == "radio") then
			return sqlLib:getRadioRowBySearch(rowIndex, musicSortAToZ, self.musicSearch, 1)
		else
			return sqlLib:getMusicRowBySearch(rowIndex, musicSortAToZ, self.musicSearch, 1)
		end
	else
		if (sqlLib.currentMusicTable == "radio") then
			return sqlLib:getRadioRow(rowIndex, musicSortAToZ)
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
	end

	return nil
end

function M:getRowData(rowIndex)
	--print("getting row data")
	musicData[rowIndex] = self:getRow(rowIndex)
end

function M:getCurrentIndex()
	return tableViewList[1]:getRealIndex()
end

function M:getMusicCount()
	return musicCount
end

function M:hasValidMusicData()
	return musicCount > 0
end

function M:getTableViewListCount()
	return #tableViewList
end

function M.new()
	createCategories()

	categoryListRightClickMenu =
		rightClickMenu.new(
		{
			items = {
				{
					title = "Move Left",
					icon = _G.isLinux and "" or "arrow-left",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						handleCategorySwapping("left")
					end
				},
				{
					title = "Move Right",
					icon = _G.isLinux and "" or "arrow-right",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						handleCategorySwapping("right")
					end
				},
				{
					title = "Hide",
					icon = _G.isLinux and "" or "eye",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Auto Size All Column",
					icon = _G.isLinux and "" or "arrows-alt-h",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
					end
				},
				{
					title = "Close",
					icon = _G.isLinux and "" or "times-circle",
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
					icon = _G.isLinux and "" or "edit",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						local song = M:getRow(rightClickRowIndex)

						editMetadataPopup:show(song)
					end
				},
				{
					title = "Add To Playlist",
					icon = _G.isLinux and "" or "list-music",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					hasSubmenu = true,
					closeOnClick = false,
					onClick = function(event)
					end,
					subItems = refreshPlaylistData
				},
				{
					title = "Remove From Library",
					icon = _G.isLinux and "" or "database",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						local removeFrom = sqlLib.currentMusicTable == "music" and "Library" or "Playlist"
						local messageEnd = sqlLib.currentMusicTable == "music" and "import it again" or "add it again"
						local song = M:getRow(rightClickRowIndex)

						if (sqlLib.currentMusicTable == "radio") then
							removeFrom = "Radio"
							messageEnd = "add it again"
						end

						local function onRemoved()
							if (audioLib.currentSong and audioLib.currentSong.fileName == song.fileName) then
								audioLib.reset()
								eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.clearSong)
							end

							if (sqlLib.currentMusicTable == "radio") then
								sqlLib:removeRadio(song)
							else
								if (removeFrom == "Playlist") then
									sqlLib:removeMusic(song)
								else
									sqlLib:removeMusicFromAll(song)
								end
							end

							M:reloadData()
						end

						alertPopup:setTitle(sFormat("Really remove from %s?", removeFrom))
						alertPopup:setMessage(
							sFormat(
								"This action cannot be reversed.\nThe song will be deleted from your %s, and you'll have to %s to get it back.\n\nAre you sure you wish to proceed?",
								removeFrom,
								messageEnd
							)
						)
						alertPopup:setButtonCallbacks({onConfirm = onRemoved})
						alertPopup:show()
					end
				},
				{
					title = "Remove From Library & Disk",
					icon = _G.isLinux and "" or "trash-alt",
					iconFont = fontAwesomeSolidFont,
					font = titleFont,
					closeOnClick = true,
					onClick = function(event)
						local song = M:getRow(rightClickRowIndex)

						local function onRemoved()
							if (audioLib.currentSong and audioLib.currentSong.fileName == song.fileName) then
								audioLib.reset()
								eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.clearSong)
							end

							sqlLib:removeMusicFromAll(song)
							fileUtils:removeFile(song.fileName, song.filePath)
							M:reloadData()
						end

						alertPopup:setTitle("Really remove from Library and Disk?")
						alertPopup:setMessage(
							"This action cannot be reversed.\nThe song will be removed from your library and the file will be deleted from your hard-drive and will not be sent to the recycle bin.\n\nAre you sure you wish to proceed?"
						)
						alertPopup:setButtonCallbacks({onConfirm = onRemoved})
						alertPopup:show()
					end
				},
				{
					title = "Close",
					icon = _G.isLinux and "" or "times-circle",
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

function M:musicListEvent(event)
	local phase = event.phase
	local musicListEvent = eventDispatcher.musicList.events

	if (phase == musicListEvent.reloadData) then
		self:reloadData()
	elseif (phase == musicListEvent.cleanReloadData) then
		self:reloadDataClean()
	elseif (phase == musicListEvent.closeRightClickMenus) then
		closeRightClickMenus()
	elseif (phase == musicListEvent.unlockScroll) then
		lockScrolling(false)
	elseif (phase == musicListEvent.setSelectedRow) then
		self:setSelectedRow(event.value)
	elseif (phase == musicListEvent.clearMusicSearch) then
		-- TODO: reselect the previously selected row
		self.musicSearch = nil
		prevSearchIndex = 1
		self:reloadData(1)
	elseif (phase == musicListEvent.setMusicCount) then
		musicCount = event.value
	elseif (phase == musicListEvent.setMusicSearch) then
		self.musicSearch = event.value
		self:setSelectedRow(0)
		self:reloadData(1)
	end

	return true
end

Runtime:addEventListener(eventDispatcher.musicList.name, M)

function M:onResize()
	categoryBar.width = display.contentWidth

	if (musicCount > 0) then
		for i = 1, #tableViewList do
			tableViewList[i]:resizeAllRowBackgrounds(display.contentWidth)
		end
	end
end

function M:populate()
	musicCount = self.musicSearch ~= nil and sqlLib.searchCount or sqlLib:currentMusicCount()

	print("populating")
	--print("POPULATE CALLED >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	local startSecond = os.date("*t").sec

	for i = 1, #tableViewList do
		tableViewList[i]:populate()
		tableViewList[i]:toFront()
	end
end

function M:removeAllRows()
	-- reset the music search function
	self.musicSearch = nil

	for i = 1, #tableViewList do
		tableViewList[i]:deleteAllRows()
	end
end

function M:reloadData(index)
	currentRowCount = 0
	musicData = nil
	musicData = {}
	musicCount = self.musicSearch ~= nil and sqlLib.searchCount or sqlLib:currentMusicCount()

	if (prevIndex == 0) then
		prevIndex = tableViewList[1]:getRealIndex()
	end

	if (prevSearchIndex == 1 and self.musicSearch and not index) then
		prevSearchIndex = tableViewList[1]:getRealIndex()
	end

	for i = 1, #tableViewList do
		--tableViewList[i]:setRowSelected(selectedRowIndex)

		if (self.musicSearch) then
			--print("ReloadData() search: scrolling to index:", prevSearchIndex)
			-- clear the selected row
			--tableViewList[i]:setRowSelected(0)
			if (index) then
				tableViewList[i]:scrollToIndex(index)
			else
				tableViewList[i]:scrollToIndex(prevSearchIndex)
			end
		else
			--print("previous index was: ", prevIndex)
			--print("ReloadData() scrolling back to index ", prevIndex)
			tableViewList[i]:scrollToIndex(prevIndex)
		end
	end

	if (self.musicSearch == nil) then
		prevIndex = 0
	else
		prevSearchIndex = 1
	end
end

function M:reloadDataClean()
	previousIndex = nil
	prevIndex = 0
	currentRowCount = 0
	musicData = nil
	musicData = {}
	musicCount = self.musicSearch ~= nil and sqlLib.searchCount or sqlLib:currentMusicCount()

	if (sqlLib.currentMusicTable == "music") then
		musicListRightClickMenu:changeItemTitle(3, "Remove From Library")
	elseif (sqlLib.currentMusicTable == "radio") then
		musicListRightClickMenu:changeItemTitle(3, "Remove From Radio")
	else
		musicListRightClickMenu:changeItemTitle(3, "Remove From Playlist")
	end

	for i = 1, #tableViewList do
		--tableViewList[i]:setRowSelected(0)
		tableViewList[i]:scrollToTop()
	end
end

function M:recreateMusicList()
	if (musicCount > 0) then
		previousIndex = tableViewList[1]:getRealIndex()
		previousMaxRows = tableViewList[1]:getMaxRows()
		currentRowCount = 0
		local newScrollIndex = 0

		--print("previous index prior to reload: ", previousIndex)

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
		local offset = 0

		if (previousMaxRows == newMaxRows) then
			newScrollIndex = 0
			offset = 0
		elseif (previousMaxRows < newMaxRows) then
			offset = (newMaxRows - previousMaxRows)
			newScrollIndex = previousIndex + (newMaxRows - previousMaxRows)
		elseif (previousMaxRows > newMaxRows) then
			offset = (previousMaxRows - newMaxRows)
			newScrollIndex = previousIndex - (previousMaxRows - newMaxRows)
		end

		if (self.musicSearch) then
			prevIndex = prevIndex + offset
		else
			self:scrollToIndex(newScrollIndex)
		end
	end
end

function M:scrollToIndex(rowIndex)
	for i = 1, #tableViewList do
		tableViewList[i]:scrollToIndex(rowIndex)
	end
end

function M:setSelectedRow(rowIndex)
	if (rowIndex == 0 and audioLib.previousSongIndex > 0) then
		local previousRow = tableViewList[1]:getRowRealIndex(audioLib.previousSongIndex)
		selectedRowIndex = 0
		tableViewList[1]:reloadRow(previousRow)
		return
	end

	selectedRowRealIndex = tableViewList[1]:getRowRealIndex(audioLib.previousSongIndex)
	selectedRowIndex = rowIndex

	if (selectedRowRealIndex > 0) then
		tableViewList[1]:reloadRow(selectedRowRealIndex)
	end

	local selectedRowRealIndex = tableViewList[1]:getRowRealIndex(selectedRowIndex)

	if (selectedRowRealIndex > 0) then
		tableViewList[1]:reloadRow(selectedRowRealIndex)
	end
end

function M:update()
	musicCount = sqlLib:totalMusicCount()

	--print("updating tableViews - music count: ", musicCount)

	for i = 1, #tableViewList do
		tableViewList[i]:update()
		tableViewList[i]:toFront()
	end
end

return M
