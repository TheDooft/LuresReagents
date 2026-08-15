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

_G.C_Item = {
	GetItemNameByID = function(id) return names[id] end,
	RequestLoadItemDataByID = function(id) requested[id] = true end,
	GetItemCount = function(id, includeBank)
		return (bags[id] or 0) + (includeBank and (banked[id] or 0) or 0)
	end,
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

local function strip(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function Tooltip.new()
	return setmetatable({ lines = {}, scripts = {}, shown = 0 }, Tooltip)
end
function Tooltip:AddLine(text) table.insert(self.lines, { strip(text) }) end
function Tooltip:AddDoubleLine(left, right) table.insert(self.lines, { strip(left), strip(right) }) end
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
for _, file in ipairs({ "Locales.lua", "Data.lua", "Core.lua", "Tooltip.lua" }) do
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

return {
	ns = ns,
	Tooltip = Tooltip,
	ShowItem = ShowItem,
	bags = bags,
	banked = banked,
	names = names,
	requested = requested,
	chat = chat,
}
