local M = {}
local tag = require("plugin.taglib")
local lfs = require("lfs")
local tfd = require("plugin.tinyFileDialogs")
local fileUtils = require("libs.file-utils")
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local ratings = require("libs.ui.ratings")
local importProgressLib = require("libs.ui.import-progress")
local activityIndicatorLib = require("libs.ui.activity-indicator")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local musicFiles = {}
local importProgress = importProgressLib.new()
local onFinished = nil
local isWindows = system.getInfo("platform") == "win32"
local userHomeDirectoryPath = isWindows and "%HOMEPATH%\\" or "~/"
local userHomeDirectoryMusicPath = isWindows and "%HOMEPATH%\\Music\\" or "~/Music"

local function isMusicFile(fileName)
	return audioLib.supportedFormats[fileName:fileExtension()]
end

function M.scanSelectedFolder(path, onComplete)
	local paths = {path}
	local count = 0
	local iterationDelay = 35
	local scanTimer = nil
	musicFiles = {}
	musicFiles = nil
	musicFiles = {}
	M.setTotalProgress(0)
	M.pushProgessToFront()
	importProgress:show()
	M.showProgress()
	importProgress:updateHeading("Looking for music")
	importProgress:updateSubHeading(sFormat("Scanning... %s", paths[1]))
	local startSecond = os.date("*t").sec
	local heading = importProgress:getHeading()
	local activityIndicator = activityIndicatorLib.new({name = "musicImporter", fontSize = 18, hideWhenStopped = false})
	activityIndicator.x = heading.x + heading.contentWidth * 0.5 + activityIndicator.contentWidth * 0.5
	activityIndicator.y = heading.y
	activityIndicator:start()

	local function scanFoldersRecursively(event)
		if (#paths == 0) then
			if (scanTimer) then
				timer.cancel(scanTimer)
				scanTimer = nil
			end

			activityIndicator:stop()
			display.remove(activityIndicator)
			activityIndicator = nil
			paths = nil
			importProgress:setTotalProgress(0)
			importProgress:updateHeading("Done!")
			importProgress:updateSubHeading("Thanks for waiting")

			if (#musicFiles < 200) then
				sqlLib:insertMusicBatch(musicFiles)
				musicFiles = nil
				musicFiles = {}
			end

			print("DONE: total time: ", os.difftime(os.date("*t").sec, startSecond))
			onComplete()

			return
		end

		local filesInDir = 0
		local fullPath = nil
		local attributes = nil
		local lock = lfs.lock_dir(paths[1])

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

							if (#musicFiles >= 200) then
								sqlLib:insertMusicBatch(musicFiles)
								musicFiles = nil
								musicFiles = {}
							end
						end
					end
				end
			end
		end

		lock:free()
		local prevPath = paths[1]
		tRemove(paths, 1)

		if (scanTimer) then
			timer.cancel(scanTimer)
			scanTimer = nil
		end

		importProgress:updateSubHeading(sFormat("Scanning... %s\nFinished scanning %s", paths[1] or "done", prevPath))
		scanTimer = timer.performWithDelay(iterationDelay, scanFoldersRecursively)
	end

	scanTimer = timer.performWithDelay(iterationDelay, scanFoldersRecursively)
end

function M.showFolderSelectDialog()
	return tfd.openFolderDialog({title = "Select Music Folder", initialPath = userHomeDirectoryMusicPath})
end

function M.showFileSelectDialog(onComplete)
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
		M.scanFiles(foundFiles, onComplete)
	end
end

function M.showFileSaveDialog(onComplete)
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

function M.scanFiles(files, onComplete)
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
		print("found file: " .. fileName)
		sqlLib:insertMusic(musicData)
	elseif (type(files) == "table") then
		for i = 1, #files do
			local fileName, filePath = files[i]:getFileNameAndPath()
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
			print("found file: " .. fileName)
			sqlLib:insertMusic(musicData)
		end
	end

	if (type(onComplete) == "function") then
		onComplete()
	end
end

function M.pushProgessToFront()
	display.getCurrentStage():insert(importProgress)
end

function M.hideProgressBar()
	importProgress:hideProgressBar()
end

function M.showProgressBar()
	importProgress:showProgressBar()
end

function M.hideProgress()
	importProgress.isVisible = false
end

function M.showProgress()
	importProgress:toFront()
	importProgress.isVisible = true
end

function M.updateHeading(text)
	importProgress:updateHeading(text)
end

function M.updateSubHeading(text)
	importProgress:updateSubHeading(text)
end

function M.setTotalProgress(progress)
	importProgress:setTotalProgress(progress)
end

function M:onResize()
	importProgress:onResize()
end

return M
