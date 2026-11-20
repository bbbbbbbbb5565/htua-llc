--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              CLL CHEAT - FULL INTEGRATION v9.1                ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  FIXED: Syntax error in keybinds, nil value crash             ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ==================== LOADER GATE ====================
do
	local auth = rawget(_G, "CLL_Auth")
	local session = rawget(_G, "CLL_SESSION")

	local function kill(msg)
		warn("[CLL] " .. tostring(msg))
		pcall(function()
			if getgenv then
				getgenv().CLL = nil
			end
		end)
		error(msg, 0)
	end

	-- прямой loadstring(main) / подмена URL лоадера
	if type(session) ~= "table" or session.ok ~= true then
		kill("Load via loader only (no session)")
	end

	if type(auth) ~= "table" or auth.status ~= "valid" then
		kill("Auth missing or invalid")
	end

	-- сессия не старше 2 минут (после лоадера)
	if type(session.ts) ~= "number" or (tick() - session.ts) > 120 then
		kill("Session expired — restart loader")
	end

	-- опционально: повторная метка, что зашёл только лоадер
	if rawget(_G, "CLL_LOADED_BY_LOADER") ~= true then
		-- лоадер должен ставить это ПЕРЕД loadstring(main)
		-- если не ставит — раскомментируй строку ниже после правки лоадера
		-- kill("Loader flag missing")
	end
end
-- ==================== END GATE ====================

--// ==================== UI ANIMATION PRESETS ====================
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local SPEED = 1.0
local AnimName = "Smooth"
local AnimOrder = { "Smooth", "Bounce", "Elastic", "Snappy", "Pop", "Slide", "Soft fade" }
local AnimPresets = {
	Smooth = { open = { ES.Quint, ED.Out, 0.5 }, close = { ES.Quart, ED.In, 0.32 }, scale = 0.93 },
	Bounce = { open = { ES.Back, ED.Out, 0.5 }, close = { ES.Back, ED.Out, 0.45 }, scale = 0.5 },
	Elastic = { open = { ES.Elastic, ED.Out, 0.8 }, close = { ES.Quad, ED.In, 0.25 }, scale = 0.7 },
	Snappy = { open = { ES.Exponential, ED.Out, 0.35 }, close = { ES.Exponential, ED.In, 0.22 }, scale = 0.96 },
	Pop = { open = { ES.Back, ED.Out, 0.4 }, close = { ES.Back, ED.In, 0.3 }, scale = 0.6 },
	Slide = { open = { ES.Cubic, ED.Out, 0.45 }, close = { ES.Cubic, ED.In, 0.3 }, scale = 1 },
	["Soft fade"] = { open = { ES.Sine, ED.Out, 0.35 }, close = { ES.Sine, ED.In, 0.25 }, scale = 1 },
}

--// ==================== STATE ====================
local isMultiSuk = false
local SUK_FIRERATE_RPS = 15
local SUK_FireDelay = 0.05
local SUK_EquipRequired = true
local SUK_IgnoreFriends = true
local SUK_TargetNPCs = false
local FriendsList = {}
local SelectedTargets = {}
local VRSelectedTargets = {}
local reloadInProgress = false
local PermanentReloadEnabled = false
local NoRecoilEnabled = false
local ReloadSpeed = 0.01
local AntiCCEnabled = false
local SUK_MaxPerTick = 8

-- Tracers
local TracersEnabled = false
local TracerColor = Color3.fromRGB(255, 50, 50)
local TracerDuration = 0.5

-- VR State
local VREnabled = false
local VRShakeEnabled = false
local VRAuraEnabled = false
local VRHandExtend = 0
local VRShakeIntensity = 0.5
local VRAuraSpeed = 5
local VRAuraRadius = 3
local VRAuraHeight = 0
local VRService = game:GetService("VRService")

-- Sky State
local SkyColorEnabled = false
local SkyColor = Color3.fromRGB(50, 150, 255)

-- Keybind State
local Keys = { 
	ESP = Enum.KeyCode.Unknown, Hitbox = Enum.KeyCode.Unknown, SUK = Enum.KeyCode.Unknown, 
	NoRecoil = Enum.KeyCode.Unknown, AntiCC = Enum.KeyCode.Unknown, 
	Spin = Enum.KeyCode.Unknown, Fly = Enum.KeyCode.Unknown, WalkSpeed = Enum.KeyCode.Unknown, 
	JumpPower = Enum.KeyCode.Unknown, Heal = Enum.KeyCode.Unknown, SilentAim = Enum.KeyCode.Unknown,
	ChinaHat = Enum.KeyCode.Unknown, Wings = Enum.KeyCode.Unknown, AntiLag = Enum.KeyCode.Unknown,
	Menu = Enum.KeyCode.RightShift, VRGrab = Enum.KeyCode.Unknown, TeleportHeal = Enum.KeyCode.Unknown,
	Combo = Enum.KeyCode.Unknown, ReloadSpas = Enum.KeyCode.Unknown
}
local KeybindWatermarkVisible = {}
local isBinding = false
local bindTarget = nil
local UI_Keybinds = {}
local isBinding = false
local bindTarget = nil
local UI_Keybinds = {}

local HealEnabled = false
local HealFlyHeight = 3.5
local healConnection, antiVelocityConnection
local savedCollision = {}
local isBlockActive = false
local savedHealPosition = nil

local ESP_Config = {
    Enabled = false, Box = true, Name = true, Health = true, Distance = true, MaxDist = 1000,
    ChamsColor = Color3.fromRGB(255, 92, 122), FriendColor = Color3.fromRGB(85, 255, 127),
    ChamsFillTrans = 0.5, ChamsOutlineTrans = 0
}
local ESP_Cache = {}
local ESPGui = nil
local HighlightChamsEnabled = false

local Hitbox_Config = { Enabled = false, IncludeNPCs = false, Size = 5, Material = "ForceField", Transparency = 0.5 }
local Hitbox_Cache = {}
local NPC_List = {}
local last_npc_scan = 0

local WalkSpeedEnabled, WalkSpeedValue = false, 16
local JumpPowerEnabled, JumpPowerValue = false, 50
local InfiniteJumpEnabled, InfiniteJumpConnection = false, nil
local NoClipEnabled, NoFallEnabled = false, false
local FlyEnabled, FlySpeed, flyVelocity, flyGyro = false, 50, nil, nil
local SpinEnabled, SpinSpeed, spinAngular = false, 100, nil
local AntiSlowEnabled = false
local AntiLagEnabled = false

local ChinaHatEnabled = false
local WingsEnabled = false

local TimeOverrideEnabled, TimeOverrideValue = false, 14
local CameraFOVLocked, CameraFOVValue = false, 70
local MaxZoomEnabled, MaxZoomValue = false, 128
local RemoveFogEnabled, FullbrightEnabled = false, false
local UIOpacity = 1

local WatermarkMainVisible, WatermarkBindsVisible, WatermarkWorldVisible = true, true, true

local isUnloaded = false
local Connections = {}
local SessionStartTime = os.clock()

-- Remotes
local FireRemote, ReloadRemote, BulletModel, SwingRemote, HelperRemote, FxRemote
task.spawn(function()
	pcall(function() FireRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fire", 5) end)
	pcall(function() ReloadRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Reload", 5) end)
	pcall(function() BulletModel = ReplicatedStorage:WaitForChild("Models", 5):WaitForChild("Bullets", 5):WaitForChild("Default", 5) end)
	pcall(function() SwingRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Swing", 5) end)
	pcall(function() HelperRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Helper", 5) end)
	pcall(function() FxRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx", 5) end)
end)

local SilentAimEnabled, SilentAimFOV = false, 90

--// ==================== HELPERS ====================
local function getCharacterParts()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function IsFriend(player) return player and FriendsList[player.UserId] == true end

local function ReapplyMovement()
	task.wait(1)
	if isUnloaded then return end
	local char, hum, root = getCharacterParts()
	if not char or not hum or not root then return end
	
	if FlyEnabled then
		if flyVelocity then flyVelocity:Destroy() end
		if flyGyro then flyGyro:Destroy() end
		flyVelocity = Instance.new("BodyVelocity", root)
		flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		flyGyro = Instance.new("BodyGyro", root)
		flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		flyGyro.P = 9000
	end
	if SpinEnabled then
		if spinAngular then spinAngular:Destroy() end
		spinAngular = Instance.new("BodyAngularVelocity", root)
		spinAngular.AngularVelocity = Vector3.new(0, SpinSpeed, 0)
		spinAngular.MaxTorque = Vector3.new(0, math.huge, 0)
		spinAngular.P = 1000
	end
end
LocalPlayer.CharacterAdded:Connect(ReapplyMovement)

--// ==================== TRACERS ====================
local tracerFolder = Instance.new("Folder")
tracerFolder.Name = "CLL_Tracers"
tracerFolder.Parent = workspace

local function CreateTracer(origin, targetPos)
	if not TracersEnabled then return end
	local dist = (targetPos - origin).Magnitude
	if dist > 500 then return end
	
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = TracerColor
	part.Size = Vector3.new(0.05, 0.05, dist)
	part.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)
	part.Parent = tracerFolder
	
	local tween = TweenService:Create(part, TweenInfo.new(TracerDuration or 0.5), { Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		part:Destroy()
	end)
end

--// ==================== INSTANT INTERACT ====================
local function disableHoldDuration(obj) if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end end
task.spawn(function()
	for _, v in pairs(workspace:GetDescendants()) do pcall(disableHoldDuration, v) end
	table.insert(Connections, workspace.DescendantAdded:Connect(disableHoldDuration))
end)

local function GetTargets()
    local targets = {}
    local anySelected = false
    for target, on in pairs(SelectedTargets) do if on then anySelected = true; break end end
    local function addPlayer(target)
        if target == LocalPlayer or not target.Parent then return end
        if SUK_IgnoreFriends and IsFriend(target) then return end
        local char = target.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if head and hum and hum.Health > 0 then table.insert(targets, {char = char, head = head, plr = target}) end
    end
    if anySelected then
        for target, on in pairs(SelectedTargets) do if on then addPlayer(target) end end
    else
        for _, plr in ipairs(Players:GetPlayers()) do addPlayer(plr) end
    end
    if SUK_TargetNPCs then
        for _, char in ipairs(NPC_List) do
            local head, hum = char:FindFirstChild("Head"), char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then table.insert(targets, {char = char, head = head}) end
        end
    end
    return targets
end

local function GetVRTargets()
    local targets = {}
    for target, on in pairs(VRSelectedTargets) do
        if on and target ~= LocalPlayer and target.Parent then
            local char = target.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then table.insert(targets, {char = char, head = head}) end
        end
    end
    return targets
end

--// ==================== COMBAT LOGIC ====================
local function ReadAmmo(tool)
	if not tool then return 0, 8 end
	local current = tool:GetAttribute("CurrentAmmo") or (tool:FindFirstChild("CurrentAmmo") and tool.CurrentAmmo.Value) or 0
	local max = tool:GetAttribute("MaxAmmo") or (tool:FindFirstChild("MaxAmmo") and tool.MaxAmmo.Value) or 8
	return tonumber(current) or 0, tonumber(max) or 8
end

local function IsReloading()
	local char = LocalPlayer.Character
	if not char then return false end
	local a = char:GetAttribute("Reloading")
	if a ~= nil then return a == true end
	local v = char:FindFirstChild("Reloading")
	if v and v:IsA("BoolValue") then return v.Value == true end
	return false
end

local function GetSpas()
	local function findSpas(container)
		if not container then return nil end
		local t = container:FindFirstChild("Spas 12") or container:FindFirstChild("Spas12") or container:FindFirstChild("SPAS 12")
		if t then return t end
		for _, ch in ipairs(container:GetChildren()) do
			if ch:IsA("Tool") and string.find(string.lower(ch.Name), "spas") then 
                return ch 
            end
		end
		return nil
	end
	return findSpas(LocalPlayer.Character) or findSpas(LocalPlayer:FindFirstChildOfClass("Backpack"))
end

local function StopReload(tool) 
    if ReloadRemote and tool then 
        pcall(function() ReloadRemote:InvokeServer(tool, "Stop Reload") end) 
    end 
end

local function InstantReload(tool)
	if not ReloadRemote or not tool or reloadInProgress then return end
	reloadInProgress = true
    
	task.spawn(function()
		pcall(function()
			local current, max = ReadAmmo(tool)
			if current >= max then return end
			
            local isShotgun = tool:GetAttribute("Shotgun") or string.find(string.lower(tool.Name), "spas") or string.find(string.lower(tool.Name), "remington")
            
            if isShotgun then
                ReloadRemote:InvokeServer(tool, "Start Reload")
                local need = math.max(0, max - current)
                for i = 1, need do
                    if isUnloaded or not tool or not tool.Parent then break end
                    ReloadRemote:InvokeServer(tool, "New Shell")
                    ReloadRemote:InvokeServer(tool, "Insert Shell")
                    task.wait(math.clamp(ReloadSpeed or 0.05, 0.01, 0.1))
                end
                ReloadRemote:InvokeServer(tool, "Stop Reload")
            else
                ReloadRemote:InvokeServer(tool)
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "MagOut")
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "ThrowMag")
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "GetNewMag")
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "InsertNewMag")
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "InsertNewMag2")
                task.wait(0.1)
                ReloadRemote:InvokeServer(tool, "SlideAction")
            end
            
			local char = LocalPlayer.Character
			if char then 
                pcall(function() char:SetAttribute("Reloading", false) end) 
            end
		end)
		pcall(function() if tool then ReloadRemote:InvokeServer(tool, "Stop Reload") end end)
		reloadInProgress = false
	end)
end

local targetIndex = 1
local function MultiFireAt()
	if not FireRemote then return end
	if reloadInProgress then return end
    
	local tool = GetSpas()
	if not tool then return end
	if tool.Parent ~= LocalPlayer.Character then return end
	if select(1, ReadAmmo(tool)) <= 0 then return end

	local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero
	local firepoint = tool:FindFirstChild("Base") and tool.Base:FindFirstChild("Firepoint")
	if firepoint then origin = firepoint.WorldPosition end

	local bulletModel = BulletModel
	local targets = GetTargets()
	local numTargets = #targets
	if numTargets == 0 then return end
	
    tool:SetAttribute("Cooldown", false) -- Bypass tool cooldown
    
	for i = 1, math.min(numTargets, 3) do
		local data = targets[targetIndex]
		if data and data.head and data.head.Parent then
			local dir = (data.head.Position - origin)
			if dir.Magnitude > 0.01 then
				dir = dir.Unit
				pcall(function()
					FireRemote:FireServer(tool, "Fire", { velocity = 2000, bullet = bulletModel, origin = origin, direction = dir })
                    if HelperRemote and TracersEnabled then
                        for j = 1, 8 do
                            pcall(function() HelperRemote:FireServer("Fx", "Fire Bullet", tool, { origin = origin, direction = dir }) end)
                        end
                    end
                end)
			end
		end
		targetIndex = (targetIndex % numTargets) + 1
	end
end

local function FireNormalGun(tool)
    if not FireRemote or not tool then return end
    tool:SetAttribute("Cooldown", false)
    
    local origin = tool:FindFirstChild("Base") and tool.Base:FindFirstChild("Firepoint") and tool.Base.Firepoint.WorldPosition or workspace.CurrentCamera.CFrame.Position
    local dir = workspace.CurrentCamera.CFrame.LookVector
    local bulletModel = BulletModel

    pcall(function()
        FireRemote:FireServer(tool, "Fire", { velocity = 2000, bullet = bulletModel, origin = origin, direction = dir })
        if HelperRemote then
            HelperRemote:FireServer("Gun Base", "Shot", tool)
            if TracersEnabled then 
                HelperRemote:FireServer("Fx", "Fire Bullet", tool, { origin = origin, direction = dir }) 
            end
        end
    end)

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, dir * 1000, params)

    if result then
        pcall(function()
            FireRemote:FireServer(tool, "Hit", {
                hit = result.Instance,
                normal = result.Normal,
                position = result.Position,
                velocity = 2000,
                bullet_cframe = CFrame.new(result.Position)
            })
            if HelperRemote then
                HelperRemote:FireServer("Gun Base", "Hit", result.Instance, result.Position, result.Normal)
                HelperRemote:FireServer("Fx", "Hitmarker", result.Instance)
            end
        end)
    end
end

--// ==================== HEAL LOGIC ====================
local function StartHealLoop()
	if healConnection then healConnection:Disconnect(); healConnection = nil end
	if antiVelocityConnection then antiVelocityConnection:Disconnect(); antiVelocityConnection = nil end
	if not HealEnabled then return end
	local _, _, root = getCharacterParts(); if root then savedHealPosition = root.CFrame end
	if SwingRemote and not isBlockActive then SwingRemote:FireServer('Block'); isBlockActive = true end
	
	healConnection = RunService.Heartbeat:Connect(function()
		if not HealEnabled or isUnloaded then return end
		local char, hum, root = getCharacterParts()
		if not char or not hum or not root or hum.Health <= 0 then return end
		local healBrick = workspace:FindFirstChild("Heal100Brick", true)
		if healBrick then
			if not hum.PlatformStand then hum.PlatformStand = true end
			local basePos = healBrick.Position + Vector3.new(0, HealFlyHeight, 0)
			root.CFrame = isMultiSuk and CFrame.new(basePos) or CFrame.new(basePos + Vector3.new(0, math.sin(os.clock() * 2) * 0.5, 0))
			root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
			for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then if not savedCollision[p] then savedCollision[p] = p.CanCollide end; p.CanCollide = false end end
		end
	end)
	table.insert(Connections, healConnection)
	antiVelocityConnection = RunService.Stepped:Connect(function()
		if not HealEnabled or isUnloaded then return end
		local _, _, root = getCharacterParts(); if root then root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
	end)
	table.insert(Connections, antiVelocityConnection)
end
local function StopHealLoop()
	if healConnection then healConnection:Disconnect(); healConnection = nil end
	if antiVelocityConnection then antiVelocityConnection:Disconnect(); antiVelocityConnection = nil end
	if SwingRemote and isBlockActive then SwingRemote:FireServer('UnBlock'); isBlockActive = false end
	if savedHealPosition then local _, _, root = getCharacterParts(); if root then root.CFrame = savedHealPosition end; savedHealPosition = nil end
	local _, humanoid = getCharacterParts(); if humanoid then humanoid.PlatformStand = false end
	for p, original in pairs(savedCollision) do if p and p.Parent then p.CanCollide = original end end
	table.clear(savedCollision)
end

--// ==================== MOVEMENT & EFFECTS ====================
RunService.Heartbeat:Connect(function()
	if isUnloaded then return end
	local char, humanoid, root = getCharacterParts()
	if not char or not humanoid or not root then return end
	if AntiSlowEnabled or AntiCCEnabled then
		for _, a in ipairs({"Stunned","Endlag","Hurt","Kicking","CantSprint","CantWalk","CantJump","CantStomp","CantDropkick","BackKickCooldown","DropkickCooldown","StompCooldown"}) do
			pcall(function() if char:GetAttribute(a) then char:SetAttribute(a, nil) end end)
		end
		pcall(function() if humanoid:GetAttribute("Stunned") then humanoid:SetAttribute("Stunned", nil) end end)
		if humanoid.WalkSpeed < 16 and not WalkSpeedEnabled then humanoid.WalkSpeed = 16 end
	end
	if NoRecoilEnabled then
		pcall(function()
			for _, tr in ipairs(humanoid:GetPlayingAnimationTracks()) do
				local n = tr.Name or ""
				if n:find("Fire") and not n:find("Reload") then tr:AdjustSpeed(0) end
			end
		end)
	end
	if WalkSpeedEnabled and humanoid.WalkSpeed ~= WalkSpeedValue then humanoid.WalkSpeed = WalkSpeedValue end
	if JumpPowerEnabled then humanoid.UseJumpPower = true; humanoid.JumpPower = JumpPowerValue end
	if NoClipEnabled then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then savedCollision[part] = savedCollision[part] or part.CanCollide; part.CanCollide = false end end end
	if FlyEnabled and flyVelocity and flyGyro and root then
		local move = Vector3.zero; local cam = workspace.CurrentCamera
		if UIS:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
		flyVelocity.Velocity = move.Magnitude > 0 and move.Unit * FlySpeed or Vector3.zero
		flyGyro.CFrame = cam.CFrame
	end
	if MaxZoomEnabled then LocalPlayer.CameraMaxZoomDistance = MaxZoomValue end
	if RemoveFogEnabled then game:GetService("Lighting").FogEnd = 100000; game:GetService("Lighting").FogStart = 0 end
	
	if FullbrightEnabled then
		local l = game:GetService("Lighting")
		l.Ambient = Color3.fromRGB(255, 255, 255); l.OutdoorAmbient = Color3.fromRGB(255, 255, 255); l.Brightness = 2; l.FogEnd = 100000
		for _, v in pairs(l:GetChildren()) do if v:IsA("Atmosphere") then v.Density = 0 end end
	elseif not FullbrightEnabled and not SkyColorEnabled then
		local l = game:GetService("Lighting")
		l.Ambient = Color3.fromRGB(70, 70, 70); l.OutdoorAmbient = Color3.fromRGB(128, 128, 128); l.Brightness = 1
	end
	
	if SkyColorEnabled then
		local l = game:GetService("Lighting")
		l.Ambient = SkyColor:Lerp(Color3.new(0,0,0), 0.5)
		l.OutdoorAmbient = SkyColor
		local sky = l:FindFirstChild("CLL_Sky")
		if not sky then
			sky = Instance.new("Sky", l)
			sky.Name = "CLL_Sky"
			sky.SkyboxBk = "rbxassetid://0"
			sky.SkyboxDn = "rbxassetid://0"
			sky.SkyboxFt = "rbxassetid://0"
			sky.SkyboxLf = "rbxassetid://0"
			sky.SkyboxRt = "rbxassetid://0"
			sky.SkyboxUp = "rbxassetid://0"
		end
	end
	
	if TimeOverrideEnabled then game:GetService("Lighting").ClockTime = TimeOverrideValue end
end)

-- FOV Lock Logic (Aggressive)
workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
	if CameraFOVLocked then workspace.CurrentCamera.FieldOfView = CameraFOVValue end
end)
RunService.RenderStepped:Connect(function()
	if CameraFOVLocked and workspace.CurrentCamera.FieldOfView ~= CameraFOVValue then
		workspace.CurrentCamera.FieldOfView = CameraFOVValue
	end
end)

--// ==================== ESP & HITBOX ====================
local function removeESP(player)
	local data = ESP_Cache[player]
	if data then for _, obj in pairs(data) do if typeof(obj) == "Instance" and obj.Destroy then obj:Destroy() end end; ESP_Cache[player] = nil end
end
Players.PlayerRemoving:Connect(removeESP); Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function() removeESP(p) end) end)

local function createESP(player)
	if ESP_Cache[player] or not ESPGui then return ESP_Cache[player] end
	local data = {}
	data.Box = Instance.new("Frame", ESPGui); data.Box.BackgroundTransparency = 1; data.Box.Visible = false; Instance.new("UIStroke", data.Box).Thickness = 1.5
	data.Name = Instance.new("TextLabel", ESPGui); data.Name.BackgroundTransparency = 1; data.Name.Font = Enum.Font.GothamBold; data.Name.TextSize = 14; data.Name.Visible = false
	data.HealthBg = Instance.new("Frame", ESPGui); data.HealthBg.BackgroundColor3 = Color3.new(0, 0, 0); data.HealthBg.Visible = false
	data.HealthFill = Instance.new("Frame", ESPGui); data.HealthFill.Visible = false
	data.Distance = Instance.new("TextLabel", ESPGui); data.Distance.BackgroundTransparency = 1; data.Distance.Font = Enum.Font.GothamBold; data.Distance.TextSize = 12; data.Distance.TextColor3 = Color3.new(1, 1, 1); data.Distance.Visible = false
	ESP_Cache[player] = data
	return data
end

RunService.RenderStepped:Connect(function()
	if isUnloaded or (not ESP_Config.Enabled and not HighlightChamsEnabled) then return end
	if not ESPGui then ESPGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui")); ESPGui.Name = "CLL_ESP"; ESPGui.ResetOnSpawn = false; ESPGui.IgnoreGuiInset = true end
	local cam = workspace.CurrentCamera
	if not cam then return end
	for _, v in ipairs(Players:GetPlayers()) do
		if v ~= LocalPlayer then
			local data = ESP_Cache[v]
			local char, hum, hrp, head = v.Character, v.Character and v.Character:FindFirstChildOfClass("Humanoid"), v.Character and v.Character:FindFirstChild("HumanoidRootPart"), v.Character and v.Character:FindFirstChild("Head")
			local visible = false
			if char and hum and hum.Health > 0 and hrp and head then
				local dist = (cam.CFrame.Position - hrp.Position).Magnitude
				if dist <= ESP_Config.MaxDist then
					local sp, onScreen = cam:WorldToViewportPoint(hrp.Position)
					if onScreen and sp.Z > 0 then
						local ts, tos = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.5, 0))
						local bs, bos = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
						if tos and bos and ts.Z > 0 and bs.Z > 0 then
							visible = true; if not data then data = createESP(v) end
							local color = IsFriend(v) and ESP_Config.FriendColor or ESP_Config.ChamsColor
							local h = math.abs(ts.Y - bs.Y); local w = h * 0.55; local x, y = sp.X - (w / 2), ts.Y
							data.Box.Visible = ESP_Config.Enabled and ESP_Config.Box
							if data.Box.Visible then data.Box.Size = UDim2.fromOffset(math.max(2, w), math.max(2, h)); data.Box.Position = UDim2.fromOffset(x, y); data.Box:FindFirstChildOfClass("UIStroke").Color = color end
							data.Name.Visible = ESP_Config.Enabled and ESP_Config.Name
							if data.Name.Visible then data.Name.Text = (IsFriend(v) and "[F] " or "") .. v.DisplayName; data.Name.Position = UDim2.new(0, sp.X, 0, y - 16); data.Name.Size = UDim2.new(0, 200, 0, 16); data.Name.TextColor3 = color; data.Name.AnchorPoint = Vector2.new(0.5, 0) end
							data.HealthBg.Visible = ESP_Config.Enabled and ESP_Config.Health; data.HealthFill.Visible = data.HealthBg.Visible
							if data.HealthBg.Visible then local hp = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1); data.HealthBg.Size = UDim2.new(0, 3, 0, h); data.HealthBg.Position = UDim2.new(0, x - 6, 0, y); data.HealthFill.Size = UDim2.new(0, 3, 0, h * hp); data.HealthFill.Position = UDim2.new(0, x - 6, 0, y + (h - h * hp)); data.HealthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), hp) end
							data.Distance.Visible = ESP_Config.Enabled and ESP_Config.Distance
							if data.Distance.Visible then data.Distance.Text = string.format("[%d m]", math.floor(dist * 0.28)); data.Distance.Position = UDim2.new(0, sp.X, 0, y + h + 2); data.Distance.Size = UDim2.new(0, 100, 0, 14); data.Distance.AnchorPoint = Vector2.new(0.5, 0) end
							if HighlightChamsEnabled then
								if not data.Highlight or data.Highlight.Parent ~= char then if data.Highlight then data.Highlight:Destroy() end; data.Highlight = Instance.new("Highlight", char); data.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end
								data.Highlight.Adornee = char; data.Highlight.Enabled = true; data.Highlight.FillColor = color; data.Highlight.OutlineColor = color; data.Highlight.FillTransparency = ESP_Config.ChamsFillTrans; data.Highlight.OutlineTransparency = ESP_Config.ChamsOutlineTrans
							elseif data.Highlight then data.Highlight.Enabled = false end
						end
					end
				end
			end
			if not visible and data then for _, obj in pairs(data) do if obj:IsA("GuiObject") then obj.Visible = false elseif obj:IsA("Highlight") then obj.Enabled = false end end end
		end
	end
end)

local function restoreHitbox(char, head, hrp)
	if Hitbox_Cache[char] then
		pcall(function()
			if head and head.Parent then head.Size = Hitbox_Cache[char].HeadSize; head.Transparency = Hitbox_Cache[char].HeadTrans; head.Material = Hitbox_Cache[char].HeadMat end
			if hrp and hrp.Parent then hrp.Size = Hitbox_Cache[char].HRPSize; hrp.Transparency = Hitbox_Cache[char].HRPTrans end
		end)
		Hitbox_Cache[char] = nil
	end
end

task.spawn(function()
	while not isUnloaded do
		task.wait(0.2)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local char = p.Character; local head, hrp, hum = char:FindFirstChild("Head"), char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
				if head and hrp and hum then
					if hum.Health <= 0 or not Hitbox_Config.Enabled then 
						restoreHitbox(char, head, hrp)
					else
						if not Hitbox_Cache[char] then Hitbox_Cache[char] = { HeadSize = head.Size, HeadTrans = head.Transparency, HeadMat = head.Material, HRPSize = hrp.Size, HRPTrans = hrp.Transparency } end
						pcall(function() 
							head.Size = Hitbox_Cache[char].HeadSize * (Hitbox_Config.Size / 2); hrp.Size = Vector3.new(Hitbox_Config.Size, Hitbox_Config.Size, Hitbox_Config.Size)
							head.Transparency = Hitbox_Config.Transparency; head.Material = Enum.Material[Hitbox_Config.Material]; hrp.Transparency = 1; head.CanCollide = false; hrp.CanCollide = false
						end)
					end
				end
			end
		end
		if Hitbox_Config.IncludeNPCs or SUK_TargetNPCs then
			if os.clock() - last_npc_scan >= 2 then
				last_npc_scan = os.clock(); table.clear(NPC_List)
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("Humanoid") then local char = obj.Parent; if char and char:IsA("Model") and not Players:GetPlayerFromCharacter(char) then if char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") then table.insert(NPC_List, char) end end end
				end
			end
			if Hitbox_Config.IncludeNPCs then
				for _, char in ipairs(NPC_List) do
					local head, hrp, hum = char:FindFirstChild("Head"), char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
					if head and hrp and hum then
						if hum.Health <= 0 or not char.Parent or not Hitbox_Config.Enabled then 
							restoreHitbox(char, head, hrp)
						else
							if not Hitbox_Cache[char] then Hitbox_Cache[char] = { HeadSize = head.Size, HeadTrans = head.Transparency, HeadMat = head.Material, HRPSize = hrp.Size, HRPTrans = hrp.Transparency } end
							pcall(function() 
								head.Size = Hitbox_Cache[char].HeadSize * (Hitbox_Config.Size / 2); hrp.Size = Vector3.new(Hitbox_Config.Size, Hitbox_Config.Size, Hitbox_Config.Size)
								head.Transparency = Hitbox_Config.Transparency; head.Material = Enum.Material[Hitbox_Config.Material]; hrp.Transparency = 1; head.CanCollide = false; hrp.CanCollide = false 
							end)
						end
					end
				end
			else for char, data in pairs(Hitbox_Cache) do if not Players:GetPlayerFromCharacter(char) then restoreHitbox(char, char:FindFirstChild("Head"), char:FindFirstChild("HumanoidRootPart")) end end end
		end
	end
end)

local function CleanDebris()
	if not AntiLagEnabled or isUnloaded then return end
	pcall(function()
		local cache = workspace:FindFirstChild("Cache")
		if cache and cache:FindFirstChild("Ignore_Debris") then for _, v in ipairs(cache.Ignore_Debris:GetChildren()) do if v:IsA("BasePart") or v:IsA("Model") then v:Destroy() end end end
	end)
end
task.spawn(function() while not isUnloaded do task.wait(0.5); if AntiLagEnabled then CleanDebris() end end end)

--// ==================== SUK & FIRERATE LOOP ====================
task.spawn(function()
	while not isUnloaded do
		local waitTime = 0.1
		if isMultiSuk then
			local tool = GetSpas()
			local char = LocalPlayer.Character
			if not tool then 
                waitTime = 0.25
			elseif tool.Parent ~= char then 
                pcall(function() char.Humanoid:EquipTool(tool) end)
                waitTime = 0.1
			else
				local ammo = select(1, ReadAmmo(tool))
				if ammo <= 0 then
                    InstantReload(tool)
					waitTime = 0.1
				else
					MultiFireAt()
					waitTime = math.max(SUK_FireDelay, 0.105)
				end
			end
		else
			if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				local char = LocalPlayer.Character
				local tool = char and char:FindFirstChildOfClass("Tool")
				if tool and not string.find(string.lower(tool.Name), "spas") then
					FireNormalGun(tool)
					waitTime = math.max(SUK_FireDelay, 0.105)
				end
			end
		end
		task.wait(waitTime)
	end
end)

--// ==================== VR IMPLEMENTATION ====================
local VR_Cam_Rotation = CFrame.new()
local vrHandShakeSeed = 0

local function releaseVRCamera()
 local cam = workspace.CurrentCamera
 if not cam then return end
 UIS.MouseIconEnabled = true
 cam.CameraType = Enum.CameraType.Custom
 local live = LocalPlayer.Character
 local liveHum = live and live:FindFirstChildOfClass("Humanoid")
 if liveHum and liveHum.Health > 0 then
  cam.CameraSubject = liveHum
 end
end

UIS.InputChanged:Connect(function(input)
 if not VREnabled then return end
 if input.UserInputType \~= Enum.UserInputType.MouseMovement then return end
 if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
 local d = input.Delta
 VR_Cam_Rotation = CFrame.Angles(0, math.rad(-d.X * 0.35), 0)
  * VR_Cam_Rotation
  * CFrame.Angles(math.rad(-d.Y * 0.35), 0, 0)
end)

RunService:BindToRenderStep("CLL_VR", Enum.RenderPriority.Camera.Value + 1, function(dt)
 if isUnloaded or not VREnabled then
  return
 end

 local cam = workspace.CurrentCamera
 local char = LocalPlayer.Character
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 local hrp = char and char:FindFirstChild("HumanoidRootPart")
 if not cam or not hum or not hrp or hum.Health <= 0 then
  releaseVRCamera()
  return
 end

 local looking = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
 UIS.MouseIconEnabled = not looking

 local headCF = CFrame.new(hrp.Position + Vector3.new(0, 1.6, 0)) * VR_Cam_Rotation
 if looking then
  cam.CameraType = Enum.CameraType.Scriptable
  cam.CFrame = headCF
 else
  if cam.CameraType == Enum.CameraType.Scriptable then
   cam.CameraType = Enum.CameraType.Custom
   cam.CameraSubject = hum
  end
  headCF = cam.CFrame
 end

 local reach = math.clamp(VRHandExtend or 0, 0, 100)
 local rightHand = headCF * CFrame.new(0.7, -0.5, -0.8 - reach)
 local leftHand = headCF * CFrame.new(-0.7, -0.5, -0.8 - reach)

 if VRShakeEnabled then
  vrHandShakeSeed += dt * 40
  local s = VRShakeIntensity or 0.5
  rightHand *= CFrame.new(math.sin(vrHandShakeSeed) * s, math.cos(vrHandShakeSeed) * s, 0)
  leftHand *= CFrame.new(math.sin(vrHandShakeSeed + 2) * s, math.cos(vrHandShakeSeed + 2) * s, 0)
 end

 local function pose(name, cf)
  local p = char:FindFirstChild(name)
  if not p then return end
  p.CanCollide = false
  p.Anchored = true
  p.CFrame = cf
 end
 pose("Right Arm", rightHand)
 pose("Left Arm", leftHand)
 pose("RightLowerArm", rightHand)
 pose("LeftLowerArm", leftHand)

 if FxRemote then
  pcall(function()
   FxRemote:FireServer("VR_UPDATE", {
    VR_RIGHT_ARM_CFRAME = rightHand,
    VR_LEFT_ARM_CFRAME = leftHand,
    VR_HEAD_CFRAME = headCF,
    VR_ROOTPART_CFRAME = hrp.CFrame,
   })
  end)
 end
end)

LocalPlayer.CharacterAdded:Connect(function()
 task.defer(releaseVRCamera)
end)

--// ==================== HOOKS ====================
local function GetClosestPlayerInFOV()
	if not SilentAimEnabled then return nil end
	local cam = workspace.CurrentCamera; if not cam then return nil end
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2); local closest, closestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local head, hum = plr.Character:FindFirstChild("Head"), plr.Character:FindFirstChildOfClass("Humanoid")
			if head and hum and hum.Health > 0 then
				local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
				if onScreen then
					local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
					if distFromCenter < (cam.ViewportSize.Y / 2) * (SilentAimFOV / cam.FieldOfView) and distFromCenter < closestDist then closest, closestDist = head, distFromCenter end
				end
			end
		end
	end
	return closest
end

local lastFireTime = 0
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = {...}
	
	if NoRecoilEnabled and method == "Fire" then
		if args[1] == "Fx" and (args[2] == "Camera Shake" or args[2] == "Fov" or args[2] == "Crosshair Shove" or args[2] == "Shake" or args[2] == "Earthquake") then return end
	end
	
	if method == "FireServer" and (self == FireRemote or self == FxRemote or self == SwingRemote) then
		local remoteName = tostring(args[1])
		if remoteName == "Fx" and (args[2] == "Camera Shake" or args[2] == "Shake" or args[2] == "Earthquake") then return end
		
		if self == FireRemote and args[2] == "Fire" then
			if SilentAimEnabled and typeof(args[3]) == "table" then
				local head = GetClosestPlayerInFOV()
				if head then
					local origin = args[3].origin
					if typeof(origin) == "Vector3" then
						local dir = head.Position - origin
						if dir.Magnitude > 0.01 then 
							args[3].direction = dir.Unit 
							CreateTracer(origin, head.Position)
						end
					end
					return oldNamecall(self, unpack(args))
				end
			end
		end
	end
	return oldNamecall(self, ...)
end)

-- Spoof VR State
local oldIndex = nil

--// ==================== UI FRAMEWORK ====================
local Theme = {
	Bg = Color3.fromRGB(10, 10, 12), Panel = Color3.fromRGB(16, 16, 20), Row = Color3.fromRGB(24, 24, 30),
	Stroke = Color3.fromRGB(38, 40, 50), Text = Color3.fromRGB(240, 242, 248), Dim = Color3.fromRGB(110, 114, 130),
	Off = Color3.fromRGB(32, 32, 40), OnTrack = Color3.fromRGB(55, 120, 255), Knob = Color3.fromRGB(255, 255, 255),
	TabOn = Color3.fromRGB(28, 32, 44), Accent = Color3.fromRGB(55, 120, 255),
}
local CosmeticColorCustom = Color3.fromRGB(55, 120, 255)
local CosmeticUseCustom = true
local watermarkMain, watermarkBinds, watermarkWorld = nil, nil, nil

local UIRefs = { window = nil, logoLabel = nil, sidebar = nil, header = nil }
local ThemeSubscribers = {}
local function subscribeTheme(fn) ThemeSubscribers[#ThemeSubscribers + 1] = fn end

local function fireTheme()
	Theme.OnTrack = Theme.Accent
	for i = 1, #ThemeSubscribers do pcall(ThemeSubscribers[i]) end
end
local DESIGN_W, DESIGN_H = 920, 560
local new = function(c, p, ch) local o = Instance.new(c); for k, v in pairs(p or {}) do o[k] = v end; for _, x in ipairs(ch or {}) do x.Parent = o end; return o end
local corner = function(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local round = function() return new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) end
local stroke = function(c, t) return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local label = function(p) p.BackgroundTransparency = 1; p.Font = p.Font or Enum.Font.Gotham; p.TextColor3 = p.TextColor3 or Theme.Text; p.TextSize = p.TextSize or 15; p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left; return new("TextLabel", p) end
local function tween(o, t, p) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), p):Play() end
local function spaced(t) return (t:upper():gsub("(.)", "%1 "):gsub(" $", "")) end

local gui = new("ScreenGui", { Name = "CLL", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true })
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

-- FOV Circle
local fovCircle = new("Frame", {
	Size = UDim2.fromOffset(200, 200), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, Visible = false, Parent = gui
}, { round(), stroke(Color3.fromRGB(255, 255, 255), 1) })

local function updateFOVCircle()
	if SilentAimEnabled then
		fovCircle.Visible = true
		local cam = workspace.CurrentCamera
		if not cam then return end
		local fovRadius = (cam.ViewportSize.Y / 2) * (SilentAimFOV / cam.FieldOfView)
		fovCircle.Size = UDim2.fromOffset(fovRadius * 2, fovRadius * 2)
	else
		fovCircle.Visible = false
	end
end
subscribeTheme(function() local s = fovCircle:FindFirstChildOfClass("UIStroke"); if s then s.Color = Theme.Accent end end)

local function cosmeticColor() return CosmeticUseCustom and CosmeticColorCustom or Theme.Accent end

-- Window (No Auto Center, No Position Reset)
local window = new("CanvasGroup", { Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Theme.Bg, GroupTransparency = 1, Parent = gui }, { corner(18), stroke() })
UIRefs.window = window
window.Visible = false
local uiScale = new("UIScale", { Parent = window })
local baseScale = 1; local animFactor = new("NumberValue", { Value = 0 })
local function applyScale() uiScale.Scale = math.max(baseScale * animFactor.Value, 0.001) end
animFactor.Changed:Connect(applyScale)
function fit() local cam = workspace.CurrentCamera; if not cam then return end; local vs = cam.ViewportSize; baseScale = math.clamp(math.min((vs.X - 24) / DESIGN_W, (vs.Y - 24) / DESIGN_H), 0.4, 1); applyScale() end
fit(); workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local header = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = window })
local logoLabel = label({ Text = "CLL", Font = Enum.Font.Michroma, TextSize = 26, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(100, 62), Position = UDim2.fromOffset(23, 0), Parent = header })
logoLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Always white
local verLabel = label({ Text = "v9.1", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(50, 62), Position = UDim2.fromOffset(85, 2), Parent = header })
local timeLabel = label({ Text = "Session: 00:00", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(150, 62), Position = UDim2.fromOffset(150, 0), Parent = header })
task.spawn(function()
	while not isUnloaded do
		local e = os.clock() - SessionStartTime
		timeLabel.Text = string.format("Session: %02d:%02d", math.floor(e/60), math.floor(e%60))
		task.wait(1)
	end
end)

-- Icons & Tabs
local function makeIcon(parent, build)
	local holder = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = parent })
	local fills, strokes = {}, {}; local kit = {}
	function kit.bar(w, h, x, y, rot, par) local f = new("Frame", { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Rotation = rot or 0, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = par or holder }, { corner(1) }); table.insert(fills, f); return f end
	function kit.disc(d, x, y, par) local f = new("Frame", { Size = UDim2.fromOffset(d, d), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = par or holder }, { round() }); table.insert(fills, f); return f end
	function kit.ring(w, h, x, y, t, par) local f = new("Frame", { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 1, Parent = par or holder }, { round() }); local s = stroke(Theme.Dim, t or 1.5); s.Parent = f; table.insert(strokes, s); return f end
	function kit.group(par) return new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, 11), BackgroundTransparency = 1, Parent = par or holder }) end
	build(kit)
	local function setColor(c) for _, f in ipairs(fills) do f.BackgroundColor3 = c end; for _, s in ipairs(strokes) do s.Color = c end end
	return setColor
end
local IconBuilders = {
	Combat = function(k) k.ring(14, 14, 11, 11, 1.5); k.bar(2, 5, 11, 2.5); k.bar(2, 5, 11, 19.5); k.bar(5, 2, 2.5, 11); k.bar(5, 2, 19.5, 11); k.disc(3, 11, 11) end,
	Movement = function(k) for _, x0 in ipairs({ 6.5, 13.5 }) do k.bar(8.5, 2, x0, 8, 45); k.bar(8.5, 2, x0, 14, -45) end end,
	Visual = function(k) local eye = k.ring(20, 12, 11, 11, 1.5); k.disc(5, 11, 11); return eye end,
	Effects = function(k) k.bar(8, 2.5, 11, 11, 0); k.bar(8, 2.5, 11, 11, 90); k.bar(6, 2, 11, 11, 45); k.bar(6, 2, 11, 11, -45); k.disc(2.5, 11, 11); for _, pos in ipairs({{5, 5}, {17, 5}, {5, 17}, {17, 17}}) do k.bar(4, 2, pos[1], pos[2], 0); k.bar(4, 2, pos[1], pos[2], 90); k.disc(1.5, pos[1], pos[2]) end end,
	Target = function(k) k.ring(19, 19, 11, 11, 1.5); k.ring(9, 9, 11, 11, 1); k.disc(3, 11, 11); k.bar(9, 1.5, 15.5, 11, 0); k.disc(3, 16.5, 6.5) end,
	Keybinds = function(k) k.ring(18, 18, 11, 11, 2); k.bar(2, 10, 9, 11, 20); k.bar(2, 10, 13, 11, -20); k.bar(5, 1.5, 11, 12, 0) end,
	Settings = function(k) local g = k.group(); for _, r in ipairs({{ 5, 8, { 3, 2 }, { 16, 8 } }, { 11, 15, { 6.5, 9 }, nil }, { 17, 11, { 4.5, 5 }, { 17.5, 5 } }}) do local y, kx, l, rt = r[1], r[2], r[3], r[4]; if l then k.bar(l[2], 2, l[1], y, 0, g) end; if rt then k.bar(rt[2], 2, rt[1], y, 0, g) end; k.disc(5, kx, y, g) end; return g end,
	VR = function(k) k.ring(16, 10, 11, 11, 1.5); k.disc(6, 7, 11); k.disc(6, 15, 11); k.bar(2, 4, 11, 5, 0) end,
	Profile = function(k) k.ring(18, 18, 11, 11, 2); k.bar(2, 10, 9, 11, 20); k.bar(2, 10, 13, 11, -20); k.bar(5, 1.5, 11, 12, 0) end,
}

local TAB_ORDER = { "Combat", "Movement", "Visual", "Effects", "Target", "Keybinds", "VR", "Settings" }
local sidebar = new("Frame", { Size = UDim2.fromOffset(150, DESIGN_H - 62), Position = UDim2.fromOffset(0, 62), BackgroundColor3 = Theme.Panel, Parent = window }, { corner(16), stroke() })
local pages, tabs = {}, {}
local currentTab
local contentFrame = new("Frame", { Size = UDim2.new(1, -150, 1, -62), Position = UDim2.fromOffset(150, 62), BackgroundTransparency = 1, Parent = window })

local function selectTab(name)
	if closeDrawer then pcall(closeDrawer) end
	currentTab = name
	for n, t in pairs(tabs) do
		local on = (n == name)
		if t.btn then tween(t.btn, 0.18, { BackgroundTransparency = on and 0 or 1 }) end
		if t.setColor then t.setColor(on and Theme.Accent or Theme.Dim) end
		if t.lbl then tween(t.lbl, 0.18, { TextColor3 = on and Theme.Text or Theme.Dim }) end
	end
	for n, pg in pairs(pages) do
		if n == name then pg.Visible = true; pg.GroupTransparency = 1; tween(pg, 0.16, { GroupTransparency = 0 })
		else pg.Visible = false end
	end
end

for idx, name in ipairs(TAB_ORDER) do
	local btn = new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 8 + (idx - 1) * 38), BackgroundColor3 = Theme.TabOn, BackgroundTransparency = 1, Parent = sidebar }, { corner(10) })
	local iconFrame = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), BackgroundTransparency = 1, Parent = btn })
	local setColor = makeIcon(iconFrame, IconBuilders[name] or IconBuilders.Settings)
	local lbl = label({ Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Dim, Size = UDim2.new(1, -48, 1, 0), Position = UDim2.fromOffset(36, 0), Parent = btn })
	tabs[name] = { btn = btn, setColor = setColor, lbl = lbl }
	pages[name] = new("CanvasGroup", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = contentFrame })
	local tabName = name
	subscribeTheme(function() if currentTab == tabName then setColor(Theme.Accent) else setColor(Theme.Dim) end end)
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- Profile
pages.Profile = new("CanvasGroup", { Name = "Profile", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = contentFrame })
do
	local card = new("TextButton", { Name = "ProfileCard", Text = "", AutoButtonColor = false, Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 1, -64), BackgroundColor3 = Theme.Row, Parent = sidebar }, { corner(12), stroke() })
	local avatar = new("ImageLabel", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Theme.Off, Parent = card }, { round(), stroke() })
	task.spawn(function() local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100); if ok then avatar.Image = img end end)
	local nick = label({ Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -56, 0, 18), Position = UDim2.fromOffset(52, 10), Parent = card })
	label({ Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Dim, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -56, 0, 16), Position = UDim2.fromOffset(52, 28), Parent = card })
	tabs.Profile = { btn = card, setColor = function() end, lbl = nick }
	card.MouseButton1Click:Connect(function() selectTab("Profile") end)
end

local PAD = 20
local function divider(parent, y) return new("Frame", { Size = UDim2.new(1, -PAD * 2, 0, 1), Position = UDim2.fromOffset(PAD, y), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = parent }) end

local function toggle(parent, cy, text, cb, initial)
	if text ~= "" then label({ Text = text, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(PAD, cy - 12), Parent = parent }) end
	local state = initial and true or false
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -PAD - 40 + 2, 0, cy - 11), BackgroundColor3 = Theme.Off, Parent = parent }, { corner(11), stroke() })
	local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme.Bg, Parent = sw }, { corner(8) })
	local function render() knob.Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3); knob.BackgroundColor3 = state and Theme.Knob or Theme.Bg; sw.BackgroundColor3 = state and Theme.OnTrack or Theme.Off end
	sw.MouseButton1Click:Connect(function() state = not state; render(); cb(state) end)
	render(); subscribeTheme(render)
	local function set(val) if state ~= val then state = val; render(); cb(state) end end
	return set
end

local function slider(parent, cy, text, min, max, default, step, cb)
	step = step or 1
	label({ Text = text, Size = UDim2.new(1, -80, 0, 18), Position = UDim2.fromOffset(12, cy - 8), Parent = parent })
	local valueLbl = label({ Text = tostring(default), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(56, 18), Position = UDim2.new(1, -68, 0, cy - 8), Parent = parent })
	local track = new("Frame", { Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, cy + 18), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = parent }, { corner(4) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }, { corner(4) })
	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Theme.Knob, Parent = track }, { corner(7) })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = track })
	local lastV = nil
	local function apply(a, fire)
		a = math.clamp(a, 0, 1); fill.Size = UDim2.fromScale(a, 1); knob.Position = UDim2.fromScale(a, 0.5)
		local v = min + (max - min) * a
		if step and step > 0 then v = math.floor(v / step + 0.5) * step end
		if step >= 1 then v = math.floor(v + 0.5) end
		valueLbl.Text = (step < 1) and string.format("%.3g", v) or tostring(v)
		if fire and v ~= lastV then lastV = v; cb(v) end
	end
	local dragging = false
	local function fromInput(i) apply((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), true) end
	hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; fromInput(i) end end)
	UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromInput(i) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	subscribeTheme(function() fill.BackgroundColor3 = Theme.Accent end)
	lastV = default; apply((default - min) / math.max(max - min, 1e-6), false)
end

local function makeMiniToggle(parent, initial, cb)
	local state = initial == true
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Active = true, Size = UDim2.fromOffset(36, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), BackgroundColor3 = Theme.Off, ZIndex = 5, Parent = parent }, { corner(10) })
	local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Theme.Knob, ZIndex = 6, Parent = sw }, { corner(8) })
	local function render() knob.Position = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2); sw.BackgroundColor3 = state and Theme.OnTrack or Theme.Off end
	sw.MouseButton1Click:Connect(function() state = not state; render(); if cb then cb(state) end end)
	render(); subscribeTheme(render)
	return function(v) state = v == true; render() end
end

local function detailSlider(parent, order, text, min, max, default, step, cb)
	local wrap = new("Frame", { Size = UDim2.new(1, -16, 0, 52), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	label({ Text = text, TextSize = 13, TextColor3 = Theme.Dim, Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(0, 0), Parent = wrap })
	local valueLbl = label({ Text = tostring(default), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(48, 18), Position = UDim2.new(1, -48, 0, 0), Parent = wrap })
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 28), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = wrap }, { corner(4) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }, { corner(4) })
	local knob = new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Theme.Knob, Parent = track }, { corner(6) })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = track })
	local function apply(a, fire)
		a = math.clamp(a, 0, 1); fill.Size = UDim2.fromScale(a, 1); knob.Position = UDim2.fromScale(a, 0.5)
		local v = min + (max - min) * a
		if step and step > 0 then v = math.floor(v / step + 0.5) * step end
		if step >= 1 then v = math.floor(v + 0.5) end
		valueLbl.Text = (step and step < 1) and string.format("%.3f", v) or tostring(v)
		if fire then cb(v) end
	end
	local dragging = false
	local function fromInput(i) apply((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), true) end
	hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; fromInput(i) end end)
	UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromInput(i) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	subscribeTheme(function() fill.BackgroundColor3 = Theme.Accent end)
	apply((default - min) / math.max(max - min, 1e-6), false)
end

local function detailColor(parent, order, title, getColor, setColor)
	local wrap = new("Frame", { Size = UDim2.new(1, -16, 0, 100), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	label({ Text = title, TextSize = 13, TextColor3 = Theme.Dim, Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(0, 0), Parent = wrap })
	local col = getColor()
	local prev = new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -28, 0, 0), BackgroundColor3 = col, Parent = wrap }, { corner(6), stroke() })
	local r, g, b = col.R, col.G, col.B
	
	local rSlider, gSlider, bSlider
	
	local function push() 
		local c = Color3.new(r, g, b)
		prev.BackgroundColor3 = c
		setColor(c) 
		if rSlider then rSlider(r) end
		if gSlider then gSlider(g) end
		if bSlider then bSlider(b) end
	end
	
	local function ch(y, name, get, set)
		label({ Text = name, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, y), Parent = wrap })
		local track = new("Frame", { Size = UDim2.new(1, -24, 0, 7), Position = UDim2.fromOffset(18, y + 3), BackgroundColor3 = Theme.Off, Parent = wrap }, { corner(3) })
		local fill = new("Frame", { Size = UDim2.fromScale(get(), 1), BackgroundColor3 = Color3.new(r, g, b), Parent = track }, { corner(3) })
		local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = track })
		local drag = false
		local function ap(a) a = math.clamp(a, 0, 1); fill.Size = UDim2.fromScale(a, 1); set(a); push(); fill.BackgroundColor3 = Color3.new(r, g, b) end
		hit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; ap((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)) end end)
		UIS.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then ap((i.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)) end end)
		UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
		return function(v) fill.Size = UDim2.fromScale(v, 1) end
	end
	
	rSlider = ch(28, "R", function() return r end, function(v) r = v end)
	gSlider = ch(52, "G", function() return g end, function(v) g = v end)
	bSlider = ch(76, "B", function() return b end, function(v) b = v end)
	push()
end

local function detailToggle(parent, order, text, initial, cb)
	local wrap = new("Frame", { Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	label({ Text = text, TextSize = 13, Size = UDim2.new(1, -50, 1, 0), Parent = wrap })
	makeMiniToggle(wrap, initial, cb)
end

local activeDrawer, activeDimmer = nil, nil
local function closeDrawer()
	local d, dim = activeDrawer, activeDimmer
	activeDrawer, activeDimmer = nil, nil
	if not d and not dim then return end
	if dim then local tdim = TweenService:Create(dim, TweenInfo.new(0.16), { BackgroundTransparency = 1 }); tdim:Play(); tdim.Completed:Connect(function() if dim then dim:Destroy() end end) end
	if d then local tw = TweenService:Create(d, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(1, 24, 0, 70) }); tw:Play(); tw.Completed:Connect(function() if d then d:Destroy() end end) end
end

local function openFeatureDrawer(feat)
	closeDrawer()
	if not feat.buildDetail then return end
	local dimmer = new("TextButton", { Name = "Dimmer", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 80, Parent = window })
	local drawer = new("Frame", { Name = "FeatureDrawer", Size = UDim2.fromOffset(300, DESIGN_H - 80), Position = UDim2.new(1, 24, 0, 70), BackgroundColor3 = Theme.Panel, ZIndex = 90, Parent = window }, { corner(16), stroke() })
	activeDrawer, activeDimmer = drawer, dimmer
	label({ Text = feat.name, Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.new(1, -50, 0, 24), Position = UDim2.fromOffset(16, 14), ZIndex = 91, Parent = drawer })
	local closeBtn = new("TextButton", { Text = "X", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Dim, BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -40, 0, 10), ZIndex = 91, Parent = drawer })
	closeBtn.MouseButton1Click:Connect(closeDrawer)
	dimmer.MouseButton1Click:Connect(closeDrawer)
	new("Frame", { Size = UDim2.new(1, -32, 0, 1), Position = UDim2.fromOffset(16, 48), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, ZIndex = 91, Parent = drawer })
	local body = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -64), Position = UDim2.fromOffset(8, 56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 91, Parent = drawer }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	feat.buildDetail(body)
	dimmer.Name = "Dimmer"
	TweenService:Create(dimmer, TweenInfo.new(0.18), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(drawer, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -312, 0, 70) }):Play()
end

local function buildFeaturePage(page, sectionTitle, features)
	local panel = new("Frame", { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.Panel, Parent = page }, { corner(14), stroke() })
	label({ Text = sectionTitle, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(16, 12), Parent = panel })
	label({ Text = "RMB - settings", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(120, 18), Position = UDim2.new(1, -132, 0, 12), Parent = panel })
	local list = new("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -42), Position = UDim2.fromOffset(6, 36), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	for i, feat in ipairs(features) do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Row, BackgroundTransparency = 0.35, LayoutOrder = i, Parent = list }, { corner(8) })
		local accentLine = new("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.fromOffset(8, 10), BackgroundColor3 = Theme.Accent, BackgroundTransparency = feat.buildDetail and 0.3 or 1, BorderSizePixel = 0, Parent = row }, { corner(2) })
		subscribeTheme(function() accentLine.BackgroundColor3 = Theme.Accent end)
		label({ Text = feat.name, Font = Enum.Font.GothamMedium, TextSize = 13, Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(18, 0), Parent = row })
		if feat.buildDetail then label({ Text = "⚙", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(28, 36), Position = UDim2.new(1, -78, 0, 0), Parent = row }) end
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -52, 1, 0), Parent = row })
		local swHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(48, 36), Position = UDim2.new(1, -48, 0, 0), ZIndex = 5, Parent = row })
		makeMiniToggle(swHolder, feat.initial == true, function(v) feat.onToggle(v) end)
		hit.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundTransparency = 0.1 }) end)
		hit.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundTransparency = 0.35 }) end)
		hit.MouseButton1Click:Connect(function() if feat.buildDetail then openFeatureDrawer(feat) end end)
		hit.MouseButton2Click:Connect(function() if feat.buildDetail then openFeatureDrawer(feat) end end)
	end
end

-- Pages
local function buildCombat()
	buildFeaturePage(pages.Combat, "ATTACK", {
		{ name = "Silent Aim", initial = false, onToggle = function(v) SilentAimEnabled = v end, buildDetail = function(d) detailSlider(d, 1, "FOV", 20, 360, SilentAimFOV, 1, function(v) SilentAimFOV = v; updateFOVCircle() end) end },
		{ name = "No Recoil", initial = false, onToggle = function(v) NoRecoilEnabled = v end, buildDetail = nil },
		{ name = "Firerate", initial = false, onToggle = function(v) end, buildDetail = function(d) detailSlider(d, 1, "RPS (1-30)", 1, 30, SUK_FIRERATE_RPS, 1, function(v) SUK_FIRERATE_RPS = v end); detailSlider(d, 2, "Fire Delay", 0.01, 0.5, SUK_FireDelay, 0.01, function(v) SUK_FireDelay = v end) end },
		{ name = "Anti-CC", initial = false, onToggle = function(v) AntiCCEnabled = v; AntiSlowEnabled = v end, buildDetail = nil },
		{ name = "Hitbox Expander", initial = false, onToggle = function(v) Hitbox_Config.Enabled = v end, buildDetail = function(d)
				detailSlider(d, 1, "Size", 1, 20, Hitbox_Config.Size, 0.5, function(v) Hitbox_Config.Size = v end)
				detailSlider(d, 2, "Transparency", 0, 1, Hitbox_Config.Transparency, 0.05, function(v) Hitbox_Config.Transparency = v end)
				detailToggle(d, 3, "Include NPCs", Hitbox_Config.IncludeNPCs, function(v) Hitbox_Config.IncludeNPCs = v end)
				local mats = { "ForceField", "Glass", "Neon", "Plastic" }; local idx = 1
				for i, m in ipairs(mats) do if m == Hitbox_Config.Material then idx = i end end
				local btn = new("TextButton", { Text = "Material: " .. mats[idx], Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = Theme.Row, LayoutOrder = 4, Parent = d }, { corner(8), stroke() })
				btn.MouseButton1Click:Connect(function() idx = idx % #mats + 1; Hitbox_Config.Material = mats[idx]; btn.Text = "Material: " .. mats[idx] end)
			end 
		},
	})
end

local function buildTarget()
	local left = new("Frame", { Size = UDim2.fromOffset(300, DESIGN_H - 102), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.Panel, ClipsDescendants = true, Parent = pages.Target }, { corner(14), stroke() })
	local right = new("Frame", { Size = UDim2.new(1, -328, 1, -24), Position = UDim2.fromOffset(320, 12), BackgroundColor3 = Theme.Panel, Parent = pages.Target }, { corner(14), stroke() })
	label({ Text = "COMBAT TARGET", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(14, 12), Parent = left })
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.fromOffset(0, 640), Parent = left })
	local y = 18
	toggle(scroll, y, "Enable SUK", function(v) isMultiSuk = v; if not v then reloadInProgress = false; local t = GetSpas(); if t then StopReload(t) end end end, false); y += 48
	slider(scroll, y, "Firerate RPS", 1, 30, SUK_FIRERATE_RPS, 1, function(v) SUK_FIRERATE_RPS = v end); y += 64
	slider(scroll, y, "Fire Delay (Safe)", 0.01, 0.5, SUK_FireDelay, 0.01, function(v) SUK_FireDelay = v end); y += 64
	slider(scroll, y, "Targets / tick", 1, 16, SUK_MaxPerTick, 1, function(v) SUK_MaxPerTick = v end); y += 64
	toggle(scroll, y, "Permanent Reload", function(v) PermanentReloadEnabled = v end, false); y += 46
	toggle(scroll, y, "Auto Healing", function(v) HealEnabled = v; if v then StartHealLoop() else StopHealLoop() end end, false); y += 46
	slider(scroll, y, "Heal Height", -5, 10, HealFlyHeight or 3.5, 0.5, function(v) HealFlyHeight = v end); y += 64
	toggle(scroll, y, "Ignore Friends", function(v) SUK_IgnoreFriends = v end, true); y += 46
	toggle(scroll, y, "Auto Kill NPCs", function(v) SUK_TargetNPCs = v end, false); y += 46
	toggle(scroll, y, "Equip required", function(v) SUK_EquipRequired = v end, SUK_EquipRequired)

	label({ Text = "PLAYERS", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(120, 18), Position = UDim2.fromOffset(14, 12), Parent = right })
	local searchBox = new("Frame", { Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 36), BackgroundColor3 = Theme.Row, Parent = right }, { corner(10), stroke() })
	local search = new("TextBox", { PlaceholderText = "Search...", PlaceholderColor3 = Theme.Dim, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.Text, BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = searchBox })
	local list = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -84), Position = UDim2.fromOffset(8, 78), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = right }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }) })
	local rows = {}
	local function refreshList()
		for _, r in pairs(rows) do if r.frame then r.frame:Destroy() end end
		table.clear(rows); local q = string.lower(search.Text or ""); local arr = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then local n, d = string.lower(p.Name), string.lower(p.DisplayName); if q == "" or string.find(n, q, 1, true) or string.find(d, q, 1, true) then table.insert(arr, p) end end
		end
		table.sort(arr, function(a, b) return a.DisplayName < b.DisplayName end)
		for i, p in ipairs(arr) do
			local on = SelectedTargets[p] == true
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Row, BackgroundTransparency = 0.25, LayoutOrder = i, Parent = list }, { corner(8) })
			label({ Text = p.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 13, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			local btn = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -34, 0.5, -11), BackgroundColor3 = on and Theme.Accent or Theme.Off, Parent = row }, { corner(6), stroke() })
			btn.MouseButton1Click:Connect(function() SelectedTargets[p] = not SelectedTargets[p]; btn.BackgroundColor3 = SelectedTargets[p] and Theme.Accent or Theme.Off end)
			rows[p] = { frame = row, btn = btn }
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(refreshList); Players.PlayerAdded:Connect(function() task.defer(refreshList) end); Players.PlayerRemoving:Connect(function(p) SelectedTargets[p] = nil; task.defer(refreshList) end); refreshList()
end

local function buildKeybinds()
	local panel = new("Frame", { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.Panel, Parent = pages.Keybinds }, { corner(12), stroke() })
	label({ Text = "KEYBINDS", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(14, 12), Parent = panel })
	local list = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -44), Position = UDim2.fromOffset(8, 36), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel }, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
	local bindRows = {
		{ "Menu", "Menu" }, { "SUK", "SUK" }, { "No Recoil", "NoRecoil" }, { "Anti-CC", "AntiCC" },
		{ "ESP", "ESP" }, { "Hitbox", "Hitbox" }, { "Fly", "Fly" }, { "Walk Speed", "WalkSpeed" }, { "Jump Power", "JumpPower" },
		{ "Heal", "Heal" }, { "Silent Aim", "SilentAim" }, { "China Hat", "ChinaHat" }, { "Wings", "Wings" }, { "Anti-Lag", "AntiLag" }, { "Spin", "Spin" },
        { "Teleport Heal", "TeleportHeal" }, { "Combo", "Combo" }, { "Reload Spas", "ReloadSpas" }
	}
	for i, item in ipairs(bindRows) do
		local title, keyName = item[1], item[2]
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Row, BackgroundTransparency = 0.25, LayoutOrder = i, Parent = list }, { corner(6) })
		label({ Text = title, Font = Enum.Font.Gotham, TextSize = 14, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
		local cur = Keys[keyName]
		local btn = new("TextButton", { Text = (cur and cur ~= Enum.KeyCode.Unknown) and cur.Name or "None", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(100, 24), Position = UDim2.new(1, -110, 0.5, -12), BackgroundColor3 = Theme.Off, Parent = row }, { corner(6), stroke() })
		btn.MouseButton1Click:Connect(function() btn.Text = "..."; isBinding = true; bindTarget = { btn = btn, keyName = keyName } end)
	end
end

local function buildVR()
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 800), Parent = pages.VR }, { corner(12), stroke() })
	
	label({ Text = "VR CONTROL (PC ONLY)", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(300, 24), Position = UDim2.fromOffset(PAD, 20), Parent = scroll })
	divider(scroll, 55)
	toggle(scroll, 80, "Enable VR Mode", function(v) 
		VREnabled = v
if v and FxRemote then
 pcall(function() FxRemote:FireServer("VR_INIT") end)
else
 releaseVRCamera()
end)
	toggle(scroll, 125, "Enable Hand Shake", function(v) VRShakeEnabled = v end, false)
	slider(scroll, 175, "Shake Intensity", 0, 2, VRShakeIntensity, 0.1, function(v) VRShakeIntensity = v end)
	
	divider(scroll, 225)
	label({ Text = "VR TARGETS", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(PAD, 245), Parent = scroll })
	
	local vrList = new("ScrollingFrame", { Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(PAD, 270), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = scroll }, { new("UIListLayout", { Padding = UDim.new(0, 4) }) })
	local vrRows = {}
	local function refreshVRList()
		for _, r in pairs(vrRows) do if r.frame then r.frame:Destroy() end end
		table.clear(vrRows)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				local on = VRSelectedTargets[p] == true
				local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Row, Parent = vrList }, { corner(6) })
				label({ Text = p.DisplayName, TextSize = 13, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = row })
				local btn = new("TextButton", { Text = "", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -25, 0.5, -10), BackgroundColor3 = on and Theme.Accent or Theme.Off, Parent = row }, { corner(5), stroke() })
				btn.MouseButton1Click:Connect(function() VRSelectedTargets[p] = not VRSelectedTargets[p]; btn.BackgroundColor3 = VRSelectedTargets[p] and Theme.Accent or Theme.Off end)
				vrRows[p] = { frame = row }
			end
		end
	end
	refreshVRList()
	Players.PlayerAdded:Connect(function() task.defer(refreshVRList) end); Players.PlayerRemoving:Connect(function(p) VRSelectedTargets[p] = nil; task.defer(refreshVRList) end)

	divider(scroll, 440)
	label({ Text = "VR AURA", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(PAD, 460), Parent = scroll })
	toggle(scroll, 490, "Enable VR Aura", function(v) VRAuraEnabled = v end, false)
	slider(scroll, 540, "Aura Speed", 1, 20, VRAuraSpeed, 1, function(v) VRAuraSpeed = v end)
	slider(scroll, 590, "Aura Radius", 1, 15, VRAuraRadius, 1, function(v) VRAuraRadius = v end)
	slider(scroll, 640, "Aura Height", -5, 10, VRAuraHeight, 1, function(v) VRAuraHeight = v end)
end

local function buildProfile()
	local panel = new("Frame", { Size = UDim2.fromOffset(350, DESIGN_H - 102), Position = UDim2.fromOffset(20, 20), BackgroundColor3 = Theme.Panel, Parent = pages.Profile }, { corner(16), stroke() })
	label({ Text = "P R O F I L E", Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = panel }); divider(panel, 61)
	local avatar = new("ImageLabel", { Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(PAD, 80), BackgroundColor3 = Theme.Row, Parent = panel }, { round(), stroke() })
	task.spawn(function() local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420); if ok then avatar.Image = img end end)
	label({ Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 22, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(PAD + 100, 85), Parent = panel })
	label({ Text = "@" .. LocalPlayer.Name, TextSize = 15, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(PAD + 100, 115), Parent = panel })
	divider(panel, 180)
	label({ Text = "A U T H  D A T A", Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(PAD, 200), Parent = panel })
	local function keyRow(name, val, y)
		label({ Text = name, TextSize = 14, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(100, 20), Position = UDim2.fromOffset(PAD, y), Parent = panel })
		label({ Text = val, Font = Enum.Font.Code, TextSize = 14, Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(PAD + 100, y), Parent = panel })
	end
	keyRow("License Key:", "CLL-PREM-1234-ABCD", 240); keyRow("Expires:", "Lifetime", 270); keyRow("Status:", "Active (Premium)", 300)
	keyRow("HWID:", string.sub(game:GetService("RbxAnalyticsService"):GetClientId(), 1, 16) .. "...", 330)
end

local function makeColorSlider(parent, y, labelText, value01, onChange)
	label({ Text = labelText, TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(18, 16), Position = UDim2.fromOffset(70, y), Parent = parent })
	local track = new("Frame", { Size = UDim2.fromOffset(220, 8), Position = UDim2.fromOffset(92, y + 4), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = parent }, { corner(4) })
	local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(value01, 0, 1), 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }, { corner(4) })
	local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = track })
	local dragging = false
	local function applyFromX(x) local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1); fill.Size = UDim2.fromScale(a, 1); fill.BackgroundColor3 = Theme.Accent; onChange(a, fill) end
	hit.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; applyFromX(input.Position.X) end end)
	UIS.InputChanged:Connect(function(input) if not dragging then return end; if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then applyFromX(input.Position.X) end end)
	UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	subscribeTheme(function() fill.BackgroundColor3 = Theme.Accent end)
	return fill
end

local function buildSettings()
    local left = new("Frame", { Size = UDim2.new(0.45, -10, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Theme.Panel, Parent = pages.Settings }, { corner(14), stroke() })
	local right = new("Frame", { Size = UDim2.new(0.55, -14, 1, -24), Position = UDim2.new(0.45, 10, 0, 12), BackgroundColor3 = Theme.Panel, Parent = pages.Settings }, { corner(14), stroke() })

    label({ Text = "INTERFACE", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(14, 12), Parent = left })
    local leftScroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, Parent = left })
    
    local y = 18
	toggle(leftScroll, y, "Watermark Main", function(v) WatermarkMainVisible = v; watermarkMain.Visible = v end, true); y += 48
	toggle(leftScroll, y, "Watermark Binds", function(v) WatermarkBindsVisible = v; watermarkBinds.Visible = v end, true); y += 48
	toggle(leftScroll, y, "Watermark World", function(v) WatermarkWorldVisible = v; watermarkWorld.Visible = v end, true); y += 64
	
	local animLbl = label({ Text = "UI Animation: " .. tostring(AnimName), TextSize = 13, Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(PAD, y), Parent = leftScroll }); y += 25
	local animBtn = new("TextButton", { Text = "Cycle preset", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, Size = UDim2.fromOffset(120, 28), Position = UDim2.fromOffset(PAD, y), BackgroundColor3 = Theme.Row, AutoButtonColor = false, Parent = leftScroll }, { corner(8), stroke() }); y += 48
	local animIdx = 1
    for i, n in ipairs(AnimOrder or {}) do 
        if n == AnimName then animIdx = i end 
    end
	animBtn.MouseButton1Click:Connect(function() 
        animIdx = (animIdx % #AnimOrder) + 1
        AnimName = AnimOrder[animIdx]
        animLbl.Text = "UI Animation: " .. AnimName 
    end)

	label({ Text = "ACCENT / SOLID COLOR", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(240, 18), Position = UDim2.fromOffset(16, y), Parent = leftScroll }); y += 30
	local accentPrev = new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(PAD, y), BackgroundColor3 = Theme.Accent, Parent = leftScroll }, { corner(8), stroke() }); y += 5
	local ar, ag, ab = Theme.Accent.R, Theme.Accent.G, Theme.Accent.B
	local function pushAccent() 
        Theme.Accent = Color3.new(ar, ag, ab)
        Theme.OnTrack = Theme.Accent
        accentPrev.BackgroundColor3 = Theme.Accent
        fireTheme() 
    end
	makeColorSlider(leftScroll, y, "R", ar, function(v, fill) ar = v; pushAccent(); if fill then fill.BackgroundColor3 = Theme.Accent end end); y += 25
	makeColorSlider(leftScroll, y, "G", ag, function(v, fill) ag = v; pushAccent(); if fill then fill.BackgroundColor3 = Theme.Accent end end); y += 25
	makeColorSlider(leftScroll, y, "B", ab, function(v, fill) ab = v; pushAccent(); if fill then fill.BackgroundColor3 = Theme.Accent end end); y += 50

    local rejoinBtn = new("TextButton", { Text = "Rejoin", Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 720), BackgroundColor3 = Theme.Row, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, Parent = leftScroll }, { corner(10), stroke() })
	rejoinBtn.MouseButton1Click:Connect(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)

	local unhookBtn = new("TextButton", { Text = "UnHook / Unload", Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 770), BackgroundColor3 = Theme.Row, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(255, 95, 110), AutoButtonColor = false, Parent = leftScroll }, { corner(10), stroke(Color3.fromRGB(255, 95, 110), 1.2) })
	unhookBtn.MouseButton1Click:Connect(function()
		isUnloaded = true
		for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
		StopHealLoop()
		if flyVelocity then flyVelocity:Destroy() end
		if flyGyro then flyGyro:Destroy() end
		if spinAngular then spinAngular:Destroy() end
		if oldNamecall then pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end) end
		if oldIndex then pcall(function() hookmetamethod(game, "__index", oldIndex) end) end
        if aimGui then aimGui:Destroy() end
		pcall(function() gui:Destroy() end)
	end)

    label({ Text = "FRIENDS & CONFIG", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(14, 12), Parent = right })
    local rScroll = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -44), Position = UDim2.fromOffset(8, 36), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, Parent = right })
    
    local rY = 0
    label({ Text = "FRIENDS", TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, rY), Parent = rScroll }); rY += 25
	local friendBox = new("TextBox", { PlaceholderText = "Player name...", PlaceholderColor3 = Theme.Dim, Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.Text, Size = UDim2.new(1, -100, 0, 32), Position = UDim2.fromOffset(0, rY), BackgroundColor3 = Theme.Row, Parent = rScroll }, { corner(8), stroke() })
	local addFriend = new("TextButton", { Text = "Add", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, Size = UDim2.fromOffset(90, 32), Position = UDim2.new(1, -90, 0, rY), BackgroundColor3 = Theme.Row, AutoButtonColor = false, Parent = rScroll }, { corner(8), stroke() })
    rY += 40
	
	local friendList = new("Frame", { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, rY), BackgroundTransparency = 1, Parent = rScroll }, { new("UIListLayout", { Padding = UDim.new(0, 4) }) }); rY += 110
	local function refreshFriends()
		for _, v in ipairs(friendList:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
		for id, _ in pairs(FriendsList) do
			local p = Players:GetPlayerByUserId(id)
			local name = p and p.DisplayName or ("ID: " .. tostring(id))
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Row, Parent = friendList }, { corner(6) })
			label({ Text = name, TextSize = 13, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = row })
			local btn = new("TextButton", { Text = "X", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -25, 0.5, -10), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 80, 80), Font = Enum.Font.GothamBold, Parent = row })
			btn.MouseButton1Click:Connect(function() FriendsList[id] = nil; refreshFriends() end)
		end
	end
	addFriend.MouseButton1Click:Connect(function() 
		local p = Players:FindFirstChild(friendBox.Text)
		if p and p ~= LocalPlayer then FriendsList[p.UserId] = true; friendBox.Text = ""; refreshFriends() end 
	end)
	refreshFriends()

    label({ Text = "CONFIG", TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, rY), Parent = rScroll }); rY += 25
    local cfgBox = new("TextBox", { Text = "default", PlaceholderText = "config name", PlaceholderColor3 = Theme.Dim, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Theme.Text, Size = UDim2.new(1, -100, 0, 32), Position = UDim2.fromOffset(0, rY), BackgroundColor3 = Theme.Row, ClearTextOnFocus = false, Parent = rScroll }, { corner(8), stroke() })
    local saveBtn = new("TextButton", { Text = "Save", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, Size = UDim2.fromOffset(90, 32), Position = UDim2.new(1, -90, 0, rY), BackgroundColor3 = Theme.Row, Parent = rScroll }, { corner(8), stroke() })
    rY += 40
    
    local cfgList = new("Frame", { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, rY), BackgroundTransparency = 1, Parent = rScroll }, { new("UIListLayout", { Padding = UDim.new(0, 4) }) }); rY += 110

	local function configPath(name) 
        name = (name or "default"):gsub("[^%w_%-]", "")
        if name == "" then name = "default" end
        return "cll_cfg_" .. name .. ".json" 
    end
	local function colorToArr(c) 
        if typeof(c) == "Color3" then return { c.R, c.G, c.B } end
        return c 
    end
	local function collectConfig()
		local esp = {}
		for k, v in pairs(ESP_Config) do esp[k] = colorToArr(v) end
		return {
			suk = isMultiSuk, fireDelay = SUK_FireDelay,
			heal = HealEnabled, ignoreFriends = SUK_IgnoreFriends, npcs = SUK_TargetNPCs,
			silent = SilentAimEnabled, fov = SilentAimFOV,
			hitbox = Hitbox_Config, esp = esp, chams = HighlightChamsEnabled,
			walk = WalkSpeedEnabled, walkV = WalkSpeedValue, jump = JumpPowerEnabled, jumpV = JumpPowerValue,
			fly = FlyEnabled, flyS = FlySpeed,
			timeOn = TimeOverrideEnabled, timeV = TimeOverrideValue,
			camFov = CameraFOVLocked, camFovV = CameraFOVValue,
			accent = { Theme.Accent.R, Theme.Accent.G, Theme.Accent.B },
		}
	end
	local function applyConfig(data)
		if type(data) ~= "table" then return end
		if data.fireDelay then SUK_FireDelay = data.fireDelay end
		if data.healH then HealFlyHeight = data.healH end
		if data.ignoreFriends ~= nil then SUK_IgnoreFriends = data.ignoreFriends end
		if data.npcs ~= nil then SUK_TargetNPCs = data.npcs end
		if data.silent ~= nil then SilentAimEnabled = data.silent end
		if data.fov then SilentAimFOV = data.fov end
		if type(data.hitbox) == "table" then for k, v in pairs(data.hitbox) do Hitbox_Config[k] = v end end
		if type(data.esp) == "table" then 
            for k, v in pairs(data.esp) do 
                if type(v) == "table" and v[1] then ESP_Config[k] = Color3.new(v[1], v[2], v[3]) 
                else ESP_Config[k] = v end 
            end 
        end
		if data.chams ~= nil then HighlightChamsEnabled = data.chams end
		if data.walk ~= nil then WalkSpeedEnabled = data.walk end
		if data.walkV then WalkSpeedValue = data.walkV end
		if data.jump ~= nil then JumpPowerEnabled = data.jump end
		if data.jumpV then JumpPowerValue = data.jumpV end
		if data.fly ~= nil then FlyEnabled = data.fly end
		if data.flyS then FlySpeed = data.flyS end
		if data.timeOn ~= nil then TimeOverrideEnabled = data.timeOn end
		if data.timeV then TimeOverrideValue = data.timeV end
		if data.camFov ~= nil then CameraFOVLocked = data.camFov end
		if data.camFovV then CameraFOVValue = data.camFovV end
		if data.accent then Theme.Accent = Color3.new(data.accent[1], data.accent[2], data.accent[3]); Theme.OnTrack = Theme.Accent end
		if data.suk ~= nil then isMultiSuk = data.suk end
		if data.heal ~= nil then HealEnabled = data.heal; if HealEnabled then pcall(StartHealLoop) else pcall(StopHealLoop) end end
		pcall(fireTheme)
	end

	saveBtn.MouseButton1Click:Connect(function() 
		pcall(function() if writefile then writefile(configPath(cfgBox.Text), HttpService:JSONEncode(collectConfig())) end end) 
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Row, Parent = cfgList }, { corner(6) })
        label({ Text = cfgBox.Text, TextSize = 13, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = row })
        local loadBtn = new("TextButton", { Text = "Load", Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -45, 0.5, -10), BackgroundColor3 = Theme.Off, TextColor3 = Theme.Text, TextSize = 10, Parent = row }, { corner(4) })
        loadBtn.MouseButton1Click:Connect(function() 
            pcall(function() 
                if isfile and isfile(configPath(cfgBox.Text)) then
                    applyConfig(HttpService:JSONDecode(readfile(configPath(cfgBox.Text))))
                end
            end)
        end)
	end)
end

buildCombat(); buildTarget(); buildKeybinds(); buildVR(); buildSettings(); buildProfile()

-- Movement
buildFeaturePage(pages.Movement, "MOVEMENT", {
	{ name = "Walk Speed", initial = false, onToggle = function(v) WalkSpeedEnabled = v; local _, h = getCharacterParts(); if h then h.WalkSpeed = v and WalkSpeedValue or 16 end end, buildDetail = function(d) detailSlider(d, 1, "Speed", 16, 200, WalkSpeedValue, 1, function(v) WalkSpeedValue = v; if WalkSpeedEnabled then local _, h = getCharacterParts(); if h then h.WalkSpeed = v end end end) end },
	{ name = "Jump Power", initial = false, onToggle = function(v) JumpPowerEnabled = v; local _, h = getCharacterParts(); if h then h.UseJumpPower = true; h.JumpPower = v and JumpPowerValue or 50 end end, buildDetail = function(d) detailSlider(d, 1, "Power", 50, 500, JumpPowerValue, 1, function(v) JumpPowerValue = v; if JumpPowerEnabled then local _, h = getCharacterParts(); if h then h.JumpPower = v end end end) end },
	{ name = "Fly", initial = false, onToggle = function(v) FlyEnabled = v; if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end; if flyGyro then flyGyro:Destroy(); flyGyro = nil end; if v then local _, _, r = getCharacterParts(); if r then flyVelocity = Instance.new("BodyVelocity", r); flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyGyro = Instance.new("BodyGyro", r); flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyGyro.P = 9000 end end end, buildDetail = function(d) detailSlider(d, 1, "Speed", 10, 200, FlySpeed, 1, function(v) FlySpeed = v end) end },
	{ name = "Spin", initial = false, onToggle = function(v) SpinEnabled = v; local _, _, r = getCharacterParts(); if spinAngular then spinAngular:Destroy(); spinAngular = nil end; if v and r then spinAngular = Instance.new("BodyAngularVelocity", r); spinAngular.AngularVelocity = Vector3.new(0, SpinSpeed, 0); spinAngular.MaxTorque = Vector3.new(0, math.huge, 0); spinAngular.P = 1000 end end, buildDetail = function(d) detailSlider(d, 1, "Spin Speed", 10, 500, SpinSpeed, 10, function(v) SpinSpeed = v; if spinAngular then spinAngular.AngularVelocity = Vector3.new(0, v, 0) end end) end },
	{ name = "No Clip", initial = false, onToggle = function(v) NoClipEnabled = v; if not v then for part, old in pairs(savedCollision) do if part and part.Parent then part.CanCollide = old end end; table.clear(savedCollision) end end, buildDetail = nil },
	{ name = "Infinite Jump", initial = false, onToggle = function(v) InfiniteJumpEnabled = v; if InfiniteJumpConnection then InfiniteJumpConnection:Disconnect(); InfiniteJumpConnection = nil end; if v then InfiniteJumpConnection = UIS.JumpRequest:Connect(function() if InfiniteJumpEnabled and not isUnloaded then local _, h = getCharacterParts(); if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end) end end, buildDetail = nil },
})

-- Visuals
buildFeaturePage(pages.Visual, "VISUAL", {
	{ name = "ESP", initial = false, onToggle = function(v) ESP_Config.Enabled = v end, buildDetail = function(d)
		detailSlider(d, 1, "Max Distance", 100, 2000, ESP_Config.MaxDist, 50, function(v) ESP_Config.MaxDist = v end)
		detailToggle(d, 2, "Box", ESP_Config.Box, function(v) ESP_Config.Box = v end)
		detailToggle(d, 3, "Name", ESP_Config.Name, function(v) ESP_Config.Name = v end)
		detailToggle(d, 4, "Health", ESP_Config.Health, function(v) ESP_Config.Health = v end)
		detailToggle(d, 5, "Distance", ESP_Config.Distance, function(v) ESP_Config.Distance = v end)
		detailColor(d, 6, "ESP Color", function() return ESP_Config.ChamsColor end, function(c) ESP_Config.ChamsColor = c end)
		detailColor(d, 7, "Friend Color", function() return ESP_Config.FriendColor end, function(c) ESP_Config.FriendColor = c end)
	end },
	{ name = "Highlight Chams", initial = false, onToggle = function(v) HighlightChamsEnabled = v end, buildDetail = function(d)
		detailSlider(d, 1, "Fill Transparency", 0, 1, ESP_Config.ChamsFillTrans, 0.05, function(v) ESP_Config.ChamsFillTrans = v end)
		detailSlider(d, 2, "Outline Transparency", 0, 1, ESP_Config.ChamsOutlineTrans, 0.05, function(v) ESP_Config.ChamsOutlineTrans = v end)
	end },
	{ name = "Bullet Tracers", initial = false, onToggle = function(v) TracersEnabled = v end, buildDetail = function(d)
		detailColor(d, 1, "Tracer Color", function() return TracerColor end, function(c) TracerColor = c end)
		detailSlider(d, 2, "Tracer Duration", 0.1, 2, TracerDuration, 0.1, function(v) TracerDuration = v end)
	end },
})

-- Effects
buildFeaturePage(pages.Effects, "EFFECTS", {
	{ name = "China Hat", initial = false, onToggle = function(v) ChinaHatEnabled = v; pcall(function() ChinaHat.set(v) end) end, buildDetail = nil },
	{ name = "Custom Wings", initial = false, onToggle = function(v) WingsEnabled = v; pcall(function() Wings.set(v) end) end, buildDetail = function(d) 
		local btn = new("TextButton", { Text = "Normal", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, Size = UDim2.new(1, -16, 0, 32), BackgroundColor3 = Theme.Row, LayoutOrder = 1, Parent = d }, { corner(8), stroke() })
		btn.MouseButton1Click:Connect(function() btn.Text = (btn.Text == "Normal" and "Bacon" or "Normal"); pcall(function() Wings.setType(btn.Text) end) end)
	end },
	{ name = "Anti-Lag", initial = false, onToggle = function(s) AntiLagEnabled = s; if s then CleanDebris() end end, buildDetail = nil },
	{ name = "Remove Fog", initial = false, onToggle = function(s) RemoveFogEnabled = s; if not s then game:GetService("Lighting").FogEnd = 1000 end end, buildDetail = nil },
	{ name = "Fullbright", initial = false, onToggle = function(s) FullbrightEnabled = s end, buildDetail = nil },
	{ name = "Time Override", initial = false, onToggle = function(s) TimeOverrideEnabled = s; if not s then game:GetService("Lighting").ClockTime = 14 end end, buildDetail = function(d) detailSlider(d, 1, "Time", 0, 24, TimeOverrideValue, 0.5, function(v) TimeOverrideValue = v end) end },
	{ name = "Camera FOV Lock", initial = false, onToggle = function(s) CameraFOVLocked = s; if not s then workspace.CurrentCamera.FieldOfView = 70 end end, buildDetail = function(d) detailSlider(d, 1, "FOV", 30, 120, CameraFOVValue, 1, function(v) CameraFOVValue = v end) end },
	{ name = "Max Zoom", initial = false, onToggle = function(s) MaxZoomEnabled = s; if not s then LocalPlayer.CameraMaxZoomDistance = 128 end end, buildDetail = function(d) detailSlider(d, 1, "Distance", 10, 500, MaxZoomValue, 1, function(v) MaxZoomValue = v; if MaxZoomEnabled then LocalPlayer.CameraMaxZoomDistance = v end end) end },
	{ name = "Sky Color", initial = false, onToggle = function(s) SkyColorEnabled = s; if not s then local sky = game:GetService("Lighting"):FindFirstChild("CLL_Sky"); if sky then sky:Destroy() end end end, buildDetail = function(d)
		detailColor(d, 1, "Sky Color", function() return SkyColor end, function(c) 
			SkyColor = c
			if SkyColorEnabled then
				local l = game:GetService("Lighting")
				local sky = l:FindFirstChild("CLL_Sky") or Instance.new("Sky", l)
				sky.Name = "CLL_Sky"
				sky.SkyboxBk = "rbxassetid://0"
				sky.SkyboxDn = "rbxassetid://0"
				sky.SkyboxFt = "rbxassetid://0"
				sky.SkyboxLf = "rbxassetid://0"
				sky.SkyboxRt = "rbxassetid://0"
				sky.SkyboxUp = "rbxassetid://0"
				sky.StarCount = 0
				l.Ambient = c:Lerp(Color3.new(0,0,0), 0.5)
				l.OutdoorAmbient = c
			end
		end)
	end }
})

-- Window Drag
do
	local dragging, startPos, startMouse
	header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, startMouse, startPos = true, i.Position, window.Position end end)
	UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - startMouse; window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

-- Watermarks
local function createWatermark(name, pos, width)
	local wm = new("Frame", {
		Size = UDim2.fromOffset(width, 32), Position = pos,
		BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, Parent = gui,
	}, { corner(10), stroke(), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }), new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }) })
	local dragging, startPos, startMouse
	wm.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, startMouse, startPos = true, i.Position, wm.Position end end)
	UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - startMouse; wm.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	return wm
end

watermarkMain = createWatermark("Main", UDim2.fromOffset(14, 70), 180)
local wmLogo = label({ Text = "CLL", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 255), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Parent = watermarkMain })
local function wmSep(parent) return new("Frame", { Size = UDim2.fromOffset(1, 12), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = parent }) end
wmSep(watermarkMain)
local fpsLbl = label({ Text = "-- FPS", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Parent = watermarkMain })
wmSep(watermarkMain)
local pingLbl = label({ Text = "-- ms", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Dim, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Parent = watermarkMain })

watermarkWorld = createWatermark("World", UDim2.fromOffset(14, 112), 120)
local worldLbl = label({ Text = "Time: 00:00", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Parent = watermarkWorld })

watermarkBinds = new("Frame", {
	Size = UDim2.fromOffset(200, 32), Position = UDim2.fromOffset(14, 154),
	BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, Parent = gui,
}, { corner(10), stroke(), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }), new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4) }) })
local bindsLbl = label({ Text = "Binds: None", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Parent = watermarkBinds })

do
	local dragging, startPos, startMouse
	watermarkBinds.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging, startMouse, startPos = true, i.Position, watermarkBinds.Position end end)
	UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - startMouse; watermarkBinds.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
end

task.spawn(function()
	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if isUnloaded then return end
		frames += 1; acc += dt
		if acc >= 0.5 then
			fpsLbl.Text = string.format("%d FPS", math.floor(frames / acc + 0.5))
			local ping = 0
			pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			pingLbl.Text = string.format("%d ms", ping)
			worldLbl.Text = "Time: " .. os.date("%H:%M")
			
			local activeBinds = {}
			for k, v in pairs(Keys) do if v ~= Enum.KeyCode.Unknown then table.insert(activeBinds, string.format("[%s] %s", v.Name, k)) end end
			if #activeBinds > 0 then bindsLbl.Text = table.concat(activeBinds, "\n") else bindsLbl.Text = "Binds: None" end
			watermarkBinds.Size = UDim2.fromOffset(200, math.max(32, 16 + #activeBinds * 16))
			frames, acc = 0, 0
		end
	end)
end)

-- Open / Close
local isOpen = false
local tweens = {}
local function play(obj, ti, goal) local t = TweenService:Create(obj, ti, goal); table.insert(tweens, t); t:Play(); return t end
local function setOpen(state)
	if state == isOpen then return end
	isOpen = state
	for _, t in ipairs(tweens) do t:Cancel() end; table.clear(tweens)
	local A = AnimPresets[AnimName] or AnimPresets.Smooth
	local oi = TweenInfo.new(A.open[3] * 0.85, A.open[1], A.open[2])
	local ci = TweenInfo.new(A.close[3] * 0.9, A.close[1], A.close[2])
	if state then
		window.Visible = true; window.GroupTransparency = 1; animFactor.Value = A.scale
		play(animFactor, oi, { Value = 1 }); play(window, TweenInfo.new(0.22, ES.Sine, ED.Out), { GroupTransparency = 0 })
	else
		play(animFactor, ci, { Value = A.scale })
		local fade = play(window, TweenInfo.new(0.2, ES.Sine, ED.In), { GroupTransparency = 1 })
		fade.Completed:Connect(function(st) if st == Enum.PlaybackState.Completed and not isOpen then window.Visible = false end end)
	end
end

local function toggleFly(state) FlyEnabled = state; if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end; if flyGyro then flyGyro:Destroy(); flyGyro = nil end; if state then local _, _, r = getCharacterParts(); if r then flyVelocity = Instance.new("BodyVelocity", r); flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyGyro = Instance.new("BodyGyro", r); flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyGyro.P = 9000 end end end

UIS.InputBegan:Connect(function(input, gp)
	if gp or UIS:GetFocusedTextBox() then return end
	if isBinding then
		if input.KeyCode == Enum.KeyCode.Escape then if bindTarget then bindTarget.btn.Text = "None"; Keys[bindTarget.keyName] = Enum.KeyCode.Unknown end
		elseif input.KeyCode ~= Enum.KeyCode.Unknown then if bindTarget then Keys[bindTarget.keyName] = input.KeyCode; bindTarget.btn.Text = input.KeyCode.Name end end
		isBinding = false; bindTarget = nil; return
	end
	local key = input.KeyCode
	if key == (Keys.Menu or Enum.KeyCode.RightShift) then setOpen(not isOpen); return end
	local function pressed(bind) return bind ~= nil and bind ~= Enum.KeyCode.Unknown and key == bind end
		if pressed(Keys.SUK) then 
        isMultiSuk = not isMultiSuk
        if not isMultiSuk then 
            reloadInProgress = false
            local t = GetSpas()
            if t then StopReload(t) end 
        end
	elseif pressed(Keys.AntiCC) then 
        AntiCCEnabled = not AntiCCEnabled
        AntiSlowEnabled = AntiCCEnabled
	elseif pressed(Keys.ESP) then 
        ESP_Config.Enabled = not ESP_Config.Enabled
	elseif pressed(Keys.Hitbox) then 
        Hitbox_Config.Enabled = not Hitbox_Config.Enabled
	elseif pressed(Keys.Fly) then 
        FlyEnabled = not FlyEnabled
        if not FlyEnabled and flyVelocity then 
            flyVelocity:Destroy()
            flyVelocity = nil
            if flyGyro then flyGyro:Destroy(); flyGyro = nil end 
        end
	elseif pressed(Keys.WalkSpeed) then 
        WalkSpeedEnabled = not WalkSpeedEnabled
	elseif pressed(Keys.JumpPower) then 
        JumpPowerEnabled = not JumpPowerEnabled
	elseif pressed(Keys.Heal) then 
        HealEnabled = not HealEnabled
        if HealEnabled then StartHealLoop() else StopHealLoop() end
	elseif pressed(Keys.SilentAim) then 
        SilentAimEnabled = not SilentAimEnabled
        updateFOVCircle()
	elseif pressed(Keys.VRGrab) then
		if VREnabled and SwingRemote then
			local targets = GetVRTargets()
			if targets[1] then 
                pcall(function() SwingRemote:FireServer("Grabmove", "RIGHT_ARM", targets[1].char) end)
                pcall(function() SwingRemote:FireServer("Grabmove", "LEFT_ARM", targets[1].char) end) 
            end
		end
	elseif pressed(Keys.TeleportHeal) then 
        TeleportToHeal()
    elseif pressed(Keys.Combo) then 
        ComboQ() 
    elseif pressed(Keys.ReloadSpas) then 
        local t = GetSpas()
        if t then InstantReload(t) end 
    end
end)

selectTab("Combat")
setOpen(true)
fireTheme()
updateFOVCircle()
