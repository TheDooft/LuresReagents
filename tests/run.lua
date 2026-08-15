-- Run from the repo root: lua tests/run.lua
local H = dofile("tests/harness.lua")
local ns, Tooltip = H.ns, H.Tooltip

local LYNXFISH, WYRMFISH, VOIDFISH = 238366, 238371, 238380
local EVERSONG, GRAND = 238652, 238656
local HEARTHSTONE = 6948

local failures = 0
local function check(label, condition)
	if condition then
		print("  ok  " .. label)
	else
		failures = failures + 1
		print("FAIL  " .. label)
	end
end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

-- Names the client has cached. Eversong is deliberately absent so the enUS
-- fallback shipped in Data.lua gets exercised.
H.names[LYNXFISH] = "Poisson-lynx"
H.names[WYRMFISH] = "Serpentin arcanique"
H.names[VOIDFISH] = "Poisson du Vide nul"

print("=== a reagent capped by a different reagent ===")
H.bags[LYNXFISH], H.bags[WYRMFISH] = 37, 16
local tooltip = Tooltip.new()
H.ShowItem(tooltip, LYNXFISH)
tooltip:Render("Lynxfish")
check("names the lure", has(tooltip.lines[3][1], "Majestic Eversong Lure"))
check("asked the client to cache the uncached name", H.requested[EVERSONG] == true)
check("states the amount per craft", has(tooltip.lines[3][2], "8 per craft"))
check("caps at 2, not the 4 that Lynxfish alone allows", has(tooltip.lines[3][2], "2 craftable"))
check("names the limiting reagent", has(tooltip.lines[4][1], "Serpentin arcanique"))
check("shortfall of 4*8-16", has(tooltip.lines[4][1], "short 16"))
check("shows the stock", has(tooltip.lines[2][2], "you have 37"))

print("=== the hovered reagent is itself the bottleneck ===")
H.bags[LYNXFISH], H.bags[WYRMFISH] = 8, 80
tooltip = Tooltip.new()
H.ShowItem(tooltip, LYNXFISH)
check("1 craftable", has(tooltip.lines[3][2], "1 craftable"))
check("no shortage line", #tooltip.lines == 3)

print("=== bank inclusion ===")
H.bags[VOIDFISH], H.banked[VOIDFISH] = 3, 9
tooltip = Tooltip.new()
H.ShowItem(tooltip, VOIDFISH)
check("bank counted", has(tooltip.lines[2][2], "you have 12"))
check("3 craftable", has(tooltip.lines[3][2], "3 craftable"))
ns.db.includeBank, ns.db.includeWarband = false, false
tooltip = Tooltip.new()
H.ShowItem(tooltip, VOIDFISH)
check("bags only once disabled", has(tooltip.lines[2][2], "you have 3"))
ns.db.includeBank, ns.db.includeWarband = true, true

print("=== the lure's own tooltip ===")
H.bags[LYNXFISH], H.bags[WYRMFISH] = 37, 16
tooltip = Tooltip.new()
H.ShowItem(tooltip, EVERSONG)
tooltip:Render("Majestic Eversong Lure")
check("header states the craftable count", has(tooltip.lines[2][2], "can craft 2"))
check("lists both reagents", #tooltip.lines == 4)
check("stock against requirement", has(tooltip.lines[3][2], "16 / 8"))

print("=== re-entry guard ===")
tooltip = Tooltip.new()
H.ShowItem(tooltip, GRAND)
local count = #tooltip.lines
H.ShowItem(tooltip, GRAND)
check("a refresh does not duplicate the lines", #tooltip.lines == count)
tooltip:Clear()
H.ShowItem(tooltip, GRAND)
check("lines return after the tooltip is cleared", #tooltip.lines == count)

print("=== guards ===")
tooltip = Tooltip.new()
H.ShowItem(tooltip, HEARTHSTONE)
check("an unrelated item is left alone", #tooltip.lines == 0)
tooltip = Tooltip.new()
H.ShowItem(tooltip, "<SECRET>")
check("a secret item id is ignored", #tooltip.lines == 0)
tooltip = Tooltip.new()
ns.db.enabled = false
H.ShowItem(tooltip, LYNXFISH)
check("the master switch silences everything", #tooltip.lines == 0)
ns.db.enabled = true

print("=== item icons ===")
H.bags[LYNXFISH], H.bags[WYRMFISH] = 37, 16
tooltip = Tooltip.new()
H.ShowItem(tooltip, LYNXFISH)
check("the lure line carries a texture escape", tooltip.lines[3].raw:find("|T" .. (100000 + EVERSONG) .. ":", 1, true) ~= nil)
check("the shortage line carries one too", tooltip.lines[4].raw:find("|T" .. (100000 + WYRMFISH) .. ":", 1, true) ~= nil)
ns.db.showIcons = false
tooltip = Tooltip.new()
H.ShowItem(tooltip, LYNXFISH)
check("none when the option is off", tooltip.lines[3].raw:find("|T", 1, true) == nil)
ns.db.showIcons = true

print("=== inventory addons as a data source ===")
-- 37 in bags here, plus an alt holding 60 and 40 in the warband bank.
H.bags[LYNXFISH], H.bags[WYRMFISH] = 37, 200
H.StubSyndicator({
	[LYNXFISH] = { characters = { { bags = 37, bank = 0 }, { bags = 60, bank = 0, mail = 0 } }, warband = 40 },
})
check("auto picks it up", ns.GetActiveProvider() ~= nil and ns.GetActiveProvider().id == "syndicator")
local total, here = ns.GetOwned(LYNXFISH)
check("total is 37+60+40", total == 137)
check("local share is still 37", here == 37)
tooltip = Tooltip.new()
H.ShowItem(tooltip, LYNXFISH)
tooltip:Render("Lynxfish, with Syndicator")
check("the split is shown", has(tooltip.lines[2][2], "you have 137") and has(tooltip.lines[2][2], "37 here"))
check("craftable uses the account total", has(tooltip.lines[3][2], "17 craftable"))

H.ClearProviders()
H.StubDataStore({ [LYNXFISH] = { bags = 50, bank = 10, reagentBag = 5 } })
H.warband[LYNXFISH] = 20
check("altoholic is used when it is the only one", ns.GetActiveProvider().id == "altoholic")
check("characters plus the live warband bank", ns.GetOwned(LYNXFISH) == 85)

H.ClearProviders()
H.warband[LYNXFISH] = 0
H.StubWarbandNexus({
	[LYNXFISH] = { warbandBank = 25, characters = { { total = 37 }, { total = 13 } } },
})
check("warband nexus is used", ns.GetActiveProvider().id == "warbandnexus")
check("its totals are summed", ns.GetOwned(LYNXFISH) == 75)

print("=== data source fallbacks ===")
H.ClearProviders()
H.StubSyndicator({})           -- provider present but knows nothing about the item
check("no count means fall back to live", ns.GetOwned(LYNXFISH) == 37)
H.StubSyndicator({ [LYNXFISH] = { characters = { { bags = 2 } } } })
check("a stale lower count never wins", ns.GetOwned(LYNXFISH) == 37)
_G.Syndicator = { API = { IsReady = function() return false end, GetInventoryInfoByItemID = function() return nil end } }
check("not ready means not available", ns.GetActiveProvider() == nil)
_G.Syndicator = { API = { GetInventoryInfoByItemID = function() error("boom") end } }
check("a provider that throws is survivable", ns.GetOwned(LYNXFISH) == 37)
H.ClearProviders()

ns.db.dataSource = "character"
H.StubSyndicator({ [LYNXFISH] = { characters = { { bags = 999 } } } })
check("'character' ignores providers", ns.GetOwned(LYNXFISH) == 37)
ns.db.dataSource = "warbandnexus"
check("naming an absent provider falls back", ns.GetOwned(LYNXFISH) == 37)
ns.db.dataSource = "auto"
H.ClearProviders()

print("=== version ===")
-- Guards against the TOC losing its literal version and falling back to "?",
-- which is what stops the in-game addon list from showing one.
check("the TOC carries a literal semver, read back as " .. tostring(ns.version),
	type(ns.version) == "string" and ns.version:match("^%d+%.%d+%.%d+$") ~= nil)

print("=== slash command ===")
SlashCmdList.LURESREAGENTS("showcounts")
check("toggles case-insensitively", ns.db.showCounts == false)
SlashCmdList.LURESREAGENTS("showCounts")
check("toggles back", ns.db.showCounts == true)
SlashCmdList.LURESREAGENTS("nope")
check("reports an unknown option", has(H.chat[#H.chat], "nope"))
SlashCmdList.LURESREAGENTS("")
check("lists every option", #H.chat > 8)
SlashCmdList.LURESREAGENTS("source character")
check("sets the data source", ns.db.dataSource == "character")
SlashCmdList.LURESREAGENTS("source nonsense")
check("rejects an unknown source", ns.db.dataSource == "character" and has(H.chat[#H.chat], "nonsense"))
SlashCmdList.LURESREAGENTS("source auto")
check("sets it back to auto", ns.db.dataSource == "auto")

print("")
if failures > 0 then
	print(failures .. " check(s) FAILED")
	os.exit(1)
end
print("all checks passed")
