local M = {}

function M.byTitleAToZ(a, b)
	local tagA = a.tags.title:len() > 1 and a.tags.title or "z"
	local tagB = b.tags.title:len() > 1 and b.tags.title or "z"

	return tagA < tagB
end

function M.byTitleZToA(a, b)
	local tagA = a.tags.title:len() > 1 and a.tags.title or "a"
	local tagB = b.tags.title:len() > 1 and b.tags.title or "a"

	return tagA > tagB
end

function M.byArtistAToZ(a, b)
	local tagA = a.tags.artist:len() > 1 and a.tags.artist or "z"
	local tagB = b.tags.artist:len() > 1 and b.tags.artist or "z"

	return tagA < tagB
end

function M.byArtistZToA(a, b)
	local tagA = a.tags.artist:len() > 1 and a.tags.artist or "a"
	local tagB = b.tags.artist:len() > 1 and b.tags.artist or "a"

	return tagA > tagB
end

function M.byAlbumAToZ(a, b)
	local tagA = a.tags.album:len() > 1 and a.tags.album or "z"
	local tagB = b.tags.album:len() > 1 and b.tags.album or "z"

	return tagA < tagB
end

function M.byAlbumZToA(a, b)
	local tagA = a.tags.album:len() > 1 and a.tags.album or "a"
	local tagB = b.tags.album:len() > 1 and b.tags.album or "a"

	return tagA > tagB
end

function M.byGenreAToZ(a, b)
	local tagA = a.tags.genre:len() > 1 and a.tags.genre or "z"
	local tagB = b.tags.genre:len() > 1 and b.tags.genre or "z"

	return tagA < tagB
end

function M.byGenreZToA(a, b)
	local tagA = a.tags.genre:len() > 1 and a.tags.genre or "a"
	local tagB = b.tags.genre:len() > 1 and b.tags.genre or "a"

	return tagA > tagB
end

function M.byDurationAToZ(a, b)
	local tagA = a.tags.duration:len() > 1 and a.tags.duration or "z"
	local tagB = b.tags.duration:len() > 1 and b.tags.duration or "z"

	return tagA < tagB
end

function M.byDurationZToA(a, b)
	local tagA = a.tags.duration:len() > 1 and a.tags.duration or "a"
	local tagB = b.tags.duration:len() > 1 and b.tags.duration or "a"

	return tagA > tagB
end

return M
