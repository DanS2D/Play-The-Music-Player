-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local strict = require("strict")
local stringExt = require("libs.string-ext")
local luaExt = require("libs.lua-ext")
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local musicBrainz = require("libs.music-brainz")
local settings = require("libs.settings")
local musicImporter = require("libs.music-importer")
local fileUtils = require("libs.file-utils")
local musicVisualizer = require("libs.ui.music-visualizer")
local mainMenuBar = require("libs.ui.main-menu-bar")
local mediaBarLib = require("libs.ui.media-bar")
local musicList = require("libs.ui.music-list")
local alertPopupLib = require("libs.ui.alert-popup")
local aboutPopupLib = require("libs.ui.about-popup")
local alertPopup = alertPopupLib.create()
local aboutPopup = aboutPopupLib.create()
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
local oldWidth = display.contentWidth
local oldHeight = display.contentHeight
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.otf"
mRandomSeed(osTime())
display.setDefault("background", 0.1, 0.1, 0.1, 0.8)
settings:load()

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
		audioLib.previousSongIndex = currentSongIndex
		audioLib.currentSongIndex = audioLib.currentSongIndex + 1

		-- handle shuffle
		if (audioLib.shuffle) then
			repeat
				audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
			until audioLib.currentSongIndex ~= currentSongIndex
		else
			-- stop audio after last index, or reset the index depending on loop mode
			if (audioLib.currentSongIndex > musicList:getMusicCount()) then
				if (audioLib.loopAll) then
					audioLib.currentSongIndex = 1
				else
					mediaBarLib.resetSongProgress()
					mediaBarLib.clearPlayingSong()
					musicVisualizer:remove()
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
	if (sqlLib:currentMusicCount() > 0) then
		mainMenuBar.setEnabled(true)

		if (lastChosenPath ~= nil) then
			settings.musicFolderPaths[#settings.musicFolderPaths + 1] = lastChosenPath
			settings:save()
		end

		musicImporter.pushProgessToFront()
		musicImporter.showProgressBar()

		if (musicList:getTableViewListCount() <= 0) then
			musicTableView = musicList.new()
		end

		musicList:populate() --################################################ << CPU HOG ########################################################################
	--playInterruptedSong() <-- plays the wrong song if the user was playing via search. Fix this later. Kinda complicated
	end
end

local applicationMainMenuBar =
	mainMenuBar.new(
	{
		font = subTitleFont,
		items = {
			{
				title = "File",
				font = subTitleFont,
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
							local selectedPath = musicImporter.showFolderSelectDialog()
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
								else
									lastChosenPath = nil
								end

								background:toFront()
								musicList:removeAllRows()
								musicImporter.pushProgessToFront()
								musicImporter.showProgressBar()
								musicImporter.getFolderList(lastChosenPath, populateTableViews)
							else
								mainMenuBar.setEnabled(true)
								playInterruptedSong()
							end
						end
					},
					{
						title = "Add Music File(s)",
						iconName = "file-music",
						onClick = function()
							local function onComplete()
								musicList:removeAllRows()
								musicImporter.pushProgessToFront()
								musicImporter.showProgressBar()
								populateTableViews()
							end

							musicImporter.showFileSelectDialog(onComplete)
						end
					},
					{
						title = "Delete Music Library",
						iconName = "trash",
						onClick = function()
							local function onRemoved()
								local databasePath = system.pathForFile("", system.DocumentsDirectory)
								sqlLib:close()
								audioLib:reset()
								musicList:destroy()
								fileUtils:removeFile("music.db", databasePath)

								timer.performWithDelay(
									100,
									function()
										print(#settings.musicFolderPaths)
										settings.musicFolderPaths = {}
										print(#settings.musicFolderPaths)
										settings:load()
										mediaBarLib.resetSongProgress()
										mediaBarLib.clearPlayingSong()
										musicImporter.updateHeading("Welcome To Play!")
										musicImporter.updateSubHeading("To get started, click `file > add music folder` to import your music")
										musicImporter.hideProgressBar()
										musicImporter.pushProgessToFront()
										musicImporter.showProgress()
									end
								)
							end

							alertPopup:setTitle("Really delete your music Library?")
							alertPopup:setMessage(
								"This action cannot be reversed.\nYour library (database only) will be removed and cannot be recovered. Your music files will not be touched.\n\nAre you sure you wish to proceed?"
							)
							alertPopup:setButtonCallbacks({onConfirm = onRemoved})
							alertPopup:show()
						end
					},
					{
						title = "Exit",
						iconName = "power-off",
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
						title = "Preferences",
						iconName = "tools",
						onClick = function(event)
						end
					},
					{
						title = "Scan For New Media",
						iconName = "sync",
						onClick = function(event)
						end
					},
					{
						title = "Scan For Removed Media",
						iconName = "sync",
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
						title = "Light Theme",
						iconName = "palette",
						onClick = function(event)
							--settings:save()
						end
					},
					{
						title = "Dark Theme",
						iconName = "palette",
						onClick = function(event)
							--settings:save()
						end
					}
				}
			},
			--[[
			{
				title = "Visualizer",
				subItems = {
					{
						title = "Enabled",
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
					},
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
			},--]]
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
							aboutPopup:show()
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

local function onResize(event)
	if (alertPopupLib:isOpen()) then
		native.setProperty("windowSize", {width = oldWidth, height = oldHeight})
		return
	end

	background.width = display.contentWidth
	background.height = display.contentHeight - 161

	applicationMainMenuBar:onResize()
	mediaBarLib:onResize()
	musicImporter:onResize()
	musicList:onResize()

	if (sqlLib:currentMusicCount() > 0) then
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

	oldWidth = display.contentWidth
	oldHeight = display.contentHeight
end

Runtime:addEventListener("resize", onResize)

local function onSystemEvent(event)
	if (event.type == "applicationExit") then
		sqlLib:close()
		audioLib.reset()
		transition.cancel()
		Runtime:removeEventListener("key", keyEventListener)
		Runtime:removeEventListener("resize", onResize)

		for id, value in pairs(timer._runlist) do
			timer.cancel(value)
		end
	end
end

Runtime:addEventListener("system", onSystemEvent)

mediaBarLib.setVolumeSliderValue(settings.volume * 100)
audioLib.setVolume(settings.volume)
populateTableViews() --################################################ << CPU HOG ########################################################################
