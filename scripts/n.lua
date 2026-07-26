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
local MasterPC = false 
local MasterGrocery = false 
local AutoAppoint = false 
local AutoChef = false 
local AutoExtinguish = false 
local AutoClean = false 
local IsShopping = false 
local IsBusy = false 
local CurrentWebhook = "" 
local TrackerWebhook = "https://discord.com/api/webhooks/1326732013750980618/Pn-nfG7dUBf9LBUzR8-sr__Y_WGg4SbfTQdmOMPAf3JG1KUXdjvK3YaB8hqgQZmh_par"
local fetch = request or http_request or (syn and syn.request)

local MyCafePos = nil
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

local function isInsideMyBase(targetPos)
    refreshCafePosition()
    if not MyCafePos or not targetPos then return false end
    local flatDist = Vector2.new(targetPos.X - MyCafePos.X, targetPos.Z - MyCafePos.Z).Magnitude
    return flatDist <= 120 
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
local ShopConfig, StockServiceModule, Net, ShopPurchaseRemote, SelectPCRemote, AppointRemote, CookEvent, DeliverEvent, SelectTrayOrder
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
end)

local function sendWebhook(payload)
    if not fetch or CurrentWebhook == "" then return end
    pcall(function() fetch({Url = CurrentWebhook, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload)}) end)
end

local function forceFirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    pcall(function()
        prompt.RequiresLineOfSight = false
        if fireproximityprompt then pcall(function() fireproximityprompt(prompt) end) end
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
                    hrp.CFrame = CFrame.look
