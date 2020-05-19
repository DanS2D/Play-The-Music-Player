local M = {}
local sqlLib = require("libs.sql-lib")
local desktopTableView = require("libs.ui.desktop-table-view")
local buttonLib = require("libs.ui.button")
local mRound = math.round
local sFormat = string.format
local tInsert = table.insert
local smallButtonFontSize = 16
local mainButtonFontSize = 28
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.otf"

function M.new(options)
	local group = display.newGroup()
	local playListButton = nil
	local playListCaretButton = nil
	local addNewPlaylistButton = nil
	local onClick = options.onClick
	local onPlaylistClick = options.onPlaylistClick
	local tableView = nil
	local parent = options.parent or display.getCurrentStage()
	local isOpen = false

	function group:destroyDropdownMenu()
		if (tableView) then
			tableView:destroy()
			tableView = nil
		end
	end

	function group:createDropdownMenu()
		self:destroyDropdownMenu()

		local playlists = sqlLib:getPlaylists()

		if (#playlists == 0) then
			tInsert(playlists, 1, "No Playlists Created")
		end

		local rowHeight = 40
		local maxRows = mRound(display.contentHeight - self.y) / #playlists
		local totalRowHeight = rowHeight * #playlists
		local width = 500
		local rowColor = {default = {0.15, 0.15, 0.15}, over = {0.20, 0.20, 0.20}}
		local fontSize = (rowHeight / 2.5)

		--print("num of subitems: ", #subItemData)

		if (maxRows > #playlists) then
			maxRows = #playlists
		end

		tableView =
			desktopTableView.new(
			{
				left = display.contentWidth - width - 40,
				top = self.y + 24,
				width = width,
				height = rowHeight * #playlists,
				rowHeight = rowHeight,
				maxRows = maxRows,
				rowLimit = #playlists,
				useSelectedRowHighlighting = false,
				backgroundColor = {0.18, 0.18, 0.18},
				rowColorDefault = rowColor,
				onRowRender = function(event)
					local phase = event.phase
					local row = event.row
					local rowContentWidth = row.contentWidth
					local rowContentHeight = row.contentHeight
					local itemData = playlists[row.index]

					if (row.index > #playlists) then
						return
					end

					local icon =
						display.newText(
						{
							x = 0,
							y = (rowContentHeight * 0.5),
							text = "list-music",
							font = fontAwesomeSolidFont,
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
							text = itemData.name,
							font = titleFont,
							fontSize = fontSize + 2,
							align = "left"
						}
					)
					subItemText.anchorX = 0
					subItemText.x = 35
					row:insert(subItemText)
				end,
				onRowClick = function(event)
					local phase = event.phase
					local row = event.row
					local itemData = playlists[row.index]

					if (row.index > #playlists) then
						return
					end

					if (type(onPlaylistClick) == "function") then
						--event.playlistName = itemData.name
						sqlLib.currentMusicTable = sFormat("%sPlaylist", itemData.name)
						onPlaylistClick(event)
						row.parent.isVisible = false
						isOpen = false
					end

					return true
				end
			}
		)
		tableView:setMaxRows(maxRows)
		tableView:createRows()
		tableView:addEventListener(
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
					local row = tableView:getRowAtIndex(j)
					local rowYStart = row.y
					local rowYEnd = row.y + row.contentHeight

					if (y >= rowYStart and y <= rowYEnd) then
						row._background:setFillColor(unpack(rowColor.over))
					else
						row._background:setFillColor(unpack(rowColor.default))
					end
				end
			end

			return true
		end

		tableView:reloadData()
		tableView:addEventListener("mouse", onMouseEvent)
	end

	local playListButton =
		buttonLib.new(
		{
			iconName = "list-music",
			fontSize = mainButtonFontSize,
			parent = group,
			onClick = function(event)
				isOpen = not isOpen

				if (type(onClick) == "function") then
					onClick(event)
				end

				if (isOpen) then
					group:createDropdownMenu()
				else
					group:destroyDropdownMenu()
				end
			end
		}
	)
	playListButton.x = playListButton.contentWidth + 10
	playListButton.y = 0

	local playListCaretButton =
		buttonLib.new(
		{
			iconName = "caret-down",
			fontSize = smallButtonFontSize,
			parent = group,
			onClick = function(event)
			end
		}
	)
	playListCaretButton.x = playListButton.x + playListButton.contentWidth * 0.5 + playListCaretButton.contentWidth * 0.5
	playListCaretButton.y = playListButton.y + playListCaretButton.contentHeight * 0.5

	local addNewPlaylistButton =
		buttonLib.new(
		{
			iconName = "plus-square",
			fontSize = smallButtonFontSize,
			parent = group,
			onClick = function(event)
				--sqlLib:createPlaylist("dance")
				--sqlLib:updatePlaylistName("dance", "rock")
			end
		}
	)
	addNewPlaylistButton.x = playListButton.x + playListButton.contentWidth * 0.5 + addNewPlaylistButton.contentWidth * 0.7
	addNewPlaylistButton.y = playListButton.y - playListButton.contentHeight * 0.5

	--group.anchorX = 0.5
	--group.anchorY = 0.5
	--group.anchorChildren = false
	group.x = options.x
	group.y = options.y
	parent:insert(group)

	return group
end

return M
