local M = {}
local widget = require("widget")
local sqlLib = require("libs.sql-lib")
local musicList = require("libs.ui.music-list")
local switchLib = require("libs.ui.switch")
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
local defaultButtonPath = "img/buttons/default/"
local overButtonPath = "img/buttons/over/"
local fontAwesomeSolidFont = "fonts/Font-Awesome-5-Free-Solid-900.otf"
local isDisabled = false
local searchBar = nil

function M.new(options)
	local menuBarColor = options.menuBarColor or {0.18, 0.18, 0.18, 1}
	local menuBarOverColor = options.menuBarOverColor or {0.12, 0.12, 0.12, 1}
	local menuBarHeight = options.menuBarHeight or 20
	local font = options.font or native.systemFont
	local itemWidth = options.itemWidth or 60
	local itemListWidth = options.itemListWidth or 200
	local items = options.items or error("options.items (table) expected, got %s", type(options.items))
	local rowColor = {default = {0.1, 0.1, 0.1}, over = {0.2, 0.2, 0.2}}
	local parentGroup = options.parentGroup or display.currentStage
	local group = display.newGroup()
	local isItemOpen = false
	local menuButtons = {}

	local background = display.newRect(0, 0, dWidth, menuBarHeight)
	background.x = display.contentCenterX
	background.y = background.contentHeight * 0.5
	background:setFillColor(unpack(menuBarColor))
	background:addEventListener(
		"touch",
		function()
			native.setKeyboardFocus(nil)
			return true
		end
	)
	group:insert(background)

	local function closeSubmenus(excludingTarget)
		local target = excludingTarget or {index = 0}

		for j = 1, #menuButtons do
			if (j ~= target.index) then
				menuButtons[j]._view:setFillColor(unpack(menuButtons[j].origFill.default))
				menuButtons[j]:closeSubmenu()
			end
		end

		native.setKeyboardFocus(nil)
	end

	function group:close()
		closeSubmenus()
	end

	for i = 1, #items do
		local mainButton =
			widget.newButton(
			{
				left = itemWidth * (i - 1),
				top = 0,
				shape = "rect",
				label = items[i].title,
				labelColor = {
					default = {1, 1, 1},
					over = {1, 1, 1, 1}
				},
				labelAlign = "left",
				font = font,
				fontSize = 12,
				width = itemWidth,
				height = menuBarHeight,
				fillColor = {
					default = menuBarColor,
					over = menuBarOverColor
				},
				onPress = function(event)
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
		mainButton.index = i
		mainButton.origFill = {
			default = menuBarColor,
			over = menuBarOverColor
		}

		function mainButton:openSubmenu()
			mainButton.mainTableView.isVisible = true
			display.getCurrentStage():insert(mainButton.mainTableView)
		end

		function mainButton:closeSubmenu()
			mainButton.mainTableView.isVisible = false
		end

		local height = #items[i].subItems * menuBarHeight

		mainButton.mainTableView =
			widget.newTableView(
			{
				left = itemWidth * (i - 1),
				top = menuBarHeight,
				width = itemListWidth,
				height = height,
				isLocked = true,
				noLines = true,
				rowTouchDelay = 0,
				backgroundColor = {0.18, 0.18, 0.18},
				onRowRender = function(event)
					local phase = event.phase
					local row = event.row
					local rowContentWidth = row.contentWidth
					local rowContentHeight = row.contentHeight
					local params = row.params
					local icon =
						display.newText(
						{
							x = 0,
							y = (rowContentHeight * 0.5),
							text = params.iconName,
							font = fontAwesomeSolidFont,
							fontSize = 10,
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
							fontSize = 10,
							align = "left"
						}
					)
					subItemText.anchorX = 0
					subItemText.x = 30
					row:insert(subItemText)

					if (params.useCheckmark) then
						local switch =
							switchLib.new(
							{
								y = rowContentHeight * 0.5,
								offIconName = "square-full",
								onIconName = "check-square",
								fontSize = 10,
								parent = group,
								onClick = function(event)
									local target = event.target

									if (target.isOffButton) then
									end
								end
							}
						)
						switch.anchorX = 1
						switch.x = rowContentWidth - 8
						row.switch = switch
						row:insert(switch)
					end
				end,
				onRowTouch = function(event)
					local phase = event.phase
					local row = event.row
					local params = row.params

					if (phase == "release") then
						if (isDisabled) then
							return
						end

						if (params.useCheckmark) then
							row.switch:setIsOn(not row.switch:getIsOn())
						else
							isItemOpen = false
							closeSubmenus()
						end

						if (type(params.onClick) == "function") then
							params.onClick()
						end
					end

					return true
				end
			}
		)
		mainButton.mainTableView.isVisible = false
		menuButtons[#menuButtons + 1] = mainButton

		for k = 1, #items[i].subItems do
			mainButton.mainTableView:insertRow {
				isCategory = false,
				rowHeight = menuBarHeight,
				rowColor = rowColor,
				params = {
					title = items[i].subItems[k].title,
					iconName = items[i].subItems[k].iconName,
					useCheckmark = items[i].subItems[k].useCheckmark,
					onClick = items[i].subItems[k].onClick
				}
			}
		end

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

	searchBar = native.newTextField(0, 0, 120, menuBarHeight - 5)
	searchBar.anchorX = 1
	searchBar.x = dWidth - 4
	searchBar.y = menuBarHeight / 2
	searchBar.placeholder = "search..."
	searchBar:addEventListener("userInput", onSearchInput)

	local function onMouseEvent(event)
		local eventType = event.type

		if (isDisabled) then
			return
		end

		if (eventType == "move") then
			for i = 1, #menuButtons do
				local button = menuButtons[i]
				local buttonXStart = button.x - button.contentWidth * 0.5
				local buttonXEnd = button.x + button.contentWidth * 0.5
				local buttonYStart = button.y - button.contentHeight * 0.5
				local buttonYEnd = button.y + button.contentHeight * 0.5
				local x = event.x
				local y = event.y

				-- handle main menu buttons
				if (y >= buttonYStart and y <= buttonYEnd) then
					if (x >= buttonXStart and x <= buttonXEnd) then
						if (isItemOpen) then
							closeSubmenus(button)
							button.openSubmenu()
							button._view:setFillColor(unpack(button.origFill.over))
						else
							closeSubmenus()
							button._view:setFillColor(unpack(button.origFill.over))
							button.mainTableView:reloadData()
						end
					else
						button._view:setFillColor(unpack(button.origFill.default))
					end
				else
					if (not isItemOpen) then
						button._view:setFillColor(unpack(button.origFill.default))
					end
				end

				-- handle subItems (the tableview contents)
				for j = 1, button.mainTableView:getNumRows() do
					local row = button.mainTableView:getRowAtIndex(j)
					local rowXEnd = itemListWidth
					local rowYStart = 20 * j
					local rowYEnd = rowYStart + 20
					local cell = row._cell

					if (x >= buttonXStart and x <= buttonXStart + rowXEnd) then
						if (y >= rowYStart and y <= rowYEnd) then
							if (isItemOpen) then
								cell:setFillColor(unpack(rowColor.over))
							else
								cell:setFillColor(unpack(rowColor.default))
							end
						else
							cell:setFillColor(unpack(rowColor.default))
						end
					end
				end
			end
		end
	end

	Runtime:addEventListener("mouse", onMouseEvent)
	parentGroup:insert(group)

	return group
end

function M.setEnabled(enabled)
	isDisabled = not enabled
end

return M
