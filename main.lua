-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local tfd = require("plugin.tinyfiledialogs")
local strict = require("strict")
local stringExt = require("libs.string-ext")
local luaExt = require("libs.lua-ext")
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local musicBrainz = require("libs.music-brainz")
local settings = require("libs.settings")
local musicImporter = require("libs.music-importer")
local musicVisualizer = require("libs.ui.music-visualizer")
local mainMenuBar = require("libs.ui.main-menu-bar")
local mediaBarLib = require("libs.ui.media-bar")
local musicList = require("libs.ui.music-list")
local sFormat = string.format
local mMin = math.min
local mRandom = math.random
local mRandomSeed = math.randomseed
local osTime = os.time
local wasSongPlaying = false
local interruptedSongPosition = {}
local lastChosenPath = nil
local musicFiles = {}
local mediaBar = nil
local musicTableView = nil
local background = nil
local resizeTimer = nil
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.otf"
mRandomSeed(osTime())
settings:load()

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
local function onAudioEvent(event)
	local phase = event.phase
	local song = event.song

	if (phase == "started") then
		--print("song STARTED")
		mediaBarLib.updatePlayPauseState(true)
		mediaBarLib.removeAlbumArtwork()
		mediaBarLib.updatePlaybackTime()
		mediaBarLib.resetSongProgress()
		mediaBarLib.updateSongText(song)
		musicBrainz.getCover(song)
		musicVisualizer:start()
	elseif (phase == "ended") then
		local currentSongIndex = audioLib.currentSongIndex
		mRandomSeed(osTime())
		audioLib.currentSongIndex = mMin(audioLib.currentSongIndex + 1, musicList:getMusicCount())

		-- handle shuffle
		if (audioLib.shuffle) then
			repeat
				audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
			until audioLib.currentSongIndex ~= currentSongIndex
		else
			-- stop audio after last index, or reset the index depending on loop mode
			if (audioLib.currentSongIndex == musicList:getMusicCount()) then
				if (audioLib.loopAll) then
					audioLib.currentSongIndex = 1
				else
					mediaBarLib.resetSongProgress()
					mediaBarLib.clearPlayingSong()
					audioLib.reset()
					musicList:setSelectedRow(0)
					return
				end
			end
		end

		local nextSong = musicList:getRow(audioLib.currentSongIndex)
		musicList:setSelectedRow(audioLib.currentSongIndex)
		mediaBarLib.updatePlaybackTime()
		mediaBarLib.resetSongProgress()
		musicVisualizer:restart()
		audioLib.load(nextSong)
		audioLib.play(nextSong)
	end

	return true
end

Runtime:addEventListener("bass", onAudioEvent)

local function playInterruptedSong()
	if (wasSongPlaying) then
		local previousSong = musicList:getRow(audioLib.currentSongIndex)
		audioLib.load(previousSong)
		audioLib.play(previousSong)

		local songPosition = interruptedSongPosition
		audioLib.seek(songPosition / 1000)
		mediaBarLib.setSongProgress(songPosition)
		wasSongPlaying = false
	end
end

local function onMusicBrainzDownloadComplete(event)
	local phase = event.phase
	local coverFileName = event.fileName

	if (phase == "downloaded") then
		mediaBarLib.setAlbumArtwork(coverFileName)
	end

	return true
end

Runtime:addEventListener("musicBrainz", onMusicBrainzDownloadComplete)

local function populateTableViews()
	if (sqlLib:musicCount() > 0) then
		mainMenuBar.setEnabled(true)
		settings.musicFolderPaths[#settings.musicFolderPaths + 1] = lastChosenPath
		settings:save()
		musicImporter.pushProgessToFront()
		musicImporter.showProgressBar()
		musicList:populate()
	--playInterruptedSong() <-- plays the wrong song if the user was playing via search. Fix this later. Kinda complicated
	end
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
						iconName = "folder-plus",
						onClick = function()
							wasSongPlaying = audioLib.isChannelPlaying()
							interruptedSongPosition = mediaBarLib.getSongProgress()
							audioLib.reset()
							musicVisualizer.pause()
							mainMenuBar.setEnabled(false)
							local selectedPath = tfd.selectFolderDialog({title = "Select Music Folder"})
							local previousPaths = settings.musicFolderPaths
							local hasUsedPath = false

							if (selectedPath ~= nil and type(selectedPath) == "string") then
								if (#previousPaths > 0) then
									for i = 1, #previousPaths do
										if (selectedPath == previousPaths[i]) then
											hasUsedPath = true
											break
										end
									end
								end

								if (not hasUsedPath) then
									lastChosenPath = selectedPath
									background:toFront()
									musicList:removeAllRows()
									musicImporter.pushProgessToFront()
									musicImporter.showProgressBar()
									musicImporter.getFolderList(lastChosenPath, populateTableViews)
								else
									mainMenuBar.setEnabled(true)
									playInterruptedSong()
								end
							else
								mainMenuBar.setEnabled(true)
								playInterruptedSong()
							end
						end
					},
					{
						title = "Add Music File",
						iconName = "file-music",
						onClick = function()
						end
					},
					{
						title = "Exit",
						iconName = "portal-exit",
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
						title = "Edit Metadata",
						iconName = "tags",
						onClick = function(event)
						end
					},
					{
						title = "Edit Playlist",
						iconName = "list-music",
						onClick = function(event)
						end
					},
					{
						title = "Preferences",
						iconName = "tools",
						onClick = function(event)
						end
					}
				}
			},
			{
				title = "Music",
				subItems = {
					{
						title = "Fade In Track",
						iconName = "turntable",
						useCheckmark = true,
						checkMarkIsOn = toboolean(settings.fadeInTrack),
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.fadeInTrack = true
								else
									settings.fadeInTrack = false
								end
							end

							settings:save()
						end
					},
					{
						title = "Fade Out Track",
						iconName = "turntable",
						useCheckmark = true,
						checkMarkIsOn = toboolean(settings.fadeOutTrack),
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.fadeOutTrack = true
								else
									settings.fadeOutTrack = false
								end
							end

							settings:save()
						end
					},
					{
						title = "Crossfade",
						iconName = "music",
						useCheckmark = true,
						checkMarkIsOn = toboolean(settings.crossFade),
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.crossFade = true
								else
									settings.crossFade = false
								end
							end

							settings:save()
						end
					}
				}
			},
			{
				title = "View",
				subItems = {
					{
						title = "Show Visualizer",
						iconName = "eye",
						useCheckmark = true,
						checkMarkIsOn = toboolean(settings.showVisualizer),
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.showVisualizer = true
								else
									settings.showVisualizer = false
								end
							end

							musicVisualizer:restart()
							settings:save()
						end
					}
				}
			},
			{
				title = "Visualizer",
				subItems = {
					{
						title = "Start",
						iconName = "play",
						onClick = function(event)
							musicVisualizer:start()
						end
					},
					{
						title = "Pause",
						iconName = "pause",
						onClick = function(event)
							musicVisualizer:pause()
						end
					},
					{
						title = "Stop",
						iconName = "stop",
						onClick = function(event)
							musicVisualizer:remove()
						end
					},
					{
						title = "Pixes",
						iconName = "dot-circle",
						useCheckmark = true,
						checkMarkIsOn = settings.selectedVisualizers.pixies.enabled,
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.selectedVisualizers.pixies.enabled = true
								else
									settings.selectedVisualizers.pixies.enabled = false
								end

								settings:save()
							end
						end
					},
					{
						title = "Fire Bar",
						iconName = "fire",
						useCheckmark = true,
						checkMarkIsOn = settings.selectedVisualizers.firebar.enabled,
						onClick = function(event)
							if (event.isSwitch) then
								if (event.isOn) then
									settings.selectedVisualizers.firebar.enabled = true
								else
									settings.selectedVisualizers.firebar.enabled = false
								end

								settings:save()
							end
						end
					}
				}
			},
			{
				title = "Help",
				subItems = {
					{
						title = "Support Me On Patreon",
						iconName = "patreon",
						font = fontAwesomeBrandsFont,
						onClick = function(event)
							system.openURL("https://www.patreon.com/dannyglover")
						end
					},
					{
						title = "Report Bug",
						iconName = "github",
						font = fontAwesomeBrandsFont,
						onClick = function(event)
							system.openURL("https://github.com/DannyGlover/Play-The-Music-Player")
						end
					},
					{
						title = "Submit Feature Request",
						iconName = "trello",
						font = fontAwesomeBrandsFont,
						onClick = function(event)
							system.openURL("https://trello.com/b/HdFlGXkR")
						end
					},
					{
						title = "Visit Website",
						iconName = "browser",
						onClick = function(event)
							system.openURL("https://playmusicplayer.net")
						end
					},
					{
						title = "About",
						iconName = "info-circle",
						onClick = function(event)
						end
					}
				}
			}
		}
	}
)

background = display.newRect(0, 0, display.contentWidth, display.contentHeight - 161)
background.anchorX = 0
background.anchorY = 0
background.x = 0
background.y = 161
background:setFillColor(0.10, 0.10, 0.10, 1)
mediaBar = mediaBarLib.new({})
musicTableView = musicList.new()
background:toFront()
musicImporter.pushProgessToFront()

local function keyEventListener(event)
	local phase = event.phase

	if (phase == "down") then
		--print(event.keyName)
		local isShiftDown = event.isShiftDown
		local keyDescriptor = event.descriptor:lower()
		-- TODO: only execute the below IF there is music data

		if (isShiftDown) then
		else
			-- pause/resume toggle
			if (keyDescriptor == "mediaplaypause") then
				if (audioLib.isChannelHandleValid()) then
					if (audioLib.isChannelPaused()) then
						mediaBarLib.updatePlayPauseState(true)
						audioLib.resume()
					else
						if (audioLib.isChannelPlaying()) then
							mediaBarLib.updatePlayPauseState(false)
							audioLib.pause()
						end
					end
				end
			elseif (keyDescriptor == "medianext") then
				-- next
				if (audioLib.currentSongIndex + 1 <= #musicFiles) then
					audioLib.currentSongIndex = audioLib.currentSongIndex + 1
					mediaBarLib.updatePlayPauseState(true)
					audioLib.load(musicFiles[audioLib.currentSongIndex])
					audioLib.play(musicFiles[audioLib.currentSongIndex])
				end
			elseif (keyDescriptor == "mediaprevious") then
				-- previous
				if (audioLib.currentSongIndex - 1 > 0) then
					audioLib.currentSongIndex = audioLib.currentSongIndex - 1
					mediaBarLib.updatePlayPauseState(true)
					audioLib.load(musicFiles[audioLib.currentSongIndex])
					audioLib.play(musicFiles[audioLib.currentSongIndex])
				end
			elseif (keyDescriptor == "mediastop") then
			-- stop audio
			end
		end
	end

	return false
end

display.getCurrentStage():insert(applicationMainMenuBar)
Runtime:addEventListener("key", keyEventListener)

local function onSystemEvent(event)
	if (event.type == "applicationExit") then
		audioLib.reset()
		transition.cancel()

		for id, value in pairs(timer._runlist) do
			timer.cancel(value)
		end
	end
end

Runtime:addEventListener("system", onSystemEvent)

local oldHeight = display.contentHeight

local function onResize(event)
	--print(display.contentWidth, display.contentHeight)
	background.width = display.contentWidth
	background.height = display.contentHeight - 161

	applicationMainMenuBar:onResize()
	mediaBarLib:onResize()
	musicList:onResize()

	if (display.contentHeight > oldHeight or display.contentHeight < oldHeight) then
		if (sqlLib:musicCount() > 0) then
			if (resizeTimer) then
				timer.cancel(resizeTimer)
				resizeTimer = nil
			end

			resizeTimer =
				timer.performWithDelay(
				500,
				function()
					musicList:recreateMusicList()
				end
			)
		end

		oldHeight = display.contentHeight
	end
end

Runtime:addEventListener("resize", onResize)

mediaBarLib.setVolumeSliderValue(settings.volume * 100)
audioLib.setVolume(settings.volume)
populateTableViews()
