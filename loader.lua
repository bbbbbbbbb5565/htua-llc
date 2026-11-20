--[[
    CLL AUTHENTICATION GATE
    Render API + Profile handoff
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local AUTH_URLS = {
	"https://cll-auth.onrender.com",
}
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/bbbbbbbbb5565/htua-llc/refs/heads/main/main.lua"
local KEY_FILE = "CLL_Key.txt"

local Theme = {
	Bg = Color3.fromRGB(13, 13, 14),
	Panel = Color3.fromRGB(17, 17, 18),
	Row = Color3.fromRGB(25, 25, 27),
	Stroke = Color3.fromRGB(42, 42, 46),
	Text = Color3.fromRGB(240, 240, 242),
	Dim = Color3.fromRGB(125, 125, 132),
	Off = Color3.fromRGB(32, 32, 35),
	Accent = Color3.fromRGB(92, 126, 255),
}

_G.CLL_Auth = nil
_G.CLL_Whitelist = {}
_G.CLL_SESSION = nil

local function getHttpRequest()
	return request or http_request or (syn and syn.request) or (http and http.request)
end

local function getExecutor()
	local ok, name = pcall(function()
		return identifyexecutor and identifyexecutor()
	end)
	if ok and name then
		return tostring(name)
	end
	return "Unknown"
end

local function getHwid()
	local candidates = {}
	pcall(function()
		if gethwid then
			table.insert(candidates, tostring(gethwid()))
		end
	end)
	pcall(function()
		if gethwidid then
			table.insert(candidates, tostring(gethwidid()))
		end
	end)
	pcall(function()
		table.insert(candidates, game:GetService("RbxAnalyticsService"):GetClientId())
	end)
	pcall(function()
		table.insert(candidates, tostring(game.JobId) .. "-" .. tostring(LocalPlayer.UserId))
	end)

	for _, id in ipairs(candidates) do
		if type(id) == "string" and #id >= 4 then
			id = id:gsub("%s+", "")
			if #id > 128 then
				id = id:sub(1, 128)
			end
			return id
		end
	end
	return ("fallback-%s"):format(tostring(LocalPlayer.UserId))
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
		local ok, key = pcall(function()
			return readfile(KEY_FILE)
		end)
		if ok and type(key) == "string" then
			key = key:gsub("%s+", "")
			if key ~= "" then
				return key
			end
		end
	end
	return nil
end

local function clearSavedKey()
	if delfile and isfile and isfile(KEY_FILE) then
		pcall(function()
			delfile(KEY_FILE)
		end)
	end
end

local function checkKey(key, retry, urlIndex)
	retry = retry or 0
	urlIndex = urlIndex or 1
	local AUTH_URL = AUTH_URLS[urlIndex]
	if not AUTH_URL then
		return { status = "offline", message = "No auth URL" }
	end

	local httpRequest = getHttpRequest()
	if not httpRequest then
		return { status = "offline", message = "Executor HTTP missing" }
	end

	local hwid = getHwid()
	local body = HttpService:JSONEncode({
		key = tostring(key or ""),
		userid = tonumber(LocalPlayer.UserId) or LocalPlayer.UserId,
		hwid = hwid,
		username = LocalPlayer.Name,
		display_name = LocalPlayer.DisplayName,
		executor = getExecutor(),
	})

	print("[CLL AUTH] POST", AUTH_URL .. "/check", "hwid=", hwid:sub(1, 12) .. "...")

	local ok, res = pcall(function()
		return httpRequest({
			Url = AUTH_URL .. "/check",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Accept"] = "application/json",
				["User-Agent"] = "Roblox/WinInet",
				["Accept-Encoding"] = "identity",
			},
			Body = body,
		})
	end)

	if not ok then
		warn("[CLL AUTH] request error:", res)
		if retry < 2 then
			task.wait(1.5)
			return checkKey(key, retry + 1, urlIndex)
		end
		return { status = "offline", message = "Cannot connect" }
	end

	local statusCode = res and (res.StatusCode or res.Status or res.status_code)
	local rawBody = res and (res.Body or res.body or "")
	if type(rawBody) ~= "string" then
		rawBody = tostring(rawBody or "")
	end

	print("[CLL AUTH] StatusCode=", statusCode, "BodyLen=", #rawBody)

	if not rawBody or rawBody == "" then
		warn("[CLL AUTH] Empty response. StatusCode=", statusCode)
		if retry < 2 then
			task.wait(2)
			return checkKey(key, retry + 1, urlIndex)
		end
		return { status = "offline", message = "Empty response (code " .. tostring(statusCode or "?") .. ")" }
	end

	local decodeOk, data = pcall(function()
		return HttpService:JSONDecode(rawBody)
	end)
	if not decodeOk or type(data) ~= "table" then
		warn("[CLL AUTH] Bad JSON:", rawBody:sub(1, 200))
		return { status = "offline", message = "JSON error" }
	end

	return data
end

local function applyAuth(data)
	local auth = {
		status = data.status,
		role = data.role,
		type = data.type,
		expires_at = data.expires_at,
		whitelist = data.whitelist == true,
	}
	local whitelist = {}
	if data.whitelist == true then
		whitelist[LocalPlayer.UserId] = true
	elseif type(data.whitelist) == "table" then
		for _, id in ipairs(data.whitelist) do
			local n = tonumber(id)
			if n then whitelist[n] = true end
		end
	end
	local session = {
		ok = true,
		ts = tick(),
		auth = auth,
	}
	local function write(tbl)
		if type(tbl) ~= "table" then return end
		tbl.CLL_Auth = auth
		tbl.CLL_SESSION = session
		tbl.CLL_Whitelist = whitelist
	end
	write(_G)
	pcall(function()
		if getgenv then write(getgenv()) end
	end)
end

local function statusMessage(data)
	if type(data) ~= "table" then
		return "Unknown error"
	end
	local reason = data.reason
	local map = {
		valid = "OK",
		invalid = (reason == "missing_data" and "Missing data (hwid/userid)")
			or (reason == "not_found" and "Key not found")
			or (reason == "bad_body" and "Bad request body")
			or (reason == "bad_hwid" and "Bad HWID")
			or (reason == "bad_userid" and "Bad UserId")
			or "Invalid key",
		banned = (reason == "ip" and "IP banned")
			or (reason == "hwid" and "HWID banned")
			or "Key banned",
		expired = "Key expired",
		hwid_mismatch = "Key bound to another device",
		userid_mismatch = "Key bound to another account",
		rate_limited = "Too many requests, wait",
		offline = data.message or "Cannot reach auth server",
		error = data.message or "Server error",
	}
	return map[data.status] or (tostring(data.status) .. (reason and (" (" .. reason .. ")") or ""))
end

local function LoadMainScript()
	local sess = _G.CLL_SESSION
	pcall(function()
		if getgenv and getgenv().CLL_SESSION then sess = getgenv().CLL_SESSION end
	end)
	if not sess or not sess.ok then
		warn("[CLL] Refusing main load: no session")
		return
	end
	local ok, err = pcall(function()
		local src = game:HttpGet(MAIN_SCRIPT_URL)
		assert(type(src) == "string" and #src > 50, "empty main")

		local function stamp(tbl)
			if type(tbl) ~= "table" then return end
			tbl.CLL_LOADED_BY_LOADER = true
			tbl.CLL_LOADED_FROM_LOADER = true
			tbl.CLL_Auth = _G.CLL_Auth or (getgenv and getgenv().CLL_Auth)
			tbl.CLL_SESSION = {
				ok = true,
				ts = tick(),
				auth = tbl.CLL_Auth,
			}
		end
		stamp(_G)
		pcall(function()
			if getgenv then stamp(getgenv()) end
		end)

		print("[CLL] flags OK, loading main (#" .. #src .. ")")
		local fn, lerr = loadstring(src)
		assert(fn, tostring(lerr))
		fn()
	end)
	if not ok then
		warn("[CLL] Failed to load main:", err)
	end
end

local function ShowLoadingSplash()
	local splashGui = Instance.new("ScreenGui")
	splashGui.Name = "CLL_LoadingSplash"
	splashGui.ResetOnSpawn = false
	splashGui.IgnoreGuiInset = true
	splashGui.Parent = CoreGui

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

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromOffset(300, 24)
	sub.Position = UDim2.fromScale(0.5, 0.52)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.BackgroundTransparency = 1
	sub.Text = "Loading..."
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 14
	sub.TextColor3 = Theme.Dim
	sub.Parent = bg

	return splashGui
end

local function CreateAuthUI(onSuccess)
	if CoreGui:FindFirstChild("CLL_AuthUI") then
		CoreGui.CLL_AuthUI:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CLL_AuthUI"
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = CoreGui

	local blur = Instance.new("BlurEffect")
	blur.Size = 18
	blur.Parent = Lighting

	local function new(class, props, children)
		local o = Instance.new(class)
		for k, v in pairs(props or {}) do
			o[k] = v
		end
		for _, c in ipairs(children or {}) do
			c.Parent = o
		end
		return o
	end
	local function corner(r)
		return new("UICorner", { CornerRadius = UDim.new(0, r) })
	end
	local function stroke(c, t)
		return new("UIStroke", {
			Color = c or Theme.Stroke,
			Thickness = t or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = screenGui,
	})

	local mainFrame = new("CanvasGroup", {
		Size = UDim2.fromOffset(460, 380),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
		ZIndex = 2,
		GroupTransparency = 1,
		Parent = screenGui,
	}, { corner(20), stroke() })

	local uiScale = new("UIScale", { Scale = 0.85, Parent = mainFrame })

	local closeBtn = new("TextButton", {
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Theme.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -40, 0, 10),
		ZIndex = 3,
		Parent = mainFrame,
	})
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255, 100, 100) }):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = Theme.Dim }):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		TweenService:Create(mainFrame, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
		task.wait(0.25)
		screenGui:Destroy()
		blur:Destroy()
	end)

	new("TextLabel", {
		Text = "CLL",
		Font = Enum.Font.Michroma,
		TextSize = 48,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 30),
		ZIndex = 3,
		Parent = mainFrame,
	})

	new("TextLabel", {
		Text = "Authentication",
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Theme.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 85),
		ZIndex = 3,
		Parent = mainFrame,
	})

	new("TextLabel", {
		Text = "License Key",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Theme.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(400, 20),
		Position = UDim2.fromOffset(30, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = mainFrame,
	})

	local inputFrame = new("Frame", {
		Size = UDim2.fromOffset(400, 50),
		Position = UDim2.fromOffset(30, 155),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = mainFrame,
	}, { corner(10), stroke() })
	local inputStroke = inputFrame:FindFirstChildOfClass("UIStroke")

	local keyInput = new("TextBox", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
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
		Parent = inputFrame,
	})

	local statusLabel = new("TextLabel", {
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 100, 100),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(400, 40),
		Position = UDim2.fromOffset(30, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Visible = false,
		ZIndex = 3,
		Parent = mainFrame,
	})

	local verifyButton = new("TextButton", {
		Size = UDim2.fromOffset(400, 50),
		Position = UDim2.fromOffset(30, 260),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Text = "Verify Key",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = mainFrame,
	}, { corner(10) })

	new("TextLabel", {
		Text = "Need a key? Contact the script developers",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 340),
		ZIndex = 3,
		Parent = mainFrame,
	})

	TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(mainFrame, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()

	verifyButton.MouseEnter:Connect(function()
		TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(112, 146, 255) }):Play()
	end)
	verifyButton.MouseLeave:Connect(function()
		if verifyButton.Active then
			TweenService:Create(verifyButton, TweenInfo.new(0.2), { BackgroundColor3 = Theme.Accent }):Play()
		end
	end)

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

	local function setBusy(busy)
		verifyButton.Active = not busy
		keyInput.Active = not busy
		verifyButton.Text = busy and "Verifying..." or "Verify Key"
		verifyButton.BackgroundColor3 = busy and Theme.Off or Theme.Accent
	end

	local function VerifyKey()
		local key = (keyInput.Text or ""):gsub("%s+", "")
		if key == "" then
			statusLabel.Text = "Please enter a key"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			statusLabel.Visible = true
			return
		end

		setBusy(true)
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
				task.wait(0.4)
				TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
				TweenService:Create(mainFrame, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
				TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
				task.wait(0.35)
				pcall(function()
					blur:Destroy()
				end)
				screenGui:Destroy()
				onSuccess()
			else
				statusLabel.Text = statusMessage(data)
				statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
				setBusy(false)
			end
		end)
	end

	verifyButton.MouseButton1Click:Connect(VerifyKey)
	keyInput.FocusLost:Connect(function(enterPressed)
		if enterPressed and verifyButton.Active then
			VerifyKey()
		end
	end)
	task.defer(function()
		keyInput:CaptureFocus()
	end)
end

-- ================== BOOT ==================
print("[CLL] Auth gate start")
local splash = ShowLoadingSplash()
task.wait(0.35)

local saved = loadKey()
if saved then
	print("[CLL] Found saved key, verifying...")
	local data = checkKey(saved)
	if data.status == "valid" then
		print("[CLL] Saved key valid")
		applyAuth(data)
		if splash then
			splash:Destroy()
		end
		LoadMainScript()
		return
	end
	print("[CLL] Saved key rejected:", data.status, data.reason or data.message)
	clearSavedKey()
end

if splash then
	splash:Destroy()
end
CreateAuthUI(function()
	LoadMainScript()
end)
