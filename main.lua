--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║              CLL CHEAT - FULL INTEGRATION v2.0                ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║                                                                ║
    ║  FEATURES:                                                     ║
    ║  • Modern UI with Combat/Movement/Visual/SUK tabs             ║
    ║  • ESP (Box, Name, Health, Distance, Chams, Friend colors)    ║
    ║  • Hitbox Expander (Players + NPCs, adjustable size)          ║
    ║  • SUK (Multi-kill system with Spas 12)                       ║
    ║  • Enhanced Autoheal:                                          ║
    ║    - Flies inside heal brick with BLOCK active                ║
    ║    - Noclip enabled during flight                             ║
    ║    - Zero velocity (no fall damage)                           ║
    ║    - Adjustable height slider (1-10 studs)                    ║
    ║  • AntiLag (Cleans debris & particles)                        ║
    ║  • Silent Aim with FOV control                                ║
    ║  • Friends system (ignore in SUK/ESP)                         ║
    ║  • China Hat & Custom Wings (cosmetic, client-side only)      ║
    ║                                                                ║
    ║  CONTROLS:                                                     ║
    ║  • Press RightShift to toggle menu                            ║
    ║                                                                ║
    ║  HEAL SYSTEM USAGE:                                            ║
    ║  1. Go to SUK tab                                             ║
    ║  2. Enable "Automatic Healing"                                ║
    ║  3. Adjust "Heal Fly Height" slider (default: 3.5)            ║
    ║  4. Player will fly inside heal brick with block spam active  ║
    ║                                                                ║
    ╚═══════════════════════════════════════════════════════════════╝
]]
--// CLL menu вЂ” FULL INTEGRATION (main UI + legacy features + enhanced autoheal)
local Players = game:GetService("Players")

--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                      ANTI-BYPASS PROTECTION                   ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- Check if loaded through official loader
if not _G.CLL_Auth or not _G.CLL_Auth.status or _G.CLL_Auth.status ~= "valid" then
    local function notify(title, text)
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 10
        })
    end
    
    notify("CLL Error", "Direct access denied!\nUse official loader.")
    
    warn("[CLL] ============================================")
    warn("[CLL] ANTI-BYPASS: Direct script access blocked")
    warn("[CLL] This script must be loaded through the official loader")
    warn("[CLL] Loadstring: https://github.com/bbbbbbbbb5565/htua-llc")
    warn("[CLL] ============================================")
    
    return -- Stop execution
end

-- Verify auth data integrity
local function verifyAuth()
    if type(_G.CLL_Auth) ~= "table" then return false end
    if not _G.CLL_Auth.status or _G.CLL_Auth.status ~= "valid" then return false end
    if not _G.CLL_Auth.role then return false end
    if not _G.CLL_Auth.type then return false end
    return true
end

if not verifyAuth() then
    warn("[CLL] Invalid authentication data - script terminated")
    return
end

print("[CLL] ✅ Authentication verified")
print("[CLL] Role:", _G.CLL_Auth.role)
print("[CLL] Type:", _G.CLL_Auth.type)
if _G.CLL_Auth.expires_at then
    print("[CLL] Expires:", _G.CLL_Auth.expires_at)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

--// ==================== SUK STATE ====================
local isMultiSuk = false
local SUK_INTERVAL = 0.1
local SUK_IgnoreFriends = true
local SUK_TargetNPCs = false
local FriendsList = {}
local SelectedTargets = {}
local SUK_Config = { velocity = 100000, bulletCount = 50 }

--// ==================== HEAL STATE (ENHANCED) ====================
local HealEnabled = false
local HealFlyHeight = 3.5 -- РќР°СЃС‚СЂР°РёРІР°РµРјР°СЏ РІС‹СЃРѕС‚Р° РїРѕР»С‘С‚Р°
local healConnection = nil
local healBlockConnection = nil
local antiVelocityConnection = nil
local savedCollision = {}

--// ==================== ESP STATE ====================
local ESP_Config = {
    Enabled = false, Box = true, Name = true, Health = true, Distance = true,
    Chams = false, MaxDist = 1000, ChamsColor = Color3.fromRGB(255, 92, 122),
    FriendColor = Color3.fromRGB(85, 255, 127),
    ChamsFillTrans = 0.5, ChamsOutlineTrans = 0
}
local ESP_Cache = {}
local ESPGui = nil
local last_esp_update = 0

--// ==================== HITBOX STATE ====================
local Hitbox_Config = { 
	Enabled = false, 
	IncludeNPCs = false, 
	Size = 5, 
	Material = Enum.Material.ForceField,
	Transparency = 0.5
}
local Hitbox_Cache = {}
local NPC_List = {}
local last_npc_scan = 0

--// ==================== MOVEMENT STATE ====================
local WalkSpeedEnabled = false
local WalkSpeedValue = 16
local JumpPowerEnabled = false
local JumpPowerValue = 50
local InfiniteJumpEnabled = false
local InfiniteJumpConnection = nil
local NoClipEnabled = false
local NoFallEnabled = false
local FlyEnabled = false
local FlySpeed = 50
local flyVelocity, flyGyro
local SpinEnabled = false
local SpinSpeed = 100
local spinAngular
local AntiSlowEnabled = false

--// ==================== ANTILAG STATE ====================
local AntiLagEnabled = false

--// ==================== VISUAL STATE ====================
local TimeOverrideEnabled = false
local TimeOverrideValue = 14
local CameraFOVLocked = false
local CameraFOVValue = 70
local MaxZoomValue = 35
local RemoveFogEnabled = false
local HighlightChamsEnabled = false
local ChamsEnemyColor = Color3.fromRGB(255, 92, 122)
local ChamsFriendColor = Color3.fromRGB(85, 255, 127)
local SessionStartTime = os.clock()
local ShowSessionTime = false

local isUnloaded = false
local Connections = {}

--// Remotes
local FireRemote, ReloadRemote, BulletModel, SwingRemote
task.spawn(function()
	pcall(function() FireRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fire", 5) end)
	pcall(function() ReloadRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Reload", 5) end)
	pcall(function() BulletModel = ReplicatedStorage:WaitForChild("Models", 5):WaitForChild("Bullets", 5):WaitForChild("Default", 5) end)
	pcall(function() SwingRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Swing", 5) end)
end)

--// ==================== SILENT AIM STATE ====================
local SilentAimEnabled = false
local SilentAimFOV = 90

--// ==================== HELPERS ====================
local function getCharacterParts()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function IsFriend(player) return player and FriendsList[player.UserId] == true end
local function AddFriend(playerOrName)
	local player
	if typeof(playerOrName) == "string" then
		-- Find player by name
		player = Players:FindFirstChild(playerOrName)
		if not player then
			-- Try DisplayName
			for _, p in ipairs(Players:GetPlayers()) do
				if p.DisplayName == playerOrName or p.Name == playerOrName then
					player = p
					break
				end
			end
		end
	else
		player = playerOrName
	end
	
	if player and player ~= LocalPlayer then
		FriendsList[player.UserId] = true
		return true
	end
	return false
end
local function RemoveFriend(userId)
	if FriendsList[userId] then
		FriendsList[userId] = nil
		return true
	end
	return false
end

--// ==================== SUK LOGIC ====================
local function disableHoldDuration(obj) if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end end
local connPrompt
task.spawn(function()
	for _, v in pairs(workspace:GetDescendants()) do pcall(disableHoldDuration, v) end
	connPrompt = workspace.DescendantAdded:Connect(disableHoldDuration)
	table.insert(Connections, connPrompt)
end)

local function GetSpas()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local char = LocalPlayer.Character
	local tool = nil
	if backpack then tool = backpack:FindFirstChild("Spas 12") end
	if not tool and char then tool = char:FindFirstChild("Spas 12") end
	return tool
end

local lastPickup = 0
local function AutoPickupSpas()
	if isUnloaded or os.clock() - lastPickup < 1 then return end
	lastPickup = os.clock()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end

	local spasObj = nil
	local tables = workspace:FindFirstChild("Weapon Tables")
	if tables then spasObj = tables:FindFirstChild("Spas 12", true) end
	if not spasObj then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj.Name == "Spas 12" and (obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart")) then
				local pos = obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position) or (obj:FindFirstChild("Handle") and obj.Handle.Position)
				if pos and (hrp.Position - pos).Magnitude < 150 then spasObj = obj; break end
			end
		end
	end
	if not spasObj then return end
	
	local pos = spasObj.Position or (spasObj.PrimaryPart and spasObj.PrimaryPart.Position) or (spasObj:FindFirstChild("Handle") and spasObj.Handle.Position)
	if not pos then return end
	
	local originalCFrame = hrp.CFrame
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
	task.wait(0.12)
	
	local prompts = {}
	for _, d in ipairs(spasObj:GetDescendants()) do if d:IsA("ProximityPrompt") then table.insert(prompts, d) end end
	if #prompts == 0 and tables then
		for _, d in ipairs(tables:GetDescendants()) do if d:IsA("ProximityPrompt") then table.insert(prompts, d) end end
	end
	for _, prompt in ipairs(prompts) do
		if prompt.Enabled then pcall(function() fireproximityprompt(prompt) end); task.wait(0.05) end
	end
	
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
		task.wait(0.06)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
	end)
	
	local startWait = os.clock()
	while not isUnloaded and os.clock() - startWait < 1.0 do
		if GetSpas() then break end
		pcall(function()
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
			task.wait(0.06)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
		end)
		task.wait(0.1)
	end
	if hrp and hrp.Parent and not isUnloaded then hrp.CFrame = originalCFrame end
end

local function InstantReload(tool)
	if not ReloadRemote or not tool then return end
	task.spawn(function()
		pcall(function()
			ReloadRemote:InvokeServer(tool, "Start Reload")
			for i = 1, 12 do ReloadRemote:InvokeServer(tool, "Insert Shell") end
			ReloadRemote:InvokeServer(tool, "Stop Reload")
		end)
	end)
end

local function MultiFireAt()
	local tool = GetSpas()
	if not tool then return end
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	local origin = myRoot.Position
	if tool:FindFirstChild("Handle") then origin = tool.Handle.Position
	elseif tool:FindFirstChild("FirePoint") then origin = tool.FirePoint.WorldPosition end

	local aliveTargets = {}
	for target, _ in pairs(SelectedTargets) do
		local char = target.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local head = char and char:FindFirstChild("Head")
		if not (SUK_IgnoreFriends and IsFriend(target)) and hum and hum.Health > 0 and head then
			table.insert(aliveTargets, {target = target, head = head})
		end
	end
	if SUK_TargetNPCs then
		for _, char in ipairs(workspace:GetDescendants()) do
			if char:IsA("Model") and not Players:GetPlayerFromCharacter(char) then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local head = char:FindFirstChild("Head")
				if hum and hum.Health > 0 and head then table.insert(aliveTargets, {target = char, head = head}) end
			end
		end
	end
	if #aliveTargets == 0 then return end
	
	local first = aliveTargets[1]
	local dir = (first.head.Position - origin).Unit
	pcall(function()
		local fireData = { velocity = SUK_Config.velocity, origin = origin, direction = dir }
		if BulletModel then fireData.bullet = BulletModel end
		FireRemote:FireServer(tool, "Fire", fireData)
	end)
	InstantReload(tool)
	
	for i = 1, SUK_Config.bulletCount do
		if isUnloaded or not isMultiSuk then break end
		local targetData = aliveTargets[(i % #aliveTargets) + 1]
		if targetData and targetData.head and targetData.head.Parent then
			local aim = targetData.head.Position
			local d = (aim - origin).Unit
			pcall(function()
				FireRemote:FireServer(tool, "Hit", { hit = targetData.head, normal = -d, position = aim, velocity = d * SUK_Config.velocity, bullet_cframe = CFrame.lookAt(aim, aim + d) })
			end)
		end
		if i % 3 == 0 then task.wait() end
	end
end

--// ==================== ENHANCED HEAL LOGIC ====================
local isBlockActive = false -- Track block state
local savedHealPosition = nil -- Save position before heal

local function StartHealLoop()
	if healConnection then healConnection:Disconnect(); healConnection = nil end
	if healBlockConnection then healBlockConnection:Disconnect(); healBlockConnection = nil end
	if antiVelocityConnection then antiVelocityConnection:Disconnect(); antiVelocityConnection = nil end
	if not HealEnabled then return end
	
	-- Save current position
	local _, _, root = getCharacterParts()
	if root then
		savedHealPosition = root.CFrame
	end
	
	-- Block connection: hold down Block constantly
	healBlockConnection = RunService.Heartbeat:Connect(function()
		if not HealEnabled or isUnloaded then return end
		if SwingRemote then
			SwingRemote:FireServer('Block')
		end
	end)
	table.insert(Connections, healBlockConnection)
	
	-- Main heal: fly + noclip
	healConnection = RunService.Heartbeat:Connect(function()
		if not HealEnabled or isUnloaded then return end
		local char, hum, root = getCharacterParts()
		if not char or not hum or not root or hum.Health <= 0 then return end
		
		-- Check if Spas-12 is in Backpack when SUK is active
		if isMultiSuk then
			-- Only check Backpack, not equipped (SUK needs it in backpack)
			local backpackTool = LocalPlayer.Backpack:FindFirstChild("Spas-12")
			if not backpackTool then return end -- Wait for SUK to get weapon
		end
		
		local traps = workspace:FindFirstChild("Traps")
		local buttons = traps and traps:FindFirstChild("buttons")
		local healBrick = buttons and buttons:FindFirstChild("Heal100Brick")
		if not healBrick then healBrick = workspace:FindFirstChild("Heal100Brick", true) end

		if healBrick then
			-- NO PlatformStand when SUK is active (prevents movement conflicts)
			if not isMultiSuk then
				-- Only sit when SUK is OFF
				if not hum.PlatformStand then
					hum.PlatformStand = true
				end
			end
			
			-- INSTANT teleport to heal brick
			local basePos = healBrick.Position + Vector3.new(0, HealFlyHeight, 0)
			
			-- NO floating animation when SUK is active (prevents physics conflicts)
			if isMultiSuk then
				root.CFrame = CFrame.new(basePos)
			else
				-- Float animation only when SUK is OFF
				local floatOffset = math.sin(os.clock() * 2) * 0.5
				root.CFrame = CFrame.new(basePos + Vector3.new(0, floatOffset, 0))
			end
			
			-- Cancel all velocity
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			
			-- Noclip
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then
					if not savedCollision[p] then savedCollision[p] = p.CanCollide end
					p.CanCollide = false
				end
			end
		end
	end)
	table.insert(Connections, healConnection)
	
	-- Anti-velocity (double insurance)
	antiVelocityConnection = RunService.Stepped:Connect(function()
		if not HealEnabled or isUnloaded then return end
		local char, hum, root = getCharacterParts()
		if not char or not hum or not root then return end
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end)
	table.insert(Connections, antiVelocityConnection)
end

local function StopHealLoop()
	if healConnection then healConnection:Disconnect(); healConnection = nil end
	if healBlockConnection then healBlockConnection:Disconnect(); healBlockConnection = nil end
	if antiVelocityConnection then antiVelocityConnection:Disconnect(); antiVelocityConnection = nil end
	
	-- Release Block
	if SwingRemote and isBlockActive then
		SwingRemote:FireServer('Unblock') -- Release block
		isBlockActive = false
	end
	
	-- Restore saved position
	if savedHealPosition then
		local _, _, root = getCharacterParts()
		if root then
			root.CFrame = savedHealPosition
		end
		savedHealPosition = nil
	end
	
	-- Restore PlatformStand
	local _, humanoid = getCharacterParts()
	if humanoid then
		humanoid.PlatformStand = false
	end
	
	local char = LocalPlayer.Character
	if char then
		for p, original in pairs(savedCollision) do
			if p and p.Parent then p.CanCollide = original end
		end
		table.clear(savedCollision)
	end
end

--// ==================== MOVEMENT LOGIC ====================
-- Main movement loop (Fly, NoClip, Anti-Slow, WalkSpeed, JumpPower)
RunService.Heartbeat:Connect(function()
	if isUnloaded then return end
	local char, humanoid, root = getCharacterParts()
	if not char or not humanoid or not root then return end
	
	-- Anti-Slow (removes Stunned, Endlag attributes)
	if AntiSlowEnabled then
		if char:GetAttribute("Stunned") then char:SetAttribute("Stunned", false) end
		if char:GetAttribute("Endlag") then char:SetAttribute("Endlag", false) end
		if humanoid.WalkSpeed < 16 and not WalkSpeedEnabled then humanoid.WalkSpeed = 16 end
	end
	
	-- WalkSpeed
	if WalkSpeedEnabled and humanoid.WalkSpeed ~= WalkSpeedValue then
		humanoid.WalkSpeed = WalkSpeedValue
	end
	
	-- JumpPower
	if JumpPowerEnabled then
		if not humanoid.UseJumpPower then humanoid.UseJumpPower = true end
		if humanoid.JumpPower ~= JumpPowerValue then humanoid.JumpPower = JumpPowerValue end
	end
	
	-- NoClip
	if NoClipEnabled then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedCollision[part] == nil then savedCollision[part] = part.CanCollide end
				part.CanCollide = false
			end
		end
	end
	
	-- Fly
	if FlyEnabled and flyVelocity and flyGyro and root then
		local move = Vector3.zero
		local cam = workspace.CurrentCamera
		if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
		
		if move.Magnitude > 0 then
			flyVelocity.Velocity = move.Unit * FlySpeed
		else
			flyVelocity.Velocity = Vector3.zero
		end
		flyGyro.CFrame = cam.CFrame
	end
	
	-- Camera FOV Lock (LOCKED - prevents game from changing it)
	if CameraFOVLocked then
		local cam = workspace.CurrentCamera
		if cam.FieldOfView ~= CameraFOVValue then
			cam.FieldOfView = CameraFOVValue
		end
	end
	
	-- Remove Fog (LOCKED - prevents game from adding fog back)
	if RemoveFogEnabled then
		local lighting = game:GetService("Lighting")
		if lighting.FogEnd ~= 100000 then
			lighting.FogEnd = 100000
			lighting.FogStart = 0
		end
	end
	
	-- Time Override (LOCKED - prevents game from changing time)
	if TimeOverrideEnabled then
		local lighting = game:GetService("Lighting")
		if lighting.ClockTime ~= TimeOverrideValue then
			lighting.ClockTime = TimeOverrideValue
		end
	end
end)

--// ==================== ESP LOGIC ====================
local function clearESP()
	if ESPGui then
		for _, child in pairs(ESPGui:GetChildren()) do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
	end
	for player, data in pairs(ESP_Cache) do
		if data.Highlight then data.Highlight:Destroy() end
	end
	ESP_Cache = {}
end

local function removeESP(player)
	local data = ESP_Cache[player]
	if data then
		if data.Box then data.Box:Destroy() end
		if data.Name then data.Name:Destroy() end
		if data.Distance then data.Distance:Destroy() end
		if data.HealthBg then data.HealthBg:Destroy() end
		if data.HealthFill then data.HealthFill:Destroy() end
		if data.HealthText then data.HealthText:Destroy() end
		if data.Highlight then data.Highlight:Destroy() end
		ESP_Cache[player] = nil
	end
end

-- РЈРґР°Р»РµРЅРёРµ РїСЂРё СЃРјРµСЂС‚Рё/respawn
Players.PlayerRemoving:Connect(removeESP)
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		p.CharacterRemoving:Connect(function() removeESP(p) end)
	end
end
Players.PlayerAdded:Connect(function(p)
	if p ~= LocalPlayer then
		p.CharacterRemoving:Connect(function() removeESP(p) end)
	end
end)

local function createESP(player)
	if ESP_Cache[player] then return ESP_Cache[player] end
	if not ESPGui then return nil end
	local data = {}
	data.Box = Instance.new("Frame", ESPGui)
	data.Box.BackgroundTransparency = 1; data.Box.BorderSizePixel = 0; data.Box.ZIndex = 50; data.Box.Visible = false
	local boxStroke = Instance.new("UIStroke", data.Box)
	boxStroke.Thickness = 1.5; boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	
	data.Name = Instance.new("TextLabel", ESPGui)
	data.Name.BackgroundTransparency = 1; data.Name.Font = Enum.Font.GothamBold; data.Name.TextSize = 14
	data.Name.TextColor3 = Color3.new(1, 1, 1); data.Name.TextStrokeTransparency = 0; data.Name.Visible = false; data.Name.ZIndex = 51
	
	data.HealthBg = Instance.new("Frame", ESPGui)
	data.HealthBg.BackgroundColor3 = Color3.new(0, 0, 0); data.HealthBg.Visible = false; data.HealthBg.ZIndex = 49
	data.HealthFill = Instance.new("Frame", ESPGui)
	data.HealthFill.Visible = false; data.HealthFill.ZIndex = 50
	data.HealthText = Instance.new("TextLabel", ESPGui)
	data.HealthText.BackgroundTransparency = 1; data.HealthText.Font = Enum.Font.GothamBold
	data.HealthText.TextSize = 12; data.HealthText.TextColor3 = Color3.new(1, 1, 1); data.HealthText.TextStrokeTransparency = 0
	data.HealthText.Visible = false; data.HealthText.ZIndex = 51
	
	data.Distance = Instance.new("TextLabel", ESPGui)
	data.Distance.BackgroundTransparency = 1; data.Distance.Font = Enum.Font.GothamBold
	data.Distance.TextSize = 12; data.Distance.TextColor3 = Color3.new(1, 1, 1); data.Distance.TextStrokeTransparency = 0
	data.Distance.Visible = false; data.Distance.ZIndex = 51
	
	ESP_Cache[player] = data
	return data
end

local function updateESP()
	if isUnloaded then return end
	if not ESP_Config.Enabled then if next(ESP_Cache) then clearESP() end return end
	if not ESPGui then
		ESPGui = Instance.new("ScreenGui")
		ESPGui.Name = "CLL_ESPLayer"; ESPGui.ResetOnSpawn = false
		ESPGui.IgnoreGuiInset = true; ESPGui.DisplayOrder = 9999
		ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ESPGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	for _, v in ipairs(Players:GetPlayers()) do
		if v ~= LocalPlayer then
			local data = ESP_Cache[v]
			local char = v.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local head = char and char:FindFirstChild("Head")
			local visible = false
			
			local currentColor = IsFriend(v) and ESP_Config.FriendColor or ESP_Config.ChamsColor

			if char and hum and hum.Health > 0 and hrp and head then
				local distance = (camera.CFrame.Position - hrp.Position).Magnitude
				if distance <= ESP_Config.MaxDist then
					local sp, onScreen = camera:WorldToViewportPoint(hrp.Position)
					if onScreen and sp.Z > 0 then
						local topPos = hrp.Position + Vector3.new(0, 2.5, 0)
						local botPos = hrp.Position - Vector3.new(0, 3.5, 0)
						local topScreen, topOnScreen = camera:WorldToViewportPoint(topPos)
						local botScreen, botOnScreen = camera:WorldToViewportPoint(botPos)
						if topOnScreen and botOnScreen and topScreen.Z > 0 and botScreen.Z > 0 then
							visible = true
							if not data then data = createESP(v) end
							if data then
								local height = math.abs(topScreen.Y - botScreen.Y)
								local width = height * 0.55
								local x = sp.X - (width / 2)
								local y = topScreen.Y
								
								if data.Box then
									data.Box.Visible = ESP_Config.Box
									if ESP_Config.Box then
										data.Box.Size = UDim2.fromOffset(math.max(2, width), math.max(2, height))
										data.Box.Position = UDim2.fromOffset(x, y)
										local stroke = data.Box:FindFirstChildOfClass("UIStroke")
										if stroke then stroke.Color = currentColor end
									end
								end
								if data.Name then
									data.Name.Visible = ESP_Config.Name
									if ESP_Config.Name then
										local prefix = IsFriend(v) and "[FRIEND] " or ""
										data.Name.Text = prefix .. v.DisplayName .. " (@" .. v.Name .. ")"
										data.Name.Position = UDim2.new(0, sp.X, 0, y - 16)
										data.Name.AnchorPoint = Vector2.new(0.5, 0)
										data.Name.Size = UDim2.new(0, 200, 0, 16)
										data.Name.TextColor3 = currentColor
									end
								end
								if data.HealthBg and data.HealthFill then
									data.HealthBg.Visible = ESP_Config.Health
									data.HealthFill.Visible = ESP_Config.Health
									if ESP_Config.Health then
										local hpPct = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
										local hpHeight = height * hpPct
										data.HealthBg.Size = UDim2.new(0, 3, 0, height)
										data.HealthBg.Position = UDim2.new(0, x - 6, 0, y)
										data.HealthFill.Size = UDim2.new(0, 3, 0, hpHeight)
										data.HealthFill.Position = UDim2.new(0, x - 6, 0, y + (height - hpHeight))
										data.HealthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), hpPct)
									end
								end
								if data.HealthText then
									data.HealthText.Visible = ESP_Config.Health
									if ESP_Config.Health then
										data.HealthText.Text = tostring(math.floor(hum.Health))
										data.HealthText.Position = UDim2.new(0, x - 10, 0, y + (height / 2) - 6)
										data.HealthText.AnchorPoint = Vector2.new(1, 0)
										data.HealthText.Size = UDim2.new(0, 40, 0, 14)
									end
								end
								if data.Distance then
									data.Distance.Visible = ESP_Config.Distance
									if ESP_Config.Distance then
										data.Distance.Text = string.format("[%d m]", math.floor(distance * 0.28))
										data.Distance.Position = UDim2.new(0, sp.X, 0, y + height + 2)
										data.Distance.AnchorPoint = Vector2.new(0.5, 0)
										data.Distance.Size = UDim2.new(0, 100, 0, 14)
									end
								end
								
								if ESP_Config.Chams then
									if not data.Highlight or not data.Highlight.Parent or data.Highlight.Parent ~= char then
										if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
										data.Highlight = Instance.new("Highlight", char)
										data.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
									end
									data.Highlight.Adornee = char
									data.Highlight.Enabled = true
									data.Highlight.FillColor = currentColor
									data.Highlight.OutlineColor = currentColor
									data.Highlight.FillTransparency = ESP_Config.ChamsFillTrans
									data.Highlight.OutlineTransparency = ESP_Config.ChamsOutlineTrans
								elseif data.Highlight then
									data.Highlight.Enabled = false
								end
							end
						end
					end
				end
			end
			
			if not visible and data then
				if data.Box then data.Box.Visible = false end
				if data.Name then data.Name.Visible = false end
				if data.Distance then data.Distance.Visible = false end
				if data.HealthBg then data.HealthBg.Visible = false end
				if data.HealthFill then data.HealthFill.Visible = false end
				if data.HealthText then data.HealthText.Visible = false end
				if data.Highlight then data.Highlight.Enabled = false end
			end
		end
	end
end

--// ==================== HITBOX LOGIC ====================
local function restoreHitbox(char, head, hrp)
	if Hitbox_Cache[char] then
		pcall(function()
			if head and head.Parent then
				head.Size = Hitbox_Cache[char].HeadSize
				head.Transparency = Hitbox_Cache[char].HeadTrans
				head.Material = Hitbox_Cache[char].HeadMat
			end
			if hrp and hrp.Parent then
				hrp.Size = Hitbox_Cache[char].HRPSize
				hrp.Transparency = Hitbox_Cache[char].HRPTrans
			end
		end)
		Hitbox_Cache[char] = nil
	end
end

local function updateHitboxes()
	if isUnloaded then return end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			local char = p.Character
			local head = char:FindFirstChild("Head")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if head and hrp and hum then
				if hum.Health <= 0 then
					restoreHitbox(char, head, hrp)
				elseif Hitbox_Config.Enabled then
					if not Hitbox_Cache[char] then
						Hitbox_Cache[char] = {
							HeadSize = head.Size,
							HeadTrans = head.Transparency,
							HeadMat = head.Material,
							HRPSize = hrp.Size,
							HRPTrans = hrp.Transparency
						}
					end
					pcall(function()
						local scale = Hitbox_Config.Size / 2
						head.Size = Hitbox_Cache[char].HeadSize * scale
						hrp.Size = Vector3.new(Hitbox_Config.Size, Hitbox_Config.Size, Hitbox_Config.Size)
						head.Transparency = Hitbox_Config.Transparency
						head.Material = Hitbox_Config.Material
						hrp.Transparency = 1
						head.Material = Hitbox_Config.Material
						head.CanCollide = false
						hrp.CanCollide = false
					end)
				else
					restoreHitbox(char, head, hrp)
				end
			end
		end
	end
	
	if Hitbox_Config.IncludeNPCs then
		if os.clock() - last_npc_scan >= 2 then
			last_npc_scan = os.clock()
			table.clear(NPC_List)
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("Humanoid") then
					local char = obj.Parent
					if char and char:IsA("Model") and not Players:GetPlayerFromCharacter(char) then
						if char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") then
							table.insert(NPC_List, char)
						end
					end
				end
			end
		end
		for _, char in ipairs(NPC_List) do
			local head = char:FindFirstChild("Head")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if head and hrp and hum then
				if hum.Health <= 0 or not char.Parent then
					restoreHitbox(char, head, hrp)
				else
					if not Hitbox_Cache[char] then
						Hitbox_Cache[char] = {
							HeadSize = head.Size,
							HeadTrans = head.Transparency,
							HeadMat = head.Material,
							HRPSize = hrp.Size,
							HRPTrans = hrp.Transparency
						}
					end
					pcall(function()
						local scale = Hitbox_Config.Size / 2
						head.Size = Hitbox_Cache[char].HeadSize * scale
						hrp.Size = Vector3.new(Hitbox_Config.Size, Hitbox_Config.Size, Hitbox_Config.Size)
						head.Transparency = Hitbox_Config.Transparency
						head.Material = Hitbox_Config.Material
						hrp.Transparency = 1
						head.Material = Hitbox_Config.Material
						head.CanCollide = false
						hrp.CanCollide = false
					end)
				end
			end
		end
	else
		for char, data in pairs(Hitbox_Cache) do
			if not Players:GetPlayerFromCharacter(char) then
				local head = char:FindFirstChild("Head")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if head and hrp then restoreHitbox(char, head, hrp) end
			end
		end
		table.clear(NPC_List)
	end
end

--// ==================== ANTILAG LOGIC ====================
local function CleanDebris()
	if not AntiLagEnabled or isUnloaded then return end
	pcall(function()
		-- Clean Cache/Ignore_Debris (rocks, debris)
		local cache = workspace:FindFirstChild("Cache")
		if cache then
			local ignoreDebris = cache:FindFirstChild("Ignore_Debris")
			if ignoreDebris then 
				for _, v in ipairs(ignoreDebris:GetChildren()) do 
					if v:IsA("BasePart") or v:IsA("Model") then
						pcall(function() v:Destroy() end)
					end
				end
			end
		end
		
		-- Clean General_VFX/Particles/Destructible
		local vfx = workspace:FindFirstChild("General_VFX")
		if vfx then
			local particles = vfx:FindFirstChild("Particles")
			if particles then
				local destructible = particles:FindFirstChild("Destructible")
				if destructible then 
					for _, v in ipairs(destructible:GetChildren()) do 
						pcall(function() v:Destroy() end)
					end
				end
			end
		end
		
		-- Disable all particle emitters with debris names
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				local name = v.Name:lower()
				if name:find("rock") or name:find("walldebris") or name:find("smoke") or name:find("debris") then
					v.Enabled = false
					pcall(function() v:Destroy() end)
				end
			end
		end
	end)
end

task.spawn(function()
	while not isUnloaded do
		task.wait(0.5) -- Faster cleanup (was 1.5)
		if AntiLagEnabled then CleanDebris() end
	end
end)

table.insert(Connections, workspace.DescendantAdded:Connect(function(obj)
	if not AntiLagEnabled or isUnloaded then return end
	if obj:IsA("ParticleEmitter") and (obj.Name:find("Rock") or obj.Name:find("WallDebris") or obj.Name:find("Smoke") or obj.Name:find("Debris")) then
		obj.Enabled = false
	end
end))

--// ==================== MAIN LOOPS ====================
-- SUK loop
task.spawn(function()
	while not isUnloaded do
		task.wait(SUK_INTERVAL)
		if isUnloaded then break end
		if isMultiSuk then
			if not GetSpas() then
				AutoPickupSpas()
			else
				MultiFireAt()
				task.wait(0.03)
			end
		end
	end
end)

-- ESP loop
task.spawn(function()
	while not isUnloaded do
		task.wait() -- Run every frame
		if ESP_Config.Enabled and os.clock() - last_esp_update >= (1/120) then -- 120 FPS update rate
			last_esp_update = os.clock()
			updateESP()
		end
	end
end)

-- Hitbox loop
task.spawn(function()
	while not isUnloaded do
		task.wait(0.2)
		updateHitboxes()
	end
end)

--// ==================== SILENT AIM ====================
local function GetClosestPlayerInFOV()
	if not SilentAimEnabled then return nil end
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local myChar = LocalPlayer.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	
	local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local closest, closestDist = nil, math.huge
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local char = plr.Character
			local head = char:FindFirstChild("Head")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if head and hum and hum.Health > 0 then
				local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
				if onScreen then
					local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
					local fovRadius = (cam.ViewportSize.Y / 2) * (SilentAimFOV / cam.FieldOfView)
					if distFromCenter < fovRadius and distFromCenter < closestDist then
						closest = head
						closestDist = distFromCenter
					end
				end
			end
		end
	end
	return closest
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = {...}
	
	if SilentAimEnabled and method == "FireServer" and self == FireRemote then
		local target = GetClosestPlayerInFOV()
		if target and args[2] == "Hit" and args[3] and typeof(args[3]) == "table" then
			args[3].hit = target
			args[3].position = target.Position
			args[3].normal = -(target.Position - args[3].position).Unit
			return oldNamecall(self, unpack(args))
		end
	end
	
	return oldNamecall(self, ...)
end)

--// Config System Variables
local HttpService = game:GetService("HttpService")
local CONFIG_FOLDER = "CLL_Configs"

local function SaveConfig(configName)
	if not writefile or not makefolder then 
		warn("[CLL] Config system not supported")
		return false
	end
	
	pcall(makefolder, CONFIG_FOLDER)
	
	local configData = {
		-- SUK
		SUK_Enabled = isMultiSuk,
		SUK_Velocity = SUK_Config.velocity,
		SUK_BulletCount = SUK_Config.bulletCount,
		SUK_Interval = SUK_INTERVAL,
		SUK_IgnoreFriends = SUK_IgnoreFriends,
		SUK_TargetNPCs = SUK_TargetNPCs,
		
		-- Heal
		HealEnabled = HealEnabled,
		HealFlyHeight = HealFlyHeight,
		
		-- ESP
		ESP_Enabled = ESP_Config.Enabled,
		ESP_Box = ESP_Config.Box,
		ESP_Name = ESP_Config.Name,
		ESP_Health = ESP_Config.Health,
		ESP_Distance = ESP_Config.Distance,
		ESP_Chams = ESP_Config.Chams,
		ESP_MaxDist = ESP_Config.MaxDist,
		ESP_ChamsFillTrans = ESP_Config.ChamsFillTrans,
		ESP_ChamsOutlineTrans = ESP_Config.ChamsOutlineTrans,
		
		-- Hitbox
		Hitbox_Enabled = Hitbox_Config.Enabled,
		Hitbox_IncludeNPCs = Hitbox_Config.IncludeNPCs,
		Hitbox_Size = Hitbox_Config.Size,
		Hitbox_Transparency = Hitbox_Config.Transparency,
		
		-- Combat
		SilentAim_Enabled = SilentAimEnabled,
		SilentAim_FOV = SilentAimFOV,
		
		-- Movement
		WalkSpeed_Enabled = WalkSpeedEnabled,
		WalkSpeed_Value = WalkSpeedValue,
		JumpPower_Enabled = JumpPowerEnabled,
		JumpPower_Value = JumpPowerValue,
		InfiniteJump_Enabled = InfiniteJumpEnabled,
		NoClip_Enabled = NoClipEnabled,
		NoFall_Enabled = NoFallEnabled,
		Fly_Enabled = FlyEnabled,
		FlySpeed = FlySpeed,
		Spin_Enabled = SpinEnabled,
		SpinSpeed = SpinSpeed,
		AntiSlow_Enabled = AntiSlowEnabled,
		
		-- Visual
		TimeOverride_Enabled = TimeOverrideEnabled,
		TimeOverride_Value = TimeOverrideValue,
		CameraFOV_Locked = CameraFOVLocked,
		CameraFOV_Value = CameraFOVValue,
		MaxZoom_Value = MaxZoomValue,
		RemoveFog_Enabled = RemoveFogEnabled,
		
		-- AntiLag
		AntiLag_Enabled = AntiLagEnabled,
		
		-- Friends
		FriendsList = FriendsList,
	}
	
	local success, err = pcall(function()
		writefile(CONFIG_FOLDER .. "/" .. configName .. ".json", HttpService:JSONEncode(configData))
	end)
	
	if success then
		print("[CLL] Config saved:", configName)
		-- Update config list
		if _G.CLL_UpdateConfigList then
			local configs = {}
			if isfolder and listfiles then
				if isfolder(CONFIG_FOLDER) then
					for _, file in ipairs(listfiles(CONFIG_FOLDER)) do
						local name = file:match("([^/\\]+)%.json$")
						if name then table.insert(configs, name) end
					end
				end
			end
			_G.CLL_UpdateConfigList(configs)
		end
		return true
	else
		warn("[CLL] Failed to save config:", err)
		return false
	end
end

local function LoadConfig(configName)
	if not readfile or not isfile then 
		warn("[CLL] Config system not supported")
		return false
	end
	
	local filePath = CONFIG_FOLDER .. "/" .. configName .. ".json"
	if not isfile(filePath) then
		warn("[CLL] Config not found:", configName)
		return false
	end
	
	local success, data = pcall(function()
		return HttpService:JSONDecode(readfile(filePath))
	end)
	
	if not success or type(data) ~= "table" then
		warn("[CLL] Failed to load config:", configName)
		return false
	end
	
	-- Apply config data
	if data.SUK_Velocity then SUK_Config.velocity = data.SUK_Velocity end
	if data.SUK_BulletCount then SUK_Config.bulletCount = data.SUK_BulletCount end
	if data.SUK_Interval then SUK_INTERVAL = data.SUK_Interval end
	if data.SUK_IgnoreFriends ~= nil then SUK_IgnoreFriends = data.SUK_IgnoreFriends end
	if data.SUK_TargetNPCs ~= nil then SUK_TargetNPCs = data.SUK_TargetNPCs end
	
	if data.HealFlyHeight then HealFlyHeight = data.HealFlyHeight end
	
	if data.ESP_MaxDist then ESP_Config.MaxDist = data.ESP_MaxDist end
	if data.ESP_ChamsFillTrans then ESP_Config.ChamsFillTrans = data.ESP_ChamsFillTrans end
	if data.ESP_ChamsOutlineTrans then ESP_Config.ChamsOutlineTrans = data.ESP_ChamsOutlineTrans end
	
	if data.Hitbox_Size then Hitbox_Config.Size = data.Hitbox_Size end
	if data.Hitbox_Transparency then Hitbox_Config.Transparency = data.Hitbox_Transparency end
	
	if data.SilentAim_FOV then SilentAimFOV = data.SilentAim_FOV end
	
	if data.WalkSpeed_Value then WalkSpeedValue = data.WalkSpeed_Value end
	if data.JumpPower_Value then JumpPowerValue = data.JumpPower_Value end
	if data.FlySpeed then FlySpeed = data.FlySpeed end
	if data.SpinSpeed then SpinSpeed = data.SpinSpeed end
	
	if data.TimeOverride_Value then TimeOverrideValue = data.TimeOverride_Value end
	if data.CameraFOV_Value then CameraFOVValue = data.CameraFOV_Value end
	if data.MaxZoom_Value then MaxZoomValue = data.MaxZoom_Value end
	
	-- Load friends list
	if data.FriendsList then
		FriendsList = {}
		for userId, v in pairs(data.FriendsList) do
			FriendsList[tonumber(userId) or userId] = v
		end
		
		-- Update friends UI
		local friendsList = {}
		for userId, _ in pairs(FriendsList) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(friendsList, player.DisplayName or player.Name)
			end
		end
		if _G.CLL_UpdateFriendsList then
			_G.CLL_UpdateFriendsList(friendsList)
		end
	end
	
	print("[CLL] Config loaded:", configName)
	return true
end

local function DeleteConfig(configName)
	if not delfile or not isfile then 
		warn("[CLL] Config system not supported")
		return false
	end
	
	local filePath = CONFIG_FOLDER .. "/" .. configName .. ".json"
	if not isfile(filePath) then
		warn("[CLL] Config not found:", configName)
		return false
	end
	
	local success = pcall(function()
		delfile(filePath)
	end)
	
	if success then
		print("[CLL] Config deleted:", configName)
		-- Update config list
		if _G.CLL_UpdateConfigList then
			local configs = {}
			if isfolder and listfiles then
				if isfolder(CONFIG_FOLDER) then
					for _, file in ipairs(listfiles(CONFIG_FOLDER)) do
						local name = file:match("([^/\\]+)%.json$")
						if name then table.insert(configs, name) end
					end
				end
			end
			_G.CLL_UpdateConfigList(configs)
		end
		return true
	else
		warn("[CLL] Failed to delete config:", configName)
		return false
	end
end

--// РљРѕР»Р±СЌРєРё: СЃСЋРґР° РїРѕРґРєР»СЋС‡Р°Р№ СЃРІРѕСЋ Р»РѕРіРёРєСѓ
local Callbacks = {
	OnMenu = function(isOpen) end,
	OnTab = function(name) end,
	OnMainToggle = function(state) 
		isMultiSuk = state
	end,
	OnSlider = function(key, value)
		if key == "velocity" then
			SUK_Config.velocity = value
		elseif key == "hits" then
			SUK_Config.bulletCount = value
		elseif key == "interval" then
			SUK_INTERVAL = value
		elseif key == "combat.silent_fov" then
			SilentAimFOV = value
		elseif key == "heal_height" then
			HealFlyHeight = value
		elseif key == "esp_maxdist" then
			ESP_Config.MaxDist = value
		elseif key == "esp_chams_fill" then
			ESP_Config.ChamsFillTrans = value
		elseif key == "esp_chams_outline" then
			ESP_Config.ChamsOutlineTrans = value
		elseif key == "hitbox_size" then
			Hitbox_Config.Size = value
		elseif key == "hitbox_trans" then
			Hitbox_Config.Transparency = value
		-- Visual sliders
		elseif key == "effects.time_value" then
			TimeOverrideValue = value
			if TimeOverrideEnabled then
				game:GetService("Lighting").ClockTime = value
			end
		elseif key == "effects.fov_value" then
			CameraFOVValue = value
			if CameraFOVLocked then
				workspace.CurrentCamera.FieldOfView = value
			end
		elseif key == "effects.max_zoom" then
			MaxZoomValue = value
			LocalPlayer.CameraMaxZoomDistance = value
		-- Movement sliders
		elseif key == "move.walkspeed_val" then
			WalkSpeedValue = value
			if WalkSpeedEnabled then
				local _, humanoid = getCharacterParts()
				if humanoid then humanoid.WalkSpeed = value end
			end
		elseif key == "move.jumppower_val" then
			JumpPowerValue = value
			if JumpPowerEnabled then
				local _, humanoid = getCharacterParts()
				if humanoid then humanoid.UseJumpPower = true; humanoid.JumpPower = value end
			end
		elseif key == "move.fly_speed" then
			FlySpeed = value
		elseif key == "move.spin_speed" then
			SpinSpeed = value
			if SpinEnabled and spinAngular then
				local _, _, root = getCharacterParts()
				if root then spinAngular.AngularVelocity = Vector3.new(0, SpinSpeed == 0 and 10000 or SpinSpeed, 0) end
			end
		end
	end,
	OnOption = function(key, state)
		if key == "heal" then
			HealEnabled = state
			if state then StartHealLoop() else StopHealLoop() end
		elseif key == "ignoreFriends" then
			SUK_IgnoreFriends = state
		elseif key == "targetNpcs" then
			SUK_TargetNPCs = state
		elseif key == "addFriend" then
			if AddFriend(state) then
				-- Update friends list UI
				local friendsList = {}
				for userId, _ in pairs(FriendsList) do
					local player = Players:GetPlayerByUserId(userId)
					if player then
						table.insert(friendsList, player.DisplayName or player.Name)
					end
				end
				if _G.CLL_UpdateFriendsList then
					_G.CLL_UpdateFriendsList(friendsList)
				end
			end
		elseif key == "removeFriend" then
			-- state is username
			local player
			for _, p in ipairs(Players:GetPlayers()) do
				if p.DisplayName == state or p.Name == state then
					player = p
					break
				end
			end
			if player and RemoveFriend(player.UserId) then
				-- Update friends list UI
				local friendsList = {}
				for userId, _ in pairs(FriendsList) do
					local p = Players:GetPlayerByUserId(userId)
					if p then
						table.insert(friendsList, p.DisplayName or p.Name)
					end
				end
				if _G.CLL_UpdateFriendsList then
					_G.CLL_UpdateFriendsList(friendsList)
				end
			end
		elseif key == "combat.silent_aim" then
			SilentAimEnabled = state
		elseif key == "esp" then
			ESP_Config.Enabled = state
		elseif key == "esp_box" then
			ESP_Config.Box = state
		elseif key == "esp_name" then
			ESP_Config.Name = state
		elseif key == "esp_health" then
			ESP_Config.Health = state
		elseif key == "esp_distance" then
			ESP_Config.Distance = state
		elseif key == "esp_chams" then
			ESP_Config.Chams = state
		elseif key == "hitbox" then
			Hitbox_Config.Enabled = state
		elseif key == "hitbox_npcs" then
			Hitbox_Config.IncludeNPCs = state
		elseif key == "antilag" then
			AntiLagEnabled = state
			if state then CleanDebris() end -- Instant cleanup when enabled
		-- Visual toggles
		elseif key == "effects.time_override" then
			TimeOverrideEnabled = state
			if not state then
				game:GetService("Lighting").ClockTime = 14 -- Reset to default
			else
				game:GetService("Lighting").ClockTime = TimeOverrideValue
			end
		elseif key == "effects.fov_lock" then
			CameraFOVLocked = state
			if state then
				workspace.CurrentCamera.FieldOfView = CameraFOVValue
			end
		elseif key == "effects.remove_fog" then
			RemoveFogEnabled = state
			local Lighting = game:GetService("Lighting")
			if state then
				Lighting.FogEnd = 100000
				Lighting.FogStart = 0
			else
				Lighting.FogEnd = 1000 -- Default
				Lighting.FogStart = 0
			end
		elseif key == "vis.highlight_chams" then
			HighlightChamsEnabled = state
		-- Movement toggles
		elseif key == "move.walkspeed" then
			WalkSpeedEnabled = state
			local _, humanoid = getCharacterParts()
			if humanoid then humanoid.WalkSpeed = state and WalkSpeedValue or 16 end
		elseif key == "move.jumppower" then
			JumpPowerEnabled = state
			local _, humanoid = getCharacterParts()
			if humanoid then 
				humanoid.UseJumpPower = true
				humanoid.JumpPower = state and JumpPowerValue or 50
			end
		elseif key == "move.infinitejump" then
			InfiniteJumpEnabled = state
			if InfiniteJumpConnection then InfiniteJumpConnection:Disconnect(); InfiniteJumpConnection = nil end
			if state then
				InfiniteJumpConnection = UIS.JumpRequest:Connect(function()
					if not InfiniteJumpEnabled or isUnloaded then return end
					local _, humanoid = getCharacterParts()
					if humanoid and humanoid.Health > 0 then
						humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end)
				table.insert(Connections, InfiniteJumpConnection)
			end
		elseif key == "move.noclip" then
			NoClipEnabled = state
			if not state then
				for part, old in pairs(savedCollision) do
					if part and part.Parent then part.CanCollide = old end
				end
				table.clear(savedCollision)
			end
		elseif key == "move.nofall" then
			NoFallEnabled = state
			local _, humanoid = getCharacterParts()
			if humanoid then
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not state) end)
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not state) end)
			end
		elseif key == "move.fly" then
			FlyEnabled = state
			if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
			if flyGyro then flyGyro:Destroy(); flyGyro = nil end
			if state then
				local _, humanoid, root = getCharacterParts()
				if root and humanoid then
					flyVelocity = Instance.new("BodyVelocity", root)
					flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
					flyVelocity.Velocity = Vector3.zero
					flyGyro = Instance.new("BodyGyro", root)
					flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
					flyGyro.P = 9000
				end
			end
		elseif key == "move.spin" then
			SpinEnabled = state
			local _, _, root = getCharacterParts()
			if spinAngular then spinAngular:Destroy(); spinAngular = nil end
			if state and root then
				spinAngular = Instance.new("BodyAngularVelocity", root)
				spinAngular.AngularVelocity = Vector3.new(0, SpinSpeed == 0 and 10000 or SpinSpeed, 0)
				spinAngular.MaxTorque = Vector3.new(0, math.huge, 0)
				spinAngular.P = 1000
			end
		elseif key == "move.antislow" then
			AntiSlowEnabled = state
		elseif key == "saveConfig" then
			SaveConfig(state)
		elseif key == "loadConfig" then
			LoadConfig(state)
		elseif key == "deleteConfig" then
			DeleteConfig(state)
		end
	end,
	OnSelectionChanged = function(selected)
		SelectedTargets = selected
	end,
	OnDropdown = function(key, value)
		if key == "hitbox_material" then
			if value == "ForceField" then
				Hitbox_Config.Material = Enum.Material.ForceField
			elseif value == "Glass" then
				Hitbox_Config.Material = Enum.Material.Glass
			elseif value == "Plastic" then
				Hitbox_Config.Material = Enum.Material.Plastic
			end
		end
	end,
}

--// РџСѓСЃС‚С‹С€РєРё РґР»СЏ РІРєР»Р°РґРѕРє Combat / Movement / Visual / Effects (РїСЂР°РІСЊ РєР°Рє С…РѕС‡РµС€СЊ)
local Features = {
	Combat = {
		{
			title = "COMBAT",
			items = {
				{ type = "toggle", text = "Silent aim", key = "combat.silent_aim" },
				{ type = "slider", text = "Silent aim FOV", key = "combat.silent_fov", min = 20, max = 360, default = 90, step = 1 },
			},
		},
		{
			title = "Hitbox Expander",
			items = {
				{ type = "toggle", text = "Hitbox Enabled", key = "hitbox" },
				{ type = "toggle", text = "Include NPCs", key = "hitbox_npcs" },
				{ type = "slider", text = "Hitbox Size", key = "hitbox_size", min = 1, max = 20, default = 5, step = 0.5 },
				{ type = "slider", text = "Transparency", key = "hitbox_trans", min = 0, max = 1, default = 0.5, step = 0.05 },
			},
		},
	},
	Movement = {
		{
			title = "Ground Movement",
			items = {
				{ type = "toggle", text = "Walk Speed", key = "move.walkspeed" },
				{ type = "slider", text = "Walk Speed Value", key = "move.walkspeed_val", min = 16, max = 200, default = 16, step = 1 },
				{ type = "toggle", text = "Jump Power", key = "move.jumppower" },
				{ type = "slider", text = "Jump Power Value", key = "move.jumppower_val", min = 50, max = 500, default = 50, step = 1 },
				{ type = "toggle", text = "Infinite Jump", key = "move.infinitejump" },
				{ type = "toggle", text = "No Clip", key = "move.noclip" },
				{ type = "toggle", text = "No Fall Damage", key = "move.nofall" },
			},
		},
		{
			title = "Flight & Spin",
			items = {
				{ type = "toggle", text = "Fly", key = "move.fly" },
				{ type = "slider", text = "Fly Speed", key = "move.fly_speed", min = 10, max = 200, default = 50, step = 1 },
				{ type = "toggle", text = "Spin", key = "move.spin" },
				{ type = "slider", text = "Spin Speed (0=max)", key = "move.spin_speed", min = 0, max = 1000, default = 100, step = 10 },
				{ type = "toggle", text = "Anti-Slow", key = "move.antislow" },
			},
		},
	},
	Visual = {
		{
			title = "ESP",
			items = {
				{ type = "toggle", text = "ESP Enabled", key = "esp" },
				{ type = "toggle", text = "Box", key = "esp_box" },
				{ type = "toggle", text = "Name", key = "esp_name" },
				{ type = "toggle", text = "Health", key = "esp_health" },
				{ type = "toggle", text = "Distance", key = "esp_distance" },
				{ type = "toggle", text = "Chams", key = "esp_chams" },
				{ type = "slider", text = "Max Distance", key = "esp_maxdist", min = 100, max = 2000, default = 1000, step = 50 },
			},
		},
		{
			title = "Chams Settings",
			items = {
				{ type = "slider", text = "Chams Fill Transparency", key = "esp_chams_fill", min = 0, max = 1, default = 0.5, step = 0.05 },
				{ type = "slider", text = "Chams Outline Transparency", key = "esp_chams_outline", min = 0, max = 1, default = 0, step = 0.05 },
				{ type = "toggle", text = "Highlight Chams", key = "vis.highlight_chams" },
			},
		},
	},
	Effects = {
		{
			title = "Cosmetics & World",
			items = {
				{ type = "toggle", text = "China hat", key = "effects.china_hat" },
				{ type = "toggle", text = "Custom wings", key = "effects.wings" },
				{ type = "toggle", text = "Anti-Lag (Clean Debris)", key = "antilag" },
				{ type = "toggle", text = "Remove Fog", key = "effects.remove_fog" },
				{ type = "toggle", text = "Time Override", key = "effects.time_override" },
				{ type = "slider", text = "Time of Day", key = "effects.time_value", min = 0, max = 24, default = 14, step = 0.5 },
			},
		},
		{
			title = "Camera",
			items = {
				{ type = "toggle", text = "Camera FOV (Locked)", key = "effects.fov_lock" },
				{ type = "slider", text = "FOV Value", key = "effects.fov_value", min = 30, max = 120, default = 70, step = 1 },
				{ type = "slider", text = "Max Zoom", key = "effects.max_zoom", min = 10, max = 100, default = 35, step = 1 },
			},
		},
	},
	Settings = {
		{
			title = "Config System",
			items = {
				-- Конфиг система будет добавлена через custom UI (кнопки Save/Load/Delete)
			},
		},
		{
			title = "Friends System",
			items = {
				-- Система друзей будет добавлена через custom UI (список + кнопки Add/Remove)
			},
		},
	},
	Keybinds = {
		{
			title = "Key Bindings",
			items = {
				-- Keybind UI будет добавлен через custom code
			},
		},
	},
}

--// ==================== PASTE MAIN UI CODE FROM MAIN SCRIPT.LUA FROM HERE ====================
--// (Theme, helpers, UI components, wings, china hat, tabs, SUK panel, etc.)
--// I'll add the heal height slider modification marker below:

-- Theme (РєРѕРїРёСЂСѓР№ РёР· main script.lua РЅР°С‡РёРЅР°СЏ СЃ "

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
}

local DESIGN_W, DESIGN_H = 1000, 590

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function round() return new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) end
local function stroke(c, t) return new("UIStroke", { Color = c or Theme.Stroke, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 15
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end
local function tween(o, t, p) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), p):Play() end
local function spaced(t) return (t:upper():gsub("(.)", "%1 "):gsub(" $", "")) end

--// ScreenGui
local gui = new("ScreenGui", { Name = "CLL", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true })
local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local window = new("CanvasGroup", {
	Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Theme.Bg, Parent = gui,
}, { corner(20), stroke() })

--// РђРІС‚РѕРјР°СЃС€С‚Р°Р± РїРѕРґ СЌРєСЂР°РЅ
window.Visible = false -- РѕС‚РєСЂРѕРµС‚СЃСЏ Р°РЅРёРјР°С†РёРµР№ РІ РєРѕРЅС†Рµ С„Р°Р№Р»Р°
local uiScale = new("UIScale", { Parent = window })
local baseScale = 1                                  -- РїРѕРґРіРѕРЅРєР° РїРѕРґ СЌРєСЂР°РЅ
local animFactor = new("NumberValue", { Value = 0 }) -- Р°РЅРёРјР°С†РёСЏ РѕС‚РєСЂС‹С‚РёСЏ/Р·Р°РєСЂС‹С‚РёСЏ (0..1)
local function applyScale() uiScale.Scale = math.max(baseScale * animFactor.Value, 0.001) end
animFactor.Changed:Connect(applyScale)
function fit()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	baseScale = math.clamp(math.min((vs.X - 24) / DESIGN_W, (vs.Y - 24) / DESIGN_H), 0.4, 1)
	applyScale()
end
fit()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

--// Header
local header = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = window })
local logoLabel = label({ Text = "CLL", Font = Enum.Font.Michroma, TextSize = 26, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(340, 62), Position = UDim2.fromOffset(23, 0), Parent = header })
local logoImage = new("ImageLabel", { Name = "LogoImage", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(23, 11), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = header })
logoImage:SetAttribute("NoTheme", true)

--// Drag
do
	local dragging, startPos, startMouse
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startMouse, startPos = true, i.Position, window.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = (i.Position - startMouse)
			window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

local body = new("Frame", { Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 62), BackgroundTransparency = 1, Parent = window })

--// РРєРѕРЅРєРё РІРєР»Р°РґРѕРє (СЂРёСЃСѓСЋС‚СЃСЏ С„СЂРµР№РјР°РјРё, Р±РµР· С€СЂРёС„С‚РѕРІ Рё СЌРјРѕРґР·Рё)
local function makeIcon(parent, build)
	local holder = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = parent })
	local fills, strokes = {}, {}
	local kit = {}
	function kit.bar(w, h, x, y, rot, par)
		local f = new("Frame", { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Rotation = rot or 0, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = par or holder }, { corner(1) })
		table.insert(fills, f)
		return f
	end
	function kit.disc(d, x, y, par)
		local f = new("Frame", { Size = UDim2.fromOffset(d, d), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = par or holder }, { round() })
		table.insert(fills, f)
		return f
	end
	function kit.ring(w, h, x, y, t, par)
		local f = new("Frame", { Size = UDim2.fromOffset(w, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 1, Parent = par or holder }, { round() })
		local s = stroke(Theme.Dim, t or 1.5)
		s.Parent = f
		table.insert(strokes, s)
		return f
	end
	function kit.group(par)
		return new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, 11), BackgroundTransparency = 1, Parent = par or holder })
	end
	local extra = build(kit)
	local function setColor(c)
		for _, f in ipairs(fills) do f.BackgroundColor3 = c end
		for _, s in ipairs(strokes) do s.Color = c end
	end
	return setColor, extra
end

local IconBuilders = {
	Combat = function(k) -- РїСЂРёС†РµР»
		k.ring(14, 14, 11, 11, 1.5)
		k.bar(2, 5, 11, 2.5); k.bar(2, 5, 11, 19.5)
		k.bar(5, 2, 2.5, 11); k.bar(5, 2, 19.5, 11)
		k.disc(3, 11, 11)
	end,
	Movement = function(k) -- РґРІРѕР№РЅРѕР№ С€РµРІСЂРѕРЅ В«РІРїРµСЂС‘РґВ»
		for _, x0 in ipairs({ 6.5, 13.5 }) do
			k.bar(8.5, 2, x0, 8, 45)
			k.bar(8.5, 2, x0, 14, -45)
		end
	end,
	Visual = function(k) -- РіР»Р°Р·
		local eye = k.ring(20, 12, 11, 11, 1.5)
		k.disc(5, 11, 11)
		return eye
	end,
	Effects = function(k) -- искры/звёздочки с длинными лучами
		-- центральная большая искра
		k.bar(8, 2.5, 11, 11, 0)    -- горизонталь (длинная)
		k.bar(8, 2.5, 11, 11, 90)   -- вертикаль (длинная)
		k.bar(6, 2, 11, 11, 45)     -- диагональ \ (средняя)
		k.bar(6, 2, 11, 11, -45)    -- диагональ / (средняя)
		k.disc(2.5, 11, 11)         -- яркое ядро в центре
		
		-- 4 маленькие искры по углам
		local corners = {{5, 5}, {17, 5}, {5, 17}, {17, 17}}
		for _, pos in ipairs(corners) do
			k.bar(4, 2, pos[1], pos[2], 0)     -- горизонталь
			k.bar(4, 2, pos[1], pos[2], 90)    -- вертикаль
			k.disc(1.5, pos[1], pos[2])        -- ядро
		end
	end,
	Settings = function(k) -- три ползунка
		local g = k.group()
		-- (центр Y, центр ручки X, левый отрезок, правый отрезок)
		local rows = {
			{ 5, 8, { 3, 2 }, { 16, 8 } },
			{ 11, 15, { 6.5, 9 }, nil },
			{ 17, 11, { 4.5, 5 }, { 17.5, 5 } },
		}
		for _, r in ipairs(rows) do
			local y, kx, l, rt = r[1], r[2], r[3], r[4]
			if l then k.bar(l[2], 2, l[1], y, 0, g) end
			if rt then k.bar(rt[2], 2, rt[1], y, 0, g) end
			k.disc(5, kx, y, g)
		end
		return g
	end,
	Config = function(k) -- облако для Config System (больше)
		-- основное тело облака - 3 больших круга
		k.disc(8, 6, 12)    -- левый
		k.disc(10, 11, 10)  -- центральный (самый большой)
		k.disc(7, 16, 12)   -- правый
		-- дополнительные маленькие облачка для объёма
		k.disc(4, 8, 8)     -- верх-лево
		k.disc(5, 14, 8)    -- верх-право
	end,
	Keybinds = function(k) -- буква A в рамке
		-- рамка
		k.ring(18, 18, 11, 11, 2)
		-- буква A
		k.bar(2, 10, 9, 11, 20) -- левая часть
		k.bar(2, 10, 13, 11, -20) -- правая часть
		k.bar(5, 1.5, 11, 12, 0) -- перекладина
	end,
	SUK = function(k) -- СЂР°РґР°СЂ: РєРѕР»СЊС†Р°, С†РµРЅС‚СЂ, РІСЂР°С‰Р°СЋС‰РёР№СЃСЏ Р»СѓС‡ Рё В«С†РµР»СЊВ»
		k.ring(19, 19, 11, 11, 1.5)
		k.ring(9, 9, 11, 11, 1)
		k.disc(3, 11, 11)
		local sweep = k.group()
		k.bar(9, 1.5, 15.5, 11, 0, sweep)
		k.disc(3, 16.5, 6.5)
		return sweep
	end,
	Cloud = function(k) -- облако для Config System
		-- основное тело облака - 3 круга
		k.disc(7, 7, 13)   -- левый
		k.disc(8, 11, 11)  -- центральный (больше)
		k.disc(6, 15, 13)  -- правый
		-- нижняя часть - прямоугольник чтобы выровнять низ
		k.bar(10, 4, 11, 15, 0)
	end,
}

local IconB64 = {
	combat = "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",
	movement = "iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAACfklEQVR42u2boa4TQRSGd9uSACkKAwkIJBaBwePxeB7gPgCKIHgArucazM01hGAwBIklKAQCEDWQELi32/thziSbsm262znZM+T/k81s0+ZPz8nM+WZndqpKkiRJkiRJkiRJkiRJKlxADdSl+EZL3LT1eZojYC/fyIm8BMxL8Y3S8ybADHgKfAG+AofA3L6ro/hGTODU2if8q5f23SyKb7jeZ+1l4DvQ2HUOnFqwB32D9fKNnMA5sABWFiTWNnZ/v92rxvKNPoQPLaiz1lBLgS+AW/a7yZi+kSEyB95bgE0r2HT/Abi46zTEyzdqEifWXjdSpl6StLT2RZ+65eUbfSjfWyv668Ee9Eyii2/UJM6sfbQWXCr+y4FQcfGNnsTnHcHuAxUX37DPxHa9ywyV7L6CiqAiqAgqgoqgIqgIKoJKSKjMxvQVVASV3fc+vHxLgMq3LcX/qOf80MU3OlTuAj86lu1X1mtuDFzJzurbpbFrANYuqqpaVVVVb/iPF4L4htwGuAJ82jLUXvfsfS6+EZOXiHncUexTwJ+tltW7BOrlG3ka83jDnK0BfgN3Bk5jsvpGTd6DVpBdTw0PB06ks/pGpe5t4OcaHdtBPhv4KJfVNzI0Pm6Z5L5JQfbcO87qWwI0lhuK+9U9obG37/8AjemYvoKGoCFoCBqChqAhaAgagkb/U0S2VJ4bGtl9I+9xnGSGRnbfEs6JnGWChotv9HMiqw0rwH2h4eJbwjmRplXkT4cWdy/fUs6JnLco+XZocffyjX5O5Aj4BfwBXgHXhhZ3L98SEnozvT7RHo5RfcP1xNwnzL18Q7+24TG0vHwlSZIkSZIkSZIkSZKkUvQX+Ov4lyLpvzIAAAAASUVORK5CYII=",
	visual = "iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAAIlUlEQVR42u2bXYyUVxnH/2dmFmQrplBSFqEFxAoCoSEYqrEWRCVopPWi0Ss1MaS9MLESTRrbq6Y13jR+kKaJXqkxNmowpNqatJYYtRKlahvdWioFkkboEru2QBF2Z+bnxT4neTyed3ZmmN0ueP7Jm/l655zn/M/zdZ5zXqmgoKCgoKCgoKCgoKCgoKCgoKCgoKArhLkgBBCcPLVpbm9LQpJCCPxfEmiERbIIIbT6bKdu7bStHa5oAoGapFoIoZkhdETStZI2SFooabGkC5KGJNUljUs6K2lU0mlJr6SEAQ1J7RBC+4oi0DRFUdOAtxhZN0u6VdKNkpYbcd3grKSTkp6V9JikQ5JeDiFczPV32RJoGqeoEcAWSbslfUbSUknDmb+1oo+rkLee+f6iEfp9ST8LIfzR9R9mg8iBExfJs8/bgR8Abf4bTbta7moCkxVX7t5m0mbb+truXYSXZy4TFxLiPgw8lQxw0gbfttfJDAndwP/Xt+XxFPCRZGLDnDRhoO583BZJ90v6aPzZImXdXtuSGkkTE5L+Kem4pJfNLD3mS7pO0mpJSyTNS35vWlSvmRuoufE9LemeEMKvU1nnlNYBy4EDiTk1ncY0E/N9HvgucCuwGriqi/6usnt3AQ8DTwMTSbst17d3GweA5TOljX1HV3u/FxhPBpIj7gXgfmCj/38yIXWgAQzZ1bDvQoUcG6zNFzJEkhA5DuzNjWG2yWvY6zLgiS6I+xOwJ9UyI6YeA08kqyIwNdy99ZRU08491lcVkRFPAMv8WGbTZOv2fhdwxAWHdkbQo8DngSFPvjch32ZC2CK7hjKkh5Rc93kIuB14LjOxbRdsjgC7Zs2k48zb+7uSyBqFiyQeB+4EhhPiQsU6WMC1wB3AfjPHV+16CXgM+CKwMs0zk8n1RM4DvmCypPL5iH1nVZsz5e8edGbayszww8DVVRqTCmvE3guMdZG+vG79L6zyYalGA1ebTO2Mm4ny/yhO9sD9ovN3I8AvM445zuYYsLOTxmXIWwb8NtHmNGH2CXbEKLCh04AzGrnTTdJkxoIOASMD9YuOvBtM6NRk4/vfAKumI877G5uQv9r/J5yJTSbph/+u7dKWk8D66UzPEwmschPm+5lwE3PDQEh0nW4ETmXIi6bwdadR9W6CkDn6Q4nw6VLvjJlsugLxchwzE502CDj/3TCTrmrzFLDxkkh05G1z+V0z6RDgnl7Wm24QX0nIi21eAPYBNwNLLApvBR4A/pXcG//7nW59VxL9Pw2cS8bWdPnitr5IdIPcBLxW0cFZYHenIFFVeTZixpM1cTTJm9z984EF7vNaZ/J+tTEJrO02iiYmvd3Gkhvja8Cmnkh05N3kzCen4pt7nR0n9B2JD2oB54H3OKJ+Yv2MAY9HYoHrgdOJvwT4Wh/yDNnr5oyLarmov72rtp0fG7HcKzcrR5zjHupTsw+4wUeB99lv60wTU5wD3m/3fCmp7AA8k+aVPU7qercoSF3VG8CNHTXc1DoAi52ZpA0902+Yd+ZbB/6emCHAe63/nzpfGLXson132O65zn5PNeWaSyRxxMZIJr89aUWMvK93jdyVce5t4PfRH/WTaDoCF7mg1HLRdjGwIDFPkhXEJLDSAsGxzLJxbb+rCWcdC2ys7Uyw+maqPLmOFrwJ2wi4Gl6nyalZHTHeP1tbFEzLjUtuVzgfNBMm3HBrU2/Cm63/J+3zRadZUQOeNxew1PySl+0ssHQGTLjlfPCmjumaCyLrO6QvfwPW9UlibP8XSQoC8ID9ttXlZili2rQnU6r6i/PjoQ/y1tnYcmN+xWUItW59wbZp0phNvUZiJ+zeJI1pm198h/3+AeB3FigmgGeB21xh4HhmH+Rbl5BWbZomjXlfr7lgo4tE2udHQ10m0lEDV5gJpon0aCTR7luZfF4C/CoTJdu2D9PtaiS4HHC7U5RLT6QrlnJVHbwB3O7ToB6i3YMVS7kx4MsJcSss+T6a9B+1ZX+P5EV//AnnS3MKsm1Q6+FOKo6ta3spJtSAhUk1O23zgpnqUTfIXH72qhFcm84/ucmrJQXhTi5qYBUZ72RzFZkngUXdlrPs9d0u4k9k2qRib2PSWcAtPZazFrlI38rUNPsOkt2G+YMdCpInkoJqvQttWO9WJn55lrt8/W7M+eBp+3EF1RMZ+ePkPTfwgmqFID/ssOPVBh5yq5bQoaQfSVwMfDvJ/Trhx8D1VQN1fdbc6uKhTEnfB7CDwNtmdKvT+xngvowGepN4EfhUqsmZTSV/FGQj8FVbSo27FOd1S2W+AWyt0vC0hG/ffdJkSQnzGngvMH9GN5UqTiLcZmvXqj2SWOr/WG5bs2oTyL67xspaa+MKo+qMS8W25g4rg9HBb5+OyXk/K5hB+cU1HTbWfUHgMPC5pECa2yzvtBGVu9dPxALr43BSiKjaWF/TSx47G0c7zmSEbiXpyaiZzOoObiIe65hn11BKVvKf1dbmaJKa5LYvz8yJox0VfnEN8GhmEO3MUY/zZmL3AR+yXG64i/6G7d4PAndbG+c7HC7yk/eo07raIPzdTB1vu0XSPk0d3c0dbyNTtjqvqXPQRzV12vScpBNWvloh6a2S3i7pnZo6Pz2cOdkaKo63vSTp7hDC/jl3vK2DNjaA3S5vzB2wbCZl+UEfsDxoR+eGB6l1s3Ua33/eATyS2fedHMAR39wm/CPAjip/fVkcMreoFp8D8YfMPyvp45JWZfrHP0hTIW+tQu7jkn4u6XvpIXN79IEr6TGH+ZLWS9opaYukzebfhrts8t+S/iHpmKQ/SHpc0p9DCBeuqMccKkz7fx47sJxyRNIySe/S1PMiSy1YNDT1YM2Ypp4PeVHSKU09aNPMTBRX3IM2M/ioVzxUzkya6eXysKG/ptsh4816Nq6goKCgoKCgoKCgoKCgoKCgoKCgoKBP/Af3BbXfPCAUWwAAAABJRU5ErkJggg==",
	radar = "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",
	sweep = "iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAACXklEQVR42u2aTW4TQRCFX/X02AEnKAErXIAb5BxInItzcAPWrDhHxAnIxqyAzGNTDaVWjxlLlpMZv08q9Ywtz8/zq6r2tAEhhBBCCCGEEEIIIYQQIkIykeyOfVw7F/H8XpO/9NvMeIxjpzMQz1y8EhnAhb8uASeIF92XgoibY4i4dAfW4kURVwA2EnBa3SvRhYC78KUEbIsXBSyiRTGzv39NMkvAdt2rhSv7OWz3ALYScL943Uhkf/8VyatwjLN1YNojWA5jHR2AW5J26PwwLbDutYQr0XvkMP51IYCbQ12YFyReq761HJhGGksH4C2Ah0NcmBdU9+o0/Z+g5TNxqnND8srMdmchoIvXNepZq8alhgtT2DcAa3fhbmo9zAtoGrlR08p+K31bc8LYuW9J3k9N4zxj93WhKYw1h33pm0ZEvAZwOdWFecZNI/vv2T6M/R4BU6Np1A8ZShpvAewW6UCveyuPdRhrAbuGgHXNq8ci4BsA32YvYHggENNoDeAixLpyYCt1a/e1nFfmxCsAWz/3fJsIyWRmw57O24/UwDzivNQQrXlqAGszG6ZMqJ+tgH4Dd+6w7y7QpccLd9+q8YuiNcerXVY/pUa1/Y7kg5l9LV/asZYATpW2IPmR/xh4OuK5PpHsyzXNSbw7v4FHj1MzkPzl2x/CtOnZp7CFRgEAQzWekseyADWrFUxfv82ePk/NF5IbvyabxbpwLNgk3wN4feJrLc3iB4DPZvZzVk3kmU7c5/fPhOrx/JNcAoBBzhNCCCGEEEIIIYQQQgghhBBCCCGEEEIIIYQQYlb8AVTSXUllWvRBAAAAAElFTkSuQmCC",
	fps = "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",
	ping = "iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAACKklEQVR42u2cwU4UQRRFzys6GEM0sED2/gh8BX6AifovrvkAExeEFVs27GFB2LDiHzBq1AQzc11YJMYwZGzG7q6qe5NZTDJ5mZx5r6vqzEyD4ziO4zj9IylMoR+49NfzNVPp0XWSNvt2Y7QKLyIkaQ94A+wAn4CPEXEsKUXE3G32wNhK2pV0JelS0rmkC0nXkvbvG+9FSW0yVALeAj+Br8AM+AF8Bl5L2oiI+TLjnFocXWADeAHcAl2+lK1loJvA9rKXuNTwNM/vARSA8gOP8AALaMsAMUADNEADNAIDNEADbNjlpdKlQD6ajebyUsFn2vmfLi8iZmN0Y1eDy5M0msvrShvbrJl2gQN+25NbYAt4L2k9Io6GhJhadnlNAfwfLq/lVXglLq9lgOGNtE8ijgEaoAEaoAE65QKs4Xd5qWWXVyTAKbk8StNZU3N5RQGcossrbYQn5/KKAThVl1fqKjwZl1cqwPBG2jFAAzRAA3QM0ADLBej/2PYEWJPLGxxgbS6PIXVWjS5vMIC1urwhR7hKlzcIwJpd3hircFUubwyA3vv5JGKABmiAjgEaoAG2CXAVm+WaavwTwMiv14I3Eo3VWA5gVlgBfMvioMtHurujXQK+AzeLPtmaavTtwBQRM+AD8Ax4kot3WSIcRsSXrLPUQI3+34FIeiXpRNKZpFNJ7ySlZe63V1ONx0J8KumlpOct11jVjVtTyzXiEZ0YgPpeJ2qq4ThOsfkFJ8VxZy0pyd4AAAAASUVORK5CYII=",
}

-- base64 -> СЃС‚СЂРѕРєР° Р±Р°Р№С‚
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64Lookup = {}
for i = 1, 64 do B64Lookup[B64:byte(i)] = i - 1 end
local function b64decode(data)
	local out = {}
	for i = 1, #data, 4 do
		local a, b, c, d = data:byte(i, i + 3)
		local n = (B64Lookup[a] or 0) * 262144 + (B64Lookup[b] or 0) * 4096 + (B64Lookup[c] or 0) * 64 + (B64Lookup[d] or 0)
		local b1, b2, b3 = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
		if c == 61 then
			out[#out + 1] = string.char(b1)
		elseif d == 61 then
			out[#out + 1] = string.char(b1, b2)
		else
			out[#out + 1] = string.char(b1, b2, b3)
		end
	end
	return table.concat(out)
end

-- PNG-РёРєРѕРЅРєРё С‡РµСЂРµР· getcustomasset (РµСЃР»Рё РёРЅР¶РµРєС‚РѕСЂ РїРѕРґРґРµСЂР¶РёРІР°РµС‚), РёРЅР°С‡Рµ СЂРёСЃСѓРµРј С„СЂРµР№РјР°РјРё
local IconAssets = {}
do
	local wf = writefile
	local gca = getcustomasset or getsynasset
	if wf and gca then
		for name, data in pairs(IconB64) do
			local okI, asset = pcall(function()
				local path = "cll_icon_" .. name .. ".png"
				wf(path, b64decode(data))
				return gca(path)
			end)
			if okI and asset then IconAssets[name] = asset end
		end
	end
end

local function makeImageIcon(parent, baseAsset, sweepAsset)
	local imgs = {}
	local function layer(asset)
		local img = new("ImageLabel", {
			Image = asset, Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1, ImageColor3 = Theme.Dim, Parent = parent,
		})
		table.insert(imgs, img)
		return img
	end
	layer(baseAsset)
	local sweep = sweepAsset and layer(sweepAsset) or nil
	local function setColor(c)
		for _, im in ipairs(imgs) do im.ImageColor3 = c end
	end
	return setColor, sweep
end

--// Р’РєР»Р°РґРєРё
local TAB_ORDER = { "Combat", "Movement", "Visual", "Effects", "Config", "Keybinds", "SUK" }
local TAB_COUNT = #TAB_ORDER
local TAB_WIDTH = math.min(TAB_COUNT * 50, 350) -- динамический размер: до 6 табов или max 350px
local tabBar = new("Frame", {
	Size = UDim2.fromOffset(TAB_WIDTH, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 31),
	BackgroundColor3 = Theme.Row, Parent = header,
}, { corner(13), stroke() })

local pages, tabs = {}, {}
local currentTab
local radarSweep

local switchTweens = {}
local switchToken = 0
local function selectTab(name, instant)
	local prev = currentTab
	currentTab = name
	for n, t in pairs(tabs) do
		local active = n == name
		tween(t.btn, 0.15, { BackgroundTransparency = active and 0 or 1 }) -- неактивные табы полностью прозрачны
		t.setColor(active and Theme.Knob or Theme.Dim)
	end

	-- РѕСЃС‚Р°РЅРѕРІРёС‚СЊ РїСЂРѕС€Р»СѓСЋ Р°РЅРёРјР°С†РёСЋ РїРµСЂРµРєР»СЋС‡РµРЅРёСЏ
	for _, t in ipairs(switchTweens) do t:Cancel() end
	table.clear(switchTweens)
	switchToken += 1
	local token = switchToken

	if instant or not prev or prev == name then
		for n, pg in pairs(pages) do
			pg.Visible = (n == name)
			pg.GroupTransparency = 0
			pg.Position = UDim2.fromOffset(0, 0)
		end
		if prev ~= name then Callbacks.OnTab(name) end
		return
	end

	for n, pg in pairs(pages) do
		if n ~= prev and n ~= name then pg.Visible = false end
	end
	local oldPg, newPg = pages[prev], pages[name]

	local function showNew()
		if token ~= switchToken then return end
		oldPg.Visible = false
		newPg.Position = UDim2.fromOffset(0, 14)
		newPg.GroupTransparency = 1
		newPg.Visible = true
		local t = TweenService:Create(newPg, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0, Position = UDim2.fromOffset(0, 0),
		})
		table.insert(switchTweens, t)
		t:Play()
	end

	if oldPg.Visible then
		local t = TweenService:Create(oldPg, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
		table.insert(switchTweens, t)
		t.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed then showNew() end
		end)
		t:Play()
	else
		showNew()
	end
	Callbacks.OnTab(name)
end

for idx, name in ipairs(TAB_ORDER) do
	local btn = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(44, 36), Position = UDim2.fromOffset(6 + (idx - 1) * 48, 4),
		BackgroundColor3 = Theme.TabOn, BackgroundTransparency = 1, Parent = tabBar,
	}, { corner(10) })
	local setColor, extra
	local assetKey = (name == "SUK") and "radar" or name:lower()
	if IconAssets[assetKey] then
		setColor, extra = makeImageIcon(btn, IconAssets[assetKey], name == "SUK" and IconAssets.sweep or nil)
	else
		setColor, extra = makeIcon(btn, IconBuilders[name])
	end
	if name == "SUK" then radarSweep = extra end
	tabs[name] = { btn = btn, setColor = setColor }
	pages[name] = new("CanvasGroup", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = body })
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	btn.MouseEnter:Connect(function() if currentTab ~= name then setColor(Theme.Dim:Lerp(Theme.Text, 0.6)) end end)
	btn.MouseLeave:Connect(function() if currentTab ~= name then setColor(Theme.Dim) end end)
end

-- СЂР°РґР°СЂ РєСЂСѓС‚РёС‚СЃСЏ
do
	local conn = RunService.RenderStepped:Connect(function()
		if radarSweep then radarSweep.Rotation = (os.clock() * 120) % 360 end
	end)
	gui.Destroying:Connect(function() conn:Disconnect() end)
end

--// РљРѕРјРїРѕРЅРµРЅС‚С‹ (РІСЃРµ Y вЂ” СЌС‚Рѕ Р¦Р•РќРўР  СЌР»РµРјРµРЅС‚Р°)
local PAD = 20
local function divider(parent, y)
	return new("Frame", { Size = UDim2.new(1, -PAD * 2, 0, 1), Position = UDim2.fromOffset(PAD, y), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = parent })
end

local function toggle(parent, cy, text, cb, initial, onRight)
	if text ~= "" then
		label({ Text = text, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(PAD, cy - 12), Parent = parent })
	end
	local state = initial and true or false
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -PAD - 40 + 2, 0, cy - 11), BackgroundColor3 = Theme.Off, Parent = parent }, { corner(11), stroke() })
	local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme.Bg, Parent = sw }, { corner(8) })
	local function render()
		tween(knob, 0.15, { Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) })
		tween(knob, 0.15, { BackgroundColor3 = state and Theme.Knob or Theme.Bg })
		tween(sw, 0.15, { BackgroundColor3 = state and Theme.OnTrack or Theme.Off })
	end
	sw.MouseButton1Click:Connect(function() state = not state; render(); cb(state) end)
	if onRight then
		label({ Text = "Right click for settings", TextSize = 12, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(200, 24), Position = UDim2.new(1, -PAD - 40 - 12 - 200 + 2, 0, cy - 12), Parent = parent })
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, -PAD * 2 - 60, 0, 28), Position = UDim2.fromOffset(PAD, cy - 14), Parent = parent })
		hit.MouseButton2Click:Connect(onRight)
		sw.MouseButton2Click:Connect(onRight)
	end
	render()
	return function(v) state = v and true or false; render() end
end

local function slider(parent, cy, text, min, max, default, step, cb)
	local W = parent.Size.X.Offset
	local trackW = W - PAD * 2 - 64
	label({ Text = text, Size = UDim2.new(1, -PAD * 2, 0, 22), Position = UDim2.fromOffset(PAD, cy - 11), Parent = parent })
	local ty = cy + 28
	local valueLbl = label({ Text = tostring(default), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(60, 22), Position = UDim2.new(1, -PAD - 60 - 4, 0, ty - 11), Parent = parent })
	local track = new("Frame", { Size = UDim2.fromOffset(trackW, 4), Position = UDim2.fromOffset(PAD, ty - 2), BackgroundColor3 = Theme.Off, BorderSizePixel = 0, Parent = parent }, { corner(2) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Knob, BorderSizePixel = 0, Parent = track }, { corner(2) })
	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Theme.Knob, Parent = track }, { corner(7) })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = track })

	-- РїР»Р°РІРЅРѕСЃС‚СЊ: РїРѕР»Р·СѓРЅРѕРє РµРґРµС‚ Рє С†РµР»Рё РїРѕ СЌРєСЃРїРѕРЅРµРЅС‚Рµ, Р·РЅР°С‡РµРЅРёРµ РїСЂРё СЌС‚РѕРј РґРёСЃРєСЂРµС‚РЅРѕРµ
	local targetA, curA, lastV = 0, 0, nil
	local function render(a)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
	end
	local conn = RunService.RenderStepped:Connect(function(dt)
		if curA ~= targetA then
			if math.abs(targetA - curA) < 0.0005 then
				curA = targetA
			else
				curA += (targetA - curA) * math.min(1, dt * 22)
			end
			render(curA)
		end
	end)
	gui.Destroying:Connect(function() conn:Disconnect() end)

	local function set(alpha, fire, instant)
		alpha = math.clamp(alpha, 0, 1)
		local v = math.clamp(math.round((min + (max - min) * alpha) / step) * step, min, max)
		targetA = alpha
		if instant then curA = alpha; render(alpha) end
		valueLbl.Text = tostring(v)
		if fire and v ~= lastV then lastV = v; cb(v) end
	end
	local dragging = false
	local function fromInput(i)
		set((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, true)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromInput(i) end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	lastV = default
	set((default - min) / (max - min), false, true)
	return function(v)
		lastV = math.clamp(v, min, max)
		set((v - min) / (max - min), false)
	end
end

local function makePanel(parent, x, w)
	return new("Frame", { Size = UDim2.fromOffset(w, 511), Position = UDim2.fromOffset(x, 2), BackgroundColor3 = Theme.Panel, Parent = parent }, { corner(16), stroke() })
end

--// РљР»РёРµРЅС‚СЃРєРёРµ 3D-СѓРєСЂР°С€РµРЅРёСЏ (РІРёРґРёС€СЊ С‚РѕР»СЊРєРѕ С‚С‹): РѕР±С‰РёРµ РїРѕРјРѕС‰РЅРёРєРё
local function cosmeticColor()
	-- Graphite -> С‚С‘РјРЅС‹Р№, Snow -> Р±РµР»С‹Р№, РѕСЃС‚Р°Р»СЊРЅС‹Рµ С‚РµРјС‹ (Рё СЃРІРѕР№ Р°РєС†РµРЅС‚) -> С†РІРµС‚ Р°РєС†РµРЅС‚Р°
	if Theme.Bg == Color3.fromRGB(13, 13, 14) and Theme.Knob == Color3.fromRGB(245, 245, 248) then return Color3.fromRGB(26, 26, 30) end
	if Theme.Bg == Color3.fromRGB(244, 244, 246) and Theme.Knob == Color3.fromRGB(40, 40, 46) then return Color3.fromRGB(250, 250, 252) end
	return Theme.Knob
end

local function mkWedge(parent, parts, transparency)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = false, false, false, false
	w.Material = Enum.Material.SmoothPlastic
	w.Transparency = transparency
	w.Parent = parent
	parts[#parts + 1] = w
	return w
end

-- С‚СЂРµСѓРіРѕР»СЊРЅРёРє РёР· РґРІСѓС… РєР»РёРЅСЊРµРІ
local function mkTriangle(a, b, c, parent, parts, transparency, thick)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1, w2 = mkWedge(parent, parts, transparency), mkWedge(parent, parts, transparency)
	w1.Size = Vector3.new(thick, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(thick, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

--// China hat: РїРѕР»Р°СЏ В«РєСЂС‹С€Р°В» РёР· С‚СЂРµСѓРіРѕР»СЊРЅРёРєРѕРІ, Р±РµР· РґРЅР°
local ChinaHat = {}
do
	local HAT_ALL = false              -- true = С€Р»СЏРїР° Рё РЅР° РґСЂСѓРіРёС… РёРіСЂРѕРєР°С… (РІСЃС‘ СЂР°РІРЅРѕ РІРёРґРёС€СЊ С‚РѕР»СЊРєРѕ С‚С‹)
	local HAT_TRANSPARENCY = 0.35
	local HAT_RADIUS, HAT_HEIGHT = 1.6, 0.9
	local HAT_LIFT = -0.05             -- РІС‹СЃРѕС‚Р° РѕСЃРЅРѕРІР°РЅРёСЏ РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ РјР°РєСѓС€РєРё (РјРµРЅСЊС€Рµ = РіР»СѓР±Р¶Рµ СЃРёРґРёС‚)
	local SEGMENTS = 28                -- РіР»Р°РґРєРѕСЃС‚СЊ РєРѕРЅСѓСЃР°
	local THICK = 0.03                 -- С‚РѕР»С‰РёРЅР° В«РєСЂС‹С€РёВ»

	local enabled = false
	local hats = {}

	local function destroyHat(plr)
		local h = hats[plr]
		if h then h.model:Destroy(); hats[plr] = nil end
	end

	local function buildHat(plr, head)
		destroyHat(plr)
		if not head or not head.Parent then return nil end
		local offset = CFrame.new(0, head.Size.Y / 2 + HAT_LIFT, 0)
		local pivot = head.CFrame * offset
		local model = Instance.new("Model")
		model.Name = "ChinaHat"
		local parts = {}
		local apex = pivot * Vector3.new(0, HAT_HEIGHT, 0)
		local ring = {}
		for i = 0, SEGMENTS do
			local ang = i / SEGMENTS * math.pi * 2
			ring[i] = pivot * Vector3.new(math.cos(ang) * HAT_RADIUS, 0, math.sin(ang) * HAT_RADIUS)
		end
		for i = 0, SEGMENTS - 1 do mkTriangle(apex, ring[i], ring[i + 1], model, parts, HAT_TRANSPARENCY, THICK) end
		model.WorldPivot = pivot
		local h = { model = model, parts = parts, head = head, offset = offset, color = nil }
		hats[plr] = h
		return h
	end

	local function wanted(plr) return plr == LocalPlayer or HAT_ALL end

	-- РєР°Р¶РґС‹Р№ РєР°РґСЂ: РїРµСЂРµСЃРѕР±РёСЂР°РµРј С€Р»СЏРїСѓ, РµСЃР»Рё СЃРјРµРЅРёР»Р°СЃСЊ РіРѕР»РѕРІР° (СЂРµСЃРїР°РІРЅ), Рё РґРІРёРіР°РµРј Р·Р° РіРѕР»РѕРІРѕР№
	local conn = RunService.RenderStepped:Connect(function()
		if not enabled then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local color = cosmeticColor()
		for _, plr in ipairs(Players:GetPlayers()) do
			if wanted(plr) then
				local head = plr.Character and plr.Character:FindFirstChild("Head")
				if not head then
					destroyHat(plr)
				else
					local h = hats[plr]
					if not h or h.head ~= head then h = buildHat(plr, head) end
					if h and head.Parent then
						h.model:PivotTo(head.CFrame * h.offset)
						if h.color ~= color then
							h.color = color
							for _, p in ipairs(h.parts) do p.Color = color end
						end
					end
					-- РѕС‚ РїРµСЂРІРѕРіРѕ Р»РёС†Р° С€Р»СЏРїР° РЅР° СЃРІРѕРµР№ РіРѕР»РѕРІРµ РЅРµ Р·Р°РєСЂС‹РІР°РµС‚ РѕР±Р·РѕСЂ
					local show = plr ~= LocalPlayer or (cam.CFrame.Position - head.Position).Magnitude > 2
					local want = show and cam or nil
					if h.model.Parent ~= want then h.model.Parent = want end
				end
			elseif hats[plr] then
				destroyHat(plr)
			end
		end
	end)
	Players.PlayerRemoving:Connect(destroyHat)
	gui.Destroying:Connect(function()
		conn:Disconnect()
		for plr in pairs(hats) do destroyHat(plr) end
	end)

	function ChinaHat.set(state)
		enabled = state
		if not state then
			for plr in pairs(hats) do destroyHat(plr) end
		end
	end
end

--// Custom wings: Normal (РєСЂС‹Р»СЊСЏ РёР· С‚СЂРµСѓРіРѕР»СЊРЅРёРєРѕРІ С†РІРµС‚Р° С‚РµРјС‹) Рё Bacon (РїРѕ 3 РјРёРЅРё-Bacon-СЃРєРёРЅР° РЅР° РєР°Р¶РґРѕРµ РєСЂС‹Р»Рѕ)
local Wings = {}
local WingsUI = { toggle = function() end }
do
	local WING_TRANSPARENCY = 0.35
	local WING_THICK = 0.03
	local BACON_SCALE = 0.6            -- СЂР°Р·РјРµСЂ РјРёРЅРё-Bacon
	local BACON_ANGLES = { 55, 15, -25 } -- 3 СЃРєРёРЅР° РЅР° РєР°Р¶РґРѕРµ РєСЂС‹Р»Рѕ: СѓРіР»С‹ РІРµРµСЂР° РІ РіСЂР°РґСѓСЃР°С… (СЃРІРµСЂС…Сѓ РІРЅРёР·)
	local BACON_RADIUS = 2.4           -- СЂР°СЃСЃС‚РѕСЏРЅРёРµ РѕС‚ РїР»РµС‡Р° РґРѕ С†РµРЅС‚СЂР° РєР°Р¶РґРѕРіРѕ СЃРєРёРЅР°
	local WING_Y, WING_YAW = 0.35, 0.45 -- РІС‹СЃРѕС‚Р° РєСЂРµРїР»РµРЅРёСЏ РЅР° СЃРїРёРЅРµ Рё СЂР°Р·РІРѕСЂРѕС‚ РєСЂС‹Р»Р° РЅР°Р·Р°Рґ

	local enabled = false
	local wingType = "Normal"
	local state
	local phase, speed, amp = 0, 2.4, 0.16

	-- РєРѕРЅС‚СѓСЂ РєСЂС‹Р»Р° (РїСЂР°РІРѕРµ), С‚РѕС‡РєР° (0,0) вЂ” РїР»РµС‡Рѕ; Р»РµРІРѕРµ РїРѕР»СѓС‡Р°РµС‚СЃСЏ Р·РµСЂРєР°Р»РѕРј
	local WING_PTS = (function()
		local pts = { Vector2.new(1.8, 1.5), Vector2.new(3.8, 2.4), Vector2.new(6.2, 1.6) }
		local F = { Vector2.new(5.6, 0.4), Vector2.new(4.8, -0.5), Vector2.new(3.8, -1.2), Vector2.new(2.6, -1.6), Vector2.new(1.4, -1.5) }
		local prev = pts[3]
		for _, f in ipairs(F) do
			pts[#pts + 1] = (prev + f) / 2 * 0.8 -- РІС‹РµРјРєР° РјРµР¶РґСѓ В«РїРµСЂСЊСЏРјРёВ»
			pts[#pts + 1] = f
			prev = f
		end
		return pts
	end)()

	local function buildNormal(side)
		local items = {}
		for i = 1, #WING_PTS - 1 do
			local p1 = Vector3.new(side * WING_PTS[i].X, WING_PTS[i].Y, 0)
			local p2 = Vector3.new(side * WING_PTS[i + 1].X, WING_PTS[i + 1].Y, 0)
			local model = Instance.new("Model")
			model.Name = "WingFeather"
			local parts = {}
			mkTriangle(Vector3.zero, p1, p2, model, parts, WING_TRANSPARENCY, WING_THICK)
			model.WorldPivot = CFrame.new()
			items[#items + 1] = { model = model, parts = parts, k = i }
		end
		return items
	end

	-- РјРёРЅРё-Bacon: Р±Р»РµРґРЅР°СЏ РєРѕР¶Р°, С‡С‘СЂРЅР°СЏ РєСѓСЂС‚РєР° РЅР° СЃРёРЅРµР№ С„СѓС‚Р±РѕР»РєРµ, С‚С‘РјРЅС‹Рµ РґР¶РёРЅСЃС‹, Р±РµР»С‹Рµ РєСЂРѕСЃСЃРѕРІРєРё, РїСЂРёС‡С‘СЃРєР° Bacon
	local C_SKIN, C_SHIRT, C_JACKET = Color3.fromRGB(238, 222, 150), Color3.fromRGB(28, 142, 196), Color3.fromRGB(24, 24, 26)
	local C_JEANS, C_SHOE, C_HAIR, C_FACE = Color3.fromRGB(34, 50, 44), Color3.fromRGB(240, 240, 242), Color3.fromRGB(140, 82, 36), Color3.fromRGB(45, 45, 50)
	local function buildFigure()
		local model = Instance.new("Model")
		model.Name = "WingBacon"
		local sc = BACON_SCALE
		local function part(size, pos, color)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Material = Enum.Material.Plastic
			p.Color = color
			p.Size = size * sc
			p.CFrame = CFrame.new(pos * sc)
			p.Parent = model
			return p
		end
		-- С‚РѕСЂСЃ: С„СѓС‚Р±РѕР»РєР° + СЂР°СЃРїР°С…РЅСѓС‚Р°СЏ РєСѓСЂС‚РєР°
		part(Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), C_SHIRT)
		part(Vector3.new(0.6, 2.05, 1.05), Vector3.new(-0.7, 0, 0), C_JACKET)
		part(Vector3.new(0.6, 2.05, 1.05), Vector3.new(0.7, 0, 0), C_JACKET)
		part(Vector3.new(0.6, 0.6, 0.1), Vector3.new(0, 0.2, -0.54), C_FACE) -- РїСЂРёРЅС‚ РЅР° С„СѓС‚Р±РѕР»РєРµ
		-- СЂСѓРєРё: РєРѕР¶Р° + С‡С‘СЂРЅС‹Рµ СЂСѓРєР°РІР°
		for _, x in ipairs({ -1.5, 1.5 }) do
			part(Vector3.new(1, 2, 1), Vector3.new(x, 0, 0), C_SKIN)
			part(Vector3.new(1.05, 1.5, 1.05), Vector3.new(x, 0.25, 0), C_JACKET)
		end
		-- РЅРѕРіРё: РґР¶РёРЅСЃС‹ + Р±РµР»С‹Рµ РєСЂРѕСЃСЃРѕРІРєРё
		for _, x in ipairs({ -0.5, 0.5 }) do
			part(Vector3.new(1, 2, 1), Vector3.new(x, -2, 0), C_JEANS)
			part(Vector3.new(1.05, 0.4, 1.15), Vector3.new(x, -2.8, -0.05), C_SHOE)
		end
		-- РіРѕР»РѕРІР°
		local head = part(Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), C_SKIN)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = head
		-- РЅРµР№С‚СЂР°Р»СЊРЅРѕРµ Р»РёС†Рѕ
		part(Vector3.new(0.2, 0.3, 0.1), Vector3.new(-0.3, 1.6, -0.66), C_FACE)
		part(Vector3.new(0.2, 0.3, 0.1), Vector3.new(0.3, 1.6, -0.66), C_FACE)
		part(Vector3.new(0.45, 0.1, 0.1), Vector3.new(0, 1.25, -0.66), C_FACE)
		-- РїСЂРёС‡С‘СЃРєР° Bacon
		part(Vector3.new(1.45, 0.5, 1.45), Vector3.new(0, 2.2, 0), C_HAIR)
		part(Vector3.new(1.45, 1, 0.45), Vector3.new(0, 1.8, 0.55), C_HAIR)
		part(Vector3.new(1.3, 0.35, 0.3), Vector3.new(0.1, 2.0, -0.6), C_HAIR)
		part(Vector3.new(0.3, 0.8, 1.2), Vector3.new(-0.72, 1.85, 0), C_HAIR)
		part(Vector3.new(0.3, 0.8, 1.2), Vector3.new(0.72, 1.85, 0), C_HAIR)
		model.WorldPivot = CFrame.new()
		return model
	end

	local function buildBacon()
		local items = {}
		for j, deg in ipairs(BACON_ANGLES) do
			items[#items + 1] = {
				model = buildFigure(), a = math.rad(deg), r = BACON_RADIUS,
				z = (#BACON_ANGLES - j) * 0.1 + 0.3,
				ph = j * 0.9, -- СЃРґРІРёРі С„Р°Р·С‹ РґР»СЏ РІРѕР»РЅС‹
			}
		end
		return items
	end

	local function destroyWings()
		if not state then return end
		for _, w in ipairs(state.wings) do
			for _, it in ipairs(w.items) do it.model:Destroy() end
		end
		state = nil
	end

	local function build(torso)
		destroyWings()
		if not torso or not torso.Parent then return end
		state = { torso = torso, kind = wingType, color = nil, wings = {} }
		for _, side in ipairs({ 1, -1 }) do
			state.wings[#state.wings + 1] = { s = side, items = wingType == "Bacon" and buildBacon() or buildNormal(side) }
		end
	end

	local conn = RunService.RenderStepped:Connect(function(dt)
		if not enabled then return end
		local cam = workspace.CurrentCamera
		local char = LocalPlayer.Character
		local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
		if not (cam and torso) then destroyWings(); return end
		if not state or state.torso ~= torso or state.kind ~= wingType then build(torso) end

		-- Р°РЅРёРјР°С†РёСЏ: РІ РІРѕР·РґСѓС…Рµ РјР°С€СѓС‚ Р±С‹СЃС‚СЂРµРµ Рё С€РёСЂРµ
		local hum = char:FindFirstChildOfClass("Humanoid")
		local air = hum and hum.FloorMaterial == Enum.Material.Air
		local k = math.min(1, dt * 6)
		speed += ((air and 9 or 2.4) - speed) * k
		amp += ((air and 0.5 or 0.16) - amp) * k
		phase += dt * speed
		local flap = 0.28 + amp * math.sin(phase)

		local head = char:FindFirstChild("Head")
		local show = not head or (cam.CFrame.Position - head.Position).Magnitude > 2
		local want = show and cam or nil
		local color = cosmeticColor()

		for _, w in ipairs(state.wings) do
			local s = w.s
			if not state.torso or not state.torso.Parent then break end
			local base = state.torso.CFrame * CFrame.new(s * 0.35, WING_Y, state.torso.Size.Z / 2 + 0.1) * CFrame.Angles(0, -s * WING_YAW, 0) * CFrame.Angles(0, 0, s * flap)
			for _, it in ipairs(w.items) do
				if state.kind == "Normal" then
					-- РєР°Р¶РґРѕРµ В«РїРµСЂРѕВ» С‡СѓС‚СЊ РіРЅС‘С‚СЃСЏ РІРѕР»РЅРѕР№ РѕС‚ РїРµСЂРµРґРЅРµР№ РєСЂРѕРјРєРё Рє Р·Р°РґРЅРµР№
					local rip = (0.12 + it.k * 0.025) * (0.4 + amp * 3) * math.sin(phase - it.k * 0.5)
					it.model:PivotTo(base * CFrame.Angles(rip, 0, 0))
					if state.color ~= color then
						for _, p in ipairs(it.parts) do p.Color = color end
					end
				else
					local ang = it.a + (0.03 + amp * 0.2) * math.sin(phase - it.ph)
					local d = Vector3.new(s * math.cos(ang), math.sin(ang), 0)
					local pos = d * it.r + Vector3.new(0, 0, it.z)
					local vZ = Vector3.new(0, 0, -1)
					it.model:PivotTo(base * CFrame.fromMatrix(pos, d:Cross(vZ), d, vZ))
				end
				if it.model.Parent ~= want then it.model.Parent = want end
			end
		end
		state.color = color
	end)
	gui.Destroying:Connect(function()
		conn:Disconnect()
		destroyWings()
	end)

	function Wings.set(on)
		enabled = on
		if not on then destroyWings() end
	end
	function Wings.setType(t)
		if t ~= "Normal" and t ~= "Bacon" then return end
		wingType = t
	end
end

--// РЎС‚СЂР°РЅРёС†С‹ Combat / Movement / Visual / Effects (РїСѓСЃС‚С‹С€РєРё)
local PANEL_X = { 15, 420 }
local PANEL_W = { 389, 564 }
for _, tabName in ipairs({ "Combat", "Movement", "Visual", "Effects" }) do
	for pi, def in ipairs(Features[tabName]) do
		local p = makePanel(pages[tabName], PANEL_X[pi], PANEL_W[pi])
		label({ Text = spaced(def.title), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = p })
		divider(p, 61)
		local y = 86
		for _, it in ipairs(def.items) do
			if it.type == "toggle" then
				toggle(p, y, it.text, function(s)
					if it.key == "effects.china_hat" then ChinaHat.set(s) end
					if it.key == "effects.wings" then Wings.set(s) end
					Callbacks.OnOption(it.key, s)
				end, nil, it.key == "effects.wings" and function() if WingsUI.toggle then WingsUI.toggle() end end or nil)
				y += 50
			elseif it.type == "slider" then
				slider(p, y, it.text, it.min, it.max, it.default, it.step or 1, function(v) Callbacks.OnSlider(it.key, v) end)
				y += 72
			end
		end
		
		-- Add Material dropdown for Hitbox Expander panel
		if tabName == "Combat" and def.title == "Hitbox Expander" and pi == 2 then
			task.defer(function()
				if dropdown then
					dropdown(p, PAD, y + 18, 345, { "ForceField", "Glass", "Plastic" }, "ForceField", function(selected) 
						if Callbacks.OnDropdown then
							Callbacks.OnDropdown("hitbox_material", selected)
						end
					end)
				end
			end)
		end
	end
end

--// РЎС‚СЂР°РЅРёС†Р° SUK
local left = makePanel(pages.SUK, 15, 389)
local right = makePanel(pages.SUK, 420, 564)

label({ Text = "S U K", Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(PAD, 20), Parent = left })
divider(left, 61)

local sukMainSet, sukMainGet = toggle(left, 86, "Enable SUK", function(v) Callbacks.OnMainToggle(v) end, false)
slider(left, 151, "Bullet velocity", 1000, 200000, 100000, 1000, function(v) Callbacks.OnSlider("velocity", v) end)
slider(left, 216, "Hit count", 1, 200, 50, 1, function(v) Callbacks.OnSlider("hits", v) end)
slider(left, 281, "Packets rate (Interval)", 0.05, 1.0, 0.1, 0.01, function(v) Callbacks.OnSlider("interval", v) end)

divider(left, 334)
label({ Text = spaced("Recovery"), Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(220, 24), Position = UDim2.fromOffset(PAD, 356), Parent = left })
divider(left, 386)

local healSet, healGet = toggle(left, 411, "Automatic Healing", function(v) Callbacks.OnOption("heal", v) end, false)
slider(left, 461, "Heal Fly Height", -5, 10, 3.5, 0.5, function(v) Callbacks.OnSlider("heal_height", v) end)

divider(left, 546)
local sukNpcSet, sukNpcGet = toggle(left, 571, "Auto Kill NPCs (Farms)", function(v) Callbacks.OnOption("targetNpcs", v) end, false)
local sukFriendSet, sukFriendGet = toggle(left, 626, "Ignore Friends in SUK", function(v) Callbacks.OnOption("ignoreFriends", v) end, true)

--// Правая панель SUK: верхняя строка
local searchBox = new("Frame", { Size = UDim2.new(1, -292, 0, 43), Position = UDim2.fromOffset(8, 13), BackgroundColor3 = Theme.Row, Parent = right }, { corner(12), stroke(Color3.fromRGB(32, 32, 35)) })
do
	local icon = new("Frame", { Size = UDim2.fromOffset(30, 43), BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Parent = searchBox })
	new("Frame", { Size = UDim2.fromOffset(11, 11), Position = UDim2.fromOffset(6, 12), BackgroundTransparency = 1, Parent = icon }, { corner(6), stroke(Theme.Dim, 1.5) })
	new("Frame", { Size = UDim2.fromOffset(7, 2), Position = UDim2.fromOffset(16, 26), Rotation = 45, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = icon })
end
local search = new("TextBox", {
	PlaceholderText = "Search players...", PlaceholderColor3 = Theme.Dim, Text = "", ClearTextOnFocus = false,
	Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0), Parent = searchBox,
})

local function pill(text, w, xFromRight)
	return new("TextButton", {
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.Text, AutoButtonColor = false,
		Size = UDim2.fromOffset(w, 43), Position = UDim2.new(1, xFromRight, 0, 13), BackgroundColor3 = Theme.Row, Parent = right,
	}, { corner(12), stroke() })
end
local btnRefresh = pill("Refresh", 84, -92)
local btnClear = pill("Clear", 70, -172)
local btnAll = pill("Select all", 92, -274)

local list = new("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -81), Position = UDim2.fromOffset(8, 73), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = right,
}, { corner(12), stroke(), new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }), new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

local emptyLbl = label({
	Text = "No players found", TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 90), Visible = false, Parent = right,
})

--// РЎРїРёСЃРѕРє РёРіСЂРѕРєРѕРІ
local selected = {}
local rows = {}

local function fireSelection() Callbacks.OnSelectionChanged(selected) end

local function playerInfo(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local hp = hum and math.floor(hum.Health) or 0
	local dist = (hrp and myHrp) and (hrp.Position - myHrp.Position).Magnitude or math.huge
	return hp, dist
end

local function buildRow(plr, order)
	local hp, dist = playerInfo(plr)
	local row = new("Frame", { Size = UDim2.new(1, -4, 0, 58), BackgroundColor3 = Theme.Row, LayoutOrder = order, Parent = list }, { corner(10) })
	local avatar = new("ImageLabel", { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(14, 10), BackgroundTransparency = 1, Parent = row }, { corner(8) })
	task.spawn(function()
		local okT, img = pcall(Players.GetUserThumbnailAsync, Players, plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if okT then avatar.Image = img end
	end)
	label({ Text = plr.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 15, Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(66, 9), Parent = row })
	label({
		Text = string.format("@%s  вЂў  %d HP  вЂў  %.1f m", plr.Name, hp, dist == math.huge and 0 or dist * 0.28),
		TextSize = 12, TextColor3 = Theme.Dim, Size = UDim2.new(1, -140, 0, 18), Position = UDim2.fromOffset(66, 31), Parent = row,
	})
	
	-- Add friend button (+)
	local addBtn = new("TextButton", { 
		Text = "+", 
		Font = Enum.Font.GothamBold, 
		TextSize = 18, 
		TextColor3 = Color3.fromRGB(85, 255, 127), 
		AutoButtonColor = false, 
		Size = UDim2.fromOffset(24, 24), 
		Position = UDim2.new(1, -60, 0.5, -12), 
		BackgroundColor3 = Theme.Row, 
		Parent = row 
	}, { corner(6), stroke(Color3.fromRGB(85, 255, 127), 1.2) })
	
	addBtn.MouseButton1Click:Connect(function()
		print("[CLL] Adding friend from SUK list:", plr.DisplayName)
		Callbacks.OnOption("addFriend", plr)
	end)
	addBtn.MouseEnter:Connect(function() tween(addBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(85, 255, 127, 0.2) }) end)
	addBtn.MouseLeave:Connect(function() tween(addBtn, 0.15, { BackgroundColor3 = Theme.Row }) end)
	
	local box = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -33, 0.5, -10), BackgroundColor3 = Theme.Row, Parent = row }, { corner(5), stroke(Theme.Dim, 1.2) })
	-- РіР°Р»РѕС‡РєР° РёР· РґРІСѓС… РїРѕРІС‘СЂРЅСѓС‚С‹С… РїРѕР»РѕСЃРѕРє
	local mark = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = box })
	new("Frame", { Size = UDim2.fromOffset(6, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(7, 11.5), Rotation = 45, BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Parent = mark }, { corner(1) })
	new("Frame", { Size = UDim2.fromOffset(11, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11.5, 9.5), Rotation = -45, BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, Parent = mark }, { corner(1) })

	local function setChecked(v)
		selected[plr] = v or nil
		mark.Visible = v
		box.BackgroundColor3 = v and Theme.Knob or Theme.Row
	end
	box.MouseButton1Click:Connect(function() setChecked(not selected[plr]); fireSelection() end)
	rows[plr] = { frame = row, setChecked = setChecked }
	setChecked(selected[plr] == true)
end

local function refresh()
	for _, r in pairs(rows) do r.frame:Destroy() end
	table.clear(rows)
	local q = search.Text:lower()
	local arr = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and (q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true)) then
			local _, d = playerInfo(p)
			table.insert(arr, { p, d })
		end
	end
	table.sort(arr, function(a, b) return a[2] < b[2] end)
	for i, e in ipairs(arr) do buildRow(e[1], i) end
	for p in pairs(selected) do if not p.Parent then selected[p] = nil end end
	emptyLbl.Visible = #arr == 0
end

btnRefresh.MouseButton1Click:Connect(refresh)
btnAll.MouseButton1Click:Connect(function() for _, r in pairs(rows) do r.setChecked(true) end; fireSelection() end)
btnClear.MouseButton1Click:Connect(function() for _, r in pairs(rows) do r.setChecked(false) end; fireSelection() end)
search:GetPropertyChangedSignal("Text"):Connect(refresh)
Players.PlayerAdded:Connect(refresh)
Players.PlayerRemoving:Connect(function() task.defer(refresh) end)

--// РљРѕРЅС‚РµРєСЃС‚РЅРѕРµ РјРµРЅСЋ РґР»СЏ РґРѕР±Р°РІР»РµРЅРёСЏ РІ РґСЂСѓР·СЊСЏ
local contextMenu = new("Frame", { Size = UDim2.fromOffset(140, 36), BackgroundColor3 = Theme.Panel, Visible = false, ZIndex = 100, Parent = right }, { corner(8), stroke() })
local addFriendBtn = new("TextButton", { Text = "Add to friends", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = contextMenu }, { corner(8) })

local selectedPlayerForFriend = nil
addFriendBtn.MouseButton1Click:Connect(function()
	if selectedPlayerForFriend then
		Callbacks.OnOption("addFriend", selectedPlayerForFriend)
		contextMenu.Visible = false
	end
end)

local function showContextMenu(plr, x, y)
	selectedPlayerForFriend = plr
	contextMenu.Position = UDim2.fromOffset(math.clamp(x, 0, right.AbsoluteSize.X - 140), math.clamp(y, 0, right.AbsoluteSize.Y - 36))
	contextMenu.Visible = true
end

UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if contextMenu.Visible then contextMenu.Visible = false end
	end
end)

--// Страница Config (Config & Friends)
do
	local configLeft = makePanel(pages.Config, 15, 389)
	local configRight = makePanel(pages.Config, 420, 564)
	
	-- Left panel: Config System
	label({ Text = spaced("CONFIG SYSTEM"), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = configLeft })
	divider(configLeft, 61)
	
	-- Config name input
	local configNameBox = new("Frame", { Size = UDim2.new(1, -40, 0, 43), Position = UDim2.fromOffset(20, 86), BackgroundColor3 = Theme.Row, Parent = configLeft }, { corner(12), stroke() })
	local configInput = new("TextBox", {
		PlaceholderText = "Enter config name...", PlaceholderColor3 = Theme.Dim, Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = configNameBox,
	})
	
	-- Config list (smaller height)
	label({ Text = "Saved Configs", TextSize = 14, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 144), Parent = configLeft })
	local configListScroll = new("ScrollingFrame", {
		Size = UDim2.new(1, -40, 0, 140), Position = UDim2.fromOffset(20, 174), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = configLeft,
	}, { corner(12), stroke(), new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name }), new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
	
	local noConfigsLabel = label({
		Text = "No configs saved yet", TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 10), Visible = true, Parent = configListScroll,
	})
	
	-- Function to update config list
	local function updateConfigList(configs)
		-- Clear existing
		for _, child in ipairs(configListScroll:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		
		if not configs or #configs == 0 then
			noConfigsLabel.Visible = true
			return
		end
		
		noConfigsLabel.Visible = false
		
		for _, configName in ipairs(configs) do
			local row = new("Frame", { Name = configName, Size = UDim2.new(1, -10, 0, 32), BackgroundColor3 = Theme.Row, Parent = configListScroll }, { corner(8) })
			label({ Text = configName, Font = Enum.Font.Gotham, TextSize = 14, Size = UDim2.new(1, -45, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = row })
			
			local loadBtn = new("TextButton", {
				Text = "Load", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false,
				Size = UDim2.fromOffset(36, 22), Position = UDim2.new(1, -38, 0.5, -11), BackgroundColor3 = Theme.TabOn, Parent = row,
			}, { corner(6) })
			
			loadBtn.MouseButton1Click:Connect(function()
				configInput.Text = configName
				print("[CLL] Loading config:", configName)
				Callbacks.OnOption("loadConfig", configName)
			end)
			loadBtn.MouseEnter:Connect(function() tween(loadBtn, 0.15, { BackgroundColor3 = Theme.Knob }) end)
			loadBtn.MouseLeave:Connect(function() tween(loadBtn, 0.15, { BackgroundColor3 = Theme.TabOn }) end)
		end
	end
	
	-- Expose update function
	_G.CLL_UpdateConfigList = updateConfigList
	
	-- Load existing configs on startup
	task.spawn(function()
		wait(0.5) -- Wait for UI to fully load
		if isfolder and listfiles then
			local configs = {}
			pcall(makefolder, CONFIG_FOLDER)
			if isfolder(CONFIG_FOLDER) then
				for _, file in ipairs(listfiles(CONFIG_FOLDER)) do
					local name = file:match("([^/\\]+)%.json$")
					if name then table.insert(configs, name) end
				end
			end
			updateConfigList(configs)
		end
	end)
	
	-- Config buttons (moved down)
	local function configBtn(text, y, callback)
		local btn = new("TextButton", {
			Text = text, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.Text, AutoButtonColor = false,
			Size = UDim2.new(1, -40, 0, 43), Position = UDim2.fromOffset(20, y), BackgroundColor3 = Theme.Row, Parent = configLeft,
		}, { corner(12), stroke() })
		btn.MouseButton1Click:Connect(callback)
		btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.TabOn }) end)
		btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundColor3 = Theme.Row }) end)
		return btn
	end
	
	configBtn("Save Config", 334, function()
		local name = configInput.Text:match("^%s*(.-)%s*$")
		if name ~= "" then
			print("[CLL] Saving config:", name)
			Callbacks.OnOption("saveConfig", name)
		end
	end)
	
	configBtn("Load Config", 397, function()
		local name = configInput.Text:match("^%s*(.-)%s*$")
		if name ~= "" then
			print("[CLL] Loading config:", name)
			Callbacks.OnOption("loadConfig", name)
		end
	end)
	
	configBtn("Delete Config", 460, function()
		local name = configInput.Text:match("^%s*(.-)%s*$")
		if name ~= "" then
			print("[CLL] Deleting config:", name)
			Callbacks.OnOption("deleteConfig", name)
		end
	end)
	
	label({ Text = "Configs are saved locally in workspace folder", TextSize = 13, TextColor3 = Theme.Dim, 
		Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 523), TextWrapped = true, Parent = configLeft })
	
	-- Right panel: Friends System
	label({ Text = spaced("FRIENDS SYSTEM"), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = configRight })
	divider(configRight, 61)
	
	-- Friends input + Add button
	local friendInputFrame = new("Frame", { Size = UDim2.new(1, -110, 0, 43), Position = UDim2.fromOffset(20, 86), BackgroundColor3 = Theme.Row, Parent = configRight }, { corner(12), stroke() })
	local friendInput = new("TextBox", {
		PlaceholderText = "Enter friend name...", PlaceholderColor3 = Theme.Dim, Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 15, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = friendInputFrame,
	})
	
	local addFriendBtn = new("TextButton", {
		Text = "Add", Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = Theme.Text, AutoButtonColor = false,
		Size = UDim2.fromOffset(80, 43), Position = UDim2.new(1, -100, 0, 86), BackgroundColor3 = Theme.Row, Parent = configRight,
	}, { corner(12), stroke() })
	
	addFriendBtn.MouseButton1Click:Connect(function()
		local name = friendInput.Text:match("^%s*(.-)%s*$")
		if name ~= "" then
			print("[CLL] Adding friend:", name)
			Callbacks.OnOption("addFriend", name)
			friendInput.Text = ""
		end
	end)
	addFriendBtn.MouseEnter:Connect(function() tween(addFriendBtn, 0.15, { BackgroundColor3 = Theme.TabOn }) end)
	addFriendBtn.MouseLeave:Connect(function() tween(addFriendBtn, 0.15, { BackgroundColor3 = Theme.Row }) end)
	
	-- Friends list
	local friendsList = new("ScrollingFrame", {
		Size = UDim2.new(1, -40, 1, -159), Position = UDim2.fromOffset(20, 149), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = configRight,
	}, { corner(12), stroke(), new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.Name }) })
	
	local friendsLabel = label({
		Text = "No friends added yet", TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20), Visible = true, Parent = friendsList,
	})
	
	-- Function to update friends list UI
	local function updateFriendsList(friends)
		-- Clear existing
		for _, child in ipairs(friendsList:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "UIListLayout" then
				child:Destroy()
			end
		end
		
		if not friends or #friends == 0 then
			friendsLabel.Visible = true
			return
		end
		
		friendsLabel.Visible = false
		
		for _, friendName in ipairs(friends) do
			local row = new("Frame", { Name = friendName, Size = UDim2.new(1, -10, 0, 38), BackgroundColor3 = Theme.Row, Parent = friendsList }, { corner(10) })
			label({ Text = friendName, Font = Enum.Font.Gotham, TextSize = 14, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			
			local removeBtn = new("TextButton", {
				Text = "×", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Color3.fromRGB(255, 80, 80), AutoButtonColor = false,
				Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -33, 0.5, -14), BackgroundColor3 = Theme.Off, Parent = row,
			}, { corner(7) })
			
			removeBtn.MouseButton1Click:Connect(function()
				print("[CLL] Removing friend:", friendName)
				Callbacks.OnOption("removeFriend", friendName)
			end)
			removeBtn.MouseEnter:Connect(function() tween(removeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(60, 20, 20) }) end)
			removeBtn.MouseLeave:Connect(function() tween(removeBtn, 0.15, { BackgroundColor3 = Theme.Off }) end)
		end
	end
	
	-- Expose update function
	_G.CLL_UpdateFriendsList = updateFriendsList
	
	-- Load existing friends on startup
	task.spawn(function()
		wait(0.5) -- Wait for UI to fully load
		local friendsList = {}
		for userId, _ in pairs(FriendsList) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(friendsList, player.DisplayName or player.Name)
			end
		end
		if #friendsList > 0 then
			updateFriendsList(friendsList)
		end
	end)
end

--// Страница Keybinds
do
	local keybindsPanel = makePanel(pages.Keybinds, 15, 964)
	
	label({ Text = spaced("KEY BINDINGS"), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = keybindsPanel })
	divider(keybindsPanel, 61)
	
	label({ Text = "Keybinds system will be added soon.\nPress a button to assign a key.", TextColor3 = Theme.Dim, TextSize = 14,
		Size = UDim2.new(1, -40, 0, 80), Position = UDim2.fromOffset(20, 100), TextWrapped = true, Parent = keybindsPanel })
end

--// Открытие / закрытие: RightShift, easeOutBack, блюр
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local OPEN_KEY = Enum.KeyCode.RightShift
local BLUR_SIZE = 18
local SPEED = 1.0          -- РѕР±С‰РёР№ РјРЅРѕР¶РёС‚РµР»СЊ СЃРєРѕСЂРѕСЃС‚Рё Р°РЅРёРјР°С†РёР№ (Р±РѕР»СЊС€Рµ = Р±С‹СЃС‚СЂРµРµ)
local CLOSED_SCALE = 0.93  -- РјР°СЃС€С‚Р°Р± РѕРєРЅР° РІ Р·Р°РєСЂС‹С‚РѕРј СЃРѕСЃС‚РѕСЏРЅРёРё
local WM_POS = UDim2.fromOffset(12, 52) -- СЃС‚Р°СЂС‚РѕРІР°СЏ РїРѕР·РёС†РёСЏ РІРѕС‚РµСЂРјР°СЂРєРё (РµС‘ РјРѕР¶РЅРѕ С‚Р°СЃРєР°С‚СЊ РјС‹С€РєРѕР№)

local function dur(t) return t / SPEED end
local function info(t, style, dir) return TweenInfo.new(dur(t), style, dir) end

local blur = new("BlurEffect", { Name = "CLLBlur", Size = 0, Parent = Lighting })
local winStroke = window:FindFirstChildOfClass("UIStroke")
window.GroupTransparency = 1
if winStroke then winStroke.Transparency = 1 end
animFactor.Value = CLOSED_SCALE

local isOpen = false
local tweens = {}
local function play(obj, ti, goal)
	local t = TweenService:Create(obj, ti, goal)
	table.insert(tweens, t)
	t:Play()
	return t
end

local ES, ED = Enum.EasingStyle, Enum.EasingDirection
-- open/close = { СЃС‚РёР»СЊ РёР·РёРЅРіР°, РЅР°РїСЂР°РІР»РµРЅРёРµ, РґР»РёС‚РµР»СЊРЅРѕСЃС‚СЊ }, scale = РјР°СЃС€С‚Р°Р± РІ Р·Р°РєСЂС‹С‚РѕРј РІРёРґРµ, slide = СЃРјРµС‰РµРЅРёРµ РїРѕ Y (px)
AnimPresets = {
	Smooth = { open = { ES.Quint, ED.Out, 0.5 }, close = { ES.Quart, ED.In, 0.32 }, scale = 0.93, slide = 24 },
	Bounce = { open = { ES.Back, ED.Out, 0.5 }, close = { ES.Back, ED.Out, 0.45 }, scale = 0.5, slide = 0 },
	Elastic = { open = { ES.Elastic, ED.Out, 0.8 }, close = { ES.Quad, ED.In, 0.25 }, scale = 0.7, slide = 0 },
	Snappy = { open = { ES.Exponential, ED.Out, 0.35 }, close = { ES.Exponential, ED.In, 0.22 }, scale = 0.96, slide = 12 },
	Pop = { open = { ES.Back, ED.Out, 0.4 }, close = { ES.Back, ED.In, 0.3 }, scale = 0.6, slide = 0 },
	Slide = { open = { ES.Cubic, ED.Out, 0.45 }, close = { ES.Cubic, ED.In, 0.3 }, scale = 1, slide = 90 },
	["Soft fade"] = { open = { ES.Sine, ED.Out, 0.35 }, close = { ES.Sine, ED.In, 0.25 }, scale = 1, slide = 0 },
}
AnimOrder = { "Smooth", "Bounce", "Elastic", "Snappy", "Pop", "Slide", "Soft fade" }
local AnimName = "Smooth"

local restPos = window.Position            -- РіРґРµ РѕРєРЅРѕ СЃС‚РѕРёС‚ РІ РѕС‚РєСЂС‹С‚РѕРј СЃРѕСЃС‚РѕСЏРЅРёРё (СѓС‡РёС‚С‹РІР°РµС‚ РїРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ)
local settled = true                       -- РѕРєРЅРѕ СЃС‚РѕРёС‚ РЅР° РјРµСЃС‚Рµ, Р°РЅРёРјР°С†РёСЏ РЅРµ РёРґС‘С‚
local function shifted(dy)
	return UDim2.new(restPos.X.Scale, restPos.X.Offset, restPos.Y.Scale, restPos.Y.Offset + dy)
end

local function setOpen(state)
	if state == isOpen then return end
	isOpen = state
	for _, t in ipairs(tweens) do t:Cancel() end
	table.clear(tweens)
	local A = AnimPresets[AnimName] or AnimPresets.Smooth
	local oi = info(A.open[3], A.open[1], A.open[2])
	local ci = info(A.close[3], A.close[1], A.close[2])
	if state then
		if not window.Visible then
			window.Position = shifted(A.slide)
			animFactor.Value = A.scale
		end
		window.Visible = true
		settled = false
		local main = play(animFactor, oi, { Value = 1 })
		play(window, oi, { Position = shifted(0) })
		local fade = info(math.min(A.open[3] * 0.6, 0.3), ES.Sine, ED.Out)
		play(window, fade, { GroupTransparency = 0 })
		if winStroke then play(winStroke, fade, { Transparency = 0 }) end
		play(blur, info(0.4, ES.Sine, ED.Out), { Size = BLUR_SIZE })
		main.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed and isOpen then settled = true end
		end)
	else
		search:ReleaseFocus()
		if settled then restPos = window.Position end
		settled = false
		local main = play(animFactor, ci, { Value = A.scale })
		play(window, ci, { Position = shifted(A.slide * 0.7) })
		local fade = info(A.close[3] * 0.8, ES.Sine, ED.In)
		play(window, fade, { GroupTransparency = 1 })
		if winStroke then play(winStroke, fade, { Transparency = 1 }) end
		play(blur, info(0.3, ES.Sine, ED.Out), { Size = 0 })
		main.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed and not isOpen then window.Visible = false end
		end)
	end
	Callbacks.OnMenu(state)
end

local keyConn = UIS.InputBegan:Connect(function(input)
	if input.KeyCode == OPEN_KEY and not UIS:GetFocusedTextBox() then
		setOpen(not isOpen)
	end
end)

--// РџР»Р°РІР°СЋС‰Р°СЏ РІРѕС‚РµСЂРјР°СЂРєР°: CLL | [РёРєРѕРЅРєР°] 240 FPS | [РёРєРѕРЅРєР°] 100 ms
local watermark = new("Frame", {
	Name = "Watermark", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34),
	Position = UDim2.new(0, -360, 0, WM_POS.Y.Offset), BackgroundColor3 = Theme.Bg, Parent = gui,
}, {
	corner(11), stroke(),
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function wmSep(order)
	return new("Frame", { Size = UDim2.fromOffset(1, 14), BackgroundColor3 = Theme.Text, BackgroundTransparency = 0.75, BorderSizePixel = 0, LayoutOrder = order, Parent = watermark })
end

-- Р·Р°РїР°СЃРЅС‹Рµ РёРєРѕРЅРєРё, РµСЃР»Рё РёРЅР¶РµРєС‚РѕСЂ РЅРµ СѓРјРµРµС‚ getcustomasset
local function fallbackIcon(parent, kind)
	local h = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, LayoutOrder = 1, Parent = parent })
	if kind == "ping" then
		for i = 1, 4 do
			new("Frame", { Size = UDim2.fromOffset(3, 3 + i * 3), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset((i - 1) * 4, 15), BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = h }, { corner(1) })
		end
	else
		new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Parent = h }, { round(), stroke(Theme.Dim, 1.5) })
		new("Frame", { Size = UDim2.fromOffset(2, 6), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(8, 8), Rotation = 35, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = h })
	end
end

local function wmMetric(order, iconKey, text)
	local grp = new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = watermark }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if IconAssets[iconKey] then
		new("ImageLabel", { Image = IconAssets[iconKey], Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, ImageColor3 = Theme.Dim, LayoutOrder = 1, Parent = grp })
	else
		fallbackIcon(grp, iconKey)
	end
	return label({ Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 2, Parent = grp })
end

local wmLogo = label({ Text = "CLL", Font = Enum.Font.Michroma, TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), LayoutOrder = 1, Parent = watermark })
local wmLogoImg = new("ImageLabel", { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, LayoutOrder = 1, Parent = watermark })
wmLogoImg:SetAttribute("NoTheme", true)
wmSep(2)
local fpsLbl = wmMetric(3, "fps", "-- FPS")
wmSep(4)
local pingLbl = wmMetric(5, "ping", "-- ms")

-- РїРµСЂРµС‚Р°СЃРєРёРІР°РЅРёРµ РІРѕС‚РµСЂРјР°СЂРєРё
do
	local dragging, startPos, startMouse
	watermark.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startMouse, startPos = true, i.Position, watermark.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			watermark.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

-- РЅР°СЃС‚РѕСЏС‰РёР№ FPS (РїРѕ РєР°РґСЂР°Рј СЂРµРЅРґРµСЂР°) Рё РїРёРЅРі (Data Ping РёР· Stats, Р·Р°РїР°СЃРЅРѕР№ РІР°СЂРёР°РЅС‚ вЂ” GetNetworkPing)
local function getPing()
	local okP, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if okP and typeof(v) == "number" and v > 0 then return math.floor(v + 0.5) end
	local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
	if ok2 and typeof(p) == "number" then return math.floor(p * 2000 + 0.5) end
	return 0
end

local frames, acc = 0, 0
local wmConn = RunService.RenderStepped:Connect(function(dt)
	frames += 1
	acc += dt
	if acc >= 0.5 then
		fpsLbl.Text = string.format("%d FPS", math.floor(frames / acc + 0.5))
		pingLbl.Text = string.format("%d ms", getPing())
		frames, acc = 0, 0
	end
end)

gui.Destroying:Connect(function()
	keyConn:Disconnect()
	wmConn:Disconnect()
	blur:Destroy()
end)

--// ===== РќР°СЃС‚СЂРѕР№РєРё: С‚РµРјР°, Р°РєС†РµРЅС‚, Р»РѕРіРѕС‚РёРї, РІРѕС‚РµСЂРјР°СЂРєР°, Р±Р»СЋСЂ =====
do
	local HttpService = game:GetService("HttpService")
	local SETTINGS_FILE = "CLL_settings.json"

	function C(r, g, b) return Color3.fromRGB(r, g, b) end
	function copy(t)
		local c = {}
		for k, v in pairs(t) do c[k] = v end
		return c
	end
	function basename(p) return tostring(p):match("([^/\\]+)$") or tostring(p) end
	function noTheme(o)
		o:SetAttribute("NoTheme", true)
		for _, d in ipairs(o:GetDescendants()) do d:SetAttribute("NoTheme", true) end
		return o
	end

	--// РџСЂРµСЃРµС‚С‹ С‚РµРј
	Presets = {
		{ name = "Graphite", colors = copy(Theme) },
		{ name = "Midnight", colors = { Bg = C(9, 12, 20), Panel = C(12, 16, 27), Row = C(19, 25, 40), Stroke = C(34, 44, 70), Text = C(235, 240, 250), Dim = C(110, 125, 160), Off = C(24, 31, 50), OnTrack = C(56, 88, 170), Knob = C(120, 165, 255), TabOn = C(32, 45, 80) } },
		{ name = "Violet", colors = { Bg = C(14, 11, 20), Panel = C(18, 14, 26), Row = C(28, 22, 40), Stroke = C(50, 40, 74), Text = C(242, 238, 250), Dim = C(130, 118, 160), Off = C(36, 29, 52), OnTrack = C(98, 66, 170), Knob = C(176, 140, 255), TabOn = C(52, 40, 82) } },
		{ name = "Crimson", colors = { Bg = C(17, 10, 11), Panel = C(22, 13, 14), Row = C(32, 19, 21), Stroke = C(62, 36, 40), Text = C(250, 238, 238), Dim = C(160, 115, 120), Off = C(42, 25, 28), OnTrack = C(150, 40, 55), Knob = C(255, 95, 110), TabOn = C(72, 34, 40) } },
		{ name = "Emerald", colors = { Bg = C(9, 15, 13), Panel = C(12, 20, 17), Row = C(18, 31, 26), Stroke = C(34, 58, 48), Text = C(236, 250, 244), Dim = C(112, 150, 132), Off = C(24, 40, 34), OnTrack = C(40, 130, 92), Knob = C(90, 230, 160), TabOn = C(30, 60, 47) } },
		{ name = "Snow", colors = { Bg = C(244, 244, 246), Panel = C(250, 250, 251), Row = C(232, 232, 236), Stroke = C(205, 205, 212), Text = C(24, 24, 28), Dim = C(120, 120, 130), Off = C(214, 214, 220), OnTrack = C(120, 120, 135), Knob = C(40, 40, 46), TabOn = C(218, 218, 226) } },
	}
	function presetColors(name)
		for _, p in ipairs(Presets) do
			if p.name == name then return p.colors end
		end
		return Presets[1].colors
	end

	MODES = { "Default", "Custom text", "Image" }
	LETTER_ANIMS = { "None", "Sizing", "Too many", "Ripple" }
	DEFAULTS = { preset = "Graphite", accent = false, logoMode = "Default", logoText = "CLL", logoFile = "", logoSize = 40, watermark = true, blur = true, anim = "Smooth", animSpeed = 100, logoAnim = "None", wingType = "Normal" }
	Settings = copy(DEFAULTS)

	--// РЎРѕС…СЂР°РЅРµРЅРёРµ / Р·Р°РіСЂСѓР·РєР°
	local saveToken = 0
	function saveSettings()
		if not writefile then return end
		pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings)) end)
	end
	function queueSave()
		saveToken = saveToken + 1
		local t = saveToken
		task.delay(0.6, function() if t == saveToken then saveSettings() end end)
	end
	function loadSettings()
		if not (isfile and readfile) then return end
		local ok, data = pcall(function()
			if isfile(SETTINGS_FILE) then return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end
		end)
		if not ok or typeof(data) ~= "table" then return end
		for k, v in pairs(data) do
			if k == "accent" then
				if typeof(v) == "table" and #v == 3 then
					local a = {}
					for i = 1, 3 do a[i] = math.clamp(tonumber(v[i]) or 200, 30, 250) end
					Settings.accent = a
				end
			elseif DEFAULTS[k] ~= nil and typeof(v) == typeof(DEFAULTS[k]) then
				Settings[k] = v
			end
		end
		local found = false
		for _, p in ipairs(Presets) do if p.name == Settings.preset then found = true end end
		if not found then Settings.preset = DEFAULTS.preset end
		found = false
		for _, m in ipairs(MODES) do if m == Settings.logoMode then found = true end end
		if not found then Settings.logoMode = DEFAULTS.logoMode end
		Settings.logoSize = math.clamp(Settings.logoSize, 20, 56)
		if not AnimPresets[Settings.anim] then Settings.anim = DEFAULTS.anim end
		Settings.animSpeed = math.clamp(Settings.animSpeed, 50, 200)
		local okLA = false
		for _, m in ipairs(LETTER_ANIMS) do if m == Settings.logoAnim then okLA = true end end
		if not okLA then Settings.logoAnim = DEFAULTS.logoAnim end
		if Settings.wingType ~= "Normal" and Settings.wingType ~= "Bacon" then Settings.wingType = DEFAULTS.wingType end
		return true
	end
	loadSettings()

	--// РџСЂРёРјРµРЅРµРЅРёРµ С‚РµРјС‹: РїРµСЂРµРєСЂР°С€РёРІР°РµРј РІСЃС‘, С‡С‚Рѕ СЃРѕРІРїР°РґР°РµС‚ РїРѕ С†РІРµС‚Сѓ СЃРѕ СЃС‚Р°СЂРѕР№ С‚РµРјРѕР№
	function colorKey(c)
		return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	function colorProps(inst)
		local p = {}
		if inst:IsA("GuiObject") then p[#p + 1] = "BackgroundColor3" end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then p[#p + 1] = "TextColor3" end
		if inst:IsA("TextBox") then p[#p + 1] = "PlaceholderColor3" end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then p[#p + 1] = "ImageColor3" end
		if inst:IsA("ScrollingFrame") then p[#p + 1] = "ScrollBarImageColor3" end
		if inst:IsA("UIStroke") then p[#p + 1] = "Color" end
		return p
	end
	local themeAnim
	function snapThemeAnim()
		if themeAnim then
			themeAnim.conn:Disconnect()
			for _, e in ipairs(themeAnim.list) do e.inst[e.prop] = e.to end
			themeAnim = nil
		end
	end
	function applyTheme(new, instant)
		snapThemeAnim()
		local oldTheme = {}
		for k, v in pairs(Theme) do oldTheme[k] = v end
		
		local list = {}
		for _, d in ipairs(gui:GetDescendants()) do
			if not d:GetAttribute("NoTheme") then
				for _, prop in ipairs(colorProps(d)) do
					local currentColor = d[prop]
					if typeof(currentColor) == "Color3" then
						for themeKey, oldColor in pairs(oldTheme) do
							if typeof(oldColor) == "Color3" and typeof(new[themeKey]) == "Color3" then
								local dr = math.abs(currentColor.R - oldColor.R)
								local dg = math.abs(currentColor.G - oldColor.G)
								local db = math.abs(currentColor.B - oldColor.B)
								if dr < 0.02 and dg < 0.02 and db < 0.02 then
									list[#list + 1] = { inst = d, prop = prop, from = currentColor, to = new[themeKey] }
									break
								end
							end
						end
					end
				end
			end
		end
		
		for k, v in pairs(new) do Theme[k] = v end
		if instant or #list == 0 then
			for _, e in ipairs(list) do e.inst[e.prop] = e.to end
			return
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.min((os.clock() - t0) / 0.3, 1)
			a = a * a * (3 - 2 * a)
			for _, e in ipairs(list) do e.inst[e.prop] = e.from:Lerp(e.to, a) end
			if a >= 1 then
				conn:Disconnect()
				themeAnim = nil
			end
		end)
		themeAnim = { conn = conn, list = list }
	end
	function currentColors()
		local base = presetColors(Settings.preset)
		if Settings.accent then
			local t = copy(base)
			local a = C(Settings.accent[1], Settings.accent[2], Settings.accent[3])
			t.Knob = a
			t.OnTrack = base.Off:Lerp(a, 0.55)
			return t
		end
		return base
	end

	--// РљРЅРѕРїРєР°-С€РµСЃС‚РµСЂС‘РЅРєР° СЃРїСЂР°РІР° СЃРІРµСЂС…Сѓ + СЃС‚СЂР°РЅРёС†Р° РЅР°СЃС‚СЂРѕРµРє
	-- Session Time Display (left of settings button)
	local sessionTimeLabel = new("TextLabel", {
		Text = "0:00", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 30), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -74, 0, 31), Visible = false, Parent = header
	})
	
	-- Update session time every second
	task.spawn(function()
		while not isUnloaded do
			if ShowSessionTime and sessionTimeLabel then
				local elapsed = os.clock() - SessionStartTime
				local minutes = math.floor(elapsed / 60)
				local seconds = math.floor(elapsed % 60)
				sessionTimeLabel.Text = string.format("%d:%02d", minutes, seconds)
				sessionTimeLabel.Visible = true
			elseif sessionTimeLabel then
				sessionTimeLabel.Visible = false
			end
			task.wait(1)
		end
	end)
	
	local setHolder = new("Frame", { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0, 31), BackgroundColor3 = Theme.Row, Parent = header }, { corner(13), stroke() })
	local setBtn = new("TextButton", { Name = "SettingsOld", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Theme.TabOn, BackgroundTransparency = 1, Parent = setHolder }, { corner(10) })
	local setColor, gear = makeIcon(setBtn, IconBuilders.Settings)
	tabs.SettingsOld = { btn = setBtn, setColor = setColor }
	settingsPage = new("CanvasGroup", { Name = "SettingsOld", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = body })
	pages.SettingsOld = settingsPage

	local lastMain = "SUK"
	openDropdown = nil
	setBtn.MouseButton1Click:Connect(function()
		if openDropdown then openDropdown.close() end
		if currentTab == "SettingsOld" then
			selectTab(lastMain)
		else
			lastMain = currentTab
			selectTab("SettingsOld")
		end
	end)
	setBtn.MouseEnter:Connect(function() if currentTab ~= "SettingsOld" then setColor(Theme.Dim:Lerp(Theme.Text, 0.6)) end end)
	setBtn.MouseLeave:Connect(function() if currentTab ~= "SettingsOld" then setColor(Theme.Dim) end end)


	--// Р”СЂРѕРїРґР°СѓРЅ
	function dropdown(parent, x, cy, w, options, current, onSelect, onOpen, openUp)
		local H, ITEM, MAXV = 36, 32, 5
		local opts, value, opened = options, current, false
		local api = {}
		local root = new("Frame", { Size = UDim2.fromOffset(w, H), Position = UDim2.fromOffset(x, cy - H / 2), BackgroundTransparency = 1, ZIndex = 20, Parent = parent })
		local head = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Row, Parent = root }, { corner(10), stroke() })
		local cur = label({ Text = current, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(14, 0), Parent = head })
		local arrow = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0.5, 0), BackgroundTransparency = 1, Parent = head })
		new("Frame", { Size = UDim2.fromOffset(8, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4.5, 7), Rotation = 45, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = arrow }, { corner(1) })
		new("Frame", { Size = UDim2.fromOffset(8, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9.5, 7), Rotation = -45, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = arrow }, { corner(1) })
		local list = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 0), AnchorPoint = openUp and Vector2.new(0, 1) or Vector2.new(0, 0), Position = openUp and UDim2.new(0, 0, 0, -6) or UDim2.new(0, 0, 1, 6), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
			ClipsDescendants = true, Visible = false, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Dim,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
		}, {
			corner(10), stroke(),
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
		})
		local items = {}
		local function paint()
			for _, it in ipairs(items) do it.btn.BackgroundTransparency = (it.name == value) and 0 or 1 end
		end
		local function setOpen(v)
			if v == opened then return end
			opened = v
			if v then
				if openDropdown and openDropdown ~= api then openDropdown.close() end
				openDropdown = api
				list.Size = UDim2.new(1, 0, 0, 0)
				list.Visible = true
				tween(list, 0.18, { Size = UDim2.new(1, 0, 0, math.min(#opts, MAXV) * ITEM + 8) })
			else
				if openDropdown == api then openDropdown = nil end
				tween(list, 0.12, { Size = UDim2.new(1, 0, 0, 0) })
				task.delay(0.13, function() if not opened then list.Visible = false end end)
			end
			tween(arrow, 0.15, { Rotation = v and 180 or 0 })
		end
		local function pick(name)
			value = name
			cur.Text = name
			paint()
			setOpen(false)
			onSelect(name)
		end
		local function build()
			for _, it in ipairs(items) do it.btn:Destroy() end
			table.clear(items)
			for i, name in ipairs(opts) do
				local btn = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ITEM), BackgroundColor3 = Theme.TabOn, BackgroundTransparency = 1, LayoutOrder = i, Parent = list }, { corner(8) })
				label({ Text = name, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = btn })
				btn.MouseEnter:Connect(function() if name ~= value then tween(btn, 0.1, { BackgroundTransparency = 0.6 }) end end)
				btn.MouseLeave:Connect(function() if name ~= value then tween(btn, 0.1, { BackgroundTransparency = 1 }) end end)
				btn.MouseButton1Click:Connect(function() pick(name) end)
				items[i] = { btn = btn, name = name }
			end
			paint()
		end
		head.MouseButton1Click:Connect(function()
			if not opened and onOpen then onOpen(api) end
			setOpen(not opened)
		end)
		api.head, api.list = head, list
		api.close = function() setOpen(false) end
		api.set = function(name) value = name; cur.Text = name; paint() end
		api.setOptions = function(o) opts = o; build() end
		build()
		return api
	end

	-- Р·Р°РєСЂС‹С‚РёРµ РґСЂРѕРїРґР°СѓРЅР° РєР»РёРєРѕРј РјРёРјРѕ
	local ddConn = UIS.InputBegan:Connect(function(i)
		if not openDropdown then return end
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
		-- РєРѕРѕСЂРґРёРЅР°С‚С‹ РјС‹С€Рё РІ СЂР°Р·РЅС‹С… РѕРєСЂСѓР¶РµРЅРёСЏС… РјРѕРіСѓС‚ РѕС‚Р»РёС‡Р°С‚СЊСЃСЏ РЅР° GuiInset (в‰€36px), РїРѕСЌС‚РѕРјСѓ РїСЂРѕРІРµСЂСЏРµРј РІСЃРµ РІР°СЂРёР°РЅС‚С‹
		local inset = game:GetService("GuiService"):GetGuiInset()
		local m = UIS:GetMouseLocation()
		local q = Vector2.new(i.Position.X, i.Position.Y)
		local pts = { m, q, q + inset, m - inset }
		local function inside(g)
			local a, sz = g.AbsolutePosition, g.AbsoluteSize
			for _, p in ipairs(pts) do
				if p.X >= a.X and p.X <= a.X + sz.X and p.Y >= a.Y and p.Y <= a.Y + sz.Y then return true end
			end
			return false
		end
		if not (inside(openDropdown.head) or inside(openDropdown.list)) then openDropdown.close() end
	end)
	
	gui.Destroying:Connect(function() ddConn:Disconnect() end)
end

	--// РџРѕР»Рµ РІРІРѕРґР°
	function textInput(parent, x, cy, w, placeholder, text, live, onChange)
		local box = new("Frame", { Size = UDim2.fromOffset(w, 36), Position = UDim2.fromOffset(x, cy - 18), BackgroundColor3 = Theme.Row, Parent = parent }, { corner(10), stroke() })
		local tb = new("TextBox", {
			PlaceholderText = placeholder, PlaceholderColor3 = Theme.Dim, Text = text or "", ClearTextOnFocus = false,
			Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = box,
		})
		if live then
			tb:GetPropertyChangedSignal("Text"):Connect(function() onChange(tb) end)
		else
			tb.FocusLost:Connect(function() onChange(tb) end)
		end
		return tb
	end

	function sectionLabel(parent, text, y)
		return label({ Text = spaced(text), Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(300, 24), Position = UDim2.fromOffset(PAD, y - 12), Parent = parent })
	end

	--// РђРЅРёРјР°С†РёСЏ Р±СѓРєРІ Р»РѕРіРѕС‚РёРїР° (РјРµРЅСЋ + РІРѕС‚РµСЂРјР°СЂРєР°)
	local TextService = game:GetService("TextService")
	local rigs = {}
	function makeRig(parent, fontSize, height, pos, layoutOrder)
		local rig = { letters = {}, text = "" }
		rig.frame = new("Frame", { Name = "LetterRig", BackgroundTransparency = 1, Size = UDim2.fromOffset(10, height), Position = pos, LayoutOrder = layoutOrder or 0, Visible = false, Parent = parent })
		rig.setText = function(t)
			if t == rig.text then return end
			rig.text = t
			for _, l in ipairs(rig.letters) do l.lbl:Destroy() end
			table.clear(rig.letters)
			local x = 0
			for ch in t:gmatch(".") do
				local w = TextService:GetTextSize(ch, fontSize, Enum.Font.Michroma, Vector2.new(1000, 1000)).X
				local lbl = new("TextLabel", {
					Text = ch, Font = Enum.Font.Michroma, TextSize = fontSize, TextColor3 = Theme.Text, BackgroundTransparency = 1,
					Size = UDim2.fromOffset(math.max(w, 1), height), AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(x + w / 2, height / 2), Parent = rig.frame,
				})
				lbl:SetAttribute("NoTheme", true)
				local sc = new("UIScale", { Parent = lbl })
				rig.letters[#rig.letters + 1] = { lbl = lbl, sc = sc }
				x = x + w
			end
			rig.frame.Size = UDim2.fromOffset(x, height)
		end
		rigs[#rigs + 1] = rig
		return rig
	end
	local logoRig = makeRig(header, 26, 62, UDim2.fromOffset(23, 0), 0)
	local wmRig = makeRig(watermark, 13, 34, UDim2.fromOffset(0, 0), 1)

	local animConn = RunService.RenderStepped:Connect(function()
		if not Settings then return end
		local mode = Settings.logoAnim
		if mode == "None" then return end
		local now = os.clock()
		local A = Theme.Text
		local B = Theme.Text:Lerp(Theme.Bg, 0.82) -- В«РІС‚РѕСЂРѕР№ РїРѕР»СЋСЃВ» РіСЂР°РґРёРµРЅС‚Р°: Рє С„РѕРЅСѓ
		for _, rig in ipairs(rigs) do
			if rig.frame.Visible then
				local n = #rig.letters
				for i, l in ipairs(rig.letters) do
					local sc, col = 1, A
					if mode == "Sizing" then
						-- Р±СѓРєРІС‹ РїРѕ РѕС‡РµСЂРµРґРё: СЂРµР·РєРёР№ СЂРѕСЃС‚, РїР»Р°РІРЅРѕРµ РІРѕР·РІСЂР°С‰РµРЅРёРµ
						local step = 0.13
						local t = (now - (i - 1) * step) % (n * step + 0.9)
						if t < 0.07 then
							sc = 1 + 0.45 * (t / 0.07)
						elseif t < 0.57 then
							local u = (t - 0.07) / 0.5
							sc = 1 + 0.45 * (1 - u) * (1 - u)
						end
					elseif mode == "Too many" then
						-- РјСЏРіРєРёР№ РіСЂР°РґРёРµРЅС‚ СЃР»РµРІР° РЅР°РїСЂР°РІРѕ: Сѓ СЃРѕСЃРµРґРЅРёС… Р±СѓРєРІ СЂР°Р·РЅС‹Рµ РѕС‚С‚РµРЅРєРё
						local ph = now * 2.2 - (i - 1) * (2 * math.pi / (n + 2))
						col = B:Lerp(A, 0.5 + 0.5 * math.sin(ph))
					else
						-- Ripple: Р±РµРіСѓС‰Р°СЏ РІРѕР»РЅР° вЂ” Р±СѓРєРІР° РІС‹СЂР°СЃС‚Р°РµС‚ Рё В«Р·Р°Р¶РёРіР°РµС‚СЃСЏВ», СЃР·Р°РґРё С‚СЏРЅРµС‚СЃСЏ РјСЏРіРєРёР№ РіСЂР°РґРёРµРЅС‚
						local pos = (now * 2.4) % (n + 3) - 1.5
						local d = (i - 1) - pos
						local bump = math.exp(-d * d / 1.1)
						sc = 1 + 0.28 * bump
						local g = 0.5 + 0.5 * math.sin(now * 1.6 - (i - 1) * (2 * math.pi / (n + 3)))
						col = B:Lerp(A, g * 0.6):Lerp(A, bump)
					end
					l.sc.Scale = sc
					l.lbl.TextColor3 = col
				end
			end
		end
	end)
	gui.Destroying:Connect(function() animConn:Disconnect() end)

	--// РћР±СЂР°Р±РѕС‚С‡РёРєРё (РѕР±СЉСЏРІР»РµРЅС‹ Р·Р°СЂР°РЅРµРµ, Р·Р°РїРѕР»РЅСЏСЋС‚СЃСЏ РЅРёР¶Рµ)
	applyLogo, applyAll, syncAccentSliders = nil, nil, nil
	--// ===== Р›РµРІР°СЏ РїР°РЅРµР»СЊ: С‚РµРјР° =====
	local L = makePanel(settingsPage, 15, 389)
	label({ Text = spaced("Theme"), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = L })
	divider(L, 61)
	sectionLabel(L, "Presets", 84)

	presetStrokes = {}
	function refreshPresetUI()
		for name, st in pairs(presetStrokes) do
			local sel = name == Settings.preset
			st.Color = sel and Theme.Knob or Theme.Stroke
			st.Thickness = sel and 1.5 or 1
		end
	end
	for i, p in ipairs(Presets) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(172, 40), Position = UDim2.fromOffset(PAD + col * 177, 104 + row * 46), BackgroundColor3 = Theme.Row, Parent = L }, { corner(10) })
		local st = stroke()
		st.Parent = b
		st:SetAttribute("NoTheme", true)
		presetStrokes[p.name] = st
		local chip = new("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = p.colors.Bg, Parent = b }, { corner(7), stroke(p.colors.Stroke, 1) })
		new("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = p.colors.Knob, BorderSizePixel = 0, Parent = chip }, { round() })
		noTheme(chip)
		label({ Text = p.name, TextSize = 14, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(44, 0), Parent = b })
		b.MouseButton1Click:Connect(function()
			Settings.preset = p.name
			Settings.accent = false
			syncAccentSliders()
			applyTheme(currentColors(), false)
			refreshPresetUI()
			queueSave()
		end)
	end

	divider(L, 254)
	sectionLabel(L, "Interface", 276)
	slider(L, 301, "GUI Transparency", 0.1, 1, 1, 0.05, function(v)
		if gui then gui.BackgroundTransparency = 1 - v end -- Inverted: 1 = opaque, 0.1 = transparent
	end)
	
	syncAccentSliders = function()
		-- Removed: Accent sliders no longer exist
	end

	--// ===== РџСЂР°РІР°СЏ РїР°РЅРµР»СЊ: РёРЅС‚РµСЂС„РµР№СЃ / Р»РѕРіРѕС‚РёРї =====
	local R = makePanel(settingsPage, 420, 564)
	label({ Text = spaced("Interface"), Font = Enum.Font.GothamMedium, TextSize = 20, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(PAD, 20), Parent = R })
	divider(R, 61)
	sectionLabel(R, "Logo", 84)
	label({ Text = "Style", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 100), Parent = R })

	function overlay()
		return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(564, 511), ZIndex = 10, Visible = false, Parent = R })
	end
	local gDefault, gText, gImage, gLetters = overlay(), overlay(), overlay(), overlay()
	local groups = { Default = gDefault, ["Custom text"] = gText, Image = gImage }
	function showGroup()
		for n, g in pairs(groups) do g.Visible = (n == Settings.logoMode) end
		gLetters.Visible = Settings.logoMode ~= "Image"
	end

	local modeDD = dropdown(R, 564 - PAD - 240, 112, 240, MODES, Settings.logoMode, function(name)
		Settings.logoMode = name
		showGroup()
		applyLogo()
		queueSave()
	end)

	-- Default
	label({ Text = "The standard CLL wordmark is used.", TextSize = 13, TextColor3 = Theme.Dim, Size = UDim2.fromOffset(500, 24), Position = UDim2.fromOffset(PAD, 144), Parent = gDefault })

	-- Custom text
	label({ Text = "Logo text", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 144), Parent = gText })
	local textBox = textInput(gText, 564 - PAD - 240, 156, 240, "CLL", Settings.logoText, true, function(tb)
		c = tb.Text:gsub("[^\32-\126]", "")
		c = c:sub(1, 12)
		if c ~= tb.Text then
			tb.Text = c
			return
		end
		Settings.logoText = c
		applyLogo()
		queueSave()
	end)
	label({ Text = "Latin letters, digits and symbols, up to 12 characters. Same font as the default logo.", TextSize = 13, TextColor3 = Theme.Dim, TextWrapped = true, Size = UDim2.fromOffset(500, 34), Position = UDim2.fromOffset(PAD, 182), TextYAlignment = Enum.TextYAlignment.Top, Parent = gText })

	-- РђРЅРёРјР°С†РёСЏ Р±СѓРєРІ (РґР»СЏ Default Рё Custom text)
	label({ Text = "Letter animation", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 238), Parent = gLetters })
	local letterDD = dropdown(gLetters, 564 - PAD - 240, 250, 240, LETTER_ANIMS, Settings.logoAnim, function(name)
		Settings.logoAnim = name
		applyLogo()
		queueSave()
	end)

	-- Image
	local fileMap = {}
	local IMG_EXT = { png = true, jpg = true, jpeg = true, bmp = true }
	local NO_FILES = "No images found"
	function scanFiles()
		table.clear(fileMap)
		local names = {}
		for _, folder in ipairs({ "", "CLL" }) do
			local okL, files = pcall(function() return listfiles(folder) end)
			if okL and typeof(files) == "table" then
				for _, f in ipairs(files) do
					local path = (tostring(f):gsub("\\", "/"))
					local name = basename(path)
					local ext = name:match("%.(%w+)$")
					if ext and IMG_EXT[ext:lower()] and name:sub(1, 9) ~= "cll_icon_" and not fileMap[name] then
						fileMap[name] = path
						names[#names + 1] = name
					end
				end
			end
		end
		table.sort(names)
		if #names == 0 then names[1] = NO_FILES end
		return names
	end
	function resolvePath(name)
		if isfile then
			local okA, a = pcall(isfile, name)
			if okA and a then return name end
			local okB, b = pcall(isfile, "CLL/" .. name)
			if okB and b then return "CLL/" .. name end
		end
		return name
	end
	local assetCache = {}
	function loadLogoAsset(path)
		if assetCache[path] then return assetCache[path] end
		local gca = getcustomasset or getsynasset
		if not (gca and isfile) then return nil, "Your executor doesn't support custom assets." end
		local okF, exists = pcall(isfile, path)
		if not okF or not exists then return nil, "File not found: " .. path end
		local okA, asset = pcall(gca, path)
		if okA and asset then
			assetCache[path] = asset
			return asset
		end
		return nil, "Couldn't load this image (png / jpg / bmp only)."
	end

	label({ Text = "Image file", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 144), Parent = gImage })
	local fileDD, fileBox
	fileDD = dropdown(gImage, 564 - PAD - 240, 156, 240, scanFiles(), Settings.logoFile ~= "" and basename(Settings.logoFile) or "Select file...", function(name)
		if name == NO_FILES then return end
		Settings.logoFile = fileMap[name] or name
		fileBox.Text = Settings.logoFile
		assetCache[resolvePath(Settings.logoFile)] = nil
		applyLogo()
		queueSave()
	end, function(api) api.setOptions(scanFiles()) end)
	label({ Text = "Or type a name", Size = UDim2.fromOffset(200, 24), Position = UDim2.fromOffset(PAD, 192), Parent = gImage })
	fileBox = textInput(gImage, 564 - PAD - 240, 204, 240, "logo.png", Settings.logoFile, false, function(tb)
		Settings.logoFile = tb.Text:gsub("^%s+", ""):gsub("%s+$", "")
		assetCache[resolvePath(Settings.logoFile)] = nil
		fileDD.set(Settings.logoFile ~= "" and basename(Settings.logoFile) or "Select file...")
		applyLogo()
		queueSave()
	end)
	local imgStatus = label({ Text = "", TextSize = 13, TextColor3 = Theme.Dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromOffset(524, 34), Position = UDim2.fromOffset(PAD, 232), Parent = gImage })
	local setSize = slider(gImage, 296, "Image size", 20, 56, Settings.logoSize, 1, function(v)
		Settings.logoSize = v
		applyLogo()
		queueSave()
	end)

	divider(R, 346)
	local wmHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(282, 44), Position = UDim2.fromOffset(0, 348), Parent = R })
	local blHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(282, 44), Position = UDim2.fromOffset(282, 348), Parent = R })
	local setWm = toggle(wmHolder, 22, "Watermark", function(s)
		Settings.watermark = s
		applyAll(true, true)
		queueSave()
	end, Settings.watermark)
	local setBlur = toggle(blHolder, 22, "Background blur", function(s)
		Settings.blur = s
		applyAll(true, true)
		queueSave()
	end, Settings.blur)
	divider(R, 396)

	label({ Text = "Animation", Size = UDim2.fromOffset(90, 24), Position = UDim2.fromOffset(PAD, 408), Parent = R })
	local animDD = dropdown(R, 110, 420, 314, AnimOrder, Settings.anim, function(name)
		Settings.anim = name
		AnimName = name
		queueSave()
	end, nil, true)
	local previewBtn = new("TextButton", { Text = "Preview", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(110, 36), Position = UDim2.fromOffset(434, 402), BackgroundColor3 = Theme.Row, Parent = R }, { corner(10), stroke() })
	previewBtn.MouseButton1Click:Connect(function()
		if openDropdown then openDropdown.close() end
		setOpen(false)
		task.delay(0.8 / SPEED, function() setOpen(true) end)
	end)
	local setSpeed = slider(R, 462, "Animation speed (%)", 50, 200, Settings.animSpeed, 10, function(v)
		Settings.animSpeed = v
		SPEED = v / 100
		queueSave()
	end)

	local rejoinBtn = new("TextButton", { Text = "Rejoin", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(100, 32), Position = UDim2.fromOffset(564 - PAD - 120 - 118 - 108, 14), BackgroundColor3 = Theme.Row, Parent = R }, { corner(10), stroke() })
	local unhookBtn = new("TextButton", { Text = "UnHook", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(255, 95, 110), AutoButtonColor = false, Size = UDim2.fromOffset(110, 32), Position = UDim2.fromOffset(564 - PAD - 120 - 118, 14), BackgroundColor3 = Theme.Row, Parent = R }, { corner(10), stroke(Color3.fromRGB(255, 95, 110), 1.2) })
	local resetBtn = new("TextButton", { Text = "Reset all", Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(120, 32), Position = UDim2.fromOffset(564 - PAD - 120, 14), BackgroundColor3 = Theme.Row, Parent = R }, { corner(10), stroke() })

	-- Rejoin callback
	rejoinBtn.MouseButton1Click:Connect(function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
	end)

	--// UnHook callback
	unhookBtn.MouseButton1Click:Connect(function()
		isUnloaded = true
		
		-- Disconnect все connections
		for _, conn in ipairs(Connections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(Connections)
		
		-- Stop heal loop
		StopHealLoop()
		
		-- Cleanup Movement
		FlyEnabled = false
		SpinEnabled = false
		NoClipEnabled = false
		WalkSpeedEnabled = false
		JumpPowerEnabled = false
		InfiniteJumpEnabled = false
		
		if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
		if flyGyro then flyGyro:Destroy(); flyGyro = nil end
		if spinAngular then spinAngular:Destroy(); spinAngular = nil end
		if InfiniteJumpConnection then InfiniteJumpConnection:Disconnect(); InfiniteJumpConnection = nil end
		
		-- Restore collision
		for part, old in pairs(savedCollision) do
			if part and part.Parent then part.CanCollide = old end
		end
		table.clear(savedCollision)
		
		-- Restore humanoid
		local char = LocalPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
				pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
			end
		end
		
		-- Unhook namecall
		if oldNamecall then
			pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
		end
		
		-- Destroy GUI
		pcall(function() gui:Destroy() end)
		
		-- Cleanup global state
		isMultiSuk = false
		SilentAimEnabled = false
	end)

	--// РџСЂРёРјРµРЅРµРЅРёРµ Р»РѕРіРѕС‚РёРїР° / РѕСЃС‚Р°Р»СЊРЅС‹С… РЅР°СЃС‚СЂРѕРµРє
	applyLogo = function()
		local txt, asset = "CLL", nil
		local status = "Put a .png / .jpg into your executor's workspace folder (or workspace/CLL) and pick it above."
		if Settings.logoMode == "Custom text" then
			local t = (tostring(Settings.logoText):gsub("[^\32-\126]", "")):sub(1, 12)
			if t ~= "" then txt = t end
		elseif Settings.logoMode == "Image" and Settings.logoFile ~= "" then
			local a, err = loadLogoAsset(resolvePath(Settings.logoFile))
			if a then
				asset = a
				status = "Loaded: " .. basename(Settings.logoFile)
			else
				status = err
			end
		end
		imgStatus.Text = status
		local sz = Settings.logoSize
		logoImage.Size = UDim2.fromOffset(sz, sz)
		logoImage.Position = UDim2.fromOffset(23, (62 - sz) / 2)
		logoImage.Visible = asset ~= nil
		if asset then logoImage.Image = asset; wmLogoImg.Image = asset end
		local animOn = asset == nil and Settings.logoAnim ~= "None"
		logoLabel.Text = txt
		logoLabel.Visible = asset == nil and not animOn
		wmLogo.Text = txt
		wmLogo.Visible = asset == nil and not animOn
		logoRig.setText(txt)
		wmRig.setText(txt)
		logoRig.frame.Visible = animOn
		wmRig.frame.Visible = animOn
		wmLogoImg.Visible = asset ~= nil
	end

	applyAll = function(instant, skipTheme)
		AnimName = Settings.anim
		SPEED = Settings.animSpeed / 100
		if not skipTheme then
			applyTheme(currentColors(), instant)
			refreshPresetUI()
			applyLogo()
		end
		watermark.Visible = Settings.watermark
		Wings.setType(Settings.wingType)
		BLUR_SIZE = Settings.blur and 18 or 0
		if isOpen then tween(blur, 0.3, { Size = BLUR_SIZE }) end
	end

	--// РџРѕРїР°Рї РЅР°СЃС‚СЂРѕРµРє Custom wings (РїСЂР°РІС‹Р№ РєР»РёРє РїРѕ С‡РµРєР±РѕРєСЃСѓ)
	local WING_TYPES = { "Normal", "Bacon" }
	local wingPopup = new("Frame", {
		Name = "WingsSettings", Size = UDim2.fromOffset(340, 176), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(702, 270), BackgroundColor3 = Theme.Panel, ZIndex = 50, Visible = false, Parent = body,
	}, { corner(14), stroke() })
	label({ Text = spaced("Custom wings"), Font = Enum.Font.GothamMedium, TextSize = 16, Size = UDim2.fromOffset(240, 30), Position = UDim2.fromOffset(PAD, 11), Parent = wingPopup })
	divider(wingPopup, 48)
	local wingClose = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -PAD - 28 + 6, 0, 12), BackgroundTransparency = 1, Parent = wingPopup })
	for _, rot in ipairs({ 45, -45 }) do
		new("Frame", { Size = UDim2.fromOffset(14, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = rot, BackgroundColor3 = Theme.Dim, BorderSizePixel = 0, Parent = wingClose }, { corner(1) })
	end
	label({ Text = "Wing type", Size = UDim2.fromOffset(120, 24), Position = UDim2.fromOffset(PAD, 72), Parent = wingPopup })
	local wingDD = dropdown(wingPopup, 340 - PAD - 190, 84, 190, WING_TYPES, Settings.wingType, function(name)
		Settings.wingType = name
		Wings.setType(name)
		queueSave()
	end)
	function setWingPopup(v)
		if openDropdown then openDropdown.close() end
		wingPopup.Visible = v
	end
	WingsUI.toggle = function() setWingPopup(not wingPopup.Visible) end
	wingClose.MouseButton1Click:Connect(function() setWingPopup(false) end)
	local wingPopConn = RunService.RenderStepped:Connect(function()
		if wingPopup.Visible and (currentTab ~= "Visual" or not isOpen) then setWingPopup(false) end
	end)
	gui.Destroying:Connect(function() wingPopConn:Disconnect() end)

	function syncUI()
		modeDD.set(Settings.logoMode)
		showGroup()
		textBox.Text = Settings.logoText
		fileBox.Text = Settings.logoFile
		fileDD.set(Settings.logoFile ~= "" and basename(Settings.logoFile) or "Select file...")
		setSize(Settings.logoSize)
		setWm(Settings.watermark)
		setBlur(Settings.blur)
		animDD.set(Settings.anim)
		letterDD.set(Settings.logoAnim)
		wingDD.set(Settings.wingType)
		setSpeed(Settings.animSpeed)
		syncAccentSliders()
	end

	resetBtn.MouseButton1Click:Connect(function()
		for k, v in pairs(DEFAULTS) do Settings[k] = v end
		syncUI()
		applyAll(false)
		queueSave()
	end)

	syncUI()
	applyAll(true)

refresh()
selectTab("SUK", true)
TweenService:Create(watermark, info(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = WM_POS }):Play()
setOpen(true)
return { Gui = gui, Callbacks = Callbacks, Features = Features, Selected = selected, Refresh = refresh, SelectTab = selectTab, SetOpen = setOpen }

