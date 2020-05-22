local M = {
	customEventName = nil,
	remoteProviders = {
		musicBrainz = 1,
		discogs = 2,
		google = 3
	}
}

local tag = require("plugin.taglib")
local musicBrainzProvider = require("libs.album-art-provider-musicbrainz")
local googleProvider = require("libs.album-art-provider-google")
local fileUtils = require("libs.file-utils")
local sFormat = string.format
local documentsPath = system.pathForFile("", system.DocumentsDirectory)
local coverSavePath = sFormat("%s%s%s", documentsPath, string.pathSeparator, fileUtils.albumArtworkFolder)

local function dispatchCoverFoundEvent(fileName)
	local event = {
		name = M.customEventName or "AlbumArtDownload",
		fileName = fileName,
		phase = "downloaded"
	}

	Runtime:dispatchEvent(event)
end

local function dispatchCoverNotFoundEvent()
	local event = {
		name = M.customEventName or "AlbumArtDownload",
		fileName = nil,
		phase = "notFound"
	}

	Runtime:dispatchEvent(event)
end

local function isMp3File(song)
	return (song.fileName:fileExtension() == "mp3")
end

local function isFlacFile(song)
	return (song.fileName:fileExtension() == "flac")
end

local function isMp4File(song)
	local extension = song.fileName:fileExtension()

	return (extension == "m4a" or extension == "m4v")
end

local function canGetCoverFromAudioFile(song)
	return isMp3File(song) or isFlacFile(song) or isMp4File(song)
end

local function getCoverFromAudioFile(song)
	tag.getArtwork(
		{
			fileName = song.fileName,
			filePath = song.filePath,
			imageFileName = song.md5,
			imageFilePath = coverSavePath
		}
	)
end

local function saveCoverToAudioFile(song, fileName)
	if (canGetCoverFromAudioFile(song)) then
		if (fileUtils:fileExists(fileName)) then
			tag.setArtwork(
				{
					fileName = song.fileName,
					filePath = song.filePath,
					imageFileName = fileName,
					imageFilePath = documentsPath
				}
			)
		end
	end
end

local function doesCoverExist(song)
	local baseDir = system.DocumentsDirectory
	local pngFileName = sFormat("%s%s.png", fileUtils.albumArtworkFolder, song.md5)
	local jpgFileName = sFormat("%s%s.jpg", fileUtils.albumArtworkFolder, song.md5)
	local pngPath = system.pathForFile(pngFileName, baseDir)
	local jpgPath = system.pathForFile(jpgFileName, baseDir)
	local pngFile, _ = io.open(pngPath, "rb")
	local jpgFile, _ = io.open(jpgPath, "rb")
	local exists = false
	local fileName = nil

	if (pngFile) then
		io.close(pngFile)

		if (fileUtils:fileSize(pngPath) > 0) then
			exists = true
			fileName = pngFileName
		else
			os.remove(pngPath)
		end
	end

	if (jpgFile) then
		io.close(jpgFile)

		if (fileUtils:fileSize(jpgPath) > 0) then
			exists = true
			fileName = jpgFileName
		else
			os.remove(jpgPath)
		end
	end

	pngFile = nil
	jpgFile = nil

	return exists, fileName
end

local function checkForLocalAlbumCover(song, onComplete)
	local function diskCheck(event)
		local exists, fileName = doesCoverExist(song)

		if (exists) then
			print("found cover filename: ", fileName)
			onComplete({phase = "complete", fileName = fileName})
			timer.cancel(event.source)
		elseif (not exists and event.count >= 30) then
			onComplete({phase = "notFound", fileName = fileName})
		end
	end

	timer.performWithDelay(50, diskCheck, 30)
end

function M:getFileAlbumCover(song)
	local function onLocalAlbumCoverCheckComplete(event)
		local phase = event.phase

		if (phase == "complete") then
			print("local Cover FOUND, dispatching downloaded event")
			dispatchCoverFoundEvent(event.fileName)
		elseif (phase == "notFound") then
			print("local Cover NOT FOUND")
		end
	end

	local exists, fileName = doesCoverExist(song)

	if (exists) then
		print("local COVER ALREADY EXISTS ON DISK w/filename: ", fileName)
		dispatchCoverFoundEvent(fileName)
	else
		if (canGetCoverFromAudioFile(song)) then
			print("local COVER DOESN'T EXIST, CHECKING IN FILE FIRST")
			getCoverFromAudioFile(song)
			checkForLocalAlbumCover(song, onLocalAlbumCoverCheckComplete)
		else
			print("CAN'T GET COVER FROM THIS AUDIO FILE")
			dispatchCoverFoundEvent()
		end
	end
end

function M:getRemoteAlbumCover(song, provider)
	if (provider == self.remoteProviders.musicBrainz) then
		musicBrainzProvider:getAlbumCover(song, dispatchCoverFoundEvent, dispatchCoverNotFoundEvent)
	elseif (provider == self.remoteProviders.google) then
		googleProvider:getAlbumCover(song, dispatchCoverFoundEvent, dispatchCoverNotFoundEvent)
	end
end

return M
