local M = {}
local tfd = require("plugin.tinyFileDialogs")
local sqlLib = require("libs.sql-lib")
local musicBrainz = require("libs.music-brainz")
local buttonLib = require("libs.ui.button")
local alertPopupLib = require("libs.ui.alert-popup")
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local sSub = string.sub
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local maxDisplayWidth = 1024
local maxDisplayHeight = 768
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local created = false

local function onTextFieldInput(event)
	local phase = event.phase
	local target = event.target

	if (phase == "began") then
	elseif (phase == "editing") then
		if (not target.isEditable) then
			target.text = target.origText
			return
		end
	end

	return true
end

local function createTextField(options)
	local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
	local maxHeight = mMin(maxDisplayHeight, display.contentHeight)

	local title =
		display.newText(
		{
			text = options.title,
			font = subTitleFont,
			fontSize = maxHeight * 0.025,
			width = options.titleBounds * 0.15,
			align = "left"
		}
	)
	title.anchorX = options.anchorX or 0
	title.anchorY = options.anchorY or 0
	title.x = options.x
	title.y = options.y
	group:insert(title)

	local textField = native.newTextField(display.contentWidth, -200, options.width - title.contentWidth, options.height)
	textField.anchorX = title.anchorX
	textField.anchorY = title.anchorY
	textField.x = title.x + title.contentWidth + 2
	textField.y = title.y
	textField.placeholder = options.placeholder
	textField.isEditable = options.isEditable
	textField.text = options.text and tostring(options.text):len() > 0 and tostring(options.text) or nil
	textField.origText = textField.text
	textField.align = "left"
	textField:addEventListener("userInput", onTextFieldInput)
	group:insert(textField)

	return {title = title, field = textField}
end

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local separatorLine = nil
	local messageText = nil
	local albumArtworkContainer = nil
	local albumArtwork = nil
	local songFilePathTextField = nil
	local songTitleTextField = nil
	local songAlbumTextField = nil
	local songArtistTextField = nil
	local songGenreTextField = nil
	local songYearTextField = nil
	local songTrackNumberTextField = nil
	local songDurationMinutesTextField = nil
	local songDurationSecondsTextField = nil
	local songCommentTextField = nil
	local onMusicBrainzDownloadComplete = nil
	-- song rating (via the rating lib)
	local cancelButton = nil
	local confirmButton = nil

	function group:cleanup()
		for i = self.numChildren, 1, -1 do
			display.remove(self[i])
			self[i] = nil
		end

		Runtime:removeEventListener("musicBrainz", onMusicBrainzDownloadComplete)
	end

	function group:show(song)
		self:cleanup()

		local textFieldEdgePadding = 20
		local textFieldYPadding = 10
		local textFieldHeight = 30
		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)
		musicBrainz.customEventName = "metadataMusicBrainz"

		interactionDisableRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
		interactionDisableRect.x = display.contentCenterX
		interactionDisableRect.y = display.contentCenterY
		interactionDisableRect.isVisible = false
		interactionDisableRect.isHitTestable = true
		interactionDisableRect:addEventListener(
			"tap",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"touch",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"mouse",
			function()
				return true
			end
		)
		self:insert(interactionDisableRect)

		background = display.newRoundedRect(0, 0, maxWidth * 0.95, maxHeight * 0.85, 2)
		background.x = display.contentCenterX
		background.y = display.contentCenterY
		background.strokeWidth = 1
		background:setFillColor(0.15, 0.15, 0.15)
		background:setStrokeColor(0.6, 0.6, 0.6, 0.5)
		self:insert(background)

		titleText =
			display.newText(
			{
				text = song.title,
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				width = background.width - 20,
				align = "center"
			}
		)
		titleText.x = background.x
		titleText.y = background.y - background.contentHeight * 0.5 + titleText.contentHeight * 0.5 + 10
		titleText:setFillColor(1, 1, 1)
		self:insert(titleText)

		separatorLine = display.newRoundedRect(0, 0, background.contentWidth - 40, 1, 1)
		separatorLine.x = background.x
		separatorLine.y = titleText.y + titleText.contentHeight * 0.5
		separatorLine:setFillColor(0.7, 0.7, 0.7)
		self:insert(separatorLine)

		albumArtworkContainer =
			display.newRoundedRect(0, 0, background.contentWidth * 0.36, background.contentWidth * 0.36, 2)
		albumArtworkContainer.anchorX = 0
		albumArtworkContainer.anchorY = 0
		albumArtworkContainer.x = background.x + 55
		albumArtworkContainer.y = titleText.y + titleText.contentHeight * 0.5 + 20
		albumArtworkContainer.strokeWidth = 1
		albumArtworkContainer:setFillColor(0.15, 0.15, 0.15)
		albumArtworkContainer:setStrokeColor(0.7, 0.7, 0.7)
		self:insert(albumArtworkContainer)

		onMusicBrainzDownloadComplete = function(event)
			local phase = event.phase
			local coverFileName = event.fileName

			if (phase == "downloaded") then
				albumArtwork =
					display.newImageRect(
					coverFileName,
					system.DocumentsDirectory,
					albumArtworkContainer.contentWidth - 1,
					albumArtworkContainer.contentHeight - 1
				)
				albumArtwork.anchorX = 0
				albumArtwork.anchorY = 0
				albumArtwork.x = albumArtworkContainer.x + 1
				albumArtwork.y = albumArtworkContainer.y + 1
				self:insert(albumArtwork)
			end

			return true
		end

		Runtime:addEventListener(musicBrainz.customEventName, onMusicBrainzDownloadComplete)
		musicBrainz.getCover(song)

		--[[
		messageText =
			display.newText(
			{
				text = "Please enter the name for your new playlist.",
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				width = background.width - 20,
				align = "center"
			}
		)
		messageText.x = titleText.x
		messageText.y = titleText.y + titleText.contentHeight * 0.5 + messageText.contentHeight * 0.5
		messageText:setFillColor(1, 1, 1)
		self:insert(messageText)--]]
		local textFieldLeftEdge = background.x - background.contentWidth * 0.5 + textFieldEdgePadding
		local durationMinutes = song.duration:sub(1, 2)
		local durationSeconds = song.duration:sub(4, 5)

		songFilePathTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = titleText.y + titleText.contentHeight * 0.5 + 20,
				width = background.width * 0.40,
				height = textFieldHeight,
				placeholder = "File Path...",
				text = sFormat("%s%s%s", song.filePath, string.pathSeparator, song.fileName),
				isEditable = false,
				align = "left",
				title = "File Path:",
				titleBounds = background.width - 40
			}
		)

		songTitleTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songFilePathTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Title...",
				text = song.title,
				align = "left",
				title = "Title:",
				titleBounds = background.width - 40
			}
		)

		songAlbumTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songTitleTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Album...",
				text = song.album,
				align = "left",
				title = "Album:",
				titleBounds = background.width - 40
			}
		)

		songArtistTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songAlbumTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Artist...",
				text = song.artist,
				align = "left",
				title = "Artist:",
				titleBounds = background.width - 40
			}
		)

		songGenreTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songArtistTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Genre...",
				text = song.genre,
				align = "left",
				title = "Genre:",
				titleBounds = background.width - 40
			}
		)

		songYearTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songGenreTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Year...",
				text = song.year,
				align = "left",
				title = "Year:",
				titleBounds = background.width - 40
			}
		)

		songTrackNumberTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songYearTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Track Number...",
				text = song.trackNumber,
				align = "left",
				title = "Track No:",
				titleBounds = background.width - 40
			}
		)

		songCommentTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songTrackNumberTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Comment...",
				text = song.comment,
				align = "left",
				title = "Comment:",
				titleBounds = background.width - 40
			}
		)

		songDurationMinutesTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songCommentTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.21,
				height = textFieldHeight,
				placeholder = "Mins...",
				text = durationMinutes,
				align = "left",
				title = "Duration:",
				titleBounds = background.width - 40
			}
		)

		songDurationSecondsTextField =
			createTextField(
			{
				x = songDurationMinutesTextField.field.x + songDurationMinutesTextField.field.contentWidth + 10,
				y = songCommentTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.072,
				height = textFieldHeight,
				placeholder = "Secs...",
				text = durationSeconds,
				align = "left",
				title = ":",
				titleBounds = 80
			}
		)

		cancelButton =
			buttonLib.new(
			{
				iconName = "window-close No",
				fontSize = maxHeight * 0.04,
				parent = self,
				onClick = function(event)
					self:hide()
				end
			}
		)
		cancelButton.x = background.x - cancelButton.contentWidth
		cancelButton.y = background.y + background.contentHeight * 0.5 - cancelButton.contentHeight

		confirmButton =
			buttonLib.new(
			{
				iconName = "check-circle Yes",
				fontSize = maxHeight * 0.04,
				parent = self,
				onClick = function(event)
					onConfirm()
				end
			}
		)
		confirmButton.x = background.x + confirmButton.contentWidth
		confirmButton.y = background.y + background.contentHeight * 0.5 - confirmButton.contentHeight

		self.isVisible = true
		self:toFront()
	end

	function group:hide()
		self:cleanup()

		musicBrainz.customEventName = nil
		self.isVisible = false
	end

	created = true
	group:hide()

	function M:isOpen()
		return group.isVisible
	end

	return group
end

return M
