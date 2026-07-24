local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

-- Your exact webhook URL formatted to use the proxy
local WEBHOOK_URL = "https://webhook.lewisakura.moe/api/webhooks/1530035274422161498/OxDOGd_v9FeYoou_JeSI1odFo_Wfj1oj3V5Hv1QFoRtewlihYIYdiO2DX16YtZVIyO-7"

-- Delta compatibility for HTTP requests
local fetch = request or http_request or (syn and syn.request)

-- ==========================================
-- ANTI-AFK SYSTEM
-- ==========================================
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("[Anti-AFK] Automatically moved to prevent idle disconnect.")
end)
print("[Restock Tracker] Anti-AFK is now ACTIVE.")

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
local TargetItems = {}
local MasterAutoBuy = false -- Defaults to OFF for safety

-- ==========================================
-- MODULE REQUIRES & AUTO-BUY SETUP
-- ==========================================
local ShopConfig = nil
local StockServiceModule = nil
local Net = nil
local ShopPurchaseRemote = nil

pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
    Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))
    ShopPurchaseRemote = Net:RemoteEvent("ShopPurchase")
end)

-- ==========================================
-- PROFESSIONAL GUI SETUP
-- ==========================================
local guiName = "TruffProfessionalGUI"
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

if playerGui:FindFirstChild(guiName) then
    playerGui[guiName]:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = guiName
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Small floating open button
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 130, 0, 40)
openBtn.Position = UDim2.new(0, 10, 0, 10)
openBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Text = "🎯 Open Truff"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", openBtn).Color = Color3.fromRGB(60, 60, 70)

-- Main Background Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 460)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -230)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.Visible = false
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(80, 80, 90)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.Text = "Truff Sniper Configuration"
header.Font = Enum.Font.GothamBold
header.TextSize = 16
header.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -40, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = mainFrame

openBtn.MouseButton1Click:Connect(function() mainFrame.Visible = true; openBtn.Visible = false end)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; openBtn.Visible = true end)

-- Master Auto-Buy Toggle
local masterToggle = Instance.new("TextButton")
masterToggle.Size = UDim2.new(1, -20, 0, 35)
masterToggle.Position = UDim2.new(0, 10, 0, 45)
masterToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40) -- Red Default
masterToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
masterToggle.Text = "⛔ MASTER AUTO-BUY: OFF"
masterToggle.Font = Enum.Font.GothamBold
masterToggle.TextSize = 14
masterToggle.Parent = mainFrame
Instance.new("UICorner", masterToggle).CornerRadius = UDim.new(0, 6)

masterToggle.MouseButton1Click:Connect(function()
    MasterAutoBuy = not MasterAutoBuy
    if MasterAutoBuy then
        masterToggle.BackgroundColor3 = Color3.fromRGB(40, 150, 60)
        masterToggle.Text = "✅ MASTER AUTO-BUY: ACTIVE"
    else
        masterToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        masterToggle.Text = "⛔ MASTER AUTO-BUY: OFF"
    end
end)

-- Dropdown Menu Button
local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Size = UDim2.new(1, -20, 0, 30)
dropdownBtn.Position = UDim2.new(0, 10, 0, 90)
dropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
dropdownBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
dropdownBtn.Text = "Category: ALL ▼"
dropdownBtn.Font = Enum.Font.GothamSemibold
dropdownBtn.TextSize = 13
dropdownBtn.Parent = mainFrame
Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", dropdownBtn).Color = Color3.fromRGB(60, 60, 70)

-- Item Scrolling Frame
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(1, -20, 1, -135)
itemScroll.Position = UDim2.new(0, 10, 0, 125)
itemScroll.BackgroundTransparency = 1
itemScroll.ScrollBarThickness = 4
itemScroll.Parent = mainFrame

local itemLayout = Instance.new("UIListLayout", itemScroll)
itemLayout.Padding = UDim.new(0, 5)
itemLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Dropdown Selection Frame (Hidden initially, ZIndex higher so it overlays)
local dropdownFrame = Instance.new("ScrollingFrame")
dropdownFrame.Size = UDim2.new(1, -20, 0, 200)
dropdownFrame.Position = UDim2.new(0, 10, 0, 125)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
dropdownFrame.ScrollBarThickness = 4
dropdownFrame.ZIndex = 10
dropdownFrame.Visible = false
dropdownFrame.Parent = mainFrame
Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", dropdownFrame).Color = Color3.fromRGB(100, 100, 120)

local dropLayout = Instance.new("UIListLayout", dropdownFrame)
dropLayout.Padding = UDim.new(0, 2)

-- Process Game Config Data
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

-- Refresh Item List Function
local function refreshItemList()
    -- Clear current list
    for _, child in ipairs(itemScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    for _, item in ipairs(guiItems) do
        if currentFilter == "All" or item.category == currentFilter then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 32)
            btn.BackgroundColor3 = TargetItems[item.name] and Color3.fromRGB(30, 80, 40) or Color3.fromRGB(35, 35, 40)
            
            local starDisplay = string.rep("⭐", item.stars)
            if item.stars == 0 then starDisplay = "" end
            
            btn.Text = "  " .. item.name .. " " .. starDisplay
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 13
            btn.Parent = itemScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            
            -- Toggle Target
            btn.MouseButton1Click:Connect(function()
                if TargetItems[item.name] then
                    TargetItems[item.name] = nil
                    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                else
                    TargetItems[item.name] = true
                    btn.BackgroundColor3 = Color3.fromRGB(30, 80, 40)
                end
            end)
        end
    end
    -- Adjust scroll canvas
    task.wait(0.1)
    itemScroll.CanvasSize = UDim2.new(0, 0, 0, itemLayout.AbsoluteContentSize.Y + 10)
end

-- Build Dropdown Choices
for cat, _ in pairs(categories) do
    local choiceBtn = Instance.new("TextButton")
    choiceBtn.Size = UDim2.new(1, 0, 0, 30)
    choiceBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    choiceBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    choiceBtn.Text = cat
    choiceBtn.Font = Enum.Font.GothamMedium
    choiceBtn.TextSize = 13
    choiceBtn.ZIndex = 11
    choiceBtn.Parent = dropdownFrame
    
    choiceBtn.MouseButton1Click:Connect(function()
        currentFilter = cat
        dropdownBtn.Text = "Category: " .. string.upper(cat) .. " ▼"
        dropdownFrame.Visible = false
        refreshItemList()
    end)
end
dropdownFrame.CanvasSize = UDim2.new(0, 0, 0, dropLayout.AbsoluteContentSize.Y + 5)

-- Dropdown Open/Close
dropdownBtn.MouseButton1Click:Connect(function()
    dropdownFrame.Visible = not dropdownFrame.Visible
end)

-- Initial Load
refreshItemList()

-- ==========================================
-- WEBHOOK FUNCTION
-- ==========================================
local function sendWebhook(payload)
    if not fetch then return end

    local success, response = pcall(function()
        return fetch({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    if success and response and (response.StatusCode == 204 or response.StatusCode == 200) then
        print("[Tracker Success] Message sent to Discord!")
    else
        print("[Tracker Error] Failed to send. Status: " .. tostring(response and response.StatusCode or "Unknown"))
    end
end

-- ==========================================
-- 1. Send Startup Notification
-- ==========================================
local startupPayload = {
    username = "Truff dev",
    embeds = {
        {
            title = "HETO NA ANG INIWAN",
            description = "Professional Sniper GUI Booted. **Auto-Buy is currently OFF by default.**",
            color = 3447003,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
}
sendWebhook(startupPayload)

-- ==========================================
-- 2. Listen for Restock Events
-- ==========================================
local stockSync = ReplicatedStorage:WaitForChild("StockServiceSync")
print("[Restock Tracker] Attached to StockServiceSync! Waiting for server restock...")

stockSync.OnClientEvent:Connect(function(shopId, stockTable)
    print("[Restock Triggered] Shop:", tostring(shopId))
    
    local embedsArray = {}
    local pcParts = {}
    local groceryFood = {}
    local mentionEveryone = false
    
    if type(stockTable) == "table" then
        for itemName, quantity in pairs(stockTable) do
            if type(quantity) == "number" and quantity > 0 then
                
                -- ==========================================
                -- AUTO-BUY LOGIC (Checks Master Toggle)
                -- ==========================================
                if TargetItems[itemName] then
                    if MasterAutoBuy then
                        mentionEveryone = true
                        print("[AUTO-BUY] Sniping " .. itemName .. " (" .. tostring(quantity) .. "x)")
                        pcall(function()
                            if ShopPurchaseRemote then
                                ShopPurchaseRemote:FireServer(shopId, itemName, quantity)
                            end
                        end)
                    else
                        print("[AUTO-BUY] Skipped " .. itemName .. " (Master Toggle is OFF)")
                    end
                end
                
                -- Standard formatting logic
                local itemData = (ShopConfig and ShopConfig.Items and ShopConfig.Items[itemName]) or {}
                local category = itemData.Category or "Others"
                
                local itemObj = {
                    name = tostring(itemName),
                    quantity = quantity,
                    price = itemData.Price or 0,
                    perHour = itemData.PerHour or 0,
                    stars = itemData.Stars or 0,
                    isTarget = TargetItems[itemName] or false
                }
                
                if category == "Grocery" then table.insert(groceryFood, itemObj)
                else table.insert(pcParts, itemObj) end
            end
        end
    end
    
    table.sort(pcParts, function(a, b)
        if a.stars ~= b.stars then return a.stars < b.stars
        else return a.perHour < b.perHour end
    end)
    
    table.sort(groceryFood, function(a, b) return a.price < b.price end)
    
    local function buildEmbeds(itemList, isGrocery)
        local currentFields = {}
        local fieldCount = 0
        
        local function packEmbed()
            if #currentFields > 0 then
                table.insert(embedsArray, {
                    title = isGrocery and ("🛒 " .. tostring(shopId) .. " - FOOD & GROCERY") or ("📦 " .. tostring(shopId) .. " - PC PARTS"),
                    color = isGrocery and 16753920 or 65280,
                    fields = currentFields
                })
                currentFields = {}
                fieldCount = 0
            end
        end

        for _, item in ipairs(itemList) do
            if #embedsArray >= 8 then break end 
            
            local safeName = item.name
            if safeName == "" or safeName == " " then safeName = "Unknown Item" end
            
            local displayName = item.isTarget and ("🎯 **" .. safeName:sub(1, 240) .. "**") or ("🔹 " .. safeName:sub(1, 250))
            
            local statsDescription
            if isGrocery then
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n\u{200B}", item.quantity, tostring(item.price))
            else
                local starDisplay = string.rep("⭐", item.stars)
                if item.stars == 0 then starDisplay = "N/A" end
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n⚡ **Per Hour:** %s\n%s\n\u{200B}", 
                    item.quantity, tostring(item.price), tostring(item.perHour), starDisplay)
            end
            
            table.insert(currentFields, { name = displayName, value = statsDescription, inline = false })
            
            fieldCount = fieldCount + 1
            if fieldCount >= 25 then packEmbed() end
        end
        if fieldCount > 0 then packEmbed() end
    end
    
    buildEmbeds(pcParts, false)
    buildEmbeds(groceryFood, true)
    
    -- Schedule Embed
    local currentUnix = os.time()
    local nextRestockUnix = currentUnix + 3600 
    
    if StockServiceModule then
        pcall(function()
            local timeUntil = StockServiceModule:TimeUntilRestock(shopId)
            if type(timeUntil) == "number" and timeUntil > 0 then
                nextRestockUnix = math.floor(currentUnix + timeUntil)
            end
        end)
    end
    
    local scheduleDescription = string.format(
        "🟢 **Restocked At:** <t:%d:f>\n🔴 **Next Restock:** <t:%d:t> (<t:%d:R>)\n⚙️ **Sniper Status:** %s", 
        currentUnix, nextRestockUnix, nextRestockUnix, MasterAutoBuy and "🟢 ACTIVE" or "🔴 OFF"
    )
    
    table.insert(embedsArray, {
        title = "⏱️ Shop Schedule & Info",
        color = 3447003,
        description = scheduleDescription,
        footer = { text = "Live Auto-Tracker | Truff dev" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    local restockPayload = { username = "Truff dev", embeds = embedsArray }
    
    if mentionEveryone and MasterAutoBuy then
        restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & AUTO-BUY FIRED!**"
    end
    
    sendWebhook(restockPayload)
end)
