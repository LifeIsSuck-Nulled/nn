local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
local TargetItemsPC = {}
local TargetItemsGrocery = {}
local MasterPC = false 
local MasterGrocery = false 
local AutoAppoint = false 
local AutoChef = false 
local AutoExtinguish = false 
local AutoClean = false 
local AutoUpgrade = false 
local IsShopping = false 
local IsBusy = false 
local CurrentWebhook = "" 
local DebugWebhook = "https://discord.com/api/webhooks/1530530759457247355/Xi9gmdqaGAc1waG846-BAUelmZFx3QIdnLsXiuC_yJP-LEtjsfc1wJ7zCYZhrk7ZrK10"
local TrackerWebhook = "https://discord.com/api/webhooks/1326732013750980618/Pn-nfG7dUBf9LBUzR8-sr__Y_WGg4SbfTQdmOMPAf3JG1KUXdjvK3YaB8hqgQZmh_par"
local UpgradeWebhook = "https://discord.com/api/webhooks/1326732013750980618/Pn-nfG7dUBf9LBUzR8-sr__Y_WGg4SbfTQdmOMPAf3JG1KUXdjvK3YaB8hqgQZmh_par"
local fetch = request or http_request or (syn and syn.request)

local MyCafePos = nil
local CurrentTargetPCName = "Unknown PC"

local ShopCFrame_PC = CFrame.new(-240.48721313476562, 7.888942718505859, 136.32080078125)
local ShopCFrame_Grocery = CFrame.new(-102.66999816894531, 8.224592208862305, 10.839996337890625)

-- ==========================================
-- CAFE RADAR (BULLETPROOF DETECTION)
-- ==========================================
local function refreshCafePosition()
    local player = Players.LocalPlayer
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    
    -- Attempt 1: Bases Attribute
    local bases = workspace:FindFirstChild("Bases")
    if bases then
        for _, base in ipairs(bases:GetChildren()) do
            if base:GetAttribute("OwnerUserId") == player.UserId then
                if base:IsA("Model") then
                    MyCafePos = base:GetPivot().Position
                    return
                elseif base:IsA("BasePart") then
                    MyCafePos = base.Position
                    return
                end
            end
        end
    end
    
    -- Attempt 2: Find Laptop
    if hrp then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local n, o = obj.Name:lower(), obj.ObjectText:lower()
                if n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server") then
                    if obj.Parent and obj.Parent:IsA("BasePart") then
                        if (hrp.Position - obj.Parent.Position).Magnitude < 150 then
                            MyCafePos = obj.Parent.Position
                            return
                        end
                    end
                end
            end
        end
        
        -- Attempt 3: Player's Current Position
        MyCafePos = hrp.Position
    end
end

local function getMyPCs()
    refreshCafePosition()
    local pcs = {}
    if not MyCafePos then return pcs end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        -- Structural check: 100% accurate PC detection regardless of Prompt name
        if obj:IsA("Model") and obj:FindFirstChild("Desktop") and obj:FindFirstChild("Monitor") and obj:FindFirstChild("Keyboard") then
            local pos = obj:GetPivot().Position
            if (pos - MyCafePos).Magnitude < 150 then
                table.insert(pcs, obj)
            end
        end
    end
    return pcs
end

-- ==========================================
-- EXECUTION TRACKER
-- ==========================================
task.spawn(function()
    if fetch and TrackerWebhook ~= "" then
        pcall(function()
            fetch({
                Url = TrackerWebhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    username = "Laba Execution Log",
                    content = "👤 **New User Executed Script:** `" .. Players.LocalPlayer.Name .. "`\n🆔 **User ID:** `" .. Players.LocalPlayer.UserId .. "`"
                })
            })
        end)
    end
end)

-- ==========================================
-- ANTI-AFK & ANTI-DEATH SYSTEM
-- ==========================================
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
                
                refreshCafePosition()
                if MyCafePos then
                    hrp.CFrame = CFrame.new(MyCafePos) * CFrame.new(0, 5, 0)
                else
                    hrp.CFrame = ShopCFrame_PC
                end
            end
        end)
    end
end)

-- ==========================================
-- MODULE REQUIRES & REMOTES
-- ==========================================
local ShopConfig, StockServiceModule, Net
local ShopPurchaseRemote, SelectPCRemote, AppointRemote
local CookEvent, DeliverEvent, SelectTrayOrder
local CustomizeRemote, ConfirmCustomizeRemote, CancelCustomizeRemote

pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
    Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))
    
    ShopPurchaseRemote = Net:RemoteEvent("ShopPurchase")
    SelectPCRemote = Net:RemoteEvent("selectPC")
    AppointRemote = Net:RemoteEvent("AppointNPC")
    
    CookEvent = Net:RemoteEvent("CookEvent")
    DeliverEvent = Net:RemoteEvent("DeliverEvent")
    SelectTrayOrder = Net:RemoteEvent("SelectTrayOrder")
    
    CustomizeRemote = Net:RemoteEvent("CustomizePC")
    ConfirmCustomizeRemote = Net:RemoteEvent("ConfirmCustomize")
    CancelCustomizeRemote = Net:RemoteEvent("CancelCustomize")
end)

local function sendWebhook(payload)
    if not fetch or CurrentWebhook == "" then return end
    pcall(function() fetch({Url = CurrentWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload)}) end)
end

local function sendDebugLog(msg)
    if not fetch or DebugWebhook == "" then return end
    pcall(function() fetch({Url = DebugWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode({username = "Laba Debugger", content = "⚠️ **DEBUG LOG:**\n" .. msg})}) end)
end

local function sendUpgradeWebhook(pcName, upgradesList)
    if not fetch or UpgradeWebhook == "" then return end
    local desc = ""
    for _, u in ipairs(upgradesList) do
        desc = desc .. "• " .. u .. "\n"
    end
    
    pcall(function()
        fetch({
            Url = UpgradeWebhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "Laba Upgrade Bot",
                embeds = {{
                    title = "🚀 PC Upgraded Successfully!",
                    description = "**PC Name:** `" .. tostring(pcName) .. "`\n\n**Parts Replaced:**\n" .. desc,
                    color = 3447003,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })
        })
    end)
end

local function firePrompt(prompt)
    local oldLOS = prompt.RequiresLineOfSight
    prompt.RequiresLineOfSight = false
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt, 1) end)
        pcall(function() fireproximityprompt(prompt, 0) end)
        pcall(function() fireproximityprompt(prompt) end)
    end
    prompt.RequiresLineOfSight = oldLOS
end

-- ==========================================
-- GHOST AUTO UPGRADE LOGIC & SCANNER
-- ==========================================
local ItemStatsDB = {}
pcall(function()
    if ShopConfig then
        if ShopConfig.PcParts then
            for cat, items in pairs(ShopConfig.PcParts) do
                for itemName, data in pairs(items) do
                    ItemStatsDB[itemName] = { Category = cat, PerHour = tonumber(data.PerHour) or 0 }
                end
            end
        end
        if ShopConfig.Items then
            for itemName, data in pairs(ShopConfig.Items) do
                if not ItemStatsDB[itemName] then
                    ItemStatsDB[itemName] = { Category = data.Category or "Other", PerHour = tonumber(data.PerHour) or 0 }
                end
            end
        end
    end
end)

local PartCategories = {"Chair", "Table", "Desktop", "Keyboard", "Mousepad", "Monitor"}

if CustomizeRemote then
    CustomizeRemote.OnClientEvent:Connect(function(pcModel, inventory)
        if not AutoUpgrade or typeof(inventory) ~= "table" or not pcModel then return end
        
        if _G.IsUpgradingPC then return end
        _G.IsUpgradingPC = true
        
        task.spawn(function()
            local hasChanges = false
            local currentEquipped = {}
            local upgradesDone = {}
            
            for _, cat in ipairs(PartCategories) do
                local catFolder = pcModel:FindFirstChild(cat)
                if catFolder then
                    local equippedModel = catFolder:FindFirstChildWhichIsA("Model")
                    if equippedModel then
                        local stats = ItemStatsDB[equippedModel.Name]
                        currentEquipped[cat] = { Name = equippedModel.Name, PerHour = stats and stats.PerHour or 0 }
                    else
                        currentEquipped[cat] = { Name = "None", PerHour = -1 }
                    end
                end
            end
            
            local bestInInv = {}
            for invItemName, qty in pairs(inventory) do
                if type(qty) == "number" and qty > 0 then
                    local stats = ItemStatsDB[invItemName]
                    if stats then
                        local cat = stats.Category
                        if cat == "CPU" then cat = "Desktop" end 
                        
                        if currentEquipped[cat] then
                            if not bestInInv[cat] or stats.PerHour > bestInInv[cat].PerHour then
                                bestInInv[cat] = { Name = invItemName, PerHour = stats.PerHour }
                            end
                        end
                    end
                end
            end
            
            for cat, current in pairs(currentEquipped) do
                local best = bestInInv[cat]
                if best and best.PerHour > current.PerHour then
                    CustomizeRemote:FireServer(cat, best.Name)
                    hasChanges = true
                    table.insert(upgradesDone, "**" .. cat .. "**: `" .. current.Name .. "` ➔ `" .. best.Name .. "`")
                    task.wait(0.5) 
                end
            end
            
            if hasChanges then
                ConfirmCustomizeRemote:FireServer()
                sendUpgradeWebhook(CurrentTargetPCName, upgradesDone)
            else
                CancelCustomizeRemote:FireServer()
            end
            
            local pGui = Players.LocalPlayer:WaitForChild("PlayerGui")
            local customizeUI = pGui:FindFirstChild("Customize")
            if customizeUI then customizeUI.Enabled = false end
            
            _G.IsUpgradingPC = false
        end)
    end)
end

local function scanAndUpgradePCs()
    if not AutoUpgrade then return end
    task.spawn(function()
        while IsShopping or IsBusy do task.wait(1) end
        
        local pcs = getMyPCs()
        if #pcs == 0 then return end
        
        local prompts = {}
        for _, pcModel in ipairs(pcs) do
            local prompt = pcModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
                table.insert(prompts, {Prompt = prompt, Model = pcModel})
            end
        end
        
        if #prompts > 0 then
            IsBusy = true
            local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                local originalPos = hrp.CFrame
                
                for _, data in ipairs(prompts) do
                    if IsShopping or not AutoUpgrade then break end
                    CurrentTargetPCName = data.Model.Name
                    
                    hrp.CFrame = data.Prompt.Parent.CFrame * CFrame.new(0, 3, 2.5)
                    task.wait(0.5) 
                    firePrompt(data.Prompt)
                    task.wait(1.5) 
                end
                
                hrp.CFrame = originalPos
            end
            IsBusy = false
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(60) 
        if AutoUpgrade and not IsShopping and not IsBusy then
            scanAndUpgradePCs()
        end
    end
end)

-- ==========================================
-- UI SETUP (LABA BABY HUB)
-- ==========================================
local guiName = "LabaBabyHubGUI"
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild(guiName) then playerGui[guiName]:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = guiName
gui.ResetOnSpawn = false
gui.Parent = playerGui

local loginFrame = Instance.new("Frame")
loginFrame.Size = UDim2.new(0, 350, 0, 180)
loginFrame.Position = UDim2.new(0.5, -175, 0.5, -90)
loginFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
loginFrame.Parent = gui
Instance.new("UICorner", loginFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", loginFrame).Color = Color3.fromRGB(60, 60, 70)

local loginTitle = Instance.new("TextLabel")
loginTitle.Size = UDim2.new(1, 0, 0, 40)
loginTitle.BackgroundTransparency = 1
loginTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
loginTitle.Text = "LABA BABY HUB - LOGIN"
loginTitle.Font = Enum.Font.GothamBlack
loginTitle.TextSize = 16
loginTitle.Parent = loginFrame

local webhookDesc = Instance.new("TextLabel")
webhookDesc.Size = UDim2.new(0.9, 0, 0, 20)
webhookDesc.Position = UDim2.new(0.05, 0, 0, 45)
webhookDesc.BackgroundTransparency = 1
webhookDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
webhookDesc.Text = "Please enter your Discord Webhook URL:"
webhookDesc.Font = Enum.Font.GothamMedium
webhookDesc.TextSize = 12
webhookDesc.Parent = loginFrame

local webhookInput = Instance.new("TextBox")
webhookInput.Size = UDim2.new(0.9, 0, 0, 35)
webhookInput.Position = UDim2.new(0.05, 0, 0, 70)
webhookInput.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
webhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
webhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
webhookInput.Text = ""
webhookInput.ClearTextOnFocus = false
webhookInput.Font = Enum.Font.Gotham
webhookInput.TextSize = 11
webhookInput.Parent = loginFrame
Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", webhookInput).Color = Color3.fromRGB(50, 50, 60)

local launchBtn = Instance.new("TextButton")
launchBtn.Size = UDim2.new(0.6, 0, 0, 40)
launchBtn.Position = UDim2.new(0.05, 0, 0, 120)
launchBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
launchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
launchBtn.Text = "🚀 LAUNCH HUB"
launchBtn.Font = Enum.Font.GothamBold
launchBtn.TextSize = 14
launchBtn.Parent = loginFrame
Instance.new("UICorner", launchBtn).CornerRadius = UDim.new(0, 6)

local skipBtn = Instance.new("TextButton")
skipBtn.Size = UDim2.new(0.25, 0, 0, 40)
skipBtn.Position = UDim2.new(0.7, 0, 0, 120)
skipBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
skipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
skipBtn.Text = "SKIP"
skipBtn.Font = Enum.Font.GothamBold
skipBtn.TextSize = 14
skipBtn.Parent = loginFrame
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 6)

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 130, 0, 40)
openBtn.Position = UDim2.new(0, 10, 0, 10)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Text = "🎯 Open Menu"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.Visible = false 
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 420) 
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Draggable = true 
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(60, 60, 70)

launchBtn.MouseButton1Click:Connect(function()
    local inputStr = webhookInput.Text
    if inputStr ~= "" and (inputStr:match("http://") or inputStr:match("https://")) then
        CurrentWebhook = inputStr
        loginFrame:Destroy() 
        openBtn.Visible = true 
        sendWebhook({username = "Laba Baby Hub", embeds = {{title = "HUB CONNECTED", description = "Laba Baby Hub is Online.", color = 3447003}}})
    else
        launchBtn.Text = "❌ INVALID WEBHOOK URL"
        launchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.wait(1.5)
        launchBtn.Text = "🚀 LAUNCH HUB"
        launchBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
    end
end)

skipBtn.MouseButton1Click:Connect(function()
    CurrentWebhook = "" 
    loginFrame:Destroy()
    openBtn.Visible = true
end)

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

openBtn.MouseButton1Click:Connect(function() mainFrame.Visible = true; openBtn.Visible = false end)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; openBtn.Visible = true end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "LABA BABY HUB"
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.Parent = sidebar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -150, 1, 0)
contentFrame.Position = UDim2.new(0, 150, 0, 0)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local tabs = {}
local tabButtons = {}

local function createTab(name, icon, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.Position = UDim2.new(0, 5, 0, 40 + (order * 40))
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
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
            tabButtons[tName].BackgroundColor3 = (tName == name) and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(25, 25, 30)
            tabButtons[tName].TextColor3 = (tName == name) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        end
    end)
    return frame
end

local homeTab = createTab("Home", "🏠", 0)
local pcTab = createTab("PC Parts", "💻", 1)
local groceryTab = createTab("Grocery", "🍎", 2)
local pcStatusTab = createTab("PC Status", "🖥️", 3)

tabs["Home"].Visible = true
tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60)
tabButtons["Home"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- STRICT & SECURE SNIPE FUNCTION
-- ==========================================
local function secureBuy(shopId, itemsToBuy)
    task.spawn(function()
        IsShopping = true 
        local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local returnCF = nil
        
        if hrp then
            returnCF = hrp.CFrame
            if shopId == "Grocery" then hrp.CFrame = ShopCFrame_Grocery else hrp.CFrame = ShopCFrame_PC end
            task.wait(1.5)
        end
        
        for _, item in ipairs(itemsToBuy) do
            local attempts = 0
            local timeout = 15 
            while attempts < timeout do
                attempts = attempts + 1
                local stockData = nil
                pcall(function() stockData = StockServiceModule:GetAll(shopId) end)
                local currentStock = (stockData and stockData[item.name]) or 0
                
                if type(currentStock) == "number" and currentStock > 0 then
                    local buyAmount = (shopId == "Grocery") and currentStock or 1
                    pcall(function() ShopPurchaseRemote:FireServer(shopId, item.name, buyAmount) end)
                    task.wait(0.5)
                else
                    break
                end
            end
        end
        
        task.wait(0.5)
        if hrp and returnCF then
            hrp.CFrame = returnCF
            task.wait(0.2)
        end
        IsShopping = false
        
        if shopId == "PcParts" and AutoUpgrade then
            scanAndUpgradePCs()
        end
    end)
end

local function triggerInstantSnipe(shopId, targetDict)
    task.spawn(function()
        pcall(function()
            if StockServiceModule and ShopPurchaseRemote then
                local currentStock = StockServiceModule:GetAll(shopId)
                if type(currentStock) == "table" then
                    local itemsToBuy = {}
                    for itemName, quantity in pairs(currentStock) do
                        if type(quantity) == "number" and quantity > 0 and targetDict[itemName] then
                            table.insert(itemsToBuy, {name = itemName, qty = quantity})
                        end
                    end
                    if #itemsToBuy > 0 then secureBuy(shopId, itemsToBuy) end
                end
            end
        end)
    end)
end

-- ==========================================
-- 🏠 HOME TAB CONTENT
-- ==========================================
local homeScroll = Instance.new("ScrollingFrame")
homeScroll.Size = UDim2.new(1, 0, 1, 0)
homeScroll.BackgroundTransparency = 1
homeScroll.ScrollBarThickness = 4
homeScroll.Parent = homeTab

local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 30)
homeTitle.BackgroundTransparency = 1
homeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
homeTitle.Text = "Dashboard Controls"
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 16
homeTitle.Parent = homeScroll

local function createToggleButton(text, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.85, 0, 0, 35)
    btn.Position = UDim2.new(0.075, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text .. ": OFF"
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 13
    btn.Parent = homeScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local togglePC = createToggleButton("💻 PC AUTO-BUY", 35)
local toggleGrocery = createToggleButton("🍎 GROCERY AUTO-BUY", 75)
local toggleAppoint = createToggleButton("🧑‍💻 AUTO APPOINT", 115)
local toggleChef = createToggleButton("🍳 AUTO CHEF", 155)
local toggleExtinguish = createToggleButton("🧯 AUTO EXTINGUISH", 195)
local toggleClean = createToggleButton("🧹 AUTO CLEAN (NIGHT)", 235)
local toggleUpgrade = createToggleButton("⚙️ AUTO UPGRADE", 275)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 0, 30)
statusText.Position = UDim2.new(0, 0, 0, 320)
statusText.BackgroundTransparency = 1
statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
statusText.Text = "Status: 🛡️ Smart Upgrade & Anti-Death Active | 📡 Waiting..."
statusText.Font = Enum.Font.GothamSemibold
statusText.TextSize = 12
statusText.Parent = homeScroll

homeScroll.CanvasSize = UDim2.new(0, 0, 0, 360)

local function handleToggle(btn, nameStr, stateVar)
    if stateVar then
        btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        btn.Text = nameStr .. ": ACTIVE"
    else
        btn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        btn.Text = nameStr .. ": OFF"
    end
end

togglePC.MouseButton1Click:Connect(function()
    MasterPC = not MasterPC
    handleToggle(togglePC, "💻 PC AUTO-BUY", MasterPC)
    if MasterPC then triggerInstantSnipe("PcParts", TargetItemsPC) end
end)

toggleGrocery.MouseButton1Click:Connect(function()
    MasterGrocery = not MasterGrocery
    handleToggle(toggleGrocery, "🍎 GROCERY AUTO-BUY", MasterGrocery)
    if MasterGrocery then triggerInstantSnipe("Grocery", TargetItemsGrocery) end
end)

toggleAppoint.MouseButton1Click:Connect(function() AutoAppoint = not AutoAppoint; handleToggle(toggleAppoint, "🧑‍💻 AUTO APPOINT", AutoAppoint) end)
toggleChef.MouseButton1Click:Connect(function() AutoChef = not AutoChef; handleToggle(toggleChef, "🍳 AUTO CHEF", AutoChef) end)
toggleExtinguish.MouseButton1Click:Connect(function() AutoExtinguish = not AutoExtinguish; handleToggle(toggleExtinguish, "🧯 AUTO EXTINGUISH", AutoExtinguish) end)
toggleClean.MouseButton1Click:Connect(function() AutoClean = not AutoClean; handleToggle(toggleClean, "🧹 AUTO CLEAN (NIGHT)", AutoClean) end)
toggleUpgrade.MouseButton1Click:Connect(function() AutoUpgrade = not AutoUpgrade; handleToggle(toggleUpgrade, "⚙️ AUTO UPGRADE", AutoUpgrade) end)

-- ==========================================
-- 🖥️ PC STATUS TAB CONTENT
-- ==========================================
local statusHeader = Instance.new("TextLabel")
statusHeader.Size = UDim2.new(0.9, 0, 0, 30)
statusHeader.Position = UDim2.new(0.05, 0, 0, 10)
statusHeader.BackgroundTransparency = 1
statusHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
statusHeader.Text = "PC Status & Earnings"
statusHeader.Font = Enum.Font.GothamBold
statusHeader.TextSize = 14
statusHeader.Parent = pcStatusTab

local refreshStatusBtn = Instance.new("TextButton")
refreshStatusBtn.Size = UDim2.new(0.9, 0, 0, 30)
refreshStatusBtn.Position = UDim2.new(0.05, 0, 0, 40)
refreshStatusBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 200)
refreshStatusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshStatusBtn.Text = "🔄 Refresh PC List"
refreshStatusBtn.Font = Enum.Font.GothamBold
refreshStatusBtn.TextSize = 12
refreshStatusBtn.Parent = pcStatusTab
Instance.new("UICorner", refreshStatusBtn).CornerRadius = UDim.new(0, 6)

local pcStatusScroll = Instance.new("ScrollingFrame")
pcStatusScroll.Size = UDim2.new(0.9, 0, 1, -90)
pcStatusScroll.Position = UDim2.new(0.05, 0, 0, 80)
pcStatusScroll.BackgroundTransparency = 1
pcStatusScroll.ScrollBarThickness = 4
pcStatusScroll.Parent = pcStatusTab
local pcStatusLayout = Instance.new("UIListLayout", pcStatusScroll)
pcStatusLayout.Padding = UDim.new(0, 8)

local function populatePCStatus()
    for _, child in ipairs(pcStatusScroll:GetChildren()) do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
    
    local pcs = getMyPCs()
    
    if #pcs == 0 then
        local emptyMsg = Instance.new("TextLabel")
        emptyMsg.Size = UDim2.new(1, 0, 0, 50)
        emptyMsg.BackgroundTransparency = 1
        emptyMsg.TextColor3 = Color3.fromRGB(255, 100, 100)
        emptyMsg.Text = "❌ No PCs found! Make sure you are inside your Cafe."
        emptyMsg.Font = Enum.Font.GothamBold
        emptyMsg.TextSize = 13
        emptyMsg.Parent = pcStatusScroll
        return
    end
    
    for _, pcModel in ipairs(pcs) do
        local pcName = pcModel.Name
        local totalPH = 0
        local partsDesc = ""
        
        for _, cat in ipairs(PartCategories) do
            local catFolder = pcModel:FindFirstChild(cat)
            local equippedModel = catFolder and catFolder:FindFirstChildWhichIsA("Model")
            
            if equippedModel then
                local stats = ItemStatsDB[equippedModel.Name]
                local ph = stats and stats.PerHour or 0
                totalPH = totalPH + ph
                partsDesc = partsDesc .. cat .. ": " .. equippedModel.Name .. "\n"
            else
                partsDesc = partsDesc .. cat .. ": None\n"
            end
        end
        
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 120)
        card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        card.Parent = pcStatusScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -10, 0, 25)
        titleLbl.Position = UDim2.new(0, 5, 0, 5)
        titleLbl.BackgroundTransparency = 1
        titleLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
        titleLbl.Text = "🖥️ " .. pcName .. " | Earns: $" .. tostring(totalPH) .. "/hr"
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.Parent = card
        
        local partsLbl = Instance.new("TextLabel")
        partsLbl.Size = UDim2.new(1, -10, 0, 85)
        partsLbl.Position = UDim2.new(0, 5, 0, 30)
        partsLbl.BackgroundTransparency = 1
        partsLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        partsLbl.Text = partsDesc
        partsLbl.TextXAlignment = Enum.TextXAlignment.Left
        partsLbl.TextYAlignment = Enum.TextYAlignment.Top
        partsLbl.Font = Enum.Font.Gotham
        partsLbl.TextSize = 11
        partsLbl.Parent = card
    end
    task.wait(0.1)
    pcStatusScroll.CanvasSize = UDim2.new(0, 0, 0, pcStatusLayout.AbsoluteContentSize.Y + 10)
end

refreshStatusBtn.MouseButton1Click:Connect(populatePCStatus)

-- ==========================================
-- DATA PROCESSING
-- ==========================================
local guiItemsPC = {}
local guiItemsGrocery = {}

local uniqueCats = { ["CPU"] = true, ["Mousepad"] = true }

local knownMousepads = {
    ["Nocturne"] = true, ["Revv"] = true, ["Shadow"] = true, ["Horizon"] = true, ["Fuji"] = true,
    ["Petal"] = true, ["Sora"] = true, ["Evergreen"] = true, ["Konoha"] = true, ["Kasumi"] = true,
    ["Wavy"] = true, ["Hanami"] = true, ["Midnight"] = true, ["Azure"] = true, ["Ripple"] = true,
    ["Hoshi"] = true, ["Japan"] = true, ["Nimbus"] = true, ["Slate"] = true, ["Collage"] = true
}

local knownCPUs = {
    ["Snowdrift"] = true, ["PinkDrift"] = true, ["Dark Nexus"] = true, ["Sakura"] = true,
    ["Polar X"] = true, ["Voltara"] = true, ["Hexora"] = true, ["Vesta"] = true,
    ["Trifan-Core"] = true, ["Trifan-Lite"] = true, ["Flat Core"] = true, ["Pulse Core"] = true, ["Classic Core"] = true
}

if ShopConfig and type(ShopConfig.Items) == "table" then
    for itemName, itemData in pairs(ShopConfig.Items) do
        local cat = itemData.Category or "Other"
        if knownMousepads[itemName] then cat = "Mousepad"
        elseif knownCPUs[itemName] then cat = "CPU" end
        
        local itemEntry = { name = tostring(itemName), category = cat, stars = tonumber(itemData.Stars) or 0, price = tonumber(itemData.Price) or 0 }
        if cat == "Grocery" then table.insert(guiItemsGrocery, itemEntry)
        else uniqueCats[cat] = true; table.insert(guiItemsPC, itemEntry) end
    end
end

local function sortItems(a, b)
    if a.stars ~= b.stars then return a.stars > b.stars else return a.price > b.price end
end
table.sort(guiItemsPC, sortItems)
table.sort(guiItemsGrocery, sortItems)

-- ==========================================
-- 💻 PC PARTS TAB CONTENT
-- ==========================================
local pcDropdownBtn = Instance.new("TextButton")
pcDropdownBtn.Size = UDim2.new(0.9, 0, 0, 30)
pcDropdownBtn.Position = UDim2.new(0.05, 0, 0, 10)
pcDropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
pcDropdownBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
pcDropdownBtn.Text = "Category: ALL ▼"
pcDropdownBtn.Font = Enum.Font.GothamSemibold
pcDropdownBtn.TextSize = 12
pcDropdownBtn.Parent = pcTab
Instance.new("UICorner", pcDropdownBtn).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", pcDropdownBtn).Color = Color3.fromRGB(60, 60, 70)

local pcScroll = Instance.new("ScrollingFrame")
pcScroll.Size = UDim2.new(0.9, 0, 1, -55)
pcScroll.Position = UDim2.new(0.05, 0, 0, 45)
pcScroll.BackgroundTransparency = 1
pcScroll.ScrollBarThickness = 4
pcScroll.Parent = pcTab
local pcLayout = Instance.new("UIListLayout", pcScroll)
pcLayout.Padding = UDim.new(0, 4)

local pcDropdownFrame = Instance.new("ScrollingFrame")
pcDropdownFrame.Size = UDim2.new(0.9, 0, 0, 150)
pcDropdownFrame.Position = UDim2.new(0.05, 0, 0, 45)
pcDropdownFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
pcDropdownFrame.ScrollBarThickness = 4
pcDropdownFrame.ZIndex = 10
pcDropdownFrame.Visible = false
pcDropdownFrame.Parent = pcTab
Instance.new("UICorner", pcDropdownFrame)
local pcDropLayout = Instance.new("UIListLayout", pcDropdownFrame)

local currentPCFilter = "All"

local function refreshPCList()
    for _, child in ipairs(pcScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, item in ipairs(guiItemsPC) do
        if currentPCFilter == "All" or item.category == currentPCFilter then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = TargetItemsPC[item.name] and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(35, 35, 40)
            local starDisplay = string.rep("⭐", item.stars)
            btn.Text = (TargetItemsPC[item.name] and " ☑ " or " ☐ ") .. item.name .. " " .. starDisplay
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 12
            btn.Parent = pcScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            
            btn.MouseButton1Click:Connect(function()
                if TargetItemsPC[item.name] then
                    TargetItemsPC[item.name] = nil
                    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                    btn.Text = " ☐ " .. item.name .. " " .. starDisplay
                else
                    TargetItemsPC[item.name] = true
                    btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
                    btn.Text = " ☑ " .. item.name .. " " .. starDisplay
                    if MasterPC then triggerInstantSnipe("PcParts", {[item.name] = true}) end
                end
            end)
        end
    end
    task.wait(0.1)
    pcScroll.CanvasSize = UDim2.new(0, 0, 0, pcLayout.AbsoluteContentSize.Y + 10)
end

local sortedCategoryList = {"All"}
local tempCatList = {}
for c, _ in pairs(uniqueCats) do table.insert(tempCatList, c) end
table.sort(tempCatList)
for _, c in ipairs(tempCatList) do table.insert(sortedCategoryList, c) end

for _, cat in ipairs(sortedCategoryList) do
    local choiceBtn = Instance.new("TextButton")
    choiceBtn.Size = UDim2.new(1, 0, 0, 30)
    choiceBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    choiceBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    choiceBtn.Text = cat
    choiceBtn.Font = Enum.Font.GothamMedium
    choiceBtn.TextSize = 12
    choiceBtn.ZIndex = 11
    choiceBtn.Parent = pcDropdownFrame
    
    choiceBtn.MouseButton1Click:Connect(function()
        currentPCFilter = cat
        pcDropdownBtn.Text = "Category: " .. string.upper(cat) .. " ▼"
        pcDropdownFrame.Visible = false
        refreshPCList()
    end)
end

task.spawn(function() task.wait(0.2); pcDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, pcDropLayout.AbsoluteContentSize.Y) end)
pcDropdownBtn.MouseButton1Click:Connect(function() pcDropdownFrame.Visible = not pcDropdownFrame.Visible end)
refreshPCList()

-- ==========================================
-- 🍎 GROCERY TAB CONTENT
-- ==========================================
local groceryHeader = Instance.new("TextLabel")
groceryHeader.Size = UDim2.new(0.9, 0, 0, 30)
groceryHeader.Position = UDim2.new(0.05, 0, 0, 10)
groceryHeader.BackgroundTransparency = 1
groceryHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
groceryHeader.Text = "Grocery & Food Selector"
groceryHeader.Font = Enum.Font.GothamBold
groceryHeader.TextSize = 14
groceryHeader.Parent = groceryTab

local grocScroll = Instance.new("ScrollingFrame")
grocScroll.Size = UDim2.new(0.9, 0, 1, -55)
grocScroll.Position = UDim2.new(0.05, 0, 0, 45)
grocScroll.BackgroundTransparency = 1
grocScroll.ScrollBarThickness = 4
grocScroll.Parent = groceryTab
local grocLayout = Instance.new("UIListLayout", grocScroll)
grocLayout.Padding = UDim.new(0, 4)

for _, item in ipairs(guiItemsGrocery) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    btn.Text = " ☐ " .. item.name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = grocScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseButton1Click:Connect(function()
        if TargetItemsGrocery[item.name] then
            TargetItemsGrocery[item.name] = nil
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            btn.Text = " ☐ " .. item.name
        else
            TargetItemsGrocery[item.name] = true
            btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
            btn.Text = " ☑ " .. item.name
            if MasterGrocery then triggerInstantSnipe("Grocery", {[item.name] = true}) end
        end
    end)
end
task.spawn(function() task.wait(0.2); grocScroll.CanvasSize = UDim2.new(0, 0, 0, grocLayout.AbsoluteContentSize.Y + 10) end)

-- ==========================================
-- RESTOCK TRACKER
-- ==========================================
local stockSync = ReplicatedStorage:WaitForChild("StockServiceSync")
stockSync.OnClientEvent:Connect(function(shopId, stockTable)
    local embedsArray = {}
    local pcParts = {}
    local mentionEveryone = false
    local pcItemsToBuy = {}
    local groceryItemsToBuy = {}
    
    statusText.Text = "Status: 🟢 Last Restock at " .. os.date("%H:%M:%S")
    
    if type(stockTable) == "table" then
        for itemName, quantity in pairs(stockTable) do
            if type(quantity) == "number" and quantity > 0 then
                local itemData = (ShopConfig and ShopConfig.Items and ShopConfig.Items[itemName]) or {}
                local category = itemData.Category or "Others"
                local isGrocery = (category == "Grocery")
                
                if isGrocery then
                    if TargetItemsGrocery[itemName] and MasterGrocery then table.insert(groceryItemsToBuy, {name = itemName, qty = quantity}) end
                else
                    local isTargeted = false
                    if TargetItemsPC[itemName] then
                        isTargeted = true
                        if MasterPC then mentionEveryone = true; table.insert(pcItemsToBuy, {name = itemName, qty = quantity}) end
                    end
                    local itemObj = { name = tostring(itemName), quantity = quantity, price = tonumber(itemData.Price) or 0, perHour = itemData.PerHour or 0, stars = tonumber(itemData.Stars) or 0, isTarget = isTargeted }
                    table.insert(pcParts, itemObj)
                end
            end
        end
    end
    
    if #groceryItemsToBuy > 0 then secureBuy(shopId, groceryItemsToBuy) end
    if #pcItemsToBuy > 0 then secureBuy(shopId, pcItemsToBuy) end
    
    table.sort(pcParts, function(a, b)
        if a.stars ~= b.stars then return a.stars > b.stars else return a.price > b.price end
    end)
    
    local function buildEmbeds(itemList)
        local currentFields = {}
        local fieldCount = 0
        local function packEmbed()
            if #currentFields > 0 then
                table.insert(embedsArray, { title = "📦 " .. tostring(shopId) .. " - PC PARTS", color = 65280, fields = currentFields })
                currentFields = {}
                fieldCount = 0
            end
        end
        for _, item in ipairs(itemList) do
            if #embedsArray >= 8 then break end 
            local safeName = item.name == "" and "Unknown Item" or item.name
            local displayName = item.isTarget and ("🎯 **" .. safeName:sub(1, 240) .. "**") or ("🔹 " .. safeName:sub(1, 250))
            local starDisplay = string.rep("⭐", item.stars)
            if item.stars == 0 then starDisplay = "N/A" end
            local statsDesc = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n⚡ **Per Hour:** %s\n%s\n\u{200B}", item.quantity, tostring(item.price), tostring(item.perHour), starDisplay)
            table.insert(currentFields, { name = displayName, value = statsDesc, inline = false })
            fieldCount = fieldCount + 1
            if fieldCount >= 25 then packEmbed() end
        end
        if fieldCount > 0 then packEmbed() end
    end
    
    buildEmbeds(pcParts)
    
    local currentUnix = os.time()
    local nextRestockUnix = currentUnix + 3600 
    if StockServiceModule then pcall(function() nextRestockUnix = math.floor(currentUnix + StockServiceModule:TimeUntilRestock(shopId)) end) end
    
    table.insert(embedsArray, {
        title = "⏱️ Info", color = 3447003,
        description = string.format("🔴 **Next Restock:** <t:%d:t> (<t:%d:R>)\n⚙️ **PC:** %s | **Grocery:** %s", nextRestockUnix, nextRestockUnix, (MasterPC and "🟢 ON" or "🔴 OFF"), (MasterGrocery and "🟢 ON" or "🔴 OFF")),
        footer = { text = "LABA BABY HUB" }, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    local restockPayload = { username = "Laba Baby Hub", embeds = embedsArray }
    if mentionEveryone then restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & SNIPED!**" end
    sendWebhook(restockPayload)
end)

-- ==========================================
-- AUTO EXTINGUISH LOOP 
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoExtinguish and not IsShopping and not IsBusy then
            pcall(function()
                local player = Players.LocalPlayer
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                
                if not hrp or not humanoid then return end
                
                local fireFound = nil
                local firePart = nil
                local isPrompt = false
                
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local name = obj.Name:lower()
                    if obj:IsA("ProximityPrompt") and (name:match("extinguish") or obj.ActionText:lower():match("extinguish") or obj.ObjectText:lower():match("fire")) then
                        fireFound = obj; firePart = obj.Parent; isPrompt = true break
                    elseif (obj:IsA("ParticleEmitter") or obj:IsA("Fire")) and (name:match("fire") or name:match("flame")) then
                        local part = obj.Parent
                        if part and part:IsA("BasePart") then fireFound = obj; firePart = part break end
                    end
                end
                
                if fireFound and firePart then
                    refreshCafePosition()
                    local targetPos = firePart.Position
                    if MyCafePos and (targetPos - MyCafePos).Magnitude > 200 then return end
                    
                    IsBusy = true 
                    humanoid:UnequipTools()
                    task.wait(0.2)
                    
                    hrp.CFrame = CFrame.new(targetPos) * CFrame.new(0, 3, -4)
                    task.wait(0.2)
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
                    task.wait(0.3)
                    if humanoid then humanoid.Sit = false end
                    
                    local extTool = nil
                    local backpack = player:FindFirstChild("Backpack")
                    if backpack then
                        for _, t in ipairs(backpack:GetChildren()) do
                            if t:IsA("Tool") and (t.Name:lower():match("extinguish") or t.Name:lower():match("fire")) then extTool = t break end
                        end
                    end
                    
                    if extTool then
                        humanoid:EquipTool(extTool)
                        local isEquipped = false
                        for w = 1, 15 do if extTool.Parent == char then isEquipped = true break end task.wait(0.1) end
                        
                        if isEquipped then
                            for i = 1, 10 do
                                if extTool.Parent == char then
                                    extTool:Activate()
                                    VirtualUser:ClickButton1(Vector2.new())
                                    if isPrompt and fireproximityprompt then
                                        local oldLOS = fireFound.RequiresLineOfSight
                                        fireFound.RequiresLineOfSight = false
                                        fireFound.MaxActivationDistance = 50
                                        fireproximityprompt(fireFound)
                                        fireFound.RequiresLineOfSight = oldLOS
                                    end
                                end
                                task.wait(0.5) 
                            end
                            task.wait(1.5) 
                        end
                    end
                    humanoid:UnequipTools()
                    IsBusy = false 
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO CLEAN LOOP
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoClean and not IsShopping and not IsBusy then
            pcall(function()
                local currentClockTime = Lighting.ClockTime
                if currentClockTime >= 18 or currentClockTime <= 6 then
                    local player = Players.LocalPlayer
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                    
                    if not hrp or not humanoid then return end
                    
                    local messFound = nil
                    local messPos = nil
                    local messType = nil 
                    
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local actionMatch = obj.ActionText:lower():match("clean")
                            local objectText = obj.ObjectText:lower()
                            if actionMatch and (objectText:match("mess") or objectText:match("glass")) then
                                messFound = obj; messPos = obj.Parent.Position; messType = objectText:match("glass") and "glass" or "mess" break
                            end
                        end
                    end
                    
                    if messFound and messPos then
                        refreshCafePosition()
                        if MyCafePos and (messPos - MyCafePos).Magnitude > 200 then return end
                        IsBusy = true 
                        humanoid:UnequipTools()
                        task.wait(0.2)
                        
                        hrp.CFrame = CFrame.new(messPos) * CFrame.new(0, 2.5, 2.5)
                        task.wait(0.2)
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(messPos.X, hrp.Position.Y, messPos.Z))
                        task.wait(0.3)
                        if humanoid then humanoid.Sit = false end
                        
                        local targetToolName = (messType == "glass") and "towel" or "walis"
                        local toolToEquip = nil
                        local backpack = player:FindFirstChild("Backpack")
                        
                        if backpack then
                            for _, t in ipairs(backpack:GetChildren()) do
                                if t:IsA("Tool") and t.Name:lower():match(targetToolName) then toolToEquip = t break end
                            end
                        end
                        
                        if toolToEquip then
                            humanoid:EquipTool(toolToEquip)
                            local isEquipped = false
                            for w = 1, 15 do if toolToEquip.Parent == char then isEquipped = true break end task.wait(0.1) end
                            
                            if isEquipped then
                                for i = 1, 8 do
                                    if toolToEquip.Parent == char then
                                        toolToEquip:Activate()
                                        VirtualUser:ClickButton1(Vector2.new())
                                        if fireproximityprompt then
                                            local oldLOS = messFound.RequiresLineOfSight
                                            messFound.RequiresLineOfSight = false
                                            messFound.MaxActivationDistance = 50
                                            fireproximityprompt(messFound)
                                            messFound.RequiresLineOfSight = oldLOS
                                        end
                                    end
                                    task.wait(0.6) 
                                end
                                task.wait(1.5) 
                            end
                        end
                        humanoid:UnequipTools()
                        IsBusy = false 
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO APPOINT LOOP
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoAppoint and not IsShopping and not IsBusy then 
            pcall(function()
                local player = Players.LocalPlayer
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                local mainUi = player.PlayerGui:FindFirstChild("MainUi")
                local serverFrame = mainUi and mainUi:FindFirstChild("ServerFrame")
                
                if hrp and serverFrame and not serverFrame.Visible then
                    refreshCafePosition()
                    local closestPrompt = nil
                    
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local n, o, a = obj.Name:lower(), obj.ObjectText:lower(), obj.ActionText:lower()
                            if not a:match("sit") and not n:match("chair") and not o:match("chair") then
                                if n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server") then
                                    if obj.Parent and obj.Parent:IsA("BasePart") and MyCafePos then
                                        if (obj.Parent.Position - MyCafePos).Magnitude < 150 then
                                            closestPrompt = obj
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    local hasCustomer = false
                    local npcInfo = serverFrame:FindFirstChild("NpcInfo")
                    if npcInfo and npcInfo.Visible then hasCustomer = true end
                    
                    if closestPrompt and not hasCustomer then
                        local laptopPos = closestPrompt.Parent.Position
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                                local hum = obj:FindFirstChild("Humanoid")
                                local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                                if root and hum and not hum.Sit and (root.Position - laptopPos).Magnitude < 25 then
                                    hasCustomer = true break
                                end
                            end
                        end
                    end
                    
                    if closestPrompt and hasCustomer and not IsShopping then
                        IsBusy = true
                        local part = closestPrompt.Parent
                        hrp.CFrame = part.CFrame * CFrame.new(0, 3, 2.5)
                        task.wait(0.2)
                        if humanoid then humanoid.Sit = false end
                        task.wait(0.3) 
                        if fireproximityprompt then
                            local oldLOS = closestPrompt.RequiresLineOfSight
                            closestPrompt.RequiresLineOfSight = false
                            closestPrompt.MaxActivationDistance = 50 
                            fireproximityprompt(closestPrompt)
                            closestPrompt.RequiresLineOfSight = oldLOS
                        end
                        task.wait(1)
                        IsBusy = false
                    end
                end
                
                if serverFrame and serverFrame.Visible and not IsShopping then
                    local pcList = serverFrame:FindFirstChild("PcList")
                    if pcList then
                        for _, pcFrame in ipairs(pcList:GetChildren()) do
                            if not AutoAppoint or IsShopping then break end
                            if pcFrame:IsA("Frame") then
                                local pcName = pcFrame.Name
                                if SelectPCRemote and AppointRemote then
                                    SelectPCRemote:FireServer(pcName)
                                    task.wait(0.05)
                                    AppointRemote:FireServer(pcName)
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO CHEF 
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoChef and not IsShopping and not IsBusy then
            pcall(function()
                local player = Players.LocalPlayer
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                local mainUi = player.PlayerGui:FindFirstChild("MainUi")
                
                if not mainUi or not hrp then return end
                
                local trayItems = {}
                local trayList = mainUi:FindFirstChild("Tray") and mainUi.Tray:FindFirstChild("ListFrame")
                if trayList then
                    for _, v in ipairs(trayList:GetChildren()) do
                        if v:IsA("Frame") and v:GetAttribute("TrayRuntimeCard") then table.insert(trayItems, v) end
                    end
                end
                
                if #trayItems > 0 and not IsShopping then
                    local equippedItem = nil
                    local firstItem = trayItems[1]
                    
                    for _, item in ipairs(trayItems) do
                        local stroke = item:FindFirstChildWhichIsA("UIStroke")
                        if stroke and stroke.Thickness == 4 then equippedItem = item break end
                    end
                    
                    if not equippedItem then
                        local rawId = firstItem.Name:gsub("TrayOrder_", "")
                        local orderId = tonumber(rawId) or rawId 
                        if SelectTrayOrder then SelectTrayOrder:FireServer(orderId) end
                        task.wait(0.5)
                        return 
                    end
                    
                    local pcLabel = equippedItem:FindFirstChild("PcNumber")
                    if pcLabel then
                        local targetPCNumber = pcLabel.Text:match("%d+")
                        if targetPCNumber then
                            refreshCafePosition()
                            local foundPC = nil
                            local shortestDist = 400 
                            local validPrefixes = {"pc", "desk", "table", "computer"}
                            
                            for _, obj in ipairs(workspace:GetDescendants()) do
                                if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
                                    local rawName = obj.Name:lower():gsub("%s+", ""):gsub("_", "")
                                    local isMatch = false
                                    if rawName == targetPCNumber then isMatch = true
                                    else
                                        for _, prefix in ipairs(validPrefixes) do
                                            if rawName == prefix .. targetPCNumber then isMatch = true break end
                                        end
                                    end
                                    
                                    if isMatch then
                                        local pos
                                        if obj:IsA("Model") then pos = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetModelCFrame().Position
                                        elseif obj:IsA("BasePart") then pos = obj.Position end
                                        if pos then
                                            if MyCafePos and (pos - MyCafePos).Magnitude > 200 then continue end
                                            local dist = (hrp.Position - pos).Magnitude
                                            if dist < shortestDist then shortestDist = dist; foundPC = obj end
                                        end
                                    end
                                end
                            end
                            
                            if foundPC and not IsShopping then
                                IsBusy = true
                                local pcPos
                                if foundPC:IsA("Model") then pcPos = foundPC.PrimaryPart and foundPC.PrimaryPart.Position or foundPC:GetModelCFrame().Position
                                else pcPos = foundPC.Position end
                                
                                local targetNPC = nil
                                local closestNPCDist = 15
                                
                                for _, model in ipairs(workspace:GetDescendants()) do
                                    if model:IsA("Model") and model:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(model) then
                                        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                                        if root then
                                            local dist = (root.Position - pcPos).Magnitude
                                            if dist < closestNPCDist then closestNPCDist = dist; targetNPC = model end
                                        end
                                    end
                                end
                                
                                if targetNPC then
                                    local npcRoot = targetNPC:FindFirstChild("HumanoidRootPart") or targetNPC.PrimaryPart
                                    local targetPos = (npcRoot.CFrame * CFrame.new(0, 0, 3.5)).Position + Vector3.new(0, 2.5, 0)
                                    hrp.CFrame = CFrame.lookAt(targetPos, npcRoot.Position)
                                else hrp.CFrame = CFrame.new(pcPos) * CFrame.new(0, 3, -4) end
                                
                                task.wait(0.2)
                                if humanoid then humanoid.Sit = false end
                                task.wait(0.3)
                                
                                if fireproximityprompt then
                                    for _, prompt in ipairs(workspace:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") then
                                            local part = prompt.Parent
                                            if part and part:IsA("BasePart") then
                                                if (part.Position - hrp.Position).Magnitude < 15 then
                                                    local a = prompt.ActionText:lower()
                                                    local o = prompt.ObjectText:lower()
                                                    if not a:match("sit") and not o:match("chair") and not o:match("seat") then 
                                                        local oldLOS = prompt.RequiresLineOfSight
                                                        prompt.RequiresLineOfSight = false
                                                        fireproximityprompt(prompt)
                                                        prompt.RequiresLineOfSight = oldLOS
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                task.wait(1)
                                IsBusy = false
                            end
                        end
                    end
                end
                
                if #trayItems < 3 and not IsShopping then
                    local prepFrame = mainUi:FindFirstChild("Cooking") and mainUi.Cooking:FindFirstChild("PreparingFrame")
                    if prepFrame then
                        for _, v in ipairs(prepFrame:GetChildren()) do
                            if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") then
                                local btn = v:FindFirstChild("Button", true)
                                if btn and btn.Text == "Deliver" and DeliverEvent then
                                    local orderId = tonumber(v.Name) or v.Name
                                    DeliverEvent:FireServer(orderId)
                                    task.wait(0.5)
                                    return
                                end
                            end
                        end
                    end
                    
                    local snackOrders = mainUi:FindFirstChild("SnacksDeliver") and mainUi.SnacksDeliver:FindFirstChild("OrdersFrame")
                    if snackOrders then
                        for _, v in ipairs(snackOrders:GetChildren()) do
                            if v:IsA("Frame") and v:GetAttribute("SnackRuntimeCard") and DeliverEvent then
                                local orderId = tonumber(v.Name) or v.Name
                                DeliverEvent:FireServer(orderId)
                                task.wait(0.5)
                                return
                            end
                        end
                    end
                    
                    local cookOrders = mainUi:FindFirstChild("Cooking") and mainUi.Cooking:FindFirstChild("OrdersFrame")
                    if cookOrders then
                        for _, v in ipairs(cookOrders:GetChildren()) do
                            if v:IsA("Frame") and v:GetAttribute("CookingRuntimeCard") and CookEvent then
                                local foodLbl = v:FindFirstChild("FoodName", true)
                                if foodLbl then
                                    local orderId = tonumber(v.Name) or v.Name
                                    CookEvent:FireServer(foodLbl.Text, orderId)
                                    task.wait(0.5)
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)
