local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")

-- ==========================================
-- SYSTEM VARIABLES
-- ==========================================
local TargetItemsPC = {}
local TargetItemsGrocery = {}
local TargetPCsToUpgrade = {} 
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
local UpgradeLock = false 

local ShopCFrame_PC = CFrame.new(-240.48721313476562, 7.888942718505859, 136.32080078125)
local ShopCFrame_Grocery = CFrame.new(-102.66999816894531, 8.224592208862305, 10.839996337890625)

-- ==========================================
-- CAFE RADAR & BOUNDARY CHECKER
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

-- 🔥 BAGONG SYSTEM: Tinitingnan lang ang FLAT distance (X at Z) para sakop ang buong 2nd floor!
local function isInsideMyBase(targetPos)
    refreshCafePosition()
    if not MyCafePos or not targetPos then return false end
    local flatDist = Vector2.new(targetPos.X - MyCafePos.X, targetPos.Z - MyCafePos.Z).Magnitude
    return flatDist <= 120 -- 120 studs safe radius para sa base mo lang
end

local function getMyPCs()
    refreshCafePosition()
    local pcs = {}
    if not MyCafePos then return pcs end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Desktop") and obj:FindFirstChild("Monitor") and obj:FindFirstChild("Keyboard") then
            local pos = obj:GetPivot().Position
            if isInsideMyBase(pos) then
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
                        TargetPCsToUpgrade[obj.Name] = true 
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
        pcall(function() fetch({Url = TrackerWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode({username = "Laba Execution Log", content = "👤 **New User Executed Script:** `" .. Players.LocalPlayer.Name .. "`\n🆔 **User ID:** `" .. Players.LocalPlayer.UserId .. "`"})}) end)
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
local ShopPurchaseRemote, SelectPCRemote, AppointRemote, CookEvent, DeliverEvent, SelectTrayOrder
pcall(function()
    ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("SHOP_CONFIG"))
    StockServiceModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("StockService"))
    Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Scripts"):WaitForChild("Packages"):WaitForChild("Net"))
    CustomizeRemote = Net:RemoteEvent("CustomizePC")
    ConfirmCustomizeRemote = Net:RemoteEvent("ConfirmCustomize")
    CancelCustomizeRemote = Net:RemoteEvent("CancelCustomize")
    ShopPurchaseRemote = Net:RemoteEvent("ShopPurchase")
    SelectPCRemote = Net:RemoteEvent("selectPC")
    AppointRemote = Net:RemoteEvent("AppointNPC")
    CookEvent = Net:RemoteEvent("CookEvent")
    DeliverEvent = Net:RemoteEvent("DeliverEvent")
    SelectTrayOrder = Net:RemoteEvent("SelectTrayOrder")
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
        prompt.RequiresLineOfSight = false
        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        end
        if prompt.InputHoldBegin then
            pcall(function() prompt:InputHoldBegin() end)
            task.delay(0.2, function() pcall(function() prompt:InputHoldEnd() end) end)
        end
        local key = prompt.KeyboardKeyCode or Enum.KeyCode.E
        VirtualInputManager:SendKeyEvent(true, key, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, key, false, game)
    end)
end

-- ==========================================
-- AUTO EXTINGUISH LOOP 
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoExtinguish and not IsShopping and not IsBusy then
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                if not hrp or not humanoid then return end
                
                local fireFound, firePart = nil, nil
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local name = obj.Name:lower()
                    if obj:IsA("ProximityPrompt") and (name:match("extinguish") or obj.ActionText:lower():match("extinguish") or obj.ObjectText:lower():match("fire")) then 
                        if obj.Parent and isInsideMyBase(obj.Parent.Position) then
                            fireFound = obj; firePart = obj.Parent; break
                        end
                    elseif (obj:IsA("ParticleEmitter") or obj:IsA("Fire")) and (name:match("fire") or name:match("flame")) then
                        local part = obj.Parent
                        if part and part:IsA("BasePart") and isInsideMyBase(part.Position) then 
                            fireFound = obj; firePart = part; break 
                        end
                    end
                end
                
                if fireFound and firePart then
                    IsBusy = true 
                    humanoid:UnequipTools(); task.wait(0.2)
                    local targetPos = firePart.Position
                    hrp.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 3, -4), targetPos); task.wait(0.3)
                    if humanoid then humanoid.Sit = false end
                    
                    local extTool = nil
                    local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
                    if backpack then
                        for _, t in ipairs(backpack:GetChildren()) do 
                            if t:IsA("Tool") and (t.Name:lower():match("extinguish") or t.Name:lower():match("fire")) then 
                                extTool = t break 
                            end 
                        end
                    end
                    
                    if extTool then
                        humanoid:EquipTool(extTool)
                        local isEquipped = false
                        for w = 1, 15 do if extTool.Parent == char then isEquipped = true break end task.wait(0.1) end
                        
                        if isEquipped then
                            for i = 1, 10 do
                                if extTool.Parent == char then
                                    extTool:Activate(); VirtualUser:ClickButton1(Vector2.new())
                                    if fireFound:IsA("ProximityPrompt") then forceFirePrompt(fireFound) end
                                end
                                task.wait(0.5) 
                            end
                            task.wait(1.5) 
                        end
                    end
                    humanoid:UnequipTools(); IsBusy = false 
                end
            end)
        end
    end
end)

-- ==========================================
-- AUTO CLEAN LOOP (STRICTER & SMARTER)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if AutoClean and not IsShopping and not IsBusy then
            pcall(function()
                local char = Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                if not hrp or not humanoid then return end
                
                local messFound, messPos, messType = nil, nil, nil
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        local act, objTxt = obj.ActionText:lower(), obj.ObjectText:lower()
                        if act:match("clean") and (objTxt:match("mess") or objTxt:match("glass") or objTxt:match("spill") or objTxt:match("trash")) then
                            if obj.Parent and isInsideMyBase(obj.Parent.Position) then
                                messFound = obj
                                messPos = obj.Parent.Position
                                messType = (objTxt:match("glass") or objTxt:match("window")) and "glass" or "mess"
                                break
                            end
                        end
                    end
                end
                
                if messFound and messPos then
                    IsBusy = true 
                    humanoid:UnequipTools(); task.wait(0.3) -- Bigyan ng oras bumitaw
                    hrp.CFrame = CFrame.lookAt(messPos + Vector3.new(0, 2.5, 2.5), messPos); task.wait(0.3)
                    if humanoid then humanoid.Sit = false end
                    
                    -- 🔥 SMARTER TOOL SELECTOR (Para hindi bumunot ng fire extinguisher)
                    local allowedTools = (messType == "glass") and {"towel", "sponge", "wipe", "rag"} or {"walis", "broom", "mop", "sweep"}
                    local toolToEquip = nil
                    local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
                    
                    if backpack then
                        for _, t in ipairs(backpack:GetChildren()) do 
                            if t:IsA("Tool") then
                                local tName = t.Name:lower()
                                for _, allowed in ipairs(allowedTools) do
                                    if tName:match(allowed) then
                                        toolToEquip = t
                                        break
                                    end
                                end
                                if toolToEquip then break end
                            end 
                        end
                    end
                    
                    if toolToEquip then
                        humanoid:EquipTool(toolToEquip)
                        local isEquipped = false
                        for w = 1, 15 do if toolToEquip.Parent == char then isEquipped = true break end task.wait(0.1) end
                        
                        if isEquipped then
                            for i = 1, 8 do
                                if toolToEquip.Parent == char then
                                    toolToEquip:Activate(); VirtualUser:ClickButton1(Vector2.new())
                                    forceFirePrompt(messFound)
                                end
                                task.wait(0.6) 
                            end
                            task.wait(1.5) 
                        end
                    end
                    humanoid:UnequipTools(); IsBusy = false 
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
                local char = Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                local mainUi = Players.LocalPlayer.PlayerGui:FindFirstChild("MainUi")
                local serverFrame = mainUi and mainUi:FindFirstChild("ServerFrame")
                
                if hrp and serverFrame and not serverFrame.Visible then
                    local closestPrompt = nil
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local n, o, a = obj.Name:lower(), obj.ObjectText:lower(), obj.ActionText:lower()
                            if not a:match("sit") and not n:match("chair") and not o:match("chair") then
                                if n:match("laptop") or n:match("server") or o:match("laptop") or o:match("server") then
                                    if obj.Parent and obj.Parent:IsA("BasePart") and isInsideMyBase(obj.Parent.Position) then
                                        closestPrompt = obj
                                        break
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
                        hrp.CFrame = closestPrompt.Parent.CFrame * CFrame.new(0, 3, 2.5); task.wait(0.2)
                        if humanoid then humanoid.Sit = false end; task.wait(0.3) 
                        forceFirePrompt(closestPrompt); task.wait(1)
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
                                    SelectPCRemote:FireServer(pcName); task.wait(0.05); AppointRemote:FireServer(pcName); task.wait(0.1)
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
                local char = Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                local mainUi = Players.LocalPlayer.PlayerGui:FindFirstChild("MainUi")
                if not mainUi or not hrp then return end
                
                local trayItems = {}
                local trayList = mainUi:FindFirstChild("Tray") and mainUi.Tray:FindFirstChild("ListFrame")
                if trayList then
                    for _, v in ipairs(trayList:GetChildren()) do if v:IsA("Frame") and v:GetAttribute("TrayRuntimeCard") then table.insert(trayItems, v) end end
                end
                
                if #trayItems > 0 and not IsShopping then
                    local equippedItem = nil
                    for _, item in ipairs(trayItems) do
                        local stroke = item:FindFirstChildWhichIsA("UIStroke")
                        if stroke and stroke.Thickness == 4 then equippedItem = item break end
                    end
                    
                    if not equippedItem then
                        local rawId = trayItems[1].Name:gsub("TrayOrder_", "")
                        local orderId = tonumber(rawId) or rawId 
                        if SelectTrayOrder then SelectTrayOrder:FireServer(orderId) end
                        task.wait(0.5); return 
                    end
                    
                    local pcLabel = equippedItem:FindFirstChild("PcNumber")
                    if pcLabel then
                        local targetPCNumber = pcLabel.Text
