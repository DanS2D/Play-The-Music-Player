-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

local composer = require("composer")
local lfs = require("lfs")
local widget = require("widget")
local strict = require("strict")
local tfd = require("plugin.tinyfiledialogs")
local mousecursor = require("plugin.mousecursor")
local bass = require("plugin.bass")
local mainMenuBar = require("main-menu-bar")
local utils = require("utils")
local tableView = require("music_tableview")
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
local settingsFileName = "settings.json"
local settings = utils:loadTable(settingsFileName)
local musicFiles = {}
local musicStreamHandle = nil
local musicPlayChannel = nil
local musicDuration = 0
local currentSongIndex = 0
local controlButtonsXOffset = 10
local documentsDirectoryPath = system.pathForFile("", system.DocumentsDirectory)
local songProgess = 0
local rowColors = {}
local songTitleText = nil
local songAlbumText = nil
local songProgressView = nil
local tableViewTarget = nil
local categoryTarget = nil
local categoryList = {}
local tableViewList = {}
local playbutton = nil
local pauseButton = nil
local playAudio = nil
local volumeOnButton = nil
local volumeOffButton = nil
local volumeSlider = nil
local playBackTimeText = nil
local previousVolume = 0
local looping = false
local audioChannels = {}
local leftChannel = {}
local rightChannel = {}
local levelVisualizationGroup = display.newGroup()
local buttonSize = 20
local rowFontSize = 10
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local resizeCursor = mousecursor.newCursor("resize left right")
local supportedFormats = {
	"b",
	"m",
	"2sf",
	"ahx",
	"as0",
	"asc",
	"ay",
	"ayc",
	"bin",
	"cc3",
	"chi",
	"cop",
	"d",
	"dmm",
	"dsf",
	"dsq",
	"dst",
	"esv",
	"fdi",
	"ftc",
	"gam",
	"gamplus",
	"gbs",
	"gsf",
	"gtr",
	"gym",
	"hes",
	"hrm",
	"hrp",
	"hvl",
	"kss",
	"lzs",
	"m",
	"mod",
	"msp",
	"mtc",
	"nsf",
	"nsfe",
	"p",
	"pcd",
	"psc",
	"psf",
	"psf2",
	"psg",
	"psm",
	"pt1",
	"pt2",
	"pt3",
	"rmt",
	"rsn",
	"s",
	"sap",
	"scl",
	"sid",
	"spc",
	"sqd",
	"sqt",
	"ssf",
	"st1",
	"st3",
	"stc",
	"stp",
	"str",
	"szx",
	"td0",
	"tf0",
	"tfc",
	"tfd",
	"tfe",
	"tlz",
	"tlzp",
	"trd",
	"trs",
	"ts",
	"usf",
	"vgm",
	"vgz",
	"vtx",
	"ym",
	"spx",
	"mpc",
	"ape",
	"ac3",
	"wav",
	"aiff",
	"mp3",
	"mp2",
	"mp1",
	"ogg",
	"flac",
	"wav"
}
widget.mouseEventsEnabled = true
widget.setTheme("widget_theme_ios")

local function fileExists(filePath, baseDir)
	local path = system.pathForFile(filePath, baseDir or system.DocumentsDirectory)
	local file = io.open(path, "r")
	local exists = false

	if (file) then
		exists = true
		io.close(file)
	end

	return exists
end

local function populateMusicTableView()
	local default = {default = {0.38, 0.38, 0.38, 0.6}, over = {0.38, 0.38, 0.38, 0}}
	local defaultSecondRow = {default = {0.28, 0.28, 0.28, 0.6}, over = {0.28, 0.28, 0.28, 0}}
	local rowColor = default

	for j = 1, #tableViewList do
		for i = 1, #musicFiles do
			rowColor = default

			if (i % 2 == 0) then
				rowColor = defaultSecondRow
			end

			tableViewList[j]:insertRow {
				isCategory = false,
				rowHeight = 25,
				rowColor = rowColor,
				params = {
					--id = [i].id,
					fileName = musicFiles[i].fileName,
					filePath = musicFiles[i].filePath
				}
			}
			rowColors[i] = rowColor
		end
	end
end

local function isMusicFile(fileName)
	local fileExtension = fileName:match("^.+(%..+)$")
	local isMusic = false

	for i = 1, #supportedFormats do
		if (fileExtension == sFormat(".%s", supportedFormats[i])) then
			isMusic = true
			break
		end
	end

	return isMusic
end

--local devices = bass.getDevices()
--print(type(devices), "num elements", #devices)
--[[
for i = 1, #devices do
	--print(devices[i].name)
	if devices[i].name:lower():find("headset") ~= 0 then
	--print("setting device to headset")
	--bass.setDevice(devices[i].index)
	end
end--]]
local function gatherMusic(path)
	local foundMusic = false
	musicFiles = {}

	local function getMusic(filename, musicPath)
		local fullPath = sFormat("%s\\%s", musicPath, filename)

		if (isMusicFile(fullPath)) then
			local chan = bass.load(filename, musicPath)
			local playbackDuration = bass.getPlaybackTime(chan).duration
			musicFiles[#musicFiles + 1] = {fileName = filename, filePath = musicPath, tags = bass.getTags(chan)}
			musicFiles[#musicFiles].tags.duration = sFormat("%02d:%02d", playbackDuration.minutes, playbackDuration.seconds)
			playbackDuration = nil
		--bass.dispose(chan)
		end
	end

	local function iterateDirectory(path)
		local paths = {}
		paths[#paths + 1] = path
		local count = 0

		repeat
			count = count + 1
			--print(paths[#paths])

			for file in lfs.dir(paths[1]) do
				if (file:sub(-1) ~= ".") then
					local fullPath = paths[1] .. "\\" .. file
					local isDir = lfs.attributes(fullPath, "mode") == "directory"
					--print(file .. " attr: ", lfs.attributes(fullPath, "mode"))

					if (isMusicFile(fullPath)) then
						--print(fullPath)
						--print(paths[1] .. "\\" .. file)
						foundMusic = true
						getMusic(file, paths[1])
					end

					if (isDir) then
						--print(fullPath .. " attr: ", lfs.attributes(fullPath, "mode"))
						table.insert(paths, fullPath)
					end
				end
			end

			table.remove(paths, 1)
		until #paths == 0
	end

	if (path) then
		iterateDirectory(path)
	end

	if (foundMusic) then
		print("found music")
		local function sortByTitle(a, b)
			if (not a.tags.title or not b.tags.title) then
				return 1 < 0
			end
			return a.tags.title < b.tags.title
		end

		table.sort(musicFiles, sortByTitle)
		populateMusicTableView()
	else
		native.showAlert("No Music Found", "I didn't find any music in the selected folder path", {"OK"})
	end
end

local function resetSongProgress()
	playBackTimeText.text = "00:00/00:00"
	songProgess = 0
	songProgressView:setProgress(0)
end

local function cleanupAudio()
	if (musicPlayChannel ~= nil) then
		playBackTimeText:update()
		bass.stop(musicPlayChannel)
		bass.dispose(musicStreamHandle)
		resetSongProgress()
	end
end

local function onAudioComplete(event)
	print("audio playback complete?", event.completed)

	if (looping) then
		print("audio is set to loop, restarting audio")
		playAudio(currentSongIndex)

		return
	end

	if (event.completed) then
		print("cleaning up audio")
		cleanupAudio()
		currentSongIndex = currentSongIndex + 1
		playAudio(currentSongIndex)
	end
end

playAudio = function(index)
	resetSongProgress()
	songTitleText:setText(musicFiles[index].tags.title)
	songAlbumText:setText(musicFiles[index].tags.album)
	--musicTableView:scrollToIndex(currentSongIndex + 1, 200)
	musicStreamHandle = bass.load(musicFiles[index].fileName, musicFiles[index].filePath)
	print(musicStreamHandle)
	musicDuration = bass.getDuration(musicStreamHandle) * 1000
	musicPlayChannel = bass.play(musicStreamHandle)
	table.remove(audioChannels)
	audioChannels[#audioChannels + 1] = musicStreamHandle
end

local applicationMainMenuBar =
	mainMenuBar.new(
	{
		font = titleFont,
		items = {
			{
				title = "File",
				subItems = {
					{
						title = "Add Music Folder",
						onClick = function()
							print("add folder")
						end
					},
					{
						title = "Add Music File",
						onClick = function()
							print("add file")
						end
					},
					{
						title = "Exit",
						onClick = function()
							print("exit")
							os.exit()
						end
					}
				}
			},
			{
				title = "Edit",
				subItems = {
					{
						title = "Edit Tags"
					},
					{
						title = "Edit Playlist"
					},
					{
						title = "Preferences"
					}
				}
			},
			{
				title = "Music",
				subItems = {
					{
						title = "Fade In Track"
					},
					{
						title = "Fade Out Track"
					}
				}
			},
			{
				title = "View",
				subItems = {
					{
						title = "Show Music List"
					},
					{
						title = "Show Playlists"
					},
					{
						title = "Show Visualizer"
					}
				}
			},
			{
				title = "Help",
				subItems = {
					{
						title = "Report Bug"
					},
					{
						title = "Submit Feature Request"
					},
					{
						title = "Visit Website"
					},
					{
						title = "About"
					}
				}
			}
		}
	}
)

local previousButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "previous-button.png",
		overFile = overButtonPath .. "previous-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			if (currentSongIndex - 1 > 0) then
				currentSongIndex = currentSongIndex - 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end
	}
)
previousButton.x = (dScreenOriginX + (previousButton.contentWidth * 0.5) + controlButtonsXOffset)
previousButton.y = 55

playButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "play-button.png",
		overFile = overButtonPath .. "play-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			if (musicStreamHandle) then
				event.target.isVisible = false
				pauseButton.isVisible = true

				if (bass.isChannelPlaying(musicPlayChannel)) then
					return
				end

				if (bass.isChannelPaused(musicPlayChannel)) then
					bass.resume(musicPlayChannel)
					return
				end

				musicPlayChannel = bass.play(musicStreamHandle)
			end
		end
	}
)
playButton.x = (previousButton.x + previousButton.contentWidth + controlButtonsXOffset)
playButton.y = previousButton.y

pauseButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "pause-button.png",
		overFile = overButtonPath .. "pause-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			if (musicStreamHandle) then
				if (bass.isChannelPlaying(musicPlayChannel)) then
					bass.pause(musicPlayChannel)
					event.target.isVisible = false
					playButton.isVisible = true
				end
			end
		end
	}
)
pauseButton.x = playButton.x
pauseButton.y = previousButton.y
pauseButton.isVisible = false

local nextButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "next-button.png",
		overFile = overButtonPath .. "next-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			if (currentSongIndex + 1 <= #musicFiles) then
				currentSongIndex = currentSongIndex + 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end
	}
)
nextButton.x = (pauseButton.x + pauseButton.contentWidth + controlButtonsXOffset)
nextButton.y = previousButton.y

local songContainerBox = display.newRoundedRect(0, 0, dWidth / 2 - 8, 50, 2)
songContainerBox.anchorX = 0
songContainerBox.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset + 29)
songContainerBox.y = nextButton.y - 5
songContainerBox.strokeWidth = 1
songContainerBox:setFillColor(0, 0, 0, 0)
songContainerBox:setStrokeColor(0.6, 0.6, 0.6, 0.5)

songTitleText =
	display.newText(
	{
		text = "",
		font = titleFont,
		align = "center",
		width = dWidth / 2,
		fontSize = 15
	}
)
songTitleText.anchorX = 0
songTitleText.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset + 30)
songTitleText.y = songContainerBox.y - 12
songTitleText:setFillColor(0.9, 0.9, 0.9)
function songTitleText:setText(title)
	self.text = title
end

songAlbumText =
	display.newText(
	{
		text = "",
		font = subTitleFont,
		align = "center",
		width = dWidth / 2,
		fontSize = 12
	}
)
songAlbumText.anchorX = 0
songAlbumText.x = songTitleText.x
songAlbumText.y = songTitleText.y + songTitleText.contentHeight
songAlbumText:setFillColor(0.6, 0.6, 0.6)
function songAlbumText:setText(album)
	self.text = album
end

local loopButton =
	widget.newSwitch(
	{
		style = "checkbox",
		id = "loop",
		onPress = function(event)
			looping = event.target.isOn
			--bass.update(musicStreamHandle, {loop = event.target.isOn})
		end
	}
)
loopButton.width = buttonSize
loopButton.height = buttonSize
loopButton.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset)
loopButton.y = previousButton.y
loopButton._viewOff:setFillColor(0.7, 0.7, 0.7)

songProgressView =
	widget.newProgressView(
	{
		width = dWidth / 2,
		isAnimated = false
	}
)
songProgressView._view._outerLeft.height = 5
songProgressView._view._outerMiddle.height = 5
songProgressView._view._outerRight.height = 5
songProgressView._view._fillLeft.height = 5
songProgressView._view._fillMiddle.height = 5
songProgressView._view._fillRight.height = 5
songProgressView.anchorX = 0
songProgressView.x = songTitleText.x
songProgressView.y = songAlbumText.y + songAlbumText.contentHeight + 1

function songProgressView:touch(event)
	local phase = event.phase

	if (phase == "began") then
		local valueX, valueY = self:contentToLocal(event.x, event.y)
		local onePercent = self.contentWidth / 100
		local currentPercent = valueX / onePercent
		local duration = musicDuration
		local seekPosition = ((currentPercent / 10) * musicDuration / 10)
		--print(seekPosition)

		if (bass.isChannelPlaying(musicPlayChannel)) then
			songProgess = seekPosition
			songProgressView:setProgress(songProgess / duration)
			bass.seek(musicStreamHandle, songProgess / 1000)
		end
	end
end

songProgressView:addEventListener("touch")
songProgressView:setProgress(0)

volumeOnButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "volume-button.png",
		overFile = overButtonPath .. "volume-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			previousVolume = bass.getVolume()
			bass.setVolume(0)
			volumeSlider:setValue(0)
			event.target.isVisible = false
			volumeOffButton.isVisible = true
		end
	}
)
volumeOnButton.x = (songProgressView.x + (songProgressView.contentWidth) + controlButtonsXOffset + 20)
volumeOnButton.y = previousButton.y

volumeOffButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "volume-off-button.png",
		overFile = overButtonPath .. "volume-off-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			bass.setVolume(previousVolume)
			volumeSlider:setValue(previousVolume * 100)
			event.target.isVisible = false
			volumeOnButton.isVisible = true
		end
	}
)
volumeOffButton.x = volumeOnButton.x
volumeOffButton.y = previousButton.y
volumeOffButton.isVisible = false

volumeSlider =
	widget.newSlider(
	{
		width = 100,
		value = 100,
		listener = function(event)
			bass.setVolume(event.value / 100)
			--print("new volume: " .. bass.getVolume())
		end
	}
)
volumeSlider.height = volumeSlider.height / 1.5
volumeSlider.x = (volumeOnButton.x + (volumeOnButton.contentWidth) + 2)
volumeSlider.y = previousButton.y - 4

--[[
local addMusicButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "add-button.png",
		overFile = overButtonPath .. "add-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			local selectedPath = tfd.selectFolderDialog({title = "Select Music Folder"})

			if (selectedPath ~= nil) then
				if (type(settings) ~= "table") then
					settings = {}
				end

				settings.musicPath = selectedPath
				utils:saveTable(settings, settingsFileName)
				musicTableView:deleteAllRows()
				gatherMusic(settings.musicPath)
			end
		end
	}
)
addMusicButton.x = (volumeSlider.x + volumeSlider.contentWidth + addMusicButton.contentWidth)
addMusicButton.y = previousButton.y--]]
for i = 1, 13 do
	leftChannel[i] = display.newRect(50, 0, 2, 30)
	rightChannel[i] = display.newRect(50, 0, 2, 30)

	if (i == 1) then
		leftChannel[i].x = 50
		leftChannel[i].origHeight = 2
		rightChannel[i].x = 104
		rightChannel[i].origHeight = 2
	else
		leftChannel[i].x = mFloor(leftChannel[i - 1].x + 4)
		leftChannel[i].origHeight = mFloor(28 - (i * 2))
		rightChannel[i].x = mFloor(rightChannel[i - 1].x + 4)
		rightChannel[i].origHeight = mFloor(rightChannel[i - 1].origHeight + 2)
	end

	leftChannel[i]:setFillColor((255 - (21 * i - 1)) / 255, (21 * i - 1) / 255, 0)
	rightChannel[i]:setFillColor((21 * i - 1) / 255, (255 - (21 * i - 1)) / 255, 0)

	leftChannel[i].anchorY = 1
	rightChannel[i].anchorY = 1
	rightChannel[i].height = 1
	leftChannel[i].height = 1
	levelVisualizationGroup:insert(leftChannel[i])
	levelVisualizationGroup:insert(rightChannel[i])
end

levelVisualizationGroup.x = volumeSlider.x + volumeSlider.contentWidth * 0.5 + 15
levelVisualizationGroup.y = volumeOnButton.y
display.getCurrentStage():insert(levelVisualizationGroup)

playBackTimeText =
	display.newText(
	{
		text = "00:00/00:00",
		font = titleFont,
		fontSize = rowFontSize,
		align = "left"
	}
)
playBackTimeText.x = levelVisualizationGroup.x + levelVisualizationGroup.contentWidth
playBackTimeText.y = levelVisualizationGroup.y + levelVisualizationGroup.contentHeight + playBackTimeText.contentHeight
function playBackTimeText:update()
	local playbackTime = bass.getPlaybackTime(musicPlayChannel)
	local pbElapsed = playbackTime.elapsed
	local pbDuration = playbackTime.duration
	playBackTimeText.text =
		sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds)
end

local function createTableView(options)
	local tView =
		tableView.new(
		{
			left = options.left,
			top = 105,
			width = options.width or (dWidth / 5),
			height = dHeight - 80,
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
				local tags = musicFiles[row.index].tags

				if (tags.title == nil) then
					tags = {
						album = "",
						artist = "",
						genre = "",
						publisher = "",
						title = "",
						track = "",
						duration = {
							hours = 0,
							minutes = 0,
							seconds = 0
						}
					}
				end

				local rowTitleText =
					display.newText(
					{
						text = tags[options.rowTitle],
						font = subTitleFont,
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						width = rowContentWidth - 10,
						height = rowContentHeight * 0.5,
						align = "left"
					}
				)
				rowTitleText.anchorX = 0
				rowTitleText.x = 10
				row:insert(rowTitleText)
			end,
			onRowTouch = function(event)
				local phase = event.phase
				local row = event.row
				local params = row.params

				if (phase == "press") then
					currentSongIndex = row.index
					cleanupAudio()
					playAudio(currentSongIndex)
					playButton.isVisible = false
					pauseButton.isVisible = true
				end
			end
		}
	)
	tView.leftPos = options.left
	tView.topPos = 80
	tView.orderIndex = options.index

	return tView
end

local categoryBar = display.newRect(0, 0, dWidth, 25)
categoryBar.anchorX = 0
categoryBar.anchorY = 0
categoryBar.x = 0
categoryBar.y = 80
categoryBar:setFillColor(0.15, 0.15, 0.15)

local listOptions = {
	{
		index = 1,
		left = 0,
		width = dWidth,
		showSeperatorLine = true,
		categoryTitle = "Title",
		rowTitle = "title"
	},
	{
		index = 2,
		left = 200,
		width = dWidth,
		showSeperatorLine = true,
		categoryTitle = "Artist",
		rowTitle = "artist"
	},
	{
		index = 3,
		left = 400,
		width = dWidth,
		showSeperatorLine = true,
		categoryTitle = "Album",
		rowTitle = "album"
	},
	{
		index = 4,
		left = 600,
		width = dWidth,
		showSeperatorLine = true,
		categoryTitle = "Genre",
		rowTitle = "genre"
	},
	{
		index = 5,
		left = 750,
		width = dWidth,
		showSeperatorLine = true,
		categoryTitle = "Duration",
		rowTitle = "duration"
	}
}

for i = 1, #listOptions do
	tableViewList[i] = createTableView(listOptions[i])
	categoryList[i] = display.newGroup()
	categoryList[i].x = listOptions[i].left
	categoryList[i].y = 80
	categoryList[i].index = i

	local seperatorText =
		display.newText(
		{
			text = "|",
			left = 0,
			y = categoryBar.contentHeight * 0.5,
			font = subTitleFont,
			fontSize = 18,
			align = "left"
		}
	)
	categoryList[i]:insert(seperatorText)

	function seperatorText:touch(event)
		local phase = event.phase

		if (phase == "began") then
			tableViewTarget = tableViewList[self.parent.index]
			categoryTarget = categoryList[i]
		elseif (phase == "ended" or phase == "cancelled") then
			tableViewTarget = nil
		end

		return true
	end

	function seperatorText:mouse(event)
		local phase = event.type
		local xStart = self.x
		local xEnd = self.x + self.contentWidth
		local yStart = self.y - self.contentHeight * 0.5
		local yEnd = self.y + self.contentHeight * 0.5
		local x, y = self:contentToLocal(event.x, event.y)

		if (phase == "move") then
			-- handle main menu buttons
			if (y >= yStart - 8 and y <= yStart + 8) then
				if (x >= xStart - 2 and x <= xEnd - 4) then
					resizeCursor:show()
				else
					resizeCursor:hide()
				end
			else
				resizeCursor:hide()
			end
		end
	end

	seperatorText:addEventListener("touch")
	seperatorText:addEventListener("mouse")

	local titleText =
		display.newText(
		{
			text = listOptions[i].categoryTitle,
			y = categoryBar.contentHeight * 0.5,
			font = titleFont,
			fontSize = 12,
			align = "left"
		}
	)
	titleText.anchorX = 0
	titleText.x = seperatorText.x + seperatorText.contentWidth
	titleText:setFillColor(1, 1, 1)
	categoryList[i]:insert(titleText)

	function titleText:touch(event)
		local phase = event.phase
		local target = event.target
		local xStart = target.x
		local xEnd = target.x + target.contentWidth
		local yStart = target.y - target.contentHeight * 0.5
		local yEnd = target.y + target.contentHeight * 0.5
		local x, y = event.x, event.y

		if (phase == "began") then
			local thisTableView = tableViewList[self.parent.index]
			local origIndex = tableViewList[thisTableView.orderIndex].orderIndex
			local buttons = {"Right", "Left", "Cancel"}

			if (tableViewList[thisTableView.orderIndex].orderIndex == 1) then
				buttons = {"Right", "Cancel"}
			elseif (tableViewList[thisTableView.orderIndex].orderIndex == #tableViewList) then
				buttons = {"Left", "Cancel"}
			end

			local function onComplete(event)
				local optionName = buttons[event.index]

				if (event.action == "clicked") then
					if (optionName == "Right") then
						local origList = tableViewList[origIndex]
						local origPreviousList = tableViewList[origIndex + 1]
						local origCategory = categoryList[origIndex]
						local origPreviousCategory = categoryList[origIndex + 1]
						local targetX = tableViewList[origIndex + 1].x
						local swapTargetX = tableViewList[origIndex].x
						local targetCategoryX = categoryList[origIndex + 1].x
						local swapTargetCategoryX = categoryList[origIndex].x

						-- swap positions
						tableViewList[origIndex].x = targetX
						tableViewList[origIndex + 1].x = swapTargetX
						categoryList[origIndex].x = targetCategoryX
						categoryList[origIndex + 1].x = swapTargetCategoryX

						-- set new indexes
						tableViewList[origIndex + 1].orderIndex = origIndex
						tableViewList[origIndex].orderIndex = origIndex + 1
						categoryList[origIndex + 1].index = origIndex
						categoryList[origIndex].index = origIndex + 1

						-- swap table items
						tableViewList[origIndex + 1] = origList
						tableViewList[origIndex] = origPreviousList
						categoryList[origIndex + 1] = origCategory
						categoryList[origIndex] = origPreviousCategory

						-- push moved (left) list to front
						tableViewList[origIndex]:toFront()

						for i = origIndex + 1, #tableViewList do
							tableViewList[i]:toFront()
						end
					elseif (optionName == "Left") then
						local origList = tableViewList[origIndex]
						local origPreviousList = tableViewList[origIndex - 1]
						local origCategory = categoryList[origIndex]
						local origPreviousCategory = categoryList[origIndex - 1]
						local targetX = tableViewList[origIndex - 1].x
						local swapTargetX = tableViewList[origIndex].x
						local targetCategoryX = categoryList[origIndex - 1].x
						local swapTargetCategoryX = categoryList[origIndex].x

						-- swap positions
						tableViewList[origIndex].x = targetX
						tableViewList[origIndex - 1].x = swapTargetX
						categoryList[origIndex].x = targetCategoryX
						categoryList[origIndex - 1].x = swapTargetCategoryX

						-- set new indexes
						tableViewList[origIndex - 1].orderIndex = origIndex
						tableViewList[origIndex].orderIndex = origIndex - 1
						categoryList[origIndex - 1].index = origIndex
						categoryList[origIndex].index = origIndex - 1

						-- swap table items
						tableViewList[origIndex - 1] = origList
						tableViewList[origIndex] = origPreviousList
						categoryList[origIndex - 1] = origCategory
						categoryList[origIndex] = origPreviousCategory

						-- push moved (right) list to front
						tableViewList[origIndex]:toFront()

						for i = origIndex + 1, #tableViewList do
							tableViewList[i]:toFront()
						end
					else
						print("cancel")
					end
				end
			end

			local alert = native.showAlert("Move Column", "Choose a direction to move this column to.", buttons, onComplete)
		end

		return true
	end

	titleText:addEventListener("touch")
end

local function moveColumns(event)
	local phase = event.phase

	if (tableViewTarget) then
		if (phase == "moved") then
			tableViewTarget.x = mFloor(event.x + tableViewTarget.contentWidth * 0.5)
			categoryTarget.x = mFloor(event.x + categoryTarget.contentWidth * 0.5 - 20)
		end

		if (phase == "ended" or phase == "cancelled") then
			resizeCursor:hide()
			tableViewTarget = nil

			for i = 1, #tableViewList do
				tableViewList[i]:addListeners()
			end
		end
	end

	return true
end

Runtime:addEventListener("touch", moveColumns)

local function onMouseEvent(event)
	local eventType = event.type

	if (eventType == "move") then
		local x = event.x
		local y = event.y

		-- handle main menu buttons
		if (y >= 105) then
			resizeCursor:hide()
		end
	end
end

Runtime:addEventListener("mouse", onMouseEvent)

local function mouseEvents(event)
	for i = 1, #tableViewList do
		tableViewList[i]:mouse(event)
	end

	if event.type == "up" then
		resizeCursor:hide()
	end
end

Runtime:addEventListener("mouse", mouseEvents)

local ts = tableViewList[1]

function ts:highlightPressedIndex(pressedIndex)
	if (pressedIndex) then
		for i = 1, #tableViewList do
			for j = 1, ts:getNumRows() do
				local list = tableViewList[i]._view._rows[j]._view

				if (list and j ~= pressedIndex) then
					list._cell:setFillColor(unpack(rowColors[j].default))
				end
			end

			if (tableViewList[i]._view._rows[pressedIndex]._view) then
				tableViewList[i]._view._rows[pressedIndex]._view._cell:setFillColor(0.5, 0.5, 0.5, 1)
			end
		end
	end
end

timer.performWithDelay(
	10,
	function()
		if (currentSongIndex > 0 and currentSongIndex <= ts:getNumRows()) then
			ts:highlightPressedIndex(currentSongIndex)
		end

		if (musicPlayChannel and bass.isChannelPlaying(musicPlayChannel)) then
			local leftLevel, rightLevel = bass.getLevel(musicPlayChannel)
			local minLevel = 0
			local maxLevel = 32768
			local chunk = 2520

			for i = 1, 13 do
				if (leftLevel > chunk * (14 - i)) then
					leftChannel[i].height = leftChannel[i].origHeight
				else
					leftChannel[i].height = 1
				end

				if (rightLevel > chunk * (1 + (i - 1))) then
					rightChannel[i].height = rightChannel[i].origHeight
				else
					rightChannel[i].height = 1
				end
			end
		end
	end,
	0
)

timer.performWithDelay(
	1000,
	function()
		if (musicPlayChannel and bass.isChannelPlaying(musicPlayChannel)) then
			local duration = (musicDuration)
			songProgess = songProgess + 1
			--print(musicDuration, duration, prog / duration)

			playBackTimeText:update()
			songProgressView:setProgress(songProgess / duration)
		end
	end,
	0
)

if (type(settings) == "table" and settings.musicPath) then
	print("gathering music")
	gatherMusic(settings.musicPath)
end

local function handleAudioEvents(event)
	if (type(audioChannels) == "table") then
		for i = 1, #audioChannels do
			local channel = audioChannels[i]
			if (channel and not bass.isChannelPlaying(channel) and not bass.isChannelPaused(channel)) then
				local e = {
					name = "bass",
					completed = true
					--loop = bass.isChannelLooping(musicStreamHandle)
				}
				--print(bass.isChannelLooping(musicStreamHandle))
				--table.remove(audioChannels, i)
				onAudioComplete(e)
			end
		end
	end
end

Runtime:addEventListener("enterFrame", handleAudioEvents)

local function keyEventListener(event)
	local keyCode = event.nativeKeyCode
	local phase = event.phase

	if (phase == "down") then
		--print("event name:", event.name)
		--print("keyname:", event.keyName)
		print("keycode:", event.nativeKeyCode)

		-- pause/resume toggle
		if (keyCode == 65539) then
			if (musicPlayChannel) then
				if (bass.isChannelPaused(musicPlayChannel)) then
					playButton.isVisible = false
					pauseButton.isVisible = true

					bass.resume(musicPlayChannel)
				else
					if (bass.isChannelPlaying(musicPlayChannel)) then
						playButton.isVisible = true
						pauseButton.isVisible = false

						bass.pause(musicPlayChannel)
					end
				end
			end
		elseif (keyCode == 65542) then
			-- next
			if (currentSongIndex + 1 <= #musicFiles) then
				currentSongIndex = currentSongIndex + 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		elseif (keyCode == 65541) then
			-- previous
			if (currentSongIndex - 1 > 0) then
				currentSongIndex = currentSongIndex - 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end
	end

	return false
end

bass.setVolume(1.0)
display.getCurrentStage():insert(applicationMainMenuBar)
Runtime:addEventListener("key", keyEventListener)
