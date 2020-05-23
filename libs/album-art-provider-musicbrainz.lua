local albumArtProviderBase = require("libs.album-art-provider-base")
local M = albumArtProviderBase:new("musicbrainz")
local json = require("json")
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

function M:getAlbumCover(song, coverFoundEvent, coverNotFoundEvent)
	local fullMusicBrainzUrl =
		sFormat(
		"%s:%s:%s&limit=1&fmt=json",
		musicBrainzUrl,
		song.album:gsub("%b()", ""):urlEncode(), -- strip anything between (and incl) parens "(text)"
		song.artist:gsub("%b()", ""):urlEncode()
	)

	print(fullMusicBrainzUrl)

	local function saveCover(event)
		self:saveCover(event, coverFoundEvent, coverNotFoundEvent)
	end

	local function musicBrainzRequestListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError

		if (isError or status ~= 200) then
			coverNotFoundEvent()
			return
		end

		local response = jDecode(event.response)
		local releaseGroups = response and response["release-groups"]
		local release = releaseGroups and releaseGroups[1]

		if (phase == "ended") then
			if (response and releaseGroups and release) then
				local imageUrl = sFormat("%s%s/front-250?limit=1", coverArtUrl, release.id)
				print(imageUrl)
				print("musicbrainz: attempting to download cover")

				networkRequests[#networkRequests + 1] = network.request(imageUrl, "GET", saveCover, {})
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
