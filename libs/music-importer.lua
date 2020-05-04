local M = {}
local sqlite3 = require("sqlite3")
local audioLib = require("libs.audio-lib")
local importProgressLib = require("libs.ui.import-progress")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local databasePath = system.pathForFile("music.db", system.DocumentsDirectory)
local database = sqlite3.open(databasePath)
local musicFolders = {}
local importProgress = importProgressLib.new()

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

function M.getFolderList(path)
	local paths = {}
	paths[#paths + 1] = path
	local count = 0
	importProgress:updateHeading("Searching folder hierarchy")

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

	local function checkContents()
		currentIndex = currentIndex + 1
		importProgress:setTotalProgress((currentIndex - 1) / #musicFolders)

		if (currentIndex > #musicFolders) then
			scanTimer = nil
			importProgress:updateHeading(sFormat("All done! I found %s music files", totalFiles))
			importProgress:updateSubHeading("Thank you for your patience. Enjoy your music :)")
			return
		end

		if (type(musicFolders) == "table") then
			local fileCount = 0
			importProgress:updateHeading(sFormat("Scanning %s for music", musicFolders[currentIndex]))

			for file in lfs.dir(musicFolders[currentIndex]) do
				if (file:sub(-1) ~= ".") then
					local fullPath = musicFolders[currentIndex] .. "\\" .. file

					if (isMusicFile(fullPath)) then
						fileCount = fileCount + 1
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
	importProgress:toFront()
end

return M
