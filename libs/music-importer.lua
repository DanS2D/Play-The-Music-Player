local M = {}
local lfs = require("lfs")
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local importProgressLib = require("libs.ui.import-progress")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
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
	local paths = {}
	paths[#paths + 1] = path
	local count = 0
	importProgress:show()
	importProgress:updateHeading("Searching folder hierarchy")
	sqlLib.open()
	onFinished = onComplete

	repeat
		count = count + 1

		for file in lfs.dir(paths[1]) do
			if (file:sub(-1) ~= ".") then
				local fullPath = paths[1] .. "\\" .. file
				local isDir = lfs.attributes(fullPath, "mode") == "directory"

				if (isDir) then
					tInsert(paths, fullPath)
				end
			end
		end

		-- add this folder to the folder list
		musicFolders[#musicFolders + 1] = paths[1]
		importProgress:updateSubHeading(sFormat("Added folder: %s to search list", paths[1]))

		tRemove(paths, 1)
	until #paths == 0

	M.scanFolders()
end

function M.scanFolders()
	local iterationDelay = 100
	local currentIndex = 0
	local totalFiles = 0
	local scanTimer = nil
	M.pushProgessToFront()
	importProgress:show()
	importProgress:showProgressBar()
	M.showProgress()

	local function checkContents()
		currentIndex = currentIndex + 1
		importProgress:setTotalProgress((currentIndex - 1) / #musicFolders)

		if (currentIndex > #musicFolders) then
			scanTimer = nil
			importProgress:updateHeading(sFormat("All done! I found %s music files", totalFiles))
			importProgress:updateSubHeading("Thank you for your patience. Enjoy your music :)")

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
				if (file:sub(-1) ~= ".") then
					local fullPath = path .. "\\" .. file

					if (isMusicFile(fullPath)) then
						audioLib.load({fileName = file, filePath = path})
						local tags = audioLib.getTags()

						if (tags) then
							local playbackDuration = audioLib.getPlaybackTime().duration
							local musicTags = tags
							local duration = sFormat("%02d:%02d", playbackDuration.minutes, playbackDuration.seconds)
							playbackDuration = nil
							audioLib.dispose()

							local musicData = {
								fileName = file,
								filePath = path,
								rating = 0.0,
								album = musicTags.album,
								artist = musicTags.artist,
								genre = musicTags.genre,
								publisher = musicTags.publisher,
								title = musicTags.title,
								track = musicTags.track,
								duration = duration
							}
							fileCount = fileCount + 1

							sqlLib.insertMusic(musicData)
						end
					end
				end
			end

			totalFiles = totalFiles + fileCount
			importProgress:updateSubHeading(sFormat("Found %d music files", fileCount))
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
