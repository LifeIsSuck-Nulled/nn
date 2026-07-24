local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
local TargetItems = {}
local MasterAutoBuy = false 
local CurrentWebhook = "https://webhook.lewisakura.moe/api/webhooks/1530035274422161498/OxDOGd_v9FeYoou_JeSI1odFo_Wfj1oj3V5Hv1QFoRtewlihYIYdiO2DX16YtZVIyO-7"
local fetch = request or http_request or (syn and syn.request)

-- ==========================================
-- ANTI-AFK SYSTEM
-- ==========================================
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- MODULE REQUIRES
-- ==========================================
local ShopConfig, StockServiceModule, Net, ShopPurchaseRemote
pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
    Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))
    ShopPurchaseRemote = Net:RemoteEvent("ShopPurchase")
end)

-- ==========================================
-- TRUFF HUB UI SETUP (100% SAFE LOAD)
-- ==========================================
local guiName = "TruffHubGUI"
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild(guiName) then playerGui[guiName]:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = guiName
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Floating Open Button
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 130, 0, 40)
openBtn.Position = UDim2.new(0, 10, 0, 10)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Text = "🎯 Open Truff"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

-- Main Frame (Landscape for Mobile)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 450, 0, 280)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -140)
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

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "TRUFF HUB"
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.Parent = sidebar

-- Tab Container (Right Side)
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -120, 1, 0)
contentFrame.Position = UDim2.new(0, 120, 0, 0)
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
    btn.TextSize = 13
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
local snipeTab = createTab("Snipe", "🎯", 1)
local setTab = createTab("Settings", "⚙️", 2)

tabs["Home"].Visible = true
tabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 60)
tabButtons["Home"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ==========================================
-- 🏠 HOME TAB CONTENT
-- ==========================================
local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 40)
homeTitle.BackgroundTransparency = 1
homeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
homeTitle.Text = "Dashboard"
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 18
homeTitle.Parent = homeTab

local masterToggle = Instance.new("TextButton")
masterToggle.Size = UDim2.new(0.8, 0, 0, 50)
masterToggle.Position = UDim2.new(0.1, 0, 0.3, 0)
masterToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
masterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggle.Text = "⛔ MASTER AUTO-BUY: OFF"
masterToggle.Font = Enum.Font.GothamBlack
masterToggle.TextSize = 14
masterToggle.Parent = homeTab
Instance.new("UICorner", masterToggle).CornerRadius = UDim.new(0, 8)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 0, 30)
statusText.Position = UDim2.new(0, 0, 0.6, 0)
statusText.BackgroundTransparency = 1
statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
statusText.Text = "Status: 🛡️ Anti-AFK Active | 📡 Waiting for Server..."
statusText.Font = Enum.Font.GothamSemibold
statusText.TextSize = 12
statusText.Parent = homeTab

masterToggle.MouseButton1Click:Connect(function()
    MasterAutoBuy = not MasterAutoBuy
    if MasterAutoBuy then
        masterToggle.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        masterToggle.Text = "✅ MASTER AUTO-BUY: ACTIVE"
        
        -- INSTANT SNIPE CHECK: Awtomatikong maghahanap kung may available na target ngayon
        task.spawn(function()
            pcall(function()
                if StockServiceModule and ShopPurchaseRemote then
                    local shops = {"PcParts", "Grocery"}
                    for _, shopId in ipairs(shops) do
                        local currentStock = StockServiceModule:GetAll(shopId)
                        if type(currentStock) == "table" then
                            for itemName, quantity in pairs(currentStock) do
                                if type(quantity) == "number" and quantity > 0 and TargetItems[itemName] then
                                    print("[INSTANT SNIPE] Found " .. itemName .. " in current stock! Buying...")
                                    ShopPurchaseRemote:FireServer(shopId, itemName, quantity)
                                end
                            end
                        end
                    end
                end
            end)
        end)
    else
        masterToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        masterToggle.Text = "⛔ MASTER AUTO-BUY: OFF"
    end
end)

-- ==========================================
-- 🎯 SNIPE TAB CONTENT
-- ==========================================
local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Size = UDim2.new(0.9, 0, 0, 30)
dropdownBtn.Position = UDim2.new(0.05, 0, 0, 10)
dropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
dropdownBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
dropdownBtn.Text = "Category: ALL ▼"
dropdownBtn.Font = Enum.Font.GothamSemibold
dropdownBtn.TextSize = 12
dropdownBtn.Parent = snipeTab
Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", dropdownBtn).Color = Color3.fromRGB(60, 60, 70)

local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(0.9, 0, 1, -55)
itemScroll.Position = UDim2.new(0.05, 0, 0, 45)
itemScroll.BackgroundTransparency = 1
itemScroll.ScrollBarThickness = 4
itemScroll.Parent = snipeTab
local itemLayout = Instance.new("UIListLayout", itemScroll)
itemLayout.Padding = UDim.new(0, 4)

local dropdownFrame = Instance.new("ScrollingFrame")
dropdownFrame.Size = UDim2.new(0.9, 0, 0, 150)
dropdownFrame.Position = UDim2.new(0.05, 0, 0, 45)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
dropdownFrame.ScrollBarThickness = 4
dropdownFrame.ZIndex = 10
dropdownFrame.Visible = false
dropdownFrame.Parent = snipeTab
Instance.new("UICorner", dropdownFrame)
local dropLayout = Instance.new("UIListLayout", dropdownFrame)

local guiItems = {}
local categories = { ["All"] = true }

if ShopConfig and type(ShopConfig.Items) == "table" then
    for itemName, itemData in pairs(ShopConfig.Items) do
        local cat = itemData.Category or "Other"
        categories[cat] = true
        table.insert(guiItems, {
            name = tostring(itemName),
            category = cat,
            stars = itemData.Stars or 0,
            price = itemData.Price or 0
        })
    end
end

table.sort(guiItems, function(a, b)
    if a.stars ~= b.stars then return a.stars > b.stars
    else return a.price > b.price end
end)

local currentFilter = "All"

local function refreshItemList()
    for _, child in ipairs(itemScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, item in ipairs(guiItems) do
        if currentFilter == "All" or item.category == currentFilter then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = TargetItems[item.name] and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(35, 35, 40)
            local starDisplay = string.rep("⭐", item.stars)
            btn.Text = (TargetItems[item.name] and " ☑ " or " ☐ ") .. item.name .. " " .. starDisplay
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 12
            btn.Parent = itemScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            
            btn.MouseButton1Click:Connect(function()
                if TargetItems[item.name] then
                    TargetItems[item.name] = nil
                    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                    btn.Text = " ☐ " .. item.name .. " " .. starDisplay
                else
                    TargetItems[item.name] = true
                    btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
                    btn.Text = " ☑ " .. item.name .. " " .. starDisplay
                    
                    -- INSTANT SNIPE CHECK kapag dinagdag sa listahan habang ON ang master switch
                    if MasterAutoBuy then
                        task.spawn(function()
                            pcall(function()
                                if StockServiceModule and ShopPurchaseRemote then
                                    local shopId = (item.category == "Grocery") and "Grocery" or "PcParts"
                                    local currentStock = StockServiceModule:GetAll(shopId)
                                    if type(currentStock) == "table" and type(currentStock[item.name]) == "number" and currentStock[item.name] > 0 then
                                        print("[INSTANT SNIPE] Newly targeted item bought! " .. item.name)
                                        ShopPurchaseRemote:FireServer(shopId, item.name, currentStock[item.name])
                                    end
                                end
                            end)
                        end)
                    end
                end
            end)
        end
    end
    task.wait(0.1)
    itemScroll.CanvasSize = UDim2.new(0, 0, 0, itemLayout.AbsoluteContentSize.Y + 10)
end

for cat, _ in pairs(categories) do
    local choiceBtn = Instance.new("TextButton")
    choiceBtn.Size = UDim2.new(1, 0, 0, 30)
    choiceBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    choiceBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    choiceBtn.Text = cat
    choiceBtn.Font = Enum.Font.GothamMedium
    choiceBtn.TextSize = 12
    choiceBtn.ZIndex = 11
    choiceBtn.Parent = dropdownFrame
    
    choiceBtn.MouseButton1Click:Connect(function()
        currentFilter = cat
        dropdownBtn.Text = "Category: " .. string.upper(cat) .. " ▼"
        dropdownFrame.Visible = false
        refreshItemList()
    end)
end
dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, dropLayout.AbsoluteContentSize.Y)

dropdownBtn.MouseButton1Click:Connect(function() dropdownFrame.Visible = not dropdownFrame.Visible end)
refreshItemList()

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
-- WEBHOOK FUNCTION
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

-- ==========================================
-- RESTOCK TRACKER LOGIC
-- ==========================================
local stockSync = ReplicatedStorage:WaitForChild("StockServiceSync")
stockSync.OnClientEvent:Connect(function(shopId, stockTable)
    local embedsArray = {}
    local pcParts = {}
    local groceryFood = {}
    local mentionEveryone = false
    
    statusText.Text = "Status: 🟢 Last Restock at " .. os.date("%H:%M:%S")
    
    if type(stockTable) == "table" then
        for itemName, quantity in pairs(stockTable) do
            if type(quantity) == "number" and quantity > 0 then
                
                -- AUTO BUY SNIPER
                if TargetItems[itemName] then
                    if MasterAutoBuy then
                        mentionEveryone = true
                        pcall(function() if ShopPurchaseRemote then ShopPurchaseRemote:FireServer(shopId, itemName, quantity) end end)
                    end
                end
                
                local itemData = (ShopConfig and ShopConfig.Items and ShopConfig.Items[itemName]) or {}
                local category = itemData.Category or "Others"
                local itemObj = {
                    name = tostring(itemName), quantity = quantity, price = itemData.Price or 0,
                    perHour = itemData.PerHour or 0, stars = itemData.Stars or 0, isTarget = TargetItems[itemName] or false
                }
                
                if category == "Grocery" then table.insert(groceryFood, itemObj) else table.insert(pcParts, itemObj) end
            end
        end
    end
    
    table.sort(pcParts, function(a, b)
        if a.stars ~= b.stars then return a.stars < b.stars else return a.perHour < b.perHour end
    end)
    table.sort(groceryFood, function(a, b) return a.price < b.price end)
    
    local function buildEmbeds(itemList, isGrocery)
        local currentFields = {}
        local fieldCount = 0
        local function packEmbed()
            if #currentFields > 0 then
                table.insert(embedsArray, {
                    title = isGrocery and ("🛒 " .. tostring(shopId) .. " - FOOD") or ("📦 " .. tostring(shopId) .. " - PC PARTS"),
                    color = isGrocery and 16753920 or 65280, fields = currentFields
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
            if isGrocery then
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
        description = string.format("🔴 **Next Restock:** <t:%d:t> (<t:%d:R>)\n⚙️ **Sniper:** %s", nextRestockUnix, nextRestockUnix, MasterAutoBuy and "🟢 ACTIVE" or "🔴 OFF"),
        footer = { text = "Truff Hub" }, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    local restockPayload = { username = "Truff Hub", embeds = embedsArray }
    if mentionEveryone and MasterAutoBuy then restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & SNIPED!**" end
    sendWebhook(restockPayload)
end)

sendWebhook({username = "Truff Hub", embeds = {{title = "HETO NA ANG INIWAN", description = "Truff Hub is Online. Master Auto-Buy is OFF.", color = 3447003}}})
