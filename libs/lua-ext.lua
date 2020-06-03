local M = {}

function _G.toboolean(value)
	if (type(value) == "number") then
		if (value == 0) then
			return false
		else
			return true
		end
	end

	return value
end

function _G.printf(msg, ...)
	print(msg:format(...))
end

return M
