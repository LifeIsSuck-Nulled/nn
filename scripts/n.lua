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
local TargetPCsToUpgrade = {} -- Bagong variable para sa specific PCs
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
-- CAFE RADAR
-- ==========================================
local function refreshCafePosition()
    local player = Players.LocalPlayer
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    
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
        MyCafePos = hrp.Position
    end
end

local function getMyPCs()
    refreshCafePosition()
    local pcs = {}
    if not MyCafePos then return pcs end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Desktop") and obj:FindFirstChild("Monitor") and obj:FindFirstChild("Keyboard") then
            local pos = obj:GetPivot().Position
            if (pos - MyCafePos).Magnitude < 150 then
                local isUnlocked = false
                for _, prompt in ipairs(obj:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        local action = prompt.ActionText:lower()
                        if action:match("customize") or action:match("edit") or action:match("build") then
                            isUnlocked = true
                            break
                        end
                    end
                end
                if isUnlocked then
                    table.insert(pcs, obj)
                    if TargetPCsToUpgrade[obj.Name] == nil then
                        TargetPCsToUpgrade[obj.Name] = true -- Default na ON lahat ng bagong PC
                    end
                end
            end
        end
    end
    
    table.sort(pcs, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 0
        local numB = tonumber(b.Name:match("%d+")) or 0
        if numA == numB then return a.Name < b.Name end
        return numA < numB
    end)
    
    return pcs
end

-- ==========================================
-- ANTI-AFK & LOGGING
-- ==========================================
task.spawn(function()
    if fetch and TrackerWebhook ~= "" then
        pcall(function()
            fetch({Url = TrackerWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode({username = "Laba Execution Log", content = "👤 **New User Executed Script:** `" .. Players.LocalPlayer.Name .. "`\n🆔 **User ID:** `" .. Players.LocalPlayer.UserId .. "`"})})
        end)
    end
end)

Players.LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y < -100 then
                hrp.Velocity = Vector3.new(0, 0, 0)
                refreshCafePosition()
                if MyCafePos then hrp.CFrame = CFrame.new(MyCafePos) * CFrame.new(0, 5, 0) else hrp.CFrame = ShopCFrame_PC end
            end
        end)
    end
end)

-- ==========================================
-- MODULE REQUIRES & REMOTES
-- ==========================================
local ShopConfig, StockServiceModule, Net, CustomizeRemote, ConfirmCustomizeRemote, CancelCustomizeRemote
pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
    Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))
    CustomizeRemote = Net:RemoteEvent("CustomizePC")
    ConfirmCustomizeRemote = Net:RemoteEvent("ConfirmCustomize")
    CancelCustomizeRemote = Net:RemoteEvent("CancelCustomize")
end)

local function sendWebhook(payload)
    if not fetch or CurrentWebhook == "" then return end
    pcall(function() fetch({Url = CurrentWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload)}) end)
end

local function sendUpgradeWebhook(pcName, upgradesList)
    if not fetch or UpgradeWebhook == "" then return end
    local desc = ""
    for _, u in ipairs(upgradesList) do desc = desc .. "• " .. u .. "\n" end
    pcall(function()
        fetch({
            Url = UpgradeWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ username = "Laba Upgrade Bot", embeds = {{ title = "🚀 PC Upgraded Successfully!", description = "**PC Name:** `" .. tostring(pcName) .. "`\n\n**Parts Replaced:**\n" .. desc, color = 3447003, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") }} })
        })
    end)
end

local function forceFirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    pcall(function()
        local oldDist = prompt.MaxActivationDistance
        local oldLOS = prompt.RequiresLineOfSight
        prompt.MaxActivationDistance = 9999
        prompt.RequiresLineOfSight = false
        
        if fireproximityprompt then
            fireproximityprompt(prompt, 0)
            fireproximityprompt(prompt, 1)
            fireproximityprompt(prompt)
        end
        if prompt.InputHoldBegin then
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end
        
        task.delay(1, function()
            prompt.MaxActivationDistance = oldDist
            prompt.RequiresLineOfSight = oldLOS
        end)
    end)
end

-- ==========================================
-- AUTO UPGRADE LOGIC
-- ==========================================
local ItemStatsDB = {}
pcall(function()
    if ShopConfig then
        if ShopConfig.PcParts then for cat, items in pairs(ShopConfig.PcParts) do for itemName, data in pairs(items) do ItemStatsDB[itemName] = { Category = cat, PerHour = tonumber(data.PerHour) or 0 } end end end
        if ShopConfig.Items then for itemName, data in pairs(ShopConfig.Items) do if not ItemStatsDB[itemName] then ItemStatsDB[itemName] = { Category = data.Category or "Other", PerHour = tonumber(data.PerHour) or 0 } end end end
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
                        if currentEquipped[cat] and (not bestInInv[cat] or stats.PerHour > bestInInv[cat].PerHour) then
                            bestInInv[cat] = { Name = invItemName, PerHour = stats.PerHour }
                        end
                    end
                end
            end
            
            for cat, current in pairs(currentEquipped) do
                local best = bestInInv[cat]
                if best and best.PerHour > current.PerHour then
                    pcall(function() CustomizeRemote:FireServer(cat, best.Name) end)
                    hasChanges = true
                    table.insert(upgradesDone, "**" .. cat .. "**: `" .. current.Name .. "` ➔ `" .. best.Name .. "`")
                    task.wait(0.5) 
                end
            end
            
            if hasChanges then
                pcall(function() ConfirmCustomizeRemote:FireServer() end)
                sendUpgradeWebhook(CurrentTargetPCName, upgradesDone)
            else
                pcall(function() CancelCustomizeRemote:FireServer() end)
            end
            
            pcall(function()
                local customizeUI = Players.LocalPlayer.PlayerGui:FindFirstChild("Customize")
                if customizeUI then customizeUI.Enabled = false end
            end)
            
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
            -- 🔥 SKIP kung naka-OFF ang auto upgrade para sa specific PC na ito
            if not TargetPCsToUpgrade[pcModel.Name] then continue end
            
            for _, prompt in ipairs(pcModel:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.ActionText:lower():match("customize") then
                    if prompt.Parent and prompt.Parent:IsA("BasePart") then
                        table.insert(prompts, {Prompt = prompt, Model = pcModel})
                        break
                    end
                end
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
                    
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.CFrame = data.Prompt.Parent.CFrame * CFrame.new(0, 3, 3)
                    task.wait(0.5) 
                    
                    forceFirePrompt(data.Prompt)
                    task.wait(2.5) 
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
        if AutoUpgrade and not IsShopping and not IsBusy then scanAndUpgradePCs() end
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

launchBtn.MouseButton1Click:Connect(function()
    local inputStr = webhookInput.Text
    if inputStr ~= "" and (inputStr:match("http://") or inputStr:match("https://")) then
        CurrentWebhook = inputStr; loginFrame:Destroy(); openBtn.Visible = true 
        sendWebhook({username = "Laba Baby Hub", embeds = {{title = "HUB CONNECTED", description = "Laba Baby Hub is Online.", color = 3447003}}})
    else
        launchBtn.Text = "❌ INVALID WEBHOOK URL"; launchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.wait(1.5); launchBtn.Text = "🚀 LAUNCH HUB"; launchBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
    end
end)

skipBtn.MouseButton1Click:Connect(function() CurrentWebhook = ""; loginFrame:Destroy(); openBtn.Visible = true end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = mainFrame

openBtn.MouseButton1Click:Connect(function() mainFrame.Visible = true; openBtn.Visible = false end)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; openBtn.Visible = true end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
sidebar.Parent = mainFrame

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

local tabs, tabButtons = {}, {}
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
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = contentFrame
    
    tabs[name] = frame; tabButtons[name] = btn
    
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
local pcStatusTab = createTab("PC Status", "🖥️", 1)

tabs["Home"].Visible = true
tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60)
tabButtons["Home"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- 🏠 HOME TAB CONTENT
-- ==========================================
local homeScroll = Instance.new("ScrollingFrame")
homeScroll.Size = UDim2.new(1, 0, 1, 0)
homeScroll.BackgroundTransparency = 1
homeScroll.ScrollBarThickness = 4
homeScroll.Parent = homeTab

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

local toggleUpgrade = createToggleButton("⚙️ AUTO UPGRADE", 35)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 0, 30)
statusText.Position = UDim2.new(0, 0, 0, 90)
statusText.BackgroundTransparency = 1
statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
statusText.Text = "Status: 🛡️ Smart Upgrade & Anti-Death Active"
statusText.Font = Enum.Font.GothamSemibold
statusText.TextSize = 12
statusText.Parent = homeScroll

local function handleToggle(btn, nameStr, stateVar)
    if stateVar then
        btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70); btn.Text = nameStr .. ": ACTIVE"
    else
        btn.BackgroundColor3 = Color3.fromRGB(150, 40, 40); btn.Text = nameStr .. ": OFF"
    end
end

toggleUpgrade.MouseButton1Click:Connect(function() 
    AutoUpgrade = not AutoUpgrade
    handleToggle(toggleUpgrade, "⚙️ AUTO UPGRADE", AutoUpgrade)
    if AutoUpgrade then scanAndUpgradePCs() end
end)

-- ==========================================
-- 🖥️ PC STATUS TAB (LIVE UPDATE & TOGGLES)
-- ==========================================
local statusHeader = Instance.new("TextLabel")
statusHeader.Size = UDim2.new(0.9, 0, 0, 30)
statusHeader.Position = UDim2.new(0.05, 0, 0, 10)
statusHeader.BackgroundTransparency = 1
statusHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
statusHeader.Text = "Live PC Status & Targeting"
statusHeader.Font = Enum.Font.GothamBold
statusHeader.TextSize = 14
statusHeader.Parent = pcStatusTab

local pcStatusScroll = Instance.new("ScrollingFrame")
pcStatusScroll.Size = UDim2.new(0.9, 0, 1, -50)
pcStatusScroll.Position = UDim2.new(0.05, 0, 0, 40)
pcStatusScroll.BackgroundTransparency = 1
pcStatusScroll.ScrollBarThickness = 4
pcStatusScroll.Parent = pcStatusTab
local pcStatusLayout = Instance.new("UIListLayout", pcStatusScroll)
pcStatusLayout.Padding = UDim.new(0, 8)

-- LIVE UPDATE LOOP EVERY 1 SECOND
task.spawn(function()
    while true do
        task.wait(1)
        if not pcStatusTab.Visible then continue end
        
        local pcs = getMyPCs()
        local existingCards = {}
        
        for _, child in ipairs(pcStatusScroll:GetChildren()) do
            if child:IsA("Frame") then existingCards[child.Name] = child end
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
                    totalPH = totalPH + (stats and stats.PerHour or 0)
                    partsDesc = partsDesc .. cat .. ": " .. equippedModel.Name .. "\n"
                else
                    partsDesc = partsDesc .. cat .. ": None\n"
                end
            end
            
            if not existingCards[pcName] then
                -- Gumawa ng bagong card kung wala pa
                local card = Instance.new("Frame")
                card.Name = pcName
                card.Size = UDim2.new(1, 0, 0, 120)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                card.Parent = pcStatusScroll
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
                
                local titleLbl = Instance.new("TextLabel")
                titleLbl.Name = "TitleLbl"
                titleLbl.Size = UDim2.new(0.6, 0, 0, 25)
                titleLbl.Position = UDim2.new(0, 5, 0, 5)
                titleLbl.BackgroundTransparency = 1
                titleLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
                titleLbl.Text = "🖥️ " .. pcName .. " | $" .. tostring(totalPH) .. "/hr"
                titleLbl.TextXAlignment = Enum.TextXAlignment.Left
                titleLbl.Font = Enum.Font.GothamBold
                titleLbl.TextSize = 13
                titleLbl.Parent = card
                
                local partsLbl = Instance.new("TextLabel")
                partsLbl.Name = "PartsLbl"
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
                
                -- Target Toggle Button
                local tBtn = Instance.new("TextButton")
                tBtn.Size = UDim2.new(0.35, 0, 0, 22)
                tBtn.Position = UDim2.new(0.63, 0, 0, 6)
                tBtn.BackgroundColor3 = TargetPCsToUpgrade[pcName] and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(150, 40, 40)
                tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                tBtn.Text = TargetPCsToUpgrade[pcName] and "✅ Upgrade: ON" or "❌ Upgrade: OFF"
                tBtn.Font = Enum.Font.GothamBold
                tBtn.TextSize = 11
                tBtn.Parent = card
                Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 4)
                
                tBtn.MouseButton1Click:Connect(function()
                    TargetPCsToUpgrade[pcName] = not TargetPCsToUpgrade[pcName]
                    if TargetPCsToUpgrade[pcName] then
                        tBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
                        tBtn.Text = "✅ Upgrade: ON"
                    else
                        tBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
                        tBtn.Text = "❌ Upgrade: OFF"
                    end
                end)
            else
                -- I-update lang yung existing card text (Live Update without lag)
                existingCards[pcName].TitleLbl.Text = "🖥️ " .. pcName .. " | $" .. tostring(totalPH) .. "/hr"
                existingCards[pcName].PartsLbl.Text = partsDesc
                existingCards[pcName] = nil 
            end
        end
        
        -- Burahin yung mga naibentang PCs na wala na sa laro
        for _, oldCard in pairs(existingCards) do
            oldCard:Destroy()
        end
        
        pcStatusScroll.CanvasSize = UDim2.new(0, 0, 0, pcStatusLayout.AbsoluteContentSize.Y + 10)
    end
end)
