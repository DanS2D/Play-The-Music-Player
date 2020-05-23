local albumArtProviderBase = require("libs.album-art-provider-base")
local M = albumArtProviderBase:new("google")
local networkRequests = {}
local googleUrl = "https://www.google.com/search?q="
local sFormat = string.format

function M:getAlbumCover(song, coverFoundEvent, coverNotFoundEvent)
	local fullGoogleUrl =
		sFormat(
		"%s%s+%s+cover&tbm=isch&hl=en&chips=q:%s+%s+cover,g_1:album",
		googleUrl,
		song.artist:urlEncode(),
		song.album:urlEncode(),
		song.artist:urlEncode(),
		song.album:urlEncode()
	)

	local function saveCover(event)
		self:saveCover(event, coverFoundEvent, coverFoundEvent)
	end

	local function googleRequestListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = event.response
		local firstImageStartPos = response:find('" src="https://')
		local foundCover = false

		if (isError or status ~= 200) then
			coverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			if (firstImageStartPos) then
				local firstImageEndPos = response:find('"/>', firstImageStartPos + 7)

				if (firstImageEndPos) then
					local imageUrl = response:sub(firstImageStartPos + 7, firstImageEndPos)

					if (imageUrl) then
						foundCover = true
						print("google: attempting to download cover")
						networkRequests[#networkRequests + 1] = network.request(imageUrl, "GET", saveCover, {})
					end
				end
			end

			if (not foundCover) then
				print("Cover NOT FOUND at google - dispatching notFound event")
				coverFoundEvent()
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

	networkRequests[#networkRequests + 1] = network.request(fullGoogleUrl, "GET", googleRequestListener, {})
end

return M
