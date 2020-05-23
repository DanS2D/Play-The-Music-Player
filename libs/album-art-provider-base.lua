local M = {}
local pureMagic = require("libs.pure-magic")
local fileUtils = require("libs.file-utils")
local sFormat = string.format
M.__index = M

function M:new(providerName)
	local object = {}
	setmetatable(object, self)

	object.providerName = providerName
	return object
end

function M:saveCover(event, coverFoundEvent, coverNotFoundEvent)
	local status = event.status
	local phase = event.phase
	local isError = event.isError
	local response = event.response

	if (isError or status ~= 200) then
		print(sFormat("response issue: Cover NOT FOUND at %s - dispatching notFound event", self.providerName))
		coverNotFoundEvent()
		return
	end

	if (phase == "ended") then
		local imagePath = sFormat("tempArtwork_%s.jpg", self.providerName)
		local file, errorString = io.open(system.pathForFile(imagePath, system.TemporaryDirectory), "wb")
		file:write(response)
		file:close()

		local fileName = imagePath
		local fileExtension = fileName:fileExtension()
		local filePath = system.pathForFile(fileName, system.TemporaryDirectory)
		local newFileName = fileName
		local mimetype = pureMagic.via_path(filePath)

		if (mimetype == "image/png" and fileExtension ~= "png") then
			newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "png")
			local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.TemporaryDirectory))
		elseif (mimetype == "image/jpeg" and fileExtension ~= "jpg") then
			newFileName = sFormat("%s.%s", fileName:sub(1, fileName:len() - 3), "jpg")
			local result, reason = os.rename(filePath, system.pathForFile(newFileName, system.TemporaryDirectory))
		end

		if (fileUtils:fileExists(newFileName, system.TemporaryDirectory)) then
			print(sFormat("GOT Artwork from %s - dispatching found event", self.providerName))

			coverFoundEvent(newFileName)
		else
			print(sFormat("Cover NOT FOUND at %s - dispatching notFound event", self.providerName))
			coverNotFoundEvent()
		end
	end
end

return M
