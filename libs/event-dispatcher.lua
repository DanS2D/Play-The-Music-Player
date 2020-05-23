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

return M
