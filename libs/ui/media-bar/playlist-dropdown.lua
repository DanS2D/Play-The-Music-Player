local M = {}
local sqlLib = require("libs.sql-lib")
local theme = require("libs.theme")
local settings = require("libs.settings")
local eventDispatcher = require("libs.event-dispatcher")
local desktopTableView = require("libs.ui.desktop-table-view")
local alertPopupLib = require("libs.ui.alert-popup")
local buttonLib = require("libs.ui.button")
local musicList = require("libs.ui.music-list")
local playlistCreatePopupLib = require("libs.ui.media-bar.playlist-create-popup")
local mRound = math.round
local sFormat = string.format
local tInsert = table.insert
local uPack = unpack
local smallButtonFontSize = 16
local mainButtonFontSize = 28
local titleFont = "fonts/Jost-500-Medium.ttf"
local subTitleFont = "fonts/Jost-400-Book.ttf"
local fontAwesomeSolidFont = "fonts/FA5-Solid.ttf"
local alertPopup = alertPopupLib.create()
local playlistCreatePopup = playlistCreatePopupLib.create()

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
	local playListCaret = nil

	function group:destroyDropdownMenu()
		if (tableView) then
			display.remove(tableView.outLineCaret)
			display.remove(tableView.outlineRect)
			tableView.outLineCaret = nil
			tableView.outlineRect = nil
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

		local ingoreTouch = false
		local rowHeight = 40
		local maxRows = mRound(display.contentHeight - self.y) / #playlists
		local totalRowHeight = rowHeight * #playlists
		local width = 500
		local height = rowHeight * #playlists
		local rowColor = {default = theme:get().rowColor.primary, over = theme:get().rowColor.over}
		local fontSize = (rowHeight / 2.5)

		--print("num of subitems: ", #subItemData)

		if (maxRows > #playlists) then
			maxRows = #playlists
		end

		tableView =
			desktopTableView.new(
			{
				left = display.contentWidth - width - 46,
				top = self.y + 24,
				width = width,
				height = height,
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
							text = _G.isLinux and "" or "list-music",
							font = fontAwesomeSolidFont,
							fontSize = fontSize,
							align = "left"
						}
					)
					icon.x = 8 + (icon.contentWidth * 0.5)
					icon:setFillColor(uPack(theme:get().iconColor.primary))
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
					subItemText:setFillColor(uPack(theme:get().textColor.primary))
					row:insert(subItemText)

					local trashIcon =
						buttonLib.new(
						{
							iconName = _G.isLinux and "" or "trash-alt",
							fontSize = fontSize,
							parent = group,
							onClick = function(event)
								local function onRemoved()
									local currentMusicTable = sqlLib.currentMusicTable
									sqlLib:removePlaylist(itemData.name)

									if (sqlLib.currentMusicTable == sFormat("%sPlaylist", itemData.name)) then
										sqlLib.currentMusicTable = "music"
										eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
									end
								end

								ingoreTouch = true
								row.parent.isVisible = false
								isOpen = false

								alertPopup:setTitle(sFormat("Really remove the '%s' playlist?", itemData.name))
								alertPopup:setMessage(
									"This action cannot be reversed.\nThe playlist will be deleted from your library, and you'll have to create it again to get it back.\n\nAre you sure you wish to proceed?"
								)
								alertPopup:setButtonCallbacks({onConfirm = onRemoved})
								alertPopup:show()
							end
						}
					)
					trashIcon.anchorX = 1
					trashIcon.x = rowContentWidth - trashIcon.contentWidth
					trashIcon.y = rowContentHeight * 0.5
					trashIcon:setFillColor(uPack(theme:get().iconColor.primary))
					row:insert(trashIcon)
				end,
				onRowClick = function(event)
					local phase = event.phase
					local row = event.row
					local itemData = playlists[row.index]

					if (row.index > #playlists) then
						return
					end

					if (type(onPlaylistClick) == "function" and not ingoreTouch) then
						if (sqlLib.currentMusicTable ~= sFormat("%sPlaylist", itemData.name)) then
							eventDispatcher:musicListEvent(eventDispatcher.musicList.events.setSelectedRow, 0)
						end

						--event.playlistName = itemData.name
						sqlLib.currentMusicTable = sFormat("%sPlaylist", itemData.name)
						settings.lastView = sqlLib.currentMusicTable
						settings:save()
						musicList.musicSearch = nil
						onPlaylistClick(event)
						row.parent.isVisible = false
						isOpen = false
						self:destroyDropdownMenu()
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

		tableView.outlineRect = display.newRoundedRect(0, 0, width + 2, height + 2, 2)
		tableView.outlineRect.strokeWidth = 1
		tableView.outlineRect:setFillColor(uPack(theme:get().backgroundColor.primary))
		tableView.outlineRect:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		tableView.outlineRect.x = tableView.x + tableView.contentWidth * 0.5 - 1
		tableView.outlineRect.y = tableView.y + tableView.contentHeight * 0.5 - 1

		tableView.outLineCaret =
			display.newText(
			{
				text = _G.isLinux and "" or "caret-up",
				font = fontAwesomeSolidFont,
				fontSize = fontSize,
				align = "center"
			}
		)
		tableView.outLineCaret.x = tableView.outlineRect.x
		tableView.outLineCaret.y = tableView.outlineRect.y - tableView.outlineRect.contentHeight * 0.5 - 1
		tableView.outLineCaret:setFillColor(uPack(theme:get().iconColor.primary))

		tableView:toFront()
	end

	local playListButton =
		buttonLib.new(
		{
			iconName = _G.isLinux and "" or "list-music",
			fontSize = mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local playlists = sqlLib:getPlaylists()

				if (sqlLib:totalMusicCount() <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Music Added!")
					alertPopup:setMessage(
						"You haven't added any music yet!\nYou can't add a playlist until you've added some music to your library."
					)
					alertPopup:show()
					return
				end

				if (#playlists <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Playlists Created!")
					alertPopup:setMessage(
						"You haven't created any playlists yet!\nYou can add a playlist by clicking the + button above the playlist button."
					)
					alertPopup:show()
					return
				end

				isOpen = not isOpen

				if (isOpen) then
					playListCaret:rotate(180)
				else
					playListCaret:rotate(-180)
				end

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

	playListCaret =
		display.newText(
		{
			text = _G.isLinux and "" or "caret-up",
			font = fontAwesomeSolidFont,
			fontSize = smallButtonFontSize
		}
	)
	playListCaret.x = playListButton.x + playListButton.contentWidth * 0.5 + playListCaret.contentWidth * 0.5
	playListCaret.y = playListButton.y + playListCaret.contentHeight * 0.5
	playListCaret:setFillColor(uPack(theme:get().iconColor.primary))
	group:insert(playListCaret)

	local addNewPlaylistButton =
		buttonLib.new(
		{
			iconName = _G.isLinux and "" or "plus-square",
			fontSize = smallButtonFontSize,
			parent = group,
			onClick = function(event)
				if (sqlLib:totalMusicCount() <= 0) then
					alertPopup:onlyUseOkButton()
					alertPopup:setTitle("No Music Added!")
					alertPopup:setMessage(
						"You haven't added any music yet!\nYou can create playlists after you have imported some music to your library."
					)
					alertPopup:show()
					return
				end

				playlistCreatePopup:show()
			end
		}
	)
	addNewPlaylistButton.x = playListButton.x + playListButton.contentWidth * 0.5 + addNewPlaylistButton.contentWidth * 0.7
	addNewPlaylistButton.y = playListButton.y - playListButton.contentHeight * 0.5

	function group:close()
		self:destroyDropdownMenu()
		isOpen = false
	end

	--group.anchorX = 0.5
	--group.anchorY = 0.5
	--group.anchorChildren = false
	group.x = options.x
	group.y = options.y
	parent:insert(group)

	local function playlistDropdownEventHandler(event)
		local phase = event.phase
		local playListEvent = eventDispatcher.playlistDropdown.events

		if (phase == playListEvent.close) then
			group:close()
		end

		return true
	end

	Runtime:addEventListener(eventDispatcher.playlistDropdown.name, playlistDropdownEventHandler)

	return group
end

return M
