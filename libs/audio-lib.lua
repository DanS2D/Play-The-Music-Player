local M = {
	supportedFormats = {
		"b",
		"m",
		"2sf",
		"ahx",
		"as0",
		"asc",
		"ay",
		"ayc",
		--"bin",
		"cc3",
		"chi",
		"cop",
		"d",
		"dmm",
		"dsf",
		"dsq",
		"dst",
		"esv",
		"fdi",
		"ftc",
		"gam",
		"gamplus",
		"gbs",
		"gsf",
		"gtr",
		"gym",
		"hes",
		"hrm",
		"hrp",
		"hvl",
		"kss",
		"lzs",
		"m",
		"mod",
		"msp",
		"mtc",
		"nsf",
		"nsfe",
		"p",
		"pcd",
		"psc",
		"psf",
		"psf2",
		"psg",
		"psm",
		"pt1",
		"pt2",
		"pt3",
		"rmt",
		"rsn",
		"s",
		"sap",
		"scl",
		"sid",
		"spc",
		"sqd",
		"sqt",
		"ssf",
		"st1",
		"st3",
		"stc",
		"stp",
		"str",
		"szx",
		"td0",
		"tf0",
		"tfc",
		"tfd",
		"tfe",
		"tlz",
		"tlzp",
		"trd",
		"trs",
		"ts",
		"usf",
		"vgm",
		"vgz",
		"vtx",
		"ym",
		"spx",
		"mpc",
		"ape",
		"ac3",
		"wav",
		"aiff",
		"mp3",
		"mp2",
		"mp1",
		"ogg",
		"flac",
		"wav"
	},
	loopOne = false,
	loopAll = false,
	shuffle = false,
	currentSongIndex = 0
}
local bass = require("plugin.bass")
local tRemove = table.remove
local bassDispose = bass.dispose
local bassGetDuration = bass.getDuration
local bassGetLevel = bass.getLevel
local bassGetPlayBackTime = bass.getPlaybackTime
local bassGetVolume = bass.getVolume
local bassIsChannelPaused = bass.isChannelPaused
local bassIsChannelPlaying = bass.isChannelPlaying
local bassLoad = bass.load
local bassPause = bass.pause
local bassPlay = bass.play
local bassResume = bass.resume
local bassRewind = bass.rewind
local bassSeek = bass.seek
local bassSetVolume = bass.setVolume
local bassStop = bass.stop
local channelHandle = nil
local currentSong = nil
local previousVolume = 1.0
local audioChannels = {}

local function dispatchPlayEvent(song)
	local event = {
		name = "bass",
		phase = "started",
		song = song
	}

	Runtime:dispatchEvent(event)
end

local function dispatchCompleteEvent(song)
	local event = {
		name = "bass",
		phase = "ended",
		song = song
	}

	Runtime:dispatchEvent(event)
end

local function cleanupAudio()
	if (channelHandle ~= nil) then
		print("cleaning up audio")
		bassStop(channelHandle)
		bassDispose(channelHandle)
	end
end

local function loadAudio(song)
	if (currentSong ~= nil and currentSong.fileName == song.fileName and bassIsChannelPlaying(channelHandle)) then
		return
	end

	currentSong = song

	if (channelHandle ~= nil) then
		bassStop(channelHandle)
		bassDispose(channelHandle)
		channelHandle = nil
	end

	channelHandle = bassLoad(currentSong.fileName, currentSong.filePath)
end

local function playAudio(song)
	if (type(channelHandle) == "number") then
		if (bassIsChannelPlaying(channelHandle)) then
			bassRewind(channelHandle)
			dispatchPlayEvent(song)
			return
		end
	end

	currentSong = song
	bassPlay(channelHandle)
	tRemove(audioChannels)
	audioChannels[#audioChannels + 1] = channelHandle
	dispatchPlayEvent(currentSong)
end

local function onAudioComplete(event)
	if (M.loopOne) then
		loadAudio(currentSong)
		playAudio(currentSong)

		return
	end

	if (event.completed) then
		cleanupAudio()
		dispatchCompleteEvent(currentSong)
	end
end

local function handleAudioEvents()
	if (type(audioChannels) == "table") then
		for i = 1, #audioChannels do
			local channel = audioChannels[i]

			if (channel and not bassIsChannelPlaying(channel) and not bassIsChannelPaused(channel)) then
				local event = {
					name = "bass-internal",
					completed = true
				}

				onAudioComplete(event)
			end
		end
	end
end

Runtime:addEventListener("enterFrame", handleAudioEvents)

function M.dispose()
	if (channelHandle ~= nil) then
		bassDispose(channelHandle)
	end
end

function M.getChannelHandle()
	return channelHandle
end

function M.getDuration()
	if (channelHandle ~= nil) then
		return bassGetDuration(channelHandle)
	end

	return nil
end

function M.getLevel()
	if (channelHandle ~= nil) then
		return bassGetLevel(channelHandle)
	end

	return 0
end

function M.getPlaybackTime()
	if (channelHandle ~= nil) then
		return bassGetPlayBackTime(channelHandle)
	end

	return nil
end

function M.getPreviousVolume()
	return previousVolume
end

function M.getVolume()
	return bassGetVolume()
end

function M.isChannelHandleValid()
	return (channelHandle ~= nil)
end

function M.isChannelPaused()
	if (channelHandle ~= nil) then
		return bassIsChannelPaused(channelHandle)
	end

	return false
end

function M.isChannelPlaying()
	if (channelHandle ~= nil) then
		return bassIsChannelPlaying(channelHandle)
	end

	return false
end

function M.load(song)
	loadAudio(song)
end

function M.pause()
	if (channelHandle ~= nil) then
		bassPause(channelHandle)
	end
end

function M.play(song)
	playAudio(song)
end

function M.resume()
	if (channelHandle ~= nil) then
		bassResume(channelHandle)
	end
end

function M.rewind()
	if (channelHandle ~= nil) then
		bassRewind(channelHandle)
	end
end

function M.seek(position)
	if (channelHandle ~= nil) then
		bassSeek(channelHandle, position)
	end
end

function M.setVolume(vol)
	previousVolume = bassGetVolume()
	bassSetVolume(vol)
end

function M.stop()
	if (channelHandle ~= nil) then
		bassStop(channelHandle)
	end
end

function M.reset()
	for i = 1, #audioChannels do
		bassStop(audioChannels[i])
		bassDispose(audioChannels[i])
	end

	tRemove(audioChannels)
end

return M
