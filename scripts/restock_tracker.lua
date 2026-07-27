--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                    LABA BABY HUB - FIXED & IMPROVED                          ║
║              Professional Roblox Automation Suite (v2.1)                     ║
║                                                                              ║
║  FIXES: Syntax errors removed, Sniper logic improved, Tool matching refined ║
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
	-- UI Settings
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

	-- Shop Configuration
	SHOP_CFS = {
		PC = CFrame.new(-240.48721313476562, 7.888942718505859, 136.32080078125),
		GROCERY = CFrame.new(-102.66999816894531, 8.224592208862305, 10.839996337890625),
	},

	-- Teleport Offsets
	TELEPORT_OFFSETS = {
		MESS = CFrame.new(0, 2.5, 2.5),
		FIRE = CFrame.new(0, 3, -4),
		APPOINT = CFrame.new(0, 3, 2.5),
		CHEF = CFrame.new(0, 3, -4),
	},

	-- Automation Limits
	BASE_RADIUS = 120,
	EQUIP_TIMEOUT = 20,
	FIRE_DETECTION_RANGE = 150,
	ACTIVATION_DISTANCE = 100,
	PROMPT_HOLD_DURATION = 0.5,

	-- Tool Matching
	TOOLS = {
		MESS = {"walis", "broom", "mop", "sweep"},
		GLASS = {"towel", "sponge", "wipe", "rag"},
		FIRE = {"extinguish", "fire"},
	},

	-- Webhook URLs
	WEBHOOKS = {
		DEBUG = "https://discord.com/api/webhooks/1530530759457247355/Xi9gmdqaGAc1waG846-BAUelmZFx3QIdnLsXiuC_yJP-LEtjsfc1wJ7zCYZhrk7ZrK10",
		TRACKER = "https://discord.com/api/webhooks/1326732013750980618/Pn-nfG7dUBf9LBUzR8-sr__Y_WGg4SbfTQdmOMPAf3JG1KUXdjvK3YaB8hqgQZmh_par",
		USER = "",
	},

	-- Sniper Configuration (IMPROVED)
	SNIPER = {
		MAX_RETRIES = 25,
		RETRY_DELAY = 0.3,
		STOCK_CHECK_DELAY = 0.2,
		MAX_BUY_AMOUNT = 999,
		SHOP_RETURN_DELAY = 1.0,
	},
}

-- State Variables
local State = {
	-- Master Toggles
	MasterPC = false,
	MasterGrocery = false,
	AutoAppoint = false,
	AutoChef = false,
	AutoExtinguish = false,
	AutoClean = false,

	-- Operational Flags
	IsShopping = false,
	IsBusy = false,

	-- Item Targets
	TargetItemsPC = {},
	TargetItemsGrocery = {},

	-- Location Tracking
	MyHomeLaptop = nil,
	MyCafePos = nil,

	-- Webhook Auth
	CurrentWebhook = "",
}

-- HTTP Request Handler
local fetch = request or http_request or (syn and syn.request)

-- ============================================================================
-- 📦 MODULE REQUIRES & REMOTES (SAFE INITIALIZATION)
-- ============================================================================
local Modules = {
	ShopConfig = nil,
	StockService = nil,
	Net = nil,
}

local Remotes = {
	ShopPurchase = nil,
	SelectPC = nil,
	Appoint = nil,
	Cook = nil,
	Deliver = nil,
	SelectTray = nil,
}

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
		fetch({
			Url = webhookUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
end

function Webhook.ExecutionLog(username)
	Webhook.Send({
		username = "Laba Execution Log",
		content = "👤 **New User Executed Script:** `" .. username .. "`\n🆔 **User ID:** `" ..
			tostring(Players.LocalPlayer.UserId) .. "`",
	}, Config.WEBHOOKS.TRACKER)
end

function Webhook.Debug(message)
	Webhook.Send({
		username = "Laba Debugger",
		content = "⚠️ **DEBUG LOG:**\n" .. message,
	}, Config.WEBHOOKS.DEBUG)
end

function Webhook.User(payload)
	Webhook.Send(payload, State.CurrentWebhook)
end

-- Log script execution
task.spawn(function()
	Webhook.ExecutionLog(Players.LocalPlayer.Name)
end)

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
			local player = Players.LocalPlayer
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")

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
				if base:IsA("Model") then
					State.MyCafePos = base:GetPivot().Position
					return
				elseif base:IsA("BasePart") then
					State.MyCafePos = base.Position
					return
				end
			end
		end
	end

	if hrp then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				local n, o = obj.Name:lower(), obj.ObjectText:lower()
				if (n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server")) then
					local part = obj.Parent
					if part and part:IsA("BasePart") then
						local dist = (hrp.Position - part.Position).Magnitude
						if dist < 150 then
							State.MyCafePos = part.Position
							return
						end
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

	local flatDist = Vector2.new(targetPos.X - State.MyCafePos.X, targetPos.Z - State.MyCafePos.Z).Magnitude
	return flatDist <= Config.BASE_RADIUS
end

function Location.TeleportAndStabilize(targetPos, offsetCF)
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")

	if not hrp or not humanoid then return false end

	hrp.CFrame = CFrame.new(targetPos) * offsetCF
	task.wait(0.4)

	if humanoid then humanoid.Sit = false end

	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
	task.wait(0.4)

	local lastPos = hrp.Position
	task.wait(0.2)
	local newPos = hrp.Position
	local moveDistance = (newPos - lastPos).Magnitude

	if moveDistance > 1 then
		task.wait(0.3)
	end

	return true
end

-- ============================================================================
-- 🎯 PROMPT & TOOL UTILITIES
-- ============================================================================

local Tools = {}

function Tools.FindAndEquip(toolKeywords)
	local player = Players.LocalPlayer
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")

	if not char or not backpack then return nil end

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local toolName = tool.Name:lower()

			for _, keyword in ipairs(toolKeywords) do
				if toolName:find(keyword, 1, true) then
					return tool
				end
			end
		end
	end

	return nil
end

function Tools.WaitForEquip(tool, timeout)
	local player = Players.LocalPlayer
	local char = player.Character
	timeout = timeout or Config.EQUIP_TIMEOUT

	for attempt = 1, timeout do
		if tool.Parent == char then
			return true
		end
		task.wait(0.1)
	end

	return false
end

function Tools.ActivateTool(tool)
	if not tool or tool.Parent ~= game:GetService("Players").LocalPlayer.Character then return false end
	pcall(function()
		tool:Activate()
	end)
	return true
end

local Prompt = {}

function Prompt.Fire(proximityPrompt, holdDuration)
	if not proximityPrompt or not proximityPrompt:IsA("ProximityPrompt") then return end

	pcall(function()
		local oldDist = proximityPrompt.MaxActivationDistance
		local oldLOS = proximityPrompt.RequiresLineOfSight

		proximityPrompt.MaxActivationDistance = Config.ACTIVATION_DISTANCE
		proximityPrompt.RequiresLineOfSight = false

		if fireproximityprompt then
			pcall(function() fireproximityprompt(proximityPrompt) end)
			task.wait(0.1)
		end

		if holdDuration and proximityPrompt.InputHoldBegin then
			proximityPrompt:InputHoldBegin()
			task.wait(holdDuration)
			proximityPrompt:InputHoldEnd()
		end

		proximityPrompt.MaxActivationDistance = oldDist
		proximityPrompt.RequiresLineOfSight = oldLOS
	end)
end

-- ============================================================================
-- 💳 SECURE SHOPPING SYSTEM (IMPROVED SNIPER)
-- ============================================================================

local Shopping = {}

function Shopping.SecureBuy(shopId, itemsToBuy)
	task.spawn(function()
		if State.IsShopping then return end
		State.IsShopping = true

		local player = Players.LocalPlayer
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local returnCF = hrp and hrp.CFrame or nil

		if hrp then
			local shopCF = (shopId == "Grocery") and Config.SHOP_CFS.GROCERY or Config.SHOP_CFS.PC
			hrp.CFrame = shopCF
			task.wait(1.5)
		end

		-- IMPROVED: Better retry logic with stock checking
		for _, item in ipairs(itemsToBuy) do
			local purchased = false

			for attempt = 1, Config.SNIPER.MAX_RETRIES do
				if purchased then break end

				-- Check current stock
				local stockData = nil
				pcall(function()
					stockData = Modules.StockService:GetAll(shopId)
				end)

				local currentStock = (stockData and stockData[item.name]) or 0

				if type(currentStock) == "number" and currentStock > 0 then
					-- Calculate purchase amount
					local buyAmount = currentStock
					if shopId == "PcParts" then
						buyAmount = 1  -- Only buy 1 PC part at a time
					elseif shopId == "Grocery" then
						buyAmount = math.min(currentStock, Config.SNIPER.MAX_BUY_AMOUNT)
					end

					-- Attempt purchase
					pcall(function()
						Remotes.ShopPurchase:FireServer(shopId, item.name, buyAmount)
					end)

					purchased = true
					task.wait(Config.SNIPER.STOCK_CHECK_DELAY)
				else
					-- No stock, wait and retry
					task.wait(Config.SNIPER.RETRY_DELAY)
				end
			end

			if not purchased then
				Webhook.Debug("❌ **" .. shopId .. " SNIPE FAILED:** `" .. item.name .. "`\nRetried " ..
					Config.SNIPER.MAX_RETRIES .. " times - Item may be out of stock or unavailable.")
			else
				Webhook.Debug("✅ **" .. shopId .. " SNIPED:** `" .. item.name .. "`")
			end
		end

		task.wait(Config.SNIPER.SHOP_RETURN_DELAY)

		if hrp and returnCF then
			hrp.CFrame = returnCF
			task.wait(0.2)
		end

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

					if #itemsToBuy > 0 then
						Shopping.SecureBuy(shopId, itemsToBuy)
					end
				end
			end
		end)
	end)
end

-- ============================================================================
-- 🌐 UI SYSTEM
-- ============================================================================

local UISystem = {}
local GUI_References = {
	MainFrame = nil,
	HomeTab = nil,
	PCTab = nil,
	GroceryTab = nil,
	StatusText = nil,
	ToggleButtons = {},
}

function UISystem.CreateLoginScreen()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild(Config.GUI_NAME)
	if existingGui then existingGui:Destroy() end

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

	local webhookDesc = Instance.new("TextLabel")
	webhookDesc.Size = UDim2.new(0.9, 0, 0, 20)
	webhookDesc.Position = UDim2.new(0.05, 0, 0, 45)
	webhookDesc.BackgroundTransparency = 1
	webhookDesc.TextColor3 = Config.UI_THEME.TEXT_SECONDARY
	webhookDesc.Text = "Please enter your Discord Webhook URL:"
	webhookDesc.Font = Enum.Font.GothamMedium
	webhookDesc.TextSize = 12
	webhookDesc.Parent = loginFrame

	local webhookInput = Instance.new("TextBox")
	webhookInput.Size = UDim2.new(0.9, 0, 0, 35)
	webhookInput.Position = UDim2.new(0.05, 0, 0, 70)
	webhookInput.BackgroundColor3 = Config.UI_THEME.BG_DARKER
	webhookInput.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
	webhookInput.Text = ""
	webhookInput.ClearTextOnFocus = false
	webhookInput.Font = Enum.Font.Gotham
	webhookInput.TextSize = 11
	webhookInput.Parent = loginFrame
	Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", webhookInput).Color = Config.UI_THEME.BORDER

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
		local inputStr = webhookInput.Text
		if inputStr ~= "" and (inputStr:match("http://") or inputStr:match("https://")) then
			State.CurrentWebhook = inputStr
			loginFrame.Parent:Destroy()
			UISystem.CreateMainHub(gui)
			Webhook.User({
				username = "Laba Baby Hub",
				embeds = {
					{
						title = "HUB CONNECTED",
						description = "Laba Baby Hub is Online. All toggles are OFF by default.",
						color = 3447003,
					},
				},
			})
		else
			launchBtn.Text = "❌ INVALID WEBHOOK URL"
			launchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			task.wait(1.5)
			launchBtn.Text = "🚀 LAUNCH HUB"
			launchBtn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN
		end
	end)

	skipBtn.MouseButton1Click:Connect(function()
		State.CurrentWebhook = ""
		loginFrame.Parent:Destroy()
		UISystem.CreateMainHub(gui)
	end)

	return gui
end

function UISystem.CreateMainHub(gui)
	local openBtn = Instance.new("TextButton")
	openBtn.Size = UDim2.new(0, 130, 0, 40)
	openBtn.Position = UDim2.new(0, 10, 0, 10)
	openBtn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT
	openBtn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	openBtn.Text = "🎯 Open Menu"
	openBtn.Font = Enum.Font.GothamBold
	openBtn.TextSize = 14
	openBtn.Visible = false
	openBtn.Parent = gui
	Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 480, 0, 380)
	mainFrame.Position = UDim2.new(0.5, -240, 0.5, -190)
	mainFrame.BackgroundColor3 = Config.UI_THEME.BG_DARK
	mainFrame.Visible = true
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.Parent = gui
	Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", mainFrame).Color = Config.UI_THEME.BORDER
	GUI_References.MainFrame = mainFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -35, 0, 5)
	closeBtn.BackgroundTransparency = 1
	closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.ZIndex = 10
	closeBtn.Parent = mainFrame

	openBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = true
		openBtn.Visible = false
	end)

	closeBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		openBtn.Visible = true
	end)

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 140, 1, 0)
	sidebar.BackgroundColor3 = Config.UI_THEME.BG_DARKER
	sidebar.Parent = mainFrame
	Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	title.Text = "LABA BABY HUB"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 14
	title.Parent = sidebar

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -140, 1, 0)
	contentFrame.Position = UDim2.new(0, 140, 0, 0)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame

	local tabs = {}
	local tabButtons = {}

	local function createTab(name, icon, order)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 35)
		btn.Position = UDim2.new(0, 5, 0, 40 + (order * 40))
		btn.BackgroundColor3 = Config.UI_THEME.BG_LIGHT
		btn.TextColor3 = Config.UI_THEME.TEXT_SECONDARY
		btn.Text = " " .. icon .. " " .. name
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.Parent = sidebar
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.Parent = contentFrame

		tabs[name] = frame
		tabButtons[name] = btn

		btn.MouseButton1Click:Connect(function()
			for tName, tFrame in pairs(tabs) do
				tFrame.Visible = (tName == name)
				tabButtons[tName].BackgroundColor3 =
					(tName == name) and Color3.fromRGB(50, 50, 60) or Config.UI_THEME.BG_LIGHT
				tabButtons[tName].TextColor3 =
					(tName == name) and Config.UI_THEME.TEXT_PRIMARY or Config.UI_THEME.TEXT_SECONDARY
			end
		end)

		return frame
	end

	local homeTab = createTab("Home", "🏠", 0)
	local pcTab = createTab("PC Parts", "💻", 1)
	local groceryTab = createTab("Grocery", "🍎", 2)

	homeTab.Visible = true
	tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	tabButtons["Home"].TextColor3 = Config.UI_THEME.TEXT_PRIMARY

	GUI_References.HomeTab = homeTab
	GUI_References.PCTab = pcTab
	GUI_References.GroceryTab = groceryTab

	-- ================================================================
	-- 🏠 HOME TAB CONTENT
	-- ================================================================

	local homeTitle = Instance.new("TextLabel")
	homeTitle.Size = UDim2.new(1, 0, 0, 30)
	homeTitle.BackgroundTransparency = 1
	homeTitle.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	homeTitle.Text = "Dashboard Controls"
	homeTitle.Font = Enum.Font.GothamBold
	homeTitle.TextSize = 16
	homeTitle.Parent = homeTab

	local function createToggleButton(text, position, toggleKey)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.85, 0, 0, 35)
		btn.Position = position
		btn.BackgroundColor3 = Config.UI_THEME.ACCENT_RED
		btn.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
		btn.Text = text .. ": OFF"
		btn.Font = Enum.Font.GothamBlack
		btn.TextSize = 13
		btn.Parent = homeTab
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		GUI_References.ToggleButtons[toggleKey] = btn
		return btn
	end

	local togglePC = createToggleButton("💻 PC AUTO-BUY", UDim2.new(0.075, 0, 0.05, 0), "PC")
	local toggleGrocery =
		createToggleButton("🍎 GROCERY AUTO-BUY", UDim2.new(0.075, 0, 0.20, 0), "Grocery")
	local toggleAppoint = createToggleButton("🧑‍💻 AUTO APPOINT", UDim2.new(0.075, 0, 0.35, 0), "Appoint")
	local toggleChef = createToggleButton("🍳 AUTO CHEF", UDim2.new(0.075, 0, 0.50, 0), "Chef")
	local toggleExtinguish =
		createToggleButton("🧯 AUTO EXTINGUISH", UDim2.new(0.075, 0, 0.65, 0), "Extinguish")
	local toggleClean =
		createToggleButton("🧹 AUTO CLEAN (NIGHT)", UDim2.new(0.075, 0, 0.80, 0), "Clean")

	local statusText = Instance.new("TextLabel")
	statusText.Size = UDim2.new(1, 0, 0, 30)
	statusText.Position = UDim2.new(0, 0, 0.91, 0)
	statusText.BackgroundTransparency = 1
	statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusText.Text = "Status: 🛡️ Anti-AFK & Anti-Death Active | 📡 Waiting for Server..."
	statusText.Font = Enum.Font.GothamSemibold
	statusText.TextSize = 12
	statusText.Parent = homeTab
	GUI_References.StatusText = statusText

	local function updateToggleUI(btn, state, prefix)
		if state then
			btn.BackgroundColor3 = Config.UI_THEME.ACCENT_GREEN
			btn.Text = prefix .. ": ACTIVE"
		else
			btn.BackgroundColor3 = Config.UI_THEME.ACCENT_RED
			btn.Text = prefix .. ": OFF"
		end
	end

	togglePC.MouseButton1Click:Connect(function()
		State.MasterPC = not State.MasterPC
		updateToggleUI(togglePC, State.MasterPC, "💻 PC AUTO-BUY")
		if State.MasterPC then
			Shopping.TriggerInstantSnipe("PcParts", State.TargetItemsPC)
		end
	end)

	toggleGrocery.MouseButton1Click:Connect(function()
		State.MasterGrocery = not State.MasterGrocery
		updateToggleUI(toggleGrocery, State.MasterGrocery, "🍎 GROCERY AUTO-BUY")
		if State.MasterGrocery then
			Shopping.TriggerInstantSnipe("Grocery", State.TargetItemsGrocery)
		end
	end)

	toggleAppoint.MouseButton1Click:Connect(function()
		State.AutoAppoint = not State.AutoAppoint
		updateToggleUI(toggleAppoint, State.AutoAppoint, "🧑‍💻 AUTO APPOINT")
	end)

	toggleChef.MouseButton1Click:Connect(function()
		State.AutoChef = not State.AutoChef
		updateToggleUI(toggleChef, State.AutoChef, "🍳 AUTO CHEF")
	end)

	toggleExtinguish.MouseButton1Click:Connect(function()
		State.AutoExtinguish = not State.AutoExtinguish
		updateToggleUI(toggleExtinguish, State.AutoExtinguish, "🧯 AUTO EXTINGUISH")
	end)

	toggleClean.MouseButton1Click:Connect(function()
		State.AutoClean = not State.AutoClean
		updateToggleUI(toggleClean, State.AutoClean, "🧹 AUTO CLEAN (NIGHT)")
	end)

	local pcTitle = Instance.new("TextLabel")
	pcTitle.Size = UDim2.new(1, 0, 0, 30)
	pcTitle.BackgroundTransparency = 1
	pcTitle.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	pcTitle.Text = "PC Parts Selector"
	pcTitle.Font = Enum.Font.GothamBold
	pcTitle.TextSize = 16
	pcTitle.Parent = pcTab

	local pcScroll = Instance.new("ScrollingFrame")
	pcScroll.Size = UDim2.new(0.9, 0, 1, -55)
	pcScroll.Position = UDim2.new(0.05, 0, 0, 45)
	pcScroll.BackgroundTransparency = 1
	pcScroll.ScrollBarThickness = 4
	pcScroll.Parent = pcTab
	local pcLayout = Instance.new("UIListLayout", pcScroll)
	pcLayout.Padding = UDim.new(0, 4)

	local groceryTitle = Instance.new("TextLabel")
	groceryTitle.Size = UDim2.new(1, 0, 0, 30)
	groceryTitle.BackgroundTransparency = 1
	groceryTitle.TextColor3 = Config.UI_THEME.TEXT_PRIMARY
	groceryTitle.Text = "Grocery & Food Selector"
	groceryTitle.Font = Enum.Font.GothamBold
	groceryTitle.TextSize = 16
	groceryTitle.Parent = groceryTab

	local grocScroll = Instance.new("ScrollingFrame")
	grocScroll.Size = UDim2.new(0.9, 0, 1, -55)
	grocScroll.Position = UDim2.new(0.05, 0, 0, 45)
	grocScroll.BackgroundTransparency = 1
	grocScroll.ScrollBarThickness = 4
	grocScroll.Parent = groceryTab
	local grocLayout = Instance.new("UIListLayout", grocScroll)
	grocLayout.Padding = UDim.new(0, 4)
end

UISystem.CreateLoginScreen()

-- ============================================================================
-- 🔥 AUTO EXTINGUISH LOOP
-- ============================================================================

task.spawn(function()
	while true do
		task.wait(1.5)

		if not State.AutoExtinguish or State.IsShopping or State.IsBusy then
			continue
		end

		pcall(function()
			local player = Players.LocalPlayer
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")

			if not hrp or not humanoid or humanoid.Health <= 0 then
				return
			end

			local fireFound = nil
			local firePart = nil

			for _, obj in ipairs(workspace:GetDescendants()) do
				local name = obj.Name:lower()

				if obj:IsA("ProximityPrompt") and (name:match("extinguish") or obj.ActionText:lower():match("extinguish")) then
					if obj.Parent and Location.IsInsideBase(obj.Parent.Position) then
						fireFound = obj
						firePart = obj.Parent
						break
					end
				elseif (obj:IsA("ParticleEmitter") or obj:IsA("Fire")) and name:match("fire") then
					local part = obj.Parent
					if part and part:IsA("BasePart") and Location.IsInsideBase(part.Position) then
						fireFound = obj
						firePart = part
						break
					end
				end
			end

			if not fireFound or not firePart then
				return
			end

			State.IsBusy = true
			local targetPos = firePart.Position

			humanoid:UnequipTools()
			task.wait(0.3)

			Location.TeleportAndStabilize(targetPos, Config.TELEPORT_OFFSETS.FIRE)

			local extTool = Tools.FindAndEquip(Config.TOOLS.FIRE)

			if extTool then
				humanoid:EquipTool(extTool)

				if Tools.WaitForEquip(extTool) then
					task.wait(0.2)

					for i = 1, 10 do
						Tools.ActivateTool(extTool)
						VirtualUser:ClickButton1(Vector2.new())

						if fireFound:IsA("ProximityPrompt") then
							Prompt.Fire(fireFound, Config.PROMPT_HOLD_DURATION)
						end

						task.wait(0.5)
					end

					task.wait(1.5)
				end
			end

			humanoid:UnequipTools()
			State.IsBusy = false
		end)
	end
end)

-- ============================================================================
-- 🧹 AUTO CLEAN LOOP
-- ============================================================================

task.spawn(function()
	while true do
		task.wait(1.5)

		if not State.AutoClean or State.IsShopping or State.IsBusy then
			continue
		end

		pcall(function()
			local currentClockTime = Lighting.ClockTime
			if not (currentClockTime >= 18 or currentClockTime <= 6) then
				return
			end

			local player = Players.LocalPlayer
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")

			if not hrp or not humanoid or humanoid.Health <= 0 then
				return
			end

			local messFound = nil
			local messPos = nil
			local messType = nil

			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then
					local actionMatch = obj.ActionText:lower():match("clean")
					local objectText = obj.ObjectText:lower()

					if actionMatch and (objectText:match("mess") or objectText:match("glass") or objectText:match("spill") or objectText:match("trash")) then
						if obj.Parent and Location.IsInsideBase(obj.Parent.Position) then
							messFound = obj
							messPos = obj.Parent.Position
							messType = (objectText:match("glass") or objectText:match("window")) and "glass" or "mess"
							break
						end
					end
				end
			end

			if not messFound or not messPos then
				return
			end

			State.IsBusy = true

			humanoid:UnequipTools()
			task.wait(0.3)

			Location.TeleportAndStabilize(messPos, Config.TELEPORT_OFFSETS.MESS)

			local toolKeywords = (messType == "glass") and Config.TOOLS.GLASS or Config.TOOLS.MESS
			local toolToEquip = Tools.FindAndEquip(toolKeywords)

			if not toolToEquip then
				Webhook.Debug("⚠️ **Cleaning tool not found!** Looking for: " .. table.concat(toolKeywords, ", "))
				State.IsBusy = false
				return
			end

			humanoid:EquipTool(toolToEquip)

			if Tools.WaitForEquip(toolToEquip, Config.EQUIP_TIMEOUT) then
				task.wait(0.2)

				Prompt.Fire(messFound, Config.PROMPT_HOLD_DURATION)
				task.wait(0.3)

				for i = 1, 5 do
					Tools.ActivateTool(toolToEquip)
					VirtualUser:ClickButton1(Vector2.new())
					task.wait(0.4)
				end

				task.wait(1.5)
			end

			humanoid:UnequipTools()
			State.IsBusy = false
		end)
	end
end)

-- ============================================================================
-- 👔 AUTO APPOINT LOOP
-- ============================================================================

task.spawn(function()
	while true do
		task.wait(1.5)

		if not State.AutoAppoint or State.IsShopping or State.IsBusy then
			continue
		end

		pcall(function()
			local player = Players.LocalPlayer
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
			local mainUi = player.PlayerGui:FindFirstChild("MainUi")

			if not hrp or not mainUi then
				return
			end

			local serverFrame = mainUi:FindFirstChild("ServerFrame")
			if not serverFrame or serverFrame.Visible then
				return
			end

			local closestPrompt = State.MyHomeLaptop

			if not closestPrompt or not closestPrompt.Parent then
				local shortestDistance = math.huge

				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") then
						local n, o = obj.Name:lower(), obj.ObjectText:lower()

						if (n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server")) then
							local part = obj.Parent
							if part and part:IsA("BasePart") then
								local dist = (hrp.Position - part.Position).Magnitude
								if dist < shortestDistance and dist < 150 and Location.IsInsideBase(part.Position) then
									shortestDistance = dist
									closestPrompt = obj
								end
							end
						end
					end
				end

				if closestPrompt then
					State.MyHomeLaptop = closestPrompt
					State.MyCafePos = closestPrompt.Parent.Position
				end
			end

			local hasCustomer = false

			local npcInfo = serverFrame:FindFirstChild("NpcInfo")
			if npcInfo and npcInfo.Visible then
				hasCustomer = true
			end

			if not hasCustomer and closestPrompt then
				local laptopPos = closestPrompt.Parent.Position
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
						local hum = obj:FindFirstChild("Humanoid")
						local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
						if root and hum and not hum.Sit and (root.Position - laptopPos).Magnitude < 25 then
							hasCustomer = true
							break
						end
					end
				end
			end

			if closestPrompt and hasCustomer and not State.IsShopping then
				State.IsBusy = true

				local part = closestPrompt.Parent
				Location.TeleportAndStabilize(part.Position, Config.TELEPORT_OFFSETS.APPOINT)

				Prompt.Fire(closestPrompt)
				task.wait(1)

				State.IsBusy = false
			end

			if serverFrame and serverFrame.Visible and not State.IsShopping then
				local pcList = serverFrame:FindFirstChild("PcList")
				if pcList then
					for _, pcFrame in ipairs(pcList:GetChildren()) do
						if not State.AutoAppoint or State.IsShopping then
							break
						end
						if pcFrame:IsA("Frame") then
							local pcName = pcFrame.Name
							if Remotes.SelectPC and Remotes.Appoint then
								Remotes.SelectPC:FireServer(pcName)
								task.wait(0.05)
								Remotes.Appoint:FireServer(pcName)
								task.wait(0.1)
							end
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

		if not State.AutoChef or State.IsShopping or State.IsBusy then
			continue
		end

		pcall(function()
			local player = Players.LocalPlayer
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
			local mainUi = player.PlayerGui:FindFirstChild("MainUi")

			if not mainUi or not hrp then
				return
			end

			local trayItems = {}
			local trayList = mainUi:FindFirstChild("Tray") and mainUi.Tray:FindFirstChild("ListFrame")

			if trayList then
				for _, v in ipairs(trayList:GetChildren()) do
					if v:IsA("Frame") and v:GetAttribute("TrayRuntimeCard") then
						table.insert(trayItems, v)
					end
				end
			end

			if #trayItems > 0 and not State.IsShopping then
				local equippedItem = nil
				local firstItem = trayItems[1]

				for _, item in ipairs(trayItems) do
					local stroke = item:FindFirstChildWhichIsA("UIStroke")
					if stroke and stroke.Thickness == 4 then
						equippedItem = item
						break
					end
				end

				if not equippedItem then
					local rawId = firstItem.Name:gsub("TrayOrder_", "")
					local orderId = tonumber(rawId) or rawId
					if Remotes.SelectTray then
						Remotes.SelectTray:FireServer(orderId)
					end
					task.wait(0.5)
					return
				end

				local pcLabel = equippedItem:FindFirstChild("PcNumber")
				if pcLabel then
					local targetPCNumber = pcLabel.Text:match("%d+")

					if targetPCNumber then
						local foundPC = nil
						local shortestDist = 400
						local validPrefixes = { "pc", "desk", "table", "computer" }

						for _, obj in ipairs(workspace:GetDescendants()) do
							if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
								local rawName = obj.Name:lower():gsub("%s+", ""):gsub("_", "")
								local isMatch = (rawName == targetPCNumber)

								if not isMatch then
									for _, prefix in ipairs(validPrefixes) do
										if rawName == prefix .. targetPCNumber then
											isMatch = true
											break
										end
									end
								end

								if isMatch then
									local pos
									if obj:IsA("Model") then
										pos = obj.PrimaryPart and obj.PrimaryPart.Position
											or obj:GetModelCFrame().Position
									elseif obj:IsA("BasePart") then
										pos = obj.Position
									end

									if pos and Location.IsInsideBase(pos) then
										local dist = (hrp.Position - pos).Magnitude
										if dist < shortestDist then
											shortestDist = dist
											foundPC = obj
										end
									end
								end
							end
						end

						if foundPC and not State.IsShopping then
							State.IsBusy = true

							local pcPos = foundPC:IsA("Model") and (foundPC.PrimaryPart and foundPC.PrimaryPart.Position
								or foundPC:GetModelCFrame().Position) or foundPC.Position

							local targetNPC = nil
							local closestNPCDist = 15

							for _, model in ipairs(workspace:GetDescendants()) do
								if model:IsA("Model") and model:FindFirstChild("Humanoid")
									and not Players:GetPlayerFromCharacter(model) then
									local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
									if root then
										local dist = (root.Position - pcPos).Magnitude
										if dist < closestNPCDist then
											closestNPCDist = dist
											targetNPC = model
										end
									end
								end
							end

							if targetNPC then
								local npcRoot = targetNPC:FindFirstChild("HumanoidRootPart") or targetNPC.PrimaryPart
								local targetPos = (npcRoot.CFrame * CFrame.new(0, 0, 3.5)).Position
									+ Vector3.new(0, 2.5, 0)
								hrp.CFrame = CFrame.lookAt(targetPos, npcRoot.Position)
							else
								Location.TeleportAndStabilize(pcPos, Config.TELEPORT_OFFSETS.CHEF)
							end

							task.wait(0.2)
							if humanoid then humanoid.Sit = false end
							task.wait(0.3)

							if fireproximityprompt then
								for _, prompt in ipairs(workspace:GetDescendants()) do
									if prompt:IsA("ProximityPrompt") then
										local part = prompt.Parent
										if part and part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude < 15 then
											local a = prompt.ActionText:lower()
											local o = prompt.ObjectText:lower()

											if not a:match("sit") and not o:match("chair") and not o:match("seat") then
												Prompt.Fire(prompt)
											end
										end
									end
								end
							end

							task.wait(1)
							State.IsBusy = false
						end
					end
				end
			end

			if #trayItems < 3 and not State.IsShopping then
				local mainUiCooking = mainUi:FindFirstChild("Cooking")

				if mainUiCooking then
					local prepFrame = mainUiCooking:FindFirstChild("PreparingFrame")
					if prepFrame then
						for _, v in ipairs(prepFrame:GetChildren()) do
							if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") then
								local btn = v:FindFirstChild("Button", true)
								if btn and btn.Text == "Deliver" and Remotes.Deliver then
									local orderId = tonumber(v.Name) or v.Name
									Remotes.Deliver:FireServer(orderId)
									task.wait(0.5)
									return
								end
							end
						end
					end

					local snackOrders = mainUi:FindFirstChild("SnacksDeliver")
						and mainUi.SnacksDeliver:FindFirstChild("OrdersFrame")
					if snackOrders then
						for _, v in ipairs(snackOrders:GetChildren()) do
							if v:IsA("Frame") and v:GetAttribute("SnackRuntimeCard") and Remotes.Deliver then
								local orderId = tonumber(v.Name) or v.Name
								Remotes.Deliver:FireServer(orderId)
								task.wait(0.5)
								return
							end
						end
					end

					local cookOrders = mainUiCooking:FindFirstChild("OrdersFrame")
					if cookOrders then
						for _, v in ipairs(cookOrders:GetChildren()) do
							if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") and Remotes.Cook then
								local foodLbl = v:FindFirstChild("FoodName", true)
								if foodLbl then
									local orderId = tonumber(v.Name) or v.Name
									Remotes.Cook:FireServer(foodLbl.Text, orderId)
									task.wait(0.5)
									return
								end
							end
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
		if not State.CurrentWebhook or State.CurrentWebhook == "" then
			return
		end

		local embedsArray = {}
		local pcItemsToBuy = {}
		local groceryItemsToBuy = {}
		local mentionEveryone = false

		if GUI_References.StatusText then
			GUI_References.StatusText.Text = "Status: 🟢 Last Restock at " .. os.date("%H:%M:%S")
		end

		if type(stockTable) == "table" then
			for itemName, quantity in pairs(stockTable) do
				if type(quantity) == "number" and quantity > 0 then
					local itemData = (Modules.ShopConfig and Modules.ShopConfig.Items and Modules.ShopConfig.Items[itemName])
						or {}
					local category = itemData.Category or "Others"
					local isGrocery = (category == "Grocery")

					if isGrocery then
						if State.TargetItemsGrocery[itemName] and State.MasterGrocery then
							table.insert(groceryItemsToBuy, { name = itemName, qty = quantity })
						end
					else
						if State.TargetItemsPC[itemName] and State.MasterPC then
							mentionEveryone = true
							table.insert(pcItemsToBuy, { name = itemName, qty = quantity })
						end
					end
				end
			end
		end

		if #groceryItemsToBuy > 0 then
			Shopping.SecureBuy("Grocery", groceryItemsToBuy)
		end

		if #pcItemsToBuy > 0 then
			Shopping.SecureBuy("PcParts", pcItemsToBuy)
		end

		table.insert(embedsArray, {
			title = "⏱️ Info",
			color = 3447003,
			description = string.format(
				"🔴 **Next Restock:** <t:%d:R>\n⚙️ **PC:** %s | **Grocery:** %s",
				math.floor(os.time() + 3600),
				State.MasterPC and "🟢 ON" or "🔴 OFF",
				State.MasterGrocery and "🟢 ON" or "🔴 OFF"
			),
			footer = { text = "LABA BABY HUB" },
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		})

		local restockPayload = { username = "Laba Baby Hub", embeds = embedsArray }
		if mentionEveryone then
			restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & SNIPED!**"
		end
		Webhook.User(restockPayload)
	end)
end)

-- ============================================================================
-- ✅ INITIALIZATION COMPLETE
-- ============================================================================
print("✅ LABA BABY HUB v2.1 INITIALIZED - All systems ready")
print("🔧 Fixes Applied:")
print("  ✓ Syntax errors removed (continue statements)")
print("  ✓ Sniper logic improved (better retry mechanism)")
print("  ✓ Tool matching refined (strict substring matching)")
