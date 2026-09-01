local _, ns = ...
local oGlow = ns.oGlow

local argcheck = oGlow.argcheck
local colorTable = ns.colorTable

local DEFAULTS = {
	thickness = 1,
	offset = 0,
	radius = 3,
	alpha = .75,
	glow = 4,
	glowAlpha = .2,
	glowMin = 2,
	offsetL = 0,
	offsetT = -0.5,
	offsetR = -0.5,
	offsetB = 0,
}

local BORDER_THICKNESS = DEFAULTS.thickness
local BORDER_OFFSET = DEFAULTS.offset
local BORDER_RADIUS = DEFAULTS.radius
local BORDER_ALPHA = DEFAULTS.alpha
local GLOW_WIDTH = DEFAULTS.glow
local GLOW_ALPHA = DEFAULTS.glowAlpha
local GLOW_MIN = DEFAULTS.glowMin
local OFFSET_L = DEFAULTS.offsetL
local OFFSET_T = DEFAULTS.offsetT
local OFFSET_R = DEFAULTS.offsetR
local OFFSET_B = DEFAULTS.offsetB

local tracked = {}

local cornerPixels = function(radius)
	local pixels, seen = {}, {}
	if(radius < 2) then
		return pixels
	end

	local x, y = 0, radius
	local d = 3 - 2 * radius
	local add = function(ox, oy)
		local px, py = radius - ox, radius - oy
		if(px >= 0 and py >= 0 and px < radius and py < radius) then
			local key = px * 100 + py
			if(not seen[key]) then
				seen[key] = true
				pixels[#pixels + 1] = {px, py}
			end
		end
	end

	while(x <= y) do
		add(x, y)
		add(y, x)
		if(d < 0) then
			d = d + 4 * x + 6
		else
			d = d + 4 * (x - y) + 10
			y = y - 1
		end
		x = x + 1
	end

	return pixels
end

local colorGlow = function(border, r, g, b, a)
	a = a or GLOW_ALPHA
	if(not border.glowTop) then
		return
	end

	if(GLOW_WIDTH <= 0 or a <= 0 or type(border._color) ~= 'number' or border._color < GLOW_MIN) then
		border.glowTop:Hide()
		border.glowBottom:Hide()
		border.glowLeft:Hide()
		border.glowRight:Hide()
		return
	end

	-- VERTICAL: first color is bottom, second is top.
	-- HORIZONTAL: first color is left, second is right.
	border.glowTop:Show()
	border.glowBottom:Show()
	border.glowLeft:Show()
	border.glowRight:Show()
	border.glowTop:SetGradientAlpha('VERTICAL', r, g, b, 0, r, g, b, a)
	border.glowBottom:SetGradientAlpha('VERTICAL', r, g, b, a, r, g, b, 0)
	border.glowLeft:SetGradientAlpha('HORIZONTAL', r, g, b, a, r, g, b, 0)
	border.glowRight:SetGradientAlpha('HORIZONTAL', r, g, b, 0, r, g, b, a)
end

local colorBorder = function(border, r, g, b, a)
	a = a or BORDER_ALPHA
	border.top:SetVertexColor(r, g, b, a)
	border.bottom:SetVertexColor(r, g, b, a)
	border.left:SetVertexColor(r, g, b, a)
	border.right:SetVertexColor(r, g, b, a)

	for i = 1, #border.corners do
		if(border.corners[i]:IsShown()) then
			border.corners[i]:SetVertexColor(r, g, b, a)
		end
	end

	colorGlow(border, r, g, b)
end

local layoutBorder = function(border, anchor)
	local pad = BORDER_OFFSET
	local t = BORDER_THICKNESS
	local r = BORDER_RADIUS

	border:ClearAllPoints()
	border:SetPoint('TOPLEFT', anchor, 'TOPLEFT', -(pad + OFFSET_L), pad + OFFSET_T)
	border:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', pad + OFFSET_R, -(pad + OFFSET_B))

	border.top:ClearAllPoints()
	border.top:SetPoint('TOPLEFT', r, 0)
	border.top:SetPoint('TOPRIGHT', -r, 0)
	border.top:SetHeight(t)

	border.bottom:ClearAllPoints()
	border.bottom:SetPoint('BOTTOMLEFT', r, 0)
	border.bottom:SetPoint('BOTTOMRIGHT', -r, 0)
	border.bottom:SetHeight(t)

	border.left:ClearAllPoints()
	border.left:SetPoint('TOPLEFT', 0, -r)
	border.left:SetPoint('BOTTOMLEFT', 0, r)
	border.left:SetWidth(t)

	border.right:ClearAllPoints()
	border.right:SetPoint('TOPRIGHT', 0, -r)
	border.right:SetPoint('BOTTOMRIGHT', 0, r)
	border.right:SetWidth(t)

	for i = 1, #border.corners do
		local tex = border.corners[i]
		if(tex:IsShown()) then
			local px, py, corner = tex._x, tex._y, tex._corner
			tex:ClearAllPoints()
			tex:SetWidth(t)
			tex:SetHeight(t)
			if(corner == 'TL') then
				tex:SetPoint('TOPLEFT', px, -py)
			elseif(corner == 'TR') then
				tex:SetPoint('TOPRIGHT', -px, -py)
			elseif(corner == 'BL') then
				tex:SetPoint('BOTTOMLEFT', px, py)
			else
				tex:SetPoint('BOTTOMRIGHT', -px, py)
			end
		end
	end

	if(not border.glowTop) then
		return
	end

	local w = GLOW_WIDTH
	if(w <= 0) then
		border.glowTop:Hide()
		border.glowBottom:Hide()
		border.glowLeft:Hide()
		border.glowRight:Hide()
		return
	end

	border.glowTop:ClearAllPoints()
	border.glowTop:SetPoint('TOPLEFT', 0, -t)
	border.glowTop:SetPoint('TOPRIGHT', 0, -t)
	border.glowTop:SetHeight(w)

	border.glowBottom:ClearAllPoints()
	border.glowBottom:SetPoint('BOTTOMLEFT', 0, t)
	border.glowBottom:SetPoint('BOTTOMRIGHT', 0, t)
	border.glowBottom:SetHeight(w)

	border.glowLeft:ClearAllPoints()
	border.glowLeft:SetPoint('TOPLEFT', t, -t)
	border.glowLeft:SetPoint('BOTTOMLEFT', t, t)
	border.glowLeft:SetWidth(w)

	border.glowRight:ClearAllPoints()
	border.glowRight:SetPoint('TOPRIGHT', -t, -t)
	border.glowRight:SetPoint('BOTTOMRIGHT', -t, t)
	border.glowRight:SetWidth(w)
end

local createEdge = function(parent, sublevel)
	local tex = parent:CreateTexture(nil, 'OVERLAY')
	tex:SetTexture[[Interface\Buttons\WHITE8X8]]
	if(sublevel) then
		tex:SetDrawLayer('OVERLAY', sublevel)
	end
	return tex
end

local ensureGlow = function(border)
	if(border.glowTop) then
		return
	end

	border.glowTop = createEdge(border, -1)
	border.glowBottom = createEdge(border, -1)
	border.glowLeft = createEdge(border, -1)
	border.glowRight = createEdge(border, -1)
end

local syncCorners = function(border)
	local offsets = cornerPixels(BORDER_RADIUS)
	local names = {'TL', 'TR', 'BL', 'BR'}
	local n = 0

	for i = 1, #offsets do
		for c = 1, 4 do
			n = n + 1
			local tex = border.corners[n]
			if(not tex) then
				tex = createEdge(border)
				border.corners[n] = tex
			end
			tex._x = offsets[i][1]
			tex._y = offsets[i][2]
			tex._corner = names[c]
			tex:Show()
		end
	end

	for i = n + 1, #border.corners do
		border.corners[i]:Hide()
	end

	border._radius = BORDER_RADIUS
end

local refreshBorder = function(border)
	if(not border.GetObjectType or border:GetObjectType() ~= 'Frame') then
		return
	end

	syncCorners(border)
	ensureGlow(border)
	layoutBorder(border, border._anchor)
	local rgb = border._color and colorTable[border._color]
	if(rgb) then
		colorBorder(border, rgb[1], rgb[2], rgb[3])
	end
end

local createBorder = function(self, point)
	local bc = self.oGlowBorder
	-- /reload leaves old overlays parented to Blizzard frames.
	if(bc and (not bc.GetObjectType or bc:GetObjectType() ~= 'Frame' or not bc.corners)) then
		bc:Hide()
		self.oGlowBorder = nil
		bc = nil
	end

	if(not bc) then
		local parent = self:IsObjectType'Frame' and self or self:GetParent()
		bc = CreateFrame('Frame', nil, parent)
		bc:SetFrameLevel(parent:GetFrameLevel() + 1)

		bc.top = createEdge(bc, 0)
		bc.bottom = createEdge(bc, 0)
		bc.left = createEdge(bc, 0)
		bc.right = createEdge(bc, 0)
		bc.corners = {}

		self.oGlowBorder = bc
	end

	ensureGlow(bc)
	bc._anchor = point or self
	tracked[self] = bc
	if(bc._radius ~= BORDER_RADIUS) then
		syncCorners(bc)
	end
	layoutBorder(bc, bc._anchor)
	return bc
end

local borderDisplay = function(frame, color)
	if(color) then
		local bc = createBorder(frame)
		local rgb = colorTable[color]

		if(rgb) then
			bc._color = color
			colorBorder(bc, rgb[1], rgb[2], rgb[3])
			bc:Show()
		end

		return true
	elseif(frame.oGlowBorder) then
		frame.oGlowBorder:Hide()
	end
end

local applySettings = function(db)
	local s = db.BorderSettings
	if(not s) then
		s = {}
		db.BorderSettings = s
	end

	if(s.thickness == nil) then s.thickness = DEFAULTS.thickness end
	if(s.offset == nil) then s.offset = DEFAULTS.offset end
	if(s.radius == nil) then s.radius = DEFAULTS.radius end
	if(s.alpha == nil) then s.alpha = DEFAULTS.alpha end
	if(s.glow == nil) then s.glow = DEFAULTS.glow end
	if(s.glowAlpha == nil) then s.glowAlpha = DEFAULTS.glowAlpha end
	if(s.glowMin == nil) then s.glowMin = DEFAULTS.glowMin end
	if(s.offsetL == nil) then s.offsetL = DEFAULTS.offsetL end
	if(s.offsetT == nil) then s.offsetT = DEFAULTS.offsetT end
	if(s.offsetR == nil) then s.offsetR = DEFAULTS.offsetR end
	if(s.offsetB == nil) then s.offsetB = DEFAULTS.offsetB end
	s.glowInset = nil

	BORDER_THICKNESS = tonumber(s.thickness) or DEFAULTS.thickness
	BORDER_OFFSET = tonumber(s.offset) or DEFAULTS.offset
	BORDER_RADIUS = tonumber(s.radius) or DEFAULTS.radius
	BORDER_ALPHA = tonumber(s.alpha) or DEFAULTS.alpha
	GLOW_WIDTH = tonumber(s.glow) or DEFAULTS.glow
	GLOW_ALPHA = tonumber(s.glowAlpha) or DEFAULTS.glowAlpha
	GLOW_MIN = tonumber(s.glowMin) or DEFAULTS.glowMin
	OFFSET_L = tonumber(s.offsetL) or DEFAULTS.offsetL
	OFFSET_T = tonumber(s.offsetT) or DEFAULTS.offsetT
	OFFSET_R = tonumber(s.offsetR) or DEFAULTS.offsetR
	OFFSET_B = tonumber(s.offsetB) or DEFAULTS.offsetB
end

function oGlow:GetBorderSettings()
	return {
		thickness = BORDER_THICKNESS,
		offset = BORDER_OFFSET,
		radius = BORDER_RADIUS,
		alpha = BORDER_ALPHA,
		glow = GLOW_WIDTH,
		glowAlpha = GLOW_ALPHA,
		glowMin = GLOW_MIN,
		offsetL = OFFSET_L,
		offsetT = OFFSET_T,
		offsetR = OFFSET_R,
		offsetB = OFFSET_B,
	}
end

function oGlow:ResetBorderSettings()
	if(not oGlowDB.BorderSettings) then
		oGlowDB.BorderSettings = {}
	end

	local s = oGlowDB.BorderSettings
	s.thickness = DEFAULTS.thickness
	s.offset = DEFAULTS.offset
	s.radius = DEFAULTS.radius
	s.alpha = DEFAULTS.alpha
	s.glow = DEFAULTS.glow
	s.glowAlpha = DEFAULTS.glowAlpha
	s.glowMin = DEFAULTS.glowMin
	s.offsetL = DEFAULTS.offsetL
	s.offsetT = DEFAULTS.offsetT
	s.offsetR = DEFAULTS.offsetR
	s.offsetB = DEFAULTS.offsetB
	s.glowInset = nil

	applySettings(oGlowDB)
	self:RefreshBorders()
end

function oGlow:SetBorderSetting(key, value)
	if(not oGlowDB.BorderSettings) then
		oGlowDB.BorderSettings = {}
	end

	oGlowDB.BorderSettings[key] = value
	applySettings(oGlowDB)
	self:RefreshBorders()
end

function oGlow:RefreshBorders()
	for owner, bc in next, tracked do
		if(bc.GetObjectType and bc:GetObjectType() == 'Frame') then
			refreshBorder(bc)
		else
			tracked[owner] = nil
		end
	end
end

oGlow:RegisterOptionCallback(applySettings)
oGlow:RegisterDisplay('Border', borderDisplay)

function oGlow:SetBorderQuality(frame, quality)
	return borderDisplay(frame, quality)
end
