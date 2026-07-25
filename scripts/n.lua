local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
local TargetItemsPC = {}
local TargetItemsGrocery = {}
local MasterPC = false 
local MasterGrocery = false 
local AutoAppoint = false 
local AutoChef = false 
local IsShopping = false -- TASK LOCK PARA HINDI MAG-AGAWAN SA TELEPORT
local CurrentWebhook = "https://webhook.lewisakura.moe/api/webhooks/1530035274422161498/OxDOGd_v9FeYoou_JeSI1odFo_Wfj1oj3V5Hv1QFoRtewlihYIYdiO2DX16YtZVIyO-7"
local fetch = request or http_request or (syn and syn.request)

-- CAFE MEMORY LOCK
local MyHomeLaptop = nil
local MyCafePos = nil

-- Shop Coordinates para sa Auto-Buy TP
local ShopCFrame = CFrame.new(-240.48721313476562, 7.888942718505859, 136.32080078125)

-- ==========================================
-- ANTI-AFK SYSTEM
-- ==========================================
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- MODULE REQUIRES & REMOTES
-- ==========================================
local ShopConfig, StockServiceModule, Net
local ShopPurchaseRemote, SelectPCRemote, AppointRemote
local CookEvent, DeliverEvent, SelectTrayOrder, AdminRemote

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
    
    -- ADMIN EXPLOIT REMOTE
    local impEvents = ReplicatedStorage:FindFirstChild("IMPORTANT_REMOTE_EVENTS")
    if impEvents then
        AdminRemote = impEvents:FindFirstChild("AdminMoneyTest")
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

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 130, 0, 40)
openBtn.Position = UDim2.new(0, 10, 0, 10)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Text = "🎯 Open Menu"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 380) 
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Draggable = true 
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(60, 60, 70)

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
sidebar.Size = UDim2.new(0, 140, 1, 0)
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
local setTab = createTab("Settings", "⚙️", 3)
local adminTab = createTab("Admin", "⚡", 4)

tabs["Home"].Visible = true
tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60)
tabButtons["Home"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- INSTANT SNIPE FUNCTION (WITH LOCK & TP)
-- ==========================================
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
                    
                    if #itemsToBuy > 0 then
                        IsShopping = true -- I-PAUSE ANG IBANG TASKS
                        local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local returnCF = nil
                        
                        if hrp then
                            returnCF = hrp.CFrame
                            hrp.CFrame = ShopCFrame
                            task.wait(0.5) 
                        end
                        
                        for _, item in ipairs(itemsToBuy) do
                            ShopPurchaseRemote:FireServer(shopId, item.name, item.qty)
                        end
                        
                        task.wait(0.5) 
                        
                        if hrp and returnCF then
                            hrp.CFrame = returnCF
                            task.wait(0.2)
                        end
                        
                        IsShopping = false -- I-RESUME ANG MGA TASKS
                    end
                end
            end
        end)
    end)
end

-- ==========================================
-- AUTO APPOINT LOOP (WITH BASE MEMORY)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoAppoint and not IsShopping then 
            pcall(function()
                local player = Players.LocalPlayer
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                local mainUi = player.PlayerGui:FindFirstChild("MainUi")
                local serverFrame = mainUi and mainUi:FindFirstChild("ServerFrame")
                
                if hrp and serverFrame and not serverFrame.Visible then
                    
                    local closestPrompt = MyHomeLaptop
                    
                    if not closestPrompt or not closestPrompt.Parent then
                        local shortestDistance = math.huge
                        
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj:IsA("ProximityPrompt") then
                                local n, o, a, pName = obj.Name:lower(), obj.ObjectText:lower(), obj.ActionText:lower(), (obj.Parent and obj.Parent.Name:lower() or "")
                                if a:match("sit") or n:match("chair") or o:match("chair") or pName:match("chair") then continue end
                                
                                if n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server") or pName:match("laptop") then
                                    local part = obj.Parent
                                    if part and part:IsA("BasePart") then
                                        local dist = (hrp.Position - part.Position).Magnitude
                                        if dist < shortestDistance and dist < 150 then
                                            shortestDistance = dist
                                            closestPrompt = obj
                                        end
                                    end
                                end
                            end
                        end
                        
                        if closestPrompt then
                            MyHomeLaptop = closestPrompt
                            MyCafePos = closestPrompt.Parent.Position
                        end
                    end
                    
                    local hasCustomer = false
                    local npcInfo = serverFrame:FindFirstChild("NpcInfo")
                    if npcInfo and npcInfo.Visible then
                        hasCustomer = true
                    end
                    
                    if closestPrompt and not hasCustomer then
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
                    
                    if closestPrompt and hasCustomer and not IsShopping then
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
-- AUTO CHEF (WITH CAFE MEMORY LOCK & SHOP PAUSE)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoChef and not IsShopping then
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
                        if v:IsA("Frame") and v:GetAttribute("TrayRuntimeCard") then
                            table.insert(trayItems, v)
                        end
                    end
                end
                
                if #trayItems > 0 and not IsShopping then
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
                        if SelectTrayOrder then
                            SelectTrayOrder:FireServer(orderId)
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
                            local validPrefixes = {"pc", "desk", "table", "computer"}
                            
                            for _, obj in ipairs(workspace:GetDescendants()) do
                                if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
                                    local rawName = obj.Name:lower():gsub("%s+", ""):gsub("_", "")
                                    local isMatch = false
                                    
                                    if rawName == targetPCNumber then
                                        isMatch = true
                                    else
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
                                            pos = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetModelCFrame().Position
                                        elseif obj:IsA("BasePart") then
                                            pos = obj.Position
                                        end
                                        
                                        if pos then
                                            if MyCafePos and (pos - MyCafePos).Magnitude > 200 then
                                                continue 
                                            end
                                            
                                            local dist = (hrp.Position - pos).Magnitude
                                            if dist < shortestDist then
                                                shortestDist = dist
                                                foundPC = obj
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if foundPC and not IsShopping then
                                local pcPos
                                if foundPC:IsA("Model") then
                                    pcPos = foundPC.PrimaryPart and foundPC.PrimaryPart.Position or foundPC:GetModelCFrame().Position
                                else
                                    pcPos = foundPC.Position
                                end
                                
                                local targetNPC = nil
                                local closestNPCDist = 15
                                
                                for _, model in ipairs(workspace:GetDescendants()) do
                                    if model:IsA("Model") and model:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(model) then
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
                                    local targetPos = (npcRoot.CFrame * CFrame.new(0, 0, 3.5)).Position + Vector3.new(0, 2.5, 0)
                                    hrp.CFrame = CFrame.lookAt(targetPos, npcRoot.Position)
                                else
                                    hrp.CFrame = CFrame.new(pcPos) * CFrame.new(0, 3, -4)
                                end
                                
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

-- ==========================================
-- 🏠 HOME TAB CONTENT
-- ==========================================
local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 30)
homeTitle.BackgroundTransparency = 1
homeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
homeTitle.Text = "Dashboard Controls"
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 16
homeTitle.Parent = homeTab

local togglePC = Instance.new("TextButton")
togglePC.Size = UDim2.new(0.85, 0, 0, 45)
togglePC.Position = UDim2.new(0.075, 0, 0.10, 0)
togglePC.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
togglePC.TextColor3 = Color3.fromRGB(255, 255, 255)
togglePC.Text = "💻 PC AUTO-BUY: OFF"
togglePC.Font = Enum.Font.GothamBlack
togglePC.TextSize = 13
togglePC.Parent = homeTab
Instance.new("UICorner", togglePC).CornerRadius = UDim.new(0, 6)

local toggleGrocery = Instance.new("TextButton")
toggleGrocery.Size = UDim2.new(0.85, 0, 0, 45)
toggleGrocery.Position = UDim2.new(0.075, 0, 0.28, 0)
toggleGrocery.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleGrocery.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleGrocery.Text = "🍎 GROCERY AUTO-BUY: OFF"
toggleGrocery.Font = Enum.Font.GothamBlack
toggleGrocery.TextSize = 13
toggleGrocery.Parent = homeTab
Instance.new("UICorner", toggleGrocery).CornerRadius = UDim.new(0, 6)

local toggleAppoint = Instance.new("TextButton")
toggleAppoint.Size = UDim2.new(0.85, 0, 0, 45)
toggleAppoint.Position = UDim2.new(0.075, 0, 0.46, 0)
toggleAppoint.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleAppoint.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleAppoint.Text = "🧑‍💻 AUTO APPOINT: OFF"
toggleAppoint.Font = Enum.Font.GothamBlack
toggleAppoint.TextSize = 13
toggleAppoint.Parent = homeTab
Instance.new("UICorner", toggleAppoint).CornerRadius = UDim.new(0, 6)

local toggleChef = Instance.new("TextButton")
toggleChef.Size = UDim2.new(0.85, 0, 0, 45)
toggleChef.Position = UDim2.new(0.075, 0, 0.64, 0)
toggleChef.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleChef.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleChef.Text = "🍳 AUTO CHEF: OFF"
toggleChef.Font = Enum.Font.GothamBlack
toggleChef.TextSize = 13
toggleChef.Parent = homeTab
Instance.new("UICorner", toggleChef).CornerRadius = UDim.new(0, 6)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 0, 30)
statusText.Position = UDim2.new(0, 0, 0.82, 0)
statusText.BackgroundTransparency = 1
statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
statusText.Text = "Status: 🛡️ Anti-AFK Active | 📡 Waiting for Server..."
statusText.Font = Enum.Font.GothamSemibold
statusText.TextSize = 12
statusText.Parent = homeTab

togglePC.MouseButton1Click:Connect(function()
    MasterPC = not MasterPC
    if MasterPC then
        togglePC.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        togglePC.Text = "💻 PC AUTO-BUY: ACTIVE"
        triggerInstantSnipe("PcParts", TargetItemsPC)
    else
        togglePC.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        togglePC.Text = "💻 PC AUTO-BUY: OFF"
    end
end)

toggleGrocery.MouseButton1Click:Connect(function()
    MasterGrocery = not MasterGrocery
    if MasterGrocery then
        toggleGrocery.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        toggleGrocery.Text = "🍎 GROCERY AUTO-BUY: ACTIVE"
        triggerInstantSnipe("Grocery", TargetItemsGrocery)
    else
        toggleGrocery.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        toggleGrocery.Text = "🍎 GROCERY AUTO-BUY: OFF"
    end
end)

toggleAppoint.MouseButton1Click:Connect(function()
    AutoAppoint = not AutoAppoint
    if AutoAppoint then
        toggleAppoint.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        toggleAppoint.Text = "🧑‍💻 AUTO APPOINT: ACTIVE"
    else
        toggleAppoint.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        toggleAppoint.Text = "🧑‍💻 AUTO APPOINT: OFF"
    end
end)

toggleChef.MouseButton1Click:Connect(function()
    AutoChef = not AutoChef
    if AutoChef then
        toggleChef.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        toggleChef.Text = "🍳 AUTO CHEF: ACTIVE"
    else
        toggleChef.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        toggleChef.Text = "🍳 AUTO CHEF: OFF"
    end
end)

-- ==========================================
-- DATA PROCESSING (SPLIT PC & GROCERY)
-- ==========================================
local guiItemsPC = {}
local guiItemsGrocery = {}
local pcCategories = { ["All"] = true }

if ShopConfig and type(ShopConfig.Items) == "table" then
    for itemName, itemData in pairs(ShopConfig.Items) do
        local cat = itemData.Category or "Other"
        local itemEntry = {
            name = tostring(itemName),
            category = cat,
            stars = itemData.Stars or 0,
            price = itemData.Price or 0
        }
        if cat == "Grocery" then
            table.insert(guiItemsGrocery, itemEntry)
        else
            pcCategories[cat] = true
            table.insert(guiItemsPC, itemEntry)
        end
    end
end

local function sortItems(a, b)
    if a.stars ~= b.stars then return a.stars > b.stars
    else return a.price > b.price end
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

for cat, _ in pairs(pcCategories) do
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
pcDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, pcDropLayout.AbsoluteContentSize.Y)
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
task.spawn(function()
    task.wait(0.2)
    grocScroll.CanvasSize = UDim2.new(0, 0, 0, grocLayout.AbsoluteContentSize.Y + 10)
end)

-- ==========================================
-- ⚙️ SETTINGS TAB CONTENT
-- ==========================================
local setLabel = Instance.new("TextLabel")
setLabel.Size = UDim2.new(0.9, 0, 0, 30)
setLabel.Position = UDim2.new(0.05, 0, 0, 20)
setLabel.BackgroundTransparency = 1
setLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
setLabel.Text = "Discord Webhook URL:"
setLabel.TextXAlignment = Enum.TextXAlignment.Left
setLabel.Font = Enum.Font.GothamSemibold
setLabel.TextSize = 13
setLabel.Parent = setTab

local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(0.9, 0, 0, 40)
webhookBox.Position = UDim2.new(0.05, 0, 0, 50)
webhookBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
webhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
webhookBox.Text = CurrentWebhook
webhookBox.TextXAlignment = Enum.TextXAlignment.Left
webhookBox.ClearTextOnFocus = false
webhookBox.TextTruncate = Enum.TextTruncate.AtEnd
webhookBox.Font = Enum.Font.Gotham
webhookBox.TextSize = 11
webhookBox.Parent = setTab
Instance.new("UICorner", webhookBox).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", webhookBox).Color = Color3.fromRGB(60, 60, 70)

webhookBox.FocusLost:Connect(function()
    CurrentWebhook = webhookBox.Text
    print("[Settings] Webhook URL Updated!")
end)

-- ==========================================
-- ⚡ ADMIN TAB CONTENT
-- ==========================================
local adminHeader = Instance.new("TextLabel")
adminHeader.Size = UDim2.new(0.9, 0, 0, 30)
adminHeader.Position = UDim2.new(0.05, 0, 0, 10)
adminHeader.BackgroundTransparency = 1
adminHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
adminHeader.Text = "Admin Exploits"
adminHeader.Font = Enum.Font.GothamBold
adminHeader.TextSize = 14
adminHeader.Parent = adminTab

local amountBox = Instance.new("TextBox")
amountBox.Size = UDim2.new(0.9, 0, 0, 35)
amountBox.Position = UDim2.new(0.05, 0, 0, 45)
amountBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
amountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
amountBox.Text = "1000000"
amountBox.PlaceholderText = "Enter Amount..."
amountBox.Font = Enum.Font.Gotham
amountBox.TextSize = 12
amountBox.Parent = adminTab
Instance.new("UICorner", amountBox).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", amountBox).Color = Color3.fromRGB(60, 60, 70)

local btnAddCash = Instance.new("TextButton")
btnAddCash.Size = UDim2.new(0.9, 0, 0, 35)
btnAddCash.Position = UDim2.new(0.05, 0, 0, 90)
btnAddCash.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
btnAddCash.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAddCash.Text = "💸 Add Cash"
btnAddCash.Font = Enum.Font.GothamBold
btnAddCash.TextSize = 12
btnAddCash.Parent = adminTab
Instance.new("UICorner", btnAddCash).CornerRadius = UDim.new(0, 4)

local btnSetMoney = Instance.new("TextButton")
btnSetMoney.Size = UDim2.new(0.9, 0, 0, 35)
btnSetMoney.Position = UDim2.new(0.05, 0, 0, 135)
btnSetMoney.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
btnSetMoney.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSetMoney.Text = "💰 Set Money"
btnSetMoney.Font = Enum.Font.GothamBold
btnSetMoney.TextSize = 12
btnSetMoney.Parent = adminTab
Instance.new("UICorner", btnSetMoney).CornerRadius = UDim.new(0, 4)

local function fireAdmin(command)
    if AdminRemote then
        local amt = tonumber(amountBox.Text) or 1000000
        -- Multi-fire para siguradong tumama sa hinihinging argument ng server
        pcall(function() AdminRemote:FireServer(command, amt) end)
        pcall(function() AdminRemote:FireServer(command, Players.LocalPlayer, amt) end)
        pcall(function() AdminRemote:FireServer(command, Players.LocalPlayer.Name, amt) end)
        print("[LABA BABY HUB] Fired Admin Event: " .. command)
    else
        warn("[LABA BABY HUB] Admin Remote not found!")
    end
end

btnAddCash.MouseButton1Click:Connect(function() fireAdmin("AddCash") end)
btnSetMoney.MouseButton1Click:Connect(function() fireAdmin("SetMoney") end)

-- ==========================================
-- WEBHOOK & RESTOCK TRACKER (WITH LOCK & TP)
-- ==========================================
local function sendWebhook(payload)
    if not fetch or CurrentWebhook == "" then return end
    pcall(function()
        fetch({
            Url = CurrentWebhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

local stockSync = ReplicatedStorage:WaitForChild("StockServiceSync")
stockSync.OnClientEvent:Connect(function(shopId, stockTable)
    local embedsArray = {}
    local pcParts = {}
    local groceryFood = {}
    local mentionEveryone = false
    
    local itemsToBuy = {}
    
    statusText.Text = "Status: 🟢 Last Restock at " .. os.date("%H:%M:%S")
    
    if type(stockTable) == "table" then
        for itemName, quantity in pairs(stockTable) do
            if type(quantity) == "number" and quantity > 0 then
                
                local itemData = (ShopConfig and ShopConfig.Items and ShopConfig.Items[itemName]) or {}
                local category = itemData.Category or "Others"
                local isGrocery = (category == "Grocery")
                
                local isTargeted = false
                if isGrocery and TargetItemsGrocery[itemName] then
                    isTargeted = true
                    if MasterGrocery then
                        mentionEveryone = true
                        table.insert(itemsToBuy, {id = shopId, name = itemName, qty = quantity})
                    end
                elseif not isGrocery and TargetItemsPC[itemName] then
                    isTargeted = true
                    if MasterPC then
                        mentionEveryone = true
                        table.insert(itemsToBuy, {id = shopId, name = itemName, qty = quantity})
                    end
                end
                
                local itemObj = {
                    name = tostring(itemName), quantity = quantity, price = itemData.Price or 0,
                    perHour = itemData.PerHour or 0, stars = itemData.Stars or 0, isTarget = isTargeted
                }
                
                if isGrocery then table.insert(groceryFood, itemObj) else table.insert(pcParts, itemObj) end
            end
        end
    end
    
    if #itemsToBuy > 0 then
        IsShopping = true 
        local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local returnCF = nil
        
        if hrp then
            returnCF = hrp.CFrame
            hrp.CFrame = ShopCFrame
            task.wait(0.5) 
        end
        
        for _, item in ipairs(itemsToBuy) do
            pcall(function() ShopPurchaseRemote:FireServer(item.id, item.name, item.qty) end)
        end
        
        task.wait(0.5) 
        
        if hrp and returnCF then
            hrp.CFrame = returnCF
            task.wait(0.2)
        end
        IsShopping = false 
    end
    
    table.sort(pcParts, function(a, b)
        if a.stars ~= b.stars then return a.stars < b.stars else return a.perHour < b.perHour end
    end)
    table.sort(groceryFood, function(a, b) return a.price < b.price end)
    
    local function buildEmbeds(itemList, isGroceryCheck)
        local currentFields = {}
        local fieldCount = 0
        local function packEmbed()
            if #currentFields > 0 then
                table.insert(embedsArray, {
                    title = isGroceryCheck and ("🛒 " .. tostring(shopId) .. " - FOOD") or ("📦 " .. tostring(shopId) .. " - PC PARTS"),
                    color = isGroceryCheck and 16753920 or 65280, fields = currentFields
                })
                currentFields = {}
                fieldCount = 0
            end
        end
        for _, item in ipairs(itemList) do
            if #embedsArray >= 8 then break end 
            local safeName = item.name == "" and "Unknown Item" or item.name
            local displayName = item.isTarget and ("🎯 **" .. safeName:sub(1, 240) .. "**") or ("🔹 " .. safeName:sub(1, 250))
            
            local statsDesc
            if isGroceryCheck then
                statsDesc = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n\u{200B}", item.quantity, tostring(item.price))
            else
                local starDisplay = string.rep("⭐", item.stars)
                if item.stars == 0 then starDisplay = "N/A" end
                statsDesc = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n⚡ **Per Hour:** %s\n%s\n\u{200B}", 
                    item.quantity, tostring(item.price), tostring(item.perHour), starDisplay)
            end
            table.insert(currentFields, { name = displayName, value = statsDesc, inline = false })
            fieldCount = fieldCount + 1
            if fieldCount >= 25 then packEmbed() end
        end
        if fieldCount > 0 then packEmbed() end
    end
    
    buildEmbeds(pcParts, false)
    buildEmbeds(groceryFood, true)
    
    local currentUnix = os.time()
    local nextRestockUnix = currentUnix + 3600 
    if StockServiceModule then pcall(function() nextRestockUnix = math.floor(currentUnix + StockServiceModule:TimeUntilRestock(shopId)) end) end
    
    table.insert(embedsArray, {
        title = "⏱️ Info",
        color = 3447003,
        description = string.format("🔴 **Next Restock:** <t:%d:t> (<t:%d:R>)\n⚙️ **PC:** %s | **Grocery:** %s", nextRestockUnix, nextRestockUnix, (MasterPC and "🟢 ON" or "🔴 OFF"), (MasterGrocery and "🟢 ON" or "🔴 OFF")),
        footer = { text = "LABA BABY HUB" }, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    local restockPayload = { username = "Laba Baby Hub", embeds = embedsArray }
    if mentionEveryone then restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & SNIPED!**" end
    sendWebhook(restockPayload)
end)

sendWebhook({username = "Laba Baby Hub", embeds = {{title = "HETO NA ANG INIWAN", description = "Laba Baby Hub is Online. Toggles are OFF by default.", color = 3447003}}})
