local M = {
	musicFolderPaths = {},
	volume = 1.0,
	loopOne = false,
	loopAll = false,
	shuffle = false,
	lastPlayedSongIndex = 0,
	lastPlayedSongTime = {
		duration = {minutes = 0, seconds = 0},
		elapsed = {minutes = 0, seconds = 0}
	},
	fadeInTrack = false,
	fadeOutTrack = false,
	fadeInTime = 3000,
	fadeOutTime = 3000,
	crossFade = false,
	displayAlbumArtwork = true,
	columnOrder = {},
	hiddenColumns = {},
	columnSizes = {},
	lastUsedColumn = "",
	lastUsedColumnSortAToZ = true,
	showVisualizer = true,
	theme = "dark",
	selectedVisualizers = {},
	lastView = "musicList"
}
local sqlLib = require("libs.sql-lib")
local hasLoadedSettings = false

function M:load()
	sqlLib:open()

	local settings = sqlLib:getSettings()

	if (settings) then
		for k, v in pairs(settings) do
			self[k] = v
		end

		hasLoadedSettings = true
	else
		sqlLib:insertSettings(self)
	end
end

function M:save()
	if (not hasLoadedSettings) then
		self:load()
	end

	sqlLib:updateSettings(self)
end

return M
