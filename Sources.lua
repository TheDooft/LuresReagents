local _, ns = ...

-- Optional inventory addons that know what the player's other characters hold.
-- Each one only has to answer "how many of this item does the account own", which
-- is what the craftable maths needs; the per-character breakdown is left to those
-- addons, which already print their own into the same tooltip.
--
-- Guild banks are deliberately excluded everywhere: shared stock is not reliably
-- the player's to spend on a craft.
--
-- Providers are tried in this order.

local providers = {}

local function AddProvider(id, name, isAvailable, getTotal)
	table.insert(providers, { id = id, name = name, IsAvailable = isAvailable, GetTotal = getTotal })
end

-- Syndicator: Syndicator.API.GetInventoryInfoByItemID returns
--   { characters = { { bags, bank, mail, equipped, void, auctions }, ... },
--     guilds = { { bank }, ... },
--     warband = { [1] = count } }
AddProvider("syndicator", "Syndicator",
	function()
		if not Syndicator or not Syndicator.API or not Syndicator.API.GetInventoryInfoByItemID then
			return false
		end
		-- IsReady guards against querying before the saved variables are digested.
		return not Syndicator.API.IsReady or Syndicator.API.IsReady()
	end,
	function(itemID)
		local info = Syndicator.API.GetInventoryInfoByItemID(itemID)
		if not info then
			return nil
		end

		local total = info.warband and info.warband[1] or 0
		for _, character in ipairs(info.characters or {}) do
			total = total + (character.bags or 0) + (character.bank or 0) + (character.mail or 0)
		end
		return total
	end)

-- Altoholic, through the DataStore modules it ships with.
-- DataStore:GetContainerItemCount(characterKey, itemID) -> bags, bank, reagentBag.
-- Its containers cover characters only, so the warband bank is read live and added.
AddProvider("altoholic", "Altoholic",
	function()
		return DataStore ~= nil
			and DataStore.GetContainerItemCount ~= nil
			and DataStore.GetRealms ~= nil
			and DataStore.GetCharacters ~= nil
	end,
	function(itemID)
		local total = 0
		for realm in pairs(DataStore:GetRealms()) do
			for _, characterKey in pairs(DataStore:GetCharacters(realm)) do
				local bags, bank, reagentBag = DataStore:GetContainerItemCount(characterKey, itemID)
				total = total + (bags or 0) + (bank or 0) + (reagentBag or 0)
			end
		end

		-- Difference between "bags plus account bank" and "bags" is the warband bank.
		local withWarband = C_Item.GetItemCount(itemID, false, false, false, true)
		local withoutWarband = C_Item.GetItemCount(itemID, false, false, false, false)
		return total + math.max(0, withWarband - withoutWarband)
	end)

-- Warband Nexus: WarbandNexus:GetDetailedItemCountsFast returns
--   { warbandBank, personalBankTotal, guilds = { ... },
--     characters = { { bagCount, bankCount, total }, ... } }
AddProvider("warbandnexus", "Warband Nexus",
	function()
		return WarbandNexus ~= nil and WarbandNexus.GetDetailedItemCountsFast ~= nil
	end,
	function(itemID)
		local info = WarbandNexus:GetDetailedItemCountsFast(itemID)
		if not info then
			return nil
		end

		local total = info.warbandBank or 0
		for _, character in ipairs(info.characters or {}) do
			total = total + (character.total or 0)
		end
		return total
	end)

ns.providers = providers

-- The provider currently in use, or nil when counting this character only.
function ns.GetActiveProvider()
	local wanted = ns.db and ns.db.dataSource or "auto"
	if wanted == "character" then
		return nil
	end

	for _, provider in ipairs(providers) do
		if wanted == "auto" or wanted == provider.id then
			-- Third-party addons change; never let one of them break a tooltip.
			local ok, available = pcall(provider.IsAvailable)
			if ok and available then
				return provider
			end
		end
	end
end

-- Returns the total the recipe maths should use, how much of it is reachable by
-- the character being played, and the provider that supplied the total (if any).
function ns.GetOwned(itemID)
	local db = ns.db
	local bank = db.includeBank or false
	local here = C_Item.GetItemCount(itemID, bank, false, bank, db.includeWarband or false)

	local provider = ns.GetActiveProvider()
	if provider then
		local ok, total = pcall(provider.GetTotal, itemID)
		-- A provider's cache can lag behind what the client can see right now, so
		-- never let it report less than the live count.
		if ok and total and total > here then
			return total, here, provider
		end
	end

	return here, here, nil
end
