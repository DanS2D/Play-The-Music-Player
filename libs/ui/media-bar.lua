local M = {}
local audioLib = require("libs.audio-lib")
local settings = require("libs.settings")
local eventDispatcher = require("libs.event-dispatcher")
local mainMenuBar = require("libs.ui.main-menu-bar")
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
local radioListButtonLib = require("libs.ui.media-bar.radio-button")
local podcastListButtonLib = require("libs.ui.media-bar.podcast-button")
local shuffleButtonLib = require("libs.ui.media-bar.shuffle-button")
local loopButtonLib = require("libs.ui.media-bar.loop-button")
local nowPlayingTextLib = require("libs.ui.media-bar.now-playing-text")
local levelVisualization = require("libs.ui.media-bar.level-visualizer")
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
local volumeButton = nil
local volumeSlider = nil
local ratingStars = nil
local playBackTimeText = nil
local albumArtwork = nil
local songContainerBox = nil
local songContainer = nil
local podcastListButton = nil
local radioButton = nil
local playlistDropdown = nil
local libraryButton = nil
local loopButton = nil
local levelVisualizer = nil
local musicDuration = 0
local currentSong = nil

local function updateMediaBar()
	if (audioLib.isChannelPlaying()) then
		playBackTimeText:update(currentSong)

		if (currentSong and currentSong.url) then
			songProgressView:setOverallProgress(0)
		else
			songProgressView:setElapsedProgress(songProgressView:getElapsedProgress() + 1)
			songProgressView:setOverallProgress(songProgressView:getElapsedProgress() / musicDuration)
		end
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

	volumeButton = volumeButtonLib.new(group)
	volumeButton.x = (nextButton.x + nextButton.contentWidth + volumeButton.contentWidth * 0.25 + controlButtonsXOffset)
	volumeButton.y = previousButton.y
	volumeButton:setIsOn(settings.volume ~= 0)

	volumeSlider = volumeSliderLib.new(group)
	volumeSlider.x = (volumeButton.x + volumeButton.contentWidth * 0.70 + controlButtonsXOffset)
	volumeSlider.y = previousButton.y

	songContainerBox, songContainer = songContainerLib.new(group)

	podcastListButton = podcastListButtonLib.new(group)
	podcastListButton.anchorX = 1
	podcastListButton.x = (display.contentWidth - podcastListButton.contentWidth - 50)
	podcastListButton.y = previousButton.y

	radioButton = radioListButtonLib.new(group)
	radioButton.anchorX = 1
	radioButton.x = podcastListButton.x - podcastListButton.contentWidth - controlButtonsXOffset - 7
	radioButton.y = previousButton.y

	playlistDropdown = playlistButtonLib.new(group)
	playlistDropdown.anchorX = 1
	playlistDropdown.x = radioButton.x - radioButton.contentWidth - controlButtonsXOffset
	playlistDropdown.y = previousButton.y

	libraryButton = libraryButtonLib.new(group)
	libraryButton.anchorX = 1
	libraryButton.x = playlistDropdown.x + controlButtonsXOffset - 2
	libraryButton.y = previousButton.y

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
	local mediaBarEvent = eventDispatcher.mediaBar.events

	if (phase == mediaBarEvent.clearSong) then
		M.clearPlayingSong()
	elseif (phase == mediaBarEvent.closePlaylists) then
		playlistDropdown:close()
	elseif (phase == mediaBarEvent.loadingUrl) then
		songTitleText.isVisible = true
		songAlbumText.isVisible = true
		levelVisualizer.isVisible = false
		songTitleText:setText(event.value.title)
		songAlbumText:setText("Loading...")
	elseif (phase == mediaBarEvent.loadedUrl) then
		levelVisualizer.isVisible = true
	end

	return true
end

Runtime:addEventListener(eventDispatcher.mediaBar.name, mediaBarEventListener)

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
	currentSong = song

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

	if (song.url) then
		songAlbumText:setText(song.url)
	else
		songAlbumText:setText(song.album)
	end

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
	playBackTimeText:update(currentSong)
end

function M:onResize()
	-- todo: you're going to have to update whether or not the current song title text (etc) needs to scroll as this happens.
	songContainerBox.width = mMax(528, display.contentWidth / 2)
	songContainerBox.x = mMax(265, display.contentCenterX - songContainerBox.contentWidth * 0.5)
	songContainer.width = songContainerBox.contentWidth - 140
	songContainer.x = songContainerBox.x + 105
	shuffleButton.x = songContainerBox.x + 90
	loopButton.x = songContainerBox.x + songContainerBox.contentWidth - shuffleButton.contentWidth
	volumeButton.x = (nextButton.x + nextButton.contentWidth + volumeButton.contentWidth * 0.25 + controlButtonsXOffset)
	volumeSlider.x = (volumeButton.x + volumeButton.contentWidth * 0.70 + controlButtonsXOffset)
	playBackTimeText.x = songContainerBox.x + songContainerBox.contentWidth - 5
	songProgressView.x = songContainerBox.x
	levelVisualizer.x = songContainerBox.x + levelVisualizer.contentWidth + 16
	podcastListButton.x = (display.contentWidth - podcastListButton.contentWidth - 50)
	radioButton.x = podcastListButton.x - podcastListButton.contentWidth - controlButtonsXOffset - 7
	playlistDropdown.x = radioButton.x - radioButton.contentWidth - controlButtonsXOffset
	libraryButton.x = playlistDropdown.x + controlButtonsXOffset - 2

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
