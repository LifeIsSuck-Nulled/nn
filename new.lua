repeat task.wait() until game:IsLoaded()
if getgenv().LABA_HUB_LOADED then return end
getgenv().LABA_HUB_LOADED = true

local P = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = P.LocalPlayer
local VU = game:GetService("VirtualUser")
local Net = require(RS.Shared.Scripts.Packages.Net)
local SR = Net:RemoteEvent("selectPC")
local AR = Net:RemoteEvent("AppointNPC")
local CE = Net:RemoteEvent("CookEvent")
local DE = Net:RemoteEvent("DeliverEvent")
local ST = Net:RemoteEvent("SelectTrayOrder")
local SPR = Net:RemoteEvent("ShopPurchase")
local PRQ = Net:RemoteEvent("PrinterRequest")
local PRU = Net:RemoteEvent("PrinterUpdate")
local PRO = Net:RemoteEvent("PrinterOpen")
local ASRQ = Net:RemoteEvent("AccessoryShopRequest")
local EBR = Net:RemoteEvent("ElectricityBillingRequest")
local EBS = Net:RemoteEvent("ElectricityBillingState")

local AA, AC, AF, AE, AAFK, AP, AB = false,false,false,false,false,false,false
local HLP, CPos = nil, nil
local ShopPC = CFrame.new(-240,8,136); local ShopGroc = CFrame.new(-103,8,11)
local PCItems, GroceryItems, AccItems = {}, {}, {}
local boughtAcc = {} -- accessories already attempted this session

local Per = getgenv().LabaTogglePersist or {}; getgenv().LabaTogglePersist = Per
if Per.AutoAppoint then AA=true end
if Per.AutoClean   then AC=true end
if Per.AutoChef    then AF=true end
if Per.AutoExt     then AE=true end
if Per.AntiAFK     then AAFK=true end
if Per.AutoPrint   then AP=true end

local billState = nil -- { PayableBill, Outage, Grace, ... } fed by periodic poll
local billBusy = false -- bill loop owns the scheduler while it pays
local billNext = 0 -- next wall time the 15s pay cycle may run
if Per.AutoBill    then AB=true end

local Sid = (getgenv().LabaHubSession or 0)+1; getgenv().LabaHubSession = Sid
local function alive() return getgenv().LabaHubSession == Sid end
local TrayDrain = false

-- Base helpers
local function ob() for _,b in ipairs((workspace:FindFirstChild("Bases")or{}):GetChildren()) do if b:GetAttribute("OwnerUserId")==LP.UserId and(b:FindFirstChild("CleaningSystem")or b:FindFirstChild("PCS"))then return b end end end
local function rp() local b=ob();if b then CPos=b:GetPivot().Position end end
local function ib(p) return CPos and p and Vector2.new(p.X-CPos.X,p.Z-CPos.Z).Magnitude<=120 end
local function vp() local b,n=ob(),0;if b and b:FindFirstChild("PCS")then for _,p in ipairs(b.PCS:GetChildren())do if p:IsA("Model")and p:GetAttribute("Available")==true then n=n+1 end end end;return n end
local function hc() local sf=LP.PlayerGui:FindFirstChild("MainUi")and LP.PlayerGui.MainUi:FindFirstChild("ServerFrame");if not sf then return false end;local nn=sf:FindFirstChild("NpcInfo")and sf.NpcInfo:FindFirstChild("NpcName");return nn and nn.Text~=""and nn.Text~="(Npc Name)"end
local function fl(hrp) if HLP and HLP.Parent then return HLP end;local be,bd=nil,1e9;for _,o in ipairs(workspace:GetDescendants())do if o:IsA("ProximityPrompt")then local ot=(o.ObjectText or""):lower();if ot:match("laptop")then local pa=o.Parent;if pa and pa:IsA("BasePart")then local d=(hrp.Position-pa.Position).Magnitude;if d<bd and d<150 and ib(pa.Position)then be=o;bd=d end end end end end;if be then HLP=be;CPos=be.Parent.Position end;return be end
local function ct(p) local a=p:GetAttribute("RequiredToolAttribute");local n=p.Name:lower();if a=="FireExtinguisher"or n:match("extinguish")then return"fire"end;if a=="CleaningTowel"or n:match("glass")then return"glass"end;if a=="CleaningBroom"or n:match("clean")then return"mess"end end
local function pp(p) if not p then return nil end;local o=p.Parent;if o and o:IsA("BasePart")then return o.Position end;local m=o and(o:IsA("Model")and o or(o.Parent and o.Parent:IsA("Model")and o.Parent));if m then local ok,v=pcall(function()return m:GetPivot().Position end);if ok then return v end end end
local function pt(p) local bp=LP:FindFirstChild("Backpack");if not bp then return nil end;local rn=p:GetAttribute("RequiredToolName");local ra=p:GetAttribute("RequiredToolAttribute");for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")then if rn and string.lower(t.Name)==string.lower(rn)then return t end;if ra and t:GetAttribute(ra)==true then return t end end end;local p2=ct(p);for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")then local n=string.lower(t.Name);if p2=="fire"and(n:match("fire")or n:match("extinguish"))then return t end;if p2=="glass"and(n:match("towel")or n:match("wipe")or n:match("rag"))then return t end;if p2=="mess"and(n:match("walis")or n:match("broom")or n:match("mop"))then return t end end end end
local function trayCap()
	local s=LP.PlayerGui:FindFirstChild("SecondaryUi")and LP.PlayerGui.SecondaryUi:FindFirstChild("TrayUpgrade");local l=s and s:FindFirstChild("CurrentTrayValue");local t=l and l.Text or ""
	if t:lower():match("unlimit")or t:lower():match("infinite")then return 1e9 end
	local n=t:match("%d+");return tonumber(n)or 3
end

-- Functions
local function custNear()
	local sf=LP.PlayerGui:FindFirstChild("MainUi")and LP.PlayerGui.MainUi:FindFirstChild("ServerFrame");if not sf then return false end
	local nn=sf:FindFirstChild("NpcInfo")and sf.NpcInfo:FindFirstChild("NpcName");local want=nn and nn.Text
	if not want or want==""or want=="(Npc Name)"then return false end
	local b=ob();if not b then return false end
	local pr=nil;for _,o in ipairs(workspace:GetDescendants())do if o:IsA("ProximityPrompt")then local ot=(o.ObjectText or""):lower();if ot:match("laptop")then local pa=o.Parent;if pa and pa:IsA("BasePart")and pa:IsDescendantOf(b)then pr=o;break end end end end
	if not pr then return false end;local lp=pr.Parent.Position
	local npcs=b:FindFirstChild("NPCS");local best=nil
	if npcs then for _,f in ipairs(npcs:GetChildren())do for _,m in ipairs(f:GetChildren())do if m:IsA("Model")and m.Name==want then local hrp=m:FindFirstChild("HumanoidRootPart");if hrp then local d=(hrp.Position-lp).Magnitude;if not best or d<best then best=d end end end end end end
	return best~=nil and best<=8
end

local function doAppoint()
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");local hm=c and c:FindFirstChildWhichIsA("Humanoid");if not h or not hm or hm.Health<=0 then return end;rp()
	local sf=LP.PlayerGui:FindFirstChild("MainUi")and LP.PlayerGui.MainUi:FindFirstChild("ServerFrame");if not sf or sf.Visible then return end;if not hc()or vp()==0 then return end
	if not custNear() then return end
	local pr=fl(h);if not pr then return end;local pa=pr.Parent
	if(h.Position-pa.Position).Magnitude>2.5 then h.CFrame=pa.CFrame*CFrame.new(0,3,2.5);task.wait(0.4);hm.Sit=false;task.wait(0.4)end
	if fireproximityprompt then local o=pr.RequiresLineOfSight;pr.RequiresLineOfSight=false;pr.MaxActivationDistance=50;fireproximityprompt(pr);pr.RequiresLineOfSight=o end
	for _=1,20 do task.wait(0.1);if sf.Visible then break end end;if not sf.Visible then return end
	local nn=sf:FindFirstChild("NpcInfo")and sf.NpcInfo:FindFirstChild("NpcName");local want=nn and nn.Text;if not want or want==""then return end
	local pl=sf:FindFirstChild("PcList");local pc=nil;if pl then for _,f in ipairs(pl:GetChildren())do if f:IsA("Frame")and f.Name~="Template"then pc=f.Name;break end end end;if not pc then return end
	SR:FireServer(pc);task.wait(0.2);AR:FireServer(pc)
	local b=ob();local lu=b and b:FindFirstChild("NPCS")and b.NPCS:FindFirstChild("LinedUp")
	for _=1,20 do
		task.wait(0.15)
		local n2=sf:FindFirstChild("NpcInfo")and sf.NpcInfo:FindFirstChild("NpcName");local w2=n2 and n2.Text
		if w2 and w2~=want then break end
		if lu then local still=false;for _,m in ipairs(lu:GetChildren())do if m.Name==want then still=true;break end end;if not still then break end end
	end
	local le=Net:RemoteEvent("LaptopQueryEvent");if le then pcall(function()le:FireServer("Close")end)end;if sf.Visible then sf.Visible=false end;task.wait(0.1)
end

local function doClean()
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");local hm=c and c:FindFirstChildWhichIsA("Humanoid");if not h or not hm or hm.Health<=0 then return end
	local b=ob();if not b then return end;CPos=b:GetPivot().Position;local cs=b:FindFirstChild("CleaningSystem");if not cs then return end
	-- Fix: collect ALL cleanable prompts, not just nearest, so one call clears the whole base
	local toClean={}
	for _,r in ipairs({cs:FindFirstChild("ActiveMesses"),cs:FindFirstChild("ActiveFires"),cs:FindFirstChild("Fires")})do
		if r then for _,p in ipairs(r:GetDescendants())do if p:IsA("ProximityPrompt")and p.Enabled then local pt2=ct(p);if pt2 then local po=pp(p);if po and ib(po)then table.insert(toClean,{p=p,po=po,pt=pt2})end end end end end
	end
	if #toClean==0 then return end
	local lastToolAttr=nil
	local tool=nil
	for _,be in ipairs(toClean)do
		local pr,po,pt2=be.p,be.po,be.pt
		if not pr.Enabled then continue end  -- might have been cleaned by a previous iteration
		-- Re-equip only if tool type changed (avoids constant unequip/equip)
		local ra=pr:GetAttribute("RequiredToolAttribute")
		if ra~=lastToolAttr then
			hm:UnequipTools();task.wait(0.05)
			tool=pt(pr);if not tool then continue end
			hm:EquipTool(tool)
			for _=1,10 do if tool.Parent==c then break end;task.wait(0.06)end
			lastToolAttr=ra
		end
		if not tool or tool.Parent~=c then continue end
		-- Teleport next to the mess and face it
		h.CFrame=CFrame.lookAt(Vector3.new(po.X,po.Y+2.2,po.Z+2.2),Vector3.new(po.X,po.Y,po.Z));task.wait(0.1);hm.Sit=false
		local oL,oD=pr.RequiresLineOfSight,pr.MaxActivationDistance;pr.RequiresLineOfSight=false;pr.MaxActivationDistance=50
		for _=1,8 do
			if fireproximityprompt then fireproximityprompt(pr)end
			if tool.Parent==c then tool:Activate();VU:ClickButton1(Vector2.new())end
			task.wait(0.12)
			if not pr.Enabled then break end  -- prompt deactivated = cleaned
		end
		pr.RequiresLineOfSight=oL;pr.MaxActivationDistance=oD
		task.wait(pt2=="fire"and 0.2 or 0.25)
	end
	hm:UnequipTools()
end

local function doChef()
	local mu=LP.PlayerGui:FindFirstChild("MainUi");if not mu then return end
	local tr={};local tl=mu:FindFirstChild("Tray")and mu.Tray:FindFirstChild("ScrollingFrame");if tl then for _,v in ipairs(tl:GetChildren())do if v:IsA("Frame")and v:GetAttribute("TrayRuntimeCard")then table.insert(tr,v)end end end
	if #tr>0 then
		TrayDrain=true
		local eq=nil;for _,v in ipairs(tr)do local s=v:FindFirstChildWhichIsA("UIStroke");if s and s.Thickness==4 then eq=v;break end end
		if not eq then local raw=tr[1].Name:gsub("TrayOrder_","");if ST then ST:FireServer(tonumber(raw)or raw)end;return end
		local pcL=eq:FindFirstChild("PcNumber");if not pcL then return end;local num=pcL.Text:match("%d+");if not num then return end
		local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");local hm=c and c:FindFirstChildWhichIsA("Humanoid");if not h or not hm then return end
		local b=ob();local pcs=b and b:FindFirstChild("PCS");local pcP=nil
		if pcs then for _,pc in ipairs(pcs:GetChildren())do if pc:IsA("Model")and pc.Name==num then pcP=pc.PrimaryPart and pc.PrimaryPart.Position or pc:GetPivot().Position;break end end end
		if pcP then
			local np=nil;local nd=1e9
			for _,npc in ipairs(workspace:GetDescendants())do if npc:IsA("Model")and npc:FindFirstChild("Humanoid")and not P:GetPlayerFromCharacter(npc)then local r=npc:FindFirstChild("HumanoidRootPart")or npc.PrimaryPart;if r then local d=(r.Position-pcP).Magnitude;if d<nd and d<15 then np=r;nd=d end end end end
			if np then
				local stand=np.Position-np.CFrame.LookVector*2.5
				h.CFrame=CFrame.lookAt(Vector3.new(stand.X,np.Position.Y,stand.Z),Vector3.new(np.Position.X,np.Position.Y,np.Position.Z))
				task.wait(0.1);hm.Sit=false;task.wait(0.35)
			end
		end
		return
	else
		TrayDrain=false
	end
	local ck=mu:FindFirstChild("Cooking")and mu.Cooking:FindFirstChild("OrdersFrame");if ck then for _,v in ipairs(ck:GetChildren())do if v:IsA("Frame")and v:GetAttribute("CookingRuntimeCard")then local l=v:FindFirstChild("FoodName",true);if l then CE:FireServer(l.Text,tonumber(v.Name)or v.Name);return end end end end
	local sk=mu:FindFirstChild("SnacksDeliver")and mu.SnacksDeliver:FindFirstChild("OrdersFrame");if sk then for _,v in ipairs(sk:GetChildren())do if v:IsA("Frame")and v:GetAttribute("SnackRuntimeCard")then DE:FireServer(tonumber(v.Name)or v.Name);return end end end
	local pp2=mu:FindFirstChild("Cooking")and mu.Cooking:FindFirstChild("PreparingFrame");if pp2 then for _,v in ipairs(pp2:GetChildren())do if v:IsA("Frame")and v:GetAttribute("CookingRuntimeCard")then local btn=v:FindFirstChild("Button",true);if btn and btn.Text=="Deliver"then DE:FireServer(tonumber(v.Name)or v.Name);return end end end end
end

local function doFire()
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");local hm=c and c:FindFirstChildWhichIsA("Humanoid");if not h or not hm or hm.Health<=0 then return end
	local b=ob();if not b then return end;local pcs=b:FindFirstChild("PCS");if not pcs then return end
	for _,pc in ipairs(pcs:GetChildren())do if pc:IsA("Model")and pc:GetAttribute("FireActive")==true then
		-- Original prompt search kept: fire prompts have RequiredToolAttribute="FireExtinguisher" when active.
		-- Also match by name pattern as a fallback (e.g. after game updates rename the prompt).
		local pp3=nil;for _,p in ipairs(pc:GetDescendants())do if p:IsA("ProximityPrompt")and p.Enabled and(p:GetAttribute("RequiredToolAttribute")=="FireExtinguisher"or p.Name:lower():match("extinguish")or p.Name:lower():match("fire"))then pp3=p;break end end
		-- If no attribute/name match, fall back to any enabled prompt in the PC (catches renamed prompts)
		if not pp3 then for _,p in ipairs(pc:GetDescendants())do if p:IsA("ProximityPrompt")and p.Enabled then local ot=(p.ObjectText or""):lower();if not ot:match("laptop")and not ot:match("select")then pp3=p;break end end end end
		if pp3 then
		hm:UnequipTools();task.wait(0.25)  -- give unequip time to complete before searching backpack
		-- Fix: find the Fire Extinguisher tool explicitly — old code used case-sensitive exact name
		-- which silently failed when name differed, falling through to nil → equipping nothing / wrong tool
		local bp=LP:FindFirstChild("Backpack");local tool=nil
		if bp then
			-- Pass 1: attribute check (most reliable, immune to name changes)
			for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")and t:GetAttribute("FireExtinguisher")==true then tool=t;break end end
			-- Pass 2: case-insensitive name match, explicitly excluding cleaning tools
			if not tool then for _,t in ipairs(bp:GetChildren())do if t:IsA("Tool")then local n=t.Name:lower();if(n:match("fire")or n:match("extinguish"))and not t:GetAttribute("CleaningBroom")and not t:GetAttribute("CleaningTowel")then tool=t;break end end end end
		end
		if not tool then return end
		hm:EquipTool(tool);for _=1,10 do if tool.Parent==c then break end;task.wait(0.1)end
		local pos=pc.PrimaryPart and pc.PrimaryPart.Position or pc:GetPivot().Position;h.CFrame=CFrame.new(pos)*CFrame.new(0,2.5,3);task.wait(0.2);hm.Sit=false;h.CFrame=CFrame.lookAt(h.Position,Vector3.new(pos.X,h.Position.Y,pos.Z));task.wait(0.2)
		local oL,oD=pp3.RequiresLineOfSight,pp3.MaxActivationDistance;pp3.RequiresLineOfSight=false;pp3.MaxActivationDistance=50
		if fireproximityprompt then fireproximityprompt(pp3)end;for _=1,4 do if tool.Parent==c then tool:Activate();VU:ClickButton1(Vector2.new())end;task.wait(0.3)end
		pp3.RequiresLineOfSight=oL;pp3.MaxActivationDistance=oD;task.wait(0.5);hm:UnequipTools();return
	end end end
end

local UI = loadstring([=[
--[[
	LABA HUB — Obsidian x Rayfield design, from scratch.
	No library, no loadstring. Every pixel is Instance.new.
	(c) 2026 LABA HUB. Licensed under LICENSE — no rebranding, no
	commercial use. See the LICENSE file shipped with this project.

	API:
		win = UI:CreateWindow({ Title = "…", Size = UDim2.fromOffset(560, 400),
		Intro = { Title = "…", Subtitle = "…", Duration = 3 } })  -- optional splash
		win:Destroy()  -- full teardown (conns + ScreenGui + config)
		tab = win:AddTab("Main")
		el = tab:AddToggle({ Name, Value, Key, Callback })   el:Get() / el:Set(v)
		el = tab:AddSlider({ Name, Min, Max, Step, Value, Suffix, Key, Callback })   el:Get() / el:Set(v)
		el = tab:AddButton({ Name, Callback })
		el = tab:AddTextBox({ Name, Placeholder, Value, Key, Callback })   el:Get() / el:Set(v) / el:Focus()
		tab:AddDropdown({ Name, Options, Value, Multi, Key, Callback })
		tab:AddParagraph({ Name, Placeholder, Value, Key, Callback })   el:Get() / el:Set(v)
		tab:AddSegmented({ Name, Options, Value, Key, Callback })   el:Get() / el:Set(v)
		tab:AddList({ Name, Options, Value, Key, Callback })   el:Get() / el:Set(v) / el:SetOptions(list)
		tab:AddLabel({ Name, Color, TextSize, Center, Wrap })
]]

-- Lua 5.1 polyfills (for Delta & other non-Luau executors)
if not table.find then table.find = function(t, v) for i = 1, #t do if t[i] == v then return i end end end end
if not table.clear then table.clear = function(t) for k in pairs(t) do t[k] = nil end end end
if not math.round then math.round = function(x) return math.floor(x + 0.5) end end
if not math.clamp then math.clamp = function(x, min, max) return x < min and min or (x > max and max or x) end end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local UI = {}

local Theme = {
	Bg     = Color3.fromRGB(12, 12, 14),
	Panel  = Color3.fromRGB(22, 23, 27),
	Element = Color3.fromRGB(31, 32, 37),
	Hover  = Color3.fromRGB(42, 44, 50),
	Stroke = Color3.fromRGB(52, 54, 61),
	Text   = Color3.fromRGB(228, 229, 233),
	Muted  = Color3.fromRGB(148, 150, 158),
	Accent = Color3.fromRGB(86, 156, 255),
	AccentDim = Color3.fromRGB(24, 38, 58),
	Font   = Font.new("rbxasset://fonts/families/GothamSSm.json"),
	FontBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	Radius = UDim.new(0, 6),
}

local CheckAccent = Color3.fromRGB(86, 156, 255)

local function New(className, props, parent)
	local obj = Instance.new(className)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function Rounded(obj, r)
	New("UICorner", { CornerRadius = r or Theme.Radius }, obj)
	return obj
end

local function Stroked(obj, c)
	return New("UIStroke", {
		Color = c or Theme.Stroke,
		Thickness = 1,
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, obj)
end

local function Text(parent, text, size, color)
	return New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = text or "",
		TextColor3 = color or Theme.Text,
		TextSize = size or 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function Tween(obj, goal, time)
	return TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
end

local fadeOrigins = {}
local function GetOrigins(root)
	local o = fadeOrigins[root]
	if not o then
		o = { root = root:IsA("Frame") and root.BackgroundTransparency or nil }
		fadeOrigins[root] = o
	end
	for _, child in ipairs(root:GetDescendants()) do
		if not o[child] then
			local kind, val
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				kind, val = "Text", child.TextTransparency
			elseif child:IsA("Frame") then
				kind, val = "BG", child.BackgroundTransparency
			elseif child.ClassName == "UIStroke" then
				kind, val = "Stroke", child.Transparency
			end
			if kind then o[child] = { kind = kind, val = val } end
		end
	end
	return o
end

local function ForgetOrigins(root)
	fadeOrigins[root] = nil
end

local function FadeInGui(root, time)
	local o = GetOrigins(root)
	if o.root then root.BackgroundTransparency = 1 end
	for child, t in pairs(o) do
		if child ~= "root" and t.kind == "Text" then child.TextTransparency = 1
		elseif child ~= "root" and t.kind == "BG" then child.BackgroundTransparency = 1
		elseif child ~= "root" and t.kind == "Stroke" then child.Transparency = 1 end
	end
	if o.root then Tween(root, { BackgroundTransparency = o.root }, time):Play() end
	for child, t in pairs(o) do
		if child ~= "root" then
			if t.kind == "Text" then Tween(child, { TextTransparency = t.val }, time):Play()
			elseif t.kind == "BG" then Tween(child, { BackgroundTransparency = t.val }, time):Play()
			elseif t.kind == "Stroke" then Tween(child, { Transparency = t.val }, time):Play() end
		end
	end
end

local function FadeOutGui(root, time, callback)
	GetOrigins(root)
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			Tween(child, { TextTransparency = 1 }, time):Play()
		elseif child:IsA("Frame") then
			Tween(child, { BackgroundTransparency = 1 }, time):Play()
		elseif child.ClassName == "UIStroke" then
			Tween(child, { Transparency = 1 }, time):Play()
		end
	end
	if root:IsA("Frame") then Tween(root, { BackgroundTransparency = 1 }, time):Play() end
	if callback then task.delay(time + 0.05, callback) end
end

local trackedConns = {}
local function Track(conn)
	table.insert(trackedConns, conn)
	return conn
end

-- â”€â”€ CONFIG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local HttpService = game:GetService("HttpService")

local Config = {
	Folder = "LABAHUB_Configs",
	Elements = {},
	Settings = { AutoLoad = false },
	Current = nil,
}

function Config:Register(key, el)
	self.Elements[key] = el
end

function Config:Path(name)
	return self.Folder .. "/" .. name .. ".json"
end

function Config:Snapshot()
	local data = {}
	for k, el in pairs(self.Elements) do
		data[k] = el.Get()
	end
	return data
end

function Config:List()
	local raw = isfolder(self.Folder) and listfiles(self.Folder) or {}
	local names = {}
	for _, p in ipairs(raw) do
		if p:match("%.json$") and not p:match("_meta%.json$") then
			local name = p:match("([^/\\]+)%.json$")
			if name then table.insert(names, name) end
		end
	end
	table.sort(names)
	return names
end

function Config:Create(name, overwrite)
	name = tostring(name or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil, "enter a config name first" end
	local p = self:Path(name)
	if isfile(p) and not overwrite then return nil, "'" .. name .. "' already exists" end
	if not isfolder(self.Folder) then makefolder(self.Folder) end
	writefile(p, HttpService:JSONEncode(self:Snapshot()))
	self.Current = name
	self:SaveMeta()
	return name
end

function Config:Load(name)
	local p = self:Path(name)
	if not isfile(p) then return false end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(p))
	end)
	if not ok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		local el = self.Elements[k]
		if el and el.Set then el.Set(v) end
	end
	self.Current = name
	self:SaveMeta()
	return true
end

function Config:Delete(name)
	local p = self:Path(name)
	if not isfile(p) then return false end
	delfile(p)
	if self.Current == name then self.Current = nil end
	return true
end

function Config:SaveMeta()
	if not isfolder(self.Folder) then makefolder(self.Folder) end
	writefile(self.Folder .. "/_meta.json", HttpService:JSONEncode({
		AutoLoad = self.Settings.AutoLoad,
		Last = self.Current,
	}))
end

function Config:LoadMeta()
	if not isfile(self.Folder .. "/_meta.json") then return end
	local ok, meta = pcall(function()
		return HttpService:JSONDecode(readfile(self.Folder .. "/_meta.json"))
	end)
	if not ok or type(meta) ~= "table" then return end
	if meta.AutoLoad ~= nil then self.Settings.AutoLoad = meta.AutoLoad end
	self.Current = meta.Last
end

function Config:Init()
	self:LoadMeta()
	if self.Settings.AutoLoad and self.Current then
		self:Load(self.Current)
	end
end

local function CreateToggle(parent, props)
	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 44), BackgroundTransparency = 1 }, parent)

	New("TextLabel", {
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = props.Name or "Toggle",
		TextColor3 = Theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, row)

	local track = New("Frame", {
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(1, -46, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Element,
	}, row)
	Rounded(track, UDim.new(1, 0))
	Stroked(track)

	local knob = New("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Theme.Muted,
	}, track)
	Rounded(knob, UDim.new(1, 0))

	local value = not not props.Value
	local function SetState(v, noCallback)
		value = v
		Tween(knob, {
			Position = value and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2),
			BackgroundColor3 = value and Theme.Accent or Theme.Muted,
		}, 0.14):Play()
		if not noCallback and props.Callback then props.Callback(value) end
	end

	New("TextButton", {
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(1, -46, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	}, row).Activated:Connect(function()
		SetState(not value)
	end)

	SetState(value, true)

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return value end,
			Set = function(v) SetState(v, false) end,
		})
	end

	return { Get = function() return value end, Set = function(self, v) SetState(v, false) end, Instance = row }
end

local function CreateSlider(parent, props)
	local min, max = props.Min or 0, props.Max or 100
	local step = props.Step or 1
	local value = min
	if props.Value ~= nil then value = props.Value end
	local suffix = props.Suffix or ""

	if max < min then min, max = max, min end

	local function Round(v)
		local raw = (v - min) / step
		return min + math.round(raw) * step
	end
	local function ClampRound(v)
		return math.clamp(Round(v), min, max)
	end
	value = ClampRound(value)

	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 56), BackgroundTransparency = 1 }, parent)

	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, row)
	Text(head, props.Name or "Slider", 14, Theme.Text)
	local valLabel = Text(head, tostring(value) .. suffix, 13, Theme.Muted)
	valLabel.TextXAlignment = Enum.TextXAlignment.Right

	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = Theme.Element,
	}, row)
	Rounded(track, UDim.new(1, 0))
	Stroked(track)

	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent }, track)
	Rounded(fill, UDim.new(1, 0))

	local handle = New("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0, -6, 0.5, -6),
		BackgroundColor3 = Theme.Accent,
	}, track)
	Rounded(handle, UDim.new(1, 0))
	Stroked(handle)

	local function Update(v, noCallback)
		v = ClampRound(v)
		value = v
		local frac = (max ~= min) and (v - min) / (max - min) or 0
		fill.Size = UDim2.new(frac, 0, 1, 0)
		handle.Position = UDim2.new(frac, -6, 0.5, -6)
		valLabel.Text = tostring(v) .. suffix
		if not noCallback and props.Callback then props.Callback(v) end
	end

	local moveConn = nil
	local function startDrag()
		local function move(pos)
			local abs, size = track.AbsolutePosition, track.AbsoluteSize
			local x = math.clamp(pos.X - abs.X, 0, size.X)
			Update(min + (max - min) * (x / size.X))
		end
		move(UserInputService:GetMouseLocation())
		moveConn = Track(UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				move(UserInputService:GetMouseLocation())
			end
		end))
	end

	New("TextButton", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0.5, -7),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
	}, track).InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag()
			local releaseConn = Track(UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					if moveConn then moveConn:Disconnect() end
					if releaseConn then releaseConn:Disconnect() end
				end
			end))
		end
	end)

	Update(value, true)

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return value end,
			Set = function(v) Update(v, true) end,
		})
	end

	return { Get = function() return value end, Set = function(self, v) Update(v, true) end, Instance = row }
end

local function CreateButton(parent, props)
	local btn = New("TextButton", {
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundColor3 = Theme.Element,
		FontFace = Theme.Font,
		Text = props.Name or "Button",
		TextColor3 = Theme.Text,
		TextSize = 14,
		AutoButtonColor = false,
	}, parent)
	Rounded(btn)
	local stroke = Stroked(btn)
	btn.MouseEnter:Connect(function()
		Tween(btn, { BackgroundColor3 = Theme.Hover }, 0.12):Play()
		Tween(btn, { TextColor3 = Theme.Accent }, 0.12):Play()
		Tween(stroke, { Color = Theme.Accent, Transparency = 0.35 }, 0.12):Play()
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, { BackgroundColor3 = Theme.Element }, 0.12):Play()
		Tween(btn, { TextColor3 = Theme.Text }, 0.12):Play()
		Tween(stroke, { Color = Theme.Stroke, Transparency = 0.4 }, 0.12):Play()
	end)
	btn.Activated:Connect(function()
		if props.Callback then props.Callback() end
	end)
	return btn
end

local function CreateTextBox(parent, props)
	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 52), BackgroundTransparency = 1 }, parent)
	Text(row, props.Name or "Textbox", 14, Theme.Text)

	local box = New("TextBox", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -30),
		BackgroundColor3 = Theme.Element,
		FontFace = Theme.Font,
		Text = props.Value or "",
		PlaceholderText = props.Placeholder or "Type here",
		PlaceholderColor3 = Theme.Muted,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 3,
	}, row)
	Rounded(box, UDim.new(0, 6))
	Stroked(box)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, box)
	local suppress = false
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if suppress then return end
		if props.Callback then props.Callback(box.Text) end
	end)

	local function SetText(v, noCallback)
		v = tostring(v or "")
		if box.Text == v then
			if not noCallback and props.Callback then props.Callback(v) end
			return
		end
		suppress = true
		box.Text = v
		suppress = false
		if not noCallback and props.Callback then props.Callback(v) end
	end

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return box.Text end,
			Set = function(v) SetText(v, true) end,
		})
	end

	return { Get = function() return box.Text end, Set = function(self, v) SetText(v, true) end, Focus = function() box:CaptureFocus() end, Instance = box }
end

local function CreateParagraph(parent, props)
	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 120), BackgroundTransparency = 1 }, parent)
	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, row)
	Text(head, props.Name or "Paragraph", 14, Theme.Text)

	local box = New("TextBox", {
		Size = UDim2.new(1, 0, 1, -26),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = Theme.Element,
		FontFace = Theme.Font,
		Text = props.Value or "",
		PlaceholderText = props.Placeholder or "Type here...",
		PlaceholderColor3 = Theme.Muted,
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		ZIndex = 3,
	}, row)
	Rounded(box, UDim.new(0, 6))
	Stroked(box)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	}, box)

	local suppress = false -- Fix: declared before SetText so both closures share the same upvalue
	local function SetText(v, noCallback)
		v = tostring(v or "")
		if box.Text == v then
			if not noCallback and props.Callback then props.Callback(v) end
			return
		end
		suppress = true
		box.Text = v
		suppress = false
		if not noCallback and props.Callback then props.Callback(v) end
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if suppress then return end
		if props.Callback then props.Callback(box.Text) end
	end)

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return box.Text end,
			Set = function(v) SetText(v, true) end,
		})
	end

	return { Get = function() return box.Text end, Set = function(self, v) SetText(v, true) end, Focus = function() box:CaptureFocus() end, Instance = box }
end

local function CreateSegmented(parent, props)
	local options = props.Options or {}
	local selected = props.Value
	if not table.find(options, selected) then selected = options[1] end

	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 76), BackgroundTransparency = 1 }, parent)
	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, row)
	Text(head, props.Name or "Segmented", 14, Theme.Text)

	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 1, -34),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
	}, row)
	Rounded(track, UDim.new(0, 6))

	local buttons = {}
	local function SetSelected(v, noCallback)
		selected = v
		for i, opt in ipairs(options) do
			local on = opt == selected
			local b = buttons[i]
			Tween(b, { BackgroundColor3 = on and Theme.Accent or Theme.Element }, 0.12):Play()
			Tween(b, { TextColor3 = on and Color3.fromRGB(12, 12, 14) or Theme.Muted }, 0.12):Play()
		end
		if not noCallback and props.Callback then props.Callback(selected) end
	end

	local count = #options
	for i, opt in ipairs(options) do
		local w = 1 / count
		local b = New("TextButton", {
			Size = UDim2.new(w, 0, 1, 0),
			Position = UDim2.new((i - 1) * w, 0, 0, 0),
			BackgroundColor3 = Theme.Element,
			FontFace = Theme.Font,
			Text = opt,
			TextColor3 = Theme.Muted,
			TextSize = 13,
			AutoButtonColor = false,
			ZIndex = 2,
		}, track)
		Rounded(b, UDim.new(0, 4))
		b.Activated:Connect(function() SetSelected(opt) end)
		buttons[i] = b
	end

	SetSelected(selected, true)

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return selected end,
			Set = function(v)
				if table.find(options, v) then SetSelected(v, true) end
			end,
		})
	end

	return { Get = function() return selected end, Set = function(self, v) if table.find(options, v) then SetSelected(v, true) end end, Instance = row }
end

local function CreateList(parent, props)
	local options = props.Options or {}
	local selected = props.Value
	if not table.find(options, selected) then selected = options[1] end

	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 172), BackgroundTransparency = 1 }, parent)
	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, row)
	Text(head, props.Name or "List", 14, Theme.Text)

	local search = New("TextBox", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = Theme.Element,
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.Muted,
		FontFace = Theme.Font,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 3,
	}, row)
	Rounded(search, UDim.new(0, 5))
	Stroked(search)
	New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, search)

	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -56),
		Position = UDim2.new(0, 0, 0, 56),
		BackgroundColor3 = Theme.Element,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, #options * 30),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
	}, row)
	Rounded(list, UDim.new(0, 6))
	Stroked(list)

	local content = New("Frame", {
		Size = UDim2.new(1, 0, 0, #options * 30),
		BackgroundTransparency = 1,
	}, list)
	New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, content)

	local widgets = {}
	local function SetSelected(v, noCallback)
		selected = v
		for opt, w in pairs(widgets) do
			local on = opt == selected
			w.Button.BackgroundColor3 = on and Theme.AccentDim or Color3.fromRGB(0, 0, 0)
			w.Button.BackgroundTransparency = on and 0 or 1
			w.Name.TextColor3 = on and Theme.Accent or Theme.Text
		end
		if not noCallback and props.Callback then props.Callback(selected) end
	end

	local function RenderOptions()
		local query = search.Text:lower()
		local shown = {}
		for _, opt in ipairs(options) do
			if query == "" or opt:lower():find(query, 1, true) then
				table.insert(shown, opt)
			end
		end
		list.CanvasSize = UDim2.new(0, 0, 0, #shown * 30)
		content.Size = UDim2.new(1, 0, 0, #shown * 30)
		for _, ch in ipairs(content:GetChildren()) do ch:Destroy() end
		widgets = {}
		for i, opt in ipairs(shown) do
			local b = New("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.fromOffset(0, (i - 1) * 30),
				BackgroundTransparency = 1,
			}, content)
			Rounded(b, UDim.new(0, 4))
			local name = New("TextLabel", {
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(10, 0),
				BackgroundTransparency = 1,
				FontFace = Theme.Font,
				Text = opt,
				TextColor3 = opt == selected and Theme.Accent or Theme.Text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 2,
			}, b)
			local btn = New("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 3,
			}, b)
			btn.Activated:Connect(function()
				SetSelected(opt)
			end)
			widgets[opt] = { Button = b, Name = name }
		end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		RenderOptions()
	end)

	RenderOptions()
	SetSelected(selected, true)

	if props.Key then
		Config:Register(props.Key, {
			Get = function() return selected end,
			Set = function(v)
				if table.find(options, v) then SetSelected(v, false) end
			end,
		})
	end

	return { Get = function() return selected end, Set = function(self, v) if table.find(options, v) then SetSelected(v, false) end end, SetOptions = function(self, newOpts) options = newOpts or {}; RenderOptions() end, Instance = row }
end

local function CreateLabel(parent, props)
	local row = New("Frame", {
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundTransparency = 1,
	}, parent)
	New("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = props.Name or "",
		TextColor3 = props.Color or Theme.Muted,
		TextSize = props.TextSize or 13,
		TextXAlignment = props.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = props.Wrap or false,
		RichText = props.RichText or false,
	}, row)
	return row
end

local function CreateDropdown(parent, props)
	local row = New("Frame", { Size = UDim2.new(1, -24, 0, 52), BackgroundTransparency = 1 }, parent)
	local head = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1 }, row)
	Text(head, props.Name or "Dropdown", 14, Theme.Text)

	local field = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -30),
		BackgroundColor3 = Theme.Element,
		Active = true,
		ZIndex = 3,
	}, row)
	Rounded(field, UDim.new(0, 6))

	local valueLabel = New("TextLabel", {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = props.Value and type(props.Value) == "table" and "" or (props.Value or (props.Options and props.Options[1]) or ""),
		TextColor3 = Theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 4,
	}, field)

	local multi = props.Multi or false
	local selection = valueLabel.Text
	local options = props.Options or {}
	local n = #options
	local selectedSet = {}
	local optionWidgets = {}
	for _, o in ipairs(type(props.Value) == "table" and props.Value or {}) do
		if table.find(options, o) then selectedSet[o] = true end
	end
	local visibleCount = math.clamp(n, 1, 5)
	local menuH = visibleCount * 30 + 42
	local menu = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 4),
		BackgroundColor3 = Theme.Panel,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 5,
	}, field)
	Rounded(menu, UDim.new(0, 6))
	Stroked(menu)

	local search = New("TextBox", {
		Size = UDim2.new(1, -10, 0, 26),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = Theme.Element,
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.Muted,
		FontFace = Theme.Font,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 7,
	}, menu)
	Rounded(search, UDim.new(0, 5))
	Stroked(search)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, search)

	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, -10, 1, -44),
		Position = UDim2.new(0, 5, 0, 37),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, n * 30),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
	}, menu)

	local content = New("Frame", {
		Size = UDim2.new(1, 0, 0, n * 30),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, list)

	local openTween = nil
	local function Open()
		row.ZIndex = 50
		menu.Visible = true
		if openTween then openTween:Cancel() end
		openTween = Tween(menu, { Size = UDim2.new(1, 0, 0, menuH) }, 0.18)
		openTween:Play()
	end
	local function Close()
		row.ZIndex = 1
		if openTween then openTween:Cancel() end
		openTween = Tween(menu, { Size = UDim2.new(1, 0, 0, 0) }, 0.12)
		openTween:Play()
		task.spawn(function()
			task.wait(0.13)
			if menu.Size.Y.Offset <= 1 then menu.Visible = false end
		end)
	end

	local function Emit(value)
		if props.Callback then props.Callback(value) end
	end

	local function UpdateLabel()
		if multi then
			local chosen = {}
			for _, o in ipairs(options) do
				if selectedSet[o] then table.insert(chosen, o) end
			end
			if #chosen == 0 then
				valueLabel.Text = "None selected"
			elseif #chosen == 1 then
				valueLabel.Text = chosen[1]
			elseif #chosen == 2 then
				valueLabel.Text = chosen[1] .. ", " .. chosen[2]
			else
				valueLabel.Text = #chosen .. " selected"
			end
		else
			valueLabel.Text = selection
		end
	end

	local function SetRowState(opt)
		local w = optionWidgets[opt]
		if not w or not w.Check then return end
		local on = selectedSet[opt] or false
		w.Check.BackgroundColor3 = on and CheckAccent or Theme.Element
		local mark = w.Check:FindFirstChildOfClass("TextLabel")
		if mark then mark.Visible = on end
	end

	local function SyncRows()
		for opt in pairs(optionWidgets) do SetRowState(opt) end
	end

	local function GetValue()
		if not multi then return selection end
		local t = {}
		for _, o in ipairs(options) do
			if selectedSet[o] then table.insert(t, o) end
		end
		return t
	end

	local function Select(opt, noCallback)
		if not table.find(options, opt) then return end
		if multi then
			if selectedSet[opt] then selectedSet[opt] = nil else selectedSet[opt] = true end
			SetRowState(opt)
			UpdateLabel()
			if not noCallback then Emit(GetValue()) end
			return
		end
		selection = opt
		valueLabel.Text = opt
		Close()
		if not noCallback and props.Callback then props.Callback(opt) end
	end

	local function SetSelection(v, noCallback)
		v = v or {}
		for k in pairs(selectedSet) do selectedSet[k] = nil end
		for _, o in ipairs(v) do
			if table.find(options, o) then selectedSet[o] = true end
		end
		SyncRows()
		UpdateLabel()
		if not noCallback and props.Callback then props.Callback(GetValue()) end
	end

	local function RenderOptions()
		local query = search.Text:lower()
		local shown = {}
		for _, opt in ipairs(options) do
			if query == "" or opt:lower():find(query, 1, true) then
				table.insert(shown, opt)
			end
		end
		list.CanvasSize = UDim2.new(0, 0, 0, #shown * 30)
		content.Size = UDim2.new(1, 0, 0, #shown * 30)
		for _, ch in ipairs(content:GetChildren()) do ch:Destroy() end
		optionWidgets = {}
		for i, opt in ipairs(shown) do
			local b = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.fromOffset(0, (i - 1) * 30),
				BackgroundColor3 = Theme.Panel,
				BackgroundTransparency = 0,
				FontFace = Theme.Font,
				Text = (multi and "" or opt),
				TextColor3 = Theme.Text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				ZIndex = 7,
			}, content)
			Rounded(b, UDim.new(0, 4))
			local check
			if multi then
				check = New("Frame", {
					Size = UDim2.fromOffset(16, 16),
					Position = UDim2.fromOffset(8, 6),
					BackgroundColor3 = Theme.Element,
					ZIndex = 8,
				}, b)
				Rounded(check, UDim.new(0, 4))
				Stroked(check)
				check.Name = "Check"
				New("TextLabel", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					FontFace = Theme.Font,
					Text = "✓",
					TextColor3 = Color3.fromRGB(12, 12, 14),
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 9,
				}, check)
				New("TextLabel", {
					Size = UDim2.new(1, -44, 1, 0),
					Position = UDim2.fromOffset(34, 0),
					BackgroundTransparency = 1,
					FontFace = Theme.Font,
					Text = opt,
					TextColor3 = Theme.Text,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 8,
				}, b)
			else
				New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
			end
			optionWidgets[opt] = { Button = b, Check = check }
			b.MouseEnter:Connect(function()
				Tween(b, { BackgroundColor3 = Theme.Hover }, 0.1):Play()
			end)
			b.MouseLeave:Connect(function()
				Tween(b, { BackgroundColor3 = Theme.Panel }, 0.1):Play()
			end)
			b.Activated:Connect(function()
				Select(opt)
			end)
		end
		SyncRows()
	end

	local function RebuildOptions(newOpts)
		options = newOpts or {}
		n = #options
		visibleCount = math.clamp(n, 1, 5)
		menuH = visibleCount * 30 + 42
		search.Text = ""
		RenderOptions()
		if not multi and not table.find(options, selection) then
			if #options > 0 then Select(options[1], true) else selection = "" valueLabel.Text = "" end
		end
		if multi then UpdateLabel() end
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		RenderOptions()
	end)

	RebuildOptions(options)

	field.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if menu.Visible then Close() else Open() end
		end
	end)

	if props.Key then
		Config:Register(props.Key, {
			Get = GetValue,
			Set = function(v)
				if multi then SetSelection(v, false)
				else Select(v, false) end
			end,
		})
	end

	return {
		Value = function(self) return GetValue() end,
		Set = function(self, v)
			if multi then SetSelection(v, false)
			else Select(v, false) end
		end,
		SetOptions = function(self, newOpts) RebuildOptions(newOpts) end,
		Instance = row,
	}
end

local function CreateIntro(screen, config, onDone)
	local spec = config.Intro
	local title = spec.Title or config.Title or "UI"
	local subtitle = spec.Subtitle or "Loading..."
	local duration = spec.Duration or 3

	local overlay = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.35,
		ZIndex = 150,
	}, screen)

	local card = New("Frame", {
		Size = UDim2.fromOffset(320, 140),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Panel,
	}, overlay)
	Rounded(card, UDim.new(0, 10))
	Stroked(card)

	New("TextLabel", {
		Size = UDim2.new(1, -32, 0, 30),
		Position = UDim2.fromOffset(16, 22),
		BackgroundTransparency = 1,
		FontFace = Theme.FontBold,
		Text = title,
		TextColor3 = Theme.Accent,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	}, card)

	New("TextLabel", {
		Size = UDim2.new(1, -32, 0, 20),
		Position = UDim2.fromOffset(16, 56),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = subtitle,
		TextColor3 = Theme.Muted,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	}, card)

	local bar = New("Frame", {
		Size = UDim2.new(1, -48, 0, 4),
		Position = UDim2.new(0, 24, 1, -30),
		BackgroundColor3 = Theme.Element,
	}, card)
	Rounded(bar, UDim.new(1, 0))
	Stroked(bar)

	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
	}, bar)
	Rounded(fill, UDim.new(1, 0))

	FadeInGui(overlay, 0.3)

	local function Hide()
		FadeOutGui(overlay, 0.4, function()
			if overlay.Parent then overlay:Destroy() end
			if onDone then onDone() end
		end)
	end

	local tween = Tween(fill, { Size = UDim2.fromScale(1, 1) }, duration)
	tween.Completed:Connect(Hide)
	tween:Play()

	return overlay
end

function UI:CreateWindow(config)
	local screen = New("ScreenGui", {
		Name = "MyObsidianUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, LocalPlayer.PlayerGui)

	New("UIScale", { Scale = config.Scale or 1 }, screen)

	local shadow = New("Frame", {
		Size = config.Size or UDim2.fromOffset(560, 400),
		Position = (config.Position or UDim2.fromScale(0.5, 0.5)) + UDim2.fromOffset(0, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.72,
		ZIndex = 1,
	}, screen)
	Rounded(shadow, UDim.new(0, 8))

	local window = New("Frame", {
		Size = config.Size or UDim2.fromOffset(560, 400),
		Position = config.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Bg,
		ClipsDescendants = true,
		ZIndex = 2,
	}, screen)
	Rounded(window, UDim.new(0, 8))
	Stroked(window)
	local winScale = New("UIScale", { Scale = 1 }, window)
	local shadowScale = New("UIScale", { Scale = 1 }, shadow)

	local titleBar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.Panel,
		ZIndex = 2,
		Active = true,
	}, window)
	New("UICorner", { CornerRadius = UDim.new(0, 8) }, titleBar)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Theme.Accent,
		ZIndex = 4,
	}, titleBar)
	New("TextLabel", {
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.FontBold,
		Text = config.Title or "UI",
		TextColor3 = Theme.Accent,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 3,
	}, titleBar)

	local function ToPill()
		local pill = New("TextButton", {
			Size = UDim2.fromOffset(120, 34),
			Position = UDim2.new(1, -12, 0, 12),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.AccentDim,
			FontFace = Theme.FontBold,
			Text = "◉  " .. (config.Title or "UI"),
			TextColor3 = Theme.Accent,
			TextSize = 13,
			AutoButtonColor = false,
		}, screen)
		Rounded(pill, UDim.new(0, 6))
		Stroked(pill)
		local pillScale = New("UIScale", { Scale = 0 }, pill)

		local startPos = window.Position
		local startShadowPos = shadow.Position
		local endScale = 0.08

		local windowTween = Tween(window, { Position = UDim2.fromScale(0.5, 0) }, 0.25)
		local shadowTween = Tween(shadow, { Position = UDim2.fromScale(0.5, 0) + UDim2.fromOffset(0, 8) }, 0.25)
		local windowScaleTween = Tween(winScale, { Scale = endScale }, 0.25)
		local shadowScaleTween = Tween(shadowScale, { Scale = endScale }, 0.25)
		FadeOutGui(window, 0.25, function()
			window.Visible = false
			shadow.Visible = false
		end)

		windowTween:Play()
		shadowTween:Play()
		windowScaleTween:Play()
		shadowScaleTween:Play()
		Tween(pillScale, { Scale = 1 }, 0.25):Play()

		pill.Activated:Connect(function()
			if not pill.Parent then return end
			Tween(pillScale, { Scale = 0 }, 0.2):Play()
			FadeOutGui(pill, 0.2, function() if pill.Parent then pill:Destroy() end end)
			window.Visible = true
			shadow.Visible = true
			winScale.Scale = endScale
			shadowScale.Scale = endScale
			window.Position = UDim2.fromScale(0.5, 0)
			shadow.Position = UDim2.fromScale(0.5, 0) + UDim2.fromOffset(0, 8)
			Tween(winScale, { Scale = 1 }, 0.25):Play()
			Tween(shadowScale, { Scale = 1 }, 0.25):Play()
			Tween(window, { Position = startPos }, 0.25):Play()
			Tween(shadow, { Position = startShadowPos }, 0.25):Play()
			FadeInGui(window, 0.25)
			FadeInGui(shadow, 0.25)
		end)
	end

	local closeBtn = New("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -34, 0.5, -13),
		BackgroundColor3 = Theme.Element,
		FontFace = Theme.Font,
		Text = "X",
		TextColor3 = Theme.Muted,
		TextSize = 12,
		AutoButtonColor = false,
		ZIndex = 4,
	}, titleBar)
	Rounded(closeBtn, UDim.new(0, 6))

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local mp = UserInputService:GetMouseLocation()
			local cb = closeBtn.AbsolutePosition
			local cs = closeBtn.AbsoluteSize
			if mp.X >= cb.X and mp.X <= cb.X + cs.X and mp.Y >= cb.Y and mp.Y <= cb.Y + cs.Y then
				return
			end
			local last = mp
			local conn
			conn = Track(UserInputService.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
					local cur = UserInputService:GetMouseLocation()
					local delta = cur - last
					last = cur
					if delta.Magnitude > 0 then
						window.Position = window.Position + UDim2.fromOffset(delta.X, delta.Y)
						shadow.Position = window.Position + UDim2.fromOffset(0, 8)
					end
				end
			end))
			local releaseConn = Track(UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					if conn then conn:Disconnect() end
					if releaseConn then releaseConn:Disconnect() end
				end
			end))
		end
	end)

	closeBtn.Activated:Connect(function()
		ToPill()
	end)

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 1, -46),
		Position = UDim2.new(0, 0, 0, 46),
		BackgroundTransparency = 1,
	}, window)

	local rail = New("Frame", { Size = UDim2.new(0, 160, 1, 0), BackgroundColor3 = Theme.Panel }, body)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, rail)
	New("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, rail)

	local content = New("Frame", {
		Size = UDim2.new(1, -160, 1, 0),
		Position = UDim2.new(0, 160, 0, 0),
		BackgroundTransparency = 1,
	}, body)

	local pages = {}

	local function SelectTab(tab)
		for _, p in ipairs(pages) do
			p.Page.Visible = (p == tab)
			Tween(p.Button, { BackgroundColor3 = p == tab and Theme.AccentDim or Theme.Panel }, 0.15):Play()
			Tween(p.Button, { TextColor3 = p == tab and Theme.Accent or Theme.Muted }, 0.15):Play()
			Tween(p.Bar, { BackgroundTransparency = p == tab and 0 or 1 }, 0.15):Play()
		end
	end

	local tabAPI = {}

	function tabAPI:AddTab(title)
		local page = New("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Stroke,
			Visible = false,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, content)
		New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		New("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}, page)

		local btn = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Theme.Panel,
			FontFace = Theme.Font,
			Text = title,
			TextColor3 = Theme.Muted,
			TextSize = 14,
			AutoButtonColor = false,
		}, rail)
		Rounded(btn, UDim.new(0, 6))

		local bar = New("Frame", {
			Size = UDim2.fromOffset(3, 20),
			Position = UDim2.new(0, 5, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, btn)
		Rounded(bar, UDim.new(0, 4))

		local tab = {
			Title = title,
			Page = page,
			Button = btn,
			Bar = bar,
			AddToggle = function(_, props) return CreateToggle(page, props) end,
			AddSlider = function(_, props) return CreateSlider(page, props) end,
			AddButton = function(_, props) return CreateButton(page, props) end,
			AddTextBox = function(_, props) return CreateTextBox(page, props) end,
			AddLabel = function(_, props) return CreateLabel(page, props) end,
			AddDropdown = function(_, props) return CreateDropdown(page, props) end,
			AddParagraph = function(_, props) return CreateParagraph(page, props) end,
			AddSegmented = function(_, props) return CreateSegmented(page, props) end,
			AddList = function(_, props) return CreateList(page, props) end,
		}

		btn.Activated:Connect(function()
			SelectTab(tab)
		end)

		table.insert(pages, tab)
		if #pages == 1 then SelectTab(tab) end
		return tab
	end

	local notifyHolder = New("Frame", {
		Size = UDim2.new(1, -24, 1, -24),
		Position = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, screen)

	local NotifyStyles = {
		info    = Color3.fromRGB(120, 180, 255),
		success = Color3.fromRGB(120, 220, 140),
		warning = Color3.fromRGB(240, 200, 90),
		error   = Color3.fromRGB(240, 110, 110),
	}

	local activeNotifs = {}

	local function ReflowNotifs(skip)
		local y = 0
		for _, n in ipairs(activeNotifs) do
			n.Target = y
			if n ~= skip then
				Tween(n.Frame, { Position = UDim2.new(1, 0, 0, y) }, 0.2):Play()
			end
			y = y + n.Frame.Size.Y.Offset + 8
		end
	end

	local function FadeOut(entry)
		local frame = entry.Frame
		if not frame.Parent then return end
		for _, child in ipairs(frame:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				Tween(child, { TextTransparency = 1 }, 0.18):Play()
			elseif child:IsA("Frame") then
				Tween(child, { BackgroundTransparency = 1 }, 0.18):Play()
			elseif child.ClassName == "UIStroke" then
				Tween(child, { Transparency = 1 }, 0.18):Play()
			end
		end
		local slide = Tween(frame, { Position = UDim2.new(1, 44, 0, entry.Target or 0) }, 0.22)
		slide.Completed:Connect(function()
			frame:Destroy()
		end)
		slide:Play()
	end

	function tabAPI:Notify(title, text, duration, style)
		duration = duration or 4
		style = style or "info"
		local color = NotifyStyles[style] or NotifyStyles.info

		local frame = New("Frame", {
			Size = UDim2.fromOffset(320, 60),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 44, 0, 0),
			BackgroundColor3 = Theme.Panel,
			ZIndex = 100,
		}, notifyHolder)
		Rounded(frame, UDim.new(0, 8))
		Stroked(frame)

		local entry = { Frame = frame, Target = 0 }

		New("Frame", {
			Size = UDim2.new(0, 4, 1, 0), -- Fix: full-height left accent bar (was 1px tall)
			BackgroundColor3 = color,
			ZIndex = 101,
		}, frame)

		New("TextLabel", {
			Size = UDim2.new(1, -52, 0, 18),
			Position = UDim2.fromOffset(18, 9),
			BackgroundTransparency = 1,
			FontFace = Theme.Font,
			Text = title or "Notification",
			TextColor3 = color,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 101,
		}, frame)

		New("TextLabel", {
			Size = UDim2.new(1, -52, 1, -34),
			Position = UDim2.fromOffset(18, 28),
			BackgroundTransparency = 1,
			FontFace = Theme.Font,
			Text = text or "",
			TextColor3 = Theme.Muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			ZIndex = 101,
		}, frame)

		New("TextButton", {
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(1, -26, 0, 8),
			BackgroundTransparency = 1,
			FontFace = Theme.Font,
			Text = "X",
			TextColor3 = Theme.Muted,
			TextSize = 12,
			AutoButtonColor = false,
			ZIndex = 102,
		}, frame).Activated:Connect(function()
			local i = table.find(activeNotifs, entry)
			if i then table.remove(activeNotifs, i) end
			FadeOut(entry)
			ReflowNotifs()
		end)

		table.insert(activeNotifs, entry)
		ReflowNotifs(entry)
		Tween(frame, { Position = UDim2.new(1, 0, 0, entry.Target) }, 0.3):Play()
		task.delay(duration, function()
			local i = table.find(activeNotifs, entry)
			if i then table.remove(activeNotifs, i) end
			FadeOut(entry)
			ReflowNotifs()
		end)
	end

	tabAPI.Window = window
	tabAPI.Screen = screen

	if config.Intro then
		window.Visible = false
		shadow.Visible = false
		CreateIntro(screen, config, function()
			window.Visible = true
			shadow.Visible = true
			FadeInGui(window, 0.3)
			FadeInGui(shadow, 0.3)
		end)
	end

	function tabAPI:Destroy()
		for i = #trackedConns, 1, -1 do
			pcall(function() trackedConns[i]:Disconnect() end)
		end
		table.clear(trackedConns)
		for key in pairs(Config.Elements) do Config.Elements[key] = nil end
		ForgetOrigins(window)
		ForgetOrigins(shadow)
		if screen and screen.Parent then
			FadeOutGui(window, 0.2, function()
				if screen.Parent then screen:Destroy() end
			end)
		end
	end

	return tabAPI
end

UI.Config = Config

return UI
]=])()
local W = UI:CreateWindow({
	Title = "LABA HUB",
	Size = UDim2.fromOffset(560, 420),
	Intro = { Title = "LABA HUB", Subtitle = "COMSHOP", Duration = 1.5 },
})

local ht = W:AddTab("Home")
local st = W:AddTab("SHOP")

local ta = ht:AddToggle({ Name="Auto Appoint", Value=AA, Key="AutoAppoint", Callback=function(v)AA=v;Per.AutoAppoint=v end })
local tc = ht:AddToggle({ Name="Auto Clean", Value=AC, Key="AutoClean", Callback=function(v)AC=v;Per.AutoClean=v end })
local tf = ht:AddToggle({ Name="Auto Chef", Value=AF, Key="AutoChef", Callback=function(v)AF=v;Per.AutoChef=v end })
local te = ht:AddToggle({ Name="Auto Fire Extinguisher", Value=AE, Key="AutoExt", Callback=function(v)AE=v;Per.AutoExt=v end })
local tak = ht:AddToggle({ Name="Anti AFK", Value=AAFK, Key="AntiAFK", Callback=function(v)AAFK=v;Per.AntiAFK=v end })
	local tbAP = ht:AddToggle({ Name="Auto Print (buy ink<20/paper<20)", Value=AP, Key="AutoPrint", Callback=function(v)AP=v;Per.AutoPrint=v end })
	local tbAB = ht:AddToggle({ Name="Auto Pay Bills", Value=AB, Key="AutoBill", Callback=function(v)AB=v;Per.AutoBill=v end })

-- Anti-AFK heartbeat (prevents Roblox idle kick)
task.spawn(function()
	while alive() do task.wait(60)
		if AAFK then pcall(function()
			VU:CaptureController()
			VU:Button2Down(Vector2.new())
			task.wait(0.1)
			VU:Button2Up(Vector2.new())
		end) end
	end
end)

-- SHOP tab
local BuyG, BuyP, BuyA = false, false, false
-- Color variants White/Pink/Red require PC variant pass — not included. Buy base items only (free).
-- Initial-B and Initial-P are separate stock IDs (free), not variants.
-- Sorted by star rating (highest first), then by price within the same star tier.
local pcN={
    -- ⭐⭐⭐⭐⭐ 5 Stars
    "Vortessa","PinkDrift","Snowdrift","AvianoDesk","Dark Nexus",
    "Initial-B","Initial-P","Sakura","AvianoChair","Polar X",
    "GamingTable","Aether","HollowFrame","NexusChair","KittyChair",
    "CyberCurve","ArcView","Overdrive","G-Force","Nightfall Keyboard",
    "Spider-X Keyboard","Nocturne","Blossom Keyboard","Revv","Shadow",
    -- ⭐⭐⭐⭐ 4 Stars
    "Voltara","Hexora","Vesta","CleanDesk","SlimDesk",
    "AngleView","V-View","Horizon","Fuji","Petal",
    "Sora","[60 - Key ] Keyboard","Evergreen","OfficeChair",
    -- ⭐⭐⭐ 3 Stars
    "Throne","StoneChair","Galon","TriFan-Core","BlockView",
    "Konoha","Kasumi","Wavy","Hanami","TriFan-Lite","[75 - Key ] Keyboard",
    -- ⭐⭐ 2 Stars
    "ShelfDesk","Midnight","BoxDesk","Azure","Ripple",
    "RoundView","Hoshi","Japan","Nimbus","[80 - Key ] Keyboard",
    "FlatCore","PulseCore","FoldingChair","Monoblock",
    -- ⭐ 1 Star
    "FrameDesk","Slate","WideView","[100 - Key ] Keyboard",
    "OpenDesk","ClassicCore","Collage","WoodenChair",
}
local grN={"Bcat","Beef Loaf","C5 Apol","C5 Klasik","C5 Limon","Cooking Oil","Lumpia","Mang Kanor","Pancit Kalamansi","Piyatos","Sayang","Toby","Water"}
local accN={"Blorb","Car","Convertible","Cute Plushie","Kitty Plush","Oi Oi Oi","PineappleHouse","RedBullCar"}
local ddP = st:AddDropdown({ Name="PC Parts", Multi=true, Options=pcN, Value={}, Key="PCItems", Callback=function(s)PCItems={};if type(s)=="table" then for _,n in ipairs(s)do PCItems[n]=true end elseif s then PCItems[s]=true end end })
local tbP = st:AddToggle({ Name="PC Parts Buy", Value=BuyP, Key="BuyP", Callback=function(v)BuyP=v end })
st:AddButton({ Name="★ Select All Parts", Callback=function()
	ddP:Set(pcN); PCItems={}; for _,n in ipairs(pcN) do PCItems[n]=true end
end })
local ddG = st:AddDropdown({ Name="Grocery", Multi=true, Options=grN, Value={}, Key="GroceryItems", Callback=function(s)GroceryItems={};if type(s)=="table" then for _,n in ipairs(s)do GroceryItems[n]=true end elseif s then GroceryItems[s]=true end end })
local tbG = st:AddToggle({ Name="Grocery Buy", Value=BuyG, Key="BuyG", Callback=function(v)BuyG=v end })
st:AddButton({ Name="Select All Grocery", Callback=function()
	ddG:Set(grN); GroceryItems={}; for _,n in ipairs(grN) do GroceryItems[n]=true end
end })
local ddA = st:AddDropdown({ Name="Accessories", Multi=true, Options=accN, Value={}, Key="AccItems", Callback=function(s)AccItems={};if type(s)=="table" then for _,n in ipairs(s)do AccItems[n]=true end elseif s then AccItems[s]=true end end })
local tbA = st:AddToggle({ Name="Accessories Buy", Value=BuyA, Key="BuyA", Callback=function(v)BuyA=v end })

-- CONFIG tab
local cf = W:AddTab("Config")
local cfgName
local cfgList
cfgName = cf:AddTextBox({
	Name = "Config Name",
	Placeholder = "name this config...",
	Value = "",
	Key = "ConfigName",
	Callback = function(v) end,
})
cf:AddButton({
	Name = "Save Config",
	Callback = function()
		local name = cfgName.Get()
		local ok, err = UI.Config:Create(name)
		if ok then
			W:Notify("Config", "Saved '" .. name .. "'")
			cfgList:SetOptions(UI.Config:List())
		else
			W:Notify("Config", err, 3, "error")
		end
	end,
})
cf:AddButton({
	Name = "Overwrite Config",
	Callback = function()
		local name = cfgList:Value()
		if not name or name == "" then
			W:Notify("Config", "Select a saved config first", 3, "warning")
			return
		end
		local ok, err = UI.Config:Create(name, true)
		if ok then
			W:Notify("Config", "Overwrote '" .. name .. "'")
			cfgList:SetOptions(UI.Config:List())
		else
			W:Notify("Config", err, 3, "error")
		end
	end,
})
cf:AddButton({
	Name = "Load Config",
	Callback = function()
		local name = cfgList:Value()
		if UI.Config:Load(name) then
			W:Notify("Config", "Loaded '" .. name .. "'", 3, "success")
		else
			W:Notify("Config", "Failed to load '" .. name .. "'", 3, "error")
		end
	end,
})
cf:AddButton({
	Name = "Delete Config",
	Callback = function()
		local name = cfgList:Value()
		if UI.Config:Delete(name) then
			W:Notify("Config", "Deleted '" .. name .. "'", 3, "warning")
			cfgList:SetOptions(UI.Config:List())
		else
			W:Notify("Config", "Not found: '" .. name .. "'", 3, "error")
		end
	end,
})
cfgList = cf:AddDropdown({
	Name = "Saved Configs",
	Options = UI.Config:List(),
	Value = nil,
	Key = "ConfigList",
	Callback = function(o) end,
})
UI.Config:LoadMeta()
cf:AddToggle({
	Name = "Auto Load",
	Value = UI.Config.Settings.AutoLoad,
	Callback = function(v)
		UI.Config.Settings.AutoLoad = v
		UI.Config:SaveMeta()
		if v then
			local name = cfgList:Value() or UI.Config.Current
			if name and name ~= "" then
				if UI.Config:Load(name) then
					W:Notify("Config", "Auto load '" .. name .. "'", 3, "success")
				else
					W:Notify("Config", "Failed to load '" .. name .. "'", 3, "error")
				end
			else
				W:Notify("Config", "Select a saved config first", 3, "warning")
			end
		else
			W:Notify("Config", "Auto load off", 3, "warning")
		end
	end,
})
UI.Config:Init()

-- Buy task (buys on restock: stock 0→positive; accessories once per session via Ren2 shop).
-- Returns true if anything was bought. Leaves the character at the store to idle.
-- Color variants (White/Pink/Red) removed — they all require PC variant pass (gamepass).
-- G-Force, Overdrive, AvianoChair, AvianoDesk, Snowdrift, Vortessa bought as base items (free color).
-- Initial-B and Initial-P are standalone stock IDs — no variant logic needed.
local lastG, lastP = {}, {}
local function doBuy()
	local StockService = require(RS.Shared.Scripts.Packages.StockService)
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");if not h then return false end
	local gS=StockService:GetAll("Grocery")or{};local pS=StockService:GetAll("PcParts")or{}
	local bG,bP={},{}
	if BuyG and type(gS)=="table" then for i,q in pairs(gS)do if type(q)=="number"and q>0 and GroceryItems[i]and(lastG[i]or 0)==0 then table.insert(bG,{i,q})end;lastG[i]=q end end
	if BuyP and type(pS)=="table" then for i,q in pairs(pS)do if type(q)=="number"and q>0 and PCItems[i]and(lastP[i]or 0)==0 then table.insert(bP,{i,1})end;lastP[i]=q end end
	local bA={}
	if BuyA then for n in pairs(AccItems)do if not boughtAcc[n] then table.insert(bA,n) end end end
	if #bG+#bP+#bA==0 then return false end
	-- Parts first (priority 1), Grocery second (priority 2)
	-- Fix: delay 0.1→0.5s between each purchase to avoid "Too fast" server rejection
	if #bP>0 then h.CFrame=ShopPC;task.wait(0.6);for _,v in ipairs(bP)do SPR:FireServer("PcParts",v[1],v[2]);task.wait(0.5)end;task.wait(0.5)end
	if #bG>0 then h.CFrame=ShopGroc;task.wait(0.8);for _,v in ipairs(bG)do SPR:FireServer("Grocery",v[1],v[2]);task.wait(0.5)end;task.wait(3)end
	if #bA>0 then
		local r2=workspace:FindFirstChild("Ren2")
		if r2 then
			h.CFrame=r2:GetPivot()*CFrame.new(0,2,5);task.wait(0.8)
			local asp=nil;for _,pp in ipairs(r2:GetDescendants())do if pp:IsA("ProximityPrompt")and(pp.ObjectText or""):lower():match("accessor")then asp=pp;break end end
			if asp and fireproximityprompt then local oL,oD=asp.RequiresLineOfSight,asp.MaxActivationDistance;asp.RequiresLineOfSight=false;asp.MaxActivationDistance=50;fireproximityprompt(asp);asp.RequiresLineOfSight=oL;asp.MaxActivationDistance=oD end
			task.wait(0.6)
			for _,n in ipairs(bA)do ASRQ:FireServer("Purchase",n);boughtAcc[n]=true;task.wait(0.7)end
			task.wait(0.5)
		end
	end
	return true
end
-- Dedicated buy loop: highest-priority task — preempts scheduler, bill, and fire.
-- Sets billBusy to pause the scheduler while buying so nothing teleports the character mid-buy.
-- Fix: removed "if billBusy then continue end" — buy no longer waits for other tasks; it preempts them.
task.spawn(function()
	while alive() do
		task.wait(0.5)
		if not (BuyG or BuyP or BuyA) then continue end
		billBusy = true
		local ok, bought = pcall(doBuy)
		if ok and bought then task.wait(3.5) end
		billBusy = false
	end
end)

-- Print task (fire Print when order waiting; refill inks/paper at Ren2 shop)
local INKS = {"Black","Blue","Pink","Yellow"}
local printState = nil -- { Paper, Inks, Order, Active, ... } fed by persistent listener
local printLastPoll = 0 -- os.clock() of last printer visit; stream only flows while standing there
PRU.OnClientEvent:Connect(function(d) if type(d)=="table" and d.Paper~=nil then printState=d end end)
PRO.OnClientEvent:Connect(function(d) if type(d)=="table" and d.Paper~=nil then printState=d end end)
local function printerObj()
	local b = ob()
	local pf = b and b:FindFirstChild("ServerTable") and b.ServerTable:FindFirstChild("PrinterFolder")
	return pf and pf:FindFirstChild("Printer")
end
local function printerPos()
	local pr = printerObj()
	if not pr then return nil end
	local att = pr:FindFirstChild("Attachment")
	if att and att:IsA("Attachment") then
		local ok, wp = pcall(function() return att.WorldPosition end)
		if ok then return wp end
	end
	-- Fix: guard ob() before calling GetDescendants (ob() can return nil)
	local base2 = ob()
	if not base2 then return nil end
	for _, v in ipairs(base2:GetDescendants()) do
		if v:IsA("ProximityPrompt") and (v.ObjectText or ""):lower():match("printer") then
			local pa = v.Parent
			if pa then
				if pa:IsA("Attachment") then
					local ok, wp = pcall(function() return pa.WorldPosition end); if ok then return wp end
				elseif pa:IsA("BasePart") then
					return pa.Position
				end
			end
		end
	end
	return nil
end
local function doPrint()
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");if not h then return end
	local pos=printerPos();if not pos then return end
	printLastPoll=os.clock()
	h.CFrame=CFrame.new(pos.X,pos.Y+3,pos.Z)
	local pr=printerObj();local pp=nil
	-- Fix: guard ob() before GetDescendants (same crash risk as printerPos)
	if pr then local baseP=ob();if baseP then for _,p in ipairs(baseP:GetDescendants()) do if p:IsA("ProximityPrompt")and(p.ObjectText or""):lower():match("printer")then pp=p;break end end end end
	if pp and fireproximityprompt then local oL,oD=pp.RequiresLineOfSight,pp.MaxActivationDistance;pp.RequiresLineOfSight=false;pp.MaxActivationDistance=50;fireproximityprompt(pp);pp.RequiresLineOfSight=oL;pp.MaxActivationDistance=oD end
	local s=nil;local conn1=PRU.OnClientEvent:Connect(function(d)if type(d)=="table"and d.Paper~=nil then s=d end end)
	local conn2=PRO.OnClientEvent:Connect(function(d)if type(d)=="table"and d.Paper~=nil then s=d end end)
	for _=1,40 do task.wait(0.2);if s then break end end
	if conn1 then pcall(function()conn1:Disconnect()end) end
	if conn2 then pcall(function()conn2:Disconnect()end) end
	if not s then return end
	if s.Order and not s.Active then
		PRQ:FireServer("Print")
	end
	local needInk=false;for _,n in ipairs(INKS)do local v=s.Inks and tonumber(s.Inks[n]) or 0;if v<20 then needInk=true end end
	local paperNeed=(tonumber(s.Paper) or 0)<20
	if needInk or paperNeed then
		local r2=workspace:FindFirstChild("Ren2")
		if r2 then
			h.CFrame=r2:GetPivot()*CFrame.new(0,2,5);task.wait(0.8)
			local asp=nil;for _,pp in ipairs(r2:GetDescendants())do if pp:IsA("ProximityPrompt")and(pp.ObjectText or""):lower():match("accessor")then asp=pp;break end end
			if asp and fireproximityprompt then local oL,oD=asp.RequiresLineOfSight,asp.MaxActivationDistance;asp.RequiresLineOfSight=false;asp.MaxActivationDistance=50;fireproximityprompt(asp);asp.RequiresLineOfSight=oL;asp.MaxActivationDistance=oD end
			task.wait(0.6)
			if needInk then for _,n in ipairs(INKS)do ASRQ:FireServer("Purchase",n.." Ink");task.wait(0.7)end;task.wait(0.5)end
			-- Fix: only buy packs needed to fill from current stock to capacity (was buying full capacity worth)
			if paperNeed then local cap=s.PaperCapacity or 80;local cur=tonumber(s.Paper) or 0;local packs=math.max(1,math.ceil((cap-cur)/20));for _=1,packs do ASRQ:FireServer("Purchase","Copy Paper");task.wait(0.7)end end
			task.wait(0.5)
			h.CFrame=CFrame.new(pos.X,pos.Y+3,pos.Z)
		end
	end
end

-- Priority scheduler: one owner loop, exclusive task execution.
-- Priority (higher wins): Appoint > Clean > Chef > Print.
-- (Fire runs on its own dedicated emergency loop that preempts everything; Buy runs on
-- its own dedicated loop so it can idle at the store. Neither lives in this scheduler.)
-- A task only runs when enabled, has pending work, and its cooldown elapsed.
-- Starvation guard: if a task hasn't run in N ticks while a higher-priority
-- one keeps claiming work, let the starved task through anyway.
local function doAppointWork()
	local sf=LP.PlayerGui:FindFirstChild("MainUi")and LP.PlayerGui.MainUi:FindFirstChild("ServerFrame")
	if not sf or sf.Visible then return false end
	return hc() and vp()>0 and custNear()
end
local function doCleanWork()
	local b=ob();if not b then return false end
	local cs=b:FindFirstChild("CleaningSystem");if not cs then return false end
	for _,r in ipairs({cs:FindFirstChild("ActiveMesses"),cs:FindFirstChild("ActiveFires"),cs:FindFirstChild("Fires")})do if r then for _,p in ipairs(r:GetDescendants())do if p:IsA("ProximityPrompt")and p.Enabled and ct(p) then return true end end end end
	return false
end
local function doChefWork()
	local mu=LP.PlayerGui:FindFirstChild("MainUi");if not mu then return false end
	local tl=mu:FindFirstChild("Tray")and mu.Tray:FindFirstChild("ScrollingFrame");if tl then for _,v in ipairs(tl:GetChildren())do if v:IsA("Frame")and v:GetAttribute("TrayRuntimeCard")then return true end end end
	local ck=mu:FindFirstChild("Cooking")and mu.Cooking:FindFirstChild("OrdersFrame");if ck then for _,v in ipairs(ck:GetChildren())do if v:IsA("Frame")and v:GetAttribute("CookingRuntimeCard")then return true end end end
	local sk=mu:FindFirstChild("SnacksDeliver")and mu.SnacksDeliver:FindFirstChild("OrdersFrame");if sk then for _,v in ipairs(sk:GetChildren())do if v:IsA("Frame")and v:GetAttribute("SnackRuntimeCard")then return true end end end
	local pp=mu:FindFirstChild("Cooking")and mu.Cooking:FindFirstChild("PreparingFrame");if pp then for _,v in ipairs(pp:GetChildren())do if v:IsA("Frame")and v:GetAttribute("CookingRuntimeCard")then return true end end end
	return false
end
local function doFireWork()
	local b=ob();if not b then return false end
	local pcs=b:FindFirstChild("PCS");if not pcs then return false end
	for _,pc in ipairs(pcs:GetChildren())do if pc:IsA("Model")and pc:GetAttribute("FireActive")==true then return true end end
	return false
end
-- Dedicated fire loop: emergency, so it ignores billBusy and preempts everything
-- (including an in-progress buy/bill) by taking the lock itself while extinguishing.
task.spawn(function()
	while alive() do
		task.wait(0.4)
		if not AE then continue end
		if not doFireWork() then continue end
		billBusy = true
		pcall(doFire)
		billBusy = false
	end
end)
local function doPrintWork()
	local s=printState
	if not s then return true end
	if os.clock()-printLastPoll>15 then return true end
	if s.Order and not s.Active then return true end
	for _,n in ipairs(INKS)do local v=s.Inks and tonumber(s.Inks[n]) or 0;if v<20 then return true end end
	if (tonumber(s.Paper) or 0)<20 then return true end
	return false
end
local function doPayBills()
	local c=LP.Character;local h=c and c:FindFirstChild("HumanoidRootPart");if not h then return end
	EBR:FireServer("Snapshot")
	local s=nil
	local conn=EBS.OnClientEvent:Connect(function(d) s=d end)
	local t0=os.clock();while not s and os.clock()-t0<3 do task.wait(0.2) end
	if conn then pcall(function()conn:Disconnect()end) end
	if s then billState=s end
	if not s or not s.PayableBill or s.PayableBill<=0 then return end
	local b=ob();if not b then return end
	local ep=nil;for _,p in ipairs(b:GetDescendants())do if p:IsA("ProximityPrompt")and p:GetAttribute("ElectricityBillingOwnerUserId")==LP.UserId then ep=p;break end end
	if not ep then return end
	h.CFrame=CFrame.new(ep.Parent.Position.X,ep.Parent.Position.Y+3,ep.Parent.Position.Z);task.wait(0.6)
	if fireproximityprompt then local oL,oD=ep.RequiresLineOfSight,ep.MaxActivationDistance;ep.RequiresLineOfSight=false;ep.MaxActivationDistance=50;fireproximityprompt(ep);ep.RequiresLineOfSight=oL;ep.MaxActivationDistance=oD end
	task.wait(0.4)
	EBR:FireServer("Pay")
	task.wait(0.5)
end
-- Dedicated bill loop: every 30s, pause the scheduler, pay the bill, resume.
task.spawn(function()
	while alive() do
		task.wait(0.5)
		if not AB or os.clock() < billNext then continue end
		billNext = os.clock() + 30
		billBusy = true
		pcall(doPayBills)
		billBusy = false
	end
end)
-- Fix: priority order per user request — Appoint > Print > Clean > Chef
local SCHED = {
	{ name="Appoint", enabled=function() return AA end, hasWork=doAppointWork, run=doAppoint, cooldown=1.5 },
	{ name="Print",   enabled=function() return AP end, hasWork=doPrintWork,   run=doPrint,   cooldown=6.0 },
	{ name="Clean",   enabled=function() return AC end, hasWork=doCleanWork,   run=doClean,   cooldown=1.5 },
	{ name="Chef",    enabled=function() return AF end, hasWork=doChefWork,    run=doChef,    cooldown=1.5 },
}
	for _,t in ipairs(SCHED) do t.last=0;t.starved=0 end
	local function ready(t) local ok1,e=pcall(t.enabled);local ok2,w=pcall(t.hasWork);return ok1 and ok2 and e and w end
	task.spawn(function()
		while alive() do task.wait(0.4)
			if billBusy then continue end
			local okRun=pcall(function()
			local now=os.clock();local chosen=nil
			-- Emergency first: a burning PC preempts everything, cooldown ignored,
			-- until no fire is left. Nothing else runs while fire is up.
			for _,t in ipairs(SCHED) do
				if t.emergency and ready(t) then chosen=t;break end
			end
			if not chosen then
				for _,t in ipairs(SCHED) do
					if ready(t) then
						if now-t.last>=t.cooldown or t.starved>=8 then chosen=t;break end
					end
				end
			end
			if not chosen then
				for _,t in ipairs(SCHED) do if ready(t) then t.starved=t.starved+1 end end
				return
			end
			chosen.last=now;chosen.starved=0
			for _,t in ipairs(SCHED) do if t~=chosen and ready(t) then t.starved=t.starved+1 end end
			pcall(chosen.run)
			end)
			if not okRun then
				for _,t in ipairs(SCHED) do t.starved=0 end
			end
		end
	end)
