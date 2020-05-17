local M = {}
local sFormat = string.format
local sGsub = string.gsub
local sByte = string.byte
local isWindows = system.getInfo("platform") == "win32"

function string:urlEncode(str)
	local wString = str or self

	if (wString) then
		wString = sGsub(wString, "\n", "\r\n")
		wString =
			sGsub(
			wString,
			"([^%w ])",
			function(c)
				return sFormat("%%%02X", sByte(c))
			end
		)
		wString = sGsub(wString, " ", "+")
	end

	return wString
end

function string:fileExtension(str)
	local wString = str or self
	wString = wString:match("^.+(%..+)$"):lower()
	wString = wString:sub(2, wString:len())

	return wString
end

string.pathSeparator = isWindows and "\\" or "/"

function string:getFileNameAndPath(str)
	local wString = str or self
	local lastPathSeparatorPos = wString:match(sFormat("%s%s", "^.*()", string.pathSeparator))

	local fileName = wString:sub(lastPathSeparatorPos + 1, wString:len())
	local filePath = wString:sub(1, lastPathSeparatorPos - 1)

	return fileName, filePath
end

return M
