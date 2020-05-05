local M = {
	item = {
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
		fadeInTracks = false,
		fadeOutTracks = false,
		crossFade = false,
		displayAlbumArtwork = true,
		columnOrder = {},
		hiddenColumns = {},
		columnSizes = {},
		lastUsedColumn = "",
		lastUsedColumnSortAToZ = true,
		showVisualizer = true,
		lastView = "musicList"
	}
}
local sqlLib = require("libs.sql-lib")

function M.load()
	sqlLib.open()
	sqlLib.insertSettings(M.item)
	M.item = sqlLib.getSettings()
end

function M.save()
	sqlLib.updateSettings(M.item)
end

return M
