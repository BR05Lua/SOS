--[[
    BR05 Smooth Superman Flight Menu (90-degree tilt, BR05-style UI)

    - Default:
        * Menu toggle: H
        * Flight toggle: F
    - UI:
        * BR05 theme: dark grey / black panel, red accents, rounded corners
        * Big red hint above menu that fades out smoothly
        * Smooth show/hide tween

    - Flight:
        * Only for whitelisted users
        * WASD = move relative to camera
        * Full 3D flying (not stuck to ground)
        * Character tilts 90° (opposite direction from before) when flying forward
        * Smooth, gradual movement + rotation
        * Walk/run sounds muted while flying, restored after
    If this script explodes, it's probably you. - me
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local cam = workspace.CurrentCamera

------------------------------------------------------------------
-- UI CONTROLS LABEL (NEW)
------------------------------------------------------------------
local pg = lp:WaitForChild("PlayerGui")
local controlGui = Instance.new("ScreenGui")
controlGui.Name = "BR05FlightControls"
controlGui.ResetOnSpawn = false
controlGui.Parent = pg

local controlLabel = Instance.new("TextLabel")
controlLabel.BackgroundTransparency = 1
controlLabel.Size = UDim2.new(0,400,0,30)
controlLabel.Position = UDim2.new(0.5,-200,0,0)
controlLabel.Text = "F = Fly   •   WASD + Q/E move"
controlLabel.TextColor3 = Color3.fromRGB(0,0,0)
controlLabel.Font = Enum.Font.GothamBold
controlLabel.TextSize = 18
controlLabel.TextStrokeTransparency = 1
controlLabel.Parent = controlGui
------------------------------------------------------------------


------------------------------------------------------------------
-- ANIMATIONS
------------------------------------------------------------------
local FLOAT_ID = "rbxassetid://88138077358201"
local FLY_ID   = "rbxassetid://131217573719045"

local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

local floatAnim = Instance.new("Animation")
floatAnim.AnimationId = FLOAT_ID
local floatTrack = animator:LoadAnimation(floatAnim)
floatTrack.Priority = Enum.AnimationPriority.Action
floatTrack.Looped = true

local flyAnim = Instance.new("Animation")
flyAnim.AnimationId = FLY_ID
local flyTrack = animator:LoadAnimation(flyAnim)
flyTrack.Priority = Enum.AnimationPriority.Action
flyTrack.Looped = true


------------------------------------------------------------------
-- FLIGHT
------------------------------------------------------------------
local flying = false
local BV, BG

local flySpeed = 200
local currentVel = Vector3.new()
local currentGyro = nil

local function startFlight()
	if flying then return end
	flying = true
	hum.PlatformStand = true

	BG = Instance.new("BodyGyro")
	BG.MaxTorque = Vector3.new(1e5,1e5,1e5)
	BG.P = 1e5
	BG.CFrame = root.CFrame
	BG.Parent = root

	BV = Instance.new("BodyVelocity")
	BV.MaxForce = Vector3.new(1e5,1e5,1e5)
	BV.Parent = root

	floatTrack:Play(0.3)
end

local function stopFlight()
	if not flying then return end
	flying = false
	
	floatTrack:Stop(0.3)
	flyTrack:Stop(0.3)

	hum.PlatformStand = false

	if BG then BG:Destroy() end
	if BV then BV:Destroy() end
end


------------------------------------------------------------------
-- UPDATE LOOP
------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not flying then return end
	
	local dir = Vector3.new()

	if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
	if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
	
	if UIS:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.new(0,1,0) end
	if UIS:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.new(0,1,0) end
	
	local moving = dir.Magnitude > 0
	
	if moving then
		dir = dir.Unit
		
		local targetVel = dir * flySpeed
		currentVel = currentVel:Lerp(targetVel, dt * 6)
		BV.Velocity = currentVel
		
		if not flyTrack.IsPlaying then
			floatTrack:Stop(0.25)
			flyTrack:Play(0.25)
		end
		
		local base = CFrame.lookAt(root.Position, root.Position + dir)
		local tilt = CFrame.Angles(-math.rad(80),0,0)
		local target = base * tilt

		if not currentGyro then currentGyro = target end
		currentGyro = currentGyro:Lerp(target, dt * 6)
		BG.CFrame = currentGyro

	else
		BV.Velocity = Vector3.new()

		if flyTrack.IsPlaying then
			flyTrack:Stop(0.25)
			floatTrack:Play(0.25)
		end
		
		local flat = Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z).Unit
		local idleCF = CFrame.lookAt(root.Position, root.Position + flat)
		local smallTilt = idleCF * CFrame.Angles(-math.rad(10),0,0)

		if not currentGyro then currentGyro = smallTilt end
		currentGyro = currentGyro:Lerp(smallTilt, dt * 6)
		BG.CFrame = currentGyro
	end
end)


------------------------------------------------------------------
-- KEYBIND
------------------------------------------------------------------
UIS.InputBegan:Connect(function(i,g)
	if g then return end
	if i.KeyCode == Enum.KeyCode.F then
		if flying then stopFlight() else startFlight() end
	end
end)

wait(1)
--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")
local cam = workspace.CurrentCamera

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- ANIMATIONS
------------------------------------------------------------------
local FLOAT_ID = "rbxassetid://119810104205917"
local FLY_ID   = "rbxassetid://86083258777928"

local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

local floatAnim = Instance.new("Animation")
floatAnim.AnimationId = FLOAT_ID
local floatTrack = animator:LoadAnimation(floatAnim)
floatTrack.Priority = Enum.AnimationPriority.Action
floatTrack.Looped = true

local flyAnim = Instance.new("Animation")
flyAnim.AnimationId = FLY_ID
local flyTrack = animator:LoadAnimation(flyAnim)
flyTrack.Priority = Enum.AnimationPriority.Action
flyTrack.Looped = true

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local character
local humanoid
local rootPart
local camera = workspace.CurrentCamera

local flying = false
local flySpeed = 100
local maxFlySpeed = 1000
local minFlySpeed = 1

local menuToggleKey = Enum.KeyCode.H
local flightToggleKey = Enum.KeyCode.F

local moveInput = Vector3.new(0, 0, 0)
local verticalInput = 0

local gui
local mainFrame
local dragging = false
local dragOffset
local hintLabel

local originalRunSoundStates = {}

local bodyGyro
local bodyVel

local currentVelocity = Vector3.new(0, 0, 0)
local currentGyroCFrame

local rightShoulder
local defaultShoulderC0

--------------------------------------------------------------------
-- UTIL
--------------------------------------------------------------------
local function getCharacter()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	-- Get right shoulder (R6 / R15)
	rightShoulder = nil
	defaultShoulderC0 = nil

	local function findRightShoulder()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("Motor6D") and part.Name == "Right Shoulder" then
				return part
			end
		end
		return nil
	end

	rightShoulder = findRightShoulder()
	if rightShoulder then
		defaultShoulderC0 = rightShoulder.C0
	end
end

local function tween(object, info, props)
	local t = TweenService:Create(object, info, props)
	t:Play()
	return t
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
-- FLIGHT
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
end

local function stopFlying()
	if not flying then return end
	flying = false

	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	if bodyVel then
		bodyVel:Destroy()
		bodyVel = nil
	end

	if humanoid then
		humanoid.PlatformStand = false
	end

	if rightShoulder and defaultShoulderC0 then
		rightShoulder.C0 = defaultShoulderC0
	end

	restoreRunSounds()
end

local function updateMovementInput()
	local dir = Vector3.new(0, 0, 0)
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		dir = dir + Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		dir = dir + Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		dir = dir + Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		dir = dir + Vector3.new(1, 0, 0)
	end

	moveInput = dir

	local vert = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.E) then
		vert = vert + 1 -- up
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		vert = vert - 1 -- down
	end
	verticalInput = vert
end

RunService.RenderStepped:Connect(function(dt)
	if not flying or not rootPart or not camera or not bodyGyro or not bodyVel then return end

	updateMovementInput()

	local camCF = camera.CFrame
	local camLook = camCF.LookVector
	local camRight = camCF.RightVector

	-- Full 3D directional movement
	local moveDir = Vector3.new(0, 0, 0)
	moveDir = moveDir + camLook * (-moveInput.Z) -- W/S
	moveDir = moveDir + camRight * (moveInput.X) -- A/D
	moveDir = moveDir + Vector3.new(0, verticalInput, 0) -- Q/E

	local moveMagnitude = moveDir.Magnitude
	if moveMagnitude > 0 then
		moveDir = moveDir.Unit
	end

	----------------------------------------------------------------
	-- VELOCITY (SMOOTH)
	----------------------------------------------------------------
	local targetVel = moveDir * flySpeed
	local alphaVel = math.clamp(dt * 6, 0, 1)
	currentVelocity = currentVelocity:Lerp(targetVel, alphaVel)
	bodyVel.Velocity = currentVelocity

	----------------------------------------------------------------
	-- ROTATION (WHOLE BODY TILTS 90° OPPOSITE DIRECTION)
	----------------------------------------------------------------
	local lookDir
	if moveMagnitude > 0.1 then
		lookDir = moveDir
	else
		local flatCam = Vector3.new(camLook.X, 0, camLook.Z)
		if flatCam.Magnitude < 0.01 then
			flatCam = Vector3.new(0, 0, -1)
		else
			flatCam = flatCam.Unit
		end
		lookDir = flatCam
	end

	local baseCF = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDir)

	-- Opposite tilt, 90 degrees when moving, small idle tilt otherwise
	local forwardTiltAngle
	if moveMagnitude > 0.1 then
		forwardTiltAngle = -math.rad(85)
	else
		forwardTiltAngle = -math.rad(10)
	end

	local forwardTilt = CFrame.Angles(forwardTiltAngle, 0, 0)
	local targetCF = baseCF * forwardTilt

	if not currentGyroCFrame then
		currentGyroCFrame = targetCF
	end

	local alphaRot = math.clamp(dt * 6, 0, 1)
	currentGyroCFrame = currentGyroCFrame:Lerp(targetCF, alphaRot)
	bodyGyro.CFrame = currentGyroCFrame

	----------------------------------------------------------------
	-- RIGHT ARM AIM
	----------------------------------------------------------------
	if rightShoulder and defaultShoulderC0 then
		if moveMagnitude > 0.1 then
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if torso then
				local relDir = torso.CFrame:VectorToObjectSpace(moveDir)

				local yaw = math.atan2(-relDir.Z, relDir.X)
				local pitch = math.asin(relDir.Y)

				local armCF =
					CFrame.new() *
					CFrame.Angles(0, -math.pi/2, 0) *
					CFrame.Angles(-pitch * 0.7, 0, -yaw * 0.5)

				rightShoulder.C0 = defaultShoulderC0 * armCF
			end
		else
			rightShoulder.C0 = rightShoulder.C0:Lerp(defaultShoulderC0, alphaRot)
		end
	end
end)

--------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == flightToggleKey then
		if flying then
			stopFlying()
		else
			startFlying()
		end
	elseif input.KeyCode == menuToggleKey then
		if mainFrame then
			local visible = mainFrame.Visible
			if visible then
				local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				tween(mainFrame, tweenInfo, {
					Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset, 0, 0),
					BackgroundTransparency = 0.3
				}).Completed:Connect(function()
					mainFrame.Visible = false
				end)
			else
				mainFrame.Visible = true
				mainFrame.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset, 0, 0)
				mainFrame.BackgroundTransparency = 0.3
				local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				tween(mainFrame, tweenInfo, {
					Size = UDim2.new(0, 320, 0, 220),
					BackgroundTransparency = 0
				})
			end
		end
	end
end)

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

	if bold then
		lbl.FontFace.Weight = Enum.FontWeight.Bold
	end

	return lbl
end

local function makeTextButton(parent, text)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	btn.BackgroundTransparency = 0.1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 30, 30)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Parent = parent
	return btn
end

--------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------
local function createUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "BR05_FlightUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	-- Big red hint above menu (like horror warning text)
	hintLabel = Instance.new("TextLabel")
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "H = Flight Menu • F = Fly"
	hintLabel.Font = Enum.Font.GothamBlack
	hintLabel.TextSize = 26
	hintLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
	hintLabel.TextStrokeTransparency = 0.4
	hintLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.6, 0, 0.35, -6)
	hintLabel.Parent = gui

	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Color3.fromRGB(255, 255, 255)
	hintStroke.Thickness = 1
	hintStroke.Parent = hintLabel

	-- Main frame (horror menu styled, but still draggable)
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "FlightMenu"
	mainFrame.Size = UDim2.new(0, 320, 0, 220)
	mainFrame.AnchorPoint = Vector2.new(0, 0)
	mainFrame.Position = UDim2.new(0.55, 0, 0.35, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	mainFrame.BackgroundTransparency = 0
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = false
	mainFrame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = mainFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(180, 30, 30)
	frameStroke.Thickness = 2
	frameStroke.Transparency = 0.2
	frameStroke.Parent = mainFrame

	local frameShadow = Instance.new("ImageLabel")
	frameShadow.Name = "Shadow"
	frameShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	frameShadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	frameShadow.Size = UDim2.new(1, 24, 1, 24)
	frameShadow.BackgroundTransparency = 1
	frameShadow.Image = "rbxassetid://5028857084" -- soft shadow
	frameShadow.ImageTransparency = 0.4
	frameShadow.ScaleType = Enum.ScaleType.Slice
	frameShadow.SliceCenter = Rect.new(24, 24, 276, 276)
	frameShadow.ZIndex = 0
	frameShadow.Parent = mainFrame

	-- Title bar strip
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleBar.BackgroundTransparency = 0.05
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 26)
	titleBar.Parent = mainFrame
	titleBar.ZIndex = 2

	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 12)
	titleBarCorner.Parent = titleBar

	-- This extra mask keeps only the top corners rounded
	local titleMask = Instance.new("Frame")
	titleMask.BackgroundTransparency = 1
	titleMask.Size = UDim2.new(1, 0, 0, 20)
	titleMask.Position = UDim2.new(0, 0, 1, -20)
	titleMask.Parent = titleBar

	local titleLabel = makeTextLabel(titleBar, "BR05 Flight Control", 18, true)
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 3

	local titleUnderline = Instance.new("Frame")
	titleUnderline.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	titleUnderline.BorderSizePixel = 0
	titleUnderline.Size = UDim2.new(1, -20, 0, 1)
	titleUnderline.Position = UDim2.new(0, 10, 1, -1)
	titleUnderline.Parent = mainFrame
	titleUnderline.ZIndex = 2

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.BackgroundTransparency = 1
	contentFrame.Size = UDim2.new(1, -20, 1, -40)
	contentFrame.Position = UDim2.new(0, 10, 0, 30)
	contentFrame.Parent = mainFrame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 0)
	padding.PaddingRight = UDim.new(0, 0)
	padding.Parent = contentFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = contentFrame

	-- Flight key row
	local flightKeyRow = Instance.new("Frame")
	flightKeyRow.BackgroundTransparency = 1
	flightKeyRow.Size = UDim2.new(1, 0, 0, 24)
	flightKeyRow.LayoutOrder = 1
	flightKeyRow.Parent = contentFrame

	local rowLayout1 = Instance.new("UIListLayout")
	rowLayout1.FillDirection = Enum.FillDirection.Horizontal
	rowLayout1.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowLayout1.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout1.Padding = UDim.new(0, 8) -- FIXED (UDim, not UDim2)
	rowLayout1.Parent = flightKeyRow

	local flightKeyLabel = makeTextLabel(flightKeyRow, "Flight Toggle Key:", 16, false)
	flightKeyLabel.Size = UDim2.new(0, 150, 1, 0)
	local flightKeyButton = makeTextButton(flightKeyRow, flightToggleKey.Name)
	flightKeyButton.Size = UDim2.new(0, 70, 1, 0)

	-- Menu key row
	local menuKeyRow = Instance.new("Frame")
	menuKeyRow.BackgroundTransparency = 1
	menuKeyRow.Size = UDim2.new(1, 0, 0, 24)
	menuKeyRow.LayoutOrder = 2
	menuKeyRow.Parent = contentFrame

	local rowLayout2 = Instance.new("UIListLayout")
	rowLayout2.FillDirection = Enum.FillDirection.Horizontal
	rowLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowLayout2.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout2.Padding = UDim.new(0, 8) -- FIXED (UDim, not UDim2)
	rowLayout2.Parent = menuKeyRow

	local menuKeyLabel = makeTextLabel(menuKeyRow, "Menu Toggle Key:", 16, false)
	menuKeyLabel.Size = UDim2.new(0, 150, 1, 0)
	local menuKeyButton = makeTextButton(menuKeyRow, menuToggleKey.Name)
	menuKeyButton.Size = UDim2.new(0, 70, 1, 0)

	-- Speed row (slider)
	local speedRow = Instance.new("Frame")
	speedRow.BackgroundTransparency = 1
	speedRow.Size = UDim2.new(1, 0, 0, 40)
	speedRow.LayoutOrder = 3
	speedRow.Parent = contentFrame

	local rowLayout3 = Instance.new("UIListLayout")
	rowLayout3.FillDirection = Enum.FillDirection.Vertical
	rowLayout3.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowLayout3.VerticalAlignment = Enum.VerticalAlignment.Top
	rowLayout3.Padding = UDim.new(0, 4)
	rowLayout3.Parent = speedRow

	local speedLabel = makeTextLabel(speedRow, "Fly Speed: " .. tostring(flySpeed), 16, false)
	speedLabel.Size = UDim2.new(1, 0, 0, 18)

	local sliderFrame = Instance.new("Frame")
	sliderFrame.BackgroundTransparency = 1
	sliderFrame.Size = UDim2.new(1, 0, 0, 16)
	sliderFrame.Parent = speedRow

	local sliderBg = Instance.new("Frame")
	sliderBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	sliderBg.BorderSizePixel = 0
	sliderBg.Size = UDim2.new(1, 0, 0, 8)
	sliderBg.Position = UDim2.new(0, 0, 0.5, -4)
	sliderBg.Parent = sliderFrame

	local sliderBgCorner = Instance.new("UICorner")
	sliderBgCorner.CornerRadius = UDim.new(1, 0)
	sliderBgCorner.Parent = sliderBg

	local sliderFill = Instance.new("Frame")
	sliderFill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	sliderFill.BorderSizePixel = 0
	sliderFill.Size = UDim2.new(0, 0, 1, 0)
	sliderFill.Parent = sliderBg

	local sliderFillCorner = Instance.new("UICorner")
	sliderFillCorner.CornerRadius = UDim.new(1, 0)
	sliderFillCorner.Parent = sliderFill

	local sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.new(0, 14, 0, 14)
	sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderKnob.BorderSizePixel = 0
	sliderKnob.Parent = sliderBg

	local sliderKnobCorner = Instance.new("UICorner")
	sliderKnobCorner.CornerRadius = UDim.new(1, 0)
	sliderKnobCorner.Parent = sliderKnob

	local sliderDragging = false
	local previewSpeed = flySpeed

	local function updateSliderVisualFromSpeed(speedValue)
		local alpha = (speedValue - minFlySpeed) / (maxFlySpeed - minFlySpeed)
		alpha = math.clamp(alpha, 0, 1)
		sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
		sliderKnob.Position = UDim2.new(alpha, -7, 0.5, -7)
		speedLabel.Text = "Fly Speed: " .. math.floor(speedValue)
	end

	updateSliderVisualFromSpeed(flySpeed)

	local function updatePreviewFromX(x)
		-- Safety: in case UI is being destroyed
		if not sliderBg or not sliderBg.Parent then return end

		local alpha = math.clamp(
			(x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X,
			0, 1
		)
		previewSpeed = minFlySpeed + (maxFlySpeed - minFlySpeed) * alpha
		updateSliderVisualFromSpeed(previewSpeed)
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not sliderBg or not sliderBg.Parent then return end
			sliderDragging = true
			updatePreviewFromX(input.Position.X)

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sliderDragging = false
					flySpeed = math.floor(previewSpeed)
					updateSliderVisualFromSpeed(flySpeed)
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updatePreviewFromX(input.Position.X)
		end
	end)

	-- Info text
	local infoLabel = makeTextLabel(
		contentFrame,
		"WASD + Q/E to move in 3D.\nIf you faceplant into a wall mid-flight, that's on you. - me",
		14,
		false
	)
	infoLabel.LayoutOrder = 4
	infoLabel.TextWrapped = true

	----------------------------------------------------------------
	-- DRAGGING (keep draggable, like a floating horror panel)
	----------------------------------------------------------------
	mainFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragOffset = input.Position - mainFrame.AbsolutePosition
		end
	end)

	mainFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
			input.UserInputType == Enum.UserInputType.Touch) then
			local newPos = input.Position - dragOffset
			mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
		end
	end)

	----------------------------------------------------------------
	-- BUTTON / KEYBIND LOGIC
	----------------------------------------------------------------
	local waitingForFlightKey = false
	local waitingForMenuKey = false

	flightKeyButton.MouseButton1Click:Connect(function()
		waitingForFlightKey = true
		waitingForMenuKey = false
		flightKeyButton.Text = "..."
	end)

	menuKeyButton.MouseButton1Click:Connect(function()
		waitingForMenuKey = true
		waitingForFlightKey = false
		menuKeyButton.Text = "..."
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if waitingForFlightKey then
				flightToggleKey = input.KeyCode
				flightKeyButton.Text = flightToggleKey.Name
				waitingForFlightKey = false
			elseif waitingForMenuKey then
				menuToggleKey = input.KeyCode
				menuKeyButton.Text = menuToggleKey.Name
				waitingForMenuKey = false
			end
		end
	end)

	----------------------------------------------------------------
	-- HINT FADE OUT (smooth)
	----------------------------------------------------------------
	task.delay(5, function()
		if hintLabel then
			local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(hintLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(1.3)
			if hintLabel then
				hintLabel:Destroy()
				hintLabel = nil
			end
		end
	end)
end

--------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------
getCharacter()
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	getCharacter()
	if flying then
		stopFlying()
	end
end)

createUI()

print("BR05 Flight Menu (horror-style UI) loaded for:", LocalPlayer.Name)
