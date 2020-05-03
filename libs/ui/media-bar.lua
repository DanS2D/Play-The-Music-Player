local M = {}
local widget = require("widget")
local audioLib = require("libs.audio-lib")
local levelVisualization = require("libs.ui.level-visualizer")
local musicVisualizer = require("libs.ui.music-visualizer")
local progressView = require("libs.ui.progress-view")
local dScreenOriginX = display.screenOriginX
local dScreenOriginY = display.dScreenOriginY
local dCenterX = display.contentCenterX
local dCenterY = display.contentCenterY
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local sFormat = string.format
local defaultButtonPath = "img/buttons/default/"
local overButtonPath = "img/buttons/over/"
local buttonSize = 20
local controlButtonsXOffset = 10
local titleFont = "fonts/Roboto-Regular.ttf"
local subTitleFont = "fonts/Roboto-Light.ttf"
local musicData = nil
local songTitleText = nil
local songAlbumText = nil
local songProgressView = nil
local previousButton = nil
local playButton = nil
local pauseButton = nil
local nextButton = nil
local volumeOnButton = nil
local volumeOffButton = nil
local volumeSlider = nil
local playBackTimeText = nil
local albumArtwork = nil
local songContainerBox = nil
local songContainer = nil
local musicVisualizerBar = nil
local loopButton = nil
local levelVisualizer = nil

local function updateMediaBar()
	if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		local musicDuration = audioLib.getDuration() * 1000

		playBackTimeText:update()
		songProgressView:setElapsedProgress(songProgressView:getElapsedProgress() + 1)
		songProgressView:setOverallProgress(songProgressView:getElapsedProgress() / musicDuration)
	end
end

timer.performWithDelay(1000, updateMediaBar, 0)

function M.new(options)
	local group = display.newGroup()

	previousButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "previous-button.png",
			overFile = overButtonPath .. "previous-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				if (audioLib.currentSongIndex - 1 > 0) then
					audioLib.currentSongIndex = audioLib.currentSongIndex - 1
					playButton.isVisible = false
					pauseButton.isVisible = true

					audioLib.load(musicData[audioLib.currentSongIndex])
					audioLib.play(musicData[audioLib.currentSongIndex])
				end
			end
		}
	)
	previousButton.x = (dScreenOriginX + (previousButton.contentWidth * 0.5) + controlButtonsXOffset)
	previousButton.y = 55
	group:insert(previousButton)

	playButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "play-button.png",
			overFile = overButtonPath .. "play-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				if (audioLib.isChannelHandleValid()) then
					event.target.isVisible = false
					pauseButton.isVisible = true

					if (audioLib.isChannelPlaying()) then
						return
					end

					if (audioLib.isChannelPaused()) then
						audioLib.resume()
						return
					end
				end
			end
		}
	)
	playButton.x = (previousButton.x + previousButton.contentWidth + controlButtonsXOffset)
	playButton.y = previousButton.y
	group:insert(playButton)

	pauseButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "pause-button.png",
			overFile = overButtonPath .. "pause-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				if (audioLib.isChannelHandleValid()) then
					if (audioLib.isChannelPlaying()) then
						audioLib.pause()
						event.target.isVisible = false
						playButton.isVisible = true
					end
				end
			end
		}
	)
	pauseButton.x = playButton.x
	pauseButton.y = previousButton.y
	pauseButton.isVisible = false
	group:insert(pauseButton)

	nextButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "next-button.png",
			overFile = overButtonPath .. "next-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				if (audioLib.currentSongIndex + 1 <= #musicData) then
					audioLib.currentSongIndex = audioLib.currentSongIndex + 1
					playButton.isVisible = false
					pauseButton.isVisible = true

					audioLib.load(musicData[audioLib.currentSongIndex])
					audioLib.play(musicData[audioLib.currentSongIndex])
				end
			end
		}
	)
	nextButton.x = (pauseButton.x + pauseButton.contentWidth + controlButtonsXOffset)
	nextButton.y = previousButton.y
	group:insert(nextButton)

	musicVisualizerBar = musicVisualizer.new({})
	musicVisualizerBar.x = display.contentCenterX
	musicVisualizerBar.y = nextButton.y - 5
	group:insert(musicVisualizerBar)

	songContainerBox = display.newRoundedRect(0, 0, dWidth / 2 - 8, 50, 2)
	songContainerBox.anchorX = 0
	songContainerBox.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset + 29)
	songContainerBox.y = nextButton.y - 5
	songContainerBox.strokeWidth = 1
	songContainerBox:setFillColor(0, 0, 0, 1)
	songContainerBox:setStrokeColor(0.6, 0.6, 0.6, 0.5)
	group:insert(songContainerBox)

	songContainer = display.newContainer(songContainerBox.contentWidth - 80, 50)
	songContainer.anchorX = 0
	songContainer.x = songContainerBox.x + 46
	songContainer.y = songContainerBox.y - 10
	group:insert(songContainer)

	songTitleText =
		display.newText(
		{
			text = "",
			font = titleFont,
			align = "center",
			fontSize = 15
		}
	)
	songTitleText.anchorX = 0
	songTitleText.x = -(songTitleText.contentWidth * 0.5)
	songTitleText.scrollTimer = nil
	songTitleText:setFillColor(0.9, 0.9, 0.9)
	songContainer:insert(songTitleText)

	function songTitleText:enterFrame()
		if (songTitleText and songTitleText.contentWidth > songContainer.contentWidth) then
			songTitleText.x = songTitleText.x - 1

			if (songTitleText.x + songTitleText.contentWidth < -songTitleText.contentWidth * 0.4) then
				songTitleText.x = songContainer.x + songContainer.contentWidth * 0.25
			end
		end

		if (songAlbumText and songAlbumText.contentWidth > songContainer.contentWidth) then
			songAlbumText.x = songAlbumText.x - 1

			if (songAlbumText.x + songAlbumText.contentWidth < -songAlbumText.contentWidth * 0.4) then
				songAlbumText.x = songContainer.x + songContainer.contentWidth * 0.25
			end
		end
	end

	function songTitleText:setText(title)
		self.text = title

		if (self.contentWidth > songContainer.contentWidth) then
			self.x = -(self.contentWidth * 0.40)
		else
			self.x = -(self.contentWidth * 0.5)
		end

		Runtime:removeEventListener("enterFrame", songTitleText)

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		if (self.contentWidth > songContainer.contentWidth) then
			self.scrollTimer =
				timer.performWithDelay(
				3000,
				function()
					Runtime:addEventListener("enterFrame", songTitleText)
				end
			)
		end
	end

	songAlbumText =
		display.newText(
		{
			text = "",
			font = subTitleFont,
			align = "center",
			fontSize = 12
		}
	)
	songAlbumText.anchorX = 0
	songAlbumText.x = -(songAlbumText.contentWidth * 0.5)
	songAlbumText.y = songTitleText.contentHeight
	songAlbumText:setFillColor(0.6, 0.6, 0.6)
	songContainer:insert(songAlbumText)
	function songAlbumText:setText(album)
		self.text = album

		if (self.contentWidth > songContainer.contentWidth) then
			self.x = -(self.contentWidth * 0.40)
		else
			self.x = -(self.contentWidth * 0.5)
		end
	end

	loopButton =
		widget.newSwitch(
		{
			style = "checkbox",
			id = "loop",
			onPress = function(event)
				audioLib.loopOne = event.target.isOn
			end
		}
	)
	loopButton.width = buttonSize
	loopButton.height = buttonSize
	loopButton.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset)
	loopButton.y = previousButton.y
	loopButton._viewOff:setFillColor(0.7, 0.7, 0.7)
	group:insert(loopButton)

	songProgressView =
		progressView.new(
		{
			width = dWidth / 2 - 10
		}
	)
	songProgressView.anchorX = 0
	songProgressView.x = songContainerBox.x + 2
	songProgressView.y = songContainerBox.y + songAlbumText.contentHeight + songProgressView.contentHeight + 1
	group:insert(songProgressView)

	volumeOnButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "volume-button.png",
			overFile = overButtonPath .. "volume-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				audioLib.setVolume(0)
				volumeSlider:setValue(0)
				event.target.isVisible = false
				volumeOffButton.isVisible = true
			end
		}
	)
	volumeOnButton.x = (songProgressView.x + songProgressView.actualWidth + controlButtonsXOffset + 20)
	volumeOnButton.y = previousButton.y
	group:insert(volumeOnButton)

	volumeOffButton =
		widget.newButton(
		{
			defaultFile = defaultButtonPath .. "volume-off-button.png",
			overFile = overButtonPath .. "volume-off-button.png",
			width = buttonSize,
			height = buttonSize,
			onPress = function(event)
				audioLib.setVolume(audioLib.getPreviousVolume())
				volumeSlider:setValue(audioLib.getVolume() * 100)
				event.target.isVisible = false
				volumeOnButton.isVisible = true
			end
		}
	)
	volumeOffButton.x = volumeOnButton.x
	volumeOffButton.y = previousButton.y
	volumeOffButton.isVisible = false
	group:insert(volumeOffButton)

	volumeSlider =
		widget.newSlider(
		{
			width = 100,
			value = 100,
			listener = function(event)
				audioLib.setVolume(event.value / 100)
			end
		}
	)
	volumeSlider.height = volumeSlider.height / 1.5
	volumeSlider.x = (volumeOnButton.x + (volumeOnButton.contentWidth) + 2)
	volumeSlider.y = previousButton.y - 4
	group:insert(volumeSlider)

	levelVisualizer = levelVisualization.new()
	levelVisualizer.x = volumeSlider.x + volumeSlider.contentWidth * 0.5 + 15
	levelVisualizer.y = volumeOnButton.y
	group:insert(levelVisualizer)

	playBackTimeText =
		display.newText(
		{
			text = "00:00/00:00",
			font = titleFont,
			fontSize = 10,
			align = "left"
		}
	)
	playBackTimeText.x = levelVisualizer.x + levelVisualizer.contentWidth
	playBackTimeText.y = levelVisualizer.y + levelVisualizer.contentHeight + playBackTimeText.contentHeight
	group:insert(playBackTimeText)

	function playBackTimeText:update()
		local playbackTime = audioLib.getPlaybackTime()
		local pbElapsed = playbackTime.elapsed
		local pbDuration = playbackTime.duration
		playBackTimeText.text =
			sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds)
	end

	return group
end

function M.setMusicData(songData)
	musicData = songData
end

function M.resetSongProgress()
	playBackTimeText.text = "00:00/00:00"
	songProgressView:setElapsedProgress(0)
	songProgressView:setOverallProgress(0)
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

	albumArtwork = display.newImageRect(fileName, system.DocumentsDirectory, 30, 30)
	albumArtwork.anchorX = 0
	albumArtwork.x = songContainerBox.x + 5
	albumArtwork.y = songContainerBox.y - 2.5
end

function M.updatePlayPauseState(playing)
	if (playing) then
		playButton.isVisible = false
		pauseButton.isVisible = true
	else
		playButton.isVisible = true
		pauseButton.isVisible = false
	end
end

function M.updateSongText(songTitle, songAlbum)
	if (musicData ~= nil) then
		songTitleText:setText(musicData[audioLib.currentSongIndex].tags.title)
		songAlbumText:setText(musicData[audioLib.currentSongIndex].tags.album)
	end
end

function M.updatePlaybackTime()
	playBackTimeText:update()
end

return M
