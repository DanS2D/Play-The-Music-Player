local M = {}
local tfd = require("plugin.tinyFileDialogs")
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local fileUtils = require("libs.file-utils")
local theme = require("libs.theme")
local tag = require("plugin.taglib")
local albumArt = require("libs.album-art")
local buttonLib = require("libs.ui.button")
local filledButtonLib = require("libs.ui.filled-button")
local alertPopupLib = require("libs.ui.alert-popup")
local ratings = require("libs.ui.ratings")
local mMin = math.min
local mMax = math.max
local sFormat = string.format
local sSub = string.sub
local uPack = unpack
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local maxDisplayWidth = 1024
local maxDisplayHeight = 768
local group = display.newGroup()
local alertPopup = alertPopupLib.create()
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.otf"
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or "~/"
local documentsPath = system.pathForFile("", system.DocumentsDirectory)
local created = false

local function onTextFieldInput(event)
	local phase = event.phase
	local target = event.target

	if (phase == "began") then
	elseif (phase == "editing") then
		if (not target.canEdit) then
			target.text = target.origText
			return
		end

		if (target.text:len() >= target.maxLength) then
			target.text = target.text:sub(1, target.maxLength)
			return
		end
	elseif (phase == "ended" or phase == "cancelled") then
		event.target.text = event.target.text:stripLeadingAndTrailingSpaces()
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
	title:setFillColor(uPack(theme:get().textColor.primary))
	group:insert(title)

	local textField = native.newTextField(display.contentWidth, -200, options.width - title.contentWidth, options.height)
	textField.anchorX = title.anchorX
	textField.anchorY = title.anchorY
	textField.x = title.x + title.contentWidth + 2
	textField.y = title.y
	textField.inputType = options.inputType or "default"
	textField.placeholder = options.placeholder
	textField.canEdit = options.canEdit
	textField.maxLength = options.maxLength or 2048
	textField.text = options.text and tostring(options.text):len() > 0 and tostring(options.text) or ""
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
	local albumArtworkContainer = nil
	local albumArtworkNotFoundText = nil
	local albumArtwork = nil
	local albumArtworkPathButton = nil
	local albumArtworkGoogleButton = nil
	local albumArtworkMusicBrainzButton = nil
	local albumArtworkMusicDiscogsButton = nil
	local albumCoverSearchWebView = nil
	local tempArtworkFullPath = nil
	local realArtworkFilename = nil
	local realArtworkPath = nil
	local realArtworkFullPath = nil
	local songFilePathTextField = nil
	local songFilePathButton = nil
	local songTitleTextField = nil
	local songSortTitleTextField = nil
	local songAlbumTextField = nil
	local songArtistTextField = nil
	local songGenreTextField = nil
	local songYearTextField = nil
	local songTrackNumberTextField = nil
	local songDurationMinutesTextField = nil
	local songDurationSecondsTextField = nil
	local songCommentTextField = nil
	local ratingText = nil
	local ratingStars = nil
	local onAlbumArtDownloadComplete = nil
	local buttonGroup = nil
	local cancelButton = nil
	local confirmButton = nil

	function group:hideChildren()
		for i = self.numChildren, 1, -1 do
			self[i].isVisible = false
		end
	end

	function group:showChildren()
		for i = self.numChildren, 1, -1 do
			if (not self[i].ignoreVisibilityChange) then
				self[i].isVisible = true
			end
		end
	end

	function group:cleanup()
		for i = self.numChildren, 1, -1 do
			display.remove(self[i])
			self[i] = nil
		end

		Runtime:removeEventListener("AlbumArtDownloadEdit", onAlbumArtDownloadComplete)
	end

	function group:show(song)
		self:cleanup()

		local textFieldEdgePadding = 20
		local textFieldYPadding = 10
		local textFieldHeight = 30
		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)
		albumArt.customEventName = "AlbumArtDownloadEdit"
		local songRating = song.rating
		local songMp3Rating = 0

		interactionDisableRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
		interactionDisableRect.x = display.contentCenterX
		interactionDisableRect.y = display.contentCenterY
		interactionDisableRect.ignoreVisibilityChange = true
		interactionDisableRect.isVisible = false
		interactionDisableRect.isHitTestable = true
		interactionDisableRect:addEventListener(
			"tap",
			function()
				if (albumCoverSearchWebView and albumCoverSearchWebView.removeSelf) then
					albumCoverSearchWebView:removeSelf()
				end

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
		background:setFillColor(uPack(theme:get().backgroundColor.primary))
		background:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		background:addEventListener(
			"tap",
			function()
				native.setKeyboardFocus(nil)
				return true
			end
		)
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
		titleText:setFillColor(uPack(theme:get().textColor.primary))
		self:insert(titleText)

		separatorLine = display.newRoundedRect(0, 0, background.contentWidth - 40, 1, 1)
		separatorLine.x = background.x
		separatorLine.y = titleText.y + titleText.contentHeight * 0.5
		separatorLine:setFillColor(uPack(theme:get().textColor.secondary))
		self:insert(separatorLine)

		albumArtworkContainer =
			display.newRoundedRect(0, 0, background.contentWidth * 0.36, background.contentWidth * 0.36, 2)
		albumArtworkContainer.anchorX = 0
		albumArtworkContainer.anchorY = 0
		albumArtworkContainer.x = background.x + 55
		albumArtworkContainer.y = titleText.y + titleText.contentHeight * 0.5 + 20
		albumArtworkContainer.strokeWidth = 1
		albumArtworkContainer:setFillColor(uPack(theme:get().backgroundColor.primary))
		albumArtworkContainer:setStrokeColor(uPack(theme:get().backgroundColor.outline))
		self:insert(albumArtworkContainer)

		albumArtworkNotFoundText =
			display.newText(
			{
				text = "Searching for cover...",
				font = subTitleFont,
				fontSize = maxHeight * 0.03,
				align = "center"
			}
		)
		albumArtworkNotFoundText.x = albumArtworkContainer.x + albumArtworkContainer.contentWidth * 0.5
		albumArtworkNotFoundText.y = albumArtworkContainer.y + albumArtworkContainer.contentHeight * 0.5
		self:insert(albumArtworkNotFoundText)

		albumArtworkPathButton =
			filledButtonLib.new(
			{
				iconName = "image-polaroid",
				labelText = "Select",
				fontSize = maxHeight * 0.03,
				parent = self,
				onClick = function(event)
					local foundFile =
						tfd.openFileDialog(
						{
							title = "Select New Image",
							initialPath = sFormat("%s%s%s", userHomeDirectoryPath, "Pictures", string.pathSeparator),
							filters = {"*.jpg", "*.jpeg", "*.png"},
							singleFilterDescription = "Image Files| *.jpg;*.jpeg;*.png;",
							multiSelect = false
						}
					)

					if (foundFile ~= nil) then
						local fileExtension = foundFile:fileExtension()

						realArtworkFullPath =
							sFormat("%s%s%s.%s", fileUtils.documentsFullPath, fileUtils.albumArtworkFolder, song.md5, fileExtension)
						tempArtworkFullPath = sFormat("%s%s.%s", fileUtils.temporaryFullPath, "tempArtwork_chooser", fileExtension)

						fileUtils:copyFile(foundFile, tempArtworkFullPath)

						if (albumArtwork) then
							display.remove(albumArtwork)
							albumArtwork = nil
						end

						albumArtwork =
							display.newImageRect(
							sFormat("%s.%s", "tempArtwork_chooser", fileExtension),
							system.TemporaryDirectory,
							albumArtworkContainer.contentWidth - 2,
							albumArtworkContainer.contentHeight - 2
						)
						albumArtwork.anchorX = 0
						albumArtwork.anchorY = 0
						albumArtwork.x = albumArtworkContainer.x + 1
						albumArtwork.y = albumArtworkContainer.y + 1
						self:insert(albumArtwork)
						albumArtworkNotFoundText.isVisible = false
					end
				end
			}
		)
		albumArtworkPathButton.x =
			albumArtworkContainer.x + albumArtworkContainer.contentWidth - albumArtworkPathButton.contentWidth * 0.75
		albumArtworkPathButton.y =
			albumArtworkContainer.y + albumArtworkContainer.contentHeight + albumArtworkPathButton.contentHeight * 0.5 + 8
		albumArtworkPathButton.isVisible = false

		albumArtworkMusicDiscogsButton =
			buttonLib.new(
			{
				iconName = "compact-disc",
				fontSize = maxHeight * 0.03,
				parent = self,
				onClick = function(clickEvent)
					albumArt:getRemoteAlbumCover(song, albumArt.remoteProviders.discogs)
				end
			}
		)
		albumArtworkMusicDiscogsButton.x =
			albumArtworkPathButton.x - albumArtworkPathButton.contentWidth * 0.5 + albumArtworkMusicDiscogsButton.contentWidth
		albumArtworkMusicDiscogsButton.y = albumArtworkPathButton.y
		albumArtworkMusicDiscogsButton.isVisible = false

		albumArtworkMusicBrainzButton =
			buttonLib.new(
			{
				iconName = "head-side-brain",
				fontSize = maxHeight * 0.03,
				parent = self,
				onClick = function(clickEvent)
					albumArt:getRemoteAlbumCover(song, albumArt.remoteProviders.musicBrainz)
				end
			}
		)
		albumArtworkMusicBrainzButton.x = albumArtworkMusicDiscogsButton.x - albumArtworkMusicBrainzButton.contentWidth - 5
		albumArtworkMusicBrainzButton.y = albumArtworkMusicDiscogsButton.y
		albumArtworkMusicBrainzButton.isVisible = false

		albumArtworkGoogleButton =
			buttonLib.new(
			{
				iconName = "google",
				font = fontAwesomeBrandsFont,
				fontSize = maxHeight * 0.03,
				parent = self,
				onClick = function(clickEvent)
					albumArt:getRemoteAlbumCover(song, albumArt.remoteProviders.google)
				end
			}
		)
		albumArtworkGoogleButton.x = albumArtworkMusicBrainzButton.x - albumArtworkMusicBrainzButton.contentWidth - 5
		albumArtworkGoogleButton.y = albumArtworkMusicBrainzButton.y
		albumArtworkGoogleButton.isVisible = false

		onAlbumArtDownloadComplete = function(event)
			local phase = event.phase

			if (phase == "downloaded") then
				local coverFileName = event.fileName

				tempArtworkFullPath = sFormat("%s%s", fileUtils.temporaryFullPath, coverFileName)
				realArtworkFullPath =
					sFormat(
					"%s%s%s.%s",
					fileUtils.documentsFullPath,
					fileUtils.albumArtworkFolder,
					song.md5,
					coverFileName:fileExtension()
				)

				local coverDirectory = coverFileName:find("tempArtwork") and system.TemporaryDirectory or system.DocumentsDirectory

				albumArtwork =
					display.newImageRect(
					coverFileName,
					coverDirectory,
					albumArtworkContainer.contentWidth - 2,
					albumArtworkContainer.contentHeight - 2
				)
				albumArtwork.anchorX = 0
				albumArtwork.anchorY = 0
				albumArtwork.x = albumArtworkContainer.x + 1
				albumArtwork.y = albumArtworkContainer.y + 1
				self:insert(albumArtwork)
				albumArtworkNotFoundText.isVisible = false
			elseif (phase == "notFound") then
				albumArtworkNotFoundText.text = "No Cover Found"
			end

			albumArtworkPathButton.isVisible = true
			albumArtworkMusicDiscogsButton.isVisible = true
			albumArtworkMusicBrainzButton.isVisible = true
			albumArtworkGoogleButton.isVisible = true

			return true
		end

		Runtime:addEventListener(albumArt.customEventName, onAlbumArtDownloadComplete)
		albumArt:getFileAlbumCover(song)

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
				canEdit = false,
				align = "left",
				title = "File Path:",
				titleBounds = background.width - 40
			}
		)

		songFilePathButton =
			filledButtonLib.new(
			{
				iconName = "ellipsis-h",
				fontSize = maxHeight * 0.0395,
				parent = self,
				onClick = function(event)
					local foundFile =
						tfd.openFileDialog(
						{
							title = "Select Music File",
							initialPath = sFormat("%s%s%s", userHomeDirectoryPath, "Music", string.pathSeparator),
							filters = audioLib.fileSelectFilter,
							singleFilterDescription = "Audio Files| *.mp3;*.flac;*.ogg;*.wav;*.ape;*.vgm;*.mod etc"
						}
					)

					if (foundFile ~= nil) then
						songFilePathTextField.field.text = foundFile
					end
				end
			}
		)
		songFilePathButton.x =
			songFilePathTextField.field.x + songFilePathTextField.field.contentWidth + songFilePathButton.contentWidth * 0.5 + 6
		songFilePathButton.y = songFilePathTextField.field.y + songFilePathTextField.field.contentHeight * 0.5

		songTitleTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songFilePathTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Title...",
				text = song.title,
				canEdit = true,
				align = "left",
				title = "Title:",
				titleBounds = background.width - 40
			}
		)

		songSortTitleTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songTitleTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Sort Title...",
				text = song.sortTitle,
				canEdit = true,
				align = "left",
				title = "Sort Title:",
				titleBounds = background.width - 40
			}
		)

		songAlbumTextField =
			createTextField(
			{
				x = textFieldLeftEdge,
				y = songSortTitleTextField.field.y + textFieldHeight + textFieldYPadding,
				width = background.width * 0.45,
				height = textFieldHeight,
				placeholder = "Album...",
				text = song.album,
				canEdit = true,
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
				canEdit = true,
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
				canEdit = true,
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
				inputType = "number",
				placeholder = "Year...",
				maxLength = 4,
				text = song.year,
				canEdit = true,
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
				inputType = "number",
				placeholder = "Track Number...",
				maxLength = 3,
				text = song.trackNumber,
				canEdit = true,
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
				canEdit = true,
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
				inputType = "number",
				placeholder = "Mins...",
				maxLength = 2,
				text = durationMinutes,
				canEdit = true,
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
				inputType = "number",
				placeholder = "Secs...",
				maxLength = 2,
				text = durationSeconds,
				canEdit = true,
				align = "left",
				title = ":",
				titleBounds = 80
			}
		)

		ratingText =
			display.newText(
			{
				text = "Rating:",
				font = subTitleFont,
				fontSize = maxHeight * 0.025,
				width = (background.width - 40) * 0.15,
				align = "left"
			}
		)
		ratingText.anchorX = 0
		ratingText.anchorY = 0
		ratingText.x = textFieldLeftEdge
		ratingText.y = songDurationMinutesTextField.field.y + textFieldHeight + textFieldYPadding
		ratingText:setFillColor(uPack(theme:get().textColor.primary))
		group:insert(ratingText)

		ratingStars =
			ratings.new(
			{
				x = ratingText.x + ratingText.contentWidth + 42,
				y = ratingText.y + ratingText.contentHeight * 0.5,
				fontSize = 12,
				rating = song.rating or 0,
				isVisible = true,
				parent = group,
				onClick = function(event)
					--print(event.rating)
					--print(event.mp3Rating)
					songRating = event.rating
					songMp3Rating = event.mp3Rating
					event.parent:update(event.rating)
				end
			}
		)

		buttonGroup = display.newGroup()

		cancelButton =
			filledButtonLib.new(
			{
				iconName = "window-close",
				labelText = "Cancel",
				fontSize = maxHeight * 0.04,
				parent = buttonGroup,
				onClick = function(event)
					self:hide()
				end
			}
		)
		cancelButton.x = -cancelButton.contentWidth * 0.5 - 10

		confirmButton =
			filledButtonLib.new(
			{
				iconName = "save",
				labelText = "Confirm",
				fontSize = maxHeight * 0.04,
				parent = buttonGroup,
				onClick = function(event)
					local checksFailed = false
					local failedTitle = "is too short"
					local failedMessage = "you entered is too short.\n\nPlease enter at least"

					-- sanity checks
					if (tonumber(songYearTextField.field.text) == nil) then
						failedTitle = sFormat("%s %s", "Song Year", failedTitle)
						failedMessage = sFormat("%s %s %d characters", "The song year", failedMessage, songYearTextField.field.maxLength)
						checksFailed = true
					end

					if (tonumber(songTrackNumberTextField.field.text) == nil) then
						failedTitle = sFormat("%s %s", "Song Track Number", failedTitle)
						failedMessage =
							sFormat(
							"%s %s 1 to %d characters",
							"The song track number",
							failedMessage,
							songTrackNumberTextField.field.maxLength
						)
						checksFailed = true
					end

					if (songDurationMinutesTextField.field.text:len() < 1) then
						failedTitle = sFormat("%s %s", "Song Duration Minutes", failedTitle)
						failedMessage =
							sFormat(
							"%s %s 1 to %d characters",
							"The song duration minutes",
							failedMessage,
							songDurationMinutesTextField.field.maxLength
						)
						checksFailed = true
					end

					if (songDurationSecondsTextField.field.text:len() < 1) then
						failedTitle = sFormat("%s %s", "Song Duration Seconds", failedTitle)
						failedMessage =
							sFormat(
							"%s %s 1 to %d characters",
							"The song duration seconds",
							failedMessage,
							songDurationSecondsTextField.field.maxLength
						)
						checksFailed = true
					end

					if (checksFailed) then
						self:hideChildren()
						alertPopup:onlyUseOkButton()
						alertPopup:setTitle(failedTitle)
						alertPopup:setMessage(failedMessage)
						alertPopup:setButtonCallbacks(
							{
								onOK = function()
									self:showChildren()
								end
							}
						)
						alertPopup:show()
						return
					end

					if (realArtworkFullPath) then
						os.remove(realArtworkFullPath)
					end

					if (tempArtworkFullPath) then
						os.rename(tempArtworkFullPath, realArtworkFullPath)
					end

					if (realArtworkFullPath) then
						albumArt:saveCoverToAudioFile(
							song,
							sFormat("%s%s", fileUtils.albumArtworkFolder, realArtworkFullPath:getFileName())
						)
					end

					song.album = songAlbumTextField.field.text:stripLeadingAndTrailingSpaces()
					song.artist = songArtistTextField.field.text:stripLeadingAndTrailingSpaces()
					song.genre = songGenreTextField.field.text:stripLeadingAndTrailingSpaces()
					song.year = tonumber(songYearTextField.field.text)
					song.trackNumber = tonumber(songTrackNumberTextField.field.text)
					song.comment = songCommentTextField.field.text:stripLeadingAndTrailingSpaces()
					song.duration =
						sFormat("%2s:%2s", songDurationMinutesTextField.field.text, songDurationSecondsTextField.field.text)
					song.rating = songRating
					song.title = songTitleTextField.field.text:stripLeadingAndTrailingSpaces()
					song.sortTitle = songSortTitleTextField.field.text:stripLeadingAndTrailingSpaces()

					tag.set(
						{
							fileName = song.fileName,
							filePath = song.filePath,
							tags = {
								album = song.album,
								artist = song.artist,
								genre = song.genre,
								year = song.year,
								trackNumber = song.trackNumber,
								comment = song.comment,
								duration = song.duration,
								rating = songMp3Rating,
								title = song.title
							}
						}
					)

					sqlLib:updateMusic(song)
					Runtime:dispatchEvent({name = "musicListEvent", phase = "reloadData"})

					self:hide()
				end
			}
		)
		confirmButton.x = confirmButton.contentWidth * 0.5 + 10
		self:insert(buttonGroup)

		buttonGroup.anchorChildren = true
		buttonGroup.anchorX = 0.5
		buttonGroup.x = background.x
		buttonGroup.y = background.y + background.contentHeight * 0.5 - buttonGroup.contentHeight

		self.isVisible = true
		self:toFront()
	end

	function group:hide()
		self:cleanup()

		albumArt.customEventName = nil
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
