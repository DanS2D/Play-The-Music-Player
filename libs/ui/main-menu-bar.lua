local M = {}
local sqlLib = require("libs.sql-lib")
local theme = require("libs.theme")
local musicList = require("libs.ui.music-list")
local buttonLib = require("libs.ui.button")
local switchLib = require("libs.ui.switch")
local desktopTableView = require("libs.ui.desktop-table-view")
local alertPopupLib = require("libs.ui.alert-popup")
local mAbs = math.abs
local mMin = math.min
local mMax = math.max
local mModf = math.modf
local mFloor = math.floor
local sFormat = string.format
local tConcat = table.concat
local tSort = table.sort
local tInsert = table.insert
local uPack = unpack
local dScreenOriginX = display.screenOriginX
local dScreenOriginY = display.dScreenOriginY
local dCenterX = display.contentCenterX
local dCenterY = display.contentCenterY
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local dSafeScreenOriginX = display.safeScreenOriginX
local dSafeScreenOriginY = display.safeScreenOriginY
local dSafeWidth = display.safeActualContentWidth
local dSafeHeight = display.safeActualContentHeight
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.otf"
local isDisabled = false
local searchBar = nil
local menuBarHeight = 28
local rowHeight = menuBarHeight + 6

function M.new(options)
	local menuBarColor = options.menuBarColor or theme:get().backgroundColor.secondary
	local menuBarOverColor = options.menuBarOverColor or theme:get().backgroundColor.primary
	local font = options.font or native.systemFont
	local fontSize = options.fontSize or (menuBarHeight / 2)
	local itemWidth = options.itemWidth or 60
	local itemListWidth = options.itemListWidth or 250
	local items = options.items or error("options.items (table) expected, got %s", type(options.items))
	local rowColor = {default = theme:get().rowColor.primary, over = theme:get().rowColor.over}
	local parentGroup = options.parentGroup or display.currentStage
	local group = display.newGroup()
	local isItemOpen = false
	local menuButtons = {}

	local background = display.newRect(0, 0, dWidth, menuBarHeight)
	background.anchorX = 0
	background.x = 0
	background.y = background.contentHeight * 0.5
	background:setFillColor(unpack(menuBarColor))
	background:addEventListener(
		"touch",
		function()
			group:close()
			Runtime:dispatchEvent({name = "mediaBar", phase = "closePlaylists"})
			Runtime:dispatchEvent({name = "musicListEvent", phase = "closeRightClickMenus"})
			native.setKeyboardFocus(nil)
			return true
		end
	)
	group:insert(background)

	local function closeSubmenus(excludingTarget)
		local target = excludingTarget or {index = 0}

		for j = 1, #menuButtons do
			if (j ~= target.index) then
				menuButtons[j]:setFillColor(uPack(theme:get().textColor.primary))
				menuButtons[j]:closeSubmenu()
			end
		end

		native.setKeyboardFocus(nil)
	end

	function group:close()
		isItemOpen = false
		closeSubmenus()
	end

	for i = 1, #items do
		local tableViewParams = {}

		local mainButton =
			buttonLib.new(
			{
				iconName = items[i].title,
				font = font,
				fontSize = fontSize + 4,
				fillColor = theme:get().textColor.primary,
				onClick = function(event)
					local target = event.target

					if (isDisabled) then
						return
					end

					isItemOpen = not isItemOpen

					if (not isItemOpen) then
						closeSubmenus()
					else
						target:setFillColor(uPack(theme:get().textColor.secondary))
						target:openSubmenu()
						closeSubmenus(target)
					end
				end
			}
		)
		mainButton.anchorX = 0
		mainButton.x = i == 1 and 10 or menuButtons[i - 1].x + menuButtons[i - 1].contentWidth + 10
		mainButton.y = menuBarHeight * 0.5
		mainButton.index = i

		function mainButton:openSubmenu()
			self.mainTableView.isVisible = true
			self.mainTableView:toFront()
			Runtime:dispatchEvent({name = "mediaBar", phase = "closePlaylists"})
			Runtime:dispatchEvent({name = "musicListEvent", phase = "closeRightClickMenus"})
			display.getCurrentStage():insert(self.mainTableView)
		end

		function mainButton:closeSubmenu()
			self.mainTableView.isVisible = false
		end

		local height = #items[i].subItems * menuBarHeight
		menuButtons[i] = mainButton

		mainButton.mainTableView =
			desktopTableView.new(
			{
				left = i == 1 and 0 or menuButtons[i].x,
				top = menuBarHeight,
				width = itemListWidth,
				height = height,
				rowHeight = rowHeight,
				rowLimit = 0,
				useSelectedRowHighlighting = false,
				backgroundColor = {0.18, 0.18, 0.18},
				onRowRender = function(event)
					local phase = event.phase
					local row = event.row
					local rowContentWidth = row.contentWidth
					local rowContentHeight = row.contentHeight
					local params = tableViewParams[row.index]
					local icon =
						display.newText(
						{
							x = 0,
							y = (rowContentHeight * 0.5),
							text = params.iconName,
							font = params.font,
							fontSize = fontSize,
							align = "left"
						}
					)
					icon.x = 8 + (icon.contentWidth * 0.5)
					row:insert(icon)

					local subItemText =
						display.newText(
						{
							x = 0,
							y = (rowContentHeight * 0.5),
							text = params.title,
							font = font,
							fontSize = fontSize + 2,
							align = "left"
						}
					)
					subItemText.anchorX = 0
					subItemText.x = 30
					row:insert(subItemText)

					if (params.useCheckmark) then
						-- have to convert to boolean
						local isOn = toboolean(params.checkMarkIsOn)

						local switch =
							switchLib.new(
							{
								y = rowContentHeight * 0.5,
								offIconName = "square-full",
								onIconName = "check-square",
								fontSize = fontSize,
								parent = group,
								onClick = function(event)
								end
							}
						)
						switch.anchorX = 1
						switch.x = rowContentWidth - 8
						row.switch = switch

						switch:setIsOn(isOn)
						row:insert(switch)

						local switchUnderlay =
							display.newRect(rowContentWidth * 0.5, rowContentHeight * 0.5, rowContentWidth, rowContentHeight)
						switchUnderlay.fill = {0, 0, 0, 0.01}
						switchUnderlay:addEventListener(
							"touch",
							function(event)
								local phase = event.phase

								if (phase == "began") then
									switch:setIsOn(not switch:getIsOn())

									if (type(params.onClick) == "function") then
										event.isSwitch = true
										event.isOn = switch:getIsOn()
										params.onClick(event)
									end
								end

								return true
							end
						)

						row:insert(switchUnderlay)
					end
				end,
				onRowClick = function(event)
					local phase = event.phase
					local row = event.row
					local params = tableViewParams[row.index]

					if (isDisabled) then
						return
					end

					if (not params.useCheckmark) then
						isItemOpen = false
						closeSubmenus()
					end

					if (type(params.onClick) == "function") then
						params.onClick(event)
					end

					return true
				end
			}
		)
		mainButton.mainTableView:addEventListener(
			"tap",
			function()
				return true
			end
		)
		mainButton.mainTableView:addEventListener(
			"mouse",
			function(event)
				local eventType = event.type

				if (eventType == "move") then
					local x, y = event.target:contentToLocal(event.x, event.y)

					-- handle subItems (the tableview contents)
					for i = 1, event.target:getMaxRows() do
						local row = event.target:getRowAtIndex(i)
						local rowYStart = rowHeight * (i - 1)
						local rowYEnd = rowHeight * i

						if (y >= rowYStart and y <= rowYEnd) then
							row._background:setFillColor(unpack(rowColor.over))
						else
							row._background:setFillColor(unpack(rowColor.default))
						end
					end
				end

				return true
			end
		)
		mainButton.mainTableView.isVisible = false
		menuButtons[i] = mainButton

		for k = 1, #items[i].subItems do
			tableViewParams[#tableViewParams + 1] = {
				title = items[i].subItems[k].title,
				iconName = items[i].subItems[k].iconName,
				useCheckmark = items[i].subItems[k].useCheckmark,
				checkMarkIsOn = items[i].subItems[k].checkMarkIsOn,
				font = items[i].subItems[k].font or fontAwesomeSolidFont,
				onClick = items[i].subItems[k].onClick
			}
		end

		mainButton.mainTableView:setMaxRows(#tableViewParams)
		mainButton.mainTableView:createRows()

		group:insert(mainButton)
		group:insert(mainButton.mainTableView)
	end

	local function onSearchInput(event)
		local phase = event.phase
		local target = event.target

		if (alertPopupLib:isOpen()) then
			target.text = ""
			native.setKeyboardFocus(nil)
			return
		end

		if (sqlLib:currentMusicCount() <= 0 or isDisabled) then
			target.text = ""
			return
		end

		if (phase == "began") then
			musicList:closeRightClickMenus()
			Runtime:dispatchEvent({name = "mediaBar", phase = "closePlaylists"})
		elseif (phase == "editing") then
			local currentText = event.text

			if (currentText:len() <= 0) then
				musicList.musicSearch = nil
				musicList:setMusicCount(sqlLib:currentMusicCount())
				musicList:reloadData()
			else
				musicList.musicResultsLimit = sqlLib:currentMusicCount()
				musicList.musicSearch = currentText:stripAccents()
				musicList:getSearchData()
				musicList:setMusicCount(sqlLib:searchCount())
				musicList:reloadData()
			end
		end

		return true
	end

	searchBar = native.newTextField(display.contentWidth, -200, 200, menuBarHeight - 5)
	searchBar.anchorX = 1
	searchBar.x = display.contentWidth - 10
	searchBar.y = menuBarHeight / 2
	searchBar.placeholder = "search..."
	searchBar:addEventListener("userInput", onSearchInput)

	local clearSearchButton =
		buttonLib.new(
		{
			iconName = "search-minus",
			fontSize = 18,
			parent = group,
			onClick = function(event)
				group:close()

				if (searchBar.text:len() > 0) then
					searchBar.text = ""
					musicList.musicSearch = nil
					musicList:setMusicCount(sqlLib:currentMusicCount())
					musicList:reloadData()
				end
			end
		}
	)
	clearSearchButton.anchorX = 1
	clearSearchButton.x = searchBar.x - searchBar.contentWidth - (clearSearchButton.contentWidth * 0.5)
	clearSearchButton.y = (menuBarHeight / 2)

	local function onMouseEvent(event)
		local eventType = event.type

		if (isDisabled) then
			return
		end

		if (eventType == "move") then
			for i = 1, #menuButtons do
				local button = menuButtons[i]
				local buttonXStart = button.x
				local buttonXEnd = button.x + button.contentWidth
				local buttonYStart = 0
				local buttonYEnd = button.y + button.contentHeight * 0.5
				local x = event.x
				local y = event.y

				-- handle main menu buttons
				if (y >= buttonYStart and y <= buttonYEnd) then
					if (x >= buttonXStart and x <= buttonXEnd) then
						if (isItemOpen) then
							closeSubmenus(button)
							button:openSubmenu()
							button:setFillColor(uPack(theme:get().textColor.secondary))
						else
							closeSubmenus()
							button:setFillColor(uPack(theme:get().textColor.secondary))
						end
					else
						button:setFillColor(uPack(theme:get().textColor.primary))
					end
				else
					if (not isItemOpen) then
						button:setFillColor(uPack(theme:get().textColor.primary))
					end
				end
			end
		end
	end

	Runtime:addEventListener("mouse", onMouseEvent)

	local function closeListener(event)
		if (event.close) then
			isItemOpen = false
			closeSubmenus()
		end
	end

	Runtime:addEventListener("menuEvent", closeListener)

	function group:onResize()
		searchBar.x = display.contentWidth - 10
		clearSearchButton.x = searchBar.x - searchBar.contentWidth - (clearSearchButton.contentWidth * 0.5)
		background.width = display.contentWidth
	end

	parentGroup:insert(group)

	return group
end

function M.setEnabled(enabled)
	isDisabled = not enabled
end

function M.getHeight()
	return menuBarHeight
end

return M
