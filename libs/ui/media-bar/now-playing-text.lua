local M = {}
local sqlLib = require("libs.sql-lib")
local theme = require("libs.theme")
local common = require("libs.ui.media-bar.common")
local eventDispatcher = require("libs.event-dispatcher")
local uPack = unpack

function M.new(parent, songContainer)
	local songTitleText =
		display.newText(
		{
			text = "",
			font = common.titleFont,
			align = "center",
			fontSize = 22
		}
	)
	songTitleText.anchorX = 0
	songTitleText.x = -(songTitleText.contentWidth * 0.5)
	songTitleText.y = -(songTitleText.contentHeight * 0.5) - 7
	songTitleText.scrollTimer = nil
	songTitleText:setFillColor(uPack(theme:get().textColor.primary))
	songContainer:insert(songTitleText)

	songTitleText.copy =
		display.newText(
		{
			text = "",
			font = common.titleFont,
			align = "center",
			fontSize = 22
		}
	)
	songTitleText.copy.anchorX = 0
	songTitleText.copy.x = songTitleText.x
	songTitleText.copy.y = songTitleText.y
	songTitleText.copy:setFillColor(uPack(theme:get().textColor.primary))
	songContainer:insert(songTitleText.copy)

	function songTitleText:restartListener()
		self:removeEventListener("enterFrame", self)

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self.scrollTimer =
			timer.performWithDelay(
			3000,
			function()
				self:addEventListener("enterFrame", self)
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

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self:removeEventListener("enterFrame", self)

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

	local songAlbumText =
		display.newText(
		{
			text = "",
			font = common.subTitleFont,
			align = "center",
			fontSize = 19
		}
	)
	songAlbumText.anchorX = 0
	songAlbumText.x = -(songAlbumText.contentWidth * 0.5)
	songAlbumText.y = songTitleText.y + (songTitleText.contentHeight * 0.5) + 8
	songAlbumText.scrollTimer = nil
	songAlbumText:setFillColor(uPack(theme:get().textColor.secondary))
	songContainer:insert(songAlbumText)

	songAlbumText.copy =
		display.newText(
		{
			text = "",
			font = common.subTitleFont,
			align = "center",
			fontSize = 19
		}
	)
	songAlbumText.copy.anchorX = 0
	songAlbumText.copy.x = -(songAlbumText.contentWidth * 0.5)
	songAlbumText.copy.y = songTitleText.y + (songTitleText.contentHeight * 0.5) + 8
	songAlbumText.copy:setFillColor(uPack(theme:get().textColor.secondary))
	songContainer:insert(songAlbumText.copy)

	function songAlbumText:restartListener()
		local startTime = songTitleText.scrollTimer == nil and 3000 or 6000
		self:removeEventListener("enterFrame", self)

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self.scrollTimer =
			timer.performWithDelay(
			startTime,
			function()
				self:addEventListener("enterFrame", self)
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

		if (self.scrollTimer) then
			timer.cancel(self.scrollTimer)
			self.scrollTimer = nil
		end

		self:removeEventListener("enterFrame", self)

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

	return songTitleText, songAlbumText
end

return M
