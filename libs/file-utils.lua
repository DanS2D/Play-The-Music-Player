local json = require("json")
local ltn12 = require("ltn12")
local M = {}
local defaultLocation = system.DocumentsDirectory
local sFormat = string.format

M.documentsFullPath = sFormat("%s%s", system.pathForFile(nil, system.DocumentsDirectory), string.pathSeparator)
M.temporaryFullPath = sFormat("%s%s", system.pathForFile(nil, system.TemporaryDirectory), string.pathSeparator)
M.albumArtworkFolder = sFormat("data%salbumArt%s", string.pathSeparator, string.pathSeparator)

function M:loadTable(filename, location)
	local loc = location

	if not location then
		loc = defaultLocation
	end

	local path = system.pathForFile(filename, loc)
	local file, errorString = io.open(path, "r")

	if not file then
		print("File error: " .. errorString .. " at path: " .. path)
		return false
	else
		local contents = file:read("*a")
		local t = json.decode(contents)
		io.close(file)

		return t
	end
end

function M:saveTable(t, filename, location)
	local loc = location

	if not location then
		loc = defaultLocation
	end

	local path = system.pathForFile(filename, loc)
	local file, errorString = io.open(path, "w")

	if not file then
		print("File error: " .. errorString)
		return false
	else
		file:write(json.encode(t))
		io.close(file)

		return true
	end
end

function M:fileExists(filePath, baseDir)
	local path = system.pathForFile(filePath, baseDir or system.DocumentsDirectory)
	local file = io.open(path, "r")
	local exists = false

	if (file) then
		exists = true
		io.close(file)
	end

	return exists
end

function M:fileExistsAtRawPath(filePath)
	local file = io.open(filePath, "r")
	local exists = false

	if (file) then
		exists = true
		io.close(file)
	end

	return exists
end

function M:fileSize(filePath)
	local file = io.open(filePath, "rb")

	if (file) then
		local current = file:seek()
		local size = file:seek("end")
		file:seek("set", current)
		io.close(file)
		file = nil

		return size
	end

	return 0
end

function M:copyFile(sourcePath, newPath)
	if (not self:fileExistsAtRawPath(sourcePath)) then
		print(sFormat("fileUtils:copyFile() couldn't copy file from %s as it doesn't exist", sourcePath))
		return
	end

	ltn12.pump.all(ltn12.source.file(assert(io.open(sourcePath, "rb"))), ltn12.sink.file(assert(io.open(newPath, "wb"))))
end

function M:removeFile(fileName, filePath)
	local separator = filePath:ends(string.pathSeparator) and "" or string.pathSeparator
	local fullPath = sFormat("%s%s%s", filePath, separator, fileName)
	local file = io.open(fullPath, "r")
	local result = false
	local reason = "File doesn't exist"

	if (file) then
		io.close(file)
		file = nil
		result, reason = os.remove(fullPath)
	end

	return result, reason
end

return M
