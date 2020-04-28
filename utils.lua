local json = require("json")

local M = {}

local defaultLocation = system.DocumentsDirectory
local sFormat = string.format

function M:loadTable(filename, location)
	local loc = location

	if not location then
		loc = defaultLocation
	end

	local path = system.pathForFile(filename, loc)
	local file, errorString = io.open(path, "r")

	if not file then
		print("File error: " .. errorString)
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

function M:copyFile(filename, destination)
	assert(type(filename) == "string", "string expected for the first parameter but got " .. type(filename) .. " instead.")
	assert(type(destination) == "table", "table expected for the second paramter but bot " .. type(destination) .. " instead.")
	--local sourceDBpath = system.pathForFile(filename, system.ResourceDirectory)
	-- io.open opens a file at path; returns nil if no file found
	local readHandle, errorString = io.open(filename, "rb")
	assert(readHandle, "Database at " .. filename .. " could not be read from system.ResourceDirectory")
	assert(type(destination.filename) == "string", "filename should be a string, its a " .. type(destination.filename))
	print(type(destination.baseDir))
	assert(type(destination.baseDir) == "userdata", "baseName should be a valid system directory")

	local destinationDBpath = system.pathForFile(destination.filename, destination.baseDir)
	local writeHandle, writeErrorString = io.open(destinationDBpath, "wb")
	assert(writeHandle, "Could not open " .. destination.filename .. " for writing.")

	local contents = readHandle:read("*a")
	writeHandle:write(contents)

	io.close(writeHandle)
	io.close(readHandle)
	return true
end

return M
