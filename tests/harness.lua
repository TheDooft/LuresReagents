-- Stubs the slice of the WoW API that LuresReagents touches, loads the addon,
-- and hands back the handles a test needs to drive it. Run from the repo root.
--
--   lua tests/run.lua

local ADDON_DIR = os.getenv("LR_ADDON_DIR") or "./"

local bags = {}    -- itemID -> amount in bags
local banked = {}  -- itemID -> amount in bank
local names = {}   -- itemID -> localised name; absent means "not cached yet"
local requested = {}
local frames = {}
local chat = {}

_G.GetLocale = function() return "enUS" end
_G.issecretvalue = function(value) return value == "<SECRET>" end

local warband = {} -- itemID -> amount in the warband bank

_G.C_Item = {
	GetItemNameByID = function(id) return names[id] end,
	RequestLoadItemDataByID = function(id) requested[id] = true end,
	GetItemIconByID = function(id) return 100000 + id end,
	-- GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)
	GetItemCount = function(id, includeBank, _, _, includeAccountBank)
		return (bags[id] or 0)
			+ (includeBank and (banked[id] or 0) or 0)
			+ (includeAccountBank and (warband[id] or 0) or 0)
	end,
}

-- Read the real TOC, so a test can catch the version going missing from it.
local tocVersion
do
	local toc = io.open(ADDON_DIR .. "LuresReagents.toc", "r")
	if toc then
		tocVersion = toc:read("a"):match("##%s*Version:%s*([^\r\n]+)")
		toc:close()
	end
end

_G.C_AddOns = {
	GetAddOnMetadata = function(_, field) return field == "Version" and tocVersion or nil end,
}

local callbacks = {}
_G.Enum = { TooltipDataType = { Item = 0 } }
_G.TooltipDataProcessor = {
	AddTooltipPostCall = function(_, fn) table.insert(callbacks, fn) end,
}

_G.CreateFrame = function()
	local frame = {}
	function frame:RegisterEvent() end
	function frame:UnregisterEvent() end
	function frame:SetScript(_, fn) self.handler = fn end
	table.insert(frames, frame)
	return frame
end

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) table.insert(chat, message) end }
_G.SlashCmdList = {}
_G.Settings = nil -- exercises the guard in RegisterSettings

-- A tooltip that records what was added to it, with colour codes stripped.
local Tooltip = {}
Tooltip.__index = Tooltip

-- Colour codes and texture escapes would swamp every assertion, so the recorded
-- line is cleaned; `raw` keeps the original for the tests that check the markup.
local function strip(text)
	return (tostring(text)
		:gsub("|T.-|t", "")
		:gsub("|c%x%x%x%x%x%x%x%x", "")
		:gsub("|r", ""))
end

function Tooltip.new()
	return setmetatable({ lines = {}, scripts = {}, shown = 0 }, Tooltip)
end
function Tooltip:AddLine(text)
	table.insert(self.lines, { strip(text), raw = tostring(text) })
end
function Tooltip:AddDoubleLine(left, right)
	table.insert(self.lines, { strip(left), strip(right), raw = tostring(left) .. tostring(right) })
end
function Tooltip:HookScript(name, fn) self.scripts[name] = fn end
function Tooltip:Show() self.shown = self.shown + 1 end

function Tooltip:Clear()
	self.lines = {}
	if self.scripts.OnTooltipCleared then
		self.scripts.OnTooltipCleared(self)
	end
end

function Tooltip:Render(title)
	print(title)
	print(("-"):rep(58))
	for _, line in ipairs(self.lines) do
		if line[2] then
			print(line[1] .. (" "):rep(math.max(1, 56 - #line[1] - #line[2])) .. line[2])
		else
			print(line[1])
		end
	end
	print("")
end

local ns = {}
for _, file in ipairs({ "Locales.lua", "Data.lua", "Sources.lua", "Core.lua", "Tooltip.lua" }) do
	assert(loadfile(ADDON_DIR .. file))("LuresReagents", ns)
end

-- Replay the load sequence the client would drive.
for _, frame in ipairs(frames) do
	if frame.handler then
		frame.handler(frame, "ADDON_LOADED", "LuresReagents")
		frame.handler(frame, "PLAYER_LOGIN")
	end
end

local function ShowItem(tooltip, itemID)
	for _, fn in ipairs(callbacks) do
		fn(tooltip, { id = itemID })
	end
end

-- Stand-ins for the optional inventory addons, shaped like the real return
-- values read out of Syndicator, DataStore and WarbandNexus.
local function StubSyndicator(perItem)
	_G.Syndicator = {
		API = {
			IsReady = function() return true end,
			GetInventoryInfoByItemID = function(itemID)
				local entry = perItem[itemID]
				if not entry then return nil end
				return {
					characters = entry.characters or {},
					guilds = entry.guilds or {},
					warband = { entry.warband or 0 },
				}
			end,
		},
	}
end

local function StubDataStore(perCharacter)
	_G.DataStore = {
		GetRealms = function() return { ["Realm"] = true } end,
		GetCharacters = function() return { Alt = "Default.Realm.Alt" } end,
		GetContainerItemCount = function(_, _, itemID)
			local entry = perCharacter[itemID]
			if not entry then return 0, 0, 0 end
			return entry.bags or 0, entry.bank or 0, entry.reagentBag or 0
		end,
	}
end

local function StubWarbandNexus(perItem)
	_G.WarbandNexus = {
		GetDetailedItemCountsFast = function(_, itemID)
			local entry = perItem[itemID]
			if not entry then return nil end
			return {
				warbandBank = entry.warbandBank or 0,
				guilds = entry.guilds or {},
				personalBankTotal = 0,
				characters = entry.characters or {},
			}
		end,
	}
end

local function ClearProviders()
	_G.Syndicator, _G.DataStore, _G.WarbandNexus = nil, nil, nil
end

return {
	ns = ns,
	Tooltip = Tooltip,
	ShowItem = ShowItem,
	bags = bags,
	banked = banked,
	warband = warband,
	names = names,
	requested = requested,
	chat = chat,
	StubSyndicator = StubSyndicator,
	StubDataStore = StubDataStore,
	StubWarbandNexus = StubWarbandNexus,
	ClearProviders = ClearProviders,
}
