local M = {}
local utf8 = require("plugin.utf8")
local tag = require("plugin.taglib")
local lfs = require("lfs")
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local importProgressLib = require("libs.ui.import-progress")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local utf8Escape = utf8.escape
local musicFolders = {}
local importProgress = importProgressLib.new()
local onFinished = nil

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

function M.getFolderList(path, onComplete)
	local paths = {path}
	local count = 0
	local iterationDelay = 25
	local scanTimer = nil
	M.setTotalProgress(0)
	M.pushProgessToFront()
	importProgress:show()
	importProgress:showProgressBar()
	M.showProgress()
	importProgress:updateHeading("Searching folder hierarchy")
	sqlLib.open()
	onFinished = onComplete
	tRemove(musicFolders)
	musicFolders = nil
	musicFolders = {}
	print("root folder from gather is:" .. paths[1])

	local function gatherFolders()
		if (#paths == 0) then
			if (scanTimer) then
				timer.cancel(scanTimer)
				scanTimer = nil
			end

			paths = nil
			importProgress:setTotalProgress(100)
			importProgress:updateHeading("Retrieved folder list")
			importProgress:updateSubHeading("Now finding music...")
			M.scanFolders()

			return
		end

		for file in lfs.dir(paths[1]) do
			if (file:sub(1, 1) ~= "." and file ~= "." and file ~= "..") then
				local fullPath = paths[1] .. "\\" .. file
				local isDir = lfs.attributes(fullPath, "mode") == "directory"

				if (isDir) then
					--print(fullPath)
					--	paths[#paths + 1] = fullPath
					tInsert(paths, fullPath)
				end
			end
		end

		-- add this folder to the folder list
		musicFolders[#musicFolders + 1] = paths[1]
		importProgress:updateSubHeading(sFormat("Added folder: %s to search list", paths[1]))
		tRemove(paths, 1)
		scanTimer = timer.performWithDelay(iterationDelay, gatherFolders)
	end

	scanTimer = timer.performWithDelay(iterationDelay, gatherFolders)
end

function M.scanFolders()
	local iterationDelay = 25
	local currentIndex = 0
	local totalFiles = 0
	local scanTimer = nil
	M.setTotalProgress(0)
	M.pushProgessToFront()
	importProgress:show()
	importProgress:showProgressBar()
	M.showProgress()
	importProgress:updateHeading(sFormat("Scanning %s for music", musicFolders[currentIndex + 1]))

	local function checkContents()
		currentIndex = currentIndex + 1
		importProgress:setTotalProgress((currentIndex - 1) / #musicFolders)

		if (currentIndex > #musicFolders) then
			print(">>>>>>>>>>FINISHED IMPORTING")
			if (scanTimer) then
				timer.cancel(scanTimer)
				scanTimer = nil
			end
			importProgress:updateHeading(sFormat("All done! I found %d music files", totalFiles))
			importProgress:updateSubHeading("Thank you for your patience. Enjoy your music :)")
			tRemove(musicFolders)
			musicFolders = nil
			musicFolders = {}

			if (type(onFinished) == "function") then
				onFinished()
			end

			return
		end

		if (type(musicFolders) == "table") then
			local path = musicFolders[currentIndex]
			local fileCount = 0
			importProgress:updateHeading(sFormat("Scanning %s for music", path))

			for file in lfs.dir(path) do
				if (file:sub(1, 1) ~= "." and file ~= "." and file ~= "..") then
					local fullPath = path .. "\\" .. file

					if (isMusicFile(fullPath)) then
						local tags = tag.get({fileName = file, filePath = path})

						--if (tags) then
						--local playbackDuration = audioLib.getPlaybackTime().duration
						--local duration = sFormat("%02d:%02d", tags.durationMinutes, tags.durationSeconds)
						--playbackDuration = nil
						--audioLib.dispose()

						local musicData = {
							fileName = utf8Escape(file),
							filePath = utf8Escape(path),
							rating = 0.0,
							album = utf8Escape(tags.album),
							artist = utf8Escape(tags.artist),
							genre = utf8Escape(tags.genre),
							publisher = "",
							title = tags.title:len() > 0 and utf8Escape(tags.title) or utf8Escape(file),
							track = tags.track,
							duration = sFormat("%02d:%02d", tags.durationMinutes, tags.durationSeconds)
						}
						--print("found file: " .. file)
						sqlLib.insertMusic(musicData)

						fileCount = fileCount + 1
					end
				end
			end

			totalFiles = totalFiles + fileCount
			importProgress:updateSubHeading(sFormat("Found %d music files", totalFiles))
			scanTimer = timer.performWithDelay(iterationDelay, checkContents)
		end
	end

	scanTimer = timer.performWithDelay(iterationDelay, checkContents)
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

return M
