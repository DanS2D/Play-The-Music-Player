-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local lfs = require("lfs")
local widget = require("widget")
local tfd = require("plugin.tinyfiledialogs")
local strict = require("strict")
local stringExt = require("libs.string-ext")
local fileUtils = require("libs.file-utils")
local audioLib = require("libs.audio-lib")
local musicBrainz = require("libs.music-brainz")
local musicImporter = require("libs.music-importer")
local mainMenuBar = require("libs.ui.main-menu-bar")
local mediaBarLib = require("libs.ui.media-bar")
local musicList = require("libs.ui.music-list")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local settingsFileName = "settings.json"
local settings = fileUtils:loadTable(settingsFileName)
local musicFiles = {}
local mediaBar = nil
local musicTableView = nil
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
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

	if (path) then
		musicImporter.getFolderList(path)
	end

	if (foundMusic) then
		print("found music")

		musicList.populate(musicFiles)
		mediaBarLib.setMusicData(musicFiles)
	else
		--native.showAlert("No Music Found", "I didn't find any music in the selected folder path", {"OK"})
	end
end

local function onAudioEvent(event)
	local phase = event.phase

	if (phase == "started") then
		mediaBarLib.updatePlayPauseState(true)
		mediaBarLib.removeAlbumArtwork()
		mediaBarLib.updatePlaybackTime()
		mediaBarLib.resetSongProgress()
		mediaBarLib.updateSongText()
		musicBrainz.getCover(musicFiles[audioLib.currentSongIndex])
	elseif (phase == "ended") then
		audioLib.currentSongIndex = audioLib.currentSongIndex + 1

		mediaBarLib.updatePlaybackTime()
		mediaBarLib.resetSongProgress()
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
		mediaBarLib.setAlbumArtwork(coverFileName)
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

mediaBar = mediaBarLib.new({})
musicTableView = musicList.new()
musicImporter.pushProgessToFront()

if (type(settings) == "table" and settings.musicPath) then
	print("gathering music")
	gatherMusic(settings.musicPath)
end

local function keyEventListener(event)
	local phase = event.phase

	if (phase == "down") then
		local keyDescriptor = event.descriptor:lower()

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
		audioLib.stop()
		audioLib.dispose()
	end
end

Runtime:addEventListener("system", onSystemEvent)
