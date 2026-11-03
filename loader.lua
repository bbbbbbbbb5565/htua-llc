--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              CLL AUTHENTICATION GATE                          ║
    ║         Integrated with Render.com API + Profile UI           ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ============== CONFIGURATION ==============
local AUTH_URL = "https://cll-auth.onrender.com"
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/bbbbbbbbb5565/htua-llc/refs/heads/main/main.lua"
local KEY_FILE = "CLL_Key.txt"
-- ===========================================

-- Global variables
_G.CLL_Auth = nil
_G.CLL_Whitelist = {}

-- Utility functions
local function getHWID()
    return (gethwid and gethwid()) or (get_hwid and get_hwid()) or "unknown"
end

local function getUserId()
    return tostring(LocalPlayer.UserId)
end

local function saveKey(key)
    if writefile then
        pcall(function()
            writefile(KEY_FILE, key)
        end)
    end
end

local function loadKey()
    if readfile and isfile and isfile(KEY_FILE) then
        local success, key = pcall(function()
            return readfile(KEY_FILE)
        end)
        if success and key and key ~= "" then
            return key
        end
    end
    return nil
end

-- Check key with API
local function checkKey(key)
    local body = HttpService:JSONEncode({
        key = key,
        userid = getUserId(),
        hwid = getHWID()
    })
    
    local success, res = pcall(function()
        return request({
            Url = AUTH_URL .. "/check",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    
    if not success or not res or not res.Body then
        return {status = "offline"}
    end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    
    if not ok then
        return {status = "offline"}
    end
    
    return data
end

-- Apply auth data
local function applyAuth(data)
    _G.CLL_Auth = {
        status = data.status,
        role = data.role,
        type = data.type,
        expires_at = data.expires_at
    }
    
    _G.CLL_Whitelist = {}
    if data.whitelist then
        for _, id in ipairs(data.whitelist) do
            _G.CLL_Whitelist[tonumber(id)] = true
        end
    end
end

-- Ping bot status
local function pingBot()
    local res = request({
        Url = AUTH_URL .. "/",
        Method = "GET"
    })
    return res and res.StatusCode == 200
end

-- Check if player is whitelisted
local function IsWhitelisted(player)
    return player and _G.CLL_Whitelist and _G.CLL_Whitelist[player.UserId] == true
end

-- ============== UI CREATION ==============

local function CreateAuthUI(onSuccess)
    -- Remove existing UI
    if game:GetService("CoreGui"):FindFirstChild("CLL_AuthUI") then
        game:GetService("CoreGui"):FindFirstChild("CLL_AuthUI"):Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CLL_AuthUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game:GetService("CoreGui")
    
    -- Blur background
    local blur = Instance.new("BlurEffect")
    blur.Size = 15
    blur.Parent = game:GetService("Lighting")
    
    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.fromOffset(440, 300)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 18)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(45, 45, 50)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    -- Gradient accent bar
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(1, 0, 0, 5)
    accentBar.Position = UDim2.fromOffset(0, 0)
    accentBar.BackgroundColor3 = Color3.fromRGB(92, 126, 255)
    accentBar.BorderSizePixel = 0
    accentBar.Parent = mainFrame
    
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 18)
    accentCorner.Parent = accentBar
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 126, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 100, 255))
    }
    gradient.Rotation = 90
    gradient.Parent = accentBar
    
    -- Logo/Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 50)
    title.Position = UDim2.fromOffset(20, 30)
    title.BackgroundTransparency = 1
    title.Text = "CLL Authentication"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 26
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame
    
    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 20)
    subtitle.Position = UDim2.fromOffset(20, 70)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Enter your license key to continue"
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 14
    subtitle.TextColor3 = Color3.fromRGB(140, 140, 150)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = mainFrame
    
    -- Key input frame
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, -40, 0, 52)
    inputFrame.Position = UDim2.fromOffset(20, 115)
    inputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    inputFrame.BorderSizePixel = 0
    inputFrame.Parent = mainFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 12)
    inputCorner.Parent = inputFrame
    
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(50, 50, 55)
    inputStroke.Thickness = 2
    inputStroke.Parent = inputFrame
    
    -- Key icon
    local keyIcon = Instance.new("TextLabel")
    keyIcon.Size = UDim2.fromOffset(40, 52)
    keyIcon.Position = UDim2.fromOffset(5, 0)
    keyIcon.BackgroundTransparency = 1
    keyIcon.Text = "🔑"
    keyIcon.Font = Enum.Font.Gotham
    keyIcon.TextSize = 20
    keyIcon.Parent = inputFrame
    
    -- Key input box
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -50, 1, 0)
    keyInput.Position = UDim2.fromOffset(45, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.Text = ""
    keyInput.PlaceholderText = "XXXX-XXXX-XXXX"
    keyInput.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
    keyInput.Font = Enum.Font.GothamMedium
    keyInput.TextSize = 17
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.ClearTextOnFocus = false
    keyInput.Parent = inputFrame
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 22)
    statusLabel.Position = UDim2.fromOffset(20, 177)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Visible = false
    statusLabel.Parent = mainFrame
    
    -- Verify button
    local verifyButton = Instance.new("TextButton")
    verifyButton.Size = UDim2.new(1, -40, 0, 52)
    verifyButton.Position = UDim2.fromOffset(20, 210)
    verifyButton.BackgroundColor3 = Color3.fromRGB(92, 126, 255)
    verifyButton.BorderSizePixel = 0
    verifyButton.Text = "Verify Key"
    verifyButton.Font = Enum.Font.GothamBold
    verifyButton.TextSize = 17
    verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    verifyButton.AutoButtonColor = false
    verifyButton.Parent = mainFrame
    
    local verifyCorner = Instance.new("UICorner")
    verifyCorner.CornerRadius = UDim.new(0, 12)
    verifyCorner.Parent = verifyButton
    
    -- Info text
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, 0, 0, 18)
    infoText.Position = UDim2.fromOffset(0, 275)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Need a key? Contact admin in Discord"
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 12
    infoText.TextColor3 = Color3.fromRGB(100, 100, 110)
    infoText.Parent = mainFrame
    
    -- Entrance animation
    mainFrame.Size = UDim2.fromOffset(0, 0)
    mainFrame.Rotation = 8
    
    TweenService:Create(mainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(440, 300),
        Rotation = 0
    }):Play()
    
    -- Button hover
    verifyButton.MouseEnter:Connect(function()
        TweenService:Create(verifyButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(102, 136, 255)
        }):Play()
    end)
    
    verifyButton.MouseLeave:Connect(function()
        TweenService:Create(verifyButton, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(92, 126, 255)
        }):Play()
    end)
    
    -- Input focus effect
    keyInput.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(92, 126, 255),
            Thickness = 2.5
        }):Play()
    end)
    
    keyInput.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.3), {
            Color = Color3.fromRGB(50, 50, 55),
            Thickness = 2
        }):Play()
    end)
    
    -- Verify function
    local function VerifyKey()
        local key = keyInput.Text:gsub("%s+", "")
        
        if key == "" then
            statusLabel.Text = "❌ Please enter a key"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            statusLabel.Visible = true
            return
        end
        
        -- Disable inputs
        verifyButton.Text = "Verifying..."
        verifyButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        verifyButton.Active = false
        keyInput.Active = false
        
        statusLabel.Text = "🔄 Connecting to server..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        statusLabel.Visible = true
        
        -- Check key
        task.spawn(function()
            local data = checkKey(key)
            
            if data.status == "valid" then
                -- Success!
                statusLabel.Text = "✅ Key verified! Loading..."
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                
                saveKey(key)
                applyAuth(data)
                
                -- Exit animation
                TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                    Size = UDim2.fromOffset(0, 0),
                    Rotation = -8
                }):Play()
                
                TweenService:Create(overlay, TweenInfo.new(0.5), {
                    BackgroundTransparency = 1
                }):Play()
                
                wait(0.6)
                blur:Destroy()
                screenGui:Destroy()
                
                onSuccess()
            else
                -- Error
                local messages = {
                    invalid = "Invalid key",
                    banned = "Key is banned",
                    expired = "Key expired",
                    hwid_mismatch = "Key bound to another device",
                    userid_mismatch = "Key bound to another account",
                    offline = "Cannot connect to server"
                }
                
                statusLabel.Text = "❌ " .. (messages[data.status] or data.status)
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                
                -- Re-enable
                verifyButton.Text = "Verify Key"
                verifyButton.BackgroundColor3 = Color3.fromRGB(92, 126, 255)
                verifyButton.Active = true
                keyInput.Active = true
                
                -- Shake animation
                local originalPos = mainFrame.Position
                for i = 1, 3 do
                    TweenService:Create(mainFrame, TweenInfo.new(0.08), {Position = originalPos + UDim2.fromOffset(-15, 0)}):Play()
                    wait(0.08)
                    TweenService:Create(mainFrame, TweenInfo.new(0.08), {Position = originalPos + UDim2.fromOffset(15, 0)}):Play()
                    wait(0.08)
                end
                TweenService:Create(mainFrame, TweenInfo.new(0.1), {Position = originalPos}):Play()
            end
        end)
    end
    
    verifyButton.MouseButton1Click:Connect(VerifyKey)
    
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            VerifyKey()
        end
    end)
    
    -- Auto focus
    task.wait(0.7)
    keyInput:CaptureFocus()
end

-- Create profile UI (optional, показывается только если нужно)
local function CreateProfileUI()
    if not _G.CLL_Auth then return end
    
    -- TODO: Implement profile UI based on Grok's design
    -- For now, just print info
    print("[CLL] Profile loaded:")
    print("  Role:", _G.CLL_Auth.role)
    print("  Type:", _G.CLL_Auth.type)
    print("  Expires:", _G.CLL_Auth.expires_at or "Never")
    print("  Whitelist:", #_G.CLL_Whitelist or 0, "users")
end

-- Load main script
local function LoadMainScript()
    print("[CLL] Loading main script...")
    
    local success, err = pcall(function()
        loadstring(game:HttpGet(MAIN_SCRIPT_URL))()
    end)
    
    if not success then
        warn("[CLL] Failed to load main script:", err)
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "CLL Error",
            Text = "Failed to load cheat",
            Duration = 10
        })
    end
end

-- ============== MAIN EXECUTION ==============

print("[CLL] Starting authentication...")

-- Try local key first
local savedKey = loadKey()
if savedKey then
    print("[CLL] Found saved key, verifying...")
    local data = checkKey(savedKey)
    
    if data.status == "valid" then
        print("[CLL] ✅ Saved key valid!")
        applyAuth(data)
        CreateProfileUI()
        LoadMainScript()
        return
    else
        print("[CLL] ❌ Saved key invalid:", data.status)
        if delfile and isfile and isfile(KEY_FILE) then
            delfile(KEY_FILE)
        end
    end
end

-- Show UI for key input
print("[CLL] No valid key, showing auth UI...")
CreateAuthUI(function()
    CreateProfileUI()
    LoadMainScript()
end)
