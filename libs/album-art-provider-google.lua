local M = {}
local pureMagic = require("libs.pure-magic")
local fileUtils = require("libs.file-utils")
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

	local function googleDownloadListener(event)
		local status = event.status
		local phase = event.phase
		local isError = event.isError
		local response = event.response

		if (isError or status ~= 200) then
			print("response issue: Cover NOT FOUND at google - dispatching notFound event")
			coverNotFoundEvent()
			return
		end

		if (phase == "ended") then
			local imagePath = "tempArtwork_google.jpg"
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
				print("GOT Artwork from google - dispatching found event")

				coverFoundEvent(newFileName)
			else
				print("Cover NOT FOUND at google - dispatching notFound event")
				coverNotFoundEvent()
			end
		end
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
					local imagePath = sFormat("%s%s.jpg", fileUtils.albumArtworkFolder, "tempArtwork_google")

					if (imageUrl) then
						foundCover = true
						print("google: attempting to download cover")
						networkRequests[#networkRequests + 1] = network.request(imageUrl, "GET", googleDownloadListener, {})
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
