-- Stock Tracker v2
-- PC Parts  → WEBHOOK_PC   (role pings on 5★ restock)
-- Accessories → WEBHOOK_ACC
-- Merchant  → WEBHOOK_MERCH (arrive + depart pings only, no inventory)

local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

-- ─── Webhooks (XOR-obfuscated, key=73) ───────────────────────────────────────
local function _d(t)
    local r={}
    for i,v in ipairs(t) do r[i]=string.char(bit32.bxor(v,73)) end
    return table.concat(r)
end
local WEBHOOK_PC    = _d({33,61,61,57,58,115,102,102,45,32,58,42,38,59,45,103,42,38,36,102,40,57,32,102,62,44,43,33,38,38,34,58,102,120,124,122,122,113,120,123,125,124,122,121,122,124,125,126,125,112,126,125,102,45,100,51,126,127,11,3,44,15,35,62,126,121,49,35,3,43,22,121,58,42,39,2,33,121,40,19,17,127,31,62,62,120,0,35,42,8,14,122,42,19,26,63,33,4,113,38,19,35,123,112,124,0,60,31,56,61,29,33,112,13,34,61,10,28,1,122,34})
local WEBHOOK_ACC   = _d({33,61,61,57,58,115,102,102,45,32,58,42,38,59,45,103,42,38,36,102,40,57,32,102,62,44,43,33,38,38,34,58,102,120,124,122,127,126,124,126,121,126,126,127,125,122,127,123,125,124,121,120,102,127,25,56,37,5,17,100,13,4,127,39,25,13,112,40,46,60,63,46,46,47,13,42,17,4,123,36,40,24,8,59,1,14,61,120,15,10,36,120,125,42,24,35,46,27,29,125,14,100,16,13,59,45,26,35,100,12,42,4,47,3,58,7,5,6,3,10,113})
local WEBHOOK_MERCH = _d({33,61,61,57,58,115,102,102,45,32,58,42,38,59,45,103,42,38,36,102,40,57,32,102,62,44,43,33,38,38,34,58,102,120,124,122,127,126,124,120,123,123,113,113,112,123,123,123,120,127,120,121,102,24,34,27,26,121,10,31,27,42,26,36,56,44,48,3,43,49,12,57,38,39,113,61,10,24,51,2,24,51,25,125,48,58,34,58,7,39,1,47,122,22,63,12,12,24,126,58,58,125,59,58,49,4,26,17,60,121,45,13,25,43,37,43,36,2,11,112,120})

-- ─── Role IDs ────────────────────────────────────────────────────────────────
local ROLE_MERCHANT = "1538032557977903276"

-- Pinged when stock for that item goes 0 → positive (PC parts only)
local PartRoles = {
    ["Aether"]             = "1533754172195864679",
    ["ArcView"]            = "1533754699033874492",
    ["AvianoChair"]        = "1536760773831954553",
    ["AvianoDesk"]         = "1536760765229432853",
    ["Blossom Keyboard"]   = "1533754683896627350",
    ["CyberCurve"]         = "1533754656180666369",
    ["Dark Nexus"]         = "1533754644256264274",
    ["G-Force"]            = "1536760710065950750",
    ["GamingTable"]        = "1533754672496771212",
    ["HollowFrame"]        = "1533755504520593458",
    ["Initial-B"]          = "1533755514658357299",
    ["Initial-P"]          = "1533755489161314459",
    ["KittyChair"]         = "1533755838198452225",
    ["NexusChair"]         = "1533755886458376252",
    ["Nightfall Keyboard"] = "1533756009510735935",
    ["Nocturne"]           = "1533755965260955781",
    ["Overdrive"]          = "1536760699915608207",
    ["PinkDrift"]          = "1533756156537999399",
    ["Polar X"]            = "1533756224703561860",
    ["Revv"]               = "1533756305540382840",
    ["Sakura"]             = "1533756474868760617",
    ["Shadow"]             = "1533756519047495790",
    ["Snowdrift"]          = "1533756593873621012",
    ["Spider-X Keyboard"]  = "1533756634298323004",
    ["Vortessa"]           = "1536760719037566996",
}

-- ─── Fallback star ratings ───────────────────────────────────────────────────
local ItemStars = {
    Aether=5, AngleView=4, ArcView=5, AvianoChair=5, AvianoDesk=5, Azure=2, BlockView=3,
    ["Blossom Keyboard"]=5, BoxDesk=2, ClassicCore=1, CleanDesk=4, Collage=1, CyberCurve=5,
    ["Dark Nexus"]=5, Evergreen=4, FlatCore=2, FoldingChair=2, FrameDesk=1, Fuji=4, Galon=3,
    GamingTable=5, ["G-Force"]=5, Hanami=3, Hexora=4, HollowFrame=5, Horizon=4, Hoshi=2,
    ["Initial-B"]=5, ["Initial-P"]=5, Japan=2, Kasumi=3, KittyChair=5, Konoha=3, Midnight=2,
    Monoblock=2, NexusChair=5, ["Nightfall Keyboard"]=5, Nimbus=2, Nocturne=5, OfficeChair=4,
    OpenDesk=1, Overdrive=5, Petal=4, PinkDrift=5, ["Polar X"]=5, PulseCore=2, Revv=5,
    Ripple=2, RoundView=2, Sakura=5, Shadow=5, ShelfDesk=2, Slate=1, SlimDesk=4, Snowdrift=5,
    Sora=4, ["Spider-X Keyboard"]=5, StoneChair=3, Throne=3, ["TriFan-Core"]=3, ["TriFan-Lite"]=3,
    ["V-View"]=4, Vesta=4, Voltara=4, Vortessa=5, Wavy=3, WideView=1, WoodenChair=1,
    ["[100 - Key ] Keyboard"]=1, ["[60 - Key ] Keyboard"]=4,
    ["[75 - Key ] Keyboard"]=3,  ["[80 - Key ] Keyboard"]=2,
}

-- ─── Script guard (safe re-execute) ─────────────────────────────────────────
local g = getgenv()
local LABEL = "StockTrackerNew"
if g[LABEL] and g[LABEL].disconnect then g[LABEL].disconnect() end
local state = { lastStock = {} }

-- ─── Anti-AFK ────────────────────────────────────────────────────────────────
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ─── ShopConfig (live item data) ─────────────────────────────────────────────
local ShopConfig
pcall(function()
    ShopConfig = require(RS:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
end)

local function isAccShop(shopId)
    return tostring(shopId):lower():find("acc") ~= nil
end

local function itemInfo(name, shopId)
    local data = {}
    if ShopConfig then
        if isAccShop(shopId) then
            data = (ShopConfig.Accessories and ShopConfig.Accessories[name]) or {}
        elseif ShopConfig.PcParts then
            for _, cat in pairs(ShopConfig.PcParts) do
                if type(cat) == "table" and cat[name] then data = cat[name]; break end
            end
        end
        if not next(data) and ShopConfig.Items then
            data = ShopConfig.Items[name] or {}
        end
    end
    return {
        stars    = tonumber(data.Stars)    or ItemStars[name] or 0,
        price    = tonumber(data.Price)    or 0,
        perHour  = tonumber(data.PerHour)  or 0,
        maxStock = tonumber(data.MaxStock) or 0,
    }
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function timestamp()
    return ("LABA HUB  [%s]  [%s]"):format(os.date("%I:%M %p"), os.date("%B %d, %Y"))
end

local function sendWebhook(url, payload)
    if not url or url == "" then return end
    pcall(function()
        request({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload),
        })
    end)
end

local function buildEmbeds(items, shopId)
    local acc    = isAccShop(shopId)
    local title  = acc and "🎭 Accessories Stock" or ("📦 " .. tostring(shopId) .. " Stock")
    local color  = acc and 0x9B59B6 or 0x00FF00
    local embeds, fields = {}, {}

    local function flush()
        if #fields > 0 then
            table.insert(embeds, { title=title, color=color, fields=fields })
            fields = {}
        end
    end

    for _, it in ipairs(items) do
        if #embeds >= 9 then break end
        local starStr  = (it.stars > 0) and string.rep("⭐", it.stars) or ""
        local nameLine = (starStr ~= "") and ("🔹 %s %s"):format(it.name, starStr)
                                         or ("🔹 %s"):format(it.name)
        local val = string.format("📦 **%d** / %s", it.qty,
            it.maxStock > 0 and tostring(it.maxStock) or "?")
        if it.price   > 0 then val = val .. "\n💵 **$" .. it.price .. "**" end
        if it.perHour > 0 then val = val .. "\n⏱️ **" .. it.perHour .. "/hr**" end
        val = val .. "\n\u{200B}"
        table.insert(fields, { name=nameLine, value=val, inline=false })
        if #fields >= 25 then flush() end
    end
    flush()
    return embeds
end

-- ─── Main stock listener ─────────────────────────────────────────────────────
local stockSync = RS:WaitForChild("StockServiceSync")
state.conn = stockSync.OnClientEvent:Connect(function(shopId, stockTable)
    if type(stockTable) ~= "table" then return end

    local prev   = state.lastStock[shopId] or {}
    local items, pings = {}, {}

    for name, qty in pairs(stockTable) do
        if type(qty) == "number" and qty > 0 then
            local info = itemInfo(name, shopId)
            table.insert(items, {
                name    = tostring(name),
                qty     = qty,
                stars   = info.stars,
                price   = info.price,
                perHour = info.perHour,
                maxStock= info.maxStock,
            })
            -- Role ping: PC parts only, 0 → positive restock
            if not isAccShop(shopId) and (prev[name] or 0) == 0 and PartRoles[name] then
                table.insert(pings, PartRoles[name])
            end
        end
    end
    state.lastStock[shopId] = stockTable

    if #items == 0 then return end

    -- Sort: stars ↓, perHour ↓, price ↓
    table.sort(items, function(a, b)
        if a.stars   ~= b.stars   then return a.stars   > b.stars   end
        if a.perHour ~= b.perHour then return a.perHour > b.perHour end
        return a.price > b.price
    end)

    local embeds = buildEmbeds(items, shopId)
    if #embeds == 0 then return end
    embeds[#embeds].footer = { text = timestamp() }

    local payload = { embeds = embeds }

    if #pings > 0 then
        -- Deduplicate role IDs so same role isn't pinged twice
        local seen, out = {}, {}
        for _, id in ipairs(pings) do
            if not seen[id] then seen[id]=true; table.insert(out, "<@&"..id..">") end
        end
        payload.content = "🚨 **Restocked!** " .. table.concat(out, " ")
    end

    sendWebhook(isAccShop(shopId) and WEBHOOK_ACC or WEBHOOK_PC, payload)
end)

-- ─── Merchant notifications ───────────────────────────────────────────────────
-- Arrive + depart pings only — no inventory listing
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))

state.merchantArriveConn = Net:RemoteEvent("MerchantSpawned").OnClientEvent:Connect(function()
    sendWebhook(WEBHOOK_MERCH, {
        content = "<@&" .. ROLE_MERCHANT .. ">",
        embeds  = {{
            title       = "🛒 Traveling Merchant has arrived!",
            description = "The merchant is now available.",
            color       = 0xF5A623,
            footer      = { text = timestamp() },
        }},
    })
end)

-- Wrap in pcall in case the depart event name differs in a future game update
pcall(function()
    state.merchantDepartConn = Net:RemoteEvent("MerchantDespawned").OnClientEvent:Connect(function()
        sendWebhook(WEBHOOK_MERCH, {
            content = "<@&" .. ROLE_MERCHANT .. ">",
            embeds  = {{
                title       = "🛒 Traveling Merchant has left.",
                description = "The merchant has departed.",
                color       = 0x808080,
                footer      = { text = timestamp() },
            }},
        })
    end)
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────
state.disconnect = function()
    if state.conn              then state.conn:Disconnect();              state.conn              = nil end
    if state.merchantArriveConn then state.merchantArriveConn:Disconnect(); state.merchantArriveConn = nil end
    if state.merchantDepartConn then state.merchantDepartConn:Disconnect(); state.merchantDepartConn = nil end
end

g[LABEL] = state
print("[Stock Tracker v2] active — PC → #pc-stock | Acc → #acc-stock | Merchant → #merchant")
