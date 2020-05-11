local M = {}
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local dRemove = display.remove
local tRemove = table.remove
local mMin = math.min
local mMax = math.max
local mModf = math.modf
local selectedRowIndex = 0

function M.new(options)
	local x = options.left or 0
	local y = options.top or 0
	local width = options.width or dWidth
	local height = options.height or error("desktop-table-view() options.height number expect, got ", type(options.height))
	local maxRows = options.maxRows or 22
	local visibleRows = maxRows - 1
	local rowLimit = options.rowLimit or maxRows
	local backgroundColor = options.backgroundColor or {0, 0, 0}
	local rowColorDefault = options.rowColorDefault or {default = {0, 0, 0}, over = {0.2, 0.2, 0.2}}
	local rowColorAlternate = options.rowColorAlternate or nil
	local rowHeight = options.rowHeight or 20
	local onRowRender =
		options.onRowRender or
		error("desktop-table-view() options.onRowRender function expected, got ", type(options.onRowRender))
	local onRowClick = options.onRowClick
	local rows = {}
	local lastMouseScrollWasUp = false
	local didMouseScroll = false
	local lockScrolling = false
	local realRowIndex = 0
	local realHeight = (dHeight - y)
	local realRowVisibleCount, _ = mModf(realHeight / rowHeight)
	local tableView = display.newGroup() --display.newContainer(width, height)
	maxRows = realRowVisibleCount + 1
	visibleRows = maxRows - 1
	tableView.x = x
	tableView.y = y
	local isRowCountEven = maxRows % 2 == 0

	if (not isRowCountEven) then
		maxRows = maxRows + 1
		visibleRows = maxRows - 1
	end

	--print("is row count even ", isRowCountEven)
	--print("we should be able to fit " .. realRowVisibleCount .. " rows on screen")

	local function onRowTap(event)
		local target = event.target
		local numClicks = event.numTaps
		rows[target.realIndex].isSelected = true

		local rowEvent = {
			row = target,
			numClicks = numClicks
		}

		onRowClick(rowEvent)
	end

	function tableView:createRows(params)
		realRowIndex = maxRows

		for i = 1, maxRows do
			rows[i] = display.newGroup()

			rows[i]._background = display.newRect(0, 0, width, rowHeight)
			rows[i]._background.anchorX = 0
			rows[i]._background.x = 0
			rows[i]._background.y = rowHeight * 0.5
			rows[i]._background:setFillColor(unpack(rowColorDefault.default))

			if (rowColorAlternate and i % 2 == 0) then
				rows[i]._background:setFillColor(unpack(rowColorAlternate.default))
			end

			rows[i]._background._isBackground = true
			rows[i]:insert(rows[i]._background)

			rows[i].y = i == 1 and 0 or rows[i - 1].y + rowHeight
			rows[i].index = i
			rows[i].realIndex = i
			rows[i].isSelected = false
			rows[i].contentWidth = width
			rows[i].contentHeight = rowHeight
			rows[i]:addEventListener("tap", onRowTap)

			self:insert(rows[i])
			self:dispatchRowEvent(i)
		end
	end

	function tableView:deleteAllRows()
		if (#rows > 0) then
			for i = 1, maxRows do
				self:deleteRowContents(i)
				display.remove(rows[i])
				rows[i] = nil
			end
		end
	end

	function tableView:deleteRowContents(index)
		for i = 1, rows[index].numChildren do
			if (rows[index][i] and not rows[index][i]._isBackground) then
				display.remove(rows[index][i])
				rows[index][i] = nil
			end
		end
	end

	function tableView:dispatchRowEvent(rowIndex)
		local event = {
			row = rows[rowIndex],
			width = width,
			height = rowHeight,
			parent = self
		}

		onRowRender(event)
	end

	function tableView:getMaxRows()
		return maxRows
	end

	function tableView:getRealIndex()
		return realRowIndex
	end

	function tableView:getVisibleRows()
		return visibleRows
	end

	function tableView:getScrollDirection()
		return lastMouseScrollWasUp and "up" or "down"
	end

	function tableView:isRowOnScreen(index)
		local row = rows[index]
		local onScreen = false

		if (row.y + (rowHeight * 0.5) > 0 and row.y - (rowHeight * 0.5) < (rowHeight * visibleRows)) then
			onScreen = true
		end

		return onScreen
	end

	function tableView:moveRow(index, position)
		rows[index].y = position
	end

	--- When scrolling UP on the scrollwheel
	function tableView:moveAllRowsDown()
		for i = 1, maxRows do
			self:moveRow(i, rows[i].y + rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				self:deleteRowContents(i)
				self:moveRow(i, 0)
				rows[i].index = realRowIndex > visibleRows and realRowIndex - visibleRows or i
				self:dispatchRowEvent(i)
			end
		end
	end

	--- When scrolling DOWN on the scrollwheel
	function tableView:moveAllRowsUp()
		for i = 1, maxRows do
			self:moveRow(i, rows[i].y - rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				self:deleteRowContents(i)
				self:moveRow(i, visibleRows * rowHeight)
				rows[i].index = realRowIndex > visibleRows and realRowIndex or i
				self:dispatchRowEvent(i)
			end
		end
	end

	function tableView:reloadData()
		for i = 1, maxRows do
			self:deleteRowContents(i)
			self:dispatchRowEvent(i)
		end
	end

	function tableView:scrollToIndex(index)
		local newRowIndex = 0

		if (index == 1) then
			newRowIndex = visibleRows
		elseif (index >= rowLimit) then
			newRowIndex = rowLimit - visibleRows
		else
			newRowIndex = index - visibleRows
		end

		for i = 1, maxRows do
			if (index <= maxRows) then
				rows[i].index = i
			elseif (index >= rowLimit) then
				rows[i].index = mMin(rowLimit, (rowLimit - maxRows) + i)
			else
				rows[i].index = mMin(rowLimit, (index - maxRows) + i)
			end

			self:moveRow(i, rowHeight * i - 1 - visibleRows)
			self:deleteRowContents(i)
			self:dispatchRowEvent(i)
		end

		realRowIndex = rows[maxRows].index
	end

	function tableView:scrollToTop()
		self:scrollToIndex(1)
	end

	function tableView:scrollToBottom()
		self:scrollToIndex(rowLimit)
	end

	function tableView:setRowLimit(limit)
		rowLimit = limit + 2
	end

	function tableView:setRowSelected(rowIndex, viaScroll)
		local color = rowIndex % 2 == 0 and rowColorAlternate.over or rowColorDefault.over
		local defaultRowColor = rowColorDefault.default
		local alternateRowColor = rowColorAlternate and rowColorAlternate.default or defaultRowColor

		if (not viaScroll) then
			selectedRowIndex = rowIndex
		end

		if (selectedRowIndex >= 0) then
			for i = 1, maxRows do
				local defaultColor = i % 2 == 0 and alternateRowColor or defaultRowColor

				if (rows[i].index == selectedRowIndex) then
					-- set the selected row to its over color
					rows[i]._background:setFillColor(unpack(color))
				else
					-- reset other rows to their default color
					rows[i]._background:setFillColor(unpack(defaultColor))
				end
			end
		end
	end

	function tableView:enterFrame(event)
		lockScrolling = (rowLimit < visibleRows)

		if (selectedRowIndex > 0) then
			self:setRowSelected(selectedRowIndex, true)
		end

		return true
	end

	Runtime:addEventListener("enterFrame", tableView)

	local function mouseEventListener(event)
		local eventType = event.type
		local scrollY = event.scrollY

		if (eventType == "scroll") then
			-- TODO: get time between scroll events. if they are rapid, scroll faster
			lastMouseScrollWasUp = scrollY < 0
			didMouseScroll = true

			if (not lockScrolling) then
				if (lastMouseScrollWasUp) then
					realRowIndex = realRowIndex - 1

					if (realRowIndex >= maxRows) then
						tableView:moveAllRowsDown()
					else
						realRowIndex = maxRows
					end
				else
					realRowIndex = realRowIndex + 1

					if (realRowIndex <= rowLimit) then
						tableView:moveAllRowsUp()
					else
						realRowIndex = rowLimit
					end
				end
			end
		else
			didMouseScroll = false
		end

		return true
	end

	Runtime:addEventListener("mouse", mouseEventListener)

	return tableView
end

return M
