local M = {
	playButton = {
		name = "playButtonEvent",
		events = {
			setOn = "setOn",
			setOff = "setOff"
		}
	},
	volumeButton = {
		name = "volumeButtonEvent",
		events = {
			setOn = "setOn",
			setOff = "setOff"
		}
	},
	volumeSlider = {
		name = "volumeSliderEvent",
		events = {
			setValue = "setValue"
		}
	},
	playlistDropdown = {
		name = "playlistDropdownEvent",
		events = {
			close = "close"
		}
	},
	mainMenu = {
		name = "mainMenuEvent",
		events = {
			close = "close"
		}
	},
	mediaBar = {
		name = "mediaBarEvent",
		events = {
			closePlaylists = "closePlaylists",
			clearSong = "clearSong",
			loadingUrl = "loadingUrl",
			loadedUrl = "loadedUrl"
		}
	},
	musicList = {
		name = "musicListEvent",
		events = {
			closeRightClickMenus = "closeRightClickMenus",
			reloadData = "reloadData",
			cleanReloadData = "cleanReloadData",
			unlockScroll = "unlockScroll",
			setSelectedRow = "setSelectedRow",
			setMusicCount = "setMusicCount",
			clearMusicSearch = "clearMusicSearch",
			setResultsLimit = "setResultsLimit",
			setMusicSearch = "setMusicSearch"
		}
	},
	mainEvent = {
		name = "mainEvent",
		events = {
			populateTableViews = "populateTableViews"
		}
	}
}

function M:playButtonEvent(eventPhase)
	local event = {
		name = self.playButton.name,
		phase = eventPhase
	}

	Runtime:dispatchEvent(event)
end

function M:volumeButtonEvent(eventPhase)
	local event = {
		name = self.volumeButton.name,
		phase = eventPhase
	}

	Runtime:dispatchEvent(event)
end

function M:volumeSliderEvent(eventPhase, value)
	local event = {
		name = self.volumeSlider.name,
		phase = eventPhase,
		value = value
	}

	Runtime:dispatchEvent(event)
end

function M:playlistDropdownEvent(eventPhase)
	local event = {
		name = self.playlistDropdown.name,
		phase = eventPhase
	}

	Runtime:dispatchEvent(event)
end

function M:mainMenuEvent(eventPhase)
	local event = {
		name = self.mainMenu.name,
		phase = eventPhase
	}

	Runtime:dispatchEvent(event)
end

function M:mediaBarEvent(eventPhase, value)
	local event = {
		name = self.mediaBar.name,
		phase = eventPhase,
		value = value
	}

	Runtime:dispatchEvent(event)
end

function M:musicListEvent(eventPhase, value)
	local event = {
		name = self.musicList.name,
		phase = eventPhase,
		value = value
	}

	Runtime:dispatchEvent(event)
end

function M:mainLuaEvent(eventPhase)
	local event = {
		name = self.mainEvent.name,
		phase = eventPhase
	}

	Runtime:dispatchEvent(event)
end

return M
