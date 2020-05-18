local M = {}
local sFormat = string.format
local sGsub = string.gsub
local sByte = string.byte
local isWindows = system.getInfo("platform") == "win32"
local accentedCharacters = {
	["À"] = "A",
	["Á"] = "A",
	["Â"] = "A",
	["Ã"] = "A",
	["Ä"] = "A",
	["Å"] = "A",
	["Æ"] = "AE",
	["Ç"] = "C",
	["È"] = "E",
	["É"] = "E",
	["Ê"] = "E",
	["Ë"] = "E",
	["Ì"] = "I",
	["Í"] = "I",
	["Î"] = "I",
	["Ï"] = "I",
	["Ð"] = "D",
	["Ñ"] = "N",
	["Ò"] = "O",
	["Ó"] = "O",
	["Ô"] = "O",
	["Õ"] = "O",
	["Ö"] = "O",
	["Ø"] = "O",
	["Ù"] = "U",
	["Ú"] = "U",
	["Û"] = "U",
	["Ü"] = "U",
	["Ý"] = "Y",
	["Þ"] = "P",
	["ß"] = "s",
	["à"] = "a",
	["á"] = "a",
	["â"] = "a",
	["ã"] = "a",
	["ä"] = "a",
	["å"] = "a",
	["æ"] = "ae",
	["ç"] = "c",
	["è"] = "e",
	["é"] = "e",
	["ê"] = "e",
	["ë"] = "e",
	["ì"] = "i",
	["í"] = "i",
	["î"] = "i",
	["ï"] = "i",
	["ð"] = "eth",
	["ñ"] = "n",
	["ò"] = "o",
	["ó"] = "o",
	["ô"] = "o",
	["õ"] = "o",
	["ö"] = "o",
	["ø"] = "o",
	["ù"] = "u",
	["ú"] = "u",
	["û"] = "u",
	["ü"] = "u",
	["ý"] = "y",
	["þ"] = "p",
	["ÿ"] = "y"
}

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

function string:stripAccents(str)
	local wString = str or self
	local strippedStr = wString:gsub("[%z\1-\127\194-\244][\128-\191]*", accentedCharacters)

	return strippedStr
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
