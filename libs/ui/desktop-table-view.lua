local M = {}
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local dRemove = display.remove
local tRemove = table.remove
local mMin = math.min
local mMax = math.max

function M.new(options)
	local x = options.left or 0
	local y = options.top or 0
	local width = options.width or dWidth
	local height = options.height or error("desktop-table-view() options.height number expect, got ", type(options.height))
	local maxRows = options.maxRows or 22
	local visbleRows = maxRows - 1
	local rowLimit = options.rowLimit or maxRows
	local backgroundColor = options.backgroundColor or {0, 0, 0}
	local rowColorDefault = options.rowColorDefault or {0, 0, 0}
	local rowColorAlternate = options.rowColorAlternate or nil
	local rowHeight = options.rowHeight or 20
	local onRowRender =
		options.onRowRender or
		error("desktop-table-view() options.onRowRender function expected, got ", type(options.onRowRender))
	local onRowClick = options.onRowClick
	local rows = {}
	local lastMouseScrollWasUp = false
	local didMouseScroll = false
	local realRowIndex = 0
	local tableView = display.newGroup() --display.newContainer(width, height)
	tableView.x = x
	tableView.y = y

	function tableView:createRows(params)
		for i = 1, maxRows do
			realRowIndex = visbleRows

			rows[i] = display.newGroup()

			rows[i]._background = display.newRect(0, 0, width, rowHeight)
			rows[i]._background.anchorX = 0
			rows[i]._background.x = 0
			rows[i]._background.y = rowHeight * 0.5
			rows[i]._background:setFillColor(unpack(rowColorDefault))

			if (rowColorAlternate and i % 2 == 0) then
				rows[i]._background:setFillColor(unpack(rowColorAlternate))
			end

			rows[i]._background._isBackground = true
			rows[i]:insert(rows[i]._background)

			rows[i].y = i == 1 and 0 or rows[i - 1].y + rowHeight
			rows[i].index = i
			rows[i].contentWidth = width
			rows[i].contentHeight = rowHeight

			local function tap(event)
				local target = event.target
				local numClicks = event.numTaps
				local event = {
					row = target,
					numClicks = numClicks
				}

				onRowClick(event)
			end

			rows[i]:addEventListener("tap", tap)

			--print("row " .. i .. "initial y = " .. rows[i].y)

			self:insert(rows[i])
			self:dispatchRowEvent(i)
		end
	end

	function tableView:dispatchRowEvent(rowIndex)
		local event = {
			row = rows[rowIndex],
			width = width,
			height = rowHeight
		}

		onRowRender(event)
	end

	function tableView:deleteRowContents(index)
		for i = 1, rows[index].numChildren do
			if (not rows[index][i]._isBackground) then
				display.remove(rows[index][i])
			end
		end
	end

	function tableView:getRealIndex()
		return realRowIndex
	end

	function tableView:isRowOnScreen(index)
		local row = rows[index]
		local onScreen = false

		if (row.y + (rowHeight * 0.5) > 0 and row.y - (rowHeight * 0.5) < (rowHeight * visbleRows)) then
			onScreen = true
		end

		return onScreen
	end

	function tableView:moveRow(index, position)
		rows[index].y = position
	end

	--- When scrolling UP
	function tableView:moveAllRowsDown()
		if (realRowIndex <= visbleRows) then
			return
		end

		for i = 1, maxRows do
			self:moveRow(i, rows[i].y + rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				self:deleteRowContents(i)
				self:moveRow(i, 0)
				rows[i].index = realRowIndex - visbleRows
				self:dispatchRowEvent(i)
			end
		end
	end

	--- When scrolling DOWN
	function tableView:moveAllRowsUp()
		if (realRowIndex > rowLimit + 1) then
			realRowIndex = rowLimit + 1
			return
		end

		if (realRowIndex < visbleRows) then
			realRowIndex = visbleRows
		end

		for i = 1, maxRows do
			self:moveRow(i, rows[i].y - rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				self:deleteRowContents(i)
				self:moveRow(i, visbleRows * rowHeight)
				rows[i].index = realRowIndex
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
			newRowIndex = visbleRows
		elseif (index >= rowLimit) then
			newRowIndex = rowLimit - visbleRows
		else
			newRowIndex = index - visbleRows
		end

		for i = 1, maxRows do
			if (index <= maxRows) then
				rows[i].index = i
			elseif (index >= rowLimit) then
				rows[i].index = mMin(rowLimit + 1, (rowLimit + 1 - maxRows) + i)
			else
				rows[i].index = mMin(rowLimit, (index - maxRows) + i)
			end

			self:moveRow(i, rowHeight * i - 1 - visbleRows)
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
		rowLimit = limit
	end

	function tableView:enterFrame(event)
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

			if (lastMouseScrollWasUp) then
				realRowIndex = realRowIndex - 1
				tableView:moveAllRowsDown()
			else
				realRowIndex = realRowIndex + 1
				tableView:moveAllRowsUp()
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
