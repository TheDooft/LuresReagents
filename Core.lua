local addonName, ns = ...
local L = ns.L

local defaults = {
	enabled       = true,
	showOnReagents = true,
	showOnLures   = true,
	showCounts    = true,
	showCraftable = true,
	showShortage  = true,
	includeBank   = true,
	includeWarband = true,
}

-- Order used by both the options panel and the slash command listing.
local optionOrder = {
	"enabled", "showOnReagents", "showOnLures", "showCounts",
	"showCraftable", "showShortage", "includeBank", "includeWarband",
}

local optionLabels = {
	enabled        = { L.OPT_ENABLED,     L.OPT_ENABLED_TT },
	showOnReagents = { L.OPT_ON_REAGENTS, L.OPT_ON_REAGENTS_TT },
	showOnLures    = { L.OPT_ON_LURES,    L.OPT_ON_LURES_TT },
	showCounts     = { L.OPT_COUNTS,      L.OPT_COUNTS_TT },
	showCraftable  = { L.OPT_CRAFTABLE,   L.OPT_CRAFTABLE_TT },
	showShortage   = { L.OPT_SHORT,       L.OPT_SHORT_TT },
	includeBank    = { L.OPT_BANK,        L.OPT_BANK_TT },
	includeWarband = { L.OPT_WARBAND,     L.OPT_WARBAND_TT },
}

local db

--------------------------------------------------------------------------------
-- Item helpers
--------------------------------------------------------------------------------

-- The client only knows an item's localised name once it has been cached. Ask for
-- it, and fall back to the enUS name shipped in Data.lua until it arrives.
function ns.GetItemName(itemID, fallback)
	local name = C_Item.GetItemNameByID(itemID)
	if name then
		return name
	end
	C_Item.RequestLoadItemDataByID(itemID)
	return fallback or tostring(itemID)
end

-- C_Item.GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)
function ns.GetOwned(itemID)
	local bank = db.includeBank or false
	return C_Item.GetItemCount(itemID, bank, false, bank, db.includeWarband or false)
end

-- How many of `lureID` the recipe allows, given what is currently owned.
-- Also reports the reagent that runs out first, so the tooltip can name it.
function ns.GetCraftable(lureID)
	local lure = ns.lures[lureID]
	if not lure then
		return 0
	end

	local crafts, limiting
	for _, reagent in ipairs(lure.reagents) do
		local possible = math.floor(ns.GetOwned(reagent.id) / reagent.count)
		if not crafts or possible < crafts then
			crafts, limiting = possible, reagent
		end
	end

	return crafts or 0, limiting
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local settingsCategory

local function RegisterSettings()
	if settingsCategory or not Settings then
		return
	end

	local category = Settings.RegisterVerticalLayoutCategory(L.OPT_TITLE)
	settingsCategory = category

	for _, key in ipairs(optionOrder) do
		local label, tooltip = optionLabels[key][1], optionLabels[key][2]
		local setting = Settings.RegisterProxySetting(
			category,
			addonName .. "_" .. key,
			Settings.VarType.Boolean,
			label,
			defaults[key],
			function() return db[key] end,
			function(value) db[key] = value end
		)
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Lures Reagents|r: " .. message)
end

local function PrintOptions()
	Print(L.SLASH_HEADER)
	for _, key in ipairs(optionOrder) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"  |cffffd100/lr %s|r — %s (%s)",
			key, optionLabels[key][1], db[key] and L.SLASH_ON or L.SLASH_OFF
		))
	end
	DEFAULT_CHAT_FRAME:AddMessage("  " .. L.SLASH_CONFIG)
end

SLASH_LURESREAGENTS1 = "/lr"
SLASH_LURESREAGENTS2 = "/luresreagents"
SlashCmdList.LURESREAGENTS = function(input)
	local argument = string.lower(string.match(input or "", "^%s*(%S*)"))

	if argument == "" then
		PrintOptions()
	elseif argument == "config" or argument == "options" then
		if settingsCategory then
			Settings.OpenToCategory(settingsCategory:GetID())
		end
	else
		-- Option keys are camelCase but the argument was lowered, so match case-insensitively.
		for _, key in ipairs(optionOrder) do
			if string.lower(key) == argument then
				db[key] = not db[key]
				Print(optionLabels[key][1] .. ": " .. (db[key] and L.SLASH_ON or L.SLASH_OFF))
				return
			end
		end
		Print(string.format(L.SLASH_UNKNOWN, argument))
	end
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and ... == addonName then
		LuresReagentsDB = LuresReagentsDB or {}
		db = LuresReagentsDB
		for key, value in pairs(defaults) do
			if db[key] == nil then
				db[key] = value
			end
		end
		ns.db = db
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		RegisterSettings()
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
