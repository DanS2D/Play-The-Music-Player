local M = {
	lastSearchQuery = nil
}
local sqlite3 = require("sqlite3")
local json = require("json")
local crypto = require("crypto")
local jEncode = json.encode
local jDecode = json.decode
local cDigest = crypto.digest
local sFormat = string.format
local database = nil
local settingsBinds =
	"(:key, :musicFolderPaths, :volume, :loopOne, :loopAll, :shuffle, :lastPlayedSongIndex, :lastPlayedSongTime, :fadeInTrack, :fadeOutTrack, :fadeInTime, :fadeOutTime, :crossFade, :displayAlbumArtwork, :columnOrder, :hiddenColumns, :columnSizes, :lastUsedColumn, :lastUsedColumnSortAToZ, :showVisualizer, :lastView, :selectedVisualizers)"
local musicBinds =
	"(:key, :fileName, :filePath, :md5, :title, :artist, :album, :genre, :comment, :year, :trackNumber, :rating, :duration, :bitrate, :sampleRate)"

local function createTables()
	-- the playlist table simply holds the name and id of the playlists. Each playlist should be
	-- it's own table. When adding a playlist, add it's name and primary key to the playlists table so it can be referenced.
	-- when removing it, also remove its entry from the playlists master table.
	database:exec(
		[[CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY, musicFolderPaths TEXT, volume REAL, loopOne INTEGER, loopAll INTEGER, shuffle INTEGER, lastPlayedSongIndex INTEGER, lastPlayedSongTime TEXT, fadeInTrack INTEGER, fadeOutTrack INTEGER, fadeInTime INTEGER, fadeOutTime INTEGER, crossFade INTEGER, displayAlbumArtwork INTEGER, columnOrder TEXT, hiddenColumns TEXT, columnSizes TEXT, lastUsedColumn TEXT, lastUsedColumnSortAToZ INTEGER, showVisualizer INTEGER, lastView TEXT, selectedVisualizers TEXT);]]
	)
	database:exec(
		[[CREATE TABLE IF NOT EXISTS music (id INTEGER PRIMARY KEY, fileName TEXT, filePath TEXT, md5 TEXT, title TEXT, artist TEXT, album TEXT, genre TEXT, comment TEXT, year INTEGER, trackNumber INTEGER, rating REAL, duration INTEGER, bitrate INTEGER, sampleRate INTEGER);]]
	)
	database:exec([[CREATE TABLE IF NOT EXISTS playlists (id INTEGER PRIMARY KEY, name TEXT, key INTEGER);]])
	database:exec([[CREATE INDEX IF NOT EXISTS musicIndex on music (album, artist, genre, title);]])
	database:exec([[CREATE INDEX IF NOT EXISTS musicAlbumIndex on music (album);]])
	database:exec([[CREATE INDEX IF NOT EXISTS musicArtistIndex on music (artist);]])
	database:exec([[CREATE INDEX IF NOT EXISTS musicTitleIndex on music (title);]])
end

function M:open()
	if (database == nil) then
		local databasePath = system.pathForFile("music.db", system.DocumentsDirectory)
		database = sqlite3.open(databasePath)

		if (database) then
			createTables()
		else
			print("ERROR: there was a problem opening the database")
		end
	end
end

local function createOrReplaceSettings(settings, replace)
	local stmt = nil

	if (replace) then
		stmt = database:prepare(sFormat([[ REPLACE INTO `settings` VALUES %s; ]], settingsBinds))
	else
		stmt = database:prepare(sFormat([[ INSERT INTO `settings` VALUES %s; ]], settingsBinds))
	end

	local userSettings = {}

	for k, v in pairs(settings) do
		if (type(v) ~= "function" and type(v) ~= "userdata") then
			userSettings[k] = v
		end
	end

	stmt:bind_names(
		{
			key = 1,
			musicFolderPaths = jEncode(userSettings.musicFolderPaths),
			volume = userSettings.volume,
			loopOne = userSettings.loopOne,
			loopAll = userSettings.loopAll,
			shuffle = userSettings.shuffle,
			lastPlayedSongIndex = userSettings.lastPlayedSongIndex,
			lastPlayedSongTime = jEncode(userSettings.lastPlayedSongTime),
			fadeInTrack = userSettings.fadeInTrack,
			fadeOutTrack = userSettings.fadeOutTrack,
			fadeInTime = userSettings.fadeInTime,
			fadeOutTime = userSettings.fadeOutTime,
			crossFade = userSettings.crossFade,
			displayAlbumArtwork = userSettings.displayAlbumArtwork,
			columnOrder = jEncode(userSettings.columnOrder),
			hiddenColumns = jEncode(userSettings.hiddenColumns),
			columnSizes = jEncode(userSettings.columnSizes),
			lastUsedColumn = userSettings.lastUsedColumn,
			lastUsedColumnSortAToZ = userSettings.lastUsedColumnSortAToZ,
			showVisualizer = userSettings.showVisualizer,
			lastView = userSettings.lastView,
			selectedVisualizers = jEncode(userSettings.selectedVisualizers)
		}
	)
	stmt:step()
	stmt:finalize()
	stmt = nil
	userSettings = nil
end

function M:insertSettings(settings)
	createOrReplaceSettings(settings, false)
end

function M:updateSettings(settings)
	createOrReplaceSettings(settings, true)
end

function M:getSettings()
	local stmt = database:prepare([[ SELECT * FROM `settings`; ]])
	local settings = nil

	for row in stmt:nrows() do
		settings = {
			musicFolderPaths = jDecode(row.musicFolderPaths),
			volume = row.volume,
			loopOne = row.loopOne,
			loopAll = row.loopAll,
			shuffle = row.shuffle,
			lastPlayedSongIndex = row.lastPlayedSongIndex,
			lastPlayedSongTime = jDecode(row.lastPlayedSongTime),
			fadeInTrack = row.fadeInTrack,
			fadeOutTrack = row.fadeOutTrack,
			crossFade = row.crossFade,
			displayAlbumArtwork = row.displayAlbumArtwork,
			columnOrder = jDecode(row.columnOrder),
			hiddenColumns = jDecode(row.hiddenColumns),
			columnSizes = jDecode(row.columnSizes),
			lastUsedColumn = row.lastUsedColumn,
			lastUsedColumnSortAToZ = row.lastUsedColumnSortAToZ,
			showVisualizer = row.showVisualizer,
			selectedVisualizers = jDecode(row.selectedVisualizers),
			lastView = row.lastView
		}
	end

	stmt:finalize()
	stmt = nil

	return settings
end

function M:insertMusic(musicData)
	local hash = cDigest(crypto.md5, musicData.title .. musicData.album)
	local stmt = database:prepare(sFormat([[ INSERT INTO `music` VALUES %s; ]], musicBinds))

	stmt:bind_names(
		{
			fileName = musicData.fileName,
			filePath = musicData.filePath,
			md5 = hash, -- use this when doing music database lookups
			title = musicData.title,
			artist = musicData.artist,
			album = musicData.album,
			genre = musicData.genre,
			comment = musicData.comment,
			year = musicData.year,
			trackNumber = musicData.trackNumber,
			rating = musicData.rating,
			duration = musicData.duration,
			bitrate = musicData.bitrate,
			sampleRate = musicData.sampleRate
		}
	)
	stmt:step()
	stmt:finalize()
	musicData = nil
	stmt = nil
end

function M:removeMusic(id)
	local stmt = database:prepare(sFormat([[ DELETE FROM `music` WHERE id=%d; ]], id))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:getMusicRow(index)
	local stmt = database:prepare(sFormat([[ SELECT * FROM `music` WHERE id=%d; ]], index))
	local music = nil

	for row in stmt:nrows() do
		music = {
			id = row.id,
			fileName = row.fileName,
			filePath = row.filePath,
			rating = row.rating,
			md5 = row.md5,
			album = row.album,
			artist = row.artist,
			genre = row.genre,
			publisher = row.publisher,
			title = row.title,
			track = row.track,
			duration = row.duration
		}
	end

	stmt:finalize()
	stmt = nil

	return music
end

local function getMusicRowBy(index, ascending, filter)
	local stmt = nil
	local orderType = ascending and "ASC" or "DESC"
	local music = nil

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat([[ SELECT * FROM `music` ORDER BY %s %s LIMIT 1 OFFSET %d; ]], filter, orderType, index - 1)
		)
	else
		stmt = database:prepare(sFormat([[ SELECT * FROM `music` ORDER BY %s %s LIMIT 1;]], filter, orderType))
	end

	for row in stmt:nrows() do
		music = {
			id = row.id,
			fileName = row.fileName,
			filePath = row.filePath,
			rating = row.rating,
			md5 = row.md5,
			album = row.album,
			artist = row.artist,
			genre = row.genre,
			publisher = row.publisher,
			title = row.title,
			track = row.track,
			duration = row.duration
		}
	end

	stmt:finalize()
	stmt = nil

	return music
end

function M:getMusicRowByAlbum(index, ascending)
	return getMusicRowBy(index, ascending, "album")
end

function M:getMusicRowByArtist(index, ascending)
	return getMusicRowBy(index, ascending, "artist")
end

function M:getMusicRowByDuration(index, ascending)
	return getMusicRowBy(index, ascending, "duration")
end

function M:getMusicRowByGenre(index, ascending)
	return getMusicRowBy(index, ascending, "genre")
end

function M:getMusicRowByRating(index, ascending)
	return getMusicRowBy(index, ascending, "rating")
end

function M:getMusicRowByTitle(index, ascending)
	return getMusicRowBy(index, ascending, "title")
end

function M:getMusicRowBySearch(index, ascending, search, limit)
	local stmt = nil
	local orderType = ascending and "ASC" or "DESC"
	local music = nil
	-- %% SEARCH %% == anywhere in the string
	-- SEARCH %% == begins with string
	-- %% SEARCH == ends with string
	local likeQuery = sFormat("LIKE '%%%s%%'", search)
	local artistQuery = sFormat("OR artist %s", likeQuery)
	local titleQuery = sFormat("OR title %s", likeQuery)
	self.lastSearchQuery = sFormat([[WHERE album %s %s %s; ]], likeQuery, artistQuery, titleQuery)

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `music` WHERE album %s %s %s ORDER BY title %s LIMIT 1 OFFSET %d; ]],
				likeQuery,
				artistQuery,
				titleQuery,
				orderType,
				index - 1
			)
		)
	else
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `music` WHERE album %s %s %s ORDER BY title %s LIMIT 1; ]],
				likeQuery,
				artistQuery,
				titleQuery,
				orderType
			)
		)
	end

	for row in stmt:nrows() do
		music = {
			id = row.id,
			fileName = row.fileName,
			filePath = row.filePath,
			rating = row.rating,
			md5 = row.md5,
			album = row.album,
			artist = row.artist,
			genre = row.genre,
			publisher = row.publisher,
			title = row.title,
			track = row.track,
			duration = row.duration
		}
	end

	stmt:finalize()
	stmt = nil

	return music
end

function M:getMusicRowsBySearch(index, ascending, orderBy, search, limit)
	local stmt = nil
	local orderType = ascending and "ASC" or "DESC"
	local music = {}
	-- %% SEARCH %% == anywhere in the string
	-- SEARCH %% == begins with string
	-- %% SEARCH == ends with string
	local likeQuery = sFormat("LIKE '%%%s%%'", search)
	local artistQuery = sFormat("OR artist %s", likeQuery)
	local titleQuery = sFormat("OR title %s", likeQuery)
	self.lastSearchQuery = sFormat([[WHERE album %s %s %s; ]], likeQuery, artistQuery, titleQuery)

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `music` WHERE album %s %s %s ORDER BY %s %s LIMIT %d OFFSET %d; ]],
				likeQuery,
				artistQuery,
				titleQuery,
				orderBy,
				orderType,
				limit,
				index - 1
			)
		)
	else
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `music` WHERE album %s %s %s ORDER BY %s %s LIMIT %d; ]],
				likeQuery,
				artistQuery,
				titleQuery,
				orderBy,
				orderType,
				limit
			)
		)
	end

	for row in stmt:nrows() do
		music[#music + 1] = {
			id = row.id,
			fileName = row.fileName,
			filePath = row.filePath,
			rating = row.rating,
			md5 = row.md5,
			album = row.album,
			artist = row.artist,
			genre = row.genre,
			publisher = row.publisher,
			title = row.title,
			track = row.track,
			duration = row.duration
		}
	end

	stmt:finalize()
	stmt = nil

	return music
end

function M:musicCount()
	local stmt = database:prepare([[ SELECT COUNT(*) AS count FROM `music`; ]])
	local count = 0

	for row in stmt:nrows() do
		count = row.count
		break
	end

	stmt:finalize()
	stmt = nil

	return count
end

function M:searchCount()
	if (self.lastSearchQuery == nil) then
		return 0
	end

	local stmt = database:prepare(sFormat([[ SELECT COUNT(*) AS count FROM `music` %s ]], self.lastSearchQuery))
	local count = 0

	for row in stmt:nrows() do
		count = row.count
		break
	end

	stmt:finalize()
	stmt = nil

	return count
end

function M:close()
	database:close()
	database = nil
end

return M
