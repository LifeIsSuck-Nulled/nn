-- 1. Gumawa ng ScreenGui sa CoreGui para hindi mawala kapag nag-respawn
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NgrokConnectorUI"
ScreenGui.Parent = game:GetService("CoreGui")

-- 2. Gumawa ng Main Background Frame
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
MainFrame.Size = UDim2.new(0, 300, 0, 150)

-- 3. Maglagay ng Title
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "MCP Ngrok Bridge"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20

-- 4. Gumawa ng TextBox para sa URL input
local UrlInput = Instance.new("TextBox")
UrlInput.Parent = MainFrame
UrlInput.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
UrlInput.BorderSizePixel = 0
UrlInput.Position = UDim2.new(0.1, 0, 0.3, 0)
UrlInput.Size = UDim2.new(0.8, 0, 0, 40)
UrlInput.Font = Enum.Font.SourceSans
UrlInput.PlaceholderText = "Paste Ngrok URL (no https://)"
UrlInput.Text = ""
UrlInput.TextColor3 = Color3.fromRGB(255, 255, 255)
UrlInput.TextSize = 16
UrlInput.ClearTextOnFocus = false

-- 5. Gumawa ng Connect Button
local ConnectBtn = Instance.new("TextButton")
ConnectBtn.Parent = MainFrame
ConnectBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
ConnectBtn.BorderSizePixel = 0
ConnectBtn.Position = UDim2.new(0.25, 0, 0.65, 0)
ConnectBtn.Size = UDim2.new(0.5, 0, 0, 35)
ConnectBtn.Font = Enum.Font.SourceSansBold
ConnectBtn.Text = "CONNECT"
ConnectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ConnectBtn.TextSize = 18

-- 6. Script kung ano ang mangyayari pag na-click ang button
ConnectBtn.MouseButton1Click:Connect(function()
    local inputUrl = UrlInput.Text
    
    -- Check kung walang nilagay na text
    if inputUrl == "" then
        ConnectBtn.Text = "Enter URL first!"
        ConnectBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        task.wait(1)
        ConnectBtn.Text = "CONNECT"
        ConnectBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        return
    end
    
    -- Update UI para alam mong nagko-connect na
    ConnectBtn.Text = "Connecting..."
    ConnectBtn.BackgroundColor3 = Color3.fromRGB(170, 170, 0)
    
    -- I-apply yung user-provided bridge URL at settings
    getgenv().BridgeURL = inputUrl
    getgenv().DisableWebSocket = true 
    
    -- Alisin yung UI sa screen dahil kumokonekta na
    ScreenGui:Destroy()

    -- Patakbuhin yung original na loop para makipag-usap sa PC mo
    while not getgenv().MCP_Loaded do
        pcall(function()
            loadstring(game:HttpGet("http://" .. getgenv().BridgeURL .. "/script.luau"))()
        end)
        task.wait(0.15)
    end
end)
