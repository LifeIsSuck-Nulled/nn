-- SH Helper v8.1 DEBUG
-- + debug logging in farmStep, all events, collect, unload
-- + pcall safety guards (stuck-flag auto-recovery)
-- + inAuction / collecting stuck-detection (30s / 90s)
-- + SH_Dump() global for manual console inspection
if _G.SH_HelperCleanup then pcall(_G.SH_HelperCleanup) end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Auction = Events:WaitForChild("Auction")
local Vehicles = Events:WaitForChild("Vehicles")
local Plot = Events:WaitForChild("Plot")
local bidRemote = Auction:WaitForChild("Bid")
local leaveRemote = Auction:WaitForChild("LeaveAuction")
local updateBid = Auction:WaitForChild("UpdateCurrentWinningBid")
local toggleBid = Auction:WaitForChild("ToggleBiddingUI")
local toggleAuctionArea = Auction:WaitForChild("ToggleAuctionArea")
local pickupEnd = Auction:WaitForChild("AuctionPickupEnd")
local pickupStart = Auction:WaitForChild("AuctionPickupStart")
local getNetWorth = Events.UI:WaitForChild("GetNetWorthBreakdown")
local getInventory = Events.Inventory:WaitForChild("GetPlayerInventory")
local transferToVehicle = Vehicles:WaitForChild("TransferInventoryItemToVehicle")
local requestSpawn = Vehicles:WaitForChild("RequestSpawn")
local getOwnedVehicles = Vehicles:WaitForChild("GetOwnedVehicles")
local repairWonItem = Events.WrenchShop:WaitForChild("RepairWonItem")
local placeStock = Plot:WaitForChild("PlaceStockItem")
local placeStockResult = Plot:WaitForChild("PlaceStockItemResult")
local getVehicleItems = Vehicles:WaitForChild("GetVehicleItems")
local unloadVehicle = Vehicles:WaitForChild("TransferVehicleItemsToInventory")
local offerOverweightAdd = Events.UI:WaitForChild("OfferOverweightAdd")
local getLostItems    = Events.UI:WaitForChild("GetLostItems")
local claimLostItem   = Events.UI:WaitForChild("ClaimLostItem")
local notifyRemote    = Events.UI:WaitForChild("Notify")
-- Base position
local ownBase = Vector3.new(-431.1, 1722.2, 430.0)
pcall(function()
	local d = Events.GPS.GetPOIs:InvokeServer()
	if type(d) == "table" and type(d.pois) == "table" then
		for _, poi in pairs(d.pois) do
			if type(poi) == "table" and poi.category == "Player Shop"
				and tonumber(poi.ownerUserId) == player.UserId and poi.position then
				ownBase = poi.position; break
			end
		end
	end
end)
local Items = {}
pcall(function() local r = require(ReplicatedStorage.Modules.Items); if type(r) == "table" then Items = r end end)
local MutatorModule, Grading
pcall(function() MutatorModule = require(ReplicatedStorage.Modules.MutatorModule) end)
pcall(function() Grading = require(ReplicatedStorage.Modules.GameConfig).Grading end)
local connections = {}
local alive = true
local refreshUi
local state = {
	master = true, farm = false, autoWin = true, autoBidSpeed = 0.5,
	selected = {}, garages = {}, index = 0,
	target = nil, targetStarted = 0, targetTimeout = 20, lastScan = 0,
	currentAuctionGarage = nil, inAuction = false,
	inAuctionSince = 0,   -- DEBUG: timestamp when inAuction last became true
	won = false, wonGarage = nil, collecting = false,
	collectingSince = 0,  -- DEBUG: timestamp when collecting started
	beforeInventory = {}, lastBid = 0, currentBid = 0, startingBid = 0,
	status = "Ready", teleportMethod = "Instant",
	autoLeaveMinBid = false, autoLeaveMinBidAmt = 5000,
	autoLeaveValueMin = false, autoLeaveValueAmt = 5000,
	autoLeaveMaxBid = false, autoLeaveMaxBidAmt = 999999,
	-- unload tab
	autoUnload = false, autoShelf = false, unloadPct = 90, unloading = false, shelving = false,
	-- overweight signal
	overweightSignal = false,
	vehicleFarSignal = false,
	shelfSlotAvailable = false,
	-- lost & found
	autoLostFound = false, lostFoundRunning = false,
	-- inventory cap
	invCap = 10,
}
local config = {
	minBid = 0, minItemValue = 100, hitTolerance = 0.0075,
	whitelist = {
		["376"]=true, ["562"]=true, ["635"]=true, ["735"]=true, ["764"]=true,
		["1"]=true,["5"]=true,["17"]=true,["44"]=true,["50"]=true,
		["67"]=true,["81"]=true,["101"]=true,["348"]=true,["362"]=true,
		["363"]=true,["365"]=true,["366"]=true,["367"]=true,["368"]=true,
		["371"]=true,["372"]=true,["373"]=true,["410"]=true,["478"]=true,
		["479"]=true,["480"]=true,["482"]=true,["483"]=true,["484"]=true,
		["485"]=true,["486"]=true,["487"]=true,["488"]=true,["489"]=true,
		["490"]=true,["491"]=true,["492"]=true,["493"]=true,["495"]=true,
		["496"]=true,["497"]=true,["498"]=true,["499"]=true,["500"]=true,
		["501"]=true,["543"]=true,["544"]=true,["547"]=true,["556"]=true,
		["557"]=true,["558"]=true,["570"]=true,["576"]=true,["613"]=true,
		["614"]=true,["615"]=true,["616"]=true,["617"]=true,["619"]=true,
		["620"]=true,["621"]=true,["622"]=true,["626"]=true,["627"]=true,
		["628"]=true,["674"]=true,["675"]=true,["676"]=true,["715"]=true,
		["716"]=true,["720"]=true,["721"]=true,["730"]=true,["731"]=true,
		["732"]=true,["745"]=true,["746"]=true,["747"]=true,["757"]=true,
		["790"]=true,["791"]=true,["800"]=true,["808"]=true,["812"]=true,
		["813"]=true,["815"]=true,["821"]=true,["829"]=true,["830"]=true,
		["831"]=true,["832"]=true,["841"]=true,["842"]=true,["843"]=true,
		["502"]=true,["503"]=true,["509"]=true,["510"]=true,["518"]=true,
		["519"]=true,["521"]=true,["522"]=true,["524"]=true,["736"]=true,
		["737"]=true,["738"]=true,["739"]=true,["751"]=true,["826"]=true,
		["504"]=true,["505"]=true,["506"]=true,["507"]=true,["511"]=true,
		["512"]=true,["520"]=true,["523"]=true,["525"]=true,["526"]=true,
		["740"]=true,["741"]=true,["742"]=true,["744"]=true,["752"]=true,
		["822"]=true,["825"]=true,
		["577"]=true,["578"]=true,["579"]=true,["580"]=true,["581"]=true,
		["582"]=true,["583"]=true,["743"]=true,["753"]=true,["823"]=true,
		["824"]=true,
	},
	shelfBlacklist = {
		["357"]=true,["358"]=true,["359"]=true,["360"]=true,["361"]=true,
		["376"]=true,["562"]=true,["635"]=true,["735"]=true,["764"]=true,
		["1"]=true,["5"]=true,["17"]=true,["44"]=true,["50"]=true,
		["67"]=true,["81"]=true,["101"]=true,["348"]=true,["362"]=true,
		["363"]=true,["365"]=true,["366"]=true,["367"]=true,["368"]=true,
		["371"]=true,["372"]=true,["373"]=true,["410"]=true,["478"]=true,
		["479"]=true,["480"]=true,["482"]=true,["483"]=true,["484"]=true,
		["485"]=true,["486"]=true,["487"]=true,["488"]=true,["489"]=true,
		["490"]=true,["491"]=true,["492"]=true,["493"]=true,["495"]=true,
		["496"]=true,["497"]=true,["498"]=true,["499"]=true,["500"]=true,
		["501"]=true,["543"]=true,["544"]=true,["547"]=true,["556"]=true,
		["557"]=true,["558"]=true,["570"]=true,["576"]=true,["613"]=true,
		["614"]=true,["615"]=true,["616"]=true,["617"]=true,["619"]=true,
		["620"]=true,["621"]=true,["622"]=true,["626"]=true,["627"]=true,
		["628"]=true,["674"]=true,["675"]=true,["676"]=true,["715"]=true,
		["716"]=true,["720"]=true,["721"]=true,["730"]=true,["731"]=true,
		["732"]=true,["745"]=true,["746"]=true,["747"]=true,["757"]=true,
		["790"]=true,["791"]=true,["800"]=true,["808"]=true,["812"]=true,
		["813"]=true,["815"]=true,["821"]=true,["829"]=true,["830"]=true,
		["831"]=true,["832"]=true,["841"]=true,["842"]=true,["843"]=true,
		["502"]=true,["503"]=true,["509"]=true,["510"]=true,["518"]=true,
		["519"]=true,["521"]=true,["522"]=true,["524"]=true,["736"]=true,
		["737"]=true,["738"]=true,["739"]=true,["751"]=true,["826"]=true,
		["504"]=true,["505"]=true,["506"]=true,["507"]=true,["511"]=true,
		["512"]=true,["520"]=true,["523"]=true,["525"]=true,["526"]=true,
		["740"]=true,["741"]=true,["742"]=true,["744"]=true,["752"]=true,
		["822"]=true,["825"]=true,
		["577"]=true,["578"]=true,["579"]=true,["580"]=true,["581"]=true,
		["582"]=true,["583"]=true,["743"]=true,["753"]=true,["823"]=true,
		["824"]=true,
	}
}
-- Trophy mutation blacklist: set mutName→true to block that mutation from shelving.
-- When empty, all trophies are blocked (default). When non-empty, only blocked mutations skip shelving.
local trophyMutBlacklist = {}
local trophyMutations = {
	"Black","Rainbow","Secret","Void","Hologram",
	"Chrome","Gem","Diamond","Corrupted","Gold",
	"Silver","Huge","Tiny",
}
local areaOptions = { "JunkYard", "BackAlley", "Farmyard", "Shipyard", "LuckyBeach", "PowerPlant" }
state.selected["JunkYard"] = true
local areaGameNames = {
	JunkYard    = "Junk Yard",
	BackAlley   = "Back Alley",
	Farmyard    = "Farmyard",
	Shipyard    = "Shipyard",
	LuckyBeach  = "Lucky Beach",
	PowerPlant  = "Power Plant",
}

-- ══════════════════════════════════════════════════════════════
-- DEBUG HELPERS
-- ══════════════════════════════════════════════════════════════
local dbg  = function(msg) print("[SH] "  .. tostring(msg)) end
local wdbg = function(msg) warn("[SH] "  .. tostring(msg)) end

-- farmStep block-reason logger: throttled to avoid spam (same reason = max 1 print per 5s)
local _farmMsg = ""; local _farmTime = 0
local function farmDbg(reason)
	local now = os.clock()
	if reason ~= _farmMsg or now - _farmTime >= 5 then
		_farmMsg = reason; _farmTime = now
		dbg("farmStep blocked → " .. reason)
	end
end

-- ══════════════════════════════════════════════════════════════
-- CORE HELPERS
-- ══════════════════════════════════════════════════════════════
local function connect(s, cb) local c = s:Connect(cb); table.insert(connections, c); return c end
local function cleanup()
	alive = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	local ui = playerGui:FindFirstChild("SH_ControlUI"); if ui then ui:Destroy() end
	getgenv().SH_SetFarm = nil; getgenv().SH_State = nil; getgenv().SH_Dump = nil
	_G.SH_HelperCleanup = nil
end
_G.SH_HelperCleanup = cleanup
local function setStatus(t) state.status = t; if refreshUi then refreshUi() end end
local function rootPart() local c = player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function normalizeArea(v) return tostring(v or ""):gsub("%s+", ""):gsub(" ", "") end
local function triggerPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	local oldHold = prompt.HoldDuration
	pcall(function() prompt.HoldDuration = 0 end)
	if fireproximityprompt then pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			local key = prompt.KeyboardKeyCode or Enum.KeyCode.E
			prompt:InputBegan(Enum.UserInputType.Keyboard, key)
			task.wait(0.05)
			prompt:InputEnded(Enum.UserInputType.Keyboard, key)
		end)
		task.wait(0.08)
	end
	pcall(function() prompt.HoldDuration = oldHold end)
end
local function teleportPlayer(targetCF)
	local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if state.teleportMethod == "Tween" then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local old = hum and hum.PlatformStand
		if hum then hum.PlatformStand = true end
		local sp = hrp.Position; local tp = targetCF.Position
		local steps = math.max(15, math.floor((tp - sp).Magnitude / 8))
		local rot = hrp.CFrame.Rotation
		for i = 1, steps do
			if not char.Parent or not hrp.Parent or not alive then break end
			hrp.CFrame = CFrame.new(sp:Lerp(tp, i/steps)) * rot
			hrp.AssemblyLinearVelocity = Vector3.zero; task.wait(0.03)
		end
		hrp.CFrame = targetCF
		if hum then hum.PlatformStand = old or false end
	else
		hrp.CFrame = targetCF; hrp.AssemblyLinearVelocity = Vector3.zero
	end
end
local exitVehicle = function()
	local c = player.Character; local h = c and c:FindFirstChildOfClass("Humanoid")
	local s = h and h.SeatPart
	if s then pcall(function() s:Sit(nil) end); h.Sit = false; task.wait(0.15) end
end
local function vehicleNear(pos)
	for _, i in ipairs(workspace:GetDescendants()) do
		if i:IsA("VehicleSeat") and (i.Position - pos).Magnitude <= 80 then return true end
	end; return false
end
local function scanGarages()
	local ok, bd = pcall(function() return getNetWorth:InvokeServer() end)
	local nw = ok and type(bd) == "table" and tonumber(bd.Total) or 0
	local r = {}
	local gf = workspace._Debris:FindFirstChild("Garages")
	if not gf then state.garages = r; state.lastScan = os.clock()
		dbg("scanGarages: Garages folder not found"); return 0
	end
	for _, g in ipairs(gf:GetChildren()) do
		local z = g:FindFirstChild("AuctionZone", true)
		if z and z:IsA("BasePart") then
			local l = g:FindFirstChild("MinNetWorth", true)
			local t = l and l:IsA("TextLabel") and l.Text or ""
			local raw = string.match(t, "%$([%d,]+)")
			local req = raw and tonumber((raw:gsub("[^%d]", ""))) or 0
			if req <= nw then
				table.insert(r, { instance = g, name = g.Name, area = normalizeArea(g:GetAttribute("AreaName")), zone = z })
			end
		end
	end
	state.garages = r; state.lastScan = os.clock()
	dbg(string.format("scanGarages: %d eligible garages (netWorth=$%d)", #r, nw))
	return #r
end
local function selectedGarage(idx)
	local n = #state.garages; if n == 0 then return nil, nil end
	for step = 1, n do
		local ni = ((idx + step - 1) % n) + 1; local g = state.garages[ni]
		if state.selected[g.area] then
			local p = g.instance:FindFirstChild("EnterAuction", true)
			if p and p:IsA("ProximityPrompt") and p.Enabled then return ni, g end
		end
	end
	for step = 1, n do
		local ni = ((idx + step - 1) % n) + 1; local g = state.garages[ni]
		if state.selected[g.area] then return ni, g end
	end
	return nil, nil
end
local function findBidBar()
	for _, i in ipairs(playerGui:GetDescendants()) do
		if i.Name == "AuctionBiddingContainer" and i:IsA("Frame") and i.Visible then
			local tr = i:FindFirstChild("Track", true)
			if tr and tr.Visible then
				local cur = tr:FindFirstChild("Cursor"); local zone = tr:FindFirstChild("BidZone")
				if cur and zone then return cur.Position.X.Scale, zone.Position.X.Scale, zone.Size.X.Scale end
			end
		end
	end
	return nil
end
local lastLeaveTime = 0
local function leaveAuction()
	dbg("leaveAuction called")
	pcall(function() leaveRemote:InvokeServer() end)
	state.inAuction = false; state.won = false; state.lastBid = 0
	state.target = nil; state.lastScan = 0
	lastLeaveTime = os.clock()
end
local function tryBid()
	local cur, zone, w = findBidBar(); if not cur then return false end
	if not state.inAuction then
		state.inAuction = true
		state.inAuctionSince = os.clock()
		dbg("tryBid: bid bar found → inAuction=true")
	end
	local checkBid = state.currentBid > 0 and state.currentBid or state.startingBid
	if state.autoLeaveMinBid and checkBid > 0 and checkBid < state.autoLeaveMinBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." < $"..state.autoLeaveMinBidAmt); return true end
	if state.autoLeaveValueMin and state.startingBid > 0 and state.startingBid < state.autoLeaveValueAmt then leaveAuction(); setStatus("Left: value $"..state.startingBid.." < $"..state.autoLeaveValueAmt); return true end
	if state.autoLeaveMaxBid and checkBid > 0 and checkBid > state.autoLeaveMaxBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." > $"..state.autoLeaveMaxBidAmt); return true end
	if config.minBid > 0 and checkBid > 0 and checkBid < config.minBid then leaveAuction(); setStatus("Below min bid"); return true end
	if state.autoWin and zone <= cur + config.hitTolerance and cur - config.hitTolerance <= zone + w then
		if os.clock() - state.lastBid > state.autoBidSpeed then
			state.lastBid = os.clock(); pcall(function() bidRemote:FireServer() end); setStatus("Bid sent")
		end
	end
	return true
end
local function startPromptLoop(g)
	task.spawn(function()
		for _ = 1, 15 do
			if not alive or not state.farm or state.won or findBidBar() then return end
			local p = g.instance:FindFirstChild("EnterAuction", true)
			if p and p:IsA("ProximityPrompt") and p.Enabled then
				triggerPrompt(p)
				task.wait(1.5)
			else
				task.wait(0.3)
			end
		end
		if alive and state.farm and not state.won and not findBidBar() then
			dbg("startPromptLoop: all 15 attempts exhausted → clearing target")
			setStatus("Missed auction — moving to next garage")
			state.target = nil
		end
	end)
end
local function chooseNextGarage()
	local idx, g = selectedGarage(state.index)
	if not g then
		dbg("chooseNextGarage: no eligible garage found → rescanning")
		setStatus("No garages -- rescanning"); scanGarages(); return
	end
	state.index = idx; state.target = g; state.targetStarted = os.clock()
	dbg("chooseNextGarage: → " .. g.area .. " / " .. g.name)
	teleportPlayer(g.zone.CFrame * CFrame.new(0, 2, -4))
	setStatus("Going: "..g.area.." / "..g.name)
	startPromptLoop(g)
end

-- ── FARM STEP ────────────────────────────────────────────────
local function farmStep()
	if not alive or not state.master or not state.farm then
		farmDbg(string.format("master=%s farm=%s alive=%s", tostring(state.master), tostring(state.farm), tostring(alive)))
		return
	end
	if #state.garages == 0 or os.clock() - state.lastScan >= 10 then scanGarages() end
	if tryBid() then return end
	if state.won then
		farmDbg("won=true (waiting for collectWonItems)")
		return
	end
	if state.collecting then
		farmDbg(string.format("collecting=true (%.0fs elapsed)", os.clock() - state.collectingSince))
		return
	end
	if state.inAuction then
		farmDbg(string.format("inAuction=true (%.0fs elapsed)", os.clock() - state.inAuctionSince))
		return
	end
	if os.clock() - lastLeaveTime < 2.5 then
		farmDbg(string.format("leaveAuction cooldown (%.1fs remaining)", 2.5 - (os.clock() - lastLeaveTime)))
		return
	end
	if state.target and os.clock() - state.targetStarted < state.targetTimeout then
		farmDbg(string.format("waiting at target '%s' (%.0fs / %.0fs)", state.target.name, os.clock()-state.targetStarted, state.targetTimeout))
		return
	end
	state.target = nil; chooseNextGarage()
end

-- ── ITEM VALUE ───────────────────────────────────────────────
local function getRealValue(entry)
	if not entry then return 0 end
	local d = Items[tostring(entry.ItemId or "")] or Items[tonumber(entry.ItemId or 0)]
	if not d then return 0 end
	local p = d.BasePrice or 0
	pcall(function()
		p = MutatorModule:CalculatePriceForEntry(p, entry)
		local m = Grading.GradeCashMultForEntry(entry)
		if m and m ~= 1 then p = math.floor(p * m * 100 + 0.5) / 100 end
	end)
	return p
end
local function moveAllWonToVehicle()
	local ok, inv = pcall(function() return getInventory:InvokeServer() end)
	if not ok or type(inv) ~= "table" then return 0, 0 end
	local moved, repaired = 0, 0
	for guid, item in pairs(inv) do
		if not state.beforeInventory[guid] then
			if tonumber(item.Condition) and tonumber(item.Condition) < 100 then
				pcall(function() repairWonItem:InvokeServer(guid) end); repaired = repaired + 1
			end
			pcall(function() transferToVehicle:InvokeServer(guid) end); moved = moved + 1
		end
	end
	return moved, repaired
end

-- ── COLLECT WON ITEMS ─────────────────────────────────────────
local collectWonItems
local isOverweight
local doUnloadAndStock
local function finalizeWin()
	state.won = true
	state.wonGarage = state.currentAuctionGarage or (state.target and state.target.instance)
	state.beforeInventory = {}
	pcall(function()
		local inv = getInventory:InvokeServer()
		if type(inv) == "table" then for guid in pairs(inv) do state.beforeInventory[guid] = true end end
	end)
	local equippedGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
	if equippedGUID ~= "" then
		pcall(function() requestSpawn:FireServer(equippedGUID) end)
		task.wait(2); exitVehicle(); task.wait(0.2)
	end
	collectWonItems()
end
collectWonItems = function()
	if state.collecting then return end
	state.collecting = true
	state.collectingSince = os.clock()
	dbg("collectWonItems: started")
	task.spawn(function()
		-- pcall wraps the ENTIRE body so any crash still runs cleanup
		local ok, err = pcall(function()
			local garage = state.wonGarage
			if not garage then
				wdbg("collectWonItems: no wonGarage — aborting")
				state.won = false; state.wonGarage = nil; state.collecting = false; return
			end
			state.overweightSignal = false
			state.vehicleFarSignal = false
			state.beforeInventory = {}
			pcall(function()
				local inv = getInventory:InvokeServer()
				if type(inv) == "table" then for g in pairs(inv) do state.beforeInventory[g] = true end end
			end)
			local deadline = os.clock() + 35
			local collected, opened = 0, 0
			-- PASS 1: open crates
			setStatus("Opening crates...")
			local crateDeadline = os.clock() + 12
			while alive and os.clock() < crateDeadline and state.won do
				local crates = {}
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
						local cp = model:FindFirstChild("OpenBoxPrompt", true)
						if cp and cp:IsA("ProximityPrompt") and cp.Enabled then
							local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
							table.insert(crates, { prompt = cp, part = part })
						end
					end
				end
				if #crates == 0 then break end
				for _, cr in ipairs(crates) do
					if not alive or not state.won then break end
					local root = rootPart()
					if root and cr.part then
						exitVehicle(); root.CFrame = cr.part.CFrame + Vector3.new(0,2,0); task.wait(0.15)
					end
					triggerPrompt(cr.prompt); opened = opened + 1; task.wait(0.6)
				end
				task.wait(0.5)
			end
			dbg(string.format("collectWonItems: opened %d crates", opened))
			-- PASS 2: pick up items
			while alive and state.farm and os.clock() < deadline and state.won do
				local candidates = {}
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
						local pp = model:FindFirstChild("PickupPrompt", true)
						if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
							local entry = nil
							pcall(function()
								if MutatorModule and MutatorModule.BuildEntryFromAttributes then
									entry = MutatorModule:BuildEntryFromAttributes(model)
								end
							end)
							if not entry then entry = { ItemId = model:GetAttribute("ItemId"), Mutators = {}, Condition = 100 } end
							local idStr = tostring(entry.ItemId or "")
							local d2 = Items[idStr] or Items[tonumber(idStr)]
							local value = getRealValue(entry)
							local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
							table.insert(candidates, { prompt = pp, part = part, entry = entry, value = value, idStr = idStr, itemName = d2 and d2.Name or "" })
						end
					end
				end
				if #candidates == 0 then break end
				table.sort(candidates, function(a, b) return a.value > b.value end)
				local acted = false
				for _, c in ipairs(candidates) do
					if not alive or not state.won then break end
					if state.overweightSignal then break end
					local whitelisted = config.whitelist[c.idStr] or config.whitelist[c.itemName]
					if config.minItemValue > 0 and c.value < config.minItemValue and not whitelisted then
						-- skip
					else
						local root = rootPart()
						if root and c.part then
							exitVehicle(); root.CFrame = c.part.CFrame + Vector3.new(0,2,0); task.wait(0.1)
						end
						triggerPrompt(c.prompt); acted = true; task.wait(0.4)
						if state.vehicleFarSignal then
							state.vehicleFarSignal = false
							dbg("collectWonItems: vehicle too far — respawning")
							setStatus("Vehicle too far! Respawning...")
							local eGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
							if eGUID ~= "" then
								pcall(function() requestSpawn:FireServer(eGUID) end)
								task.wait(2); exitVehicle(); task.wait(0.2)
							end
							break
						end
						collected = collected + 1
						if state.overweightSignal then break end
					end
				end
				if state.overweightSignal then break end
				if not acted then break end
			end
			-- overweight bail-out
			if state.overweightSignal then
				local moved, repaired = moveAllWonToVehicle()
				dbg(string.format("collectWonItems: overweight bail → collected=%d moved=%d repaired=%d", collected, moved, repaired))
				setStatus(string.format("Overweight! Picked %d | moved %d — unloading...", collected, moved))
				state.won = false; state.wonGarage = nil; state.collecting = false
				state.overweightSignal = false
				if not state.unloading then task.spawn(doUnloadAndStock) end
				return
			end
			-- double check
			task.wait(0.5)
			local remaining = 0
			for _, model in ipairs(workspace:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
					local pp = model:FindFirstChild("PickupPrompt", true)
					if pp and pp:IsA("ProximityPrompt") and pp.Enabled then remaining = remaining + 1 end
				end
			end
			if remaining > 0 then
				dbg("collectWonItems: double-check found " .. remaining .. " remaining items")
				setStatus("Double check: "..remaining.." items remaining, picking up...")
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
						local pp = model:FindFirstChild("PickupPrompt", true)
						if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
							local entry = { ItemId = model:GetAttribute("ItemId"), Mutators = {}, Condition = 100 }
							local idStr = tostring(entry.ItemId or "")
							local d2 = Items[idStr] or Items[tonumber(idStr)]
							local whitelisted = config.whitelist[idStr] or (d2 and config.whitelist[d2.Name])
							local value = getRealValue(entry)
							if not (config.minItemValue > 0 and value < config.minItemValue and not whitelisted) then
								local root = rootPart()
								local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
								if root and part then exitVehicle(); root.CFrame = part.CFrame + Vector3.new(0,2,0); task.wait(0.1) end
								triggerPrompt(pp); collected = collected + 1; task.wait(0.4)
							end
						end
					end
				end
			end
			local moved, repaired = moveAllWonToVehicle()
			dbg(string.format("collectWonItems: done — collected=%d crates=%d moved=%d repaired=%d", collected, opened, moved, repaired))
			setStatus(string.format("Collected %d items, %d crates | moved %d (%d repaired)", collected, opened, moved, repaired))
			state.won = false; state.wonGarage = nil; state.collecting = false
			state.inAuction = false
			state.target = nil
			state.lastScan = 0
			if state.autoUnload and isOverweight() and not state.unloading then
				task.spawn(doUnloadAndStock)
			end
		end)
		-- SAFETY: if pcall caught an error, guarantee all flags are cleared
		if not ok then
			wdbg("collectWonItems CRASHED: " .. tostring(err))
			state.won = false; state.wonGarage = nil; state.collecting = false
			state.inAuction = false; state.target = nil; state.lastScan = 0
		end
	end)
end

-- ── VEHICLE WEIGHT ───────────────────────────────────────────
local function getVehicleModel()
	local guid = tostring(player:GetAttribute("EquippedVehicle") or "")
	if guid == "" then return nil end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and tostring(obj:GetAttribute("VehicleGUID")) == guid then return obj end
	end
end
local function getVehicleWeight()
	local vm = getVehicleModel()
	if not vm then return 0, 0 end
	return tonumber(vm:GetAttribute("CargoWeight")) or 0, tonumber(vm:GetAttribute("CargoWeightLimit")) or 0
end
local function getMaxInventory()
	local cap = tonumber(player:GetAttribute("InventoryCapacity"))
		or tonumber(player:GetAttribute("MaxInventory"))
		or tonumber(player:GetAttribute("InventorySize"))
		or tonumber(player:GetAttribute("MaxInventorySlots"))
	if cap and cap > 0 then return cap end
	return state.invCap or 10
end
isOverweight = function()
	local cw, lim = getVehicleWeight()
	return lim > 0 and (cw/lim*100) >= state.unloadPct
end

-- ── SHELF STOCKING ───────────────────────────────────────────
-- Returns true if this trophy's mutation is in the blacklist (should be skipped).
local function trophyIsBlocked(entry)
	if not next(trophyMutBlacklist) then return false end
	local blocked = false
	pcall(function()
		if type(entry.Mutators) == "table" then
			for _, mut in ipairs(entry.Mutators) do
				local name = type(mut) == "string" and mut
					or (type(mut) == "table" and (mut.name or mut.Name))
				if name and trophyMutBlacklist[name] then
					blocked = true
				end
			end
		end
	end)
	return blocked
end
local function stockShelves()
	local myPlot
	local plots = workspace:FindFirstChild("_Plots")
	if plots then
		for _, p in ipairs(plots:GetChildren()) do
			if p:GetAttribute("OwnerUserId") == player.UserId then myPlot = p; break end
		end
	end
	if not myPlot then setStatus("Shelf: plot not found"); return 0 end
	local stockF = myPlot:FindFirstChild("Stock")
	local furnit = myPlot:FindFirstChild("Furniture")
	if not furnit then return 0 end
	local slots = {}
	for _, shelf in ipairs(furnit:GetChildren()) do
		if shelf:GetAttribute("IsShelf") == true then
			local sg = shelf:GetAttribute("GUID")
			local occ = {}
			if stockF then
				for _, s in ipairs(stockF:GetChildren()) do
					if s:GetAttribute("ShelfGUID") == sg then
						local sn = s:GetAttribute("SnapPointName"); if sn then occ[sn] = true end
					end
				end
			end
			for _, obj in ipairs(shelf:GetDescendants()) do
				if obj:IsA("Attachment") and obj.Name:match("^SnapPoint") and not occ[obj.Name] then
					table.insert(slots, { sg = sg, sn = obj.Name, att = obj })
				end
			end
		end
	end
	if #slots == 0 then return 0 end
	local ok, inv = pcall(function() return getInventory:InvokeServer() end)
	if not ok or type(inv) ~= "table" then return 0 end
	local stocked, si = 0, 1
	for guid, entry in pairs(inv) do
		if not alive or si > #slots then break end
		local id = tostring(entry.ItemId or "")
		if config.shelfBlacklist[id] then
			-- Trophy (376): honour per-mutation blacklist if configured
			if id == "376" and next(trophyMutBlacklist) then
				if trophyIsBlocked(entry) then continue end
				-- mutation not blacklisted → fall through and allow shelving
			else
				continue
			end
		end
		local d = Items[id] or Items[tonumber(id)]
		if not d then continue end
		local slot = slots[si]
		local price = d.BasePrice or 0
		pcall(function()
			price = MutatorModule:CalculatePriceForEntry(price, entry)
			local m = Grading.GradeCashMultForEntry(entry)
			if m and m ~= 1 then price = math.floor(price*m*100+0.5)/100 end
		end)
		local rotY = d.ShelfRotationY or 0
		local pcf = slot.att.WorldCFrame * CFrame.Angles(0, math.rad(rotY), 0)
		local rg = HttpService:GenerateGUID(false)
		local done, succ = false, false
		local conn = placeStockResult.OnClientEvent:Connect(function(g2, ok2)
			if g2 == rg then done = true; succ = ok2 end
		end)
		pcall(function() placeStock:FireServer(guid, id, pcf, price, slot.sg, slot.sn, nil, nil, true, rg) end)
		local t = 0
		while not done and t < 3 do task.wait(0.1); t = t + 0.1 end
		pcall(function() conn:Disconnect() end)
		if succ then stocked = stocked + 1 end
		si = si + 1; task.wait(0.25)
	end
	return stocked
end

-- ── UNLOAD SEQUENCE ──────────────────────────────────────────
doUnloadAndStock = function()
	if state.unloading then
		dbg("doUnloadAndStock: already unloading — skipped")
		return
	end
	state.unloading = true
	local wasFarming = state.farm
	state.farm = false
	if refreshUi then refreshUi() end
	dbg("doUnloadAndStock: started (wasFarming=" .. tostring(wasFarming) .. ")")
	-- pcall wraps the entire body so a crash still restores flags
	local ok, err = pcall(function()
		setStatus("Going to base to unload...")
		teleportPlayer(CFrame.new(ownBase + Vector3.new(0,3,0)))
		task.wait(1.2)
		local equippedGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
		if equippedGUID ~= "" then
			pcall(function() requestSpawn:FireServer(equippedGUID) end)
			task.wait(2)
		end
		local totalUnloaded = 0
		for _ = 1, 20 do
			local ok2, vitems = pcall(function() return getVehicleItems:InvokeServer(equippedGUID) end)
			if not ok2 or type(vitems) ~= "table" or not next(vitems) then
				dbg("doUnloadAndStock: vehicle empty or error — stopping unload loop")
				break
			end
			local ok3, inv = pcall(function() return getInventory:InvokeServer() end)
			local invCount = 0
			if ok3 and type(inv) == "table" then for _ in pairs(inv) do invCount = invCount + 1 end end
			local freeSlots = getMaxInventory() - invCount
			if freeSlots <= 0 then
				if state.autoShelf then
					dbg("doUnloadAndStock: inv full — stocking shelves first")
					setStatus("Inventory full, stocking shelves first...")
					stockShelves(); task.wait(0.5)
				else
					dbg("doUnloadAndStock: inv full and autoShelf=false — stopping")
					break
				end
			else
				local guids = {}
				for g in pairs(vitems) do table.insert(guids, g); if #guids >= freeSlots then break end end
				pcall(function() unloadVehicle:FireServer(guids) end)
				totalUnloaded = totalUnloaded + #guids
				dbg(string.format("doUnloadAndStock: batch unloaded %d items (total=%d)", #guids, totalUnloaded))
				task.wait(1.5)
				local remaining = 0
				for _ in pairs(vitems) do remaining = remaining + 1 end
				if #guids >= remaining then break end
			end
		end
		setStatus("Unloaded "..totalUnloaded.." items")
		if state.autoShelf and alive then
			setStatus("Stocking shelves...")
			local stocked = stockShelves()
			setStatus("Unloaded "..totalUnloaded.." | Stocked "..stocked)
			dbg(string.format("doUnloadAndStock: stocked %d items", stocked))
		end
	end)
	-- SAFETY: always restore flags regardless of success/error
	if not ok then
		wdbg("doUnloadAndStock CRASHED: " .. tostring(err))
	end
	state.unloading = false
	if wasFarming then
		state.farm = true
		scanGarages(); state.target = nil; state.index = 0
		if refreshUi then refreshUi() end
		setStatus("Farm resumed after unload")
		dbg("doUnloadAndStock: farm restored")
	end
end

-- ── LOST AND FOUND ───────────────────────────────────────────
local function doLostAndFound()
	if state.lostFoundRunning then return end
	state.lostFoundRunning = true
	local areaKey = nil
	for _, key in ipairs(areaOptions) do
		if state.selected[key] then areaKey = key; break end
	end
	if not areaKey then state.lostFoundRunning = false; return end
	local gameName = areaGameNames[areaKey]
	if not gameName then state.lostFoundRunning = false; return end
	local ok, result = pcall(function() return getLostItems:InvokeServer(gameName) end)
	if not ok or type(result) ~= "table" or type(result.items) ~= "table" then
		dbg("doLostAndFound: no items or error for " .. gameName)
		state.lostFoundRunning = false; return
	end
	local qualifying = {}
	for guid, entry in pairs(result.items) do
		local idStr = tostring(entry.ItemId or "")
		local d = Items[idStr] or Items[tonumber(idStr)]
		local itemName = d and d.Name or ""
		local value = getRealValue(entry)
		local whitelisted = config.whitelist[idStr] or config.whitelist[itemName]
		if not (config.minItemValue > 0 and value < config.minItemValue and not whitelisted) then
			table.insert(qualifying, { guid = guid, entry = entry, value = value })
		end
	end
	if #qualifying == 0 then state.lostFoundRunning = false; return end
	table.sort(qualifying, function(a, b) return a.value > b.value end)
	dbg(string.format("doLostAndFound: %d qualifying items in %s", #qualifying, gameName))
	local waited = 0
	while (state.won or state.collecting or state.inAuction) and waited < 60 and alive do
		task.wait(1); waited = waited + 1
	end
	if not alive then state.lostFoundRunning = false; return end
	local areasFolder = workspace:FindFirstChild("Areas")
	local areaFolder  = areasFolder and areasFolder:FindFirstChild(gameName)
	local lnfBox      = areaFolder and areaFolder:FindFirstChild("Lost and Found Box")
	local lnfPart     = lnfBox and (
		(lnfBox:IsA("BasePart") and lnfBox) or
		lnfBox.PrimaryPart or
		lnfBox:FindFirstChildWhichIsA("BasePart", true)
	)
	if not lnfPart then
		setStatus("L&F: Lost and Found Box not found for "..gameName)
		state.lostFoundRunning = false; return
	end
	local wasFarming = state.farm
	state.farm = false
	if refreshUi then refreshUi() end
	setStatus("L&F: going to "..gameName.." Lost and Found Box...")
	teleportPlayer(CFrame.new(lnfPart.Position + Vector3.new(0, 3, 0)))
	task.wait(0.6)
	local equippedGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
	if equippedGUID ~= "" then
		pcall(function() requestSpawn:FireServer(equippedGUID) end)
		task.wait(2); exitVehicle(); task.wait(0.2)
	end
	local beforeLnfInv = {}
	pcall(function()
		local inv = getInventory:InvokeServer()
		if type(inv) == "table" then for g in pairs(inv) do beforeLnfInv[g] = true end end
	end)
	local claimed = 0
	for _, item in ipairs(qualifying) do
		if not alive then break end
		local ok2, res = pcall(function()
			return claimLostItem:InvokeServer(gameName, item.guid)
		end)
		if ok2 and type(res) == "table" and res.success then
			claimed = claimed + 1
			setStatus(string.format("L&F: claimed $%d (ID %s) [%d/%d]",
				item.value, tostring(item.entry.ItemId), claimed, #qualifying))
		end
		task.wait(0.5)
	end
	if claimed > 0 then
		task.wait(0.5)
		local ok3, inv = pcall(function() return getInventory:InvokeServer() end)
		if ok3 and type(inv) == "table" then
			for guid, item in pairs(inv) do
				if not beforeLnfInv[guid] then
					if tonumber(item.Condition) and tonumber(item.Condition) < 100 then
						pcall(function() repairWonItem:InvokeServer(guid) end)
					end
					pcall(function() transferToVehicle:InvokeServer(guid) end)
				end
			end
		end
	end
	dbg(string.format("doLostAndFound: done — %d/%d claimed", claimed, #qualifying))
	setStatus(string.format("L&F: done — %d/%d items claimed", claimed, #qualifying))
	state.lostFoundRunning = false
	if wasFarming then
		state.farm = true
		scanGarages(); state.target = nil; state.index = 0
		if refreshUi then refreshUi() end
		setStatus("Farm resumed after L&F")
	end
end

-- ── AUTO CHECKS (weight / shelf / lost+found / stuck detection) ───────────────
local lastWeightCheck = 0
local lastShelfCheck = 0
local lastLostFoundCheck = 0
local lastStateDump = 0

local function autoChecks()
	local now = os.clock()

	-- ── PERIODIC STATE DUMP (every 10s when farm is running) ──
	if state.farm and now - lastStateDump >= 10 then
		lastStateDump = now
		local cw, lim = getVehicleWeight()
		warn(string.format(
			"[SH-STATE] farm=%s won=%s collecting=%s(%.0fs) inAuction=%s(%.0fs) unloading=%s shelving=%s | garages=%d target=%s | vehicle=%.0f/%.0fkg",
			tostring(state.farm), tostring(state.won),
			tostring(state.collecting), now - state.collectingSince,
			tostring(state.inAuction), now - state.inAuctionSince,
			tostring(state.unloading), tostring(state.shelving),
			#state.garages, state.target and state.target.name or "nil",
			cw, lim
		))
	end

	-- ── STUCK DETECTION: inAuction > 30s with no bid bar ─────
	if state.inAuction and not state.won and not state.collecting then
		local stuckSec = now - state.inAuctionSince
		if stuckSec > 30 then
			local hasBidBar = findBidBar() ~= nil
			if not hasBidBar then
				wdbg(string.format("STUCK: inAuction=true for %.0fs with no bid bar → auto-clearing", stuckSec))
				state.inAuction = false
				state.lastScan = 0; state.target = nil
			end
		end
	end

	-- ── STUCK DETECTION: collecting > 90s ────────────────────
	if state.collecting then
		local stuckSec = now - state.collectingSince
		if stuckSec > 90 then
			wdbg(string.format("STUCK: collecting=true for %.0fs → force-clearing", stuckSec))
			state.won = false; state.wonGarage = nil; state.collecting = false
			state.inAuction = false; state.target = nil; state.lastScan = 0
		end
	end

	-- ── STUCK DETECTION: unloading > 120s ────────────────────
	if state.unloading then
		-- unloading has its own wasFarming restore at the end,
		-- but if it crashed we need a backstop
		-- (doUnloadAndStock now has pcall so this is a last resort)
		local stuckSec = now - (state.unloadingSince or now)
		if stuckSec > 120 then
			wdbg(string.format("STUCK: unloading=true for %.0fs → force-clearing", stuckSec))
			state.unloading = false
		end
	end

	-- ── AUTO UNLOAD ───────────────────────────────────────────
	if state.autoUnload and not state.unloading and not state.inAuction and not state.won and not state.collecting then
		if now - lastWeightCheck >= 5 then
			lastWeightCheck = now
			if isOverweight() then
				dbg("autoChecks: vehicle overweight → triggering unload")
				task.spawn(doUnloadAndStock); return
			end
		end
	end

	-- ── AUTO LOST & FOUND ─────────────────────────────────────
	if state.autoLostFound and state.farm and not state.lostFoundRunning and not state.unloading then
		if now - lastLostFoundCheck >= 45 then
			lastLostFoundCheck = now
			task.spawn(doLostAndFound)
		end
	end

	-- ── AUTO SHELF ────────────────────────────────────────────
	if state.autoShelf and not state.unloading and not state.shelving then
		if now - lastShelfCheck >= 5 then
			lastShelfCheck = now
			task.spawn(function()
				local ok, inv = pcall(function() return getInventory:InvokeServer() end)
				if not ok or type(inv) ~= "table" then return end
				local hasItems = false
				for _, entry in pairs(inv) do
					if not config.shelfBlacklist[tostring(entry.ItemId or "")] then hasItems = true; break end
				end
				if not hasItems then return end
				local myPlot
				local plots = workspace:FindFirstChild("_Plots")
				if plots then
					for _, p in ipairs(plots:GetChildren()) do
						if p:GetAttribute("OwnerUserId") == player.UserId then myPlot = p; break end
					end
				end
				if not myPlot then return end
				local stockF = myPlot:FindFirstChild("Stock")
				local furnit = myPlot:FindFirstChild("Furniture")
				if not furnit then return end
				local freeSlotFound = false
				for _, shelf in ipairs(furnit:GetChildren()) do
					if freeSlotFound then break end
					if shelf:GetAttribute("IsShelf") == true then
						local sg = shelf:GetAttribute("GUID"); local occ = {}
						if stockF then
							for _, s in ipairs(stockF:GetChildren()) do
								if s:GetAttribute("ShelfGUID") == sg then
									local sn = s:GetAttribute("SnapPointName"); if sn then occ[sn] = true end
								end
							end
						end
						for _, obj in ipairs(shelf:GetDescendants()) do
							if obj:IsA("Attachment") and obj.Name:match("^SnapPoint") and not occ[obj.Name] then
								freeSlotFound = true; break
							end
						end
					end
				end
				local hrp2 = rootPart()
				local nearBase = hrp2 and (hrp2.Position - ownBase).Magnitude < 250
				if not ((nearBase and freeSlotFound) or state.shelfSlotAvailable) then return end
				state.shelfSlotAvailable = false
				local waited = 0
				while (state.inAuction or state.won or state.collecting) and waited < 60 do
					task.wait(1); waited = waited + 1
				end
				state.shelving = true
				local wasFarming = state.farm
				local savedGarage = state.target
				local savedInAuction = state.inAuction
				state.farm = false
				if refreshUi then refreshUi() end
				setStatus("Stocking shelves...")
				teleportPlayer(CFrame.new(ownBase + Vector3.new(0,3,0)))
				task.wait(1.2)
				local stocked = stockShelves()
				setStatus("Stocked "..stocked.." items")
				state.shelving = false
				if wasFarming then
					state.farm = true
					if refreshUi then refreshUi() end
					if savedInAuction and savedGarage then
						setStatus("Returning to auction at "..savedGarage.name.."...")
						teleportPlayer(savedGarage.zone.CFrame * CFrame.new(0,2,-4))
						task.wait(0.5); startPromptLoop(savedGarage)
					else
						scanGarages(); state.target = nil; state.index = 0
						setStatus("Farm resumed after stocking")
					end
				end
			end)
		end
	end
end

-- ══════════════════════════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "SH_ControlUI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = playerGui
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.fromOffset(460, 540); panel.Position = UDim2.fromOffset(8, 64)
panel.BackgroundColor3 = Color3.fromRGB(14,17,24); panel.BorderSizePixel = 0; panel.Active = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,10)
local pstroke = Instance.new("UIStroke", panel); pstroke.Color = Color3.fromRGB(52,148,118); pstroke.Thickness = 1
local uiScaleObj = Instance.new("UIScale", panel)
uiScaleObj.Scale = 1.0
local floatBtn = Instance.new("TextButton", gui)
floatBtn.Size = UDim2.fromOffset(60, 24)
floatBtn.Position = UDim2.fromOffset(8, 36)
floatBtn.BackgroundColor3 = Color3.fromRGB(20,60,45)
floatBtn.BorderSizePixel = 0
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 11
floatBtn.TextColor3 = Color3.fromRGB(235,245,250)
floatBtn.Text = "SH ▼"
do local c = Instance.new("UICorner", floatBtn); c.CornerRadius = UDim.new(0,5) end
do local s = Instance.new("UIStroke", floatBtn); s.Color = Color3.fromRGB(52,148,118); s.Thickness = 1 end
connect(floatBtn.MouseButton1Click, function()
	panel.Visible = not panel.Visible
	floatBtn.Text = panel.Visible and "SH ▼" or "SH ▶"
end)
do
	local drag, ds, dp = false, nil, nil
	panel.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;ds=i.Position;dp=panel.Position end end)
	panel.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
	panel.InputChanged:Connect(function(i)
		if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
			local d=i.Position-ds; panel.Position=UDim2.fromOffset(dp.X.Offset+d.X,dp.Y.Offset+d.Y)
		end
	end)
end
local function btn(text, parent, x, y, w)
	w = w or 190
	local b = Instance.new("TextButton", parent)
	b.Position=UDim2.fromOffset(x,y); b.Size=UDim2.fromOffset(w,28)
	b.BackgroundColor3=Color3.fromRGB(30,40,50); b.BorderSizePixel=0
	b.Font=Enum.Font.GothamBold; b.TextSize=11
	b.TextColor3=Color3.fromRGB(235,245,250); b.Text=text
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
end
local function lbl(text, parent, x, y, w)
	local l=Instance.new("TextLabel",parent); l.Position=UDim2.fromOffset(x,y)
	l.Size=UDim2.fromOffset(w or 430,18); l.BackgroundTransparency=1
	l.Font=Enum.Font.GothamBold; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextColor3=Color3.fromRGB(140,200,180); l.Text=text; return l
end
local function inp(text, parent, x, y, w)
	local i=Instance.new("TextBox",parent); i.Position=UDim2.fromOffset(x,y)
	i.Size=UDim2.fromOffset(w or 90,28); i.Text=text
	i.BackgroundColor3=Color3.fromRGB(30,40,50); i.TextColor3=Color3.fromRGB(255,255,255)
	i.Font=Enum.Font.Gotham; i.TextSize=12; i.BorderSizePixel=0
	Instance.new("UICorner",i).CornerRadius=UDim.new(0,5); return i
end
local tabs = { "MAIN", "FARM", "TELEPORT", "UNLOAD" }
local pages = {}
local tabBar = Instance.new("Frame", panel)
tabBar.Size=UDim2.new(1,0,0,34); tabBar.BackgroundColor3=Color3.fromRGB(20,26,34); tabBar.BorderSizePixel=0
for i, name in ipairs(tabs) do
	local t = btn(name, tabBar, (i-1)*115, 3, 113)
	local pg = Instance.new("Frame", panel); pg.Position=UDim2.fromOffset(0,34)
	pg.Size=UDim2.new(1,0,1,-34); pg.BackgroundTransparency=1; pg.Visible=i==1; pages[i]=pg
	connect(t.MouseButton1Click, function() for n,o in ipairs(pages) do o.Visible=n==i end end)
end
-- PAGE 1: MAIN
local masterBtn = btn("Master: ON", pages[1], 8, 8)
local winBtn    = btn("Auto-Win: ON", pages[1], 236, 8, 214)
local tpBtn     = btn("TP: Instant", pages[1], 8, 44, 190)
local exitBtn   = btn("Exit Script", pages[1], 206, 44, 244)
exitBtn.BackgroundColor3=Color3.fromRGB(80,30,30); exitBtn.TextColor3=Color3.fromRGB(240,110,110)
connect(exitBtn.MouseButton1Click, function() cleanup() end)
local statusLbl = lbl("Ready", pages[1], 8, 84)
local weightLbl = lbl("Vehicle: -- / -- kg", pages[1], 8, 104)
do
	local scaleLbl = Instance.new("TextLabel", pages[1])
	scaleLbl.Position = UDim2.fromOffset(8, 128)
	scaleLbl.Size = UDim2.fromOffset(440, 18)
	scaleLbl.BackgroundTransparency = 1
	scaleLbl.Font = Enum.Font.GothamBold; scaleLbl.TextSize = 11
	scaleLbl.TextXAlignment = Enum.TextXAlignment.Left
	scaleLbl.TextColor3 = Color3.fromRGB(140,200,180)
	scaleLbl.Text = "UI Scale: 1.00x  (tap – / + to resize)"
	local scaleDownBtn  = btn("   –   ", pages[1], 8,   150, 80)
	local scaleUpBtn    = btn("   +   ", pages[1], 96,  150, 80)
	local scaleResetBtn = btn("Reset 1x", pages[1], 184, 150, 100)
	local function applyScale(s)
		s = math.floor(s * 100 + 0.5) / 100
		s = math.max(0.40, math.min(1.50, s))
		uiScaleObj.Scale = s
		scaleLbl.Text = string.format("UI Scale: %.2fx  (tap – / + to resize)", s)
	end
	connect(scaleDownBtn.MouseButton1Click,  function() applyScale(uiScaleObj.Scale - 0.05) end)
	connect(scaleUpBtn.MouseButton1Click,    function() applyScale(uiScaleObj.Scale + 0.05) end)
	connect(scaleResetBtn.MouseButton1Click, function() applyScale(1.0) end)
end
connect(tpBtn.MouseButton1Click, function()
	state.teleportMethod = state.teleportMethod=="Instant" and "Tween" or "Instant"
	tpBtn.Text = "TP: "..state.teleportMethod
end)
-- PAGE 2: FARM
local farmBtn   = btn("Farm: OFF", pages[2], 8, 8, 200)
local rescanBtn = btn("Rescan", pages[2], 216, 8, 110)
local applyBtn  = btn("Apply", pages[2], 334, 8, 116)
lbl("Min Bid ($)", pages[2], 8, 46)
local bidBox = inp("0", pages[2], 8, 64, 130)
lbl("Min Pickup Value ($)", pages[2], 150, 46)
local itemBox = inp("100", pages[2], 150, 64, 130)
lbl("Max Bid Cap ($)", pages[2], 292, 46)
local maxBidBox = inp("999999", pages[2], 292, 64, 158)
local leaveBidBtn = btn("Leave if bid < min: OFF", pages[2], 8, 102, 220)
local leaveMaxBtn = btn("Leave if bid > max: OFF", pages[2], 236, 102, 214)
local leaveValBtn = btn("Leave if value < min: OFF", pages[2], 8, 138, 434)
connect(leaveBidBtn.MouseButton1Click, function()
	state.autoLeaveMinBid = not state.autoLeaveMinBid
	leaveBidBtn.Text = "Leave if bid < min: "..(state.autoLeaveMinBid and "ON" or "OFF")
	state.autoLeaveMinBidAmt = tonumber(bidBox.Text) or 5000
end)
connect(leaveMaxBtn.MouseButton1Click, function()
	state.autoLeaveMaxBid = not state.autoLeaveMaxBid
	leaveMaxBtn.Text = "Leave if bid > max: "..(state.autoLeaveMaxBid and "ON" or "OFF")
	state.autoLeaveMaxBidAmt = tonumber(maxBidBox.Text) or 999999
end)
connect(leaveValBtn.MouseButton1Click, function()
	state.autoLeaveValueMin = not state.autoLeaveValueMin
	leaveValBtn.Text = "Leave if value < min: "..(state.autoLeaveValueMin and "ON" or "OFF")
	state.autoLeaveValueAmt = tonumber(itemBox.Text) or 5000
end)
connect(applyBtn.MouseButton1Click, function()
	config.minBid = tonumber(bidBox.Text) or 0
	config.minItemValue = tonumber(itemBox.Text) or 0
	state.autoLeaveMinBidAmt = tonumber(bidBox.Text) or 5000
	state.autoLeaveMaxBidAmt = tonumber(maxBidBox.Text) or 999999
	setStatus("Filters applied")
end)
connect(farmBtn.MouseButton1Click, function()
	state.farm = not state.farm
	if state.farm then scanGarages(); state.target=nil; state.index=0 end
	setStatus(state.farm and "Farm ON" or "Farm OFF")
end)
connect(rescanBtn.MouseButton1Click, function()
	setStatus("Garages: "..scanGarages()); state.target=nil
end)
local areaDisplay = {
	{key="JunkYard",lbl="Junk Yard"},{key="BackAlley",lbl="Back Alley"},
	{key="Farmyard",lbl="Farmyard"},{key="Shipyard",lbl="Shipyard"},
	{key="LuckyBeach",lbl="Lucky Beach"},{key="PowerPlant",lbl="Power Plant"},
}
local areaBtns = {}
for i, a in ipairs(areaDisplay) do
	local x = 8+((i-1)%2)*222; local y = 176+math.floor((i-1)/2)*32
	local isSelected = state.selected[a.key]
	local b = btn((isSelected and "[•] " or "[ ] ")..a.lbl, pages[2], x, y, 210)
	areaBtns[a.key] = b
	connect(b.MouseButton1Click, function()
		for _, ad in ipairs(areaDisplay) do
			state.selected[ad.key] = false
			if areaBtns[ad.key] then areaBtns[ad.key].Text = "[ ] "..ad.lbl end
		end
		state.selected[a.key] = true
		b.Text = "[•] "..a.lbl
		state.target = nil
	end)
end
local drinkIds = {"359","360","361"}; local diamondIds = {"357","358"}
local whitelistLbl
local function updateWhitelistLabel()
	if not whitelistLbl then return end
	local ids={}; for k in pairs(config.whitelist) do table.insert(ids,k) end
	table.sort(ids); whitelistLbl.Text=#ids>0 and table.concat(ids,", ") or "(none)"
end
local drinkBtn   = btn("[ ] Always pickup: Drinks",   pages[2], 8,   282, 210)
local diamondBtn = btn("[ ] Always pickup: Diamonds", pages[2], 226, 282, 224)
local drinkOn, diamondOn = false, false
connect(drinkBtn.MouseButton1Click, function()
	drinkOn=not drinkOn; drinkBtn.Text=(drinkOn and "[x]" or "[ ]").." Always pickup: Drinks"
	for _,id in ipairs(drinkIds) do if drinkOn then config.whitelist[id]=true else config.whitelist[id]=nil end end
	updateWhitelistLabel()
end)
connect(diamondBtn.MouseButton1Click, function()
	diamondOn=not diamondOn; diamondBtn.Text=(diamondOn and "[x]" or "[ ]").." Always pickup: Diamonds"
	for _,id in ipairs(diamondIds) do if diamondOn then config.whitelist[id]=true else config.whitelist[id]=nil end end
	updateWhitelistLabel()
end)
lbl("Pickup Whitelist (bypass min value filter):", pages[2], 8, 318)
whitelistLbl = lbl("376, 562, 635, 735, 764", pages[2], 8, 334)
whitelistLbl.TextColor3 = Color3.fromRGB(100,220,165)
local whiteBox = inp("", pages[2], 8, 352, 270); whiteBox.PlaceholderText="Item ID or name..."
local whiteAddBtn = btn("Add", pages[2], 286, 352, 60)
local whiteClrBtn = btn("Clear", pages[2], 354, 352, 96)
connect(whiteAddBtn.MouseButton1Click, function()
	local id=whiteBox.Text:match("^%s*(.-)%s*$")
	if id~="" then config.whitelist[id]=true; updateWhitelistLabel() end; whiteBox.Text=""
end)
connect(whiteClrBtn.MouseButton1Click, function() config.whitelist={}; updateWhitelistLabel() end)
local lnfBtn = btn("[ ] Lost & Found Auto-Claim: OFF", pages[2], 8, 390, 434)
connect(lnfBtn.MouseButton1Click, function()
	state.autoLostFound = not state.autoLostFound
	lnfBtn.Text = (state.autoLostFound and "[•] " or "[ ] ").."Lost & Found Auto-Claim: "..(state.autoLostFound and "ON" or "OFF")
	if state.autoLostFound then lastLostFoundCheck = 0 end
end)
-- PAGE 3: TELEPORT
local tpEntries = {
	{"Junk Yard",Vector3.new(19.9,1721.7,-24.3)},{"Back Alley",Vector3.new(-571.2,1721.3,-400)},
	{"Farmyard",Vector3.new(-78.5,1721.6,-1148)},{"Shipyard",Vector3.new(-551,1721.4,698)},
	{"Lucky Beach",Vector3.new(-222.6,1688.8,-1784.8)},{"Power Plant",Vector3.new(-2115.6,1721.1,-955.8)},
}
for i, e in ipairs(tpEntries) do
	local b = btn(e[1], pages[3], 8+((i-1)%2)*224, 8+math.floor((i-1)/2)*34, 212)
	connect(b.MouseButton1Click, function() teleportPlayer(CFrame.new(e[2])) end)
end
connect(btn("My Base", pages[3], 8, 116, 212).MouseButton1Click, function()
	teleportPlayer(CFrame.new(ownBase+Vector3.new(0,3,0)))
end)
-- PAGE 4: UNLOAD
local autoUnloadBtn = btn("Auto-Unload: OFF", pages[4], 8, 8, 214)
local autoShelfBtn  = btn("Auto-Shelf: OFF",  pages[4], 230, 8, 220)
connect(autoUnloadBtn.MouseButton1Click, function()
	state.autoUnload=not state.autoUnload
	autoUnloadBtn.Text="Auto-Unload: "..(state.autoUnload and "ON" or "OFF")
end)
connect(autoShelfBtn.MouseButton1Click, function()
	state.autoShelf=not state.autoShelf
	autoShelfBtn.Text="Auto-Shelf: "..(state.autoShelf and "ON" or "OFF")
end)
lbl("Trigger at weight % (default 90):", pages[4], 8, 46)
local weightPctBox = inp("90", pages[4], 8, 64, 80)
local weightSetBtn = btn("Set", pages[4], 96, 64, 60)
connect(weightSetBtn.MouseButton1Click, function()
	state.unloadPct=tonumber(weightPctBox.Text) or 90
	setStatus("Unload at "..state.unloadPct.."%")
end)
local invCapDetectedLbl = lbl("Inv cap: auto-detecting...", pages[4], 8, 100)
invCapDetectedLbl.TextColor3 = Color3.fromRGB(100,220,165)
task.spawn(function()
	task.wait(1)
	local detected = getMaxInventory()
	state.invCap = detected
	invCapDetectedLbl.Text = "Inv cap: "..detected.." (auto-detected)"
end)
lbl("Override inv cap (if wrong):", pages[4], 230, 84)
local invCapBox = inp(tostring(state.invCap), pages[4], 230, 100, 80)
local invCapSetBtn = btn("Set", pages[4], 318, 100, 60)
connect(invCapSetBtn.MouseButton1Click, function()
	local v = tonumber(invCapBox.Text)
	if v and v > 0 then
		state.invCap = v
		invCapDetectedLbl.Text = "Inv cap: "..v.." (manual)"
		setStatus("Inv cap set to "..v)
	end
end)
connect(btn("Unload + Stock Now", pages[4], 8, 138, 214).MouseButton1Click, function()
	task.spawn(doUnloadAndStock)
end)
connect(btn("Stock Shelves Only", pages[4], 230, 138, 220).MouseButton1Click, function()
	task.spawn(function() setStatus("Stocking..."); local n=stockShelves(); setStatus("Stocked "..n.." items") end)
end)
lbl("Shelf Blacklist (never placed on shelf):", pages[4], 8, 176)
local shelfBLlbl = lbl("357,358,359,360,361,635,735,764", pages[4], 8, 192)
shelfBLlbl.TextColor3=Color3.fromRGB(220,100,100)
local shelfBlBox = inp("", pages[4], 8, 210, 270); shelfBlBox.PlaceholderText="Add item ID..."
local shelfBlAdd = btn("Add", pages[4], 286, 210, 60)
local shelfBlClr = btn("Clear all", pages[4], 354, 210, 96)
local function updateShelfBL()
	local ids={}; for id in pairs(config.shelfBlacklist) do table.insert(ids,id) end
	table.sort(ids); shelfBLlbl.Text=#ids>0 and table.concat(ids,",") or "(none)"
end
updateShelfBL()
connect(shelfBlAdd.MouseButton1Click, function()
	local id=shelfBlBox.Text:match("^%s*(.-)%s*$")
	if id~="" then config.shelfBlacklist[id]=true; updateShelfBL() end; shelfBlBox.Text=""
end)
connect(shelfBlClr.MouseButton1Click, function() config.shelfBlacklist={}; updateShelfBL() end)

-- ── TROPHY MUTATION BLACKLIST ──────────────────────────────
-- Checked = that mutation is BLOCKED from shelving.
-- When nothing is checked, all trophies are skipped (legacy behaviour).
-- When at least one mutation is checked, only checked mutations are skipped;
-- trophies whose mutation is NOT checked ARE placed on shelves.
do
	lbl("── Trophy Mut Blacklist (checked = skip shelving) ──", pages[4], 8, 244)
	local trophyMutLbl = lbl("Blocked: (none — all trophies skip by default)", pages[4], 8, 262)
	trophyMutLbl.Size = UDim2.fromOffset(444, 14); trophyMutLbl.TextSize = 10
	trophyMutLbl.TextColor3 = Color3.fromRGB(220,100,100)

	local trophyMutBtns = {}
	local function updateTrophyMutLbl()
		local names = {}
		for _, m in ipairs(trophyMutations) do
			if trophyMutBlacklist[m] then table.insert(names, m) end
		end
		if #names == 0 then
			trophyMutLbl.Text = "Blocked: (none — all trophies skip by default)"
		else
			trophyMutLbl.Text = "Blocked: " .. table.concat(names, ", ")
		end
	end

	local COLS = 2; local BW = 218; local BROW = 26
	for i, mutName in ipairs(trophyMutations) do
		local col = (i-1) % COLS
		local row = math.floor((i-1) / COLS)
		local bx = 8 + col * (BW+4)
		local by = 278 + row * BROW
		local b = btn("[ ] "..mutName, pages[4], bx, by, BW)
		b.TextSize = 11
		trophyMutBtns[mutName] = b
		connect(b.MouseButton1Click, function()
			if trophyMutBlacklist[mutName] then
				trophyMutBlacklist[mutName] = nil
				b.Text = "[ ] "..mutName
			else
				trophyMutBlacklist[mutName] = true
				b.Text = "[x] "..mutName
			end
			updateTrophyMutLbl()
		end)
	end

	-- "Clear" button goes in the slot after the last mutation
	local lastIdx = #trophyMutations - 1
	local lastCol = lastIdx % COLS
	local lastRow = math.floor(lastIdx / COLS)
	local clrCol = lastCol + 1; local clrRow = lastRow
	if clrCol >= COLS then clrCol = 0; clrRow = lastRow + 1 end
	local clrX = 8 + clrCol * (BW+4)
	local clrY = 278 + clrRow * BROW
	connect(btn("Clear Trophy BL", pages[4], clrX, clrY, BW).MouseButton1Click, function()
		trophyMutBlacklist = {}
		for _, m in ipairs(trophyMutations) do
			if trophyMutBtns[m] then trophyMutBtns[m].Text = "[ ] "..m end
		end
		updateTrophyMutLbl()
	end)
end

-- REFRESH
refreshUi = function()
	masterBtn.Text="Master: "..(state.master and "ON" or "OFF")
	winBtn.Text="Auto-Win: "..(state.autoWin and "ON" or "OFF")
	farmBtn.Text="Farm: "..(state.farm and "ON" or "OFF")
	statusLbl.Text=state.status.." | Bid: $"..math.floor(state.currentBid).." | Garages: "..#state.garages
	local cw, lim = getVehicleWeight()
	local pct = lim>0 and math.floor(cw/lim*100) or 0
	weightLbl.Text=string.format("Vehicle: %.0f/%.0f kg (%d%%)", cw, lim, pct)
end

-- ══════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ══════════════════════════════════════════════════════════════
connect(masterBtn.MouseButton1Click, function()
	state.master=not state.master; setStatus(state.master and "Master ON" or "Master OFF")
end)
connect(winBtn.MouseButton1Click, function()
	state.autoWin=not state.autoWin; setStatus(state.autoWin and "Auto-Win ON" or "Auto-Win OFF")
end)
connect(updateBid.OnClientEvent, function(bid, bidder)
	state.currentBid=tonumber(bid) or 0
	if bidder=="Starting" then state.startingBid=state.currentBid end
	dbg(string.format("updateBid: bid=$%d bidder=%s", state.currentBid, tostring(bidder)))
	local checkBid=state.currentBid>0 and state.currentBid or state.startingBid
	if state.autoLeaveMinBid and checkBid>0 and checkBid<state.autoLeaveMinBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." < $"..state.autoLeaveMinBidAmt) end
	if state.autoLeaveMaxBid and checkBid>0 and checkBid>state.autoLeaveMaxBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." > $"..state.autoLeaveMaxBidAmt) end
	refreshUi()
end)
connect(toggleBid.OnClientEvent, function(open)
	dbg("toggleBid: open=" .. tostring(open))
	if open then
		state.inAuction = true
		state.inAuctionSince = os.clock()
		setStatus("Bidding")
	end
end)
connect(toggleAuctionArea.OnClientEvent, function(active, g)
	dbg(string.format("toggleAuctionArea: active=%s garage=%s", tostring(active), g and g.Name or "nil"))
	state.currentAuctionGarage=g; state.inAuction=active
	if active then
		state.inAuctionSince = os.clock()
		setStatus("Auction: "..(g and g.Name or "?"))
		state.targetStarted = os.clock()
		if state.farm then
			task.spawn(function()
				local zone = g and g:FindFirstChild("AuctionZone", true)
				if zone then
					teleportPlayer(zone.CFrame * CFrame.new(0, 2, -4))
				elseif state.target and state.target.zone then
					teleportPlayer(state.target.zone.CFrame * CFrame.new(0, 2, -4))
				end
			end)
		end
		if state.autoLeaveValueMin and state.startingBid>0 and state.startingBid<state.autoLeaveValueAmt then
			task.wait(0.5); leaveAuction(); setStatus("Left: value $"..state.startingBid.." < $"..state.autoLeaveValueAmt)
		end
	else
		dbg("toggleAuctionArea: auction area closed → inAuction=false")
	end
end)
connect(pickupEnd.OnClientEvent, function()
	dbg("pickupEnd fired")
	state.inAuction=false
	if not state.collecting then state.won=false end
	setStatus("Pickup ended")
end)
connect(pickupStart.OnClientEvent, function()
	dbg("pickupStart fired → finalizeWin()")
	finalizeWin()
end)
connect(notifyRemote.OnClientEvent, function(msg)
	if type(msg) ~= "string" then return end
	dbg("notify: " .. msg)
	local lmsg = msg:lower()
	if lmsg:find("too far") and state.collecting then
		dbg("notify: vehicle too far → vehicleFarSignal=true")
		state.vehicleFarSignal = true
	end
	if lmsg:find("^sold ") and state.autoShelf then
		dbg("notify: item sold → shelf slot available")
		state.shelfSlotAvailable = true
		lastShelfCheck = 0
	end
end)
connect(offerOverweightAdd.OnClientEvent, function()
	dbg("offerOverweightAdd fired → overweightSignal=true")
	state.overweightSignal = true
	task.wait(0.1)
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("TextButton") and obj.Text:lower():find("not now") then
			local toDestroy = obj
			while toDestroy.Parent and not toDestroy.Parent:IsA("ScreenGui") do
				toDestroy = toDestroy.Parent
			end
			pcall(function() toDestroy:Destroy() end)
			break
		end
	end
end)

-- ══════════════════════════════════════════════════════════════
-- HEARTBEAT
-- ══════════════════════════════════════════════════════════════
local lastUIRefresh = 0
connect(RunService.Heartbeat, function()
	if state.master and state.farm then pcall(farmStep) end
	pcall(autoChecks)
	if os.clock()-lastUIRefresh >= 1.5 then lastUIRefresh=os.clock(); pcall(refreshUi) end
end)

-- ══════════════════════════════════════════════════════════════
-- GLOBALS
-- ══════════════════════════════════════════════════════════════
getgenv().SH_SetFarm = function(v)
	state.farm=v==true
	if state.farm then scanGarages(); state.target=nil; state.index=0 end
	setStatus(state.farm and "Farm ON" or "Farm OFF")
end
getgenv().SH_State = state

-- SH_Dump(): call this anytime in the console to get a full state snapshot
getgenv().SH_Dump = function()
	local now = os.clock()
	local cw, lim = getVehicleWeight()
	warn("══════ SH MANUAL DUMP ══════")
	warn(string.format("farm=%s  master=%s  autoWin=%s", tostring(state.farm), tostring(state.master), tostring(state.autoWin)))
	warn(string.format("won=%s  collecting=%s (%.0fs ago started)  inAuction=%s (%.0fs ago started)",
		tostring(state.won), tostring(state.collecting), now - state.collectingSince,
		tostring(state.inAuction), now - state.inAuctionSince))
	warn(string.format("unloading=%s  shelving=%s  lnfRunning=%s", tostring(state.unloading), tostring(state.shelving), tostring(state.lostFoundRunning)))
	warn(string.format("overweightSig=%s  vehicleFarSig=%s  shelfSlotAvail=%s",
		tostring(state.overweightSignal), tostring(state.vehicleFarSignal), tostring(state.shelfSlotAvailable)))
	warn(string.format("garages=%d  target=%s  index=%d", #state.garages, state.target and state.target.name or "nil", state.index))
	warn(string.format("lastLeaveTime=%.1fs ago  lastScan=%.1fs ago  targetTimeout=%ds",
		now - lastLeaveTime, now - state.lastScan, state.targetTimeout))
	warn(string.format("vehicle=%.0f/%.0fkg  unloadPct=%d%%  invCap=%d", cw, lim, state.unloadPct, state.invCap))
	warn("════════════════════════════")
end

-- ══════════════════════════════════════════════════════════════
-- INIT
-- ══════════════════════════════════════════════════════════════
scanGarages(); refreshUi()
print("[SH v8.1-debug] Loaded — call SH_Dump() anytime for a full state snapshot")
