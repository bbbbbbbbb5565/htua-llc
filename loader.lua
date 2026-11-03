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

-- Theme matching CLL menu
local Theme = {
	Bg = Color3.fromRGB(13, 13, 14),
	Panel = Color3.fromRGB(17, 17, 18),
	Row = Color3.fromRGB(25, 25, 27),
	Stroke = Color3.fromRGB(42, 42, 46),
	Text = Color3.fromRGB(240, 240, 242),
	Dim = Color3.fromRGB(125, 125, 132),
	Off = Color3.fromRGB(32, 32, 35),
	OnTrack = Color3.fromRGB(95, 95, 105),
	Knob = Color3.fromRGB(245, 245, 248),
	TabOn = Color3.fromRGB(46, 46, 52),
	Accent = Color3.fromRGB(92, 126, 255),
}

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
    
    print("[CLL AUTH] Checking key:", key)
    print("[CLL AUTH] UserID:", getUserId())
    print("[CLL AUTH] HWID:", getHWID())
    print("[CLL AUTH] API URL:", AUTH_URL .. "/check")
    
    local success, res = pcall(function()
        return request({
            Url = AUTH_URL .. "/check",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    
    if not success then
        warn("[CLL AUTH] Request failed:", res)
        return {status = "offline"}
    end
    
    if not res or not res.Body then
        warn("[CLL AUTH] No response body")
        return {status = "offline"}
    end
    
    print("[CLL AUTH] Response:", res.Body)
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    
    if not ok then
        warn("[CLL AUTH] Failed to parse JSON:", data)
        return {status = "offline"}
    end
    
    print("[CLL AUTH] Parsed data:", HttpService:JSONEncode(data))
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
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game:GetService("CoreGui")
    
    -- Blur background
    local blur = Instance.new("BlurEffect")
    blur.Size = 18
    blur.Parent = game:GetService("Lighting")
    
    -- Dark overlay
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 1
    overlay.Parent = screenGui
    
    -- Helper functions
    local function new(class, props, children)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        for _, c in ipairs(children or {}) do c.Parent = o end
        return o
    end
    local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
    local function stroke(c, t) return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
    
    -- Main frame (CanvasGroup for smooth animations)
    local mainFrame = new("CanvasGroup", {
        Size = UDim2.fromOffset(460, 380),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 2,
        GroupTransparency = 1,
        Parent = screenGui
    }, { corner(20), stroke() })
    
    local uiScale = new("UIScale", { Scale = 0.85, Parent = mainFrame })
    
    -- Close Button (X)
    local closeBtn = new("TextButton", {
        Text = "✕",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -40, 0, 10),
        ZIndex = 3,
        Parent = mainFrame
    })
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(255, 100, 100)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), {TextColor3 = Theme.Dim}):Play() end)
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainFrame, TweenInfo.new(0.2), {GroupTransparency = 1}):Play()
        TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
        task.wait(0.25)
        screenGui:Destroy()
        blur:Destroy()
    end)

    -- Logo
    local logo = new("TextLabel", {
        Text = "CLL",
        Font = Enum.Font.Michroma,
        TextSize = 48,
        TextColor3 = Theme.Text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 30),
        ZIndex = 3,
        Parent = mainFrame
    })
    
    -- Subtitle
    local subtitle = new("TextLabel", {
        Text = "Authentication",
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Theme.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(0, 85),
        ZIndex = 3,
        Parent = mainFrame
    })
    
    -- Key label
    local keyLabel = new("TextLabel", {
        Text = "License Key",
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = Theme.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(400, 20),
        Position = UDim2.fromOffset(30, 130),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = mainFrame
    })
    
    -- Key input frame
    local inputFrame = new("Frame", {
        Size = UDim2.fromOffset(400, 50),
        Position = UDim2.fromOffset(30, 155),
        BackgroundColor3 = Theme.Row,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = mainFrame
    }, { corner(10), stroke() })
    local inputStroke = inputFrame:FindFirstChildOfClass("UIStroke")
    
    -- Drawn Key Icon
    local keyIconHolder = new("Frame", {
        Size = UDim2.fromOffset(50, 50),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = inputFrame
    })
    new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(18, 16), BackgroundTransparency = 1, ZIndex = 3, Parent = keyIconHolder }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Dim, 2) })
    new("Frame", { Size = UDim2.fromOffset(10, 2), Position = UDim2.fromOffset(28, 22), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    new("Frame", { Size = UDim2.fromOffset(2, 4), Position = UDim2.fromOffset(34, 22), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    new("Frame", { Size = UDim2.fromOffset(2, 3), Position = UDim2.fromOffset(31, 22), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    
    -- Key input
    local keyInput = new("TextBox", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(60, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "XXXX-XXXX-XXXX",
        PlaceholderColor3 = Theme.Dim,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 3,
        Parent = inputFrame
    })
    
    -- Status label
    local statusLabel = new("TextLabel", {
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 100, 100),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(400, 20),
        Position = UDim2.fromOffset(30, 215),
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        ZIndex = 3,
        Parent = mainFrame
    })
    
    -- Verify button
    local verifyButton = new("TextButton", {
        Size = UDim2.fromOffset(400, 50),
        Position = UDim2.fromOffset(30, 250),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Text = "Verify Key",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        ZIndex = 3,
        Parent = mainFrame
    }, { corner(10) })
    
    -- Footer text
    local footerText = new("TextLabel", {
        Text = "Need a key? Contact the script developers",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Dim,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(0, 340),
        ZIndex = 3,
        Parent = mainFrame
    })
    
    -- Entrance animation
    TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(mainFrame, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
    
    -- Button hover
    verifyButton.MouseEnter:Connect(function()
        TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(112, 146, 255) }):Play()
    end)
    verifyButton.MouseLeave:Connect(function()
        TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Theme.Accent }):Play()
    end)
    
    -- Input focus effect
    keyInput.Focused:Connect(function()
        if inputStroke then
            TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Theme.Accent, Thickness = 2 }):Play()
        end
    end)
    
    keyInput.FocusLost:Connect(function()
        if inputStroke then
            TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Theme.Stroke, Thickness = 1 }):Play()
        end
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
        
        verifyButton.Text = "Verifying..."
        verifyButton.BackgroundColor3 = Theme.Off
        verifyButton.Active = false
        keyInput.Active = false
        
        statusLabel.Text = "🔄 Connecting to server..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        statusLabel.Visible = true
        
        task.spawn(function()
            local data = checkKey(key)
            
            if data.status == "valid" then
                statusLabel.Text = "✅ Key verified! Loading..."
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                
                saveKey(key)
                applyAuth(data)
                
                wait(0.5)
                
                TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
                TweenService:Create(mainFrame, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
                TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
                
                wait(0.4)
                blur:Destroy()
                screenGui:Destroy()
                
                onSuccess()
            else
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
                
                verifyButton.Text = "Verify Key"
                verifyButton.BackgroundColor3 = Theme.Accent
                verifyButton.Active = true
                keyInput.Active = true
                
                local originalPos = UDim2.fromScale(0.5, 0.5)
                for i = 1, 3 do
                    TweenService:Create(mainFrame, TweenInfo.new(0.05), { Position = UDim2.new(0.5, 12, 0.5, 0) }):Play()
                    wait(0.05)
                    TweenService:Create(mainFrame, TweenInfo.new(0.05), { Position = UDim2.new(0.5, -12, 0.5, 0) }):Play()
                    wait(0.05)
                end
                TweenService:Create(mainFrame, TweenInfo.new(0.1), { Position = originalPos }):Play()
            end
        end)
    end
    
    verifyButton.MouseButton1Click:Connect(VerifyKey)
    
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and verifyButton.Active then
            VerifyKey()
        end
    end)
    
    task.wait(0.5)
    keyInput:CaptureFocus()
end

-- Create profile UI (optional)
local function CreateProfileUI()
    if not _G.CLL_Auth then return end
    
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

-- Show loading splash
local function ShowLoadingSplash()
    local splashGui = Instance.new("ScreenGui")
    splashGui.Name = "CLL_LoadingSplash"
    splashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    splashGui.ResetOnSpawn = false
    splashGui.IgnoreGuiInset = true
    splashGui.Parent = game:GetService("CoreGui")
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(13, 13, 14)
    bg.BorderSizePixel = 0
    bg.Parent = splashGui
    
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.fromOffset(200, 80)
    logo.Position = UDim2.fromScale(0.5, 0.45)
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.BackgroundTransparency = 1
    logo.Text = "CLL"
    logo.Font = Enum.Font.Michroma
    logo.TextSize = 48
    logo.TextColor3 = Color3.fromRGB(240, 240, 242)
    logo.Parent = bg
    
    local loadingText = Instance.new("TextLabel")
    loadingText.Size = UDim2.fromOffset(300, 30)
    loadingText.Position = UDim2.fromScale(0.5, 0.55)
    loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
    loadingText.BackgroundTransparency = 1
    loadingText.Text = "Loading..."
    loadingText.Font = Enum.Font.Gotham
    loadingText.TextSize = 16
    loadingText.TextColor3 = Color3.fromRGB(125, 125, 132)
    loadingText.Parent = bg
    
    task.spawn(function()
        local dots = {".", "..", "..."}
        local i = 1
        while splashGui.Parent do
            loadingText.Text = "Loading" .. dots[i]
            i = i % 3 + 1
            wait(0.4)
        end
    end)
    
    bg.BackgroundTransparency = 1
    logo.TextTransparency = 1
    loadingText.TextTransparency = 1
    
    TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(logo, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    TweenService:Create(loadingText, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    
    return splashGui
end

local function HideLoadingSplash(splashGui)
    if not splashGui or not splashGui.Parent then return end
    
    local bg = splashGui:FindFirstChild("Frame")
    if bg then
        TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        for _, child in ipairs(bg:GetChildren()) do
            if child:IsA("TextLabel") then
                TweenService:Create(child, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            end
        end
    end
    
    wait(0.4)
    splashGui:Destroy()
end

print("[CLL] Starting authentication...")

local splash = ShowLoadingSplash()
wait(0.5)

local savedKey = loadKey()
if savedKey then
    print("[CLL] Found saved key, verifying...")
    local data = checkKey(savedKey)
    
    if data.status == "valid" then
        print("[CLL] ✅ Saved key valid!")
        applyAuth(data)
        HideLoadingSplash(splash)
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

HideLoadingSplash(splash)

print("[CLL] No valid key, showing auth UI...")
CreateAuthUI(function()
    CreateProfileUI()
    LoadMainScript()
end)
