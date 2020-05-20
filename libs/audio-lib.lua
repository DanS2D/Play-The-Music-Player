local M = {
	supportedFormats = {
		["spx"] = 1,
		["mpc"] = 1,
		["ape"] = 1,
		["ac3"] = 1,
		["aiff"] = 1,
		["mp3"] = 1,
		["mp2"] = 1,
		["mp1"] = 1,
		["ogg"] = 1,
		["flac"] = 1,
		["wav"] = 1
	},
	loopOne = false,
	loopAll = false,
	shuffle = false,
	currentSongIndex = 0,
	previousSongIndex = 0,
	currentSong = nil
}
local bass = require("plugin.bass")
local settings = require("libs.settings")
local sFormat = string.format
local tInsert = table.insert
local tRemove = table.remove
local bassDispose = bass.dispose
local bassFadeIn = bass.fadeIn
local bassFadeOut = bass.fadeOut
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

-- chiptunes formats:
-- ZX Spectrum (ASC, FTC, GTR, PSC, PSG, PSM, PT1/PT2/PT3, SQT, STC/ST1/ST3, STP, VTX, YM, TurboSound tracks, AY with embedded player, TXT files for Vortex Tracker II, CHI, DMM, DST, ET1, PDT, SQD, STR, TFC, TFD, TFE)
-- PC (669, AMF, DMF, FAR, FNK, GDM, IMF, IT, LIQ, PSM, MDL, MTM, PTM, RTM, S3M, STIM, STM, STX, ULT, V2M, XM)
-- Amiga (DBM, EMOD, MOD, MTN, IMS, MED, OKT, PT36, SFX, AHX)
-- Atari (DTM, GTK, TCB, SAP, RMT)
-- Acorn (DTT)
-- Sam Coupe (COP)
-- Commodore 64/128 MOS6581 (SID)
-- Amstrad CPC (AYC)
-- Super Nintendo (SPC)
-- Multiplatform (MTC, VGM, VGZ, GYM)
-- Nintendo (NSF, NSFe)
-- GameBoy (GBS, GSF)
-- TurboGrafX (HES)
-- MSX (KSS)
-- PlayStation (PSF, PSF2, AT3, AT9)
-- Ultra64 (USF)
-- Nintendo DS (2SF)
-- Dreamcast (DSF)
-- Saturn (SSF)

local chipTunesFormats = {
	["asc"] = 1,
	["ftc"] = 1,
	["gtr"] = 1,
	["psc"] = 1,
	["psg"] = 1,
	["psm"] = 1,
	["pt1"] = 1,
	["pt2"] = 1,
	["pt3"] = 1,
	["sqt"] = 1,
	["stc"] = 1,
	["st1"] = 1,
	["st3"] = 1,
	["stp"] = 1,
	["vtx"] = 1,
	["ym"] = 1,
	["chi"] = 1,
	["dmm"] = 1,
	["dst"] = 1,
	["et1"] = 1,
	["pdt"] = 1,
	["sqd"] = 1,
	["str"] = 1,
	["tfc"] = 1,
	["tfd"] = 1,
	["tfe"] = 1,
	["669"] = 1,
	["amf"] = 1,
	["dmf"] = 1,
	["far"] = 1,
	["fnk"] = 1,
	["gdm"] = 1,
	["imf"] = 1,
	["it"] = 1,
	["liq"] = 1,
	["mdl"] = 1,
	["mtm"] = 1,
	["ptm"] = 1,
	["rtm"] = 1,
	["s3m"] = 1,
	["stim"] = 1,
	["stm"] = 1,
	["stx"] = 1,
	["ult"] = 1,
	["v2m"] = 1,
	["xm"] = 1,
	["dbm"] = 1,
	["emod"] = 1,
	["mod"] = 1,
	["mtn"] = 1,
	["ims"] = 1,
	["med"] = 1,
	["okt"] = 1,
	["pt36"] = 1,
	["sfx"] = 1,
	["ahx"] = 1,
	["dtm"] = 1,
	["gtk"] = 1,
	["tcb"] = 1,
	["sap"] = 1,
	["rmt"] = 1,
	["dtt"] = 1,
	["cop"] = 1,
	["sid"] = 1,
	["ayc"] = 1,
	["spc"] = 1,
	["mtc"] = 1,
	["vgm"] = 1,
	["vgz"] = 1,
	["gym"] = 1,
	["nsf"] = 1,
	["nsfe"] = 1,
	["gbs"] = 1,
	["gsf"] = 1,
	["hes"] = 1,
	["kss"] = 1,
	["psf"] = 1,
	["psf2"] = 1,
	["at3"] = 1,
	["at9"] = 1,
	["usf"] = 1,
	["2sf"] = 1,
	["dsf"] = 1,
	["ssf"] = 1
}
M.fileSelectFilter = {}

for k, v in pairs(chipTunesFormats) do
	M.supportedFormats[k] = v
end

for k, v in pairs(M.supportedFormats) do
	tInsert(M.fileSelectFilter, sFormat("*.%s", k))
end

local function isChiptunes(song)
	return chipTunesFormats[song.fileName:fileExtension()] ~= nil
end

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

local function getRemainingPlaybackTimeInSeconds()
	local playbackTime = M.getPlaybackTime()
	local duration = playbackTime.duration
	local elapsed = playbackTime.elapsed

	return (duration.minutes * 60 - elapsed.minutes * 60 + duration.seconds - elapsed.seconds)
end

local function loadAudio(song)
	if (currentSong ~= nil and currentSong.fileName == song.fileName and bassIsChannelPlaying(channelHandle)) then
		return
	end

	currentSong = song
	M.currentSong = song

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

			if (toboolean(settings.fadeInTrack)) then
				bassFadeIn(channelHandle, settings.fadeInTime)
			end

			dispatchPlayEvent(song)
			return
		end
	end

	currentSong = song
	M.currentSong = song

	bassPlay(channelHandle)
	tRemove(audioChannels)
	audioChannels[#audioChannels + 1] = channelHandle

	if (toboolean(settings.fadeInTrack)) then
		bassFadeIn(channelHandle, settings.fadeInTime)
	end

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

			if (channel) then
				if (not bassIsChannelPlaying(channel) and not bassIsChannelPaused(channel)) then
					local event = {
						name = "bass-internal",
						completed = true
					}

					onAudioComplete(event)
				else
					if (toboolean(settings.fadeOutTrack)) then
						if (getRemainingPlaybackTimeInSeconds() <= settings.fadeOutTime / 1000) then
							bassFadeOut(channelHandle, settings.fadeOutTime)
						end
					end
				end
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
	if (isChiptunes(song)) then
		print("loading chiptunes plugin")
		M.loadChipTunesPlugin()
	else
		M.unloadChipTunesPlugin()
		collectgarbage("collect")
	end

	loadAudio(song)
end

function M.loadChipTunesPlugin()
	if (not bass.isChipTunesPluginLoaded()) then
		bass.loadChipTunesPlugin()
	end
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
		if (type(audioChannels[i]) == "number") then
			bassStop(audioChannels[i])
			bassDispose(audioChannels[i])
		end
	end

	channelHandle = nil
	tRemove(audioChannels)
end

function M.unloadChipTunesPlugin()
	bass.unloadChipTunesPlugin()
end

return M
