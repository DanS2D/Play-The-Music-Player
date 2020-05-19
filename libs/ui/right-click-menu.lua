local M = {}
local desktopTableView = require("libs.ui.desktop-table-view")
local mRound = math.round

function M.new(options)
	local x = options.left or display.contentWidth
	local y = options.top or display.contentHeight
	local width = options.width or 320
	local rowHeight = options.rowHeight or 35
	local fontSize = options.fontSize or (rowHeight / 2.5)
	local items = options.items or error("rightClickMenu() options.items (table) expected got, %s", type(options.items))
	local rowColor = {default = {0.15, 0.15, 0.15}, over = {0.20, 0.20, 0.20}}
	local subItems = {}
	local subMenuXPosition = 0

	local menu =
		desktopTableView.new(
		{
			left = 0,
			top = 0,
			width = width,
			height = rowHeight * #items,
			rowHeight = rowHeight,
			rowLimit = #items,
			useSelectedRowHighlighting = false,
			backgroundColor = {0.18, 0.18, 0.18},
			rowColorDefault = rowColor,
			onRowRender = function(event)
				local phase = event.phase
				local row = event.row
				local rowContentWidth = row.contentWidth
				local rowContentHeight = row.contentHeight
				local icon =
					display.newText(
					{
						x = 0,
						y = (rowContentHeight * 0.5),
						text = items[row.index].icon,
						font = items[row.index].iconFont,
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
						text = items[row.index].title,
						font = items[row.index].font,
						fontSize = fontSize + 2,
						align = "left"
					}
				)
				subItemText.anchorX = 0
				subItemText.x = 35
				row:insert(subItemText)

				if (items[row.index].hasSubmenu) then
					local subMenuIcon =
						display.newText(
						{
							x = 0,
							y = (rowContentHeight * 0.5),
							text = "caret-right",
							font = items[row.index].iconFont,
							fontSize = fontSize,
							align = "left"
						}
					)
					subMenuIcon.anchorX = 1
					subMenuIcon.x = rowContentWidth - subMenuIcon.contentWidth
					row:insert(subMenuIcon)
				end

				if (items[row.index].disabled) then
					icon.alpha = 0.5
					subItemText.alpha = 0.5
				end
			end,
			onRowClick = function(event)
				local phase = event.phase
				local row = event.row
				local onClick = items[row.index].onClick

				if (not items[row.index].disabled) then
					if (type(onClick) == "function") then
						onClick(event)

						if (items[row.index].closeOnClick) then
							row.parent:close()
						end
					end
				end

				return true
			end
		}
	)
	menu.isVisible = false
	menu:setMaxRows(#items)
	menu:createRows()
	menu:addEventListener(
		"tap",
		function()
			return true
		end
	)

	function menu:destroySubmenus()
		if (#subItems > 0) then
			for i = 1, #subItems do
				subItems[i]:destroy()
				subItems[i] = nil
			end

			subItems = nil
			subItems = {}
		end
	end

	function menu:createSubmenus()
		for i = 1, #items do
			if (type(items[i].subItems) == "function") then
				local subItemData = items[i].subItems()
				local maxRows = mRound((display.contentHeight - (self.y + (rowHeight * (i - 1)))) / rowHeight) - 1

				--print("num of subitems: ", #subItemData)

				if (maxRows > #subItemData) then
					maxRows = #subItemData
				end

				subItems[#subItems + 1] =
					desktopTableView.new(
					{
						left = subMenuXPosition,
						top = self.y + (rowHeight * (i - 1)),
						width = width,
						height = rowHeight * #subItemData,
						rowHeight = rowHeight,
						maxRows = maxRows,
						rowLimit = #subItemData,
						useSelectedRowHighlighting = false,
						backgroundColor = {0.18, 0.18, 0.18},
						rowColorDefault = rowColor,
						onRowRender = function(event)
							local phase = event.phase
							local row = event.row
							local rowContentWidth = row.contentWidth
							local rowContentHeight = row.contentHeight
							local itemData = subItemData[row.index]

							if (row.index > #subItemData) then
								return
							end

							local icon =
								display.newText(
								{
									x = 0,
									y = (rowContentHeight * 0.5),
									text = itemData.icon,
									font = itemData.iconFont,
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
									text = itemData.title,
									font = itemData.font,
									fontSize = fontSize + 2,
									align = "left"
								}
							)
							subItemText.anchorX = 0
							subItemText.x = 35
							row:insert(subItemText)

							if (itemData.disabled) then
								icon.alpha = 0.5
								subItemText.alpha = 0.5
							end
						end,
						onRowClick = function(event)
							local phase = event.phase
							local row = event.row
							local itemData = subItemData[row.index]
							local onClick = itemData.onClick

							if (row.index > #subItemData) then
								return
							end

							if (not itemData.disabled) then
								if (type(onClick) == "function") then
									event.playlistName = itemData.title
									onClick(event)

									if (itemData.closeOnClick) then
										menu:close()
									end
								end
							end

							return true
						end
					}
				)
				subItems[#subItems].index = i
				subItems[#subItems].id = #subItems
				subItems[#subItems].isVisible = false
				subItems[#subItems]:setMaxRows(maxRows)
				subItems[#subItems]:createRows()
				subItems[#subItems]:lockScroll(true)
				subItems[#subItems]:addEventListener(
					"tap",
					function()
						return true
					end
				)

				local function onMouseEvent(event)
					local eventType = event.type

					if (eventType == "move") then
						local x, y = event.target:contentToLocal(event.x, event.y)
						local subItemIndex = event.target.id

						-- handle subItems (the tableview contents)
						for j = 1, maxRows do
							local row = subItems[subItemIndex]:getRowAtIndex(j)
							local rowYStart = row.y
							local rowYEnd = row.y + row.contentHeight

							if (y >= rowYStart and y <= rowYEnd) then
								row._background:setFillColor(unpack(rowColor.over))
							else
								row._background:setFillColor(unpack(rowColor.default))
							end
						end
					end

					return (event.isSecondaryButtonDown) -- let right clicks seep through to below objects
				end

				subItems[#subItems].isValid = #subItemData > 0
				subItems[#subItems]:reloadData()
				subItems[#subItems]:addEventListener("mouse", onMouseEvent)
			end
		end
	end

	local function onMouseEvent(event)
		local eventType = event.type

		if (eventType == "move") then
			local x, y = event.target:contentToLocal(event.x, event.y)

			-- handle subItems (the tableview contents)
			for i = 1, menu:getMaxRows() do
				local row = menu:getRowAtIndex(i)
				local rowYStart = rowHeight * (i - 1)
				local rowYEnd = rowHeight * i

				if (y >= rowYStart and y <= rowYEnd) then
					if (#subItems > 0) then
						for j = 1, #subItems do
							if (subItems[j].index == i and subItems[j].isVisible == false) then
								subItems[j]:lockScroll(false)
								subItems[j].isVisible = true
							end
						end
					end

					row._background:setFillColor(unpack(rowColor.over))
				else
					if (#subItems > 0) then
						for j = 1, #subItems do
							if (subItems[j].index == i and subItems[j].isVisible == true) then
								subItems[j]:lockScroll(true)
								subItems[j].isVisible = false
							end
						end
					end

					row._background:setFillColor(unpack(rowColor.default))
				end
			end
		end

		return (event.isSecondaryButtonDown) -- let right clicks seep through to below objects
	end

	menu:addEventListener("mouse", onMouseEvent)

	function menu:changeItemTitle(index, newTitle)
		items[index].title = newTitle
	end

	function menu:open(x, y)
		subMenuXPosition = x + menu.contentWidth

		if (x + self.contentWidth > display.contentWidth) then
			x = display.contentWidth - self.contentWidth
			subMenuXPosition = x - menu.contentWidth
		end

		if (y + self.contentHeight > display.contentHeight) then
			y = display.contentHeight - self.contentHeight
		end

		self.x = x
		self.y = y
		self:reloadData()
		self:toFront()
		self:destroySubmenus()
		self:createSubmenus()

		for i = 1, #subItems do
			subItems[i]:toFront()
		end

		self.isVisible = true
	end

	function menu:close()
		self.x = display.contentWidth
		self.y = display.contentCenterY
		self.isVisible = false
		self:destroySubmenus()
	end

	function menu:isOpen()
		return self.isVisible
	end

	function menu:disableOption(index)
		items[index].disabled = true
		menu:reloadData()
	end

	function menu:enableOption(index)
		items[index].disabled = false
		menu:reloadData()
	end

	return menu
end

return M
