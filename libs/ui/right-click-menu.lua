local M = {}
local desktopTableView = require("libs.ui.desktop-table-view")

function M.new(options)
	local x = options.left or display.contentWidth
	local y = options.top or display.contentHeight
	local width = options.width or 320
	local rowHeight = options.rowHeight or 35
	local fontSize = options.fontSize or (rowHeight / 2.5)
	local items = options.items
	local rowColor = {default = {0.15, 0.15, 0.15}, over = {0.20, 0.20, 0.20}}

	local menu =
		desktopTableView.new(
		{
			left = x,
			top = y,
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
					if (type(items[row.index].onClick) == "function") then
						items[row.index].onClick(event)

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
					row._background:setFillColor(unpack(rowColor.over))
				else
					row._background:setFillColor(unpack(rowColor.default))
				end
			end
		end

		return (event.isSecondaryButtonDown) -- let right clicks seep through to below objects
	end

	menu:addEventListener("mouse", onMouseEvent)

	function menu:open(x, y)
		if (x + self.contentWidth > display.contentWidth) then
			x = display.contentWidth - self.contentWidth
		end

		if (y + self.contentHeight > display.contentHeight) then
			y = display.contentHeight - self.contentHeight
		end

		self.x = x
		self.y = y
		self:toFront()
		self.isVisible = true
	end

	function menu:close()
		self.x = display.contentWidth
		self.y = display.contentCenterY
		self.isVisible = false
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
