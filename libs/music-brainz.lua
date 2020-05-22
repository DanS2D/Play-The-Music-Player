local M = {
	customEventName = nil
}
local json = require("json")
local lfs = require("lfs")
local tag = require("plugin.taglib")
local fileUtils = require("libs.file-utils")
local pureMagic = require("libs.pure-magic")
local sFormat = string.format
local urlRequestListener = nil
local downloadListener = nil
local requestedSong = nil
local tryAgain = true
local coverArtUrl = "http://coverartarchive.org/release-group/"
local musicBrainzUrl = "http://musicbrainz.org/ws/2/release-group/?query=release"
local musicBrainzParams = {
	headers = {
		["User-Agent"] = "Play The Music Player/1.0"
	}
}
local documentsPath = system.pathForFile("", system.DocumentsDirectory)
local coverSavePath = sFormat("%s%s%s", documentsPath, string.pathSeparator, fileUtils.albumArtworkFolder)

local function dispatchFoundCoverEvent(fileName)
	local musicBrainzEvent = {
		name = M.customEventName or "musicBrainz",
		fileName = fileName,
		phase = "downloaded"
	}

	Runtime:dispatchEvent(musicBrainzEvent)
end

local function dispatchNotFoundCoverEvent()
	local musicBrainzEvent = {
		name = M.customEventName or "musicBrainz",
		fileName = nil,
		phase = "notFound"
	}

	Runtime:dispatchEvent(musicBrainzEvent)
end

--[[
local function setCoverFromDownload(song, fileName)
	if (isMp3File(song) or isFlacFile(song) or isMp4File(song)) then
		if (fileUtils:fileExists(fileName, system.DocumentsDirectory)) then
			print("setting artwork")
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

urlRequestListener = function(event)
	if (event.isError) then
		--print("MusicBrainz urlRequestListener: Network error ", event.response)
		dispatchCoverEvent(true)
	else
		--print("RESPONSE: " .. event.response)
		local response = json.decode(event.response)
		local releaseGroups = response and response["release-groups"]
		local release = releaseGroups and releaseGroups[1]

		-- TODO: get this metadata when a song is missing some fields (artist, album, whatever) and
		-- add the metadata to the files where appropriate. You can do this to all files, not just mp3.
		-- only cover art stuff is limited to mp3

		if (response and releaseGroups and release) then
			local imageUrl = sFormat("%s%s/front-250?limit=1", coverArtUrl, release.id)
			print("attempting to download cover to: ", currentCoverFileName)

			--print("FOUND entry for " .. requestedSong.title .. " at musicbrainz - url:", imageUrl)
			network.download(imageUrl, "GET", downloadListener, {}, currentCoverFileName, system.DocumentsDirectory)
		else
			--print("FAILED to get song info for " .. requestedSong.title .. " at musicbrainz")
			dispatchCoverEvent(true)
		end
	end
end

downloadListener = function(event)
	--print("download callback")

	if (event.status ~= 200) then
		if (tryAgain) then
			local songTitle = requestedSong.title
			local artistTitle = requestedSong.artist

			--print("FAILED to get artwork for " .. requestedSong.title .. " from coverarchive.org")
			--print("REQUESTING artwork for " .. requestedSong.title .. " (song title, artist) from musicbrainz")
			local fullMusicBrainzUrl =
				sFormat("%s:%s:%s&limit=1&fmt=json", musicBrainzUrl, songTitle:urlEncode(), artistTitle:urlEncode())
			network.request(fullMusicBrainzUrl, "GET", urlRequestListener, musicBrainzParams)
			tryAgain = false
		else
			--dispatchCoverEvent(true)
		end

		return
	end

	if (event.isError) then
		--print("Network error - download failed: ", event.response)
		dispatchCoverEvent(true)
	elseif (event.phase == "began") then
		--print("Progress Phase: began")
	elseif (event.phase == "ended") then
		local fileName = event.response.filename
		local fileExtension = fileName:sub(fileName:len() - 3)
		local newFileName = currentCoverFileName:sub(1, currentCoverFileName:len() - 4) .. fileExtension
		local baseDir = event.response.baseDirectory
		--print("current filename: ", currentCoverFileName, "new name:", newFileName)
		--local result, reason =
		--	os.rename(system.pathForFile(currentCoverFileName, baseDir), system.pathForFile(newFileName, baseDir))

		local path = system.pathForFile(currentCoverFileName, system.DocumentsDirectory)
		--local fName = "04cc22c81455179997b2478966005f57.png"

		local mimetype = pureMagic.via_path(path)
		--print("mime type: ", mimetype)

		if (mimetype == "image/png") then
			newFileName = currentCoverFileName:sub(1, currentCoverFileName:len() - 4) .. ".png"
			local result, reason =
				os.rename(system.pathForFile(currentCoverFileName, baseDir), system.pathForFile(newFileName, baseDir))
		elseif (mimetype == "image/jpeg") then
			--print(result)
			newFileName = currentCoverFileName:sub(1, currentCoverFileName:len() - 4) .. ".jpg"
			local result, reason =
				os.rename(system.pathForFile(currentCoverFileName, baseDir), system.pathForFile(newFileName, baseDir))
		else
			newFileName = currentCoverFileName
		end

		if (fileUtils:fileExists(newFileName, system.DocumentsDirectory)) then
			currentCoverFileName = newFileName
			setCoverFromDownload(requestedSong, newFileName)
			print("GOT artwork for " .. requestedSong.title .. " from opencoverart.org")
			dispatchCoverEvent()
		else
			dispatchCoverEvent(true)
		end
	end
end--]]
--[[
function M.getCover(song)
	local hash = song.md5
	local artistTitle = song.artist
	local albumTitle = song.album
	local fullMusicBrainzUrl =
		sFormat("%s:%s:%s&limit=1&fmt=json", musicBrainzUrl, artistTitle:urlEncode(), albumTitle:urlEncode())
	requestedSong = song
	currentCoverFileName = sFormat("%s%s.png", fileUtils.albumArtworkFolder, hash)
	local coverOnDisk, fileName = coverExists(song)

	local function setOrGetData()
		local foundFile, foundFileName = coverExists(song)

		-- check to see if the cover exists again (it may have still been saving to disk)
		if (foundFile) then
			currentCoverFileName = foundFileName
			--print("artwork exists for " .. requestedSong.artist .. " / " .. requestedSong.album)
			dispatchCoverEvent()
		else
			tryAgain = true
			--print("REQUESTING artwork for " .. requestedSong.title .. " (artist, album) from musicbrainz")
			network.request(fullMusicBrainzUrl, "GET", urlRequestListener, musicBrainzParams)
		end
	end

	-- check if the file exists
	if (coverOnDisk) then
		local cPath = sFormat("%s%s", documentsPath, fileName)
		local mimetype = pureMagic.via_path(cPath)

		if (mimetype == "image/jpeg" or mimetype == "image/png") then
			currentCoverFileName = fileName
			dispatchCoverEvent()
		else
			os.remove(cPath)
			setOrGetData()
		end
	else
		if (canGetCoverFromAudioFile(song)) then
			getCoverFromAudioFile(song)
			--print("trying to get cover from mp3 file")

			local function findFileSavedFromMp3(event)
				local coverOnDiskExists, coverFileName = coverExists(song)

				if (coverOnDiskExists) then
					local cPath = sFormat("%s%s", documentsPath, coverFileName)
					local mimetype = pureMagic.via_path(cPath)
					--print("found cover " .. coverFileName .. " cancelling timer now")

					if (mimetype == "image/jpeg" or mimetype == "image/png") then
						currentCoverFileName = coverFileName
						dispatchCoverEvent()
						timer.cancel(event.source)
					else
						timer.cancel(event.source)
						setOrGetData()
					end
				end

				if (event.count >= 20) then
					setOrGetData()
				end
			end

			timer.performWithDelay(50, findFileSavedFromMp3, 30)
		else
			setOrGetData()
		end
	end
end--]]
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
		exists = true
		fileName = pngFileName
	end

	if (jpgFile) then
		io.close(jpgFile)
		exists = true
		fileName = jpgFileName
	end

	pngFile = nil
	jpgFile = nil

	return exists, fileName
end

local function checkForLocalAlbumCover(song, onComplete)
	local function diskCheck(event)
		local exists, fileName = doesCoverExist(song)

		if (exists) then
			onComplete({phase = "complete", fileName = fileName})
			timer.cancel(event.source)
		elseif (not exists and event.count >= 30) then
			onComplete({phase = "notFound", fileName = fileName})
		end
	end

	timer.performWithDelay(50, diskCheck, 30)
end

local function getRemoteCover(song)
end

function M:getAlbumCover(song)
	local function onLocalAlbumCoverCheckComplete(event)
		local phase = event.phase

		if (phase == "complete") then
			dispatchFoundCoverEvent(event.fileName)
		elseif (phase == "notFound") then
			getRemoteCover(song)
		end
	end

	local exists, fileName = doesCoverExist(song)

	if (exists) then
		print("COVER ALREADY EXISTS ON DISK")
		dispatchFoundCoverEvent(fileName)
	else
		if (canGetCoverFromAudioFile(song)) then
			print("COVER DOESN'T EXIST, CHECKING IN FILE FIRST")
			getCoverFromAudioFile(song)
			checkForLocalAlbumCover(song, onLocalAlbumCoverCheckComplete)
		else
			-- check musicbrainz for the coverArt
		end
	end
end

return M
