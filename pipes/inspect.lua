-- Inspect paperdoll glows. WotLK inspect data is on the unit as soon as the
-- frame exists; Cata added INSPECT_READY. Do not wait on that event here.
--
-- ChromieCraft inspect can briefly expose the transmog appearance, then the
-- worn item. Wait 0.2s and glow from the last link per slot.

if(select(4, GetAddOnInfo("Fizzle"))) then return end

local slots = {
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
	"Hands", "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand",
	"SecondaryHand", "Ranged", "Tabard",
}

local HIDDEN_ITEM_ID = 1
local SETTLE_TIME = 0.2
local SETTLE_FRAMES = 5

local lastLink = {}
local settleGuid
local settleElapsed = 0
local settleFrames = 0
local settling

local pollFrame = CreateFrame'Frame'
pollFrame:Hide()
local hooked

local function inspectGuid(unit)
	return unit and UnitGUID(unit) or nil
end

local function slotFrame(slotName)
	return _G['Inspect' .. slotName .. 'Slot']
end

local function itemIdFromLink(link)
	if(not link) then
		return nil
	end
	return tonumber(string.match(link, 'item:(%d+)'))
end

local function wipeLast()
	for k in pairs(lastLink) do
		lastLink[k] = nil
	end
end

local function noteSlot(unit, slotID)
	if(not unit or not slotID) then
		return
	end
	local link = GetInventoryItemLink(unit, slotID)
	if(link) then
		lastLink[slotID] = link
	end
end

local function snapshotAll(unit)
	for key in ipairs(slots) do
		noteSlot(unit, key % 20)
	end
end

local function glowLink(link)
	local id = itemIdFromLink(link)
	if(not id or id == HIDDEN_ITEM_ID) then
		return nil
	end
	return link
end

local function applySettled()
	for key, slotName in ipairs(slots) do
		local frame = slotFrame(slotName)
		if(frame) then
			oGlow:CallFilters('inspect', frame, glowLink(lastLink[key % 20]))
		end
	end
end

local function clearAll()
	for _, slotName in ipairs(slots) do
		local frame = slotFrame(slotName)
		if(frame) then
			oGlow:CallFilters('inspect', frame)
		end
	end
end

local function beginSettle(unit)
	if(not unit) then
		return
	end
	local guid = inspectGuid(unit)
	if(settleGuid ~= guid) then
		wipeLast()
		clearAll()
		settleGuid = guid
	end
	settling = true
	settleElapsed = 0
	settleFrames = 0
	snapshotAll(unit)
	pollFrame:Show()
end

pollFrame:SetScript('OnUpdate', function(self, elapsed)
	elapsed = elapsed or arg1 or 0
	if(not InspectFrame or not InspectFrame:IsShown() or not InspectFrame.unit) then
		self:Hide()
		settling = nil
		return
	end
	local unit = InspectFrame.unit
	if(inspectGuid(unit) ~= settleGuid) then
		beginSettle(unit)
		return
	end
	snapshotAll(unit)
	if(not settling) then
		self:Hide()
		return
	end
	settleElapsed = settleElapsed + elapsed
	settleFrames = settleFrames + 1
	if(settleElapsed >= SETTLE_TIME and settleFrames >= SETTLE_FRAMES) then
		settling = nil
		applySettled()
		self:Hide()
	end
end)

local update = function()
	if(not InspectFrame or not InspectFrame:IsShown() or not oGlow:IsPipeEnabled'inspect') then return end
	local unit = InspectFrame.unit
	if(not unit) then
		clearAll()
		return
	end
	beginSettle(unit)
end

local UNIT_INVENTORY_CHANGED = function(self, event, unit)
	unit = unit or arg1
	if(not InspectFrame or not InspectFrame:IsShown() or InspectFrame.unit ~= unit) then
		return
	end
	if(inspectGuid(unit) ~= settleGuid) then
		beginSettle(unit)
		return
	end
	snapshotAll(unit)
	if(not settling) then
		applySettled()
	end
end

local function hookInspect()
	if(hooked or not InspectFrame) then return end
	hooked = true
	InspectFrame:HookScript('OnShow', update)
	InspectFrame:HookScript('OnHide', function()
		pollFrame:Hide()
		settling = nil
		settleGuid = nil
		wipeLast()
		clearAll()
	end)
	if(InspectPaperDollFrame_OnShow) then
		hooksecurefunc('InspectPaperDollFrame_OnShow', update)
	end
	if(InspectPaperDollItemSlotButton_Update) then
		hooksecurefunc('InspectPaperDollItemSlotButton_Update', function(button)
			button = button or this
			if(not button or not InspectFrame or not InspectFrame:IsShown()) then return end
			local unit = InspectFrame.unit
			if(not unit) then return end
			if(inspectGuid(unit) ~= settleGuid) then
				beginSettle(unit)
				return
			end
			noteSlot(unit, button:GetID())
			if(not settling) then
				applySettled()
			end
		end)
	end
end

local function ADDON_LOADED(self, event, addon)
	addon = addon or arg1
	if(addon == 'Blizzard_InspectUI') then
		hookInspect()
		self:RegisterEvent('UNIT_INVENTORY_CHANGED', UNIT_INVENTORY_CHANGED)
		if(select(4, GetBuildInfo()) >= 40000) then
			self:RegisterEvent('INSPECT_READY', update)
		end
		self:UnregisterEvent('ADDON_LOADED', ADDON_LOADED)
		update()
	end
end

local enable = function(self)
	if(IsAddOnLoaded('Blizzard_InspectUI')) then
		hookInspect()
		self:RegisterEvent('UNIT_INVENTORY_CHANGED', UNIT_INVENTORY_CHANGED)
		if(select(4, GetBuildInfo()) >= 40000) then
			self:RegisterEvent('INSPECT_READY', update)
		end
		if(InspectFrame and InspectFrame:IsShown()) then
			update()
		end
	else
		self:RegisterEvent('ADDON_LOADED', ADDON_LOADED)
	end
end

local disable = function(self)
	self:UnregisterEvent('ADDON_LOADED', ADDON_LOADED)
	self:UnregisterEvent('UNIT_INVENTORY_CHANGED', UNIT_INVENTORY_CHANGED)
	if(select(4, GetBuildInfo()) >= 40000) then
		self:UnregisterEvent('INSPECT_READY', update)
	end
	pollFrame:Hide()
	settling = nil
	settleGuid = nil
	wipeLast()
	clearAll()
end

oGlow:RegisterPipe('inspect', enable, disable, update, 'Inspect frame', nil)
