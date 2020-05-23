local albumArtProviderBase = require("libs.album-art-provider-base")
local M = albumArtProviderBase:new("discogs")
local json = require("json")
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

	local function saveCover(event)
		self:saveCover(event, coverFoundEvent, coverFoundEvent)
	end

	local function discogsRequestListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = type(event.response) == "string" and jDecode(event.response)
		local result = response and response["results"]
		local info = result and result[1]

		if (isError or status ~= 200) then
			coverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			if (response and result and info) then
				local imageUrl = info["cover_image"]
				print("discogs: attempting to download cover ")

				networkRequests[#networkRequests + 1] = network.request(imageUrl, "GET", saveCover, discogsParams)
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
