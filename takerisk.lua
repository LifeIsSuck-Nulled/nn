-- SH Helper v8 fixed: crate opening + owner scan + real values + whitelist + unload tab
-- + OfferOverweightAdd detection: stops pickup, dismisses popup, triggers unload
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
local offerOverweightAdd = Events.UI:WaitForChild("OfferOverweightAdd") -- NEW
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
	won = false, wonGarage = nil, collecting = false,
	beforeInventory = {}, lastBid = 0, currentBid = 0, startingBid = 0,
	status = "Ready", teleportMethod = "Instant",
	autoLeaveMinBid = false, autoLeaveMinBidAmt = 5000,
	autoLeaveValueMin = false, autoLeaveValueAmt = 5000,
	autoLeaveMaxBid = false, autoLeaveMaxBidAmt = 999999,
	-- unload tab
	autoUnload = false, autoShelf = false, unloadPct = 90, unloading = false, shelving = false,
	-- overweight signal
	overweightSignal = false, -- set true when OfferOverweightAdd fires during pickup
	vehicleFarSignal = false,   -- set true when "vehicle too far away" Notify fires during pickup
	shelfSlotAvailable = false, -- set true when a "Sold" notification confirms a slot opened
	-- lost & found
	autoLostFound = false, lostFoundRunning = false,
	-- inventory cap (auto-detected; override if needed)
	invCap = 10,
}

local config = {
	minBid = 0, minItemValue = 100, hitTolerance = 0.0075,
	whitelist = {
		["376"] = true, -- Gavel Trophy (110 kg, $10)
		["562"] = true, -- Race Trophy (38 kg, $1040)
		["635"] = true, -- Wooden Certificate Of Authenticity
		["735"] = true, -- Premium Certificate Of Authenticity
		["764"] = true, -- Ripped Certificate Of Authenticity
	},
	shelfBlacklist = {
		["357"] = true, ["358"] = true,
		["359"] = true, ["360"] = true, ["361"] = true,
		["635"] = true, ["735"] = true, ["764"] = true,
	}
}

local areaOptions = { "JunkYard", "BackAlley", "Farmyard", "Shipyard", "LuckyBeach", "PowerPlant" }
state.selected["JunkYard"] = true -- default: only one area selected at a time (radio)

-- Maps script area key → game display name used by GetLostItems / ClaimLostItem / workspace.Areas
local areaGameNames = {
	JunkYard    = "Junk Yard",
	BackAlley   = "Back Alley",
	Farmyard    = "Farmyard",
	Shipyard    = "Shipyard",
	LuckyBeach  = "Lucky Beach",
	PowerPlant  = "Power Plant",
}

local function connect(s, cb) local c = s:Connect(cb); table.insert(connections, c); return c end
local function cleanup()
	alive = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	local ui = playerGui:FindFirstChild("SH_ControlUI"); if ui then ui:Destroy() end
	getgenv().SH_SetFarm = nil; getgenv().SH_State = nil; _G.SH_HelperCleanup = nil
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
	if not gf then state.garages = r; state.lastScan = os.clock(); return 0 end
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
	state.garages = r; state.lastScan = os.clock(); return #r
end

local function selectedGarage(idx)
	local n = #state.garages; if n == 0 then return nil, nil end
	-- first pass: prefer garages whose EnterAuction prompt is currently enabled (active auction)
	for step = 1, n do
		local ni = ((idx + step - 1) % n) + 1; local g = state.garages[ni]
		if state.selected[g.area] then
			local p = g.instance:FindFirstChild("EnterAuction", true)
			if p and p:IsA("ProximityPrompt") and p.Enabled then return ni, g end
		end
	end
	-- fallback: any selected garage (no active auction visible yet — wait at one until it starts)
	for step = 1, n do
		local ni = ((idx + step - 1) % n) + 1; local g = state.garages[ni]
		if state.selected[g.area] then return ni, g end
	end
	return nil, nil
end

-- ORIGINAL findBidBar from v8 (no changes)
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

local lastLeaveTime = 0 -- cooldown timer: set on leaveAuction, checked in farmStep

-- ORIGINAL leaveAuction from v8
local function leaveAuction()
	pcall(function() leaveRemote:InvokeServer() end)
	state.inAuction = false; state.won = false; state.lastBid = 0
	state.target = nil; state.lastScan = 0 -- force immediate rescan + next garage on next farmStep tick
	lastLeaveTime = os.clock() -- cooldown: prevent instant TP to next garage after leaving
end

-- ORIGINAL tryBid from v8
local function tryBid()
	local cur, zone, w = findBidBar(); if not cur then return false end
	state.inAuction = true
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

-- ORIGINAL startPromptLoop from v8
local function startPromptLoop(g)
	task.spawn(function()
		for _ = 1, 15 do
			if not alive or not state.farm or state.won or findBidBar() then return end
			local p = g.instance:FindFirstChild("EnterAuction", true)
			if p and p:IsA("ProximityPrompt") and p.Enabled then
				triggerPrompt(p)
				task.wait(1.5) -- wait for bid bar to appear before retrying (reduces "already in auction" spam)
			else
				task.wait(0.3)
			end
		end
	end)
end

-- ORIGINAL chooseNextGarage from v8
local function chooseNextGarage()
	local idx, g = selectedGarage(state.index)
	if not g then setStatus("No garages -- rescanning"); scanGarages(); return end
	state.index = idx; state.target = g; state.targetStarted = os.clock()
	teleportPlayer(g.zone.CFrame * CFrame.new(0, 2, -4))
	setStatus("Going: "..g.area.." / "..g.name)
	startPromptLoop(g)
end

-- ORIGINAL farmStep from v8 (with collecting guard added)
local function farmStep()
	if not alive or not state.master or not state.farm then return end
	if #state.garages == 0 or os.clock() - state.lastScan >= 10 then scanGarages() end
	if tryBid() then return end
	if state.won or state.collecting then return end
	if state.inAuction then return end -- don't switch garages while server says we're in an auction
	if os.clock() - lastLeaveTime < 2.5 then return end -- cooldown after leaving auction (prevents instant re-TP)
	if state.target and os.clock() - state.targetStarted < state.targetTimeout then return end
	state.target = nil; chooseNextGarage()
end

-- Real item value
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
	-- always spawn vehicle before collecting won items
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
	task.spawn(function()
		local garage = state.wonGarage
		if not garage then
			state.won = false; state.wonGarage = nil; state.collecting = false; return
		end

		state.overweightSignal = false  -- reset at start of each pickup session
		state.vehicleFarSignal = false
		state.beforeInventory = {}
		pcall(function()
			local inv = getInventory:InvokeServer()
			if type(inv) == "table" then for g in pairs(inv) do state.beforeInventory[g] = true end end
		end)

		local deadline = os.clock() + 35
		local collected, opened = 0, 0

		-- PASS 1: open crates first
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
		setStatus(string.format("Opened %d crates, scanning items...", opened))

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
				if state.overweightSignal then break end -- NEW: stop if overweight fired
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
						-- pickup failed: vehicle too far — respawn and let outer while retry items
						state.vehicleFarSignal = false
						setStatus("Vehicle too far! Respawning...")
						local eGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
						if eGUID ~= "" then
							pcall(function() requestSpawn:FireServer(eGUID) end)
							task.wait(2); exitVehicle(); task.wait(0.2)
						end
						break -- outer while will rescan and retry remaining items
					end
					collected = collected + 1
					if state.overweightSignal then break end -- check after each pickup
				end
			end
			if state.overweightSignal then break end -- NEW: propagate break to outer while
			if not acted then break end
		end

		-- NEW: overweight bail-out — skip double-check, move what we have, go unload
		if state.overweightSignal then
			local moved, repaired = moveAllWonToVehicle()
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
		setStatus(string.format("Collected %d items, %d crates | moved %d (%d repaired)", collected, opened, moved, repaired))
		state.won = false; state.wonGarage = nil; state.collecting = false

		if state.autoUnload and isOverweight() and not state.unloading then
			task.spawn(doUnloadAndStock)
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
	-- try known player attributes first
	local cap = tonumber(player:GetAttribute("InventoryCapacity"))
		or tonumber(player:GetAttribute("MaxInventory"))
		or tonumber(player:GetAttribute("InventorySize"))
		or tonumber(player:GetAttribute("MaxInventorySlots"))
	if cap and cap > 0 then return cap end
	-- fallback: user-set override (state.invCap), default 10
	return state.invCap or 10
end
isOverweight = function()
	local cw, lim = getVehicleWeight()
	return lim > 0 and (cw/lim*100) >= state.unloadPct
end

-- ── SHELF STOCKING ───────────────────────────────────────────
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
		if config.shelfBlacklist[id] then continue end
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
	if state.unloading then return end
	state.unloading = true
	local wasFarming = state.farm
	state.farm = false
	if refreshUi then refreshUi() end
	setStatus("Going to base to unload...")
	teleportPlayer(CFrame.new(ownBase + Vector3.new(0,3,0)))
	task.wait(1.2)

	-- spawn vehicle (stay seated for unload)
	local equippedGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
	if equippedGUID ~= "" then
		pcall(function() requestSpawn:FireServer(equippedGUID) end)
		task.wait(2)
	end

	-- unload in batches
	local totalUnloaded = 0
	for _ = 1, 20 do
		local ok, vitems = pcall(function() return getVehicleItems:InvokeServer(equippedGUID) end)
		if not ok or type(vitems) ~= "table" or not next(vitems) then break end
		local ok2, inv = pcall(function() return getInventory:InvokeServer() end)
		local invCount = 0
		if ok2 and type(inv) == "table" then for _ in pairs(inv) do invCount = invCount + 1 end end
		local freeSlots = getMaxInventory() - invCount
		if freeSlots <= 0 then
			if state.autoShelf then
				setStatus("Inventory full, stocking shelves first...")
				stockShelves(); task.wait(0.5)
			else break end
		else
			local guids = {}
			for g in pairs(vitems) do table.insert(guids, g); if #guids >= freeSlots then break end end
			pcall(function() unloadVehicle:FireServer(guids) end)
			totalUnloaded = totalUnloaded + #guids
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
	end

	state.unloading = false
	if wasFarming then
		state.farm = true
		scanGarages(); state.target = nil; state.index = 0
		if refreshUi then refreshUi() end
		setStatus("Farm resumed after unload")
	end
end

-- ── LOST AND FOUND ───────────────────────────────────────────
local function doLostAndFound()
	if state.lostFoundRunning then return end
	state.lostFoundRunning = true

	-- find the currently selected area key
	local areaKey = nil
	for _, key in ipairs(areaOptions) do
		if state.selected[key] then areaKey = key; break end
	end
	if not areaKey then state.lostFoundRunning = false; return end

	local gameName = areaGameNames[areaKey]
	if not gameName then state.lostFoundRunning = false; return end

	-- query server for lost items in this area
	local ok, result = pcall(function() return getLostItems:InvokeServer(gameName) end)
	if not ok or type(result) ~= "table" or type(result.items) ~= "table" then
		state.lostFoundRunning = false; return
	end

	-- filter by min value + whitelist (same rules as normal pickup — whitelist bypasses min value)
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

	-- wait for any active auction / pickup to finish (up to 60s)
	local waited = 0
	while (state.won or state.collecting or state.inAuction) and waited < 60 and alive do
		task.wait(1); waited = waited + 1
	end
	if not alive then state.lostFoundRunning = false; return end

	-- locate Lost and Found Box in workspace.Areas
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

	-- spawn vehicle before pickup
	local equippedGUID = tostring(player:GetAttribute("EquippedVehicle") or "")
	if equippedGUID ~= "" then
		pcall(function() requestSpawn:FireServer(equippedGUID) end)
		task.wait(2); exitVehicle(); task.wait(0.2)
	end

	-- snapshot inventory so we know what's new after claims
	local beforeLnfInv = {}
	pcall(function()
		local inv = getInventory:InvokeServer()
		if type(inv) == "table" then for g in pairs(inv) do beforeLnfInv[g] = true end end
	end)

	-- claim qualifying items one by one
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

	-- move newly claimed items to vehicle
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

	setStatus(string.format("L&F: done — %d/%d items claimed", claimed, #qualifying))
	state.lostFoundRunning = false

	if wasFarming then
		state.farm = true
		scanGarages(); state.target = nil; state.index = 0
		if refreshUi then refreshUi() end
		setStatus("Farm resumed after L&F")
	end
end

-- ── AUTO WEIGHT + SHELF CHECK ─────────────────────────────────
local lastWeightCheck = 0
local lastShelfCheck = 0
local lastLostFoundCheck = 0
local function autoChecks()
	local now = os.clock()
	-- weight check every 5s
	if state.autoUnload and not state.unloading and not state.inAuction and not state.won and not state.collecting then
		if now - lastWeightCheck >= 5 then
			lastWeightCheck = now
			if isOverweight() then task.spawn(doUnloadAndStock); return end
		end
	end
	-- lost & found check every 45s
	if state.autoLostFound and state.farm and not state.lostFoundRunning and not state.unloading then
		if now - lastLostFoundCheck >= 45 then
			lastLostFoundCheck = now
			task.spawn(doLostAndFound)
		end
	end
	-- shelf check every 5s (background, farm keeps running)
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
				-- check free slots
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
				-- When far from base, workspace._Plots isn't fully streamed: the Stock folder
				-- has no children so every snap point looks free (false positive).
				-- Only trust the local scan when the player is near base.
				-- If a "Sold" notification arrived, a slot definitely opened — trust that instead.
				local hrp2 = rootPart()
				local nearBase = hrp2 and (hrp2.Position - ownBase).Magnitude < 250
				if not ((nearBase and freeSlotFound) or state.shelfSlotAvailable) then return end
				state.shelfSlotAvailable = false -- consume the flag
				-- confirmed slot available — wait for auction/pickup to finish, then stock and return
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

-- ── MOBILE ADDITIONS ─────────────────────────────────────────
-- UIScale so the whole panel can be shrunk for small screens
local uiScaleObj = Instance.new("UIScale", panel)
uiScaleObj.Scale = 1.0

-- Floating hide/show toggle (always visible even when panel is hidden)
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
-- ─────────────────────────────────────────────────────────────

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

-- UI Scale controls (step 0.05, range 0.40x – 1.50x)
do
	local scaleLbl = Instance.new("TextLabel", pages[1])
	scaleLbl.Position = UDim2.fromOffset(8, 128)
	scaleLbl.Size = UDim2.fromOffset(440, 18)
	scaleLbl.BackgroundTransparency = 1
	scaleLbl.Font = Enum.Font.GothamBold; scaleLbl.TextSize = 11
	scaleLbl.TextXAlignment = Enum.TextXAlignment.Left
	scaleLbl.TextColor3 = Color3.fromRGB(140,200,180)
	scaleLbl.Text = "UI Scale: 1.00x  (tap – / + to resize)"

	local scaleDownBtn = btn("   –   ", pages[1], 8, 150, 80)
	local scaleUpBtn   = btn("   +   ", pages[1], 96, 150, 80)
	local scaleResetBtn = btn("Reset 1x", pages[1], 184, 150, 100)

	local function applyScale(s)
		s = math.floor(s * 100 + 0.5) / 100          -- round to 2dp
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

-- areas (radio: only one location active at a time)
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
		-- deselect all
		for _, ad in ipairs(areaDisplay) do
			state.selected[ad.key] = false
			if areaBtns[ad.key] then areaBtns[ad.key].Text = "[ ] "..ad.lbl end
		end
		-- select this one
		state.selected[a.key] = true
		b.Text = "[•] "..a.lbl
		state.target = nil
	end)
end

-- whitelist
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

-- lost & found toggle
local lnfBtn = btn("[ ] Lost & Found Auto-Claim: OFF", pages[2], 8, 390, 434)
connect(lnfBtn.MouseButton1Click, function()
	state.autoLostFound = not state.autoLostFound
	lnfBtn.Text = (state.autoLostFound and "[•] " or "[ ] ").."Lost & Found Auto-Claim: "..(state.autoLostFound and "ON" or "OFF")
	if state.autoLostFound then
		lastLostFoundCheck = 0 -- trigger a check immediately on next autoChecks tick
	end
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
	task.wait(1) -- wait for player data to load
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
connect(shelfBlAdd.MouseButton1Click, function()
	local id=shelfBlBox.Text:match("^%s*(.-)%s*$")
	if id~="" then config.shelfBlacklist[id]=true; updateShelfBL() end; shelfBlBox.Text=""
end)
connect(shelfBlClr.MouseButton1Click, function() config.shelfBlacklist={}; updateShelfBL() end)

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

-- EVENTS
connect(masterBtn.MouseButton1Click, function()
	state.master=not state.master; setStatus(state.master and "Master ON" or "Master OFF")
end)
connect(winBtn.MouseButton1Click, function()
	state.autoWin=not state.autoWin; setStatus(state.autoWin and "Auto-Win ON" or "Auto-Win OFF")
end)
connect(updateBid.OnClientEvent, function(bid, bidder)
	state.currentBid=tonumber(bid) or 0
	if bidder=="Starting" then state.startingBid=state.currentBid end
	local checkBid=state.currentBid>0 and state.currentBid or state.startingBid
	if state.autoLeaveMinBid and checkBid>0 and checkBid<state.autoLeaveMinBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." < $"..state.autoLeaveMinBidAmt) end
	if state.autoLeaveMaxBid and checkBid>0 and checkBid>state.autoLeaveMaxBidAmt then leaveAuction(); setStatus("Left: bid $"..checkBid.." > $"..state.autoLeaveMaxBidAmt) end
	refreshUi()
end)
connect(toggleBid.OnClientEvent, function(open) if open then state.inAuction=true; setStatus("Bidding") end end)
connect(toggleAuctionArea.OnClientEvent, function(active, g)
	state.currentAuctionGarage=g; state.inAuction=active
	if active then
		setStatus("Auction: "..(g and g.Name or "?"))
		-- reset target timer so farmStep won't timeout and switch garages mid-auction
		state.targetStarted = os.clock()
		-- immediately TP back to the auction zone (game gives ~10s window)
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
	end
end)
connect(pickupEnd.OnClientEvent, function()
	state.inAuction=false
	if not state.collecting then state.won=false end
	setStatus("Pickup ended")
end)
connect(pickupStart.OnClientEvent, function() finalizeWin() end)

-- Notify handler: "vehicle too far" → respawn mid-pickup; "Sold ..." → shelf slot opened
connect(notifyRemote.OnClientEvent, function(msg)
	if type(msg) ~= "string" then return end
	local lmsg = msg:lower()
	if lmsg:find("too far") and state.collecting then
		state.vehicleFarSignal = true
	end
	if lmsg:find("^sold ") and state.autoShelf then
		-- an item sold = a shelf slot just freed up; trigger stocking on next autoChecks tick
		state.shelfSlotAvailable = true
		lastShelfCheck = 0
	end
end)

-- auto-dismiss overweight popup + signal pickup loop to bail out
connect(offerOverweightAdd.OnClientEvent, function()
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

local lastUIRefresh = 0
connect(RunService.Heartbeat, function()
	if state.master and state.farm then pcall(farmStep) end
	pcall(autoChecks)
	if os.clock()-lastUIRefresh >= 1.5 then lastUIRefresh=os.clock(); pcall(refreshUi) end
end)

getgenv().SH_SetFarm = function(v)
	state.farm=v==true
	if state.farm then scanGarages(); state.target=nil; state.index=0 end
	setStatus(state.farm and "Farm ON" or "Farm OFF")
end
getgenv().SH_State = state

scanGarages(); refreshUi()
print("[SH v8 phone] Loaded")
