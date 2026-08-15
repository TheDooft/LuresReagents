local _, ns = ...
local L = ns.L

local format, floor = string.format, math.floor

-- Present since 12.0; kept behind a fallback so the file stays loadable on older clients.
local issecretvalue = issecretvalue or function() return false end

local HEADER = "|cffffd100"
local NAME   = "|cffffffff"
local DIM    = "|cff9d9d9d"
local GOOD   = "|cff20ff20"
local BAD    = "|cffff4040"
local WARN   = "|cffff8040"
local OFF    = "|r"

--------------------------------------------------------------------------------
-- Re-entry guard
--------------------------------------------------------------------------------

-- Tooltip frames are pooled and the post-call runs again on every refresh, so a
-- naive implementation appends its lines over and over. Claim the tooltip once
-- per display and release it when the frame is cleared.
local hooked = setmetatable({}, { __mode = "k" })

local function ClaimTooltip(tooltip)
	if tooltip.luresReagentsClaimed then
		return false
	end

	if not hooked[tooltip] then
		hooked[tooltip] = true
		tooltip:HookScript("OnTooltipCleared", function(self)
			self.luresReagentsClaimed = nil
		end)
	end

	tooltip.luresReagentsClaimed = true
	return true
end

--------------------------------------------------------------------------------
-- Line builders
--------------------------------------------------------------------------------

local function PerCraft(lure, reagentID)
	for _, reagent in ipairs(lure.reagents) do
		if reagent.id == reagentID then
			return reagent.count
		end
	end
	return 0
end

-- On a fish: which lures consume it, and how many of each you could make.
local function AddReagentLines(tooltip, itemID)
	local db = ns.db
	local owned = ns.GetOwned(itemID)

	tooltip:AddLine(" ")
	if db.showCounts then
		tooltip:AddDoubleLine(HEADER .. L.USED_IN_LURES .. OFF, DIM .. format(L.YOU_HAVE, owned) .. OFF)
	else
		tooltip:AddLine(HEADER .. L.USED_IN_LURES .. OFF)
	end

	for _, lureID in ipairs(ns.reagentToLures[itemID]) do
		local lure = ns.lures[lureID]
		local perCraft = PerCraft(lure, itemID)
		if perCraft > 0 then
			local crafts, limiting = ns.GetCraftable(lureID)

			local right = DIM .. format(L.PER_CRAFT, perCraft) .. OFF
			if db.showCraftable then
				right = right .. DIM .. "  ·  " .. OFF
					.. (crafts > 0 and GOOD or BAD) .. format(L.CRAFTABLE, crafts) .. OFF
			end
			tooltip:AddDoubleLine("  " .. NAME .. ns.GetItemName(lureID, lure.name) .. OFF, right, 1, 1, 1, 1, 1, 1)

			-- Name the reagent that actually caps the recipe, when it is not this one.
			if db.showShortage and limiting and limiting.id ~= itemID then
				local selfCrafts = floor(owned / perCraft)
				if selfCrafts > crafts then
					local missing = selfCrafts * limiting.count - ns.GetOwned(limiting.id)
					tooltip:AddLine("    " .. WARN
						.. format(L.SHORT_OF, missing, ns.GetItemName(limiting.id, limiting.name)) .. OFF)
				end
			end
		end
	end
end

-- On a lure: what it takes to craft, and how much of that you already hold.
local function AddLureLines(tooltip, itemID)
	local db = ns.db
	local lure = ns.lures[itemID]
	local crafts = ns.GetCraftable(itemID)

	tooltip:AddLine(" ")
	if db.showCraftable then
		tooltip:AddDoubleLine(HEADER .. L.REAGENTS .. OFF,
			(crafts > 0 and GOOD or BAD) .. format(L.CAN_CRAFT, crafts) .. OFF)
	else
		tooltip:AddLine(HEADER .. L.REAGENTS .. OFF)
	end

	for _, reagent in ipairs(lure.reagents) do
		local right
		if db.showCounts then
			local owned = ns.GetOwned(reagent.id)
			right = (owned >= reagent.count and GOOD or BAD)
				.. format(L.HAVE_OF_NEED, owned, reagent.count) .. OFF
		else
			right = DIM .. format(L.PER_CRAFT, reagent.count) .. OFF
		end
		tooltip:AddDoubleLine("  " .. NAME .. ns.GetItemName(reagent.id, reagent.name) .. OFF, right, 1, 1, 1, 1, 1, 1)
	end
end

--------------------------------------------------------------------------------
-- Hook
--------------------------------------------------------------------------------

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
	local db = ns.db
	if not db or not db.enabled or not tooltip or not data then
		return
	end

	local itemID = data.id
	-- Check for a secret value before anything else: comparing one, or using it as
	-- a table key, raises and aborts the calling code.
	if issecretvalue(itemID) or not itemID then
		return
	end

	local asReagent = db.showOnReagents and ns.reagentToLures[itemID] ~= nil
	local asLure = db.showOnLures and ns.lures[itemID] ~= nil
	if not (asReagent or asLure) then
		return
	end

	if not ClaimTooltip(tooltip) then
		return
	end

	if asReagent then
		AddReagentLines(tooltip, itemID)
	end
	if asLure then
		AddLureLines(tooltip, itemID)
	end

	tooltip:Show()
end)
