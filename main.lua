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
local wasSongPlaying = false
local interruptedSongPosition = {}
local musicFiles = {}
local mediaBar = nil
local musicTableView = nil
local background = nil
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
widget.setTheme("widget_theme_ios")

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
		mediaBarLib.updatePlayPauseState(true)
		mediaBarLib.removeAlbumArtwork()
		mediaBarLib.updatePlaybackTime()
		mediaBarLib.resetSongProgress()
		mediaBarLib.updateSongText(song)
		musicBrainz.getCover(song)
		musicVisualizer.start()
	elseif (phase == "ended") then
		audioLib.currentSongIndex = audioLib.currentSongIndex + 1
		local nextSong = musicList.musicFunction(audioLib.currentSongIndex, musicList.musicSortAToZ)

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
		local previousSong = musicList.musicFunction(audioLib.currentSongIndex, musicList.musicSortAToZ)
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
	if (sqlLib.musicCount() > 0) then
		musicImporter.pushProgessToFront()
		musicImporter.showProgressBar()
		musicList.populate()
		playInterruptedSong()
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
						onClick = function()
							wasSongPlaying = audioLib.isChannelPlaying()
							interruptedSongPosition = mediaBarLib.getSongProgress()
							audioLib.reset()
							musicVisualizer.pause()
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
									previousPaths[#previousPaths + 1] = selectedPath
									settings.item.musicFolderPaths[#settings.item.musicFolderPaths + 1] = selectedPath
									settings.save()

									for i = 1, #musicList.rowCreationTimers do
										if (musicList.rowCreationTimers[i] ~= nil) then
											timer.cancel(musicList.rowCreationTimers[i])
										end

										table.remove(musicList.rowCreationTimers, i)
									end

									for i = 1, #musicTableView do
										musicTableView[i]:deleteAllRows()
									end

									background:toFront()
									musicImporter.pushProgessToFront()
									musicImporter.showProgressBar()
									musicImporter.getFolderList(selectedPath, populateTableViews)
								else
									playInterruptedSong()
								end
							else
								playInterruptedSong()
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

background = display.newRect(0, 0, display.contentWidth, display.contentHeight)
background.anchorY = 0
background.x = display.contentCenterX
background.y = 100
background:setFillColor(0.10, 0.10, 0.10, 1)
mediaBar = mediaBarLib.new({})
musicTableView = musicList.new()
background:toFront()
musicImporter.pushProgessToFront()
settings.load()

local function keyEventListener(event)
	local phase = event.phase

	if (phase == "down") then
		local keyDescriptor = event.descriptor:lower()
		-- TODO: only execute the below IF there is music data

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
