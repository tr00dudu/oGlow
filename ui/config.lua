local _, ns = ...
local oGlow = ns.oGlow
local colorTable = ns.colorTable

local BACKDROP = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = true, tileSize = 16,
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
}

local updateAllPipes = function()
	for pipe, active in oGlow.IteratePipes() do
		if(active) then
			oGlow:UpdatePipe(pipe)
		end
	end
end

local frame = CreateFrame('Frame', 'oGlowConfig', UIParent)
frame:SetSize(360, 628)
frame:SetPoint'CENTER'
frame:SetFrameStrata'HIGH'
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetBackdrop(BACKDROP)
frame:SetBackdropColor(.1, .1, .1, .9)
frame:SetBackdropBorderColor(.3, .3, .3, 1)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag'LeftButton'
frame:SetScript('OnDragStart', frame.StartMoving)
frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
frame:Hide()

tinsert(UISpecialFrames, 'oGlowConfig')

local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
close:SetPoint('TOPRIGHT', 2, 2)

local title = ns.createFontString(frame, 'GameFontNormal')
title:SetPoint('TOP', 0, -12)
title:SetText'oGlow'

local borderLabel = ns.createFontString(frame, 'GameFontNormalSmall')
borderLabel:SetPoint('TOPLEFT', 16, -36)
borderLabel:SetText'Border'

local rows = {}
local sideEdits = {}
local syncing

local SETTINGS = {
	{
		key = 'thickness',
		label = 'Thickness',
		min = 1, max = 8, step = 1,
		format = '%d',
	},
	{
		key = 'offset',
		label = 'Offset',
		min = -8, max = 8, step = 1,
		format = '%d',
	},
	{
		key = 'radius',
		label = 'Radius',
		min = 0, max = 12, step = 1,
		format = '%d',
	},
	{
		key = 'alpha',
		label = 'Alpha',
		min = 0, max = 1, step = .05,
		format = '%.2f',
	},
	{
		key = 'glow',
		label = 'Glow',
		min = 0, max = 16, step = 1,
		format = '%d',
	},
	{
		key = 'glowAlpha',
		label = 'G. alpha',
		min = 0, max = 1, step = .05,
		format = '%.2f',
	},
}

local roundTo = function(value, step)
	return math.floor(value / step + .5) * step
end

local currentSettings = function()
	return oGlow:GetBorderSettings()
end

local syncWidgets = function()
	local values = currentSettings()
	syncing = true
	for i = 1, #rows do
		local row = rows[i]
		local value = values[row.key]
		row.slider:SetValue(value)
		row.edit:SetText(string.format(row.format, value))
	end
	for i = 1, #sideEdits do
		local group = sideEdits[i]
		group.edit:SetText(string.format('%.1f', values[group.key]))
	end
	syncing = nil
end

local setValue = function(key, value, step)
	value = roundTo(value, step)
	local values = currentSettings()
	if(values[key] == value) then
		return
	end
	oGlow:SetBorderSetting(key, value)
	syncWidgets()
end

local createStepButton = function(parent, text)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(18, 18)
	button:SetNormalFontObject(GameFontHighlight)
	button:SetText(text)
	return button
end

for i = 1, #SETTINGS do
	local info = SETTINGS[i]
	local row = CreateFrame('Frame', nil, frame)
	row:SetHeight(28)
	row:SetPoint('LEFT', 16, 0)
	row:SetPoint('RIGHT', -16, 0)
	if(i == 1) then
		row:SetPoint('TOPLEFT', borderLabel, 'BOTTOMLEFT', 0, -6)
	else
		row:SetPoint('TOPLEFT', rows[i - 1], 'BOTTOMLEFT', 0, -2)
	end

	local label = ns.createFontString(row)
	label:SetPoint('LEFT')
	label:SetWidth(70)
	label:SetText(info.label)

	local plus = createStepButton(row, '+')
	plus:SetPoint('RIGHT')

	local edit = ns.createEditBox(row)
	edit:ClearAllPoints()
	edit:SetSize(36, 18)
	edit:SetPoint('RIGHT', plus, 'LEFT', -2, 0)
	edit:SetJustifyH'CENTER'
	edit:SetMaxLetters(6)

	local minus = createStepButton(row, '-')
	minus:SetPoint('RIGHT', edit, 'LEFT', -2, 0)

	local slider = CreateFrame('Slider', 'oGlowConfigSlider'..info.key, row, 'OptionsSliderTemplate')
	slider:SetPoint('LEFT', label, 'RIGHT', 8, 0)
	slider:SetPoint('RIGHT', minus, 'LEFT', -8, 0)
	slider:SetMinMaxValues(info.min, info.max)
	slider:SetValueStep(info.step)
	_G[slider:GetName()..'Text']:SetText''
	_G[slider:GetName()..'Low']:SetText''
	_G[slider:GetName()..'High']:SetText''

	row.key = info.key
	row.format = info.format
	row.step = info.step
	row.min = info.min
	row.max = info.max
	row.slider = slider
	row.edit = edit
	rows[i] = row

	slider:SetScript('OnValueChanged', function(self)
		if(syncing) then return end
		local value = roundTo(self:GetValue(), info.step)
		if(value < info.min) then value = info.min end
		if(value > info.max) then value = info.max end
		setValue(info.key, value, info.step)
	end)

	edit.update = function(self)
		if(syncing) then return end
		local value = tonumber(self:GetText())
		if(not value) then return end
		if(value < info.min) then value = info.min end
		if(value > info.max) then value = info.max end
		setValue(info.key, value, info.step)
	end

	edit.validate = function(self, text)
		if(text == '' or text == '-' or text == '.' or text == '-.') then
			return true
		end
		local value = tonumber(text)
		return value ~= nil
	end

	local step = function(delta)
		local value = currentSettings()[info.key] + (delta * info.step)
		if(value < info.min) then value = info.min end
		if(value > info.max) then value = info.max end
		setValue(info.key, value, info.step)
	end

	minus:SetScript('OnClick', function() step(-1) end)
	plus:SetScript('OnClick', function() step(1) end)
end

local directionalLabel = ns.createFontString(frame, 'GameFontNormalSmall')
directionalLabel:SetPoint('TOPLEFT', rows[#rows], 'BOTTOMLEFT', 0, -12)
directionalLabel:SetText'Directional offsets'

local sideRow = CreateFrame('Frame', nil, frame)
sideRow:SetHeight(28)
sideRow:SetPoint('TOPLEFT', directionalLabel, 'BOTTOMLEFT', 0, -4)
sideRow:SetPoint('RIGHT', -16, 0)

local SIDES = {
	{key = 'offsetL', label = 'L'},
	{key = 'offsetT', label = 'T'},
	{key = 'offsetR', label = 'R'},
	{key = 'offsetB', label = 'B'},
}

for i = 1, #SIDES do
	local info = SIDES[i]
	local group = CreateFrame('Frame', nil, sideRow)
	group:SetSize(82, 28)
	if(i == 1) then
		group:SetPoint('LEFT', 0, 0)
	else
		group:SetPoint('LEFT', sideEdits[i - 1], 'RIGHT', 4, 0)
	end

	local label = ns.createFontString(group)
	label:SetPoint('LEFT', 0, 0)
	label:SetWidth(10)
	label:SetText(info.label)

	local minus = createStepButton(group, '-')
	minus:SetPoint('LEFT', label, 'RIGHT', 2, 0)

	local edit = ns.createEditBox(group)
	edit:ClearAllPoints()
	edit:SetSize(32, 18)
	edit:SetPoint('LEFT', minus, 'RIGHT', 1, 0)
	edit:SetJustifyH'CENTER'
	edit:SetMaxLetters(5)

	local plus = createStepButton(group, '+')
	plus:SetPoint('LEFT', edit, 'RIGHT', 1, 0)

	edit.update = function(self)
		if(syncing) then return end
		local value = tonumber(self:GetText())
		if(not value) then return end
		if(value < -8) then value = -8 end
		if(value > 8) then value = 8 end
		setValue(info.key, value, .5)
	end

	edit.validate = function(self, text)
		if(text == '' or text == '-' or text == '.' or text == '-.' or text == '-0.') then
			return true
		end
		return tonumber(text) ~= nil
	end

	minus:SetScript('OnClick', function()
		local value = currentSettings()[info.key] - .5
		if(value < -8) then value = -8 end
		setValue(info.key, value, .5)
	end)
	plus:SetScript('OnClick', function()
		local value = currentSettings()[info.key] + .5
		if(value > 8) then value = 8 end
		setValue(info.key, value, .5)
	end)

	group.key = info.key
	group.edit = edit
	sideEdits[i] = group
end

local qualityLabel = ns.createFontString(frame, 'GameFontNormalSmall')
qualityLabel:SetPoint('TOPLEFT', sideRow, 'BOTTOMLEFT', 0, -12)
qualityLabel:SetText'Min. quality'

local resetLabel = ns.createFontString(frame, 'GameFontNormalSmall')
resetLabel:SetPoint('TOP', qualityLabel, 'TOP')
resetLabel:SetPoint('RIGHT', -16, 0)
resetLabel:SetText'Reset Above'

local resetBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
resetBtn:SetSize(64, 22)
resetBtn:SetPoint('TOP', resetLabel, 'BOTTOM', 0, -6)
resetBtn:SetPoint('RIGHT', -16, 0)
resetBtn:SetText'Reset'
resetBtn:SetScript('OnClick', function()
	oGlow:ResetBorderSettings()
	syncWidgets()
	frame:RefreshQuality()
	frame:RefreshGlowMin()
end)

local DROP_WIDTH = 90

local qualityText = function(i)
	return ns.Hex(colorTable[i]) .. _G['ITEM_QUALITY'..i..'_DESC']
end

local qualityDrop = CreateFrame('Button', 'oGlowConfigQualityThreshold', frame, 'UIDropDownMenuTemplate')
qualityDrop:SetPoint('TOPLEFT', qualityLabel, 'BOTTOMLEFT', -16, -2)
UIDropDownMenu_SetWidth(qualityDrop, DROP_WIDTH)

local glowDrop = CreateFrame('Button', 'oGlowConfigGlowThreshold', frame, 'UIDropDownMenuTemplate')
glowDrop:SetPoint('TOPLEFT', qualityDrop, 'TOPRIGHT', -16, 0)
UIDropDownMenu_SetWidth(glowDrop, DROP_WIDTH)

local glowLabel = ns.createFontString(frame, 'GameFontNormalSmall')
glowLabel:SetPoint('BOTTOMLEFT', glowDrop, 'TOPLEFT', 16, 2)
glowLabel:SetText'Min. glow'

do
	local qualityIndex = function()
		local threshold = 1
		local filters = oGlowDB.FilterSettings
		if(filters and filters.quality) then
			threshold = filters.quality
		end
		return threshold + 1
	end

	local DropDown_OnClick = function(self)
		if(not oGlowDB.FilterSettings) then
			oGlowDB.FilterSettings = {}
		end
		oGlowDB.FilterSettings.quality = self.value - 1
		oGlow:CallOptionCallbacks()
		updateAllPipes()
		UIDropDownMenu_SetSelectedValue(qualityDrop, self.value)
		UIDropDownMenu_SetText(qualityDrop, qualityText(self.value))
	end

	local DropDown_init = function()
		local selected = qualityIndex()
		for i = 0, 7 do
			local info = UIDropDownMenu_CreateInfo()
			info.text = qualityText(i)
			info.value = i
			info.func = DropDown_OnClick
			info.checked = (i == selected)
			UIDropDownMenu_AddButton(info)
		end
	end

	local UpdateSelected = function()
		local i = qualityIndex()
		UIDropDownMenu_SetSelectedValue(qualityDrop, i)
		UIDropDownMenu_SetText(qualityDrop, qualityText(i))
	end

	qualityDrop:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:SetText('Lowest item quality that should show a border.', nil, nil, nil, nil, 1)
	end)
	qualityDrop:SetScript('OnLeave', GameTooltip_Hide)

	function frame:RefreshQuality()
		UIDropDownMenu_Initialize(qualityDrop, DropDown_init)
		UpdateSelected()
	end
end

do
	local glowIndex = function()
		return oGlow:GetBorderSettings().glowMin or 2
	end

	local Glow_OnClick = function(self)
		oGlow:SetBorderSetting('glowMin', self.value)
		UIDropDownMenu_SetSelectedValue(glowDrop, self.value)
		UIDropDownMenu_SetText(glowDrop, qualityText(self.value))
	end

	local Glow_init = function()
		local selected = glowIndex()
		for i = 0, 7 do
			local info = UIDropDownMenu_CreateInfo()
			info.text = qualityText(i)
			info.value = i
			info.func = Glow_OnClick
			info.checked = (i == selected)
			UIDropDownMenu_AddButton(info)
		end
	end

	local UpdateSelected = function()
		local i = glowIndex()
		UIDropDownMenu_SetSelectedValue(glowDrop, i)
		UIDropDownMenu_SetText(glowDrop, qualityText(i))
	end

	glowDrop:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:SetText('Lowest item quality that should show an inward glow.', nil, nil, nil, nil, 1)
	end)
	glowDrop:SetScript('OnLeave', GameTooltip_Hide)

	function frame:RefreshGlowMin()
		UIDropDownMenu_Initialize(glowDrop, Glow_init)
		UpdateSelected()
	end
end

local colorLabel = ns.createFontString(frame, 'GameFontNormalSmall')
colorLabel:SetPoint('TOPLEFT', qualityDrop, 'BOTTOMLEFT', 16, -8)
colorLabel:SetText'Colors'

local box = CreateFrame('Frame', nil, frame)
box:SetBackdrop(BACKDROP)
box:SetBackdropColor(.1, .1, .1, .5)
box:SetBackdropBorderColor(.3, .3, .3, 1)
box:SetPoint('TOPLEFT', colorLabel, 'BOTTOMLEFT', 0, -4)
box:SetPoint('RIGHT', -16, 0)

local Swatch_Update = function(self, update, r, g, b)
	local row = self:GetParent()
	self:GetNormalTexture():SetVertexColor(r, g, b)
	row.nameLabel:SetTextColor(r, g, b)

	row.swatch.r = r
	row.swatch.g = g
	row.swatch.b = b

	row.redLabel:SetNumber(math.floor(r * 255 + .5))
	row.greenLabel:SetNumber(math.floor(g * 255 + .5))
	row.blueLabel:SetNumber(math.floor(b * 255 + .5))

	if(update) then
		oGlow:RegisterColor(row.id, r, g, b)
		oGlow:RefreshBorders()
	end
end

local Swatch_Ok = function()
	Swatch_Update(box.colorPicker, true, ColorPickerFrame:GetColorRGB())
end

local Swatch_Cancel = function()
	Swatch_Update(box.colorPicker, true, ColorPicker_GetPreviousValues())
end

local Label_Update = function(self)
	local row = self:GetParent()
	local r = row.redLabel:GetNumber() / 255
	local g = row.greenLabel:GetNumber() / 255
	local b = row.blueLabel:GetNumber() / 255
	Swatch_Update(row.swatch, true, r, g, b)
end

local Label_Validate = function(self)
	if(self:GetNumber() > 255) then
		return
	end
	return true
end

local Reset_OnClick = function(self)
	local row = self:GetParent()
	Swatch_Update(row.swatch, nil, oGlow:ResetColor(row.id))
	oGlow:RefreshBorders()
end

local colorRows = {}
for i = 0, 7 do
	local row = CreateFrame('Button', nil, box)
	row:SetBackdrop(BACKDROP)
	row:SetBackdropBorderColor(.3, .3, .3)
	row:SetBackdropColor(.1, .1, .1, .5)
	row:SetHeight(24)
	row:SetPoint('LEFT', 6, 0)
	row:SetPoint('RIGHT', -25, 0)
	if(i == 0) then
		row:SetPoint('TOP', 0, -8)
	else
		row:SetPoint('TOP', colorRows[i - 1], 'BOTTOM')
	end

	local swatch = ns.createColorSwatch(row)
	swatch:SetPoint('RIGHT', -10, 0)
	swatch.swatchFunc = Swatch_Ok
	swatch.cancelFunc = Swatch_Cancel
	row.swatch = swatch

	local blueLabel = ns.createEditBox(row)
	blueLabel:SetPoint('RIGHT', swatch, 'LEFT', -5, 0)
	blueLabel:SetJustifyH'CENTER'
	blueLabel:SetNumeric(true)
	blueLabel.update = Label_Update
	blueLabel.validate = Label_Validate
	row.blueLabel = blueLabel

	local greenLabel = ns.createEditBox(row)
	greenLabel:SetPoint('RIGHT', blueLabel, 'LEFT', -5, 0)
	greenLabel:SetJustifyH'CENTER'
	greenLabel:SetNumeric(true)
	greenLabel.update = Label_Update
	greenLabel.validate = Label_Validate
	row.greenLabel = greenLabel

	local redLabel = ns.createEditBox(row)
	redLabel:SetPoint('RIGHT', greenLabel, 'LEFT', -5, 0)
	redLabel:SetJustifyH'CENTER'
	redLabel:SetNumeric(true)
	redLabel.update = Label_Update
	redLabel.validate = Label_Validate
	row.redLabel = redLabel

	local nameLabel = ns.createFontString(row)
	nameLabel:SetPoint('LEFT', 10, 0)
	nameLabel:SetPoint('RIGHT', redLabel, 'LEFT', -6, 0)
	nameLabel:SetJustifyH'LEFT'
	row.nameLabel = nameLabel

	local reset = CreateFrame('Button', nil, row)
	reset:SetSize(16, 16)
	reset:SetPoint('LEFT', row, 'RIGHT')
	reset:SetNormalTexture[[Interface\Buttons\UI-Panel-MinimizeButton-Up]]
	reset:SetPushedTexture[[Interface\Buttons\UI-Panel-MinimizeButton-Down]]
	reset:SetHighlightTexture[[Interface\Buttons\UI-Panel-MinimizeButton-Highlight]]
	reset:SetScript('OnClick', Reset_OnClick)
	reset:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText(RESET)
	end)
	reset:SetScript('OnLeave', GameTooltip_Hide)

	row.id = i
	colorRows[i] = row
end
box:SetHeight(8 * 24 + 16)

local createCheckBox = function(parent)
	local check = CreateFrame('CheckButton', nil, parent)
	check:SetSize(16, 16)
	check:SetNormalTexture[[Interface\Buttons\UI-CheckBox-Up]]
	check:SetPushedTexture[[Interface\Buttons\UI-CheckBox-Down]]
	check:SetHighlightTexture[[Interface\Buttons\UI-CheckBox-Highlight]]
	check:SetCheckedTexture[[Interface\Buttons\UI-CheckBox-Check]]
	return check
end

local pipes = CreateFrame('Frame', 'oGlowPipesConfig', frame)
pipes:SetWidth(253)
pipes:SetPoint('TOPLEFT', frame, 'TOPRIGHT', -2, 0)
pipes:SetBackdrop(BACKDROP)
pipes:SetBackdropColor(.1, .1, .1, .9)
pipes:SetBackdropBorderColor(.3, .3, .3, 1)
pipes:EnableMouse(true)
pipes:Hide()

local pipesClose = CreateFrame('Button', nil, pipes, 'UIPanelCloseButton')
pipesClose:SetPoint('TOPRIGHT', 2, 2)

local pipesTitle = ns.createFontString(pipes, 'GameFontNormal')
pipesTitle:SetPoint('TOP', 0, -12)
pipesTitle:SetText'Show on'

local pipeChecks = {}

local Pipe_OnClick = function(self)
	local pipe = self.pipe
	if(self:GetChecked()) then
		oGlow:EnablePipe(pipe)
		for name in oGlow.IterateFilters() do
			oGlow:RegisterFilterOnPipe(pipe, name)
		end
		oGlow:UpdatePipe(pipe)
	else
		oGlow:DisablePipe(pipe)
	end
end

local refreshPipes = function()
	local n = 0
	for pipe, active, name in oGlow.IteratePipes() do
		n = n + 1
		local check = pipeChecks[n]
		if(not check) then
			check = createCheckBox(pipes)
			if(n == 1) then
				check:SetPoint('TOPLEFT', 16, -36)
			else
				check:SetPoint('TOPLEFT', pipeChecks[n - 1], 'BOTTOMLEFT', 0, -6)
			end
			check:SetScript('OnClick', Pipe_OnClick)

			local label = ns.createFontString(check)
			label:SetPoint('LEFT', check, 'RIGHT', 6, 0)
			check.label = label
			pipeChecks[n] = check
		end

		check.pipe = pipe
		check:SetChecked(active)
		check.label:SetText(name)
		check:Show()
	end

	for i = n + 1, #pipeChecks do
		pipeChecks[i]:Hide()
	end

	pipes:SetHeight(36 + n * 22 + 16)
end

local more = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
more:SetSize(120, 22)
more:SetPoint('BOTTOM', 0, 12)
more:SetText'Show on...'
more:SetScript('OnClick', function()
	if(pipes:IsShown()) then
		pipes:Hide()
	else
		refreshPipes()
		pipes:Show()
	end
end)

local refreshColors = function()
	for i = 0, 7 do
		local r, g, b = unpack(colorTable[i])
		local row = colorRows[i]
		row.nameLabel:SetText(_G['ITEM_QUALITY'..i..'_DESC'])
		Swatch_Update(row.swatch, false, r, g, b)
	end
end

frame:SetScript('OnShow', function()
	syncWidgets()
	frame:RefreshQuality()
	frame:RefreshGlowMin()
	refreshColors()
end)

frame:SetScript('OnHide', function()
	pipes:Hide()
end)

SLASH_OGLOW_UI1 = '/oglow'
SlashCmdList['OGLOW_UI'] = function()
	if(frame:IsShown()) then
		frame:Hide()
	else
		frame:Show()
	end
end
