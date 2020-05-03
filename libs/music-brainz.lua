local M = {}
local json = require("json")
local crypto = require("crypto")
local fileUtils = require("libs.file-utils")
local sFormat = string.format
local cDigest = crypto.digest
local urlRequestListener = nil
local downloadListener = nil
local requestedSong = nil
local currentCoverFileName = nil
local coverArtUrl = "http://coverartarchive.org/release-group/"
local musicBrainzUrl = "http://musicbrainz.org/ws/2/release-group/?query=release"
local musicBrainzParams = {
	headers = {
		["User-Agent"] = "Play The Music Player/1.0"
	}
}

local function dispatchCoverEvent()
	local event = {
		name = "musicBrainz",
		fileName = currentCoverFileName,
		phase = "downloaded"
	}

	Runtime:dispatchEvent(event)
end

urlRequestListener = function(event)
	if (event.isError) then
		print("MusicBrainz urlRequestListener: Network error ", event.response)
	else
		--print("RESPONSE: " .. event.response)
		local response = json.decode(event.response)
		local releaseGroups = response and response["release-groups"]
		local release = releaseGroups and releaseGroups[1]

		if (response and releaseGroups and release) then
			local imageUrl = sFormat("%s%s/front-250?limit=1", coverArtUrl, release.id)
			print("FOUND entry for " .. requestedSong.tags.title .. " at musicbrainz - url:", imageUrl)
			network.download(imageUrl, "GET", downloadListener, {}, currentCoverFileName, system.DocumentsDirectory)
		else
			print("FAILED to get song info for " .. requestedSong.tags.title .. " at musicbrainz")
		end
	end
end

downloadListener = function(event)
	print("download callback")

	if (event.status ~= 200) then
		local tryAgain = true

		if (tryAgain) then
			local songTitle = requestedSong.tags.title
			local artistTitle = requestedSong.tags.artist

			print("FAILED to get artwork for " .. requestedSong.tags.title .. " from coverarchive.org")
			print("REQUESTING artwork for " .. requestedSong.tags.title .. " (song title, artist) from musicbrainz")
			local fullMusicBrainzUrl =
				sFormat("%s:%s:%s&limit=1&fmt=json", musicBrainzUrl, songTitle:urlEncode(), artistTitle:urlEncode())
			network.request(fullMusicBrainzUrl, "GET", urlRequestListener, musicBrainzParams)
			tryAgain = false
		end

		return
	end

	if (event.isError) then
		print("Network error - download failed: ", event.response)
	elseif (event.phase == "began") then
		print("Progress Phase: began")
	elseif (event.phase == "ended") then
		--print(event.response)
		if (fileUtils:fileExists(currentCoverFileName, system.DocumentsDirectory)) then
			print("GOT artwork for " .. requestedSong.tags.title .. " from opencoverart.org")
			dispatchCoverEvent()
		end
	end
end

function M.getCover(song)
	local hash = cDigest(crypto.md5, song.tags.title .. song.tags.album)
	local artistTitle = song.tags.artist
	local albumTitle = song.tags.album
	local fullMusicBrainzUrl =
		sFormat("%s:%s:%s&limit=1&fmt=json", musicBrainzUrl, artistTitle:urlEncode(), albumTitle:urlEncode())
	requestedSong = song
	currentCoverFileName = sFormat("%s.png", hash)

	if (fileUtils:fileExists(currentCoverFileName, system.DocumentsDirectory)) then
		--print("artwork exists for " .. requestedSong.tags.artist .. " / " .. requestedSong.tags.album)
		dispatchCoverEvent()
	else
		print("REQUESTING artwork for " .. requestedSong.tags.title .. " (artist, album) from musicbrainz")
		network.request(fullMusicBrainzUrl, "GET", urlRequestListener, musicBrainzParams)
	end
end

return M
