local M = {}
local tag = require("plugin.taglib")
local lfs = require("lfs")
local fileUtils = require("libs.file-utils")
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local ratings = require("libs.ui.ratings")
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
	sqlLib:open()
	onFinished = onComplete
	musicFolders = {}
	musicFolders = nil
	musicFolders = {}
	print("root folder from gather is:" .. paths[1])
	importProgress:updateSubHeading(sFormat("Added folder: %s", paths[1]))
	musicFolders[#musicFolders + 1] = {name = paths[1], path = paths[1]}

	local function gatherFolders()
		if (#paths == 0) then
			if (scanTimer) then
				timer.cancel(scanTimer)
				scanTimer = nil
			end

			paths = nil
			importProgress:setTotalProgress(0)
			importProgress:updateHeading("Retrieved folder list")
			importProgress:updateSubHeading("Now finding music...")

			timer.performWithDelay(
				500,
				function()
					M.scanFolders()
				end
			)

			return
		end

		for file in lfs.dir(paths[1]) do
			if (file:sub(1, 1) ~= "." and file ~= "." and file ~= "..") then
				local fullPath = paths[1] .. "\\" .. file
				local isDir = lfs.attributes(fullPath, "mode") == "directory"

				if (isDir) then
					--print(fullPath)
					--	paths[#paths + 1] = fullPath
					importProgress:updateSubHeading(sFormat("Added folder: %s", file))
					-- add this folder to the folder list
					musicFolders[#musicFolders + 1] = {name = file, path = fullPath}
					tInsert(paths, fullPath)
				end
			end
		end

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
	importProgress:updateHeading(sFormat("Scanning %s...", musicFolders[currentIndex + 1].name))

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
			musicFolders = {}
			musicFolders = nil
			musicFolders = {}
			collectgarbage("collect")

			if (type(onFinished) == "function") then
				onFinished()
			end

			return
		end

		if (type(musicFolders) == "table") then
			local path = musicFolders[currentIndex].path
			local folderName = musicFolders[currentIndex].name
			local fileCount = 0
			importProgress:updateHeading(sFormat("Scanning %s...", folderName))

			for file in lfs.dir(path) do
				if (file:sub(1, 1) ~= "." and file ~= "." and file ~= "..") then
					local fullPath = path .. "\\" .. file

					if (isMusicFile(fullPath)) then
						if (fileUtils:fileSize(fullPath) > 0) then
							local tags = tag.get({fileName = file, filePath = path})
							local musicData = {
								fileName = file,
								filePath = path,
								title = tags.title:len() > 0 and tags.title or file,
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
							--print("found file: " .. file)
							sqlLib:insertMusic(musicData)
							fileCount = fileCount + 1
						else
							-- TODO: keep a table of any corrupt files and offer to remove them from disk
							-- after the import process is complete
							print("couldn't add file " .. file .. " as it is corrupt")
						end
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
