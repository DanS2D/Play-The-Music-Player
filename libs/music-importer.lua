local M = {}
local tagLib = require("plugin.taglib")
local lfs = require("lfs")
local tfd = require("plugin.tinyFileDialogs")
local fileUtils = require("libs.file-utils")
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local settings = require("libs.settings")
local ratings = require("libs.ui.ratings")
local eventDispatcher = require("libs.event-dispatcher")
local activityIndicatorLib = require("libs.ui.activity-indicator")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local musicFiles = {}
local fileList = {}
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or os.getenv("HOME")
local userHomeDirectoryMusicPath = isWindows and "%HOMEPATH%\\Music\\" or os.getenv("HOME") .. "/Music"

local function isMusicFile(fileName)
	return audioLib.supportedFormats[fileName:fileExtension()]
end

local function scanFolder(path, delay, onComplete)
	local paths = {path}
	local count = 0
	local iterationDelay = delay or 2
	local scanTimer = nil
	fileList = nil
	fileList = {}
	musicFiles = nil
	musicFiles = {}
	local startSecond = os.time()
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.startActivity)
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.lock)

	local function scanFoldersRecursively(event)
		if (#paths == 0) then
			if (scanTimer) then
				timer.cancel(scanTimer)
				scanTimer = nil
			end

			paths = nil
			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
			eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.unlock)
			_G.printf("Got folder list in: %d seconds", os.difftime(os.time(), startSecond))
			onComplete()

			return
		end

		local fullPath = nil
		local attributes = nil

		for file in lfs.dir(paths[1]) do
			if (file ~= "." and file ~= "..") then
				fullPath = sFormat("%s%s%s", paths[1], string.pathSeparator, file)
				attributes = lfs.attributes(fullPath)

				if (attributes) then
					if (attributes.mode == "directory") then
						--print("file: " .. file .. " is directory")
						tInsert(paths, fullPath)
					elseif (attributes.mode == "file") then
						if (isMusicFile(file) and attributes.size > 0) then
							count = count + 1
							fileList[count] = {fileName = file, filePath = paths[1]}
						end
					end
				end
			end
		end

		tRemove(paths, 1)
		scanTimer = timer.performWithDelay(iterationDelay, scanFoldersRecursively)
	end

	scanTimer = timer.performWithDelay(iterationDelay, scanFoldersRecursively)
end

function M:scanFiles(files, onComplete)
	if (type(files) == "string") then
		local fileName, filePath = files:getFileNameAndPath()
		local tags = tagLib.get({fileName = fileName, filePath = filePath})
		local musicData = {
			fileName = fileName,
			filePath = filePath,
			title = tags.title:len() > 0 and tags.title or fileName,
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
		--print("found file: " .. fileName)
		sqlLib:insertMusic(musicData)
	elseif (type(files) == "table") then
		local musicData = {}

		for i = 1, #files do
			local fileName, filePath = files[i]:getFileNameAndPath()
			local tags = tagLib.get({fileName = fileName, filePath = filePath})

			musicData[#musicData + 1] = {
				fileName = fileName,
				filePath = filePath,
				title = tags.title:len() > 0 and tags.title or fileName,
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
			--print("found file: " .. fileName)
		end

		sqlLib:insertMusicBatch(musicData)
		musicData = nil
	end

	if (type(onComplete) == "function") then
		onComplete()
	end
end

function M:getFilesFromList(onInitial, onComplete)
	local startSecond = os.time()
	local scanTimer = nil
	musicFiles = nil
	musicFiles = {}
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.startActivity)

	local function iterate()
		for i = 1, #fileList do
			local item = fileList[i]
			local fileName = item.fileName
			local filePath = item.filePath
			local fullPath = sFormat("%s%s%s", filePath, string.pathSeparator, fileName)

			if (fileName) then
				if (fileUtils:fileExistsAtRawPath(fullPath)) then
					local tags = tagLib.get({fileName = fileName, filePath = filePath})

					musicFiles[#musicFiles + 1] = {
						fileName = fileName,
						filePath = filePath,
						title = tags.title:len() > 0 and tags.title:stripLeadingAndTrailingSpaces() or fileName,
						artist = tags.artist:stripLeadingAndTrailingSpaces(),
						album = tags.album:stripLeadingAndTrailingSpaces(),
						genre = tags.genre:stripLeadingAndTrailingSpaces(),
						comment = tags.comment:stripLeadingAndTrailingSpaces(),
						year = tags.year,
						trackNumber = tags.trackNumber,
						rating = ratings:convert(tags.rating),
						playCount = 0, -- TODO: read from taglib when it supports it
						duration = sFormat("%02d:%02d", tags.durationMinutes, tags.durationSeconds),
						bitrate = tags.bitrate,
						sampleRate = tags.sampleRate
					}
				end
			end

			local currentMusicFileCount = #musicFiles

			if (currentMusicFileCount > 1 and currentMusicFileCount <= 2) then
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
			elseif (currentMusicFileCount >= 450) then
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.lockScroll)
				sqlLib:insertMusicBatch(musicFiles)
				musicFiles = nil
				musicFiles = {}
				onInitial()
			end

			if (i % 25 == 0) then
				coroutine.yield()
			end
		end
	end

	local co = coroutine.create(iterate)

	local function getNextFile()
		if (coroutine.status(co) == "dead") then
			timer.cancel(scanTimer)
			scanTimer = nil

			if (#musicFiles > 0) then
				sqlLib:insertMusicBatch(musicFiles)
				onInitial()
			end

			fileList = {}
			fileList = nil
			musicFiles = {}
			musicFiles = nil

			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
			eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.unlock)
			_G.printf("populated SQL Database in: %d seconds", os.difftime(os.time(), startSecond))

			onComplete()

			return
		end

		coroutine.resume(co)
	end

	scanTimer = timer.performWithDelay(2, getNextFile, 0)
end

function M:scanSelectedFolder(path, onInitial, onComplete)
	local function onFinished()
		self:getFilesFromList(onInitial, onComplete)
	end

	scanFolder(path, 2, onFinished)
end

function M:checkForNewFiles(onComplete)
	local musicFolders = settings.musicFolderPaths
	local paths = nil
	local count = 0
	local iterationDelay = 4
	local folderIndex = 1
	local scanTimer = nil
	fileList = nil
	fileList = {}
	musicFiles = nil
	musicFiles = {}
	local startSecond = os.time()

	local function getFiles()
		local stmt = sqlLib:getAllMusicRows()
		local startSecond = os.time()
		musicFiles = nil
		musicFiles = {}

		local function iterate()
			for i = 1, #fileList do
				local item = fileList[i]
				local fileName = item.fileName
				local filePath = item.filePath
				local fullPath = sFormat("%s%s%s", filePath, string.pathSeparator, fileName)

				if (fileName) then
					if (fileUtils:fileExistsAtRawPath(fullPath)) then
						if (not sqlLib:doesRowExist(fileName)) then
							local tags = tagLib.get({fileName = fileName, filePath = filePath})

							musicFiles[#musicFiles + 1] = {
								fileName = fileName,
								filePath = filePath,
								title = tags.title:len() > 0 and tags.title:stripLeadingAndTrailingSpaces() or fileName,
								artist = tags.artist:stripLeadingAndTrailingSpaces(),
								album = tags.album:stripLeadingAndTrailingSpaces(),
								genre = tags.genre:stripLeadingAndTrailingSpaces(),
								comment = tags.comment:stripLeadingAndTrailingSpaces(),
								year = tags.year,
								trackNumber = tags.trackNumber,
								rating = ratings:convert(tags.rating),
								playCount = 0, -- TODO: read from taglib when it supports it
								duration = sFormat("%02d:%02d", tags.durationMinutes, tags.durationSeconds),
								bitrate = tags.bitrate,
								sampleRate = tags.sampleRate
							}
						end
					end
				end

				local currentMusicFileCount = #musicFiles

				if (currentMusicFileCount > 1 and currentMusicFileCount <= 2) then
					eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
				elseif (currentMusicFileCount >= 450) then
					eventDispatcher:musicListEvent(eventDispatcher.musicList.events.lockScroll)
					sqlLib:insertMusicBatch(musicFiles)
					musicFiles = nil
					musicFiles = {}
				end

				if (i % 25 == 0) then
					coroutine.yield()
				end
			end
		end

		local co = coroutine.create(iterate)

		local function getNextFile()
			if (coroutine.status(co) == "dead") then
				if (#musicFiles > 0) then
					sqlLib:insertMusicBatch(musicFiles)
				end

				musicFiles = {}
				musicFiles = nil

				eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
				eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
				eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.unlock)

				if (folderIndex + 1 <= #musicFolders) then
					fileList = {}
					fileList = nil

					co = coroutine.create(iterate)
					folderIndex = folderIndex + 1
					_G.printf("Update: Checking for new files in saved folder path %d", folderIndex)
					scanFolder(paths[folderIndex], 5, getFiles)
				else
					if (scanTimer) then
						timer.cancel(scanTimer)
						scanTimer = nil
					end

					fileList = {}
					fileList = nil

					_G.printf("Update: finished new file check in: %d seconds", os.difftime(os.time(), startSecond))

					onComplete()
				end

				return
			end

			coroutine.resume(co)
		end

		scanTimer = timer.performWithDelay(5, getNextFile, 0)
	end

	if (#musicFolders > 0) then
		print("Update: Checking for new files in first saved folder path")

		for i = 1, #musicFolders do
			paths = {musicFolders[i]}
		end

		scanFolder(paths[1], 5, getFiles)
	end
end

function M:checkForRemovedFiles()
	print("Missing: checking for missing files")
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.startActivity)

	local startSecond = os.time()
	local stmt = sqlLib:getAllMusicRows()
	local count = 0

	for row in stmt:nrows() do
		count = count + 1
		if (not fileUtils:fileExistsAtRawPath(sFormat("%s%s%s", row.filePath, string.pathSeparator, row.fileName))) then
			-- TODO: do something with the removed file (either remove it or popup a message for removal confirmation)
			print("file:", row.fileName, "is missing")
		end
	end

	stmt:finalize()
	stmt = nil
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
	_G.printf("Missing: finished missing file check in: %d seconds", os.difftime(os.time(), startSecond))
end

function M:showFolderSelectDialog()
	return tfd.openFolderDialog({title = "Select Music Folder", initialPath = userHomeDirectoryMusicPath})
end

function M:showFileSelectDialog(onComplete)
	local foundFiles =
		tfd.openFileDialog(
		{
			title = "Select Music Files (limited to 32 files)",
			initialPath = userHomeDirectoryMusicPath,
			filters = audioLib.fileSelectFilter,
			singleFilterDescription = "Audio Files| *.mp3;*.flac;*.ogg;*.wav;*.ape;*.vgm;*.mod etc",
			multiSelect = true
		}
	)

	if (foundFiles ~= nil) then
		self:scanFiles(foundFiles, onComplete)
	end
end

function M:showFileSaveDialog(onComplete)
	local saveFilePath =
		tfd.saveFileDialog(
		{
			title = "Save As",
			initialPath = userHomeDirectoryMusicPath,
			filters = audioLib.fileSelectFilter,
			singleFilterDescription = "Audio Files| *.mp3;*.flac;*.ogg;*.wav;*.ape;*.vgm;*.mod etc"
		}
	)

	if (saveFilePath ~= nil) then
		onComplete()
	end
end

return M
