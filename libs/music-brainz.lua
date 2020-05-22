local M = {
	customEventName = nil
}
local json = require("json")
local lfs = require("lfs")
local tag = require("plugin.taglib")
local fileUtils = require("libs.file-utils")
local pureMagic = require("libs.pure-magic")
local jDecode = json.decode
local sFormat = string.format
local networkRequests = {}
local coverArtUrl = "http://coverartarchive.org/release-group/"
local musicBrainzUrl = "http://musicbrainz.org/ws/2/release-group/?query=release"
local musicBrainzParams = {
	headers = {
		["User-Agent"] = "Play The Music Player/1.0"
	}
}
local documentsPath = system.pathForFile("", system.DocumentsDirectory)
local coverSavePath = sFormat("%s%s%s", documentsPath, string.pathSeparator, fileUtils.albumArtworkFolder)

local function dispatchCoverFoundEvent(fileName)
	local musicBrainzEvent = {
		name = M.customEventName or "musicBrainz",
		fileName = fileName,
		phase = "downloaded"
	}

	Runtime:dispatchEvent(musicBrainzEvent)
end

local function dispatchCoverNotFoundEvent()
	local musicBrainzEvent = {
		name = M.customEventName or "musicBrainz",
		fileName = nil,
		phase = "notFound"
	}

	Runtime:dispatchEvent(musicBrainzEvent)
end

--[[
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

local function getRemoteCover(song)
	local musicBrainzRequestListener = nil
	local musicBrainzDownloadListener = nil
	local fullMusicBrainzUrl =
		sFormat(
		"%s:%s:%s&limit=1&fmt=json",
		musicBrainzUrl,
		song.album:gsub("%b()", ""):urlEncode(),
		song.artist:gsub("%b()", ""):urlEncode()
	)

	print(fullMusicBrainzUrl)

	musicBrainzDownloadListener = function(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = event.response

		if (isError or status ~= 200) then
			print("Cover NOT FOUND at coverarchive.org - dispatching notFound event")
			dispatchCoverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			local fileName = response.filename
			local fileExtension = fileName:fileExtension()
			local filePath = system.pathForFile(fileName, system.DocumentsDirectory)
			local newFileName = fileName
			local mimetype = pureMagic.via_path(filePath)

			if (mimetype == "image/png" and fileExtension ~= "png") then
				newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "png")
				local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.DocumentsDirectory))
			elseif (mimetype == "image/jpeg" and fileExtension ~= "jpg") then
				newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "jpg")
				local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.DocumentsDirectory))
			end

			if (fileUtils:fileExists(newFileName)) then
				print("GOT Artwork from opencoverart.org - dispatching found event")

				saveCoverToAudioFile(song, newFileName)
				dispatchCoverFoundEvent(newFileName)
			else
				print("Cover NOT FOUND at coverarchive.org - dispatching notFound event")
				dispatchCoverNotFoundEvent()
			end
		end
	end

	musicBrainzRequestListener = function(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = jDecode(event.response)
		local releaseGroups = response and response["release-groups"]
		local release = releaseGroups and releaseGroups[1]

		print("musicBrainzRequest() status: ", status, "isError: ", isError, "phase: ", phase)

		if (isError or status ~= 200) then
			dispatchCoverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			if (response and releaseGroups and release) then
				local imageUrl = sFormat("%s%s/front-250?limit=1", coverArtUrl, release.id)
				local imagePath = sFormat("%s%s.jpg", fileUtils.albumArtworkFolder, song.md5)
				print(imageUrl)
				print("attempting to download cover to: ", imagePath)

				networkRequests[#networkRequests + 1] =
					network.download(imageUrl, "GET", musicBrainzDownloadListener, {}, imagePath, system.DocumentsDirectory)
			else
				-- let's try to get the cover via title / artist (TODO:)
				print("SONG NOT FOUND at MusicBrainz, dispatching notFound event")
				dispatchCoverNotFoundEvent()
			end
		end
	end

	-- let's try to get the cover via album / artist
	networkRequests[#networkRequests + 1] =
		network.request(fullMusicBrainzUrl, "GET", musicBrainzRequestListener, musicBrainzParams)
end

function M:getAlbumCover(song)
	local function onLocalAlbumCoverCheckComplete(event)
		local phase = event.phase

		if (phase == "complete") then
			print("Cover FOUND, dispatching downloaded event")
			dispatchCoverFoundEvent(event.fileName)
		elseif (phase == "notFound") then
			print("Cover NOT FOUND, looking for cover at musicbrainz")
			getRemoteCover(song)
		end
	end

	-- cancel any previous cover operations
	for i = 1, #networkRequests do
		network.cancel(networkRequests[i])
		networkRequests[i] = nil
	end

	local exists, fileName = doesCoverExist(song)
	networkRequests = nil
	networkRequests = {}

	if (exists) then
		print("COVER ALREADY EXISTS ON DISK w/filename: ", fileName)
		dispatchCoverFoundEvent(fileName)
	else
		if (canGetCoverFromAudioFile(song)) then
			print("COVER DOESN'T EXIST, CHECKING IN FILE FIRST")
			getCoverFromAudioFile(song)
			checkForLocalAlbumCover(song, onLocalAlbumCoverCheckComplete)
		else
			print("CAN'T GET COVER FROM THIS AUDIO FILE, CHECKING MUSICBRAINZ")
			-- check musicbrainz for the coverArt
			getRemoteCover(song)
		end
	end
end

return M
