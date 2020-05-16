local M = {}
local sFormat = string.format
local sGsub = string.gsub
local sByte = string.byte

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

return M
