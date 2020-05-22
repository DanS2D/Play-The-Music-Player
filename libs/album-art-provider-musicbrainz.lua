local M = {}
local json = require("json")
local pureMagic = require("libs.pure-magic")
local fileUtils = require("libs.file-utils")
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

function M:getAlbumCover(song, coverFoundEvent, coverNotFoundEvent)
	local fullMusicBrainzUrl =
		sFormat(
		"%s:%s:%s&limit=1&fmt=json",
		musicBrainzUrl,
		song.album:gsub("%b()", ""):urlEncode(), -- strip anything between (and incl) parens "(text)"
		song.artist:gsub("%b()", ""):urlEncode()
	)

	print(fullMusicBrainzUrl)

	local function musicBrainzDownloadListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = event.response

		if (isError or status ~= 200) then
			print("Cover NOT FOUND at coverarchive.org - dispatching notFound event")
			coverNotFoundEvent()
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

				coverFoundEvent(newFileName)
			else
				print("Cover NOT FOUND at coverarchive.org - dispatching notFound event")
				coverNotFoundEvent()
			end
		end
	end

	local function musicBrainzRequestListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = jDecode(event.response)
		local releaseGroups = response and response["release-groups"]
		local release = releaseGroups and releaseGroups[1]

		print("musicBrainzRequest() status: ", status, "isError: ", isError, "phase: ", phase)

		if (isError or status ~= 200) then
			coverNotFoundEvent()
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
				coverNotFoundEvent()
			end
		end
	end

	-- cancel any previous cover operations
	for i = 1, #networkRequests do
		network.cancel(networkRequests[i])
		networkRequests[i] = nil
	end

	networkRequests = nil
	networkRequests = {}

	-- let's try to get the cover via album / artist
	networkRequests[#networkRequests + 1] =
		network.request(fullMusicBrainzUrl, "GET", musicBrainzRequestListener, musicBrainzParams)
end

return M
