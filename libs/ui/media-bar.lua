local M = {}
local audioLib = require("libs.audio-lib")
local sqlLib = require("libs.sql-lib")
local settings = require("libs.settings")
local mainMenuBar = require("libs.ui.main-menu-bar")
local levelVisualization = require("libs.ui.level-visualizer")
local progressView = require("libs.ui.progress-view")
local ratings = require("libs.ui.ratings")
local previousButtonLib = require("libs.ui.media-bar.previous-button")
local playButtonLib = require("libs.ui.media-bar.play-button")
local nextButtonLib = require("libs.ui.media-bar.next-button")
local songContainerLib = require("libs.ui.media-bar.song-container")
local volumeSliderLib = require("libs.ui.media-bar.volume-slider")
local volumeButtonLib = require("libs.ui.media-bar.volume-button")
local libraryButtonLib = require("libs.ui.media-bar.library-button")
local playlistButtonLib = require("libs.ui.media-bar.playlist-button")
local shuffleButtonLib = require("libs.ui.media-bar.shuffle-button")
local loopButtonLib = require("libs.ui.media-bar.loop-button")
local nowPlayingTextLib = require("libs.ui.media-bar.now-playing-text")
local playbackTimeTextLib = require("libs.ui.media-bar.playback-time-text")
local sFormat = string.format
local mMin = math.min
local mMax = math.max
local controlButtonsXOffset = 10
local barHeight = 80
local songTitleText = nil
local songAlbumText = nil
local songProgressView = nil
local previousButton = nil
local playButton = nil
local nextButton = nil
local shuffleButton = nil
local libraryButton = nil
local volumeButton = nil
local volumeSlider = nil
local ratingStars = nil
local playBackTimeText = nil
local albumArtwork = nil
local songContainerBox = nil
local songContainer = nil
local playlistDropdown = nil
local loopButton = nil
local levelVisualizer = nil
local musicDuration = 0

local function updateMediaBar()
	if (audioLib.isChannelPlaying()) then
		playBackTimeText:update()
		songProgressView:setElapsedProgress(songProgressView:getElapsedProgress() + 1)
		songProgressView:setOverallProgress(songProgressView:getElapsedProgress() / musicDuration)
	end
end

timer.performWithDelay(1000, updateMediaBar, 0)

function M.new(options)
	local group = display.newGroup()

	previousButton = previousButtonLib.new(group)
	previousButton.x = (display.screenOriginX + previousButton.contentWidth + controlButtonsXOffset)
	previousButton.y = mainMenuBar:getHeight() + previousButton.contentHeight + 18

	playButton = playButtonLib.new(group)
	playButton.x = (previousButton.x + previousButton.contentWidth + controlButtonsXOffset)
	playButton.y = previousButton.y

	nextButton = nextButtonLib.new(group)
	nextButton.x = (playButton.x + playButton.contentWidth + controlButtonsXOffset)
	nextButton.y = previousButton.y

	volumeSlider = volumeSliderLib.new(group)
	volumeSlider.x = display.contentWidth - volumeSlider.contentWidth - 28
	volumeSlider.y = previousButton.y

	volumeButton = volumeButtonLib.new(group)
	volumeButton.x = volumeSlider.x - volumeButton.contentWidth
	volumeButton.y = previousButton.y
	volumeButton:setIsOn(settings.volume ~= 0)

	songContainerBox, songContainer = songContainerLib.new(group)

	libraryButton = libraryButtonLib.new(group)
	libraryButton.x = songContainerBox.x - libraryButton.contentWidth - 10
	libraryButton.y = previousButton.y

	playlistDropdown = playlistButtonLib.new(group)
	playlistDropdown.x = songContainerBox.x + songContainerBox.contentWidth
	playlistDropdown.y = previousButton.y

	shuffleButton = shuffleButtonLib.new(group)
	shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
	shuffleButton.y = songContainerBox.y - shuffleButton.contentHeight - 5

	loopButton = loopButtonLib.new(group)
	loopButton.x = songContainerBox.x + songContainerBox.contentWidth - shuffleButton.contentWidth
	loopButton.y = shuffleButton.y

	songTitleText, songAlbumText = nowPlayingTextLib.new(group, songContainer)

	levelVisualizer = levelVisualization.new()
	levelVisualizer.x = songContainerBox.x + levelVisualizer.contentWidth + 16
	levelVisualizer.y = songContainerBox.y + songContainerBox.contentHeight * 0.5 - 12
	levelVisualizer.isVisible = false
	group:insert(levelVisualizer)

	playBackTimeText = playbackTimeTextLib.new(group)
	playBackTimeText.anchorX = 1
	playBackTimeText.x = songContainerBox.x + songContainerBox.contentWidth - 5
	playBackTimeText.y = songContainerBox.y + (songContainerBox.contentHeight * 0.5) - 16
	playBackTimeText.text = ""

	songProgressView =
		progressView.new(
		{
			width = songContainerBox.contentWidth,
			allowTouch = true
		}
	)
	songProgressView.anchorX = 0
	songProgressView.x = songContainerBox.x
	songProgressView.y = songContainerBox.y + songContainerBox.contentHeight * 0.5 - songProgressView.contentHeight * 0.5
	group:insert(songProgressView)

	return group
end

local function mediaBarEventListener(event)
	local phase = event.phase

	if (phase == "clearSong") then
		M.clearPlayingSong()
	elseif (phase == "closePlaylists") then
		playlistDropdown:close()
	end

	return true
end

Runtime:addEventListener("mediaBar", mediaBarEventListener)

function M.resetSongProgress()
	playBackTimeText.text = "00:00/00:00"
	musicDuration = 0
	songProgressView:setElapsedProgress(0)
	songProgressView:setOverallProgress(0)
end

function M.getSongProgress()
	return songProgressView:getElapsedProgress()
end

function M.setSongProgress(progress)
	songProgressView:setElapsedProgress(progress)
end

function M.removeAlbumArtwork()
	if (albumArtwork) then
		display.remove(albumArtwork)
		albumArtwork = nil
	end
end

function M.setAlbumArtwork(fileName)
	if (albumArtwork) then
		display.remove(albumArtwork)
		albumArtwork = nil
	end

	albumArtwork = display.newImageRect(fileName, system.DocumentsDirectory, 65, 65)
	albumArtwork.anchorX = 0
	albumArtwork.alpha = 0
	albumArtwork.x = songContainerBox.x + 5
	albumArtwork.y = songContainerBox.y - 3

	if (albumArtwork) then
		transition.to(shuffleButton, {x = songContainerBox.x + 90, time = 250, transition = easing.inOutQuad})
		transition.to(albumArtwork, {alpha = 1, transition = easing.inOutQuad})
	else
		transition.to(
			shuffleButton,
			{x = songContainerBox.x + shuffleButton.contentWidth, time = 250, transition = easing.inOutQuad}
		)
	end
end

function M.updatePlayPauseState(playing)
	playButton:setIsOn(playing)
end

function M.setVolumeSliderValue(volume)
	volumeSlider:setValue(volume)
end

function M.clearPlayingSong()
	if (albumArtwork) then
		display.remove(albumArtwork)
		albumArtwork = nil
	end

	if (albumArtwork) then
		transition.to(shuffleButton, {x = songContainerBox.x + 90, time = 250, transition = easing.inOutQuad})
	else
		transition.to(
			shuffleButton,
			{x = songContainerBox.x + shuffleButton.contentWidth, time = 250, transition = easing.inOutQuad}
		)
	end

	if (ratingStars ~= nil) then
		ratingStars:destroy()
		ratingStars = nil
	end

	levelVisualizer.isVisible = false
	playBackTimeText.isVisible = false
	musicDuration = 0
	playButton:setIsOn(false)
	songTitleText:setText("")
	songAlbumText:setText("")
	M.resetSongProgress()
end

function M.updateSongText(song)
	levelVisualizer.isVisible = true

	if (ratingStars ~= nil) then
		ratingStars:destroy()
		ratingStars = nil
	end

	if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		musicDuration = audioLib.getDuration() * 1000
	end

	ratingStars =
		ratings.new(
		{
			x = 0,
			y = songAlbumText.y + songAlbumText.contentHeight * 0.5 + 8,
			fontSize = 12,
			rating = song.rating or 0,
			isVisible = true,
			parent = songContainer,
			onClick = function(event)
				--print(event.rating)
				--print(event.mp3Rating)
				-- TODO: update database with new rating (also the mp3 file, if this is an mp3 file)
				event.parent:update(event.rating)
			end
		}
	)

	--songTitleText:setText(
	--	"This is a ludicrously long text string to get scrolling text working again. Wow, is it long. omg"
	--)

	--songAlbumText:setText(
	--	"This is a ludicrously long text string to get scrolling text working again. Wow, is it long. omg. so so so long"
	--)
	playBackTimeText.isVisible = true
	songTitleText:setText(song.title)
	songAlbumText:setText(song.album)

	if (albumArtwork) then
		transition.to(shuffleButton, {x = songContainerBox.x + 90, time = 250, transition = easing.inOutQuad})
	else
		transition.to(
			shuffleButton,
			{x = songContainerBox.x + shuffleButton.contentWidth, time = 250, transition = easing.inOutQuad}
		)
	end
end

function M.updatePlaybackTime()
	playBackTimeText:update()
end

function M:onResize()
	-- todo: you're going to have to update whether or not the current song title text (etc) needs to scroll as this happens.
	volumeSlider.x = display.contentWidth - volumeSlider.contentWidth - 28
	volumeButton.x = volumeSlider.x - volumeButton.contentWidth
	songContainerBox.width = mMax(489, display.contentWidth / 2)
	songContainerBox.x = display.contentCenterX - songContainerBox.contentWidth * 0.5 - 38
	songContainer.width = songContainerBox.contentWidth - 140
	songContainer.x = songContainerBox.x + 105
	shuffleButton.x = songContainerBox.x + 90
	loopButton.x = songContainerBox.x + songContainerBox.contentWidth - shuffleButton.contentWidth
	libraryButton.x = songContainerBox.x - libraryButton.contentWidth - 10
	playlistDropdown.x = songContainerBox.x + songContainerBox.contentWidth
	playBackTimeText.x = songContainerBox.x + songContainerBox.contentWidth - 5
	songProgressView.x = songContainerBox.x
	levelVisualizer.x = songContainerBox.x + levelVisualizer.contentWidth + 16

	if (albumArtwork) then
		albumArtwork.x = songContainerBox.x + 5
		shuffleButton.x = songContainerBox.x + 90
	else
		shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
	end

	songProgressView:setWidth(songContainerBox.contentWidth)

	if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		songProgressView:setOverallProgress(songProgressView:getElapsedProgress() / musicDuration)
	end
end

return M
