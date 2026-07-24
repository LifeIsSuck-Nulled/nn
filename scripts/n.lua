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
-- DYNAMIC TARGET LIST
-- ==========================================
local TargetItems = {}

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
-- MOBILE-FRIENDLY GUI SETUP (SAFE LOAD)
-- ==========================================
local guiName = "TruffAutoBuyGUI"

-- Safely find a folder to put the GUI without triggering capability crashes
local guiParent = nil
pcall(function()
    guiParent = gethui and gethui()
end)

if not guiParent then
    guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Clean up old GUI if re-executed
pcall(function()
    if guiParent:FindFirstChild(guiName) then
        guiParent[guiName]:Destroy()
    end
end)
pcall(function()
    if Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(guiName) then
        Players.LocalPlayer.PlayerGui[guiName]:Destroy()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = guiName
gui.ResetOnSpawn = false -- Keeps GUI on screen if you die
gui.Parent = guiParent

-- Toggle Button (To hide/show menu on mobile)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 120, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "🎯 Sniper GUI"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Parent = gui
local toggleCorner = Instance.new("UICorner", toggleBtn)

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 450)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.Visible = false -- Hidden by default
mainFrame.Parent = gui
local mainCorner = Instance.new("UICorner", mainFrame)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Select Targets to Snipe"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -50)
scrollFrame.Position = UDim2.new(0, 10, 0, 40)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 6
scrollFrame.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout", scrollFrame)
uiListLayout.Padding = UDim.new(0, 5)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder

toggleBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Extract and Sort items for the GUI
local guiItems = {}
if ShopConfig and type(ShopConfig.Items) == "table" then
    for itemName, itemData in pairs(ShopConfig.Items) do
        table.insert(guiItems, {
            name = tostring(itemName),
            category = itemData.Category or "Other",
            stars = itemData.Stars or 0,
            price = itemData.Price or 0
        })
    end
end

-- Sort: Category first, then Stars (Highest to Lowest), then Price (Highest to Lowest)
table.sort(guiItems, function(a, b)
    if a.category ~= b.category then
        return a.category < b.category
    elseif a.stars ~= b.stars then
        return a.stars > b.stars
    else
        return a.price > b.price
    end
end)

-- Populate GUI
local currentCategory = ""
for _, item in ipairs(guiItems) do
    if item.category ~= currentCategory then
        currentCategory = item.category
        
        local categoryLabel = Instance.new("TextLabel")
        categoryLabel.Size = UDim2.new(1, 0, 0, 25)
        categoryLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        categoryLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        categoryLabel.Text = "  --- " .. string.upper(item.category) .. " ---"
        categoryLabel.Font = Enum.Font.GothamBold
        categoryLabel.TextSize = 12
        categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
        categoryLabel.Parent = scrollFrame
        Instance.new("UICorner", categoryLabel)
    end
    
    local itemBtn = Instance.new("TextButton")
    itemBtn.Size = UDim2.new(1, 0, 0, 35)
    itemBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20) -- Red (Off)
    
    local starDisplay = string.rep("⭐", item.stars)
    if item.stars == 0 then starDisplay = "" end
    
    itemBtn.Text = item.name .. " " .. starDisplay
    itemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemBtn.Font = Enum.Font.GothamSemibold
    itemBtn.TextSize = 13
    itemBtn.Parent = scrollFrame
    Instance.new("UICorner", itemBtn)
    
    -- Click Event to Toggle Target
    itemBtn.MouseButton1Click:Connect(function()
        if TargetItems[item.name] then
            TargetItems[item.name] = nil
            itemBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20) -- Turn Red (Off)
        else
            TargetItems[item.name] = true
            itemBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 20) -- Turn Green (On)
        end
    end)
end

-- Update scrolling frame size automatically
uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 10)
end)

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
            description = "System Online. Use the in-game GUI to select targets. Waiting for restocks...",
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
                -- AUTO-BUY SNIPER LOGIC
                -- ==========================================
                if TargetItems[itemName] then
                    mentionEveryone = true
                    print("[AUTO-BUY] Target item detected: " .. itemName .. "! Attempting to snipe " .. tostring(quantity) .. "x")
                    
                    -- Fire the purchase remote safely
                    pcall(function()
                        if ShopPurchaseRemote then
                            ShopPurchaseRemote:FireServer(shopId, itemName, quantity)
                        end
                    end)
                end
                
                -- Standard item tracking
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
                
                if category == "Grocery" then
                    table.insert(groceryFood, itemObj)
                else
                    table.insert(pcParts, itemObj)
                end
            end
        end
    end
    
    table.sort(pcParts, function(a, b)
        if a.stars ~= b.stars then
            return a.stars < b.stars
        else
            return a.perHour < b.perHour
        end
    end)
    
    table.sort(groceryFood, function(a, b)
        return a.price < b.price
    end)
    
    local function buildEmbeds(itemList, isGrocery)
        local currentFields = {}
        local fieldCount = 0
        
        local function packEmbed()
            if #currentFields > 0 then
                local embedTitle = isGrocery and ("🛒 " .. tostring(shopId) .. " - FOOD & GROCERY") or ("📦 " .. tostring(shopId) .. " - PC PARTS")
                local embedColor = isGrocery and 16753920 or 65280
                
                table.insert(embedsArray, {
                    title = embedTitle,
                    color = embedColor,
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
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n\u{200B}", 
                    item.quantity, tostring(item.price))
            else
                local starDisplay = string.rep("⭐", item.stars)
                if item.stars == 0 then starDisplay = "N/A" end
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n⚡ **Per Hour:** %s\n%s\n\u{200B}", 
                    item.quantity, tostring(item.price), tostring(item.perHour), starDisplay)
            end
            
            table.insert(currentFields, {
                name = displayName,
                value = statsDescription,
                inline = false
            })
            
            fieldCount = fieldCount + 1
            if fieldCount >= 25 then
                packEmbed()
            end
        end
        
        if fieldCount > 0 then
            packEmbed()
        end
    end
    
    buildEmbeds(pcParts, false)
    buildEmbeds(groceryFood, true)
    
    -- ==========================================
    -- 3. Calculate Time & Schedule Embed
    -- ==========================================
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
        "🟢 **Restocked At:** <t:%d:f>\n🔴 **Next Restock:** <t:%d:t> (<t:%d:R>)", 
        currentUnix, 
        nextRestockUnix, 
        nextRestockUnix
    )
    
    table.insert(embedsArray, {
        title = "⏱️ Shop Schedule",
        color = 3447003,
        description = scheduleDescription,
        footer = { text = "Live Auto-Tracker | Truff dev" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    
    local restockPayload = {
        username = "Truff dev",
        embeds = embedsArray
    }
    
    if mentionEveryone then
        restockPayload.content = "@everyone 🚨 **TARGET ITEM DETECTED & AUTO-BUY FIRED!**"
    end
    
    sendWebhook(restockPayload)
end)
