local addonName, ns = ...
local L = ns.L

local defaults = {
	enabled        = true,
	showOnReagents = true,
	showOnLures    = true,
	showIcons      = true,
	showCounts     = true,
	showCraftable  = true,
	showShortage   = true,
	includeBank    = true,
	includeWarband = true,
	-- Not a toggle: "auto" picks the first available inventory addon, "character"
	-- counts only the character being played, or name a provider from Sources.lua.
	dataSource     = "auto",
}

-- Order used by both the options panel and the slash command listing.
local optionOrder = {
	"enabled", "showOnReagents", "showOnLures", "showIcons", "showCounts",
	"showCraftable", "showShortage", "includeBank", "includeWarband",
}

local optionLabels = {
	enabled        = { L.OPT_ENABLED,     L.OPT_ENABLED_TT },
	showOnReagents = { L.OPT_ON_REAGENTS, L.OPT_ON_REAGENTS_TT },
	showOnLures    = { L.OPT_ON_LURES,    L.OPT_ON_LURES_TT },
	showIcons      = { L.OPT_ICONS,       L.OPT_ICONS_TT },
	showCounts     = { L.OPT_COUNTS,      L.OPT_COUNTS_TT },
	showCraftable  = { L.OPT_CRAFTABLE,   L.OPT_CRAFTABLE_TT },
	showShortage   = { L.OPT_SHORT,       L.OPT_SHORT_TT },
	includeBank    = { L.OPT_BANK,        L.OPT_BANK_TT },
	includeWarband = { L.OPT_WARBAND,     L.OPT_WARBAND_TT },
}

local db
local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
ns.version = version

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

-- The item's icon, as a tooltip texture escape. Nil until the client has the
-- item cached, in which case the caller just gets no icon this time round.
function ns.GetItemIcon(itemID)
	local icon = C_Item.GetItemIconByID(itemID)
	if not icon then
		return ""
	end
	return string.format("|T%d:16:16:0:0|t ", icon)
end

-- Stops for the stock gradient: red at nothing, through orange and amber, to
-- green once there is enough for one craft. Each row is {position, r, g, b}.
-- The path goes via orange rather than straight from red to green, which would
-- pass through a muddy olive at the midpoint.
local gradientStops = {
	{ 0.00, 0.90, 0.15, 0.15 },
	{ 0.45, 1.00, 0.45, 0.10 },
	{ 0.75, 1.00, 0.78, 0.15 },
	{ 1.00, 0.25, 0.95, 0.25 },
}

local function Blend(from, to, ratio)
	-- Rounded to an integer: string.format("%02x", ...) rejects a float in 5.4,
	-- which is what the test harness runs on.
	return math.floor((from + (to - from) * ratio) * 255 + 0.5)
end

-- Colour code for `owned`, judged against the amount one craft needs.
function ns.GradientColor(owned, needed)
	local progress
	if needed and needed > 0 then
		progress = math.min(1, math.max(0, owned / needed))
	else
		progress = owned > 0 and 1 or 0
	end

	for index = 2, #gradientStops do
		local from, to = gradientStops[index - 1], gradientStops[index]
		if progress <= to[1] then
			local span = to[1] - from[1]
			local ratio = span > 0 and (progress - from[1]) / span or 0
			return string.format("|cff%02x%02x%02x",
				Blend(from[2], to[2], ratio),
				Blend(from[3], to[3], ratio),
				Blend(from[4], to[4], ratio))
		end
	end
end

-- ns.GetOwned lives in Sources.lua: it has to consult whichever inventory addon
-- is available before falling back to the current character's own count.

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

	-- Which inventory addon supplies the counts. Only providers actually loaded
	-- are offered, so the list matches what the player really has installed.
	local function GetSourceOptions()
		local container = Settings.CreateControlTextContainer()
		container:Add("auto", L.SOURCE_AUTO, L.SOURCE_AUTO_TT)
		container:Add("character", L.SOURCE_CHARACTER, L.SOURCE_CHARACTER_TT)
		for _, provider in ipairs(ns.providers) do
			local ok, available = pcall(provider.IsAvailable)
			if ok and available then
				container:Add(provider.id, provider.name)
			end
		end
		return container:GetData()
	end

	local sourceSetting = Settings.RegisterProxySetting(
		category,
		addonName .. "_dataSource",
		Settings.VarType.String,
		L.OPT_SOURCE,
		defaults.dataSource,
		function() return db.dataSource end,
		function(value) db.dataSource = value end
	)
	Settings.CreateDropdown(category, sourceSetting, GetSourceOptions, L.OPT_SOURCE_TT)

	Settings.RegisterAddOnCategory(category)
end

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Lures Reagents|r: " .. message)
end

local function PrintOptions()
	Print(string.format(L.SLASH_HEADER, version))
	for _, key in ipairs(optionOrder) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"  |cffffd100/lr %s|r — %s (%s)",
			key, optionLabels[key][1], db[key] and L.SLASH_ON or L.SLASH_OFF
		))
	end

	local provider = ns.GetActiveProvider()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"  |cffffd100/lr source <auto|character|id>|r — %s (%s)",
		L.OPT_SOURCE, provider and provider.name or L.SOURCE_CHARACTER
	))
	DEFAULT_CHAT_FRAME:AddMessage("  " .. L.SLASH_CONFIG)
end

local function SetSource(value)
	if value == "auto" or value == "character" then
		db.dataSource = value
	else
		for _, provider in ipairs(ns.providers) do
			if provider.id == value then
				db.dataSource = value
				break
			end
		end
	end

	if db.dataSource ~= value then
		Print(string.format(L.SOURCE_UNKNOWN, value))
		return
	end

	local active = ns.GetActiveProvider()
	Print(string.format(L.SOURCE_SET, active and active.name or L.SOURCE_CHARACTER))
end

SLASH_LURESREAGENTS1 = "/lr"
SLASH_LURESREAGENTS2 = "/luresreagents"
SlashCmdList.LURESREAGENTS = function(input)
	local argument, rest = string.match(input or "", "^%s*(%S*)%s*(%S*)")
	argument = string.lower(argument)

	if argument == "" then
		PrintOptions()
	elseif argument == "config" or argument == "options" then
		if settingsCategory then
			Settings.OpenToCategory(settingsCategory:GetID())
		end
	elseif argument == "source" then
		SetSource(string.lower(rest))
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
