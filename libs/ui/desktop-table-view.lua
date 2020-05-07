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
	local maxRows = options.maxRows or 20
	local backgroundColor = options.backgroundColor or {0, 0, 0}
	local rowColorDefault = options.rowColor or {0, 0, 0}
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
	local renderRowsAgain = false
	local tableView = display.newGroup()
	tableView.scrollView = display.newGroup()
	tableView:insert(tableView.scrollView)
	tableView.x = x
	tableView.y = y

	--[[ the idea here is that we don't delete rows, we just move them around.
			for example. If you scroll down, it will move rows[1] to row [10] down to row[40]s position.
			or something. The idea is to have continuous vertical scrolling from a visual perspective,
			but in reality, there are only ever MAX_ROWS created.
	--]]
	function tableView:createRows(params)
		for i = 1, maxRows do
			realRowIndex = 19

			rows[i] = display.newGroup()
			rows[i].y = i == 1 and 0 or rows[i - 1].y + rows[i - 1].contentHeight
			rows[i].index = i
			rows[i].contentWidth = width
			rows[i].contentHeight = rowHeight

			local function tap(event)
				local target = event.target
				local numTaps = event.numTaps
				local event = {
					index = target.index,
					row = target,
					numTaps = numTaps
				}

				onRowClick(event)
			end

			rows[i]:addEventListener("tap", tap)

			--print("row " .. i .. "initial y = " .. rows[i].y)

			self.scrollView:insert(rows[i])
			self:dispatchRowEvent(i, i)
		end
	end

	function tableView:dispatchRowEvent(rowIndex, realIndex)
		local event = {
			index = realIndex,
			row = rows[rowIndex],
			width = width,
			height = rowHeight
		}

		onRowRender(event)
	end

	function tableView:deleteRowContents(index)
		for i = 1, rows[index].numChildren do
			display.remove(rows[index][i])
		end
	end

	--[[
	function tableView:deleteRow(index)
		if (rows[index]) then
			for i = 1, rows[index].numChildren do
				display.remove(rows[index][i])
			end

			self.scrollView:remove(rows[index])
			dRemove(rows[index])
			tRemove(rows, index)
		end
	end

	function tableView:deleteAllRows()
		for j = 1, #rows do
			if (rows[j]) then
				for i = 1, rows[j].numChildren do
					self.scrollView:remove(rows[j][i])
					display.remove(rows[j][i])
				end

				dRemove(rows[j])
				tRemove(rows, j)
			end
		end
	end

	function tableView:insertRow(index)
		rows[index] = display.newGroup()

		local event = {
			index = index * realRowIndex,
			row = rows[index],
			width = width,
			height = rowHeight
		}

		self.scrollView:insert(rows[index])
		onRowRender(event)
	end--]]
	function tableView:isRowOnScreen(index)
		local row = rows[index]
		local onScreen = false

		if (row.y + (rowHeight * 0.5) > 0 and row.y - (rowHeight * 0.5) < (rowHeight * 19)) then
			onScreen = true
		end

		return onScreen
	end

	function tableView:moveRow(index, position)
		rows[index].y = position
	end

	--- When scrolling UP
	function tableView:moveAllRowsDown()
		if (realRowIndex <= maxRows - 1) then
			for i = 1, maxRows do
				--self:dispatchRowEvent(i, i)
			end
			return
		end

		for i = 1, maxRows do
			self:moveRow(i, rows[i].y + rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				--print("moving row " .. i .. " down to the bottom")
				self:deleteRowContents(i)
				self:moveRow(i, 0)
				rows[i].index = realRowIndex - 19
				--print("moving row " .. i .. " to position " .. -rowHeight)
				--print("row " .. i .. " is now at position ", rows[i].y)
				--print("real row index " .. realRowIndex + 1)
				self:dispatchRowEvent(i, realRowIndex - 19)
			end
		end
	end

	--- When scrolling DOWN
	function tableView:moveAllRowsUp()
		if (realRowIndex < 19) then
			realRowIndex = 20
		end

		for i = 1, maxRows do
			self:moveRow(i, rows[i].y - rowHeight)
		end

		for i = 1, maxRows do
			if (not self:isRowOnScreen(i)) then
				--print("moving row " .. i .. " down to the bottom")
				self:deleteRowContents(i)
				self:moveRow(i, 19 * rowHeight)
				rows[i].index = realRowIndex + 1
				--print("moving row " .. i .. " to position " .. 19 * rowHeight)
				--print("row " .. i .. " is now at position ", rows[i].y)
				--print("real row index " .. realRowIndex + 1)
				self:dispatchRowEvent(i, realRowIndex + 1)
			end
		end
	end

	function tableView:reloadData()
		for i = 1, maxRows do
			self:dispatchRowEvent(i, i)
		end
	end

	function tableView:scrollToTop()
		self.scrollView.y = 0
	end

	function tableView:scrollToBottom()
		self.scrollView.y = self.scrollView.contentHeight
	end

	function tableView:enterFrame(event)
		if (didMouseScroll) then
			if (lastMouseScrollWasUp) then
				-- insert row above, remove row below
				--self:insertRow(1)
				--self:deleteRow(maxRows)
				-- move rows down
			else
				-- insert row below, remove row above
				--self:insertRow(maxRows)
				--self:deleteRow(1)
				-- move rows up
				if (renderRowsAgain) then
					--[[
					for i = 1, maxRows do
						if (self:isRowOnScreen(i)) then
							self:deleteRowContents(i)

							--self:moveRow(i, rows[maxRows].y)
							local event = {
								index = realRowIndex,
								row = rows[i],
								width = width,
								height = rowHeight
							}

							onRowRender(event)
						else
							self:deleteRowContents(i)
						end
					end--]]
					renderRowsAgain = false
				end
			end
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

			if (lastMouseScrollWasUp) then
				realRowIndex = realRowIndex - 1
				--mMax(maxRows - 1, realRowIndex - 1)
				renderRowsAgain = true
				--tableView.scrollView.y = mMin(0, tableView.scrollView.y - 20)
				tableView:moveAllRowsDown()
			else
				--tableView.scrollView.y = mMax(tableView.scrollView.contentHeight, tableView.scrollView.y + 20)
				realRowIndex = realRowIndex + 1 -- todo: should be able to assign the max row index (i.e. total amount of REAL rows) via a function call
				renderRowsAgain = true
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
