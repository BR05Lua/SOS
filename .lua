--[[
    SOS HUD
    BR05 Smooth Superman Flight Menu (glass UI + tabs + scroll)

    PC:
      - Toggle menu: H (changeable in UI) -> collapses/expands from top with arrow
      - Toggle fly:  F (changeable in UI)
      - Move: WASD + Q/E

    Mobile:
      - Bottom-right button: Fly
      - Menu uses the top arrow to collapse/expand

    Note about animation IDs:
      Animation IDs must be a Published Marketplace/Catalog EMOTE assetId from the Creator Store.
      If you paste random IDs, it can fail.
      Copy and paste the ID from the Creator Store emote link / chosen emote.
      It will not work with normal Marketplace IDs.

    Saving:
      This script saves your IDs and keybinds locally using Player Attributes (survives respawn).
      True cross-session saving (leaving + rejoining) cannot be done safely from a client-only script.
      That requires a server DataStore (which needs a separate server script).

    R15: Uses Float/Fly animations with smooth switching.
    R6: Smooth flight only (no anims).

    Added:
      - Anim Packs tab (with pop-down categories: Roblox Anims, Unreleased Anims, Custom)

    Changes (per request):
      - Added FLOAT_ID reset button too
      - Packs tab renamed to "Anim Packs"
      - Inside Anim Packs: dropdown sections
        * Unreleased: Cowboy, Princess, ZombieFE, Confident, Ghost, Patrol, Popstar, Sneaky
        * Roblox Anims: everything else
        * Custom: blank for future
]]

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local DEBUG = false
local function dprint(...)
	if DEBUG then
		print("[SOS HUD DEBUG]", ...)
	end
end

local DEFAULT_FLOAT_ID = "rbxassetid://88138077358201"
local DEFAULT_FLY_ID   = "rbxassetid://131217573719045"

local ATTR_FLOAT_ID = "SOS_FLOAT_ID"
local ATTR_FLY_ID   = "SOS_FLY_ID"
local ATTR_MENU_KEY = "SOS_MENU_KEY"
local ATTR_FLY_KEY  = "SOS_FLY_KEY"

local VEL_LERP_RATE = 5.25
local ROT_LERP_RATE = 5.25

local TILT_MOVING_DEG = 85
local TILT_IDLE_DEG = 10

local THEME_RED = Color3.fromRGB(180, 30, 30)
local GLASS_BG = Color3.fromRGB(18, 18, 18)

local SOS_DISCORD_LINK = "https://discord.gg/cacg7kvX"

local MIC_UP_PLACE_IDS = {
	[6884319169] = true,
	[15546218972] = true,
}

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local character
local humanoid
local rootPart

local flying = false
local flySpeed = 200
local maxFlySpeed = 1000
local minFlySpeed = 1

local menuToggleKey = Enum.KeyCode.H
local flightToggleKey = Enum.KeyCode.F

local moveInput = Vector3.new(0, 0, 0)
local verticalInput = 0

local bodyGyro
local bodyVel
local currentVelocity = Vector3.new(0, 0, 0)
local currentGyroCFrame

local rightShoulder
local defaultShoulderC0

local originalRunSoundStates = {}

local isR15 = false
local animator
local floatTrack
local flyTrack
local currentFloatId = DEFAULT_FLOAT_ID
local currentFlyId = DEFAULT_FLY_ID

local gui
local mainFrame
local titleBar
local tabsScroll
local tabsRow
local contentHolder
local tabFrames = {}
local activeTab = "Info"

local mobileButtonsGui
local mobileFlyBtn

local MENU_EXPANDED_H = 300
local MENU_COLLAPSED_H = 32
local menuCollapsed = false
local arrowBtn

--------------------------------------------------------------------
-- UTIL
--------------------------------------------------------------------
local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function safeDestroy(inst)
	if inst and inst.Parent then
		inst:Destroy()
	end
end

local function isTouchDevice()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getR15()
	if not character then return false end
	return character:FindFirstChild("UpperTorso") ~= nil
end

local function tryNotify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "SOS HUD",
			Text = text,
			Duration = 2
		})
	end)
end

local function copyToClipboard(text)
	local ok = false
	if type(setclipboard) == "function" then
		ok = pcall(function() setclipboard(text) end)
	elseif type(toclipboard) == "function" then
		ok = pcall(function() toclipboard(text) end)
	end
	return ok
end

local function keyFromName(name)
	if type(name) ~= "string" then return nil end
	local kc = Enum.KeyCode[name]
	if kc then return kc end
	return nil
end

local function loadSettingsFromAttributes()
	local floatId = LocalPlayer:GetAttribute(ATTR_FLOAT_ID)
	local flyId = LocalPlayer:GetAttribute(ATTR_FLY_ID)
	local menuKeyName = LocalPlayer:GetAttribute(ATTR_MENU_KEY)
	local flyKeyName = LocalPlayer:GetAttribute(ATTR_FLY_KEY)

	if type(floatId) == "string" and floatId ~= "" then
		currentFloatId = floatId
	end
	if type(flyId) == "string" and flyId ~= "" then
		currentFlyId = flyId
	end

	local mk = keyFromName(menuKeyName)
	local fk = keyFromName(flyKeyName)
	if mk then menuToggleKey = mk end
	if fk then flightToggleKey = fk end
end

local function saveSettingsToAttributes()
	LocalPlayer:SetAttribute(ATTR_FLOAT_ID, currentFloatId)
	LocalPlayer:SetAttribute(ATTR_FLY_ID, currentFlyId)
	LocalPlayer:SetAttribute(ATTR_MENU_KEY, menuToggleKey.Name)
	LocalPlayer:SetAttribute(ATTR_FLY_KEY, flightToggleKey.Name)
end

--------------------------------------------------------------------
-- CHARACTER
--------------------------------------------------------------------
local function getCharacter()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	isR15 = getR15()

	rightShoulder = nil
	defaultShoulderC0 = nil
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == "Right Shoulder" then
			rightShoulder = d
			defaultShoulderC0 = d.C0
			break
		end
	end

	animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
end

--------------------------------------------------------------------
-- FOOTSTEP SOUND CONTROL
--------------------------------------------------------------------
local function cacheAndMuteRunSounds()
	if not character then return end
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Sound") then
			local nameLower = string.lower(desc.Name)
			if nameLower:find("run") or nameLower:find("walk") or nameLower:find("footstep") then
				if not originalRunSoundStates[desc] then
					originalRunSoundStates[desc] = {
						Volume = desc.Volume,
						Playing = desc.Playing,
					}
				end
				desc.Volume = 0
				desc.Playing = false
			end
		end
	end
end

local function restoreRunSounds()
	for sound, data in pairs(originalRunSoundStates) do
		if sound and sound.Parent then
			sound.Volume = data.Volume or 0.5
			if data.Playing then
				sound.Playing = true
			end
		end
	end
end

--------------------------------------------------------------------
-- ANIM LOADING / SWITCHING
--------------------------------------------------------------------
local function stopAndNilTracks()
	if floatTrack then pcall(function() floatTrack:Stop(0.15) end) end
	if flyTrack then pcall(function() flyTrack:Stop(0.15) end) end
	floatTrack = nil
	flyTrack = nil
end

local function loadTracks()
	stopAndNilTracks()
	if not humanoid or not animator then return end
	if not isR15 then return end

	local floatAnim = Instance.new("Animation")
	floatAnim.AnimationId = currentFloatId

	local flyAnim = Instance.new("Animation")
	flyAnim.AnimationId = currentFlyId

	local ok1, t1 = pcall(function() return animator:LoadAnimation(floatAnim) end)
	if ok1 and t1 then
		floatTrack = t1
		floatTrack.Priority = Enum.AnimationPriority.Action
		floatTrack.Looped = true
	end

	local ok2, t2 = pcall(function() return animator:LoadAnimation(flyAnim) end)
	if ok2 and t2 then
		flyTrack = t2
		flyTrack.Priority = Enum.AnimationPriority.Action
		flyTrack.Looped = true
	end
end

local function playFloat()
	if not isR15 then return end
	if not floatTrack then return end
	if flyTrack and flyTrack.IsPlaying then pcall(function() flyTrack:Stop(0.12) end) end
	if not floatTrack.IsPlaying then pcall(function() floatTrack:Play(0.12) end) end
end

local function playFly()
	if not isR15 then return end
	if not flyTrack then return end
	if floatTrack and floatTrack.IsPlaying then pcall(function() floatTrack:Stop(0.12) end) end
	if not flyTrack.IsPlaying then pcall(function() flyTrack:Play(0.12) end) end
end

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
local function updateMovementInput()
	local dir = Vector3.new(0, 0, 0)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir + Vector3.new(0, 0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir + Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Vector3.new(1, 0, 0) end

	moveInput = dir

	local vert = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.E) then vert = vert + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) then vert = vert - 1 end
	verticalInput = vert
end

--------------------------------------------------------------------
-- FLIGHT CORE
--------------------------------------------------------------------
local function startFlying()
	if flying or not humanoid or not rootPart then return end
	flying = true

	humanoid.PlatformStand = true
	cacheAndMuteRunSounds()

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.P = 1e5
	bodyGyro.CFrame = rootPart.CFrame
	bodyGyro.Parent = rootPart

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVel.Velocity = Vector3.new()
	bodyVel.Parent = rootPart

	currentVelocity = Vector3.new(0, 0, 0)
	currentGyroCFrame = rootPart.CFrame

	loadTracks()
	playFloat()
end

local function stopFlying()
	if not flying then return end
	flying = false

	if floatTrack then pcall(function() floatTrack:Stop(0.15) end) end
	if flyTrack then pcall(function() flyTrack:Stop(0.15) end) end

	safeDestroy(bodyGyro); bodyGyro = nil
	safeDestroy(bodyVel); bodyVel = nil

	if humanoid then
		humanoid.PlatformStand = false
	end
	if rightShoulder and defaultShoulderC0 then
		rightShoulder.C0 = defaultShoulderC0
	end

	restoreRunSounds()
end

--------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not flying or not rootPart or not Camera or not bodyGyro or not bodyVel then return end

	updateMovementInput()

	local camCF = Camera.CFrame
	local camLook = camCF.LookVector
	local camRight = camCF.RightVector

	local moveDir = Vector3.new(0, 0, 0)
	moveDir = moveDir + camLook * (-moveInput.Z)
	moveDir = moveDir + camRight * (moveInput.X)
	moveDir = moveDir + Vector3.new(0, verticalInput, 0)

	local moveMagnitude = moveDir.Magnitude
	local moving = moveMagnitude > 0.05
	if moveMagnitude > 0 then
		moveDir = moveDir.Unit
	end

	if not moving then
		local flat = Vector3.new(camLook.X, 0, camLook.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		moveDir = flat.Unit
	end

	local targetVel = (moving and (moveDir * flySpeed)) or Vector3.new(0, 0, 0)
	local aVel = math.clamp(dt * VEL_LERP_RATE, 0, 1)
	currentVelocity = currentVelocity:Lerp(targetVel, aVel)
	bodyVel.Velocity = currentVelocity

	if isR15 then
		if moving then
			playFly()
		else
			playFloat()
		end
	end

	local baseCF = CFrame.lookAt(rootPart.Position, rootPart.Position + moveDir)
	local tiltDeg = moving and TILT_MOVING_DEG or TILT_IDLE_DEG
	local targetCF = baseCF * CFrame.Angles(-math.rad(tiltDeg), 0, 0)

	if not currentGyroCFrame then currentGyroCFrame = targetCF end
	local aRot = math.clamp(dt * ROT_LERP_RATE, 0, 1)
	currentGyroCFrame = currentGyroCFrame:Lerp(targetCF, aRot)
	bodyGyro.CFrame = currentGyroCFrame

	if rightShoulder and defaultShoulderC0 and moving then
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso then
			local relDir = torso.CFrame:VectorToObjectSpace((moving and moveDir) or camLook.Unit)
			local yaw = math.atan2(-relDir.Z, relDir.X)
			local pitch = math.asin(relDir.Y)
			local armCF =
				CFrame.new() *
				CFrame.Angles(0, -math.pi/2, 0) *
				CFrame.Angles(-pitch * 0.7, 0, -yaw * 0.5)
			rightShoulder.C0 = defaultShoulderC0 * armCF
		end
	elseif rightShoulder and defaultShoulderC0 then
		rightShoulder.C0 = rightShoulder.C0:Lerp(defaultShoulderC0, aRot)
	end
end)

--------------------------------------------------------------------
-- ANIMATION PACK CHANGER (Anim Packs tab uses this)
--------------------------------------------------------------------
local function StopAllAnimations(h)
	for _, track in ipairs(h:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
end

local AnimationPacks = {
	Vampire = { Idle1=1083445855, Idle2=1083450166, Walk=1083473930, Run=1083462077, Jump=1083455352, Climb=1083439238, Fall=1083443587 },
	Hero = { Idle1=616111295, Idle2=616113536, Walk=616122287, Run=616117076, Jump=616115533, Climb=616104706, Fall=616108001 },
	ZombieClassic = { Idle1=616158929, Idle2=616160636, Walk=616168032, Run=616163682, Jump=616161997, Climb=616156119, Fall=616157476 },
	Mage = { Idle1=707742142, Idle2=707855907, Walk=707897309, Run=707861613, Jump=707853694, Climb=707826056, Fall=707829716 },
	Ghost = { Idle1=616006778, Idle2=616008087, Walk=616010382, Run=616013216, Jump=616008936, Climb=616003713, Fall=616005863 },
	Elder = { Idle1=845397899, Idle2=845400520, Walk=845403856, Run=845386501, Jump=845398858, Climb=845392038, Fall=845396048 },
	Levitation = { Idle1=616006778, Idle2=616008087, Walk=616013216, Run=616010382, Jump=616008936, Climb=616003713, Fall=616005863 },
	Astronaut = { Idle1=891621366, Idle2=891633237, Walk=891667138, Run=891636393, Jump=891627522, Climb=891609353, Fall=891617961 },
	Ninja = { Idle1=656117400, Idle2=656118341, Walk=656121766, Run=656118852, Jump=656117878, Climb=656114359, Fall=656115606 },
	Werewolf = { Idle1=1083195517, Idle2=1083214717, Walk=1083178339, Run=1083216690, Jump=1083218792, Climb=1083182000, Fall=1083189019 },
	Cartoon = { Idle1=742637544, Idle2=742638445, Walk=742640026, Run=742638842, Jump=742637942, Climb=742636889, Fall=742637151 },
	Pirate = { Idle1=750781874, Idle2=750782770, Walk=750785693, Run=750783738, Jump=750782230, Climb=750779899, Fall=750780242 },
	Sneaky = { Idle1=1132473842, Idle2=1132477671, Walk=1132510133, Run=1132494274, Jump=1132489853, Climb=1132461372, Fall=1132469004 },
	Toy = { Idle1=782841498, Idle2=782845736, Walk=782843345, Run=782842708, Jump=782847020, Climb=782843869, Fall=782846423 },
	Knight = { Idle1=657595757, Idle2=657568135, Walk=657552124, Run=657564596, Jump=658409194, Climb=658360781, Fall=657600338 },
	Confident = { Idle1=1069977950, Idle2=1069987858, Walk=1070017263, Run=1070001516, Jump=1069984524, Climb=1069946257, Fall=1069973677 },
	Popstar = { Idle1=1212900985, Idle2=1212900985, Walk=1212980338, Run=1212980348, Jump=1212954642, Climb=1213044953, Fall=1212900995 },
	Princess = { Idle1=941003647, Idle2=941013098, Walk=941028902, Run=941015281, Jump=941008832, Climb=940996062, Fall=941000007 },
	Cowboy = { Idle1=1014390418, Idle2=1014398616, Walk=1014421541, Run=1014401683, Jump=1014394726, Climb=1014380606, Fall=1014384571 },
	Patrol = { Idle1=1149612882, Idle2=1150842221, Walk=1151231493, Run=1150967949, Jump=1150944216, Climb=1148811837, Fall=1148863382 },
	ZombieFE = { Idle1=3489171152, Idle2=3489171152, Walk=3489174223, Run=3489173414, Jump=616161997, Climb=616156119, Fall=616157476 },
}

local function ApplyAnimationPack(packName)
	local pack = AnimationPacks[packName]
	if not pack then
		warn("Unknown animation pack:", packName)
		return
	end

	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid")
	local animate = char:FindFirstChild("Animate")

	if not animate then
		warn("No Animate script found in character. This expects the standard Roblox Animate setup.")
		return
	end

	animate.Disabled = true
	StopAllAnimations(hum)

	local idle = animate:FindFirstChild("idle")
	local walk = animate:FindFirstChild("walk")
	local run = animate:FindFirstChild("run")
	local jump = animate:FindFirstChild("jump")
	local climb = animate:FindFirstChild("climb")
	local fall = animate:FindFirstChild("fall")

	if idle and idle:FindFirstChild("Animation1") then idle.Animation1.AnimationId = "rbxassetid://" .. pack.Idle1 end
	if idle and idle:FindFirstChild("Animation2") then idle.Animation2.AnimationId = "rbxassetid://" .. pack.Idle2 end
	if walk and walk:FindFirstChild("WalkAnim") then walk.WalkAnim.AnimationId = "rbxassetid://" .. pack.Walk end
	if run and run:FindFirstChild("RunAnim") then run.RunAnim.AnimationId = "rbxassetid://" .. pack.Run end
	if jump and jump:FindFirstChild("JumpAnim") then jump.JumpAnim.AnimationId = "rbxassetid://" .. pack.Jump end
	if climb and climb:FindFirstChild("ClimbAnim") then climb.ClimbAnim.AnimationId = "rbxassetid://" .. pack.Climb end
	if fall and fall:FindFirstChild("FallAnim") then fall.FallAnim.AnimationId = "rbxassetid://" .. pack.Fall end

	animate.Disabled = false
	hum:ChangeState(Enum.HumanoidStateType.Running)
end

local LastPack = nil
local function SetPack(packName)
	LastPack = packName
	ApplyAnimationPack(packName)
end

LocalPlayer.CharacterAdded:Connect(function()
	if LastPack then
		task.wait(0.1)
		ApplyAnimationPack(LastPack)
	end
end)

_G.SetAnimationPack = SetPack

--------------------------------------------------------------------
-- UI HELPERS
--------------------------------------------------------------------
local function makeTextLabel(parent, text, size, bold)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = size or 18
	lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Parent = parent
	if bold and lbl.FontFace then
		pcall(function() lbl.FontFace.Weight = Enum.FontWeight.Bold end)
	end
	return lbl
end

local function makeTextButton(parent, text)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btn.BackgroundTransparency = 0.12
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME_RED
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	btn.Parent = parent
	return btn
end

local function makeGlassFrame(parent)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = GLASS_BG
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	f.Parent = parent

	local grad = Instance.new("UIGradient")
	grad.Rotation = 25
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(18, 18, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 28, 28)),
	})
	grad.Parent = f

	local shine = Instance.new("ImageLabel")
	shine.BackgroundTransparency = 1
	shine.Image = "rbxassetid://8992230677"
	shine.ImageTransparency = 0.75
	shine.ScaleType = Enum.ScaleType.Crop
	shine.Size = UDim2.new(1, 0, 1, 0)
	shine.Parent = f

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = f

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME_RED
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = f

	return f
end

local function setTab(name)
	activeTab = name
	for tabName, frame in pairs(tabFrames) do
		frame.Visible = (tabName == name)
	end
end

local function makeScrollingTab(parent)
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.new(1, 0, 1, 0)
	sf.ScrollBarThickness = 6
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.Parent = parent

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = sf

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = sf

	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		sf.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 14)
	end)

	return sf, list
end

local function makeDropdownSection(parentSF, titleText)
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -6, 0, 30)
	header.Parent = parentSF

	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Padding = UDim.new(0, 10)
	hl.Parent = header

	local btn = makeTextButton(header, "˅")
	btn.Size = UDim2.new(0, 34, 0, 24)

	local title = makeTextLabel(header, titleText, 16, true)
	title.Size = UDim2.new(1, -60, 0, 20)

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -6, 0, 0)
	container.ClipsDescendants = true
	container.Parent = parentSF

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = container

	local expanded = true

	local function updateSizeInstant()
		container.Size = expanded and UDim2.new(1, -6, 0, list.AbsoluteContentSize.Y) or UDim2.new(1, -6, 0, 0)
		btn.Text = expanded and "˅" or "˄"
	end

	local function updateSizeTween()
		local targetY = expanded and list.AbsoluteContentSize.Y or 0
		btn.Text = expanded and "˅" or "˄"
		tween(container, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Size = UDim2.new(1, -6, 0, targetY)
		})
	end

	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if expanded then
			updateSizeInstant()
		end
	end)

	btn.MouseButton1Click:Connect(function()
		expanded = not expanded
		updateSizeTween()
	end)

	task.defer(updateSizeInstant)

	return container
end

--------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------
local function createUI()
	loadSettingsFromAttributes()

	if gui then gui:Destroy() end
	if mobileButtonsGui then mobileButtonsGui:Destroy(); mobileButtonsGui = nil end

	gui = Instance.new("ScreenGui")
	gui.Name = "SOS_HUD_FlightUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	mainFrame = makeGlassFrame(gui)
	mainFrame.Name = "FlightMenu"
	mainFrame.Size = UDim2.new(0, 390, 0, MENU_EXPANDED_H)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0, 10)
	mainFrame.Active = true

	titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	titleBar.BackgroundTransparency = 0.08
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.Parent = mainFrame

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 14)
	tCorner.Parent = titleBar

	arrowBtn = makeTextButton(titleBar, "˄")
	arrowBtn.Size = UDim2.new(0, 34, 0, 22)
	arrowBtn.Position = UDim2.new(0, 10, 0.5, -11)
	arrowBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -110, 1, 0)
	titleLabel.Position = UDim2.new(0, 55, 0, 0)
	titleLabel.Text = "SOS HUD"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Parent = titleBar

	tabsScroll = Instance.new("ScrollingFrame")
	tabsScroll.BackgroundTransparency = 1
	tabsScroll.BorderSizePixel = 0
	tabsScroll.Size = UDim2.new(1, -20, 0, 30)
	tabsScroll.Position = UDim2.new(0, 10, 0, 38)
	tabsScroll.ScrollBarThickness = 0
	tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabsScroll.Parent = mainFrame

	tabsRow = Instance.new("Frame")
	tabsRow.BackgroundTransparency = 1
	tabsRow.Size = UDim2.new(0, 0, 1, 0)
	tabsRow.Parent = tabsScroll

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabsRow

	tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabsRow.Size = UDim2.new(0, tabLayout.AbsoluteContentSize.X, 1, 0)
		tabsScroll.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X, 0, 0)
	end)

	local function addTabButton(tabName, order)
		local b = makeTextButton(tabsRow, tabName)
		b.LayoutOrder = order
		b.Size = UDim2.new(0, 120, 0, 26)
		b.MouseButton1Click:Connect(function()
			setTab(tabName)
		end)
		return b
	end

	contentHolder = Instance.new("Frame")
	contentHolder.BackgroundTransparency = 1
	contentHolder.Size = UDim2.new(1, -20, 1, -78)
	contentHolder.Position = UDim2.new(0, 10, 0, 70)
	contentHolder.Parent = mainFrame

	local tabOrder = 1
	addTabButton("Info", tabOrder); tabOrder += 1
	addTabButton("Fly", tabOrder); tabOrder += 1
	addTabButton("Anim Packs", tabOrder); tabOrder += 1
	addTabButton("Camera", tabOrder); tabOrder += 1
	addTabButton("Lighting", tabOrder); tabOrder += 1
	addTabButton("Server Stuff", tabOrder); tabOrder += 1
	addTabButton("Client", tabOrder); tabOrder += 1

	local showMicUp = MIC_UP_PLACE_IDS[game.PlaceId] == true
	if showMicUp then
		addTabButton("Mic Up", tabOrder); tabOrder += 1
	end

	-- INFO TAB
	local infoFrame = (select(1, makeScrollingTab(contentHolder)))
	tabFrames["Info"] = infoFrame

	local infoHeader = makeTextLabel(infoFrame, "Sins of Scripting HUD", 16, true)
	infoHeader.LayoutOrder = 1
	infoHeader.Size = UDim2.new(1, -6, 0, 20)
	infoHeader.TextXAlignment = Enum.TextXAlignment.Center

	local infoText = Instance.new("TextLabel")
	infoText.BackgroundTransparency = 1
	infoText.Size = UDim2.new(1, -6, 0, 170)
	infoText.TextXAlignment = Enum.TextXAlignment.Left
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.Font = Enum.Font.Gotham
	infoText.TextSize = 14
	infoText.TextColor3 = Color3.fromRGB(220, 220, 220)
	infoText.TextWrapped = true
	infoText.LayoutOrder = 2
	infoText.Parent = infoFrame

	local discordBtn = makeTextButton(infoFrame, "Press to copy (SOS Server)")
	discordBtn.LayoutOrder = 3
	discordBtn.Size = UDim2.new(1, -6, 0, 30)

	local discordHint = Instance.new("TextLabel")
	discordHint.BackgroundTransparency = 1
	discordHint.Size = UDim2.new(1, -6, 0, 36)
	discordHint.Text = "Press the button to copy this link\n" .. SOS_DISCORD_LINK
	discordHint.Font = Enum.Font.Gotham
	discordHint.TextSize = 13
	discordHint.TextColor3 = Color3.fromRGB(200, 200, 200)
	discordHint.TextXAlignment = Enum.TextXAlignment.Center
	discordHint.TextYAlignment = Enum.TextYAlignment.Center
	discordHint.TextWrapped = true
	discordHint.LayoutOrder = 4
	discordHint.Parent = infoFrame

	local function refreshInfoText()
		infoText.Text =
			"Controls:\n" ..
			"PC: " .. menuToggleKey.Name .. " = Menu • " .. flightToggleKey.Name .. " = Fly\n" ..
			"Move: WASD + Q/E\n\n" ..
			"Animation IDs must be a Published Marketplace/Catalog EMOTE assetId from the Creator Store.\n" ..
			"(If you paste random IDs, it can fail.)\n" ..
			"(Copy and paste the ID in the link of the Creator Store version or the chosen Emote.)\n" ..
			"(Won't work with normal Marketplace ID.)"
	end
	refreshInfoText()

	discordBtn.MouseButton1Click:Connect(function()
		local ok = copyToClipboard(SOS_DISCORD_LINK)
		if ok then
			discordBtn.Text = "Copied"
			tryNotify("Copied SOS Server link.")
			task.delay(1.0, function()
				if discordBtn and discordBtn.Parent then
					discordBtn.Text = "Press to copy (SOS Server)"
				end
			end)
		else
			discordBtn.Text = "Copy unsupported"
			tryNotify("Copy not supported here. Link shown on Info tab.")
			task.delay(1.2, function()
				if discordBtn and discordBtn.Parent then
					discordBtn.Text = "Press to copy (SOS Server)"
				end
			end)
		end
	end)

	-- FLY TAB
	local flyFrame = (select(1, makeScrollingTab(contentHolder)))
	flyFrame.Visible = false
	tabFrames["Fly"] = flyFrame

	local function makeRowLabelButton(parent, labelText, buttonText)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -6, 0, 30)
		row.Parent = parent

		local rLayout = Instance.new("UIListLayout")
		rLayout.FillDirection = Enum.FillDirection.Horizontal
		rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		rLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rLayout.Padding = UDim.new(0, 10)
		rLayout.Parent = row

		local lbl = makeTextLabel(row, labelText, 15, false)
		lbl.Size = UDim2.new(0, 150, 1, 0)

		local btn = makeTextButton(row, buttonText)
		btn.Size = UDim2.new(0, 140, 1, 0)

		return row, lbl, btn
	end

	local _, _, flyKeyBtn = makeRowLabelButton(flyFrame, "Flight Toggle Key:", flightToggleKey.Name)
	local _, _, menuKeyBtn = makeRowLabelButton(flyFrame, "Menu Toggle Key:", menuToggleKey.Name)

	local function makeIdRow(parent, label, startText)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -6, 0, 34)
		row.Parent = parent

		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Left
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 10)
		l.Parent = row

		local lbl = makeTextLabel(row, label, 15, false)
		lbl.Size = UDim2.new(0, 90, 1, 0)

		local box = Instance.new("TextBox")
		box.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		box.BackgroundTransparency = 0.15
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1, -110, 0, 28)
		box.Text = startText
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.Gotham
		box.TextSize = 14
		box.TextColor3 = Color3.fromRGB(235, 235, 235)
		box.Parent = row

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = box

		local s = Instance.new("UIStroke")
		s.Color = THEME_RED
		s.Thickness = 1
		s.Transparency = 0.35
		s.Parent = box

		return row, box
	end

	local _, floatBox = makeIdRow(flyFrame, "FLOAT_ID:", currentFloatId)
	local _, flyBox = makeIdRow(flyFrame, "FLY_ID:", currentFlyId)

	local applyBtn = makeTextButton(flyFrame, "Apply Animation IDs")
	applyBtn.Size = UDim2.new(1, -6, 0, 30)

	local resetFloatBtn = makeTextButton(flyFrame, "Reset FLOAT_ID to Default")
	resetFloatBtn.Size = UDim2.new(1, -6, 0, 30)

	local resetFlyBtn = makeTextButton(flyFrame, "Reset FLY_ID to Default")
	resetFlyBtn.Size = UDim2.new(1, -6, 0, 30)

	local resetAllBtn = makeTextButton(flyFrame, "Reset BOTH IDs to Default")
	resetAllBtn.Size = UDim2.new(1, -6, 0, 30)

	local speedRow = Instance.new("Frame")
	speedRow.BackgroundTransparency = 1
	speedRow.Size = UDim2.new(1, -6, 0, 52)
	speedRow.Parent = flyFrame

	local speedLabel = makeTextLabel(speedRow, "Fly Speed: " .. tostring(flySpeed), 15, false)
	speedLabel.Size = UDim2.new(1, 0, 0, 18)
	speedLabel.Position = UDim2.new(0, 0, 0, 0)

	local sliderBg = Instance.new("Frame")
	sliderBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	sliderBg.BorderSizePixel = 0
	sliderBg.Size = UDim2.new(1, 0, 0, 8)
	sliderBg.Position = UDim2.new(0, 0, 0, 32)
	sliderBg.Parent = speedRow

	local sliderBgCorner = Instance.new("UICorner")
	sliderBgCorner.CornerRadius = UDim.new(1, 0)
	sliderBgCorner.Parent = sliderBg

	local sliderFill = Instance.new("Frame")
	sliderFill.BackgroundColor3 = THEME_RED
	sliderFill.BorderSizePixel = 0
	sliderFill.Size = UDim2.new(0, 0, 1, 0)
	sliderFill.Parent = sliderBg

	local sliderFillCorner = Instance.new("UICorner")
	sliderFillCorner.CornerRadius = UDim.new(1, 0)
	sliderFillCorner.Parent = sliderFill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = sliderBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local function setSliderFromSpeed(v)
		local a = (v - minFlySpeed) / (maxFlySpeed - minFlySpeed)
		a = math.clamp(a, 0, 1)
		sliderFill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -7, 0.5, -7)
		speedLabel.Text = "Fly Speed: " .. tostring(math.floor(v))
	end
	setSliderFromSpeed(flySpeed)

	local sliderDragging = false
	local previewSpeed = flySpeed

	local function updatePreview(x)
		local a = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
		previewSpeed = minFlySpeed + (maxFlySpeed - minFlySpeed) * a
		setSliderFromSpeed(previewSpeed)
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliderDragging = true
			updatePreview(input.Position.X)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sliderDragging = false
					flySpeed = math.floor(previewSpeed)
					setSliderFromSpeed(flySpeed)
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updatePreview(input.Position.X)
		end
	end)

	applyBtn.MouseButton1Click:Connect(function()
		currentFloatId = floatBox.Text
		currentFlyId = flyBox.Text
		saveSettingsToAttributes()
		loadTracks()
		if flying then
			if currentVelocity.Magnitude > 0.5 then
				playFly()
			else
				playFloat()
			end
		end
	end)

	resetFloatBtn.MouseButton1Click:Connect(function()
		currentFloatId = DEFAULT_FLOAT_ID
		floatBox.Text = currentFloatId
		saveSettingsToAttributes()
		loadTracks()
		if flying and currentVelocity.Magnitude <= 0.5 then
			playFloat()
		end
	end)

	resetFlyBtn.MouseButton1Click:Connect(function()
		currentFlyId = DEFAULT_FLY_ID
		flyBox.Text = currentFlyId
		saveSettingsToAttributes()
		loadTracks()
		if flying and currentVelocity.Magnitude > 0.5 then
			playFly()
		end
	end)

	resetAllBtn.MouseButton1Click:Connect(function()
		currentFloatId = DEFAULT_FLOAT_ID
		currentFlyId = DEFAULT_FLY_ID
		floatBox.Text = currentFloatId
		flyBox.Text = currentFlyId
		saveSettingsToAttributes()
		loadTracks()
		if flying then
			if currentVelocity.Magnitude > 0.5 then
				playFly()
			else
				playFloat()
			end
		end
	end)

	local waitingFlight = false
	local waitingMenu = false

	flyKeyBtn.MouseButton1Click:Connect(function()
		waitingFlight = true
		waitingMenu = false
		flyKeyBtn.Text = "..."
	end)

	menuKeyBtn.MouseButton1Click:Connect(function()
		waitingMenu = true
		waitingFlight = false
		menuKeyBtn.Text = "..."
	end)

	-- ANIM PACKS TAB (with dropdown sections)
	local packsFrame = (select(1, makeScrollingTab(contentHolder)))
	packsFrame.Visible = false
	tabFrames["Anim Packs"] = packsFrame

	local packsHeader = makeTextLabel(packsFrame, "Anim Packs", 16, true)
	packsHeader.Size = UDim2.new(1, -6, 0, 20)
	packsHeader.TextXAlignment = Enum.TextXAlignment.Center

	local packsHint = Instance.new("TextLabel")
	packsHint.BackgroundTransparency = 1
	packsHint.Size = UDim2.new(1, -6, 0, 36)
	packsHint.Text = "Press a pack name to apply it."
	packsHint.Font = Enum.Font.Gotham
	packsHint.TextSize = 13
	packsHint.TextColor3 = Color3.fromRGB(200, 200, 200)
	packsHint.TextXAlignment = Enum.TextXAlignment.Center
	packsHint.TextYAlignment = Enum.TextYAlignment.Center
	packsHint.TextWrapped = true
	packsHint.Parent = packsFrame

	local unreleasedSet = {
		Cowboy = true,
		Princess = true,
		ZombieFE = true,
		Confident = true,
		Ghost = true,
		Patrol = true,
		Popstar = true,
		Sneaky = true,
	}

	local robloxContainer = makeDropdownSection(packsFrame, "Roblox Anims")
	local unreleasedContainer = makeDropdownSection(packsFrame, "Unreleased Anims")
	local customContainer = makeDropdownSection(packsFrame, "Custom (Soon)")

	-- Custom placeholder (blank)
	do
		local note = Instance.new("TextLabel")
		note.BackgroundTransparency = 1
		note.Size = UDim2.new(1, -6, 0, 24)
		note.Text = "Nothing here yet."
		note.Font = Enum.Font.Gotham
		note.TextSize = 14
		note.TextColor3 = Color3.fromRGB(200, 200, 200)
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextYAlignment = Enum.TextYAlignment.Center
		note.Parent = customContainer
	end

	local function addPackButton(parent, packName)
		local b = makeTextButton(parent, packName)
		b.Size = UDim2.new(1, -6, 0, 28)
		b.MouseButton1Click:Connect(function()
			SetPack(packName)
			tryNotify("Applied pack: " .. packName)
		end)
	end

	local allNames = {}
	for name in pairs(AnimationPacks) do
		table.insert(allNames, name)
	end
	table.sort(allNames)

	for _, name in ipairs(allNames) do
		if unreleasedSet[name] then
			addPackButton(unreleasedContainer, name)
		else
			addPackButton(robloxContainer, name)
		end
	end

	-- EMPTY TABS
	local function addEmptyTab(tabName)
		local f = (select(1, makeScrollingTab(contentHolder)))
		f.Visible = false
		tabFrames[tabName] = f

		local lbl = makeTextLabel(f, tabName, 16, true)
		lbl.Size = UDim2.new(1, -6, 0, 20)
		lbl.TextXAlignment = Enum.TextXAlignment.Center

		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.new(1, -6, 0, 30)
		sub.Text = "Coming soon."
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 14
		sub.TextColor3 = Color3.fromRGB(200, 200, 200)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		sub.TextYAlignment = Enum.TextYAlignment.Center
		sub.Parent = f
	end

	addEmptyTab("Camera")
	addEmptyTab("Lighting")
	addEmptyTab("Server Stuff")
	addEmptyTab("Client")

	-- MIC UP TAB (conditional)
	if showMicUp then
		local micFrame = (select(1, makeScrollingTab(contentHolder)))
		micFrame.Visible = false
		tabFrames["Mic Up"] = micFrame

		local micHeader = makeTextLabel(micFrame, "Mic Up", 16, true)
		micHeader.Size = UDim2.new(1, -6, 0, 20)
		micHeader.TextXAlignment = Enum.TextXAlignment.Center

		local msg = Instance.new("TextLabel")
		msg.BackgroundTransparency = 1
		msg.Size = UDim2.new(1, -6, 0, 140)
		msg.TextXAlignment = Enum.TextXAlignment.Left
		msg.TextYAlignment = Enum.TextYAlignment.Top
		msg.Font = Enum.Font.Gotham
		msg.TextSize = 14
		msg.TextColor3 = Color3.fromRGB(220, 220, 220)
		msg.TextWrapped = true
		msg.Text =
			"For those of you who play this game hopefully your not a P£D0 also dont be weird and enjoy this tab\n" ..
			"(Some Stuff Will Be Added Soon)"
		msg.Parent = micFrame
	end

	-- KEYBINDS / HOTKEYS
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		if waitingFlight then
			flightToggleKey = input.KeyCode
			flyKeyBtn.Text = flightToggleKey.Name
			waitingFlight = false
			saveSettingsToAttributes()
			refreshInfoText()
			return
		end

		if waitingMenu then
			menuToggleKey = input.KeyCode
			menuKeyBtn.Text = menuToggleKey.Name
			waitingMenu = false
			saveSettingsToAttributes()
			refreshInfoText()
			return
		end

		if input.KeyCode == menuToggleKey then
			menuCollapsed = not menuCollapsed
			arrowBtn:Activate()
		elseif input.KeyCode == flightToggleKey then
			if flying then stopFlying() else startFlying() end
		end
	end)

	local function setCollapsed(state)
		menuCollapsed = state
		arrowBtn.Text = menuCollapsed and "˅" or "˄"

		if menuCollapsed then
			tabsScroll.Visible = true
			contentHolder.Visible = true
			tween(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Size = UDim2.new(0, 390, 0, MENU_COLLAPSED_H)
			}).Completed:Connect(function()
				if menuCollapsed then
					tabsScroll.Visible = false
					contentHolder.Visible = false
				end
			end)
		else
			tabsScroll.Visible = true
			contentHolder.Visible = true
			tween(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Size = UDim2.new(0, 390, 0, MENU_EXPANDED_H)
			})
		end
	end

	arrowBtn.MouseButton1Click:Connect(function()
		setCollapsed(not menuCollapsed)
	end)

	setTab("Info")
	setCollapsed(false)

	if isTouchDevice() then
		mobileButtonsGui = Instance.new("ScreenGui")
		mobileButtonsGui.Name = "SOS_HUD_MobileButtons"
		mobileButtonsGui.ResetOnSpawn = false
		mobileButtonsGui.IgnoreGuiInset = true
		mobileButtonsGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(0, 140, 0, 60)
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -18, 1, -110)
		holder.Parent = mobileButtonsGui

		mobileFlyBtn = makeTextButton(holder, "Fly")
		mobileFlyBtn.Size = UDim2.new(1, 0, 0, 44)
		mobileFlyBtn.Position = UDim2.new(0, 0, 0, 8)

		mobileFlyBtn.MouseButton1Click:Connect(function()
			if flying then stopFlying() else startFlying() end
		end)
	end
end

--------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------
loadSettingsFromAttributes()
saveSettingsToAttributes()

getCharacter()
loadTracks()
createUI()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.25)
	getCharacter()
	loadTracks()
	if flying then
		stopFlying()
	end
end)

dprint("SOS HUD loaded for:", LocalPlayer.Name)
