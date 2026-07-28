local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NgrokConnectorUI"
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
MainFrame.Size = UDim2.new(0, 300, 0, 150)

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "MCP Ngrok Bridge (Fixed)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20

local UrlInput = Instance.new("TextBox")
UrlInput.Parent = MainFrame
UrlInput.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
UrlInput.BorderSizePixel = 0
UrlInput.Position = UDim2.new(0.1, 0, 0.3, 0)
UrlInput.Size = UDim2.new(0.8, 0, 0, 40)
UrlInput.Font = Enum.Font.SourceSans
UrlInput.PlaceholderText = "Paste Ngrok URL here"
UrlInput.Text = ""
UrlInput.TextColor3 = Color3.fromRGB(255, 255, 255)
UrlInput.TextSize = 14
UrlInput.ClearTextOnFocus = false

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

-- Piliin ang tamang HTTP Request function ng Delta
local httpRequest = (syn and syn.request) or (http and http.request) or request or http_request

ConnectBtn.MouseButton1Click:Connect(function()
    local rawUrl = UrlInput.Text
    
    -- Linisin ang URL para tanggalin ang https://, http://, o trailing slashes
    local cleanedUrl = rawUrl:gsub("https://", ""):gsub("http://", ""):gsub("/", "")
    
    if cleanedUrl == "" then
        ConnectBtn.Text = "Enter URL first!"
        ConnectBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        task.wait(1)
        ConnectBtn.Text = "CONNECT"
        ConnectBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        return
    end
    
    ConnectBtn.Text = "Connecting..."
    ConnectBtn.BackgroundColor3 = Color3.fromRGB(170, 170, 0)
    
    getgenv().BridgeURL = cleanedUrl
    getgenv().DisableWebSocket = true 
    
    ScreenGui:Destroy()

    -- Loop na may kasamang Ngrok warning bypass header
    task.spawn(function()
        while not getgenv().MCP_Loaded do
            pcall(function()
                if httpRequest then
                    local response = httpRequest({
                        Url = "https://" .. getgenv().BridgeURL .. "/script.luau",
                        Method = "GET",
                        Headers = {
                            ["ngrok-skip-browser-warning"] = "true",
                            ["User-Agent"] = "Mozilla/5.0"
                        }
                    })
                    if response and response.Body then
                        loadstring(response.Body)()
                    end
                else
                    loadstring(game:HttpGet("https://" .. getgenv().BridgeURL .. "/script.luau"))()
                end
            end)
            task.wait(0.15)
        end
    end)
end)
