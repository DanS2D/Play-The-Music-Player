local M = {}
local json = require("json")
local pureMagic = require("libs.pure-magic")
local fileUtils = require("libs.file-utils")
local jDecode = json.decode
local sFormat = string.format
local networkRequests = {}
local consumerKey = "NZjXwzlQcPuNZVasbAlj"
local consumerSecret = "etiShvDnZQmeOskwEdpZJuDwHnlPQwZZ"
local requestTokenUrl = "https://api.discogs.com/oauth/request_token"
local authUrl = "https://www.discogs.com/oauth/authorize"
local accessTokenUrl = "https://api.discogs.com/oauth/access_token"
local discogsUrl = "https://api.discogs.com/database/search?q="
local discogsParams = {
	headers = {
		["User-Agent"] = "Play The Music Player/1.0 +http://playmusicplayer.net",
		["Authorization"] = sFormat("Discogs key=%s, secret=%s", consumerKey, consumerSecret)
	}
}

function M:getAlbumCover(song, coverFoundEvent, coverNotFoundEvent)
	local fullDiscogsUrl =
		sFormat(
		"%s%s&artist=%s&format=album&per_page=1",
		discogsUrl,
		song.album:gsub("%b()", ""):urlEncode(), -- strip anything between (and incl) parens "(text)"
		song.artist:gsub("%b()", ""):urlEncode()
	)

	print(fullDiscogsUrl)

	local function discogsDownloadListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = event.response

		if (isError or status ~= 200) then
			print("response issue: Cover NOT FOUND at discogs - dispatching notFound event")
			coverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			local imagePath = "tempArtwork_discogs.jpg"
			local file, errorString = io.open(system.pathForFile(imagePath, system.TemporaryDirectory), "wb")
			file:write(response)
			file:close()

			local fileName = imagePath
			local fileExtension = fileName:fileExtension()
			local filePath = system.pathForFile(fileName, system.TemporaryDirectory)
			local newFileName = fileName
			local mimetype = pureMagic.via_path(filePath)

			if (mimetype == "image/png" and fileExtension ~= "png") then
				newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "png")
				local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.TemporaryDirectory))
			elseif (mimetype == "image/jpeg" and fileExtension ~= "jpg") then
				newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "jpg")
				local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.TemporaryDirectory))
			end

			if (fileUtils:fileExists(newFileName, system.TemporaryDirectory)) then
				print("GOT Artwork from discogs - dispatching found event")

				coverFoundEvent(newFileName)
			else
				print("Cover NOT FOUND at discogs - dispatching notFound event")
				coverNotFoundEvent()
			end
		end
	end

	local function discogsRequestListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = type(event.response) == "string" and jDecode(event.response)
		local result = response and response["results"]
		local info = result and result[1]

		print("discogs() status: ", status, "isError: ", isError, "phase: ", phase)

		if (isError or status ~= 200) then
			coverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			if (response and result and info) then
				local imageUrl = info["cover_image"]
				print("discogs: attempting to download cover ")

				networkRequests[#networkRequests + 1] = network.request(imageUrl, "GET", discogsDownloadListener, discogsParams)
			else
				-- let's try to get the cover via title / artist (TODO:)
				print("SONG NOT FOUND at discogs, dispatching notFound event")
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
	networkRequests[#networkRequests + 1] = network.request(fullDiscogsUrl, "GET", discogsRequestListener, discogsParams)
end

return M
