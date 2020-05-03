-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local lfs = require("lfs")
local widget = require("widget")
local json = require("json")
local crypto = require("crypto")
local tfd = require("plugin.tinyfiledialogs")
local mousecursor = require("plugin.mousecursor")
local strict = require("strict")
local fileUtils = require("libs.file-utils")
local audioLib = require("libs.audio-lib")
local musicBrainz = require("libs.music-brainz")
local stringExt = require("libs.string-ext")
local mainMenuBar = require("libs.ui.main-menu-bar")
local progressView = require("libs.ui.progress-view")
local levelVisualization = require("libs.ui.level-visualizer")
local musicList = require("libs.ui.music-list")
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
local settings = fileUtils:loadTable(settingsFileName)
local musicFiles = {}
local musicDuration = 0
local controlButtonsXOffset = 10
local documentsDirectoryPath = system.pathForFile("", system.DocumentsDirectory)
local songTitleText = nil
local songAlbumText = nil
local songProgressView = nil
local playbutton = nil
local pauseButton = nil
local volumeOnButton = nil
local volumeOffButton = nil
local volumeSlider = nil
local playBackTimeText = nil
local albumArtwork = nil
local updateAlbumArtworkPosition = nil
local musicTableView = nil
local buttonSize = 20
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local resizeCursor = mousecursor.newCursor("resize left right")
widget.setTheme("widget_theme_ios")

local function isMusicFile(fileName)
	local fileExtension = fileName:match("^.+(%..+)$")
	local isMusic = false

	for i = 1, #audioLib.supportedFormats do
		local currentFormat = audioLib.supportedFormats[i]

		if (fileExtension == sFormat(".%s", currentFormat)) then
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
			audioLib.load({fileName = filename, filePath = musicPath})
			local tags = audioLib.getTags()

			if (tags) then
				local playbackDuration = audioLib.getPlaybackTime().duration
				musicFiles[#musicFiles + 1] = {fileName = filename, filePath = musicPath, tags = tags}
				musicFiles[#musicFiles].tags.duration = sFormat("%02d:%02d", playbackDuration.minutes, playbackDuration.seconds)
				playbackDuration = nil
				audioLib.dispose()
			end
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

		musicList.populate(musicFiles)
	else
		native.showAlert("No Music Found", "I didn't find any music in the selected folder path", {"OK"})
	end
end

local function resetSongProgress()
	playBackTimeText.text = "00:00/00:00"
	songProgressView:setElapsedProgress(0)
	songProgressView:setOverallProgress(0)
end

local function onAudioEvent(event)
	local phase = event.phase

	if (phase == "started") then
		if (albumArtwork) then
			display.remove(albumArtwork)
			albumArtwork = nil
		end

		playButton.isVisible = false
		pauseButton.isVisible = true
		musicDuration = audioLib.getDuration() * 1000
		resetSongProgress()
		playBackTimeText:update()
		songTitleText:setText(musicFiles[audioLib.currentSongIndex].tags.title)
		songAlbumText:setText(musicFiles[audioLib.currentSongIndex].tags.album)
		musicBrainz.getCover(musicFiles[audioLib.currentSongIndex])
	elseif (phase == "ended") then
		audioLib.currentSongIndex = audioLib.currentSongIndex + 1

		playBackTimeText:update()
		resetSongProgress()
		audioLib.load(musicFiles[audioLib.currentSongIndex])
		audioLib.play(musicFiles[audioLib.currentSongIndex])
	end

	return true
end

Runtime:addEventListener("bass", onAudioEvent)

local function onMusicBrainzDownloadComplete(event)
	local phase = event.phase
	local coverFileName = event.fileName

	if (phase == "downloaded") then
		if (albumArtwork) then
			display.remove(albumArtwork)
			albumArtwork = nil
		end

		albumArtwork = display.newImageRect(coverFileName, system.DocumentsDirectory, 30, 30)
		albumArtwork.anchorX = 0
		updateAlbumArtworkPosition()
	end

	return true
end

Runtime:addEventListener("musicBrainz", onMusicBrainzDownloadComplete)

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
							local selectedPath = tfd.selectFolderDialog({title = "Select Music Folder"})

							if (selectedPath ~= nil) then
								if (type(settings) ~= "table") then
									settings = {}
								end

								for i = 1, #musicTableView do
									musicTableView[i]:deleteAllRows()
								end

								settings.musicPath = selectedPath
								fileUtils:saveTable(settings, settingsFileName)
								gatherMusic(settings.musicPath)
							end
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
							native.requestExit()
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
			if (audioLib.currentSongIndex - 1 > 0) then
				audioLib.currentSongIndex = audioLib.currentSongIndex - 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				audioLib.load(musicFiles[audioLib.currentSongIndex])
				audioLib.play(musicFiles[audioLib.currentSongIndex])
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
			if (audioLib.isChannelHandleValid()) then
				event.target.isVisible = false
				pauseButton.isVisible = true

				if (audioLib.isChannelPlaying()) then
					return
				end

				if (audioLib.isChannelPaused()) then
					audioLib.resume()
					return
				end
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
			if (audioLib.isChannelHandleValid()) then
				if (audioLib.isChannelPlaying()) then
					audioLib.pause()
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
			if (audioLib.currentSongIndex + 1 <= #musicFiles) then
				audioLib.currentSongIndex = audioLib.currentSongIndex + 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				audioLib.load(musicFiles[audioLib.currentSongIndex])
				audioLib.play(musicFiles[audioLib.currentSongIndex])
			end
		end
	}
)
nextButton.x = (pauseButton.x + pauseButton.contentWidth + controlButtonsXOffset)
nextButton.y = previousButton.y

local emitterParams = fileUtils:loadTable("my_galaxy.json", system.ResourceDirectory)
local emitter = display.newEmitter(emitterParams)
emitter.x = display.contentCenterX
emitter.y = nextButton.y - 5

local songContainerBox = display.newRoundedRect(0, 0, dWidth / 2 - 8, 50, 2)
songContainerBox.anchorX = 0
songContainerBox.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset + 29)
songContainerBox.y = nextButton.y - 5
songContainerBox.strokeWidth = 1
songContainerBox:setFillColor(0, 0, 0, 1)
songContainerBox:setStrokeColor(0.6, 0.6, 0.6, 0.5)

local songContainer = display.newContainer(songContainerBox.contentWidth - 80, 50)
songContainer.anchorX = 0
songContainer.x = songContainerBox.x + 46
songContainer.y = songContainerBox.y - 10

updateAlbumArtworkPosition = function()
	if (albumArtwork ~= nil) then
		albumArtwork.x = songContainerBox.x + 5
		albumArtwork.y = songContainerBox.y - 2.5
	end
end

songTitleText =
	display.newText(
	{
		text = "",
		font = titleFont,
		align = "center",
		fontSize = 15
	}
)
songTitleText.anchorX = 0
songTitleText.x = -(songTitleText.contentWidth * 0.5)
songTitleText.scrollTimer = nil
songTitleText:setFillColor(0.9, 0.9, 0.9)
songContainer:insert(songTitleText)

function songTitleText:enterFrame()
	if (songTitleText and songTitleText.contentWidth > songContainer.contentWidth) then
		songTitleText.x = songTitleText.x - 1

		if (songTitleText.x + songTitleText.contentWidth < -songTitleText.contentWidth * 0.4) then
			songTitleText.x = songContainer.x + songContainer.contentWidth * 0.25
		end
	end

	if (songAlbumText and songAlbumText.contentWidth > songContainer.contentWidth) then
		songAlbumText.x = songAlbumText.x - 1

		if (songAlbumText.x + songAlbumText.contentWidth < -songAlbumText.contentWidth * 0.4) then
			songAlbumText.x = songContainer.x + songContainer.contentWidth * 0.25
		end
	end
end

function songTitleText:setText(title)
	self.text = title

	if (self.contentWidth > songContainer.contentWidth) then
		self.x = -(self.contentWidth * 0.40)
	else
		self.x = -(self.contentWidth * 0.5)
	end

	Runtime:removeEventListener("enterFrame", songTitleText)

	if (self.scrollTimer) then
		timer.cancel(self.scrollTimer)
		self.scrollTimer = nil
	end

	if (self.contentWidth > songContainer.contentWidth) then
		self.scrollTimer =
			timer.performWithDelay(
			3000,
			function()
				Runtime:addEventListener("enterFrame", songTitleText)
			end
		)
	end
end

songAlbumText =
	display.newText(
	{
		text = "",
		font = subTitleFont,
		align = "center",
		fontSize = 12
	}
)
songAlbumText.anchorX = 0
songAlbumText.x = -(songAlbumText.contentWidth * 0.5)
songAlbumText.y = songTitleText.contentHeight
songAlbumText:setFillColor(0.6, 0.6, 0.6)
songContainer:insert(songAlbumText)
function songAlbumText:setText(album)
	self.text = album

	if (self.contentWidth > songContainer.contentWidth) then
		self.x = -(self.contentWidth * 0.40)
	else
		self.x = -(self.contentWidth * 0.5)
	end
end

local loopButton =
	widget.newSwitch(
	{
		style = "checkbox",
		id = "loop",
		onPress = function(event)
			audioLib.loopOne = event.target.isOn
		end
	}
)
loopButton.width = buttonSize
loopButton.height = buttonSize
loopButton.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset)
loopButton.y = previousButton.y
loopButton._viewOff:setFillColor(0.7, 0.7, 0.7)

songProgressView =
	progressView.new(
	{
		width = dWidth / 2 - 10,
		musicDuration = musicDuration,
		musicStreamHandle = audioLib.getChannelHandle()
	}
)
songProgressView.anchorX = 0
songProgressView.x = songContainerBox.x + 2
songProgressView.y = songContainerBox.y + songAlbumText.contentHeight + songProgressView.contentHeight + 1

volumeOnButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "volume-button.png",
		overFile = overButtonPath .. "volume-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			audioLib.setVolume(0)
			volumeSlider:setValue(0)
			event.target.isVisible = false
			volumeOffButton.isVisible = true
		end
	}
)
volumeOnButton.x = (songProgressView.x + songProgressView.actualWidth + controlButtonsXOffset + 20)
volumeOnButton.y = previousButton.y

volumeOffButton =
	widget.newButton(
	{
		defaultFile = defaultButtonPath .. "volume-off-button.png",
		overFile = overButtonPath .. "volume-off-button.png",
		width = buttonSize,
		height = buttonSize,
		onPress = function(event)
			audioLib.setVolume(audioLib.getPreviousVolume())
			volumeSlider:setValue(audioLib.getVolume() * 100)
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
			audioLib.setVolume(event.value / 100)
		end
	}
)
volumeSlider.height = volumeSlider.height / 1.5
volumeSlider.x = (volumeOnButton.x + (volumeOnButton.contentWidth) + 2)
volumeSlider.y = previousButton.y - 4

local levelVisualizer = levelVisualization.new()
levelVisualizer.x = volumeSlider.x + volumeSlider.contentWidth * 0.5 + 15
levelVisualizer.y = volumeOnButton.y
display.getCurrentStage():insert(levelVisualizer)

playBackTimeText =
	display.newText(
	{
		text = "00:00/00:00",
		font = titleFont,
		fontSize = 10,
		align = "left"
	}
)
playBackTimeText.x = levelVisualizer.x + levelVisualizer.contentWidth
playBackTimeText.y = levelVisualizer.y + levelVisualizer.contentHeight + playBackTimeText.contentHeight
function playBackTimeText:update()
	local playbackTime = audioLib.getPlaybackTime()
	local pbElapsed = playbackTime.elapsed
	local pbDuration = playbackTime.duration
	playBackTimeText.text =
		sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds)
end

musicTableView = musicList.new()

timer.performWithDelay(
	10,
	function()
		if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
			local leftLevel, rightLevel = audioLib.getLevel()
			local minLevel = 0
			local maxLevel = 32768
			local chunk = 2520

			emitter.radialAcceleration = (leftLevel / 1000) * (rightLevel / 1000)
			emitter.startParticleSize = 1
			emitter.finishParticleSizeVariance = emitter.startParticleSize
			emitter.startColorAlpha = 0
			emitter.finishColorAlpha = 1
		--emitter.startColorRed = 1
		--emitter.startColorBlue = 1
		--emitter.startColorGreen = 1
		--emitter.startColorVarianceAlpha = (leftLevel / 100000 * 2)
		--emitter.startColorVarianceRed = (leftLevel / 100000 * 3)
		--emitter.startColorVarianceBlue = (leftLevel / 100000 * 3)
		--emitter.startColorVarianceGreen = (leftLevel / 100000 * 3)
		--emitter.gravityx = leftLevel / 100
		--emitter.gravityy = leftLevel / 100
		--emitter.sourcePositionVariancex = leftLevel / 200
		--emitter.sourcePositionVariancey = -(leftLevel / 200)
		--emitter.speedVariance = leftLevel / 50
		--emitter.startParticleSize = leftLevel / 3200
		--emitter.radialAccelVariance = leftLevel / 300
		end
	end,
	0
)

timer.performWithDelay(
	1000,
	function()
		if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
			playBackTimeText:update()
			songProgressView:updateHandles(musicDuration, audioLib.getChannelHandle())
			songProgressView:setElapsedProgress(songProgressView:getElapsedProgress() + 1)
			songProgressView:setOverallProgress(songProgressView:getElapsedProgress() / musicDuration)
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
			if (audioLib.isChannelHandleValid()) then
				if (audioLib.isChannelPaused()) then
					playButton.isVisible = false
					pauseButton.isVisible = true

					audioLib.resume()
				else
					if (audioLib.isChannelPlaying()) then
						playButton.isVisible = true
						pauseButton.isVisible = false

						audioLib.pause()
					end
				end
			end
		elseif (keyCode == 65542) then
			-- next
			if (audioLib.currentSongIndex + 1 <= #musicFiles) then
				audioLib.currentSongIndex = audioLib.currentSongIndex + 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				audioLib.play(musicFiles[audioLib.currentSongIndex])
			end
		elseif (keyCode == 65541) then
			-- previous
			if (audioLib.currentSongIndex - 1 > 0) then
				audioLib.currentSongIndex = audioLib.currentSongIndex - 1
				playButton.isVisible = false
				pauseButton.isVisible = true

				audioLib.play(musicFiles[audioLib.currentSongIndex])
			end
		end
	end

	return false
end

audioLib.setVolume(1.0)
display.getCurrentStage():insert(applicationMainMenuBar)
Runtime:addEventListener("key", keyEventListener)

local function onSystemEvent(event)
	if (event.type == "applicationExit") then
		audioLib.stop()
		audioLib.dispose()
	end
end

Runtime:addEventListener("system", onSystemEvent)
