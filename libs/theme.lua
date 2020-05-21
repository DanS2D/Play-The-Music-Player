local M = {}
local defaultThemes = {
	dark = {
		backgroundColor = {
			primary = {0.10, 0.10, 0.10, 1},
			secondary = {0.15, 0.15, 0.15, 1},
			outline = {0.6, 0.6, 0.6, 0.5}
		},
		rowColor = {
			primary = {0.10, 0.10, 0.10, 1},
			over = {0.18, 0.18, 0.18, 1}
		},
		iconColor = {
			primary = {0.7, 0.7, 0.7, 1},
			highlighted = {0.7, 0.7, 0.7, 0.6}
		},
		textColor = {
			primary = {0.9, 0.9, 0.9, 1},
			secondary = {0.7, 0.7, 0.7, 1}
		}
	},
	light = {
		backgroundColor = {
			primary = {1, 1, 1, 1},
			secondary = {0.94, 0.94, 0.94, 1},
			outline = {0.6, 0.6, 0.6, 0.5}
		},
		rowColor = {
			primary = {1, 1, 1, 1},
			over = {0.80, 0.80, 0.80, 1}
		},
		iconColor = {
			primary = {0.33, 0.33, 0.33, 1},
			highlighted = {0.33, 0.33, 0.33, 0.6}
		},
		textColor = {
			primary = {0, 0, 0, 1},
			secondary = {0.2, 0.2, 0.2, 1}
		}
	}
}
local currentTheme = defaultThemes.dark

function M:get()
	return currentTheme
end

function M:set(themeName)
	currentTheme = defaultThemes[themeName]
end

function M:setDefaultBackgroundColor()
	local primaryColor = currentTheme.backgroundColor.primary

	display.setDefault("background", primaryColor[1], primaryColor[2], primaryColor[3], primaryColor[4])
end

return M
