local M = {}
local buttonLib = require("libs.ui.button")
local mMin = math.min
local mMax = math.max
local titleFont = "fonts/Jost-500-Medium.otf"
local subTitleFont = "fonts/Jost-300-Light.otf"
local background = nil
local group = display.newGroup()
local maxDisplayWidth = 1650
local maxDisplayHeight = 1024
local onlyUseOkButton = false
local created = false

function M.create()
	if (created) then
		return group
	end

	local interactionDisableRect = nil
	local background = nil
	local titleText = nil
	local messageText = nil
	local okButton = nil
	local cancelButton = nil
	local confirmButton = nil
	local onOK = nil
	local onCancel = nil
	local onConfirm = nil

	function group:setTitle(title)
		if (interactionDisableRect) then
			display.remove(interactionDisableRect)
			interactionDisableRect = nil
		end

		if (background) then
			display.remove(background)
			background = nil
		end

		if (titleText) then
			display.remove(titleText)
			titleText = nil
		end

		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)

		interactionDisableRect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
		interactionDisableRect.x = display.contentCenterX
		interactionDisableRect.y = display.contentCenterY
		interactionDisableRect.isVisible = false
		interactionDisableRect.isHitTestable = true
		interactionDisableRect:addEventListener(
			"tap",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"touch",
			function()
				return true
			end
		)
		interactionDisableRect:addEventListener(
			"mouse",
			function()
				return true
			end
		)
		self:insert(interactionDisableRect)

		background = display.newRoundedRect(0, 0, maxWidth * 0.5, maxHeight * 0.5, 2)
		background.x = display.contentCenterX
		background.y = display.contentCenterY
		background.strokeWidth = 1
		background:setFillColor(0.15, 0.15, 0.15)
		background:setStrokeColor(0.6, 0.6, 0.6, 0.5)
		self:insert(background)

		titleText =
			display.newText(
			{
				text = title,
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.04,
				width = background.width - 20,
				align = "center"
			}
		)
		titleText.x = background.x
		titleText.y = background.y - background.contentHeight * 0.5 + titleText.contentHeight * 0.5 + 10
		titleText:setFillColor(1, 1, 1)
		self:insert(titleText)
	end

	function group:setMessage(message)
		if (messageText) then
			display.remove(messageText)
			messageText = nil
		end

		if (okButton) then
			display.remove(okButton)
			okButton = nil
		end

		if (cancelButton) then
			display.remove(cancelButton)
			cancelButton = nil
		end

		if (confirmButton) then
			display.remove(confirmButton)
			confirmButton = nil
		end

		local maxWidth = mMin(maxDisplayWidth, display.contentWidth)
		local maxHeight = mMin(maxDisplayHeight, display.contentHeight)

		messageText =
			display.newText(
			{
				text = message,
				font = titleFont,
				x = 0,
				y = 0,
				fontSize = maxHeight * 0.03,
				width = background.width - 20,
				align = "center"
			}
		)
		messageText.x = titleText.x
		messageText.y = titleText.y + titleText.contentHeight * 0.5 + messageText.contentHeight * 0.5
		messageText:setFillColor(1, 1, 1)
		self:insert(messageText)

		if (onlyUseOkButton) then
			okButton =
				buttonLib.new(
				{
					iconName = "check-circle OK",
					fontSize = maxHeight * 0.03,
					parent = self,
					onClick = function(event)
						self:hide()

						if (type(onOK) == "function") then
							self:hide()
							onOK()
						end
					end
				}
			)
			okButton.x = background.x
			okButton.y = background.y + background.contentHeight * 0.5 - okButton.contentHeight
		else
			cancelButton =
				buttonLib.new(
				{
					iconName = "window-close No",
					fontSize = maxHeight * 0.03,
					parent = self,
					onClick = function(event)
						self:hide()

						if (type(onCancel) == "function") then
							onCancel()
						end
					end
				}
			)
			cancelButton.x = background.x - cancelButton.contentWidth
			cancelButton.y = background.y + background.contentHeight * 0.5 - cancelButton.contentHeight

			confirmButton =
				buttonLib.new(
				{
					iconName = "check-circle Yes",
					fontSize = maxHeight * 0.03,
					parent = self,
					onClick = function(event)
						if (type(onConfirm) == "function") then
							self:hide()
							onConfirm()
						end
					end
				}
			)
			confirmButton.x = background.x + confirmButton.contentWidth
			confirmButton.y = background.y + background.contentHeight * 0.5 - confirmButton.contentHeight
		end
	end

	function group:onlyUseOkButton()
		onlyUseOkButton = true
	end

	function group:setButtonCallbacks(options)
		onCancel = nil
		onConfirm = nil
		onCancel = options and options.onCancel
		onConfirm = options and options.onConfirm
		onOK = options and options.onOK

		if (onCancel or onConfirm) then
			onlyUseOkButton = false
		end
	end

	function group:show()
		self.isVisible = true
		self:toFront()
	end

	function group:hide()
		if (interactionDisableRect) then
			display.remove(interactionDisableRect)
			interactionDisableRect = nil
		end

		if (background) then
			display.remove(background)
			background = nil
		end

		if (titleText) then
			display.remove(titleText)
			titleText = nil
		end

		if (messageText) then
			display.remove(messageText)
			messageText = nil
		end

		if (okButton) then
			display.remove(okButton)
			okButton = nil
		end

		if (cancelButton) then
			display.remove(cancelButton)
			cancelButton = nil
		end

		if (confirmButton) then
			display.remove(confirmButton)
			confirmButton = nil
		end

		self.isVisible = false
	end

	created = true
	group:hide()

	return group
end

function M:isOpen()
	return group.isVisible
end

return M
