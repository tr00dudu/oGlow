local _, ns = ...
local oGlow = ns.oGlow

local argcheck = oGlow.argcheck

local rgb = function(r, g, b)
	if(r > 255) then r = 255 end
	if(g > 255) then g = 255 end
	if(b > 255) then b = 255 end
	return {r / 255, g / 255, b / 255}
end

-- Uncommon / Rare / Epic. Other qualities still use GetItemQualityColor.
local defaultColors = {
	[2] = rgb(24, 205, 0),
	[3] = rgb(0, 116, 228),
	[4] = rgb(169, 55, 247),
}

local colorTable = setmetatable(
	{},

	{__index = function(self, val)
		argcheck(val, 2, 'number')
		local color = defaultColors[val]
		if(color) then
			color = {color[1], color[2], color[3]}
		else
			local r, g, b = GetItemQualityColor(val)
			color = {r, g, b}
		end
		rawset(self, val, color)

		return color
	end}
)

function oGlow:RegisterColor(name, r, g, b)
	argcheck(name, 2, 'string', 'number')
	argcheck(r, 3, 'number')
	argcheck(g, 4, 'number')
	argcheck(b, 5, 'number')

	local color = rawget(colorTable, name)
	if(color) then
		color[1], color[2], color[3] = r, g, b
	else
		color = {r, g, b}
		rawset(colorTable, name, color)
	end

	oGlowDB.Colors[name] = color

	return true
end

function oGlow:ResetColor(name)
	argcheck(name, 2, 'string', 'number')

	oGlowDB.Colors[name] = nil
	colorTable[name] = nil

	return unpack(colorTable[name])
end

ns.colorTable = colorTable
