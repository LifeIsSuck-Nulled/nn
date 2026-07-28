-- SPY SCRIPT NA MAY DISCORD WEBHOOK SUPPORT
local webhookUrl = "https://discord.com/api/webhooks/1530530756210724894/mYm3mE9b3u4oQmEIFOxvLURebrEq_NJBEKw4Jr3tqiIbYwQ5LFWjQS5KbErndUw39I1w"
local HttpService = game:GetService("HttpService")

-- Function para mag-send sa Webhook nang hindi nagpapa-lag sa laro
local function sendToWebhook(message)
    task.spawn(function()
        pcall(function()
            request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode({
                    content = "```\n" .. message .. "\n```"
                })
            })
        end)
    end)
end

-- 1. Namecall Hook (Nasa Console lang para hindi ma-rate limit ang Discord)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FindFirstChild" or method == "WaitForChild" then
        if type(args[1]) == "string" and (args[1]:lower():match("mess") or args[1]:lower():match("trash") or args[1]:lower():match("spill") or args[1]:lower():match("glass")) then
            print("👀 NAGHAHANAP: " .. tostring(args[1]) .. " SA: " .. self:GetFullName())
        end
    end

    return oldNamecall(self, ...)
end)

-- 2. ProximityPrompt Hook (Ito ang ipapadala sa Discord Webhook)
local oldFire = fireproximityprompt
if oldFire then
    getgenv().fireproximityprompt = function(prompt, amount, skip)
        local targetPath = prompt.Parent and prompt.Parent:GetFullName() or "Unknown"
        local msg = "🔥 NAG-INTERACT (CLEAN) SILA SA:\n" .. targetPath
        
        print(msg) -- I-print sa console
        sendToWebhook(msg) -- I-send sa Discord Webhook
        
        return oldFire(prompt, amount, skip)
    end
end

-- Test message para ma-verify kung working ang webhook
sendToWebhook("✅ Spy Script Activated! Naka-abang na sa mga lilinisin ng Obfuscated Script.")
