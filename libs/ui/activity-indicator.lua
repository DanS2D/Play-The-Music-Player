local M = {}
local theme = require("libs.theme")
local uPack = unpack
local fontAwesomeSolidFont = "fonts/FA5-Solid.ttf"

function M.new(options)
	local x = options.x or 0
	local y = options.y or 0
	local name = options.name or error("activity-indicator.new() name (string) expected, got %s", type(options.name))
	local iconName = options.iconName or "sync-alt"
	local fontSize = options.fontSize or 14
	local font = options.font or fontAwesomeSolidFont
	local hideWhenStopped = options.hideWhenStopped or false
	local onClick = options.onClick
	local parent = options.parent or display.getCurrentStage()

	if (_G.isLinux and iconName == "sync-alt") then
		iconName = ""
	end

	local activityIndicator =
		display.newText(
		{
			text = iconName,
			font = font,
			fontSize = fontSize,
			align = "center"
		}
	)
	activityIndicator.x = x
	activityIndicator.y = y
	activityIndicator:setFillColor(uPack(theme:get().iconColor.primary))
	parent:insert(activityIndicator)

	function activityIndicator:start()
		local function onStart()
			transition.to(
				self,
				{
					tag = name,
					time = 1000,
					rotation = 360,
					onComplete = function()
						self.rotation = 0
						onStart()
					end
				}
			)
		end

		self.isVisible = true
		onStart()
	end

	function activityIndicator:stop()
		transition.cancel(self.name)
		self.rotation = 0

		if (hideWhenStopped) then
			self.isVisible = false
		end
	end

	return activityIndicator
end

return M
