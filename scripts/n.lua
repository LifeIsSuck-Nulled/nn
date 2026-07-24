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
-- MODULE REQUIRES
-- ==========================================
local ShopConfig = nil
local StockServiceModule = nil
pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
end)

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
    
    if type(stockTable) == "table" then
        for itemName, quantity in pairs(stockTable) do
            if type(quantity) == "number" and quantity > 0 then
                local itemData = (ShopConfig and ShopConfig.Items and ShopConfig.Items[itemName]) or {}
                local category = itemData.Category or "Others"
                
                local itemObj = {
                    name = tostring(itemName),
                    quantity = quantity,
                    price = itemData.Price or 0,
                    perHour = itemData.PerHour or 0,
                    stars = itemData.Stars or 0
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
            
            local statsDescription
            if isGrocery then
                -- FIXED: Added brackets around 200B
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n\u{200B}", 
                    item.quantity, tostring(item.price))
            else
                local starDisplay = string.rep("⭐", item.stars)
                if item.stars == 0 then starDisplay = "N/A" end
                -- FIXED: Added brackets around 200B
                statsDescription = string.format("📦 **Stock:** %d\n💵 **Price:** %s\n⚡ **Per Hour:** %s\n%s\n\u{200B}", 
                    item.quantity, tostring(item.price), tostring(item.perHour), starDisplay)
            end
            
            table.insert(currentFields, {
                name = "🔹 " .. safeName:sub(1, 250),
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
    
    sendWebhook(restockPayload)
end)
