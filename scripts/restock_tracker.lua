--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                    LABA BABY HUB - FIXED & IMPROVED                          ║
║              Professional Roblox Automation Suite (v2.2)                     ║
║                                                                              ║
║  FIXES: Syntax errors removed, Sniper logic improved, Tool matching refined, ║
║         UI Login bug fixed, RESTORED MISSING PC/GROCERY, SORTING BUG FIXED!  ║
╚══════════════════════════════════════════════════════════════════════════════╝
]]

-- ============================================================================
-- 🔧 SERVICE INITIALIZATION
-- ============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

-- ============================================================================
-- 🎯 GLOBAL STATE & CONFIGURATION
-- ============================================================================
local Config = {
	GUI_NAME = "LabaBabyHubGUI",
	UI_THEME = {
		BG_DARK = Color3.fromRGB(25, 25, 30),
		BG_DARKER = Color3.fromRGB(18, 18, 22),
		BG_LIGHT = Color3.fromRGB(35, 35, 40),
		ACCENT_GREEN = Color3.fromRGB(40, 160, 70),
		ACCENT_RED = Color3.fromRGB(150, 40, 40),
		TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
		TEXT_SECONDARY = Color3.fromRGB(200, 200, 200),
		BORDER = Color3.fromRGB(60, 60, 70),
	},
	SHOP_CFS = {
		PC = CFrame.new(-240.48721313476562, 7.888942718505859, 136.32080078125),
		GROCERY = CFrame.new(-102.66999816894531, 8.224592208862305, 10.839996337890625),
	},
	TELEPORT_OFFSETS = {
		MESS = CFrame.new(0, 2.5, 2.5),
		FIRE = CFrame.new(0, 3, -4),
		APPOINT = CFrame.new(0, 3, 2.5),
		CHEF = CFrame.new(0, 3, -4),
	},
	BASE_RADIUS = 120,
	EQUIP_TIMEOUT = 20,
	ACTIVATION_DISTANCE = 100,
	PROMPT_HOLD_DURATION = 0.5,
	TOOLS = {
		MESS = {"walis", "broom", "mop", "sweep"},
		GLASS = {"towel", "sponge", "wipe", "rag"},
		FIRE = {"extinguish", "fire"},
	},
	WEBHOOKS = {
		DEBUG = "https://discord.com/api/webhooks/1530530759457247355/Xi9gmdqaGAc1waG846-BAUelmZFx3QIdnLsXiuC_yJP-LEtjsfc1wJ7zCYZhrk7ZrK10",
		TRACKER = "https://discord.com/api/webhooks/1326732013750980618/Pn-nfG7dUBf9LBUzR8-sr__Y_WGg4SbfTQdmOMPAf3JG1KUXdjvK3YaB8hqgQZmh_par",
	},
	SNIPER = {
		MAX_RETRIES = 25,
		RETRY_DELAY = 0.3,
		STOCK_CHECK_DELAY = 0.2,
		MAX_BUY_AMOUNT = 999,
		SHOP_RETURN_DELAY = 1.0,
	},
}

local State = {
	MasterPC = false,
	MasterGrocery = false,
	AutoAppoint = false,
	AutoChef = false,
	AutoExtinguish = false,
	AutoClean = false,
	IsShopping = false,
	IsBusy = false,
	TargetItemsPC = {},
	TargetItemsGrocery = {},
	MyHomeLaptop = nil,
	MyCafePos = nil,
	CurrentWebhook = "",
}

local fetch = request or http_request or (syn and syn.request)

-- ============================================================================
-- 📦 MODULE REQUIRES & REMOTES
-- ============================================================================
local Modules = { ShopConfig = nil, StockService = nil, Net = nil }
local Remotes = {}

pcall(function()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local scripts = shared:WaitForChild("Scripts")
	Modules.ShopConfig = require(scripts:WaitForChild("SHOP_CONFIG"))
	Modules.StockService = require(scripts:WaitForChild("Packages"):WaitForChild("StockService"))
	Modules.Net = require(scripts:WaitForChild("Packages"):WaitForChild("Net"))

	Remotes.ShopPurchase = Modules.Net:RemoteEvent("ShopPurchase")
	Remotes.SelectPC = Modules.Net:RemoteEvent("selectPC")
	Remotes.Appoint = Modules.Net:RemoteEvent("AppointNPC")
	Remotes.Cook = Modules.Net:RemoteEvent("CookEvent")
	Remotes.Deliver = Modules.Net:RemoteEvent("DeliverEvent")
	Remotes.SelectTray = Modules.Net:RemoteEvent("SelectTrayOrder")
end)

-- ============================================================================
-- 🌐 WEBHOOK & LOGGING SYSTEM
-- ============================================================================
local Webhook = {}
function Webhook.Send(payload, webhookUrl)
	if not fetch or not webhookUrl or webhookUrl == "" then return end
	pcall(function()
		fetch({ Url = webhookUrl, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) })
	end)
end

function Webhook.ExecutionLog(username)
	Webhook.Send({
		username = "Laba Execution Log",
		content = "👤 **New User Executed Script:** `" .. username .. "`\n🆔 **User ID:** `" .. tostring(Players.LocalPlayer.UserId) .. "`",
	}, Config.WEBHOOKS.TRACKER)
end

function Webhook.Debug(message)
	Webhook.Send({ username = "Laba Debugger", content = "⚠️ **DEBUG LOG:**\n" .. message }, Config.WEBHOOKS.DEBUG)
end

function Webhook.User(payload)
	Webhook.Send(payload, State.CurrentWebhook)
end

task.spawn(function() Webhook.ExecutionLog(Players.LocalPlayer.Name) end)

-- ============================================================================
-- 🛡️ ANTI-AFK & ANTI-DEATH SYSTEMS
-- ============================================================================
Players.LocalPlayer.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		pcall(function()
			local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < -100 then
				hrp.Velocity = Vector3.new(0, 0, 0)
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				if State.MyHomeLaptop and State.MyHomeLaptop.Parent then
					hrp.CFrame = State.MyHomeLaptop.Parent.CFrame * CFrame.new(0, 4, 2.5)
				elseif State.MyCafePos then
					hrp.CFrame = CFrame.new(State.MyCafePos) * CFrame.new(0, 5, 0)
				else
					hrp.CFrame = Config.SHOP_CFS.PC
				end
			end
		end)
	end
end)

-- ============================================================================
-- 🗺️ LOCATION & BOUNDARY UTILITIES
-- ============================================================================
local Location = {}
function Location.RefreshCafePosition()
	local player = Players.LocalPlayer
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local bases = workspace:FindFirstChild("Bases")

	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			if base:GetAttribute("OwnerUserId") == player.UserId then
				if base:IsA("Model") then State.MyCafePos = base:GetPivot().Position return
				elseif base:IsA("BasePart") then State.MyCafePos = base.Position return end
			end
		end
	end

	if hrp then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				local n, o = obj.Name:lower(), obj.ObjectText:lower()
				if (n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server")) then
					local part = obj.Parent
					if part and part:IsA("BasePart") and (hrp.Position - part.Position).Magnitude < 150 then
						State.MyCafePos = part.Position return
					end
				end
			end
		end
		State.MyCafePos = hrp.Position
	end
end

function Location.IsInsideBase(targetPos)
	Location.RefreshCafePosition()
	if not State.MyCafePos or not targetPos then return false end
	return Vector2.new(targetPos.X - State.MyCafePos.X, targetPos.Z - State.MyCafePos.Z).Magnitude <= Config.BASE_RADIUS
end

function Location.TeleportAndStabilize(targetPos, offsetCF)
	local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
	if not hrp or not humanoid then return false end

	hrp.CFrame = CFrame.new(targetPos) * offsetCF
	task.wait(0.4)
	if humanoid then humanoid.Sit = false end
	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
	task.wait(0.4)
	
	local lastPos = hrp.Position
	task.wait(0.2)
	if (hrp.Position - lastPos).Magnitude > 1 then task.wait(0.3) end
	return true
end

-- ============================================================================
-- 🎯 PROMPT & TOOL UTILITIES
-- ============================================================================
local Tools, Prompt = {}, {}
function Tools.FindAndEquip(toolKeywords)
	local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return nil end
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local toolName = tool.Name:lower()
			for _, keyword in ipairs(toolKeywords) do
				if toolName:find(keyword, 1, true) then return tool end
			end
		end
	end
	return nil
end

function Tools.WaitForEquip(tool, timeout)
	local char = Players.LocalPlayer.Character
	for _ = 1, (timeout or Config.EQUIP_TIMEOUT) do
		if tool.Parent == char then return true end
		task.wait(0.1)
	end
	return false
end

function Tools.ActivateTool(tool)
	if not tool or tool.Parent ~= Players.LocalPlayer.Character then return false end
	pcall(function() tool:Activate() end)
	return true
end

function Prompt.Fire(proximityPrompt, holdDuration)
	if not proximityPrompt or not proximityPrompt:IsA("ProximityPrompt") then return end
	pcall(function()
		local oldDist, oldLOS = proximityPrompt.MaxActivationDistance, proximityPrompt.RequiresLineOfSight
		proximityPrompt.MaxActivationDistance = Config.ACTIVATION_DISTANCE
		proximityPrompt.RequiresLineOfSight = false

		if fireproximityprompt then pcall(function() fireproximityprompt(proximityPrompt) end) task.wait(0.1) end
		if holdDuration and proximityPrompt.InputHoldBegin then
			proximityPrompt:InputHoldBegin() task.wait(holdDuration) proximityPrompt:InputHoldEnd()
		end

		proximityPrompt.MaxActivationDistance, proximityPrompt.RequiresLineOfSight = oldDist, oldLOS
	end)
end

-- ============================================================================
-- 💳 SECURE SHOPPING SYSTEM
-- ============================================================================
local Shopping = {}
function Shopping.SecureBuy(shopId, itemsToBuy)
	task.spawn(function()
		if State.IsShopping then return end
		State.IsShopping = true

		local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local returnCF = hrp and hrp.CFrame or nil

		if hrp then
			hrp.CFrame = (shopId == "Grocery") and Config.SHOP_CFS.GROCERY or Config.SHOP_CFS.PC
			task.wait(1.5)
		end

		for _, item in ipairs(itemsToBuy) do
			local purchased = false
			for attempt = 1, Config.SNIPER.MAX_RETRIES do
				if purchased then break end
				local stockData = nil
				pcall(function() stockData = Modules.StockService:GetAll(shopId) end)
				local currentStock = (stockData and stockData[item.name]) or 0

				if type(currentStock) == "number" and currentStock > 0 then
					local buyAmount = (shopId == "PcParts") and 1 or math.min(currentStock, Config.SNIPER.MAX_BUY_AMOUNT)
					pcall(function() Remotes.ShopPurchase:FireServer(shopId, item.name, buyAmount) end)
					purchased = true
					task.wait(Config.SNIPER.STOCK_CHECK_DELAY)
				else
					task.wait(Config.SNIPER.RETRY_DELAY)
				end
			end
		end

		task.wait(Config.SNIPER.SHOP_RETURN_DELAY)
		if hrp and returnCF then hrp.CFrame = returnCF task.wait(0.2) end
		State.IsShopping = false
	end)
end

function Shopping.TriggerInstantSnipe(shopId, targetDict)
	task.spawn(function()
		pcall(function()
			if Modules.StockService and Remotes.ShopPurchase then
				local currentStock = Modules.StockService:GetAll(shopId)
				if type(currentStock) == "table" then
					local itemsToBuy = {}
					for itemName, quantity in pairs(currentStock) do
						if type(quantity) == "number" and quantity > 0 and targetDict[itemName] then
							table.insert(itemsToBuy, { name = itemName, qty = quantity })
						end
					end
					if #itemsToBuy > 0 then Shopping.SecureBuy(shopId, itemsToBuy) end
				end
			end
		end)
	end)
end

-- ============================================================================
-- 🌐 UI SYSTEM & DATA PROCESSING
-- ============================================================================
local UISystem = {}
local GUI_References = { ToggleButtons = {} }

function UISystem.CreateLoginScreen()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild(Config.GUI_NAME) then playerGui[Config.GUI_NAME]:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = Config.GUI_NAME
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local loginFrame = Instance.new("Frame")
	loginFrame.Size = UDim2.new(0, 350, 0, 180)
	loginFrame.Position = UDim2.new(0.5, -175, 0.5, -90)
	loginFrame.BackgroundColor3 = Config.UI_THEME.BG_DARK
	loginFrame.Parent = gui
	Instance.new("UICorner", loginFrame).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", loginFrame).Color = Config.UI_THEME.BORDER

	local loginTitle = Instance.new("TextLabel")
	loginTitle.Size = UDim2.new(1, 0, 0, 40)
	loginTitle.BackgroundTransparency = 1
	loginTitle.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	loginTitle.Text = "LABA BABY HUB - LOGIN"
	loginTitle.Font = Enum.Font.GothamBlack
	loginTitle.TextSize = 16
	loginTitle.Parent = loginFrame

	local webhookInput = Instance.new("TextBox")
	webhookInput.Size = UDim2.new(0.9, 0, 0, 35)
	webhookInput.Position = UDim2.new(0.05, 0, 0, 70)
	webhookInput.BackgroundColor3 = Config.UI_THEME.BG_DARKER
	webhookInput.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
	webhookInput.Text = ""
	webhookInput.Font = Enum.Font.Gotham
	webhookInput.TextSize = 11
	webhookInput.Parent = loginFrame
	Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 4)

	local launchBtn = Instance.new("TextButton")
	launchBtn.Size = UDim2.new(0.6, 0, 0, 40)
	launchBtn.Position = UDim2.new(0.05, 0, 0, 120)
	launchBtn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN
	launchBtn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	launchBtn.Text = "🚀 LAUNCH HUB"
	launchBtn.Font = Enum.Font.GothamBold
	launchBtn.TextSize = 14
	launchBtn.Parent = loginFrame
	Instance.new("UICorner", launchBtn).CornerRadius = UDim.new(0, 6)

	local skipBtn = Instance.new("TextButton")
	skipBtn.Size = UDim2.new(0.25, 0, 0, 40)
	skipBtn.Position = UDim2.new(0.7, 0, 0, 120)
	skipBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
	skipBtn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	skipBtn.Text = "SKIP"
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.TextSize = 14
	skipBtn.Parent = loginFrame
	Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 6)

	launchBtn.MouseButton1Click:Connect(function()
		if webhookInput.Text ~= "" then
			State.CurrentWebhook = webhookInput.Text
			loginFrame:Destroy()
			UISystem.CreateMainHub(gui)
			Webhook.User({ username = "Laba Baby Hub", embeds = {{ title = "HUB CONNECTED", description = "Laba Baby Hub is Online.", color = 3447003}}})
		else
			launchBtn.Text = "❌ INVALID" launchBtn.BackgroundColor3 = Config.UI_THEME.ACCENT_RED
			task.wait(1.5) launchBtn.Text = "🚀 LAUNCH HUB" launchBtn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN
		end
	end)

	skipBtn.MouseButton1Click:Connect(function()
		State.CurrentWebhook = ""
		loginFrame:Destroy()
		UISystem.CreateMainHub(gui)
	end)
end

function UISystem.CreateMainHub(gui)
	-- ================================================================
	-- 🗃️ DATA PROCESSING 
	-- ================================================================
	local guiItemsPC = {}
	local guiItemsGrocery = {}
	local uniqueCats = { ["CPU"] = true, ["Mousepad"] = true }
	
	local knownMousepads = {
		["Nocturne"]=true, ["Revv"]=true, ["Shadow"]=true, ["Horizon"]=true, ["Fuji"]=true,
		["Petal"]=true, ["Sora"]=true, ["Evergreen"]=true, ["Konoha"]=true, ["Kasumi"]=true,
		["Wavy"]=true, ["Hanami"]=true, ["Midnight"]=true, ["Azure"]=true, ["Ripple"]=true,
		["Hoshi"]=true, ["Japan"]=true, ["Nimbus"]=true, ["Slate"]=true, ["Collage"]=true
	}
	local knownCPUs = {
		["Snowdrift"]=true, ["PinkDrift"]=true, ["Dark Nexus"]=true, ["Sakura"]=true,
		["Polar X"]=true, ["Voltara"]=true, ["Hexora"]=true, ["Vesta"]=true,
		["Trifan-Core"]=true, ["Trifan-Lite"]=true, ["Flat Core"]=true, ["Pulse Core"]=true, ["Classic Core"]=true
	}

	if Modules.ShopConfig and type(Modules.ShopConfig.Items) == "table" then
		for itemName, itemData in pairs(Modules.ShopConfig.Items) do
			local cat = itemData.Category or "Other"
			if knownMousepads[itemName] then cat = "Mousepad" elseif knownCPUs[itemName] then cat = "CPU" end
			
			local itemEntry = { name = tostring(itemName), category = cat, stars = tonumber(itemData.Stars) or 0, price = tonumber(itemData.Price) or 0 }
			if cat == "Grocery" then table.insert(guiItemsGrocery, itemEntry)
			else uniqueCats[cat] = true table.insert(guiItemsPC, itemEntry) end
		end
	end

	-- ✅ FIXED SORTING FUNCTION (No more silent errors!)
	local function sortItems(a, b)
		if a.stars ~= b.stars then 
			return a.stars > b.stars
		else 
			return a.price > b.price 
		end
	end
	table.sort(guiItemsPC, sortItems)
	table.sort(guiItemsGrocery, sortItems)

	-- ================================================================
	-- 🎨 UI GENERATION
	-- ================================================================
	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(0, 130, 0, 40) openBtn.Position = UDim2.new(0, 10, 0, 10)
	openBtn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT openBtn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	openBtn.Text = "🎯 Open Menu" openBtn.Font = Enum.Font.GothamBold openBtn.TextSize = 14
	openBtn.Visible = true -- ✅ LALABAS AGAD ANG OPEN MENU
	openBtn.Parent = gui 
	Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 480, 0, 380) mainFrame.Position = UDim2.new(0.5, -240, 0.5, -190)
	mainFrame.BackgroundColor3 = Config.UI_THEME.BG_DARK mainFrame.Draggable = true 
	mainFrame.Visible = false -- ✅ NAKATAGO MUNA ANG MAIN MENU (Katulad ng dati)
	mainFrame.Parent = gui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8) Instance.new("UIStroke", mainFrame).Color = Config.UI_THEME.BORDER

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30) closeBtn.Position = UDim2.new(1, -35, 0, 5)
	closeBtn.BackgroundTransparency = 1 closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "X" closeBtn.Font = Enum.Font.GothamBold closeBtn.TextSize = 16
	closeBtn.ZIndex = 10 closeBtn.Parent = mainFrame

	openBtn.MouseButton1Click:Connect(function() mainFrame.Visible = true openBtn.Visible = false end)
	closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false openBtn.Visible = true end)

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 140, 1, 0) sidebar.BackgroundColor3 = Config.UI_THEME.BG_DARKER sidebar.Parent = mainFrame
	Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40) title.BackgroundTransparency = 1
	title.TextColor3 = Config.UI_THEME.TEXT_PRIMARY title.Text = "LABA BABY HUB" title.Font = Enum.Font.GothamBlack title.TextSize = 14 title.Parent = sidebar

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -140, 1, 0) contentFrame.Position = UDim2.new(0, 140, 0, 0)
	contentFrame.BackgroundTransparency = 1 contentFrame.Parent = mainFrame

	local tabs, tabButtons = {}, {}
	local function createTab(name, icon, order)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 35) btn.Position = UDim2.new(0, 5, 0, 40 + (order * 40))
		btn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT btn.TextColor3 = Config.UI_THEME.TEXT_SECONDARY
		btn.Text = " " .. icon .. " " .. name btn.TextXAlignment = Enum.TextXAlignment.Left btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0) frame.BackgroundTransparency = 1 frame.Visible = false frame.Parent = contentFrame

		tabs[name] = frame tabButtons[name] = btn
		btn.MouseButton1Click:Connect(function()
			for tName, tFrame in pairs(tabs) do
				tFrame.Visible = (tName == name)
				tabButtons[tName].BackgroundColor3 = (tName == name) and Color3.fromRGB(50, 50, 60) or Config.UI_THEME.BG_LIGHT
				tabButtons[tName].TextColor3 = (tName == name) and Config.UI_THEME.TEXT_PRIMARY or Config.UI_THEME.TEXT_SECONDARY
			end
		end)
		return frame
	end

	local homeTab = createTab("Home", "🏠", 0)
	local pcTab = createTab("PC Parts", "💻", 1)
	local groceryTab = createTab("Grocery", "🍎", 2)
	tabs["Home"].Visible = true tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60) tabButtons["Home"].TextColor3 = Config.UI_THEME.TEXT_PRIMARY

	-- ========================================== HOME TAB ==========================================
	local function createToggle(text, pos, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.85, 0, 0, 35) btn.Position = pos
		btn.BackgroundColor3 = Config.UI_THEME.ACCENT_RED btn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
		btn.Text = text .. ": OFF" btn.Font = Enum.Font.GothamBlack btn.TextSize = 13 btn.Parent = homeTab
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	local tPC = createToggle("💻 PC AUTO-BUY", UDim2.new(0.075, 0, 0.05, 0), function()
		State.MasterPC = not State.MasterPC
		GUI_References.ToggleButtons.PC.BackgroundColor3 = State.MasterPC and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.PC.Text = "💻 PC AUTO-BUY: " .. (State.MasterPC and "ACTIVE" or "OFF")
		if State.MasterPC then Shopping.TriggerInstantSnipe("PcParts", State.TargetItemsPC) end
	end)
	GUI_References.ToggleButtons.PC = tPC

	local tGroc = createToggle("🍎 GROCERY AUTO-BUY", UDim2.new(0.075, 0, 0.20, 0), function()
		State.MasterGrocery = not State.MasterGrocery
		GUI_References.ToggleButtons.Groc.BackgroundColor3 = State.MasterGrocery and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.Groc.Text = "🍎 GROCERY AUTO-BUY: " .. (State.MasterGrocery and "ACTIVE" or "OFF")
		if State.MasterGrocery then Shopping.TriggerInstantSnipe("Grocery", State.TargetItemsGrocery) end
	end)
	GUI_References.ToggleButtons.Groc = tGroc

	local tApp = createToggle("🧑‍💻 AUTO APPOINT", UDim2.new(0.075, 0, 0.35, 0), function()
		State.AutoAppoint = not State.AutoAppoint
		GUI_References.ToggleButtons.App.BackgroundColor3 = State.AutoAppoint and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.App.Text = "🧑‍💻 AUTO APPOINT: " .. (State.AutoAppoint and "ACTIVE" or "OFF")
	end)
	GUI_References.ToggleButtons.App = tApp

	local tChef = createToggle("🍳 AUTO CHEF", UDim2.new(0.075, 0, 0.50, 0), function()
		State.AutoChef = not State.AutoChef
		GUI_References.ToggleButtons.Chef.BackgroundColor3 = State.AutoChef and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.Chef.Text = "🍳 AUTO CHEF: " .. (State.AutoChef and "ACTIVE" or "OFF")
	end)
	GUI_References.ToggleButtons.Chef = tChef

	local tExt = createToggle("🧯 AUTO EXTINGUISH", UDim2.new(0.075, 0, 0.65, 0), function()
		State.AutoExtinguish = not State.AutoExtinguish
		GUI_References.ToggleButtons.Ext.BackgroundColor3 = State.AutoExtinguish and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.Ext.Text = "🧯 AUTO EXTINGUISH: " .. (State.AutoExtinguish and "ACTIVE" or "OFF")
	end)
	GUI_References.ToggleButtons.Ext = tExt

	local tCln = createToggle("🧹 AUTO CLEAN (NIGHT)", UDim2.new(0.075, 0, 0.80, 0), function()
		State.AutoClean = not State.AutoClean
		GUI_References.ToggleButtons.Cln.BackgroundColor3 = State.AutoClean and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.ACCENT_RED
		GUI_References.ToggleButtons.Cln.Text = "🧹 AUTO CLEAN (NIGHT): " .. (State.AutoClean and "ACTIVE" or "OFF")
	end)
	GUI_References.ToggleButtons.Cln = tCln

	local statusText = Instance.new("TextLabel")
	statusText.Size = UDim2.new(1, 0, 0, 30) statusText.Position = UDim2.new(0, 0, 0.91, 0)
	statusText.BackgroundTransparency = 1 statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusText.Text = "Status: 🛡️ Anti-AFK & Anti-Death Active | 📡 Waiting for Server..."
	statusText.Font = Enum.Font.GothamSemibold statusText.TextSize = 12 statusText.Parent = homeTab
	GUI_References.StatusText = statusText

	-- ========================================== PC TAB ==========================================
	local pcDropdownBtn = Instance.new("TextButton")
	pcDropdownBtn.Size = UDim2.new(0.9, 0, 0, 30) pcDropdownBtn.Position = UDim2.new(0.05, 0, 0, 10)
	pcDropdownBtn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT pcDropdownBtn.TextColor3 = Config.UI_THEME.TEXT_SECONDARY
	pcDropdownBtn.Text = "Category: ALL ▼" pcDropdownBtn.Font = Enum.Font.GothamSemibold pcDropdownBtn.TextSize = 12 pcDropdownBtn.Parent = pcTab
	Instance.new("UICorner", pcDropdownBtn).CornerRadius = UDim.new(0, 4)

	local pcScroll = Instance.new("ScrollingFrame")
	pcScroll.Size = UDim2.new(0.9, 0, 1, -55) pcScroll.Position = UDim2.new(0.05, 0, 0, 45)
	pcScroll.BackgroundTransparency = 1 pcScroll.ScrollBarThickness = 4 pcScroll.Parent = pcTab
	local pcLayout = Instance.new("UIListLayout", pcScroll) pcLayout.Padding = UDim.new(0, 4)

	local pcDropdownFrame = Instance.new("ScrollingFrame")
	pcDropdownFrame.Size = UDim2.new(0.9, 0, 0, 150) pcDropdownFrame.Position = UDim2.new(0.05, 0, 0, 45)
	pcDropdownFrame.BackgroundColor3 = Config.UI_THEME.BG_DARKER pcDropdownFrame.ScrollBarThickness = 4
	pcDropdownFrame.ZIndex = 10 pcDropdownFrame.Visible = false pcDropdownFrame.Parent = pcTab
	Instance.new("UICorner", pcDropdownFrame)
	local pcDropLayout = Instance.new("UIListLayout", pcDropdownFrame)

	local currentPCFilter = "All"

	local function refreshPCList()
		for _, child in ipairs(pcScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		for _, item in ipairs(guiItemsPC) do
			if currentPCFilter == "All" or item.category == currentPCFilter then
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 30)
				btn.BackgroundColor3 = State.TargetItemsPC[item.name] and Config.UI_THEME.ACCENT_GREEN or Config.UI_THEME.BG_LIGHT
				local starDisplay = string.rep("⭐", item.stars)
				btn.Text = (State.TargetItemsPC[item.name] and " ☑ " or " ☐ ") .. item.name .. " " .. starDisplay
				btn.TextXAlignment = Enum.TextXAlignment.Left btn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
				btn.Font = Enum.Font.GothamMedium btn.TextSize = 12 btn.Parent = pcScroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					if State.TargetItemsPC[item.name] then
						State.TargetItemsPC[item.name] = nil
						btn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT btn.Text = " ☐ " .. item.name .. " " .. starDisplay
					else
						State.TargetItemsPC[item.name] = true
						btn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN btn.Text = " ☑ " .. item.name .. " " .. starDisplay
						if State.MasterPC then Shopping.TriggerInstantSnipe("PcParts", {[item.name] = true}) end
					end
				end)
			end
		end
		task.wait(0.1) pcScroll.CanvasSize = UDim2.new(0, 0, 0, pcLayout.AbsoluteContentSize.Y + 10)
	end

	local sortedCategoryList, tempCatList = {"All"}, {}
	for c, _ in pairs(uniqueCats) do table.insert(tempCatList, c) end
	table.sort(tempCatList)
	for _, c in ipairs(tempCatList) do table.insert(sortedCategoryList, c) end

	for _, cat in ipairs(sortedCategoryList) do
		local choiceBtn = Instance.new("TextButton")
		choiceBtn.Size = UDim2.new(1, 0, 0, 30) choiceBtn.BackgroundColor3 = Config.UI_THEME.BG_DARK
		choiceBtn.TextColor3 = Config.UI_THEME.TEXT_SECONDARY choiceBtn.Text = cat choiceBtn.Font = Enum.Font.GothamMedium
		choiceBtn.TextSize = 12 choiceBtn.ZIndex = 11 choiceBtn.Parent = pcDropdownFrame
		choiceBtn.MouseButton1Click:Connect(function()
			currentPCFilter = cat pcDropdownBtn.Text = "Category: " .. string.upper(cat) .. " ▼"
			pcDropdownFrame.Visible = false refreshPCList()
		end)
	end
	task.spawn(function() task.wait(0.2) pcDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, pcDropLayout.AbsoluteContentSize.Y) end)
	pcDropdownBtn.MouseButton1Click:Connect(function() pcDropdownFrame.Visible = not pcDropdownFrame.Visible end)
	refreshPCList()

	-- ========================================== GROCERY TAB ==========================================
	local groceryHeader = Instance.new("TextLabel")
	groceryHeader.Size = UDim2.new(0.9, 0, 0, 30) groceryHeader.Position = UDim2.new(0.05, 0, 0, 10)
	groceryHeader.BackgroundTransparency = 1 groceryHeader.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	groceryHeader.Text = "Grocery & Food Selector" groceryHeader.Font = Enum.Font.GothamBold groceryHeader.TextSize = 14 groceryHeader.Parent = groceryTab

	local grocScroll = Instance.new("ScrollingFrame")
	grocScroll.Size = UDim2.new(0.9, 0, 1, -55) grocScroll.Position = UDim2.new(0.05, 0, 0, 45)
	grocScroll.BackgroundTransparency = 1 grocScroll.ScrollBarThickness = 4 grocScroll.Parent = groceryTab
	local grocLayout = Instance.new("UIListLayout", grocScroll) grocLayout.Padding = UDim.new(0, 4)

	for _, item in ipairs(guiItemsGrocery) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 30) btn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT
		btn.Text = " ☐ " .. item.name btn.TextXAlignment = Enum.TextXAlignment.Left btn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
		btn.Font = Enum.Font.GothamMedium btn.TextSize = 12 btn.Parent = grocScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			if State.TargetItemsGrocery[item.name] then
				State.TargetItemsGrocery[item.name] = nil
				btn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT btn.Text = " ☐ " .. item.name
			else
				State.TargetItemsGrocery[item.name] = true
				btn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN btn.Text = " ☑ " .. item.name
				if State.MasterGrocery then Shopping.TriggerInstantSnipe("Grocery", {[item.name] = true}) end
			end
		end)
	end
	task.spawn(function() task.wait(0.2) grocScroll.CanvasSize = UDim2.new(0, 0, 0, grocLayout.AbsoluteContentSize.Y + 10) end)
end
UISystem.CreateLoginScreen()

-- ============================================================================
-- 🔥 AUTO EXTINGUISH LOOP
-- ============================================================================
task.spawn(function()
	while true do
		task.wait(1.5)
		if not State.AutoExtinguish or State.IsShopping or State.IsBusy then continue end
		pcall(function()
			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
			if not hrp or not humanoid or humanoid.Health <= 0 then return end

			local fireFound, firePart = nil, nil
			for _, obj in ipairs(workspace:GetDescendants()) do
				local name = obj.Name:lower()
				if obj:IsA("ProximityPrompt") and (name:match("extinguish") or obj.ActionText:lower():match("extinguish")) then
					if obj.Parent and Location.IsInsideBase(obj.Parent.Position) then
						fireFound, firePart = obj, obj.Parent break
					end
				elseif (obj:IsA("ParticleEmitter") or obj:IsA("Fire")) and name:match("fire") then
					local part = obj.Parent
					if part and part:IsA("BasePart") and Location.IsInsideBase(part.Position) then
						fireFound, firePart = obj, part break
					end
				end
			end

			if not fireFound or not firePart then return end
			State.IsBusy = true humanoid:UnequipTools() task.wait(0.3)
			Location.TeleportAndStabilize(firePart.Position, Config.TELEPORT_OFFSETS.FIRE)
			
			local extTool = Tools.FindAndEquip(Config.TOOLS.FIRE)
			if extTool then
				humanoid:EquipTool(extTool)
				if Tools.WaitForEquip(extTool) then
					task.wait(0.2)
					for i = 1, 10 do
						Tools.ActivateTool(extTool) VirtualUser:ClickButton1(Vector2.new())
						if fireFound:IsA("ProximityPrompt") then Prompt.Fire(fireFound, Config.PROMPT_HOLD_DURATION) end
						task.wait(0.5)
					end
					task.wait(1.5)
				end
			end
			humanoid:UnequipTools() State.IsBusy = false
		end)
	end
end)

-- ============================================================================
-- 🧹 AUTO CLEAN LOOP
-- ============================================================================
task.spawn(function()
	while true do
		task.wait(1.5)
		if not State.AutoClean or State.IsShopping or State.IsBusy then continue end
		pcall(function()
			local cTime = Lighting.ClockTime
			if not (cTime >= 18 or cTime <= 6) then return end

			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
			if not hrp or not humanoid or humanoid.Health <= 0 then return end

			local messFound, messPos, messType = nil, nil, nil
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then
					local a, o = obj.ActionText:lower(), obj.ObjectText:lower()
					if a:match("clean") and (o:match("mess") or o:match("glass") or o:match("spill") or o:match("trash")) then
						if obj.Parent and Location.IsInsideBase(obj.Parent.Position) then
							messFound, messPos = obj, obj.Parent.Position
							messType = (o:match("glass") or o:match("window")) and "glass" or "mess"
							break
						end
					end
				end
			end

			if not messFound or not messPos then return end
			State.IsBusy = true humanoid:UnequipTools() task.wait(0.3)
			Location.TeleportAndStabilize(messPos, Config.TELEPORT_OFFSETS.MESS)
			
			local toolKw = (messType == "glass") and Config.TOOLS.GLASS or Config.TOOLS.MESS
			local tool = Tools.FindAndEquip(toolKw)
			
			if tool then
				humanoid:EquipTool(tool)
				if Tools.WaitForEquip(tool, Config.EQUIP_TIMEOUT) then
					task.wait(0.2) Prompt.Fire(messFound, Config.PROMPT_HOLD_DURATION) task.wait(0.3)
					for i = 1, 5 do Tools.ActivateTool(tool) VirtualUser:ClickButton1(Vector2.new()) task.wait(0.4) end
					task.wait(1.5)
				end
			end
			humanoid:UnequipTools() State.IsBusy = false
		end)
	end
end)

-- ============================================================================
-- 👔 AUTO APPOINT LOOP
-- ============================================================================
task.spawn(function()
	while true do
		task.wait(1.5)
		if not State.AutoAppoint or State.IsShopping or State.IsBusy then continue end
		pcall(function()
			local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local mainUi = Players.LocalPlayer.PlayerGui:FindFirstChild("MainUi")
			if not hrp or not mainUi then return end

			local sf = mainUi:FindFirstChild("ServerFrame")
			if not sf or sf.Visible then return end

			local closestPrompt = State.MyHomeLaptop
			if not closestPrompt or not closestPrompt.Parent then
				local sDist = math.huge
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") then
						local n, o = obj.Name:lower(), obj.ObjectText:lower()
						if (n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server")) then
							local part = obj.Parent
							if part and part:IsA("BasePart") then
								local dist = (hrp.Position - part.Position).Magnitude
								if dist < sDist and dist < 150 and Location.IsInsideBase(part.Position) then
									sDist, closestPrompt = dist, obj
								end
							end
						end
					end
				end
				if closestPrompt then State.MyHomeLaptop, State.MyCafePos = closestPrompt, closestPrompt.Parent.Position end
			end

			local hasCust = false
			local npcInfo = sf:FindFirstChild("NpcInfo")
			if npcInfo and npcInfo.Visible then hasCust = true end

			if not hasCust and closestPrompt then
				local lPos = closestPrompt.Parent.Position
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
						local hum, root = obj:FindFirstChild("Humanoid"), obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
						if root and hum and not hum.Sit and (root.Position - lPos).Magnitude < 25 then
							hasCust = true break
						end
					end
				end
			end

			if closestPrompt and hasCust and not State.IsShopping then
				State.IsBusy = true
				Location.TeleportAndStabilize(closestPrompt.Parent.Position, Config.TELEPORT_OFFSETS.APPOINT)
				Prompt.Fire(closestPrompt) task.wait(1) State.IsBusy = false
			end

			if sf and sf.Visible and not State.IsShopping then
				local pcList = sf:FindFirstChild("PcList")
				if pcList then
					for _, pc in ipairs(pcList:GetChildren()) do
						if not State.AutoAppoint or State.IsShopping then break end
						if pc:IsA("Frame") and Remotes.SelectPC and Remotes.Appoint then
							Remotes.SelectPC:FireServer(pc.Name) task.wait(0.05) Remotes.Appoint:FireServer(pc.Name) task.wait(0.1)
						end
					end
				end
			end
		end)
	end
end)

-- ============================================================================
-- 👨‍🍳 AUTO CHEF LOOP
-- ============================================================================
task.spawn(function()
	while true do
		task.wait(1.5)
		if not State.AutoChef or State.IsShopping or State.IsBusy then continue end
		pcall(function()
			local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local mainUi = Players.LocalPlayer.PlayerGui:FindFirstChild("MainUi")
			if not mainUi or not hrp then return end

			local trayItems, trayList = {}, mainUi:FindFirstChild("Tray") and mainUi.Tray:FindFirstChild("ListFrame")
			if trayList then
				for _, v in ipairs(trayList:GetChildren()) do
					if v:IsA("Frame") and v:GetAttribute("TrayRuntimeCard") then table.insert(trayItems, v) end
				end
			end

			if #trayItems > 0 and not State.IsShopping then
				local eqItem = nil
				for _, i in ipairs(trayItems) do
					local stroke = i:FindFirstChildWhichIsA("UIStroke")
					if stroke and stroke.Thickness == 4 then eqItem = i break end
				end

				if not eqItem then
					local rawId = trayItems[1].Name:gsub("TrayOrder_", "")
					if Remotes.SelectTray then Remotes.SelectTray:FireServer(tonumber(rawId) or rawId) end
					task.wait(0.5) return
				end

				local pcLbl = eqItem:FindFirstChild("PcNumber")
				if pcLbl then
					local tgtNum = pcLbl.Text:match("%d+")
					if tgtNum then
						local foundPC, sDist, validPfx = nil, 400, {"pc", "desk", "table", "computer"}
						for _, obj in ipairs(workspace:GetDescendants()) do
							if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
								local rName = obj.Name:lower():gsub("%s+", ""):gsub("_", "")
								local isMatch = (rName == tgtNum)
								if not isMatch then for _, p in ipairs(validPfx) do if rName == p..tgtNum then isMatch = true break end end end
								if isMatch then
									local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetModelCFrame().Position) or obj.Position
									if pos and Location.IsInsideBase(pos) then
										local dist = (hrp.Position - pos).Magnitude
										if dist < sDist then sDist, foundPC = dist, obj end
									end
								end
							end
						end

						if foundPC and not State.IsShopping then
							State.IsBusy = true
							local pcPos = foundPC:IsA("Model") and (foundPC.PrimaryPart and foundPC.PrimaryPart.Position or foundPC:GetModelCFrame().Position) or foundPC.Position
							local tgtNPC, cDist = nil, 15
							for _, m in ipairs(workspace:GetDescendants()) do
								if m:IsA("Model") and m:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(m) then
									local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
									if root and (root.Position - pcPos).Magnitude < cDist then
										cDist, tgtNPC = (root.Position - pcPos).Magnitude, m
									end
								end
							end
							
							if tgtNPC then
								local r = tgtNPC:FindFirstChild("HumanoidRootPart") or tgtNPC.PrimaryPart
								local tPos = (r.CFrame * CFrame.new(0, 0, 3.5)).Position + Vector3.new(0, 2.5, 0)
								hrp.CFrame = CFrame.lookAt(tPos, r.Position)
							else
								Location.TeleportAndStabilize(pcPos, Config.TELEPORT_OFFSETS.CHEF)
							end
							task.wait(0.5)

							if fireproximityprompt then
								for _, prompt in ipairs(workspace:GetDescendants()) do
									if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") and (prompt.Parent.Position - hrp.Position).Magnitude < 15 then
										local a, o = prompt.ActionText:lower(), prompt.ObjectText:lower()
										if not a:match("sit") and not o:match("chair") and not o:match("seat") then Prompt.Fire(prompt) end
									end
								end
							end
							task.wait(1) State.IsBusy = false
						end
					end
				end
			end

			if #trayItems < 3 and not State.IsShopping then
				local cookMain = mainUi:FindFirstChild("Cooking")
				if cookMain then
					local prep = cookMain:FindFirstChild("PreparingFrame")
					if prep then
						for _, v in ipairs(prep:GetChildren()) do
							if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") then
								local btn = v:FindFirstChild("Button", true)
								if btn and btn.Text == "Deliver" and Remotes.Deliver then
									Remotes.Deliver:FireServer(tonumber(v.Name) or v.Name) task.wait(0.5) return
								end
							end
						end
					end
					
					local cookOrds = cookMain:FindFirstChild("OrdersFrame")
					if cookOrds then
						for _, v in ipairs(cookOrds:GetChildren()) do
							if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") and Remotes.Cook then
								local foodLbl = v:FindFirstChild("FoodName", true)
								if foodLbl then Remotes.Cook:FireServer(foodLbl.Text, tonumber(v.Name) or v.Name) task.wait(0.5) return end
							end
						end
					end
				end

				local snkOrds = mainUi:FindFirstChild("SnacksDeliver") and mainUi.SnacksDeliver:FindFirstChild("OrdersFrame")
				if snkOrds then
					for _, v in ipairs(snkOrds:GetChildren()) do
						if v:IsA("Frame") and v:GetAttribute("SnackRuntimeCard") and Remotes.Deliver then
							Remotes.Deliver:FireServer(tonumber(v.Name) or v.Name) task.wait(0.5) return
						end
					end
				end
			end
		end)
	end
end)

-- ============================================================================
-- 📦 RESTOCK TRACKER
-- ============================================================================
task.spawn(function()
	local stockSync = ReplicatedStorage:WaitForChild("StockServiceSync")
	stockSync.OnClientEvent:Connect(function(shopId, stockTable)
		if not State.CurrentWebhook or State.CurrentWebhook == "" then return end
		local pcToBuy, grocToBuy, mentionEveryone = {}, {}, false

		if GUI_References.StatusText then GUI_References.StatusText.Text = "Status: 🟢 Last Restock at " .. os.date("%H:%M:%S") end

		if type(stockTable) == "table" then
			for iName, qty in pairs(stockTable) do
				if type(qty) == "number" and qty > 0 then
					local itemData = (Modules.ShopConfig and Modules.ShopConfig.Items and Modules.ShopConfig.Items[iName]) or {}
					local isGroc = (itemData.Category or "Others") == "Grocery"
					
					if isGroc and State.TargetItemsGrocery[iName] and State.MasterGrocery then
						table.insert(grocToBuy, { name = iName, qty = qty })
					elseif not isGroc and State.TargetItemsPC[iName] and State.MasterPC then
						mentionEveryone = true table.insert(pcToBuy, { name = iName, qty = qty })
					end
				end
			end
		end

		if #grocToBuy > 0 then Shopping.SecureBuy("Grocery", grocToBuy) end
		if #pcToBuy > 0 then Shopping.SecureBuy("PcParts", pcToBuy) end

		local payload = {
			username = "Laba Baby Hub",
			embeds = {{
				title = "⏱️ Info", color = 3447003,
				description = string.format("🔴 **Next Restock:** <t:%d:R>\n⚙️ **PC:** %s | **Grocery:** %s", math.floor(os.time() + 3600), State.MasterPC and "🟢 ON" or "🔴 OFF", State.MasterGrocery and "🟢 ON" or "🔴 OFF"),
				footer = { text = "LABA BABY HUB" }, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
			}}
		}
		if mentionEveryone then payload.content = "@everyone 🚨 **TARGET ITEM DETECTED & SNIPED!**" end
		Webhook.User(payload)
	end)
end)

-- ============================================================================
-- ✅ INITIALIZATION COMPLETE
-- ============================================================================
print("✅ LABA BABY HUB v2.2 INITIALIZED - All systems ready")
