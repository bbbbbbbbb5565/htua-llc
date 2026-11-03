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
local AUTH_URLS = {
    "https://cll-auth.onrender.com", 
}
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/bbbbbbbbb5565/htua-llc/refs/heads/main/main.lua"
local KEY_FILE = "CLL_Key.txt"
local CURRENT_AUTH_URL = 1
-- ===========================================

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

_G.CLL_Auth = nil
_G.CLL_Whitelist = {}

local function getUserId()
    return tostring(LocalPlayer.UserId)
end

local function saveKey(key)
    if writefile then
        pcall(function() writefile(KEY_FILE, key) end)
    end
end

local function loadKey()
    if readfile and isfile and isfile(KEY_FILE) then
        local success, key = pcall(function() return readfile(KEY_FILE) end)
        if success and key and key ~= "" then return key end
    end
    return nil
end

local function checkKey(key, retry, urlIndex)
    retry = retry or 0
    urlIndex = urlIndex or 1
    local AUTH_URL = AUTH_URLS[urlIndex]
    
    -- Отправляем ТОЛЬКО ключ и userid
    local body = HttpService:JSONEncode({
        key = key,
        userid = tostring(getUserId())
    })
    
    print("[CLL AUTH] Checking key:", key)
    
    local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
    if not httpRequest then return {status = "offline", message = "Executor not supported"} end
    
    local success, res = pcall(function()
        return httpRequest({
            Url = AUTH_URL .. "/check",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/WinInet"
            },
            Body = body
        })
    end)
    
    if not success then
        warn("[CLL AUTH] Request failed:", res)
        if retry < 2 then
            task.wait(2)
            return checkKey(key, retry + 1, urlIndex)
        end
        return {status = "offline", message = "Cannot connect"}
    end
    
    if not res or not res.Body then return {status = "offline", message = "Empty response"} end
    print("[CLL AUTH] Response:", res.Body)
    
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok then return {status = "offline", message = "JSON error"} end
    
    return data
end

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

local function CreateAuthUI(onSuccess)
    if game:GetService("CoreGui"):FindFirstChild("CLL_AuthUI") then
        game:GetService("CoreGui"):FindFirstChild("CLL_AuthUI"):Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CLL_AuthUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = game:GetService("CoreGui")
    
    local blur = Instance.new("BlurEffect")
    blur.Size = 18
    blur.Parent = game:GetService("Lighting")
    
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 1
    overlay.Parent = screenGui
    
    local function new(class, props, children)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        for _, c in ipairs(children or {}) do c.Parent = o end
        return o
    end
    local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
    local function stroke(c, t) return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
    
    local mainFrame = new("CanvasGroup", {
        Size = UDim2.fromOffset(460, 380),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        ZIndex = 2,
        GroupTransparency = 1,
        Parent = screenGui
    }, { corner(20), stroke() })
    
    local uiScale = new("UIScale", { Scale = 0.85, Parent = mainFrame })
    
    -- ИСПРАВЛЕННЫЙ КРЕСТИК (Буква X вместо эмодзи)
    local closeBtn = new("TextButton", {
        Text = "X",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
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
    
    local inputFrame = new("Frame", {
        Size = UDim2.fromOffset(400, 50),
        Position = UDim2.fromOffset(30, 155),
        BackgroundColor3 = Theme.Row,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = mainFrame
    }, { corner(10), stroke() })
    local inputStroke = inputFrame:FindFirstChildOfClass("UIStroke")
    
    -- ИСПРАВЛЕННАЯ ИКОНКА КЛЮЧА (Меньше кольцо, тоньше обводка)
    local keyIconHolder = new("Frame", {
        Size = UDim2.fromOffset(50, 50),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Parent = inputFrame
    })
    new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(20, 19), BackgroundTransparency = 1, ZIndex = 3, Parent = keyIconHolder }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Theme.Dim, 1.5) })
    new("Frame", { Size = UDim2.fromOffset(10, 2), Position = UDim2.fromOffset(30, 24), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    new("Frame", { Size = UDim2.fromOffset(2, 4), Position = UDim2.fromOffset(36, 24), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    new("Frame", { Size = UDim2.fromOffset(2, 3), Position = UDim2.fromOffset(33, 24), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = keyIconHolder })
    
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
    
    TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    TweenService:Create(mainFrame, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
    
    verifyButton.MouseEnter:Connect(function() TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(112, 146, 255) }):Play() end)
    verifyButton.MouseLeave:Connect(function() TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Theme.Accent }):Play() end)
    
    keyInput.Focused:Connect(function() if inputStroke then TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Theme.Accent, Thickness = 2 }):Play() end end)
    keyInput.FocusLost:Connect(function() if inputStroke then TweenService:Create(inputStroke, TweenInfo.new(0.2), { Color = Theme.Stroke, Thickness = 1 }):Play() end end)
    
    local function VerifyKey()
        local key = keyInput.Text:gsub("%s+", "")
        if key == "" then
            statusLabel.Text = "Please enter a key"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            statusLabel.Visible = true
            return
        end
        
        verifyButton.Text = "Verifying..."
        verifyButton.BackgroundColor3 = Theme.Off
        verifyButton.Active = false
        keyInput.Active = false
        
        statusLabel.Text = "Connecting to server..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        statusLabel.Visible = true
        
        task.spawn(function()
            local data = checkKey(key)
            
            if data.status == "valid" then
                statusLabel.Text = "Key verified! Loading..."
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
                    invalid = "Invalid key (data error)",
                    banned = "Key is banned",
                    expired = "Key expired",
                    userid_mismatch = "Key bound to another account",
                    offline = data.message or "Cannot connect to server"
                }
                
                local errorMsg = messages[data.status] or data.status or "Unknown error"
                statusLabel.Text = errorMsg
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                
                verifyButton.Text = "Verify Key"
                verifyButton.BackgroundColor3 = Theme.Accent
                verifyButton.Active = true
                keyInput.Active = true
            end
        end)
    end
    
    verifyButton.MouseButton1Click:Connect(VerifyKey)
    keyInput.FocusLost:Connect(function(enterPressed) if enterPressed and verifyButton.Active then VerifyKey() end end)
    task.wait(0.5)
    keyInput:CaptureFocus()
end

local function LoadMainScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(MAIN_SCRIPT_URL))()
    end)
    if not success then warn("[CLL] Failed to load main script:", err) end
end

local function ShowLoadingSplash()
    local splashGui = Instance.new("ScreenGui")
    splashGui.Name = "CLL_LoadingSplash"
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
    
    return splashGui
end

local splash = ShowLoadingSplash()
wait(0.5)

local savedKey = loadKey()
if savedKey then
    local data = checkKey(savedKey)
    if data.status == "valid" then
        applyAuth(data)
        if splash then splash:Destroy() end
        LoadMainScript()
        return
    else
        if delfile and isfile and isfile(KEY_FILE) then delfile(KEY_FILE) end
    end
end

if splash then splash:Destroy() end
CreateAuthUI(function() LoadMainScript() end)
