local M = {
	lastSearchQuery = nil,
	currentMusicTable = "music"
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
	"(:key, :fileName, :filePath, :md5, :title, :artist, :album, :genre, :comment, :year, :trackNumber, :rating, :duration, :bitrate, :sampleRate, :sortTitle, :albumSearch, :artistSearch, :titleSearch)"
local playListTableBinds = "(:key, :md5, :name)"
local function createTables()
	-- the playlist table simply holds the name and id of the playlists. Each playlist should be
	-- it's own table. When adding a playlist, add it's name and primary key to the playlists table so it can be referenced.
	-- when removing it, also remove its entry from the playlists master table.
	database:exec(
		[[CREATE TABLE IF NOT EXISTS `settings` (id INTEGER PRIMARY KEY, musicFolderPaths TEXT, volume REAL, loopOne INTEGER, loopAll INTEGER, shuffle INTEGER, lastPlayedSongIndex INTEGER, lastPlayedSongTime TEXT, fadeInTrack INTEGER, fadeOutTrack INTEGER, fadeInTime INTEGER, fadeOutTime INTEGER, crossFade INTEGER, displayAlbumArtwork INTEGER, columnOrder TEXT, hiddenColumns TEXT, columnSizes TEXT, lastUsedColumn TEXT, lastUsedColumnSortAToZ INTEGER, showVisualizer INTEGER, lastView TEXT, selectedVisualizers TEXT);]]
	)
	database:exec(
		[[CREATE TABLE IF NOT EXISTS `music` (id INTEGER PRIMARY KEY, fileName TEXT, filePath TEXT, md5 TEXT, title TEXT, artist TEXT, album TEXT, genre TEXT, comment TEXT, year INTEGER, trackNumber INTEGER, rating REAL, duration INTEGER, bitrate INTEGER, sampleRate INTEGER, sortTitle TEXT, albumSearch TEXT, artistSearch TEXT, titleSearch TEXT, UNIQUE(md5));]]
	)
	database:exec([[CREATE TABLE IF NOT EXISTS `playlists` (id INTEGER PRIMARY KEY, md5 TEXT, name TEXT, UNIQUE(md5));]])
	database:exec([[CREATE INDEX IF NOT EXISTS `musicIndex` on music (album, artist, genre, title);]])
	database:exec([[CREATE INDEX IF NOT EXISTS `musicAlbumIndex` on music (album);]])
	database:exec([[CREATE INDEX IF NOT EXISTS `musicArtistIndex` on music (artist);]])
	database:exec([[CREATE INDEX IF NOT EXISTS `musicTitleIndex` on music (title);]])
end

local function escapeString(string)
	return string:gsub("'", "''")
end

local function buildUpdateString(data)
	local builtString = ""
	local index = 1

	for k, v in pairs(data) do
		if (k ~= "key" and k ~= "id") then
			if (index == 1) then
				if (type(v) == "string") then
					builtString = sFormat("%s = '%s'", k, v)
				elseif (type(v) == "number") then
					builtString = sFormat("%s = '%d'", k, v)
				end
			else
				if (type(v) == "string") then
					builtString = sFormat("%s, %s = '%s'", builtString, k, v)
				elseif (type(v) == "number") then
					builtString = sFormat("%s, %s = '%d'", builtString, k, v)
				end
			end

			index = index + 1
		end
	end

	return builtString
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

	if (stmt) then
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
	end

	return settings
end

function M:createPlaylist(name)
	database:exec(
		sFormat(
			[[CREATE TABLE IF NOT EXISTS `%sPlaylist` (id INTEGER PRIMARY KEY, fileName TEXT, filePath TEXT, md5 TEXT, title TEXT, artist TEXT, album TEXT, genre TEXT, comment TEXT, year INTEGER, trackNumber INTEGER, rating REAL, duration INTEGER, bitrate INTEGER, sampleRate INTEGER, sortTitle TEXT, albumSearch TEXT, artistSearch TEXT, titleSearch TEXT, UNIQUE(md5));]],
			name
		)
	)
	local hash = cDigest(crypto.md5, name)
	local stmt = database:prepare(sFormat([[ INSERT OR IGNORE INTO `playlists` VALUES %s; ]], playListTableBinds))
	stmt:bind_names({name = name, md5 = hash})
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:getPlaylists()
	local stmt = database:prepare(sFormat([[ SELECT * FROM `playlists`; ]]))
	local playlists = {}

	for row in stmt:nrows() do
		playlists[#playlists + 1] = {
			id = row.id,
			name = row.name
		}
	end

	stmt:finalize()
	stmt = nil

	return playlists
end

function M:updatePlaylistName(currentName, newName)
	local hash = cDigest(crypto.md5, currentName)

	local stmt =
		database:prepare(sFormat([[ UPDATE `playlists` SET name='%s' WHERE md5='%s'; ]], escapeString(newName), hash))
	stmt:step()
	stmt:finalize()
	stmt = nil

	local stmt =
		database:prepare(sFormat([[ UPDATE `playlists` SET md5='%s' WHERE md5='%s'; ]], cDigest(crypto.md5, newName), hash))
	stmt:step()
	stmt:finalize()
	stmt = nil

	local stmt =
		database:prepare(sFormat([[ ALTER TABLE `%sPlaylist` RENAME TO '%sPlayList'; ]], currentName, escapeString(newName)))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:removePlaylist(playlistName)
	local hash = cDigest(crypto.md5, playlistName)
	local stmt = database:prepare(sFormat([[ DELETE FROM `playlists` WHERE md5='%s'; ]], hash))
	stmt:step()
	stmt:finalize()
	stmt = nil

	local stmt = database:prepare(sFormat([[ DROP TABLE '%sPlaylist'; ]], playlistName))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:addToPlaylist(playlistName, musicData)
	local hash = cDigest(crypto.md5, musicData.title .. musicData.album)
	local stmt = database:prepare(sFormat([[ INSERT OR IGNORE INTO `%sPlaylist` VALUES %s; ]], playlistName, musicBinds))

	stmt:bind_names(
		{
			fileName = musicData.fileName,
			filePath = musicData.filePath,
			md5 = hash,
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
			sampleRate = musicData.sampleRate,
			sortTitle = musicData.title,
			albumSearch = musicData.album:stripAccents(),
			artistSearch = musicData.artist:stripAccents(),
			titleSearch = musicData.title:stripAccents()
		}
	)
	stmt:step()
	stmt:finalize()
	musicData = nil
	stmt = nil
end

function M:removeFromPlaylist(playlistName, id)
	local stmt = database:prepare(sFormat([[ DELETE FROM `%sPlaylist` WHERE id=%d; ]], playlistName, id))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:insertMusic(musicData)
	local hash = cDigest(crypto.md5, musicData.title .. musicData.album)
	local stmt = database:prepare(sFormat([[ INSERT OR IGNORE INTO `music` VALUES %s; ]], musicBinds))

	stmt:bind_names(
		{
			fileName = musicData.fileName,
			filePath = musicData.filePath,
			md5 = hash,
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
			sampleRate = musicData.sampleRate,
			sortTitle = musicData.title,
			albumSearch = musicData.album:stripAccents(),
			artistSearch = musicData.artist:stripAccents(),
			titleSearch = musicData.title:stripAccents()
		}
	)
	stmt:step()
	stmt:finalize()
	musicData = nil
	stmt = nil
end

function M:removeMusic(id)
	local stmt = database:prepare(sFormat([[ DELETE FROM `%s` WHERE id=%d; ]], self.currentMusicTable, id))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

function M:updateMusic(musicData)
	--print(musicData.id)
	--print(buildUpdateString(musicData))

	local values = buildUpdateString(musicData)
	local stmt = database:prepare(sFormat([[ UPDATE `music` SET %s WHERE id=%d; ]], values, musicData.id))
	stmt:step()
	stmt:finalize()
	stmt = nil
end

local function getMusicRowBy(index, ascending, filter)
	local stmt = nil
	local orderType = ascending and "ASC" or "DESC"
	local music = nil

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `%s` ORDER BY %s %s LIMIT 1 OFFSET %d; ]],
				M.currentMusicTable,
				filter,
				orderType,
				index - 1
			)
		)
	else
		stmt =
			database:prepare(sFormat([[ SELECT * FROM `%s` ORDER BY %s %s LIMIT 1;]], M.currentMusicTable, filter, orderType))
	end

	for row in stmt:nrows() do
		music = {
			id = row.id,
			fileName = row.fileName,
			filePath = row.filePath,
			md5 = row.md5,
			title = row.title,
			artist = row.artist,
			album = row.album,
			genre = row.genre,
			comment = row.comment,
			year = row.year,
			trackNumber = row.trackNumber,
			rating = row.rating,
			duration = row.duration,
			bitrate = row.bitrate,
			sampleRate = row.sampleRate,
			sortTitle = row.title,
			albumSearch = row.album,
			artistSearch = row.artist,
			titleSearch = row.title
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
	return getMusicRowBy(index, ascending, "sortTitle")
end

function M:getMusicRowBySearch(index, ascending, search, limit)
	local stmt = nil
	local orderType = ascending and "ASC" or "DESC"
	local music = nil
	-- %% SEARCH %% == anywhere in the string
	-- SEARCH %% == begins with string
	-- %% SEARCH == ends with string
	local likeQuery = sFormat("LIKE '%%%s%%'", escapeString(search))
	local artistQuery = sFormat("OR artistSearch %s", likeQuery)
	local titleQuery = sFormat("OR titleSearch %s", likeQuery)
	self.lastSearchQuery = sFormat([[WHERE albumSearch %s %s %s; ]], likeQuery, artistQuery, titleQuery)

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `%s` WHERE albumSearch %s %s %s ORDER BY sortTitle %s LIMIT 1 OFFSET %d; ]],
				self.currentMusicTable,
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
				[[ SELECT * FROM `%s` WHERE albumSearch %s %s %s ORDER BY sortTitle %s LIMIT 1; ]],
				self.currentMusicTable,
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
			md5 = row.md5,
			title = row.title,
			artist = row.artist,
			album = row.album,
			genre = row.genre,
			comment = row.comment,
			year = row.year,
			trackNumber = row.trackNumber,
			rating = row.rating,
			duration = row.duration,
			bitrate = row.bitrate,
			sampleRate = row.sampleRate,
			sortTitle = row.title,
			albumSearch = row.album,
			artistSearch = row.artist,
			titleSearch = row.title
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
	local likeQuery = sFormat("LIKE '%%%s%%'", escapeString(search))
	local artistQuery = sFormat("OR artistSearch %s", likeQuery)
	local titleQuery = sFormat("OR titleSearch %s", likeQuery)
	self.lastSearchQuery = sFormat([[WHERE albumSearch %s %s %s; ]], likeQuery, artistQuery, titleQuery)

	if (index > 1) then
		stmt =
			database:prepare(
			sFormat(
				[[ SELECT * FROM `%s` WHERE albumSearch %s %s %s ORDER BY %s %s LIMIT %d OFFSET %d; ]],
				self.currentMusicTable,
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
				[[ SELECT * FROM `%s` WHERE albumSearch %s %s %s ORDER BY %s %s LIMIT %d; ]],
				self.currentMusicTable,
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
			md5 = row.md5,
			title = row.title,
			artist = row.artist,
			album = row.album,
			genre = row.genre,
			comment = row.comment,
			year = row.year,
			trackNumber = row.trackNumber,
			rating = row.rating,
			duration = row.duration,
			bitrate = row.bitrate,
			sampleRate = row.sampleRate,
			sortTitle = row.title,
			albumSearch = row.album,
			artistSearch = row.artist,
			titleSearch = row.title
		}
	end

	stmt:finalize()
	stmt = nil

	return music
end

function M:musicCount()
	local stmt = database:prepare(sFormat([[ SELECT COUNT(*) AS count FROM `%s`; ]], self.currentMusicTable))
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

	local stmt =
		database:prepare(sFormat([[ SELECT COUNT(*) AS count FROM `%s` %s ]], self.currentMusicTable, self.lastSearchQuery))
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
