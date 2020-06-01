local M = {}
local tag = require("plugin.taglib")
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
local onFinished = nil
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or "~/"
local userHomeDirectoryMusicPath = isWindows and "%HOMEPATH%\\Music\\" or "~/Music"

local function isMusicFile(fileName)
	return audioLib.supportedFormats[fileName:fileExtension()]
end

function M:scanFiles(files, onComplete)
	if (type(files) == "string") then
		local fileName, filePath = files:getFileNameAndPath()
		local tags = tag.get({fileName = fileName, filePath = filePath})
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
			local tags = tag.get({fileName = fileName, filePath = filePath})

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

function M:scanSelectedFolder(path, onInitial, onComplete)
	local paths = {path}
	local count = 0
	local iterationDelay = 5
	local scanTimer = nil
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

			if (#musicFiles < 200) then
				sqlLib:insertMusicBatch(musicFiles)
				musicFiles = nil
				musicFiles = {}
			end

			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
			eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
			eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.unlock)

			print("DONE: total time: ", os.difftime(os.time(), startSecond))
			onComplete()

			return
		end

		local filesInDir = 0
		local fullPath = nil
		local attributes = nil
		local lock = lfs.lock_dir(paths[1])

		local function iterate()
			for file in lfs.dir(paths[1]) do
				if (file ~= "." and file ~= "..") then
					count = count + 1
					fullPath = sFormat("%s%s%s", paths[1], string.pathSeparator, file)
					attributes = lfs.attributes(fullPath)

					if (attributes) then
						if (attributes.mode == "directory") then
							--print("file: " .. file .. " is directory")
							tInsert(paths, fullPath)
						elseif (attributes.mode == "file") then
							if (isMusicFile(file) and attributes.size > 0) then
								filesInDir = filesInDir + 1

								local tags = tag.get({fileName = file, filePath = paths[1]})
								musicFiles[#musicFiles + 1] = {
									fileName = file,
									filePath = paths[1],
									title = tags.title:len() > 0 and tags.title:stripLeadingAndTrailingSpaces() or file,
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

								local currentMusicFileCount = #musicFiles

								if (currentMusicFileCount > 1 and currentMusicFileCount <= 2) then
									eventDispatcher:musicListEvent(eventDispatcher.musicList.events.unlockScroll)
								elseif (currentMusicFileCount >= 200) then
									eventDispatcher:musicListEvent(eventDispatcher.musicList.events.lockScroll)
									sqlLib:insertMusicBatch(musicFiles)
									musicFiles = nil
									musicFiles = {}
									onInitial()
								end
							end
						end
					end

					if (count >= 25) then
						count = 0
						coroutine.yield()
					end
				end
			end
		end

		local co = coroutine.create(iterate)

		local function getNextFile()
			if (coroutine.status(co) == "dead") then
				timer.cancel(scanTimer)
				scanTimer = nil
				lock:free()
				local prevPath = paths[1]
				tRemove(paths, 1)

				scanFoldersRecursively()
				return
			end

			coroutine.resume(co)
		end

		scanTimer = timer.performWithDelay(iterationDelay, getNextFile, 0)
	end

	scanTimer = timer.performWithDelay(iterationDelay, scanFoldersRecursively)
end

function M:checkForNewFiles(onComplete)
	local function NOP()
	end

	local musicFolders = settings.musicFolderPaths

	if (#musicFolders > 0) then
		print("Checking for new files")
		for i = 1, #musicFolders do
			self:scanSelectedFolder(musicFolders[i], NOP, onComplete or NOP)
		end
	end
end

function M:checkForRemovedFiles()
	print("checking for missing files")
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.startActivity)

	local startSecond = os.time()
	local stmt = sqlLib:getAllMusicRows()
	local count = 0

	for row in stmt:nrows() do
		count = count + 1
		if (not fileUtils:fileExistsAtRawPath(sFormat("%s%s%s", row.filePath, string.pathSeparator, row.fileName))) then
			print("file:", row.fileName, "is missing")
		end
	end

	stmt:finalize()
	stmt = nil
	eventDispatcher:mainMenuEvent(eventDispatcher.mainMenu.events.stopActivity)
	print("finished missing file check: total time:", os.difftime(os.time(), startSecond))
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
