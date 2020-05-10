local M = {}
local widget = require("widget")
local audioLib = require("libs.audio-lib")
local buttonLib = require("libs.ui.button")
local multiButtonLib = require("libs.ui.multi-button")
local switchLib = require("libs.ui.switch")
local musicList = require("libs.ui.music-list")
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
local songTitleText = nil
local songAlbumText = nil
local songProgressView = nil
local previousButton = nil
local playButton = nil
local nextButton = nil
local shuffleButton = nil
local volumeButton = nil
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
		buttonLib.new(
		{
			iconName = "step-backward",
			fontSize = 18,
			parent = group,
			onClick = function(event)
				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				if (audioLib.currentSongIndex - 1 > 0) then
					audioLib.currentSongIndex = audioLib.currentSongIndex - 1
					local previousSong = musicList:getRow(audioLib.currentSongIndex)

					playButton:setIsOn(true)
					musicList:setSelectedRow(audioLib.currentSongIndex)
					audioLib.load(previousSong)
					audioLib.play(previousSong)
				end
			end
		}
	)
	previousButton.x = (dScreenOriginX + (previousButton.contentWidth * 0.5) + controlButtonsXOffset)
	previousButton.y = 55

	playButton =
		switchLib.new(
		{
			offIconName = "play",
			onIconName = "pause",
			fontSize = 18,
			parent = group,
			onClick = function(event)
				local target = event.target

				if (target.isOffButton) then
					if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
						playButton:setIsOn(false)
						return
					end

					if (audioLib.isChannelHandleValid()) then
						if (audioLib.isChannelPlaying()) then
							return
						end

						if (audioLib.isChannelPaused()) then
							audioLib.resume()
							musicVisualizer.start()
							return
						end
					end
				else
					if (not musicList:hasValidMusicData()) then
						return
					end

					if (audioLib.isChannelHandleValid()) then
						if (audioLib.isChannelPlaying()) then
							audioLib.pause()
							musicVisualizer.pause()
						end
					end
				end
			end
		}
	)
	playButton.x = (previousButton.x + previousButton.contentWidth + controlButtonsXOffset)
	playButton.y = previousButton.y
	group:insert(playButton)

	nextButton =
		buttonLib.new(
		{
			iconName = "step-forward",
			fontSize = 18,
			parent = group,
			onClick = function(event)
				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				if (audioLib.currentSongIndex + 1 <= musicList:getMusicCount()) then
					audioLib.currentSongIndex = audioLib.currentSongIndex + 1
					local nextSong = musicList:getRow(audioLib.currentSongIndex)

					playButton:setIsOn(true)
					musicList:setSelectedRow(audioLib.currentSongIndex)
					audioLib.load(nextSong)
					audioLib.play(nextSong)
				end
			end
		}
	)
	nextButton.x = (playButton.x + playButton.contentWidth + controlButtonsXOffset)
	nextButton.y = previousButton.y
	group:insert(nextButton)

	loopButton =
		multiButtonLib.new(
		{
			fontSize = 18,
			buttonOptions = {
				{
					iconName = "repeat",
					name = "off",
					alpha = 0.6,
					onClick = function(event)
						audioLib.loopAll = true
						audioLib.loopOne = false
					end
				},
				{
					iconName = "repeat",
					name = "repeatAll",
					onClick = function(event)
						audioLib.loopOne = true
						audioLib.loopAll = false
					end
				},
				{
					iconName = "repeat-1",
					name = "repeatOne",
					onClick = function(event)
						audioLib.loopAll = false
						audioLib.loopOne = false
					end
				}
			}
		}
	)
	loopButton.x = (nextButton.x + nextButton.contentWidth + controlButtonsXOffset)
	loopButton.y = previousButton.y
	group:insert(loopButton)

	shuffleButton =
		switchLib.new(
		{
			offIconName = "random",
			onIconName = "random",
			offAlpha = 0.6,
			fontSize = 18,
			parent = group,
			onClick = function(event)
				local target = event.target
				audioLib.shuffle = target.isOffButton
			end
		}
	)
	shuffleButton.x = (loopButton.x + loopButton.contentWidth + controlButtonsXOffset)
	shuffleButton.y = previousButton.y
	group:insert(shuffleButton)

	musicVisualizerBar = musicVisualizer.new({})
	musicVisualizerBar.x = display.contentCenterX
	musicVisualizerBar.y = shuffleButton.y - 5
	group:insert(musicVisualizerBar)

	songContainerBox = display.newRoundedRect(0, 0, dWidth / 2 - 8, 50, 2)
	songContainerBox.anchorX = 0
	songContainerBox.x = (shuffleButton.x + controlButtonsXOffset + 14)
	songContainerBox.y = shuffleButton.y - 5
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

	songProgressView =
		progressView.new(
		{
			width = dWidth / 2 - 10,
			allowTouch = true
		}
	)
	songProgressView.anchorX = 0
	songProgressView.x = songContainerBox.x + 2
	songProgressView.y = songContainerBox.y + songAlbumText.contentHeight + songProgressView.contentHeight + 1
	group:insert(songProgressView)

	volumeButton =
		switchLib.new(
		{
			offIconName = "volume-slash",
			onIconName = "volume-up",
			fontSize = 18,
			parent = group,
			onClick = function(event)
				local target = event.target

				if (target.isOffButton) then
					audioLib.setVolume(audioLib.getPreviousVolume())
					volumeSlider:setValue(audioLib.getVolume() * 100)
				else
					audioLib.setVolume(0)
					volumeSlider:setValue(0)
				end
			end
		}
	)
	volumeButton.x = (songProgressView.x + songProgressView.actualWidth + controlButtonsXOffset + 20)
	volumeButton.y = previousButton.y
	volumeButton:setIsOn(true)
	group:insert(volumeButton)

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
	volumeSlider.x = (volumeButton.x + volumeButton.contentWidth)
	volumeSlider.y = previousButton.y - 4
	group:insert(volumeSlider)

	levelVisualizer = levelVisualization.new()
	levelVisualizer.x = volumeSlider.x + volumeSlider.contentWidth * 0.5 + 15
	levelVisualizer.y = volumeButton.y
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

		if (playbackTime) then
			local pbElapsed = playbackTime.elapsed
			local pbDuration = playbackTime.duration
			playBackTimeText.text =
				sFormat("%02d:%02d/%02d:%02d", pbElapsed.minutes, pbElapsed.seconds, pbDuration.minutes, pbDuration.seconds)
		end
	end

	return group
end

function M.resetSongProgress()
	playBackTimeText.text = "00:00/00:00"
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

	albumArtwork = display.newImageRect(fileName, system.DocumentsDirectory, 30, 30)
	albumArtwork.anchorX = 0
	albumArtwork.x = songContainerBox.x + 5
	albumArtwork.y = songContainerBox.y - 2.5
end

function M.updatePlayPauseState(playing)
	playButton:setIsOn(playing)
end

function M.clearPlayingSong()
	if (albumArtwork) then
		display.remove(albumArtwork)
		albumArtwork = nil
	end

	songTitleText:setText("")
	songAlbumText:setText("")
end

function M.updateSongText(song)
	songTitleText:setText(song.title)
	songAlbumText:setText(song.album)
end

function M.updatePlaybackTime()
	playBackTimeText:update()
end

return M
