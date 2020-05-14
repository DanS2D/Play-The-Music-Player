local M = {}
local sqlLib = require("libs.sql-lib")
local musicList = require("libs.ui.music-list")
local buttonLib = require("libs.ui.button")
local switchLib = require("libs.ui.switch")
local desktopTableView = require("libs.ui.desktop-table-view")
local mAbs = math.abs
local mMin = math.min
local mMax = math.max
local mModf = math.modf
local mFloor = math.floor
local sFormat = string.format
local tConcat = table.concat
local tSort = table.sort
local tInsert = table.insert
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
	local menuBarColor = options.menuBarColor or {0.18, 0.18, 0.18, 1}
	local menuBarOverColor = options.menuBarOverColor or {0.12, 0.12, 0.12, 1}
	local font = options.font or native.systemFont
	local fontSize = options.fontSize or (menuBarHeight / 2)
	local itemWidth = options.itemWidth or 60
	local itemListWidth = options.itemListWidth or 200
	local items = options.items or error("options.items (table) expected, got %s", type(options.items))
	local rowColor = {default = {0.1, 0.1, 0.1}, over = {0.2, 0.2, 0.2}}
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
			native.setKeyboardFocus(nil)
			return true
		end
	)
	group:insert(background)

	local function closeSubmenus(excludingTarget)
		local target = excludingTarget or {index = 0}

		for j = 1, #menuButtons do
			if (j ~= target.index) then
				menuButtons[j]:setFillColor(unpack(menuButtons[j].origFill.default))
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

		local tempItemText =
			display.newText(
			{
				text = items[i].title,
				font = font,
				fontSize = fontSize + 4,
				height = menuBarHeight,
				align = "left"
			}
		)
		tempItemText.isVisible = false

		local realWidth = tempItemText.contentWidth
		display.remove(tempItemText)
		tempItemText = nil

		local mainButton =
			buttonLib.new(
			{
				iconName = items[i].title,
				font = font,
				fontSize = fontSize + 4,
				onClick = function(event)
					local target = event.target

					if (isDisabled) then
						return
					end

					isItemOpen = not isItemOpen

					if (not isItemOpen) then
						closeSubmenus()
					else
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
		mainButton.origFill = {
			default = {1, 1, 1},
			over = {1, 1, 1, 0.6}
		}

		function mainButton:openSubmenu()
			self.mainTableView.isVisible = true
			self.mainTableView:toFront()
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

		if (sqlLib.musicCount() <= 0 or isDisabled) then
			target.text = ""
			return
		end

		if (phase == "began") then
		elseif (phase == "editing") then
			local currentText = event.text

			if (currentText:len() <= 0) then
				musicList.musicSearch = nil
				musicList:setMusicCount(sqlLib:musicCount())
				musicList:reloadData()
			else
				musicList.musicResultsLimit = sqlLib:musicCount()
				musicList.musicSearch = currentText
				musicList:getSearchData()
				musicList:setMusicCount(sqlLib:searchCount())
				musicList:reloadData(true)
			end
		end

		return true
	end

	searchBar = native.newTextField(0, 0, 200, menuBarHeight - 5)
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
					musicList:setMusicCount(sqlLib:musicCount())
					musicList:reloadData(true)
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
							button:setFillColor(unpack(button.origFill.over))
						else
							closeSubmenus()
							button:setFillColor(unpack(button.origFill.over))
						end
					else
						button:setFillColor(unpack(button.origFill.default))
					end
				else
					if (not isItemOpen) then
						button:setFillColor(unpack(button.origFill.default))
					end
				end

				-- handle subItems (the tableview contents)
				for j = 1, button.mainTableView:getMaxRows() do
					local row = button.mainTableView:getRowAtIndex(j)
					local rowXEnd = itemListWidth
					local rowYStart = rowHeight * j
					local rowYEnd = rowYStart + rowHeight

					if (x >= buttonXStart and x <= buttonXStart + rowXEnd) then
						if (y >= rowYStart and y <= rowYEnd) then
							if (isItemOpen) then
								row._background:setFillColor(unpack(rowColor.over))
							else
								row._background:setFillColor(unpack(rowColor.default))
							end
						else
							row._background:setFillColor(unpack(rowColor.default))
						end
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
