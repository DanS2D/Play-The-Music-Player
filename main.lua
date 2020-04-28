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
local bass = require("plugin.bass")
local utils = require("utils")
widget.mouseEventsEnabled = true
widget.setTheme("widget_theme_android_holo_dark")
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
local statusText = nil
local songProgressView = nil
local musicTableView = nil
local playAudio = nil
local rowFontSize = 10
local id3Info = {
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
	local category = {default = {0.48, 0.48, 0.8}, over = {0.48, 0.48, 0.48, 0.8}}
	local rowColor = default

	for i = 1, #musicFiles + 1 do
		rowColor = default

		if (i % 2 == 0) then
			rowColor = defaultSecondRow
		end

		musicTableView:insertRow {
			isCategory = i == 1,
			rowHeight = 25,
			rowColor = i == 1 and category or rowColor,
			params = {
				--id = [i].id,
				fileName = i > 1 and musicFiles[i - 1].fileName,
				filePath = i > 1 and musicFiles[i - 1].filePath
			}
		}
		rowColors[i] = (i == 1) and category or rowColor
	end
end

local function isMusicFile(fileName)
	local fileExtension = fileName:match("^.+(%..+)$")
	local isMusic = false
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

	for i = 1, #supportedFormats do
		if (fileExtension == sFormat(".%s", supportedFormats[i])) then
			isMusic = true
			break
		end
	end

	return isMusic
end

local devices = bass.getDevices()
--print(type(devices), "num elements", #devices)

for i = 1, #devices do
	--print(devices[i].name)
	if devices[i].name:lower():find("headset") ~= 0 then
	--print("setting device to headset")
	--bass.setDevice(devices[i].index)
	end
end

local function gatherMusic(path)
	local foundMusic = false
	musicFiles = {}

	local function getMusic(filename, musicPath)
		local fullPath = sFormat("%s\\%s", musicPath, filename)

		if (isMusicFile(fullPath)) then
			local chan = bass.load(filename, musicPath)
			musicFiles[#musicFiles + 1] = {fileName = filename, filePath = musicPath, tags = bass.getTags(chan)}
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
	songProgess = 0
	songProgressView:setProgress(0)
end

local function cleanupAudio()
	if (musicPlayChannel ~= nil) then
		bass.stop(musicPlayChannel)
		bass.dispose(musicStreamHandle)
		resetSongProgress()
	end
end

local function onAudioComplete(event)
	print("audio playback complete?", event.completed)

	if (event.loop) then
		print("audio is set to loop, restarting audio")
		resetSongProgress()

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
	statusText:setSongName(musicFiles[index].tags.title, musicFiles[index].tags.artist)
	--musicTableView:scrollToIndex(currentSongIndex + 1, 200)
	musicStreamHandle = bass.load(musicFiles[index].fileName, musicFiles[index].filePath)
	musicDuration = bass.getDuration(musicStreamHandle) * 1000
	musicPlayChannel = bass.play(musicStreamHandle, {loop = false, onComplete = onAudioComplete})
end

local background = display.newRect(0, 0, dWidth, 80)
background.anchorY = 0
background.x = dCenterX
background.y = 0
background.fill = {
	type = "gradient",
	color1 = {39 / 255, 51 / 255, 1, 0.6},
	color2 = {181 / 255, 42 / 255, 1, 0.6},
	direction = "up"
}

statusText =
	display.newText(
	{
		text = "No Song Playing",
		align = "center",
		width = dWidth - 20,
		fontSize = 18
	}
)
statusText.x = dCenterX
statusText.y = 20
function statusText:setSongName(name, artist)
	self.text = sFormat("Currently Playing: %s by %s", name, artist)
end

local previousButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "previous-button.png",
		overFile = overButtonPath .. "previous-button.png",
		width = 30,
		height = 30,
		onPress = function(event)
			if (currentSongIndex - 1 > 0) then
				currentSongIndex = currentSongIndex - 1

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end
	}
)
previousButton.x = (dScreenOriginX + (previousButton.contentWidth * 0.5) + controlButtonsXOffset)
previousButton.y = (statusText.y + (statusText.contentHeight) + 10)

local stopButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "stop-button.png",
		overFile = overButtonPath .. "stop-button.png",
		width = 30,
		height = 30,
		onPress = function(event)
			statusText:setSongName("Nothing", "Nobody")
			cleanupAudio()
		end
	}
)
stopButton.x = (previousButton.x + previousButton.contentWidth + controlButtonsXOffset)
stopButton.y = previousButton.y

local playButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "play-button.png",
		overFile = overButtonPath .. "play-button.png",
		width = 30,
		height = 30,
		onPress = function(event)
			if (musicStreamHandle) then
				if (bass.isChannelPlaying(musicPlayChannel)) then
					return
				end

				if (bass.isChannelPaused(musicPlayChannel)) then
					bass.resume(musicPlayChannel)
					return
				end

				musicPlayChannel = bass.play(musicStreamHandle, {loop = false, onComplete = onAudioComplete})
			end
		end
	}
)
playButton.x = (stopButton.x + stopButton.contentWidth + controlButtonsXOffset)
playButton.y = previousButton.y

local pauseButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "pause-button.png",
		overFile = overButtonPath .. "pause-button.png",
		width = 30,
		height = 30,
		onPress = function(event)
			if (musicStreamHandle) then
				if (bass.isChannelPlaying(musicPlayChannel)) then
					bass.pause(musicPlayChannel)
				end
			end
		end
	}
)
pauseButton.x = (playButton.x + playButton.contentWidth + controlButtonsXOffset)
pauseButton.y = previousButton.y

local nextButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "next-button.png",
		overFile = overButtonPath .. "next-button.png",
		width = 30,
		height = 30,
		onPress = function(event)
			if (currentSongIndex + 1 <= #musicFiles) then
				currentSongIndex = currentSongIndex + 1

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end
	}
)
nextButton.x = (pauseButton.x + pauseButton.contentWidth + controlButtonsXOffset)
nextButton.y = previousButton.y

local loopButton =
	widget.newSwitch(
	{
		style = "checkbox",
		id = "loop",
		onPress = function(event)
			bass.update(musicStreamHandle, {loop = event.target.isOn})
		end
	}
)
loopButton.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset)
loopButton.y = previousButton.y

local volumeSlider =
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
volumeSlider.x = (loopButton.x + (loopButton.contentWidth * 0.5) + 20)
volumeSlider.y = previousButton.y - 5

songProgressView =
	widget.newProgressView(
	{
		width = 100,
		isAnimated = true
	}
)
songProgressView.x = (volumeSlider.x + volumeSlider.contentWidth + songProgressView.contentWidth)
songProgressView.y = previousButton.y

function songProgressView:touch(event)
	local phase = event.phase

	if (phase == "began") then
		local valueX, valueY = self:contentToLocal(event.x, event.y)
		--local duration = (musicDuration / 1000)
		local duration = musicDuration
		local seekPosition = ((valueX / 10) * musicDuration / 10)
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

local addMusicButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "add-button.png",
		overFile = overButtonPath .. "add-button.png",
		width = 30,
		height = 30,
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
addMusicButton.x = (songProgressView.x + songProgressView.contentWidth + addMusicButton.contentWidth)
addMusicButton.y = previousButton.y

musicTableView =
	widget.newTableView(
	{
		left = 0,
		top = 80,
		width = dWidth,
		height = dHeight - 80,
		isLocked = true,
		noLines = true,
		rowTouchDelay = 0,
		backgroundColor = {0.18, 0.18, 0.18},
		onRowRender = function(event)
			local phase = event.phase
			local row = event.row
			local rowContentHeight = row.contentHeight
			local params = row.params

			if (row.isCategory) then
				local titleText =
					display.newText(
					{
						text = "Title",
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						align = "left"
					}
				)
				titleText.anchorX = 0
				titleText.x = 25
				row:insert(titleText)

				local albumText =
					display.newText(
					{
						text = "Album",
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						align = "left"
					}
				)
				albumText.anchorX = 0
				albumText.x = titleText.x + titleText.contentWidth + albumText.contentWidth + 380
				row:insert(albumText)

				local artistText =
					display.newText(
					{
						text = "Artist",
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						align = "left"
					}
				)
				artistText.anchorX = 0
				artistText.x = albumText.x + albumText.contentWidth + artistText.contentWidth + 200
				row:insert(artistText)
			else
				local tags = musicFiles[row.index - 1].tags
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

				local songTitleText =
					display.newText(
					{
						text = tags.title,
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						width = row.contentWidth * 0.5 - 10,
						align = "left"
					}
				)
				songTitleText.anchorX = 0
				songTitleText.x = 25
				row:insert(songTitleText)

				local songAlbumText =
					display.newText(
					{
						text = tags.album,
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						width = row.contentWidth * 0.25,
						align = "left"
					}
				)
				songAlbumText.anchorX = 0
				songAlbumText.x = songTitleText.x + songTitleText.contentWidth + 10
				row:insert(songAlbumText)

				local songArtistText =
					display.newText(
					{
						text = tags.artist,
						x = 0,
						y = (rowContentHeight * 0.5),
						fontSize = rowFontSize,
						width = row.contentWidth * 0.25,
						align = "left"
					}
				)
				songArtistText.anchorX = 0
				songArtistText.x = songAlbumText.x + songAlbumText.contentWidth + 10
				row:insert(songArtistText)
			end
		end,
		onRowTouch = function(event)
			local phase = event.phase
			local row = event.row
			local params = row.params

			if (phase == "press") then
				currentSongIndex = row.index - 1
				cleanupAudio()
				playAudio(currentSongIndex)
			end
		end,
		listener = function(event)
		end
	}
)

function musicTableView:highlightPressedIndex(pressedIndex)
	if (pressedIndex) then
		for i = 2, musicTableView:getNumRows() do
			local view = musicTableView._view._rows[i]._view

			if (view) then
				view._cell:setFillColor(unpack(rowColors[i].default))
			end
		end

		if (musicTableView._view._rows[pressedIndex + 1]._view) then
			musicTableView._view._rows[pressedIndex + 1]._view._cell:setFillColor(0, 0, 0, 0)
		end
	end
end

local leftChannel = {}
local rightChannel = {}
local levelVisualizationGroup = display.newGroup()

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

levelVisualizationGroup.x = addMusicButton.x
levelVisualizationGroup.y = addMusicButton.y + addMusicButton.contentHeight * 0.5 - 5

timer.performWithDelay(
	10,
	function()
		if (currentSongIndex > 0 and currentSongIndex <= musicTableView:getNumRows()) then
			musicTableView:highlightPressedIndex(currentSongIndex)
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
			local playbackTime = bass.getPlaybackTime(musicPlayChannel)
			local pbElapsed = playbackTime.elapsed
			local pbDuration = playbackTime.duration

			--print(sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds))
			--print(musicDuration, duration, prog / duration)

			songProgressView:setProgress(songProgess / duration)
		end
	end,
	0
)

if (type(settings) == "table" and settings.musicPath) then
	print("gathering music")
	gatherMusic(settings.musicPath)
end

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
					bass.resume(musicPlayChannel)
				else
					if (bass.isChannelPlaying(musicPlayChannel)) then
						bass.pause(musicPlayChannel)
					end
				end
			end
		elseif (keyCode == 65542) then
			-- next
			if (currentSongIndex + 1 <= #musicFiles) then
				currentSongIndex = currentSongIndex + 1

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		elseif (keyCode == 65541) then
			-- previous
			if (currentSongIndex - 1 > 0) then
				currentSongIndex = currentSongIndex - 1

				cleanupAudio()
				playAudio(currentSongIndex)
			end
		elseif (keyCode == 65540) then
			-- stop
			statusText:setSongName("Nothing", "Nobody")
			cleanupAudio()
		end
	end

	return false
end

bass.setVolume(1.0)
Runtime:addEventListener("key", keyEventListener)
