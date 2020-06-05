-----------------------------------------------------------------------------------------
-- Copyright 2020 Danny Glover, all rights reserved
-----------------------------------------------------------------------------------------

local lfs = require("lfs")
local stringExt = require("libs.string-ext")
local luaExt = require("libs.lua-ext")
local sFormat = string.format

lfs.mkdir(system.pathForFile("data", system.DocumentsDirectory))
lfs.mkdir(system.pathForFile(sFormat("data%sthemes", string.pathSeparator), system.DocumentsDirectory))
lfs.mkdir(system.pathForFile(sFormat("data%salbumArt", string.pathSeparator), system.DocumentsDirectory))

local theme = require("libs.theme")
local settings = require("libs.settings")

settings:load()
theme:set(settings.theme)
theme:setDefaultBackgroundColor()
math.randomseed(os.time())

local tfd = require("plugin.tinyFileDialogs")
local directoryMonitor = require("plugin.directoryMonitor")
local tagLib = require("plugin.taglib")
local strict = require("strict")
local sqlLib = require("libs.sql-lib")
local audioLib = require("libs.audio-lib")
local albumArt = require("libs.album-art")
local musicImporter = require("libs.music-importer")
local fileUtils = require("libs.file-utils")
local eventDispatcher = require("libs.event-dispatcher")
local mainMenuBar = require("libs.ui.main-menu-bar")
local mediaBarLib = require("libs.ui.media-bar")
local musicList = require("libs.ui.music-list")
local ratings = require("libs.ui.ratings")
local alertPopupLib = require("libs.ui.alert-popup")
local aboutPopupLib = require("libs.ui.about-popup")
local alertPopup = alertPopupLib.create()
local aboutPopup = aboutPopupLib.create()
local mMin = math.min
local mRandom = math.random
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
local titleFont = "fonts/Jost-500-Medium.ttf"
local subTitleFont = "fonts/Jost-400-Book.ttf"
local fontAwesomeBrandsFont = "fonts/FA5-Brands-Regular.ttf"
local isWindows = system.getInfo("platform") == "win32"
sqlLib.currentMusicTable = settings.lastView
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or os.getenv("HOME")

local function cancelAllTimers()
	for id, value in pairs(timer._runlist) do
		timer.cancel(value)
	end

	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
	eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.unlock)
end

local function reachedEndOfMusicList()
	local reachedEnd = false

	if
		(musicList.musicSearch and audioLib.currentSongIndex > sqlLib.searchCount or
			audioLib.currentSongIndex > musicList:getMusicCount() or
			audioLib.currentSongIndex <= 1)
	 then
		if (audioLib.loopAll) then
			audioLib.currentSongIndex = 1
		else
			mediaBarLib.resetSongProgress()
			mediaBarLib.clearPlayingSong()
			audioLib.reset()
			eventDispatcher:musicListEvent(eventDispatcher.musicList.events.setSelectedRow, 0)
			reachedEnd = true
		end
	end

	return reachedEnd
end

local function onAudioEvent(event)
	local phase = event.phase
	local song = event.song
	local decrementIndex = event.decrementIndex

	if (phase == "started") then
		-- print("song STARTED")
		eventDispatcher:mediaBarEvent(eventDispatcher.mediaBar.events.loadedUrl)
		mediaBarLib.updatePlayPauseState(true)
		mediaBarLib.removeAlbumArtwork()
		mediaBarLib.resetSongProgress()
		mediaBarLib.updatePlaybackTime()
		mediaBarLib.updateSongText(song)
		albumArt:getFileAlbumCover(song)
	elseif (phase == "ended") then
		local currentSongIndex = audioLib.currentSongIndex
		audioLib.previousSongIndex = currentSongIndex

		if (decrementIndex) then
			audioLib.currentSongIndex = audioLib.currentSongIndex - 1
		else
			audioLib.currentSongIndex = audioLib.currentSongIndex + 1
		end

		-- handle shuffle
		if (audioLib.shuffle) then
			repeat
				audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
			until audioLib.currentSongIndex ~= currentSongIndex
		else
			-- stop audio after last index, or reset the index depending on loop mode
			if (reachedEndOfMusicList()) then
				return
			end
		end

		local nextSong = musicList:getRow(audioLib.currentSongIndex)
		local songExists =
			fileUtils:fileExistsAtRawPath(sFormat("%s%s%s", nextSong.filePath, string.pathSeparator, nextSong.fileName))

		if (not songExists) then
			repeat
				if (decrementIndex) then
					audioLib.currentSongIndex = audioLib.currentSongIndex - 1
				else
					audioLib.currentSongIndex = audioLib.currentSongIndex + 1
				end

				if (reachedEndOfMusicList()) then
					break
				end

				nextSong = musicList:getRow(audioLib.currentSongIndex)
				songExists =
					fileUtils:fileExistsAtRawPath(sFormat("%s%s%s", nextSong.filePath, string.pathSeparator, nextSong.fileName))
			until songExists
		end

		eventDispatcher:musicListEvent(eventDispatcher.musicList.events.setSelectedRow, audioLib.currentSongIndex)
		mediaBarLib.resetSongProgress()
		mediaBarLib.updatePlaybackTime()
		audioLib.load(nextSong)
		audioLib.play(nextSong)
	end

	return true
end

Runtime:addEventListener("playAudio", onAudioEvent)

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

local function onAlbumArtDownloadComplete(event)
	local phase = event.phase

	if (phase == "downloaded") then
		mediaBarLib.setAlbumArtwork(event.fileName)
	end

	return true
end

Runtime:addEventListener("AlbumArtDownload", onAlbumArtDownloadComplete)

local function populateTableViews()
	mainMenuBar.setEnabled(true)

	if (musicList:getTableViewListCount() <= 0) then
		musicTableView = musicList.new()
	end

	musicList:populate()
	-- playInterruptedSong() <-- plays the wrong song if the user was playing via search. Fix this later. Kinda complicated
end

local function reloadTableViews()
	musicList:reloadData()
end

local function updateTableViews()
	musicList:update()
end

local function changeTheme(newTheme)
	local function onConfirm()
		theme:set(newTheme)
		settings.theme = theme:getName()
		settings:save()
		native.requestExit()

		if (isWindows) then
			os.execute('start /MIN "%s" Play.exe', lfs.currentdir())
		else
			-- untested (for macOS)
			os.execute('open -a "%s/Play.app"', lfs.currentdir())
		end
	end

	alertPopup:setTitle("Changing theme requires restart.")
	alertPopup:setMessage(
		"Changing the theme requires the program to restart.\nClicking confirm will restart the program.\n\nClose now?"
	)
	alertPopup:setButtonCallbacks({onConfirm = onConfirm})
	alertPopup:show()
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
							mainMenuBar.setEnabled(false)

							local selectedPath = musicImporter:showFolderSelectDialog()
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

								if (lastChosenPath ~= nil) then
									settings.musicFolderPaths[#settings.musicFolderPaths + 1] = lastChosenPath
									settings:save()
								end

								background:toFront()
								musicList:removeAllRows()
								musicImporter:scanSelectedFolder(selectedPath, updateTableViews, reloadTableViews)
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
								reloadTableViews()
							end

							musicImporter:showFileSelectDialog(onComplete)
						end
					},
					{
						title = "Import Music Library",
						iconName = "file-import",
						onClick = function()
							local foundFile =
								tfd.openFileDialog(
								{
									title = "Select Music Library",
									initialPath = userHomeDirectoryPath,
									filters = {"*.pmdb"},
									singleFilterDescription = "Play Media Library| *.pmdb",
									multiSelect = false
								}
							)

							if (foundFile ~= nil) then
								local newPath = system.pathForFile(sqlLib.dbFilePath, system.DocumentsDirectory)
								settings:save()
								sqlLib:close()

								timer.performWithDelay(
									200,
									function()
										fileUtils:copyFile(foundFile, newPath)
										settings:load()
										sqlLib.currentMusicTable = settings.lastView
										eventDispatcher:mainLuaEvent(eventDispatcher.mainEvent.events.populateTableViews)
										eventDispatcher:musicListEvent(eventDispatcher.musicList.events.cleanReloadData)
									end
								)
							end
						end
					},
					{
						title = "Export Music Library",
						iconName = "file-export",
						onClick = function()
							local saveFilePath =
								tfd.saveFileDialog(
								{
									title = "Save As",
									initialPath = userHomeDirectoryPath,
									filters = {"*.pmdb"},
									singleFilterDescription = "Play Media Library| *.pmdb"
								}
							)

							if (saveFilePath ~= nil) then
								local oldPath = system.pathForFile(sqlLib.dbFilePath, system.DocumentsDirectory)
								local fileExtension = saveFilePath:fileExtension()

								if (fileExtension == nil) then
									saveFilePath = sFormat("%s.pmdb", saveFilePath)
								else
									saveFilePath = saveFilePath:sub(1, saveFilePath:len() - fileExtension:len())
									saveFilePath = sFormat("%s.pmdb", saveFilePath)
								end

								settings:save()
								sqlLib:close()
								fileUtils:copyFile(oldPath, saveFilePath)
								settings:load()
							end
						end
					},
					{
						title = "Delete Music Library",
						iconName = "trash",
						onClick = function()
							local function onRemoved()
								local databasePath = system.pathForFile("", system.DocumentsDirectory)

								cancelAllTimers()
								sqlLib:close()
								audioLib:reset()
								musicList:destroy()
								fileUtils:removeFile(sqlLib.dbFilePath, databasePath)

								timer.performWithDelay(
									100,
									function()
										settings.musicFolderPaths = {}
										settings:load()
										mediaBarLib.resetSongProgress()
										mediaBarLib.clearPlayingSong()
										populateTableViews()
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
							changeTheme("light")
						end
					},
					{
						title = "Dark Theme",
						iconName = "palette",
						onClick = function(event)
							changeTheme("dark")
						end
					},
					{
						title = "Hacker Theme",
						iconName = "palette",
						onClick = function(event)
							changeTheme("hacker")
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
							aboutPopup:show()
						end
					}
				}
			}
		}
	}
)

background = display.newRect(0, 0, display.contentWidth, display.contentHeight - 150)
background.anchorX = 0
background.anchorY = 0
background.x = 0
background.y = 150
background:setFillColor(unpack(theme:get().backgroundColor.primary))
mediaBar = mediaBarLib.new({})
musicTableView = musicList.new()
background:toFront()

local function keyEventListener(event)
	local phase = event.phase

	if (phase == "down") then
		-- print(event.keyName)
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

local function onMainEvent(event)
	local phase = event.phase
	local mainEvent = eventDispatcher.mainEvent.events

	if (phase == mainEvent.populateTableViews) then
		populateTableViews()
	end

	return true
end

Runtime:addEventListener(eventDispatcher.mainEvent.name, onMainEvent)

local function onResize(event)
	if (alertPopupLib:isOpen()) then
		native.setProperty("windowSize", {width = oldWidth, height = oldHeight})
		return
	end

	background.width = display.contentWidth
	background.height = display.contentHeight - 161
	applicationMainMenuBar:onResize()
	mediaBarLib:onResize()
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
		cancelAllTimers()
		transition.cancel()
		Runtime:removeEventListener("key", keyEventListener)
		Runtime:removeEventListener("resize", onResize)
	end
end

Runtime:addEventListener("system", onSystemEvent)
mediaBarLib.setVolumeSliderValue(settings.volume * 100)
audioLib.setVolume(settings.volume)
populateTableViews()

if (sqlLib:totalMusicCount() > 0) then
	timer.performWithDelay(
		500,
		function()
			musicImporter:checkForNewFiles(
				function()
					musicImporter:checkForRemovedFiles()
				end
			)
		end
	)
end

local function directoryListener(event)
	for k, v in pairs(event) do
		print(k, v)
	end
	--[[
	local action = event.action
	local rootDir = event.rootDirectory
	local filePath = event.filePath

	if (action == "create") then
		local tags = tagLib.get({fileName = filePath, filePath = rootDir})
		local musicData = {
			fileName = filePath:getFileName(),
			filePath = filePath,
			title = tags.title:len() > 0 and tags.title or filePath:getFileName(),
			artist = tags.artist,
			album = tags.album,
			genre = tags.genre,
			comment = tags.comment,
			year = tags.year,
			trackNumber = tags.trackNumber,
			rating = ratings:convert(tags.rating),
			duration = sFormat("%02d:%02d", tags.durationMinutes, tags.durationSeconds),
			bitrate = tags.bitrate,
			sampleRate = tags.sampleRate
		}

		sqlLib:insertMusic(musicData)
		_G.printf("directory monitor: adding file %s\\%s to the database", rootDir, filePath)
	elseif (action == "delete") then
		local row = sqlLib:getMusicRowByFileName(filePath:getFileName())
		sqlLib:removeMusicFromAll(row)
		_G.printf("directory monitor: removing file %s\\%s from the database", rootDir, filePath)
	elseif (action == "modify") then
	elseif (action == "move") then
	end--]]
	return true
end

Runtime:addEventListener("directoryMonitor", directoryListener)

for i = 1, #settings.musicFolderPaths do
	_G.printf("Monitoring directory: %s for changes", settings.musicFolderPaths[i])
	local watchID = directoryMonitor.watch(settings.musicFolderPaths[i])
end
