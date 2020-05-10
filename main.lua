-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local widget = require("widget")
local tfd = require("plugin.tinyfiledialogs")
local strict = require("strict")
local stringExt = require("libs.string-ext")
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
local random = math.random
local wasSongPlaying = false
local interruptedSongPosition = {}
local lastChosenPath = nil
local musicFiles = {}
local mediaBar = nil
local musicTableView = nil
local background = nil
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
widget.setTheme("widget_theme_ios")
math.randomseed(os.time())

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
		musicVisualizer.start()
	elseif (phase == "ended") then
		--print("song ENDED")
		audioLib.currentSongIndex = mMin(audioLib.currentSongIndex + 1, musicList:getMusicCount())

		-- handle shuffle
		if (audioLib.shuffle) then
			audioLib.currentSongIndex = random(1, musicList:getMusicCount())
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
		audioLib.load(nextSong)
		audioLib.play(nextSong)
		musicVisualizer.start()
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
		settings.item.musicFolderPaths[#settings.item.musicFolderPaths + 1] = lastChosenPath
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
							local previousPaths = settings.item.musicFolderPaths
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
							print("add file")
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
						iconName = "tags"
					},
					{
						title = "Edit Playlist",
						iconName = "list-music"
					},
					{
						title = "Preferences",
						iconName = "tools"
					}
				}
			},
			{
				title = "Music",
				subItems = {
					{
						title = "Fade In Track",
						iconName = "turntable",
						useCheckmark = true
					},
					{
						title = "Fade Out Track",
						iconName = "turntable",
						useCheckmark = true
					}
				}
			},
			{
				title = "View",
				subItems = {
					{
						title = "Show Visualizer",
						iconName = "eye",
						useCheckmark = true
					}
				}
			},
			{
				title = "Help",
				subItems = {
					{
						title = "Report Bug",
						iconName = "bug"
					},
					{
						title = "Submit Feature Request",
						iconName = "inbox-out"
					},
					{
						title = "Visit Website",
						iconName = "browser"
					},
					{
						title = "About",
						iconName = "info-circle"
					}
				}
			}
		}
	}
)

background = display.newRect(0, 0, display.contentWidth, display.contentHeight)
background.anchorY = 0
background.x = display.contentCenterX
background.y = 100
background:setFillColor(0.10, 0.10, 0.10, 1)
mediaBar = mediaBarLib.new({})
musicTableView = musicList.new()
background:toFront()
musicImporter.pushProgessToFront()
settings:load()

local function keyEventListener(event)
	local phase = event.phase

	if (phase == "down") then
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
			elseif (keyDescriptor == "pagedown") then
				musicList:scrollToBottom()
			elseif (keyDescriptor == "pageup") then
				musicList:scrollToTop()
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
		audioLib.reset()
		transition.cancel()

		for id, value in pairs(timer._runlist) do
			timer.cancel(value)
		end
	end
end

Runtime:addEventListener("system", onSystemEvent)

populateTableViews()
