local M = {}
local audioLib = require("libs.audio-lib")
local buttonLib = require("libs.ui.button")
local multiButtonLib = require("libs.ui.multi-button")
local switchLib = require("libs.ui.switch")
local musicList = require("libs.ui.music-list")
local mainMenuBar = require("libs.ui.main-menu-bar")
local levelVisualization = require("libs.ui.level-visualizer")
local musicVisualizer = require("libs.ui.music-visualizer")
local progressView = require("libs.ui.progress-view")
local ratings = require("libs.ui.ratings")
local volumeSliderLib = require("libs.ui.volume-slider")
local settings = require("libs.settings")
local dScreenOriginX = display.screenOriginX
local dScreenOriginY = display.dScreenOriginY
local dCenterX = display.contentCenterX
local dCenterY = display.contentCenterY
local dWidth = display.contentWidth
local dHeight = display.contentHeight
local sFormat = string.format
local mAbs = math.abs
local mMin = math.min
local mMax = math.max
local mRandom = math.random
local mSqrt = math.sqrt
local smallButtonFontSize = 20
local mainButtonFontSize = 28
local controlButtonsXOffset = 10
local barHeight = 80
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
local ratingStars = nil
local playBackTimeText = nil
local albumArtwork = nil
local songContainerBox = nil
local songContainer = nil
local musicVisualizerBar = nil
local loopButton = nil
local levelVisualizer = nil
local musicDuration = 0

local function updateMediaBar()
	if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
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
			fontSize = mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local canPlay = true

				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				if (audioLib.shuffle) then
					audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
				else
					if (audioLib.currentSongIndex - 1 > 0) then
						audioLib.currentSongIndex = audioLib.currentSongIndex - 1
					else
						canPlay = false
					end
				end

				if (canPlay) then
					local previousSong = musicList:getRow(audioLib.currentSongIndex)

					musicVisualizer:restart()
					playButton:setIsOn(true)
					musicList:setSelectedRow(audioLib.currentSongIndex)
					audioLib.load(previousSong)
					audioLib.play(previousSong)
				end
			end
		}
	)
	previousButton.x = (dScreenOriginX + previousButton.contentWidth + controlButtonsXOffset)
	previousButton.y = mainMenuBar:getHeight() + previousButton.contentHeight + 18

	playButton =
		switchLib.new(
		{
			offIconName = "play",
			onIconName = "pause",
			fontSize = mainButtonFontSize,
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
			fontSize = mainButtonFontSize,
			parent = group,
			onClick = function(event)
				local canPlay = true

				if (not musicList:hasValidMusicData() or not audioLib.isChannelHandleValid()) then
					return
				end

				if (audioLib.shuffle) then
					audioLib.currentSongIndex = mRandom(1, musicList:getMusicCount())
				else
					if (audioLib.currentSongIndex + 1 <= musicList:getMusicCount()) then
						audioLib.currentSongIndex = audioLib.currentSongIndex + 1
					else
						canPlay = false
					end
				end

				if (canPlay) then
					local nextSong = musicList:getRow(audioLib.currentSongIndex)
					musicVisualizer:restart()
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

	volumeSlider =
		volumeSliderLib.new(
		{
			width = 100,
			value = 100,
			listener = function(event)
				audioLib.setVolume(event.value / 100)
			end,
			onTouchEnded = function(event)
				settings.volume = (event.value / 100)
				settings:save()
			end
		}
	)
	volumeSlider.x = display.contentWidth - volumeSlider.contentWidth - 28
	volumeSlider.y = previousButton.y
	group:insert(volumeSlider)

	volumeButton =
		switchLib.new(
		{
			offIconName = "volume-slash",
			onIconName = "volume-up",
			fontSize = mainButtonFontSize,
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
	volumeButton.x = volumeSlider.x - volumeButton.contentWidth
	volumeButton.y = previousButton.y
	volumeButton:setIsOn(true)
	group:insert(volumeButton)

	musicVisualizerBar = musicVisualizer.new({yPos = 26, group = group})

	songContainerBox = display.newRoundedRect(0, 0, mMax(489, display.contentWidth / 2), barHeight, 2)
	songContainerBox.anchorX = 0
	songContainerBox.x = display.contentCenterX - songContainerBox.contentWidth * 0.5 - 38
	songContainerBox.y = (barHeight - 5)
	songContainerBox.strokeWidth = 1
	songContainerBox:setFillColor(0.1, 0.1, 0.1, 0.8)
	songContainerBox:setStrokeColor(0.6, 0.6, 0.6, 0.5)
	group:insert(songContainerBox)

	songContainer = display.newContainer(songContainerBox.contentWidth - 140, barHeight - 14)
	songContainer.anchorX = 0
	songContainer.x = songContainerBox.x + 105
	songContainer.y = songContainerBox.y - 3
	group:insert(songContainer)

	--[[
	local rect = display.newRect(0, 0, songContainer.contentWidth, songContainer.contentHeight)
	rect.anchorX = 0
	rect.x = songContainer.x
	rect.y = songContainer.y
	group:insert(rect)
	--]]
	shuffleButton =
		switchLib.new(
		{
			offIconName = "random",
			onIconName = "random",
			offAlpha = 0.6,
			fontSize = smallButtonFontSize,
			parent = group,
			onClick = function(event)
				local target = event.target
				audioLib.shuffle = target.isOffButton
			end
		}
	)
	shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
	shuffleButton.y = songContainerBox.y - shuffleButton.contentHeight - 5
	group:insert(shuffleButton)

	loopButton =
		multiButtonLib.new(
		{
			fontSize = smallButtonFontSize,
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
	loopButton.x = songContainerBox.x + songContainerBox.contentWidth - shuffleButton.contentWidth
	loopButton.y = shuffleButton.y
	group:insert(loopButton)

	songTitleText =
		display.newText(
		{
			text = "",
			font = titleFont,
			align = "center",
			fontSize = 22
		}
	)
	songTitleText.anchorX = 0
	songTitleText.x = -(songTitleText.contentWidth * 0.5)
	songTitleText.y = -(songTitleText.contentHeight * 0.5) - 10
	songTitleText.scrollTimer = nil
	songTitleText:setFillColor(0.9, 0.9, 0.9)
	songContainer:insert(songTitleText)

	songTitleText.copy =
		display.newText(
		{
			text = "",
			font = titleFont,
			align = "center",
			fontSize = 22
		}
	)
	songTitleText.copy.anchorX = 0
	songTitleText.copy.x = songTitleText.x
	songTitleText.copy.y = songTitleText.y
	songTitleText.copy:setFillColor(0.9, 0.9, 0.9)
	songContainer:insert(songTitleText.copy)

	function songTitleText:restartListener()
		Runtime:removeEventListener("enterFrame", self)

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self.scrollTimer =
			timer.performWithDelay(
			3000,
			function()
				Runtime:addEventListener("enterFrame", self)
			end
		)
	end

	function songTitleText:enterFrame()
		self.x = self.x - 1
		self.copy.x = self.copy.x - 1

		if (self.x + self.contentWidth < -self.contentWidth * 0.47) then
			self.x = -songContainer.contentWidth * 0.5 + self.contentWidth + 30
		end

		if (self.copy.x <= -songContainer.contentWidth * 0.5) then
			self.copy.x = -songContainer.contentWidth * 0.5 + self.contentWidth + 30
			self.x = -songContainer.contentWidth * 0.5
			self:restartListener()
		end

		return true
	end

	function songTitleText:setText(title)
		self.text = title
		self.copy.text = title

		if (self.contentWidth > songContainer.contentWidth) then
			self.copy.isVisible = true
			self.anchorX = 0
			self.x = -songContainer.contentWidth * 0.5
		else
			self.copy.isVisible = false
			self.anchorX = 0.5
			self.x = 0
		end

		self.copy.x = self.x + self.contentWidth + 30

		if (self.contentWidth > songContainer.contentWidth) then
			self:restartListener()
		end
	end

	songAlbumText =
		display.newText(
		{
			text = "",
			font = subTitleFont,
			align = "center",
			fontSize = 19
		}
	)
	songAlbumText.anchorX = 0
	songAlbumText.x = -(songAlbumText.contentWidth * 0.5)
	songAlbumText.y = songTitleText.y + (songTitleText.contentHeight * 0.5) + 8
	songAlbumText.scrollTimer = nil
	songAlbumText:setFillColor(0.7, 0.7, 0.7)
	songContainer:insert(songAlbumText)

	songAlbumText.copy =
		display.newText(
		{
			text = "",
			font = subTitleFont,
			align = "center",
			fontSize = 19
		}
	)
	songAlbumText.copy.anchorX = 0
	songAlbumText.copy.x = -(songAlbumText.contentWidth * 0.5)
	songAlbumText.copy.y = songTitleText.y + (songTitleText.contentHeight * 0.5) + 8
	songAlbumText.copy:setFillColor(0.7, 0.7, 0.7)
	songContainer:insert(songAlbumText.copy)

	function songAlbumText:restartListener()
		local startTime = songTitleText.scrollTimer == nil and 3000 or 6000
		Runtime:removeEventListener("enterFrame", self)

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self.scrollTimer =
			timer.performWithDelay(
			startTime,
			function()
				Runtime:addEventListener("enterFrame", self)
			end
		)
	end

	function songAlbumText:enterFrame()
		self.x = self.x - 1
		self.copy.x = self.copy.x - 1

		if (self.x + self.contentWidth < -self.contentWidth * 0.47) then
			self.x = -songContainer.contentWidth * 0.5 + self.contentWidth + 30
		end

		if (self.copy.x <= -songContainer.contentWidth * 0.5) then
			self.copy.x = -songContainer.contentWidth * 0.5 + self.contentWidth + 30
			self.x = -songContainer.contentWidth * 0.5
			self:restartListener()
		end

		return true
	end

	function songAlbumText:setText(album)
		self.text = album
		self.copy.text = album

		if (self.contentWidth > songContainer.contentWidth) then
			self.copy.isVisible = true
			self.anchorX = 0
			self.x = -songContainer.contentWidth * 0.5
		else
			self.copy.isVisible = false
			self.anchorX = 0.5
			self.x = 0
		end

		self.copy.x = self.x + self.contentWidth + 30

		if (self.contentWidth > songContainer.contentWidth) then
			self:restartListener()
		end
	end

	levelVisualizer = levelVisualization.new()
	levelVisualizer.x = songContainerBox.x + 28
	levelVisualizer.y = songContainerBox.y + songContainerBox.contentHeight * 0.5 - 12
	levelVisualizer.isVisible = false
	group:insert(levelVisualizer)

	playBackTimeText =
		display.newText(
		{
			text = "00:00/00:00",
			font = titleFont,
			fontSize = 14,
			align = "left"
		}
	)
	playBackTimeText.anchorX = 1
	playBackTimeText.x = songContainerBox.x + songContainerBox.contentWidth - 5
	playBackTimeText.y = songContainerBox.y + (songContainerBox.contentHeight * 0.5) - 16
	playBackTimeText.text = ""
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
	albumArtwork.x = songContainerBox.x + 5
	albumArtwork.y = songContainerBox.y - 3

	if (albumArtwork) then
		shuffleButton.x = songContainerBox.x + 90
	else
		shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
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
		shuffleButton.x = songContainerBox.x + 90
	else
		shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
	end

	levelVisualizer.isVisible = false
	musicDuration = 0
	songTitleText:setText("")
	songAlbumText:setText("")
end

function M.updateSongText(song)
	levelVisualizer.isVisible = true

	if (ratingStars ~= nil) then
		display.remove(ratingStars)
		ratingStars = nil
	end

	if (audioLib.isChannelHandleValid() and audioLib.isChannelPlaying()) then
		musicDuration = audioLib.getDuration() * 1000
	end

	ratingStars =
		ratings.new(
		{
			x = 0,
			y = songAlbumText.y + songAlbumText.contentHeight * 0.5 + 5,
			fontSize = 10,
			rating = song.rating or 0,
			isVisible = true,
			parent = songContainer
		}
	)

	--[[
	songTitleText:setText(
		"This is a ludicrously long text string to get scrolling text working again. Wow, is it long. omg"
	)

	songAlbumText:setText(
		"This is a ludicrously long text string to get scrolling text working again. Wow, is it long. omg. so so so long"
	)--]]
	songTitleText:setText(song.title)
	songAlbumText:setText(song.album)

	if (albumArtwork) then
		shuffleButton.x = songContainerBox.x + 90
	else
		shuffleButton.x = songContainerBox.x + shuffleButton.contentWidth
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
	playBackTimeText.x = songContainerBox.x + songContainerBox.contentWidth - 5
	songProgressView.x = songContainerBox.x
	levelVisualizer.x = songContainerBox.x + 28

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
