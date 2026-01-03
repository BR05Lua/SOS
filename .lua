-- SOS HUD (The Sins Of Scripting)
-- Single LocalScript (StarterPlayerScripts recommended)
-- Update: Added mini Animations sub-tab inside Sins and Co/Owners tabs (Idle + Run only)
-- Future-proof: Added empty tables for Sins/CoOwners custom idles/runs so you can tell me later what to add where

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local DEBUG = false
local function dprint(...)
	if DEBUG then
		print("[SOS HUD]", ...)
	end
end

local DEFAULT_FLOAT_ID = "rbxassetid://88138077358201"
local DEFAULT_FLY_ID   = "rbxassetid://131217573719045"

local FLOAT_ID = DEFAULT_FLOAT_ID
local FLY_ID   = DEFAULT_FLY_ID

-- Menu key stays fixed, option removed from UI per request
local menuToggleKey = Enum.KeyCode.H

-- Fly keybind moved to Fly tab, can be disabled and unbound per request
local flightToggleKey = Enum.KeyCode.F
local flightBindEnabled = true

local waitingForFlyKeybind = false
local flyKeyBtnRef = nil
local flyBindToggleBtnRef = nil
local flyUnbindBtnRef = nil
local controlsInfoRef = nil

-- Flight feature enable (internal use, eg bhop), separate from keybind enable
local flightFeatureEnabled = true

local flySpeed = 150
local maxFlySpeed = 1000
local minFlySpeed = 1

local velocityLerpRate = 7.0
local rotationLerpRate = 7.0
local idleSlowdownRate = 2.6

local MOVING_TILT_DEG = 85
local IDLE_TILT_DEG = 10

local MOBILE_FLY_POS = UDim2.new(1, -170, 1, -190)
local MOBILE_FLY_SIZE = UDim2.new(0, 140, 0, 60)

local MICUP_PLACE_IDS = {
	["6884319169"] = true,
	["15546218972"] = true,
}

local DISCORD_LINK = "https://discord.gg/cacg7kvX"

local INTRO_SOUND_ID = "rbxassetid://1843492223"

local BUTTON_CLICK_SOUND_ID = "rbxassetid://111174530730534"
local BUTTON_CLICK_VOLUME = 0.6

local DEFAULT_FOV = nil
local DEFAULT_CAM_MIN_ZOOM = nil
local DEFAULT_CAM_MAX_ZOOM = nil
local DEFAULT_CAMERA_SUBJECT_MODE = "Humanoid"
local INFINITE_ZOOM = 1e9

local SETTINGS_FILE_PREFIX = "SOS_HUD_Settings_"
local SETTINGS_ATTR_NAME = "SOS_HUD_SETTINGS_JSON"

local VIP_GAMEPASSES = {
	951459548,
	28828491,
}

--------------------------------------------------------------------
-- ROLE GATES FOR TABS
--------------------------------------------------------------------
local OWNER_USERIDS = {
	[433636433] = true,
	[196988708] = true,
	[4926923208] = true,
}

local function isOwnerUser()
	if OWNER_USERIDS[LocalPlayer.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return LocalPlayer.UserId == game.CreatorId
	end
	return false
end

local function isSinsAllowed()
	if LocalPlayer.Name == "Sins" then
		return true
	end
	return isOwnerUser()
end

local function isCoOwnersAllowed()
	if LocalPlayer.Name == "Cinna" then
		return true
	end
	return isOwnerUser()
end

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local character
local humanoid
local rootPart

local flying = false
local bodyGyro
local bodyVel

local currentVelocity = Vector3.new(0, 0, 0)
local currentGyroCFrame

local moveInput = Vector3.new(0, 0, 0)
local verticalInput = 0

local rightShoulder
local defaultShoulderC0

local originalRunSoundStates = {}

local animator
local floatTrack
local flyTrack

local animMode = "Float"
local lastAnimSwitch = 0
local ANIM_SWITCH_COOLDOWN = 0.25
local ANIM_TO_FLY_THRESHOLD = 0.22
local ANIM_TO_FLOAT_THRESHOLD = 0.12

local VALID_ANIM_STATES = {
	Idle = true,
	Walk = true,
	Run = true,
	Jump = true,
	Climb = true,
	Fall = true,
	Swim = true,
}

local stateOverrides = {
	Idle = nil,
	Walk = nil,
	Run = nil,
	Jump = nil,
	Climb = nil,
	Fall = nil,
	Swim = nil,
}

local lastChosenState = "Idle"
local lastChosenCategory = "Custom"

local DEFAULT_WALKSPEED = nil
local playerSpeed = nil

local camSubjectMode = DEFAULT_CAMERA_SUBJECT_MODE
local camOffset = Vector3.new(0, 0, 0)
local camFov = nil
local camMaxZoom = INFINITE_ZOOM

local gui

local menuFrame
local menuHandle
local arrowButton
local tabsBar
local pagesHolder

local mobileFlyButton

local fpsLabel
local fpsAcc = 0
local fpsFrames = 0
local fpsValue = 60
local rainbowHue = 0

local menuOpen = false
local menuTween = nil

local clickSoundTemplate = nil
local buttonSoundAttached = setmetatable({}, { __mode = "k" })

local pendingSave = false

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local function notify(title, text, dur)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "SOS HUD",
			Text = text or "",
			Duration = dur or 3
		})
	end)
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

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

local function toAssetIdString(anyValue)
	local s = tostring(anyValue or "")
	s = s:gsub("%s+", "")
	if s == "" then return nil end
	if s:find("^rbxassetid://") then
		return s
	end
	if s:match("^%d+$") then
		return "rbxassetid://" .. s
	end
	if s:find("^http") and s:lower():find("roblox.com") and s:lower():find("id=") then
		local id = s:match("id=(%d+)")
		if id then return "rbxassetid://" .. id end
	end
	return nil
end

local function findRightShoulderMotor(char)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("Motor6D") and part.Name == "Right Shoulder" then
			return part
		end
	end
	return nil
end

local function stopAllPlayingTracks(hum)
	for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
		pcall(function()
			tr:Stop(0)
		end)
	end
end

local function getFlightKeyName()
	return flightToggleKey and flightToggleKey.Name or "Unbound"
end

local function refreshFlyBindUI()
	if flyKeyBtnRef then
		if waitingForFlyKeybind then
			flyKeyBtnRef.Text = "Press a key"
		else
			flyKeyBtnRef.Text = getFlightKeyName()
		end
	end

	if flyBindToggleBtnRef then
		flyBindToggleBtnRef.Text = flightBindEnabled and "Bind: ON" or "Bind: OFF"
		local st = flyBindToggleBtnRef:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = flightBindEnabled and 0.05 or 0.35
			st.Thickness = flightBindEnabled and 2 or 1
		end
		flyBindToggleBtnRef.BackgroundTransparency = flightBindEnabled and 0.08 or 0.22
	end

	if controlsInfoRef then
		local flyLine = "PC:\n- Fly Toggle: " .. getFlightKeyName()
		if not flightBindEnabled then
			flyLine = flyLine .. " (Bind off)"
		end
		if not flightFeatureEnabled then
			flyLine = flyLine .. " (Disabled)"
		end

		controlsInfoRef.Text =
			flyLine ..
			"\n- Menu Toggle: " .. menuToggleKey.Name ..
			"\n- Move: WASD + Q/E\n\nMobile:\n- Use the Fly button (bottom-right)\n- Use the top arrow to open/close the menu"
	end
end

local function canStartFlightNow()
	if not flightFeatureEnabled then
		notify("Flight", "Flight is disabled.", 2)
		return false
	end

	if typeof(_G) == "table" and _G.SOS_BlockFlight then
		local reason = _G.SOS_BlockFlightReason or "Blocked"
		notify("Flight", "Blocked: " .. tostring(reason), 2)
		return false
	end

	return true
end

local function setFlightFeatureEnabled(on, reason)
	flightFeatureEnabled = on and true or false
	if not flightFeatureEnabled and flying then
		if typeof(reason) ~= "string" then reason = "Disabled" end
		notify("Flight", "Stopped: " .. reason, 2)
	end
	refreshFlyBindUI()
end

--------------------------------------------------------------------
-- SAVE / LOAD (per UserId)
--------------------------------------------------------------------
local function canFileIO()
	return (typeof(readfile) == "function") and (typeof(writefile) == "function") and (typeof(isfile) == "function")
end

local function getSettingsFileName()
	return SETTINGS_FILE_PREFIX .. tostring(LocalPlayer.UserId) .. ".json"
end

local function encodeSettings(tbl)
	local ok, res = pcall(function()
		return HttpService:JSONEncode(tbl)
	end)
	if ok then return res end
	return nil
end

local function decodeSettings(str)
	local ok, res = pcall(function()
		return HttpService:JSONDecode(str)
	end)
	if ok and typeof(res) == "table" then
		return res
	end
	return nil
end

local function buildSettingsTable()
	return {
		Version = 2,
		UserId = LocalPlayer.UserId,

		FLOAT_ID = FLOAT_ID,
		FLY_ID = FLY_ID,
		FlySpeed = flySpeed,

		FlightToggleKey = flightToggleKey and flightToggleKey.Name or nil,
		FlightBindEnabled = flightBindEnabled,

		PlayerSpeed = playerSpeed,

		CamSubjectMode = camSubjectMode,
		CamOffset = { camOffset.X, camOffset.Y, camOffset.Z },
		CamFov = camFov,
		CamMaxZoom = camMaxZoom,

		AnimOverrides = stateOverrides,
		LastAnimState = lastChosenState,
		LastAnimCategory = lastChosenCategory,

		Lighting = _G.__SOS_LightingSaveState or nil,
	}
end

local function applySettingsTable(s)
	if typeof(s) ~= "table" then return end

	if typeof(s.FLOAT_ID) == "string" then FLOAT_ID = s.FLOAT_ID end
	if typeof(s.FLY_ID) == "string" then FLY_ID = s.FLY_ID end
	if typeof(s.FlySpeed) == "number" then
		flySpeed = math.clamp(math.floor(s.FlySpeed + 0.5), minFlySpeed, maxFlySpeed)
	end

	if typeof(s.FlightToggleKey) == "string" then
		local kc = Enum.KeyCode[s.FlightToggleKey]
		if kc then
			flightToggleKey = kc
		end
	end
	if typeof(s.FlightBindEnabled) == "boolean" then
		flightBindEnabled = s.FlightBindEnabled
	end

	if typeof(s.PlayerSpeed) == "number" then
		playerSpeed = math.clamp(math.floor(s.PlayerSpeed + 0.5), 2, 500)
	end

	if typeof(s.CamSubjectMode) == "string" then camSubjectMode = s.CamSubjectMode end
	if typeof(s.CamOffset) == "table" and #s.CamOffset >= 3 then
		local x = tonumber(s.CamOffset[1]) or 0
		local y = tonumber(s.CamOffset[2]) or 0
		local z = tonumber(s.CamOffset[3]) or 0
		camOffset = Vector3.new(x, y, z)
	end
	if typeof(s.CamFov) == "number" then camFov = math.clamp(s.CamFov, 40, 120) end
	if typeof(s.CamMaxZoom) == "number" then camMaxZoom = math.clamp(s.CamMaxZoom, 5, INFINITE_ZOOM) end

	if typeof(s.AnimOverrides) == "table" then
		for k, v in pairs(s.AnimOverrides) do
			if VALID_ANIM_STATES[k] then
				stateOverrides[k] = v
			end
		end
	end

	if typeof(s.LastAnimState) == "string" and VALID_ANIM_STATES[s.LastAnimState] then
		lastChosenState = s.LastAnimState
	end
	if typeof(s.LastAnimCategory) == "string" then lastChosenCategory = s.LastAnimCategory end

	if typeof(s.Lighting) == "table" then
		_G.__SOS_LightingSaveState = s.Lighting
	end
end

local function loadSettings()
	local raw = nil

	if canFileIO() then
		local file = getSettingsFileName()
		if isfile(file) then
			local ok, data = pcall(function()
				return readfile(file)
			end)
			if ok and type(data) == "string" and #data > 0 then
				raw = data
			end
		end
	end

	if not raw then
		local attr = LocalPlayer:GetAttribute(SETTINGS_ATTR_NAME)
		if type(attr) == "string" and #attr > 0 then
			raw = attr
		end
	end

	if raw then
		local t = decodeSettings(raw)
		if t then
			applySettingsTable(t)
		end
	end
end

local function saveSettingsNow()
	local tbl = buildSettingsTable()
	local json = encodeSettings(tbl)
	if not json then return end

	if canFileIO() then
		pcall(function()
			writefile(getSettingsFileName(), json)
		end)
	end

	pcall(function()
		LocalPlayer:SetAttribute(SETTINGS_ATTR_NAME, json)
	end)
end

local function scheduleSave()
	if pendingSave then return end
	pendingSave = true
	task.delay(0.35, function()
		pendingSave = false
		saveSettingsNow()
	end)
end

--------------------------------------------------------------------
-- BUTTON SOUND SYSTEM
--------------------------------------------------------------------
local function ensureClickSoundTemplate()
	if clickSoundTemplate and clickSoundTemplate.Parent then
		return clickSoundTemplate
	end
	if not gui then
		return nil
	end

	local s = Instance.new("Sound")
	s.Name = "SOS_ButtonClickTemplate"
	s.SoundId = BUTTON_CLICK_SOUND_ID
	s.Volume = BUTTON_CLICK_VOLUME
	s.Looped = false
	s.Parent = gui
	clickSoundTemplate = s
	return clickSoundTemplate
end

local function playButtonClick()
	local tmpl = ensureClickSoundTemplate()
	if not tmpl then return end

	local s = tmpl:Clone()
	s.Name = "SOS_ButtonClick"
	s.Parent = gui
	pcall(function() s:Play() end)
	Debris:AddItem(s, 3)
end

local function attachSoundToButton(btn)
	if not btn then return end
	if buttonSoundAttached[btn] then return end
	buttonSoundAttached[btn] = true

	local okActivated = pcall(function()
		btn.Activated:Connect(function()
			playButtonClick()
		end)
	end)

	if not okActivated then
		pcall(function()
			btn.MouseButton1Click:Connect(function()
				playButtonClick()
			end)
		end)
	end
end

local function setupGlobalButtonSounds(root)
	if not root then return end

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			attachSoundToButton(d)
		end
	end

	root.DescendantAdded:Connect(function(d)
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			attachSoundToButton(d)
		end
	end)
end

--------------------------------------------------------------------
-- INTRO SOUND ONLY
--------------------------------------------------------------------
local function playIntroSoundOnly()
	if not gui then return end
	local s = Instance.new("Sound")
	s.Name = "SOS_IntroSound"
	s.SoundId = INTRO_SOUND_ID
	s.Volume = 0.9
	s.Looped = false
	s.Parent = gui
	pcall(function() s:Play() end)
	Debris:AddItem(s, 8)
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
-- FLIGHT ANIMS
--------------------------------------------------------------------
local function loadFlightTracks()
	if not humanoid then return end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		animator = nil
		floatTrack = nil
		flyTrack = nil
		return
	end

	animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if floatTrack then pcall(function() floatTrack:Stop(0) end) end
	if flyTrack then pcall(function() flyTrack:Stop(0) end) end
	floatTrack = nil
	flyTrack = nil

	do
		local a = Instance.new("Animation")
		a.AnimationId = FLOAT_ID
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok and tr then
			floatTrack = tr
			floatTrack.Priority = Enum.AnimationPriority.Action
			floatTrack.Looped = true
		else
			floatTrack = nil
			dprint("Float track failed to load:", FLOAT_ID)
		end
	end

	do
		local a = Instance.new("Animation")
		a.AnimationId = FLY_ID
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok and tr then
			flyTrack = tr
			flyTrack.Priority = Enum.AnimationPriority.Action
			flyTrack.Looped = true
		else
			flyTrack = nil
			dprint("Fly track failed to load:", FLY_ID)
		end
	end

	animMode = "Float"
	lastAnimSwitch = 0
end

local function playFloat()
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then return end
	if not floatTrack then return end

	if flyTrack and flyTrack.IsPlaying then
		pcall(function() flyTrack:Stop(0.25) end)
	end
	if not floatTrack.IsPlaying then
		pcall(function() floatTrack:Play(0.25) end)
	end
end

local function playFly()
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then return end
	if not flyTrack then return end

	if floatTrack and floatTrack.IsPlaying then
		pcall(function() floatTrack:Stop(0.25) end)
	end
	if not flyTrack.IsPlaying then
		pcall(function() flyTrack:Play(0.25) end)
	end
end

local function stopFlightAnims()
	if floatTrack then pcall(function() floatTrack:Stop(0.25) end) end
	if flyTrack then pcall(function() flyTrack:Stop(0.25) end) end
end

--------------------------------------------------------------------
-- CHARACTER SETUP
--------------------------------------------------------------------
local function getCharacter()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	camera = workspace.CurrentCamera

	rightShoulder = findRightShoulderMotor(character)
	defaultShoulderC0 = rightShoulder and rightShoulder.C0 or nil

	originalRunSoundStates = {}

	if DEFAULT_WALKSPEED == nil then
		DEFAULT_WALKSPEED = humanoid.WalkSpeed
	end
	if playerSpeed == nil then
		playerSpeed = humanoid.WalkSpeed
	end

	if DEFAULT_FOV == nil and camera then
		DEFAULT_FOV = camera.FieldOfView
	end
	if DEFAULT_CAM_MIN_ZOOM == nil then
		DEFAULT_CAM_MIN_ZOOM = LocalPlayer.CameraMinZoomDistance
	end
	if DEFAULT_CAM_MAX_ZOOM == nil then
		DEFAULT_CAM_MAX_ZOOM = LocalPlayer.CameraMaxZoomDistance
	end
	if camFov == nil and DEFAULT_FOV then
		camFov = DEFAULT_FOV
	end
	if camMaxZoom == nil then
		camMaxZoom = INFINITE_ZOOM
	end

	loadFlightTracks()
end

--------------------------------------------------------------------
-- ANIMATE OVERRIDES (Anim Packs)
--------------------------------------------------------------------
local function getAnimateScript()
	if not character then return nil end
	return character:FindFirstChild("Animate")
end

local function applyStateOverrideToAnimate(stateName, packEntry)
	local animate = getAnimateScript()
	if not animate then
		notify("Anim Packs", "No Animate script found in character.", 3)
		return false
	end

	local hum = humanoid
	if not hum then return false end

	animate.Disabled = true
	stopAllPlayingTracks(hum)

	local function setAnimValue(folderName, childName, assetIdStr)
		local f = animate:FindFirstChild(folderName)
		if not f then return end
		local a = f:FindFirstChild(childName)
		if a and a:IsA("Animation") then
			a.AnimationId = assetIdStr
		end
	end

	local function setDirect(childName, assetIdStr)
		local a = animate:FindFirstChild(childName)
		if a and a:IsA("Animation") then
			a.AnimationId = assetIdStr
		end
	end

	local assetIdStr = toAssetIdString(packEntry)
	if not assetIdStr then
		animate.Disabled = false
		return false
	end

	if stateName == "Idle" then
		setAnimValue("idle", "Animation1", assetIdStr)
		setAnimValue("idle", "Animation2", assetIdStr)
	elseif stateName == "Walk" then
		setAnimValue("walk", "WalkAnim", assetIdStr)
	elseif stateName == "Run" then
		setAnimValue("run", "RunAnim", assetIdStr)
	elseif stateName == "Jump" then
		setAnimValue("jump", "JumpAnim", assetIdStr)
	elseif stateName == "Climb" then
		setAnimValue("climb", "ClimbAnim", assetIdStr)
	elseif stateName == "Fall" then
		setAnimValue("fall", "FallAnim", assetIdStr)
	elseif stateName == "Swim" then
		setAnimValue("swim", "Swim", assetIdStr)
		setAnimValue("swim", "SwimIdle", assetIdStr)
		setDirect("swim", assetIdStr)
	end

	animate.Disabled = false
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)

	return true
end

local function reapplyAllOverridesAfterRespawn()
	for stateName, asset in pairs(stateOverrides) do
		if asset then
			applyStateOverrideToAnimate(stateName, asset)
		end
	end
end

--------------------------------------------------------------------
-- ANIMATION PACK LIST (Roblox Anims / Unreleased)
--------------------------------------------------------------------
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

local UnreleasedNames = {
	"Cowboy",
	"Princess",
	"ZombieFE",
	"Confident",
	"Ghost",
	"Patrol",
	"Popstar",
	"Sneaky",
}

local function isInUnreleased(name)
	for _, n in ipairs(UnreleasedNames) do
		if n == name then return true end
	end
	return false
end

--------------------------------------------------------------------
-- CUSTOM ANIMS (Custom tab)
--------------------------------------------------------------------
local CustomIdle = {
	["Tall"] = 91348372558295,

	["Jonathan"] = 120629563851640,
	["Killer Queen"] = 104714163485875,
	["Dio"] = 138467089338692,
	["Dio OH"] = 96658788627102,
	["Joseph"] = 87470625500564,
	["Diego"] = 127117233320016,
	["Polnareff"] = 104647713661701,
	["Jotaro"] = 134878791451155,
	["Funny V"] = 88859285630202,
	["Johnny"] = 77834689346843,
	["Made in Heaven"] = 79234770032233,
	["Mahito"] = 92585001378279,
	["Honored One"] = 139000839803032,
	["Gon Rage"] = 136678571910037,
	["Sol's RNG 1"] = 125722696765151,
	["Luffy"] = 107520488394848,
	["Sans"] = 123627677663418,
	["Fake R6"] = 96518514398708,
	["Goku Warm Up"] = 84773442399798,
	["Goku UI/Mui"] = 130104867308995,
	["Goku Black"] = 110240143520283,
	["Sukuna"] = 82974857632552,
	["Toji"] = 113657065279101,
	["Isagi"] = 135818607077529,
	["Yuji"] = 103088653217891,
	["Lavinho"] = 92045987196732,
	["Ippo"] = 76110924880592,
	["Tall 2"] = 120873587634730,
	["Kaneki"] = 116671111363578,
	["Tanjiro"] = 118533315464114,
	["Head Hold"] = 129453036635884,
	["Robot Perform"] = 105174189783870,

	["Springtrap"] = 90257184304714,
	["Hmmm Float"] = 107666091494733,
	["OG Golden Freddy"] = 138402679058341,
	["Wally West"] = 106169111259587,
	["L"] = 103267638009024,
	["Robot Malfunction"] = 110419039625879,

	["A Vibing Spider"] = 86005347720103,
	["Spiderman"] = 74785222555193,
	["Ballora"] = 88392341793465,
	["Backpack"] = 114948866128817,
	["Cute Sit"] = 86546752992173,
	["Animal"] = 79105016523357,
	["Standing"] = 127972564618207,
	["Shy"] = 123358425539087,
	["Protagonist"] = 92686470851073,
	["Arms Crossed"] = 132861892011980,
	["The Zombie"] = 115485274167727,
}

local CustomRun = {
	["Tall"] = 134010853417610,
	["Officer Earl"] = 104646820775114,
	["AOT Titan"] = 95363958550738,
	["Animal"] = 87721497492370,
	["Captain JS"] = 87806542116815,
	["Ninja Sprint"] = 123763532572423,
	["IDEK"] = 101293881003047,
	["Honored One"] = 82260970223217,
	["Head Hold"] = 92715775326925,

	["Springtrap Sturdy"] = 80927378599036,
	["UFO"] = 118703314621593,
	["Closed Eyes Vibe"] = 117991470645633,
	["Wally West"] = 102622695004986,
	["Squidward"] = 82365330773489,
	["On A Mission"] = 113718116290824,
	["Very Happy Run"] = 86522070222739,
	["Missile"] = 92401041987431,
	["I Wanna Run Away"] = 78510387198062,

	["A Spider"] = 89356423918695,
	["Ballora"] = 75557142930836,
	["Pennywise Strut"] = 79671615133463,
	["The Zombie"] = 113076603308515,
}

-- Custom Walk removed per request
local CustomWalk = nil

--------------------------------------------------------------------
-- NEW: PRIVATE CUSTOM LISTS FOR SINS AND CO/OWNERS
--------------------------------------------------------------------
local SinsIdle = {
	-- ["Name"] = 1234567890,
}

local SinsRun = {
	-- ["Name"] = 1234567890,
}

local CoOwnersIdle = {
	-- ["Name"] = 1234567890,
}

local CoOwnersRun = {
	-- ["Name"] = 1234567890,
}

--------------------------------------------------------------------
-- LIST HELPERS
--------------------------------------------------------------------
local function listNamesFromMap(map)
	local t = {}
	if not map then return t end
	for name, _ in pairs(map) do
		table.insert(t, name)
	end
	table.sort(t)
	return t
end

local function listCustomNamesForState(stateName)
	if stateName == "Idle" then return listNamesFromMap(CustomIdle) end
	if stateName == "Run" then return listNamesFromMap(CustomRun) end
	return {}
end

local function getCustomIdForState(name, stateName)
	if stateName == "Idle" then return CustomIdle[name] end
	if stateName == "Run" then return CustomRun[name] end
	return nil
end

local function listPackNamesForCategory(category)
	local names = {}
	for name, _ in pairs(AnimationPacks) do
		if category == "Unreleased" then
			if isInUnreleased(name) then
				table.insert(names, name)
			end
		elseif category == "Roblox Anims" then
			if not isInUnreleased(name) then
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names
end

local function getPackValueForState(packName, stateName)
	local pack = AnimationPacks[packName]
	if not pack then return nil end
	if stateName == "Idle" then
		return pack.Idle1 or pack.Idle2
	elseif stateName == "Walk" then
		return pack.Walk
	elseif stateName == "Run" then
		return pack.Run
	elseif stateName == "Jump" then
		return pack.Jump
	elseif stateName == "Climb" then
		return pack.Climb
	elseif stateName == "Fall" then
		return pack.Fall
	elseif stateName == "Swim" then
		return nil
	end
	return nil
end

--------------------------------------------------------------------
-- MOVEMENT INPUT
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
	if not canStartFlightNow() then return end

	flying = true

	humanoid.PlatformStand = true
	cacheAndMuteRunSounds()

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.P = 1e5
	bodyGyro.D = 1000
	bodyGyro.CFrame = rootPart.CFrame
	bodyGyro.Parent = rootPart

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVel.Velocity = Vector3.new()
	bodyVel.P = 1250
	bodyVel.Parent = rootPart

	currentVelocity = Vector3.new(0, 0, 0)
	currentGyroCFrame = rootPart.CFrame

	local camLook = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
	if camLook.Magnitude < 0.01 then camLook = Vector3.new(0, 0, -1) end
	camLook = camLook.Unit

	local baseCF = CFrame.lookAt(rootPart.Position, rootPart.Position + camLook)
	currentGyroCFrame = baseCF * CFrame.Angles(-math.rad(IDLE_TILT_DEG), 0, 0)
	bodyGyro.CFrame = currentGyroCFrame

	animMode = "Float"
	lastAnimSwitch = 0
	playFloat()
end

local function stopFlying()
	if not flying then return end
	flying = false

	stopFlightAnims()

	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	if bodyVel then bodyVel:Destroy() bodyVel = nil end

	if humanoid then humanoid.PlatformStand = false end

	if rightShoulder and defaultShoulderC0 then
		rightShoulder.C0 = defaultShoulderC0
	end

	restoreRunSounds()
end

-- Global hooks used by other sections (eg bhop)
if typeof(_G) == "table" then
	_G.SOS_StopFlight = function(reason)
		if flying then
			stopFlying()
		end
	end

	_G.SOS_SetFlightEnabled = function(on, reason)
		setFlightFeatureEnabled(on, reason)
		if not on and flying then
			stopFlying()
		end
	end
end

--------------------------------------------------------------------
-- UI BUILDING BLOCKS
--------------------------------------------------------------------
local function makeCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

local function makeStroke(parent, thickness)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(200, 40, 40)
	s.Thickness = thickness or 2
	s.Transparency = 0.1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function makeGlass(parent)
	parent.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	parent.BackgroundTransparency = 0.18

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 22)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(10, 10, 12)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 8)),
	})
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.20),
	})
	grad.Parent = parent

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundTransparency = 1
	shine.Size = UDim2.new(1, -8, 0.35, 0)
	shine.Position = UDim2.new(0, 4, 0, 4)
	shine.Parent = parent

	local shineImg = Instance.new("ImageLabel")
	shineImg.BackgroundTransparency = 1
	shineImg.Size = UDim2.new(1, 0, 1, 0)
	shineImg.Image = "rbxassetid://5028857084"
	shineImg.ImageTransparency = 0.72
	shineImg.Parent = shine

	local shineGrad = Instance.new("UIGradient")
	shineGrad.Rotation = 0
	shineGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineGrad.Parent = shineImg
end

local function makeText(parent, txt, size, bold)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = txt or ""
	t.TextColor3 = Color3.fromRGB(240, 240, 240)
	t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	t.TextSize = size or 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextWrapped = true
	t.Parent = parent
	return t
end

local function makeButton(parent, txt)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = txt or "Button"
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(245, 245, 245)
	b.Parent = parent
	makeCorner(b, 10)

	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(200, 40, 40)
	st.Thickness = 1
	st.Transparency = 0.25
	st.Parent = b

	return b
end

local function makeInput(parent, placeholder)
	local tb = Instance.new("TextBox")
	tb.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	tb.BackgroundTransparency = 0.15
	tb.BorderSizePixel = 0
	tb.ClearTextOnFocus = false
	tb.Text = ""
	tb.PlaceholderText = placeholder or ""
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 14
	tb.TextColor3 = Color3.fromRGB(245, 245, 245)
	tb.PlaceholderColor3 = Color3.fromRGB(170, 170, 170)
	tb.Parent = parent
	makeCorner(tb, 10)

	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(200, 40, 40)
	st.Thickness = 1
	st.Transparency = 0.35
	st.Parent = tb

	return tb
end

local function setTabButtonActive(btn, active)
	local st = btn:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = active and 0.05 or 0.35
		st.Thickness = active and 2 or 1
	end
	btn.BackgroundTransparency = active and 0.08 or 0.22
end

--------------------------------------------------------------------
-- LIGHTING SYSTEM (unchanged)
--------------------------------------------------------------------
local ORIGINAL_LIGHTING = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	ExposureCompensation = Lighting.ExposureCompensation,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	GeographicLatitude = Lighting.GeographicLatitude,
}

local function cloneIfExists(className)
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst.ClassName == className then
			return inst:Clone()
		end
	end
	return nil
end

ORIGINAL_LIGHTING.Sky = cloneIfExists("Sky")
ORIGINAL_LIGHTING.Atmosphere = cloneIfExists("Atmosphere")
ORIGINAL_LIGHTING.Bloom = cloneIfExists("BloomEffect")
ORIGINAL_LIGHTING.ColorCorrection = cloneIfExists("ColorCorrectionEffect")
ORIGINAL_LIGHTING.DepthOfField = cloneIfExists("DepthOfFieldEffect")
ORIGINAL_LIGHTING.Blur = cloneIfExists("BlurEffect")
ORIGINAL_LIGHTING.SunRays = cloneIfExists("SunRaysEffect")

local function getOrCreateEffect(className, name)
	local inst = Lighting:FindFirstChild(name)
	if inst and inst.ClassName == className then
		return inst
	end
	if inst then
		inst:Destroy()
	end
	local newInst = Instance.new(className)
	newInst.Name = name
	newInst.Parent = Lighting
	return newInst
end

local function destroyIfExists(name)
	local inst = Lighting:FindFirstChild(name)
	if inst then inst:Destroy() end
end

local SKY_PRESETS = {
	["Crimson Night"] = {
		Sky = {
			Bk = "rbxassetid://401664839",
			Dn = "rbxassetid://401664862",
			Ft = "rbxassetid://401664960",
			Lf = "rbxassetid://401664881",
			Rt = "rbxassetid://401664901",
			Up = "rbxassetid://401664936",
		},
	},
	["Deep Space"] = {
		Sky = {
			Bk = "rbxassetid://149397692",
			Dn = "rbxassetid://149397686",
			Ft = "rbxassetid://149397697",
			Lf = "rbxassetid://149397684",
			Rt = "rbxassetid://149397688",
			Up = "rbxassetid://149397702",
		},
	},
	["Vaporwave Nebula"] = {
		Sky = {
			Bk = "rbxassetid://1417494030",
			Dn = "rbxassetid://1417494146",
			Ft = "rbxassetid://1417494253",
			Lf = "rbxassetid://1417494402",
			Rt = "rbxassetid://1417494499",
			Up = "rbxassetid://1417494643",
		},
	},
	["Soft Clouds"] = {
		Sky = {
			Bk = "rbxassetid://570557514",
			Dn = "rbxassetid://570557775",
			Ft = "rbxassetid://570557559",
			Lf = "rbxassetid://570557620",
			Rt = "rbxassetid://570557672",
			Up = "rbxassetid://570557727",
		},
	},
	["Cloudy Skies"] = {
		Sky = {
			Bk = "rbxassetid://252760981",
			Dn = "rbxassetid://252763035",
			Ft = "rbxassetid://252761439",
			Lf = "rbxassetid://252760980",
			Rt = "rbxassetid://252760986",
			Up = "rbxassetid://252762652",
		},
	},
}

local LightingState = {
	Enabled = true,
	SelectedSky = nil,
	Toggles = {
		Sky = true,
		Atmosphere = true,
		ColorCorrection = true,
		Bloom = true,
		DepthOfField = true,
		MotionBlur = true,
		SunRays = true,
	},
}

local function writeLightingSaveState()
	_G.__SOS_LightingSaveState = {
		Enabled = LightingState.Enabled,
		SelectedSky = LightingState.SelectedSky,
		Toggles = LightingState.Toggles,
	}
	scheduleSave()
end

local function readLightingSaveState()
	local s = _G.__SOS_LightingSaveState
	if typeof(s) ~= "table" then return end
	if typeof(s.Enabled) == "boolean" then LightingState.Enabled = s.Enabled end
	if typeof(s.SelectedSky) == "string" then LightingState.SelectedSky = s.SelectedSky end
	if typeof(s.Toggles) == "table" then
		for k, v in pairs(s.Toggles) do
			if typeof(v) == "boolean" and LightingState.Toggles[k] ~= nil then
				LightingState.Toggles[k] = v
			end
		end
	end
end

local function applyFancyDefaults()
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.15
end

local function removeSOSLightingOnly()
	for _, name in ipairs({
		"SOS_Sky",
		"SOS_Atmosphere",
		"SOS_Bloom",
		"SOS_ColorCorrection",
		"SOS_DepthOfField",
		"SOS_MotionBlur",
		"SOS_SunRays",
	}) do
		destroyIfExists(name)
	end
end

local function applySkyPreset(name)
	LightingState.SelectedSky = name
	writeLightingSaveState()

	if not LightingState.Enabled then return end
	local preset = SKY_PRESETS[name]
	if not preset then return end

	applyFancyDefaults()

	if LightingState.Toggles.Sky then
		local sky = getOrCreateEffect("Sky", "SOS_Sky")
		sky.SkyboxBk = preset.Sky.Bk
		sky.SkyboxDn = preset.Sky.Dn
		sky.SkyboxFt = preset.Sky.Ft
		sky.SkyboxLf = preset.Sky.Lf
		sky.SkyboxRt = preset.Sky.Rt
		sky.SkyboxUp = preset.Sky.Up
	else
		destroyIfExists("SOS_Sky")
	end

	if LightingState.Toggles.ColorCorrection then
		local cc = getOrCreateEffect("ColorCorrectionEffect", "SOS_ColorCorrection")
		cc.Enabled = true
		cc.Brightness = 0.02
		cc.Contrast = 0.18
		cc.Saturation = 0.06
		cc.TintColor = Color3.fromRGB(255, 240, 240)
	else
		destroyIfExists("SOS_ColorCorrection")
	end

	if LightingState.Toggles.Bloom then
		local bloom = getOrCreateEffect("BloomEffect", "SOS_Bloom")
		bloom.Enabled = true
		bloom.Intensity = 0.8
		bloom.Size = 28
		bloom.Threshold = 1
	else
		destroyIfExists("SOS_Bloom")
	end

	if LightingState.Toggles.DepthOfField then
		local dof = getOrCreateEffect("DepthOfFieldEffect", "SOS_DepthOfField")
		dof.Enabled = true
		dof.FarIntensity = 0.12
		dof.FocusDistance = 55
		dof.InFocusRadius = 40
		dof.NearIntensity = 0.25
	else
		destroyIfExists("SOS_DepthOfField")
	end

	if LightingState.Toggles.MotionBlur then
		local blur = getOrCreateEffect("BlurEffect", "SOS_MotionBlur")
		blur.Enabled = true
		blur.Size = 2
	else
		destroyIfExists("SOS_MotionBlur")
	end

	if LightingState.Toggles.SunRays then
		local rays = getOrCreateEffect("SunRaysEffect", "SOS_SunRays")
		rays.Enabled = true
		rays.Intensity = 0.06
		rays.Spread = 0.75
	else
		destroyIfExists("SOS_SunRays")
	end

	if LightingState.Toggles.Atmosphere then
		local atm = getOrCreateEffect("Atmosphere", "SOS_Atmosphere")
		atm.Density = 0.32
		atm.Offset = 0.1
		atm.Color = Color3.fromRGB(210, 200, 255)
		atm.Decay = Color3.fromRGB(70, 60, 90)
		atm.Glare = 0.12
		atm.Haze = 1
	else
		destroyIfExists("SOS_Atmosphere")
	end
end

local function resetLightingToOriginal()
	removeSOSLightingOnly()

	Lighting.Ambient = ORIGINAL_LIGHTING.Ambient
	Lighting.OutdoorAmbient = ORIGINAL_LIGHTING.OutdoorAmbient
	Lighting.Brightness = ORIGINAL_LIGHTING.Brightness
	Lighting.ClockTime = ORIGINAL_LIGHTING.ClockTime
	Lighting.ExposureCompensation = ORIGINAL_LIGHTING.ExposureCompensation
	Lighting.EnvironmentDiffuseScale = ORIGINAL_LIGHTING.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = ORIGINAL_LIGHTING.EnvironmentSpecularScale
	Lighting.FogColor = ORIGINAL_LIGHTING.FogColor
	Lighting.FogEnd = ORIGINAL_LIGHTING.FogEnd
	Lighting.FogStart = ORIGINAL_LIGHTING.FogStart
	Lighting.GeographicLatitude = ORIGINAL_LIGHTING.GeographicLatitude

	local function restoreClone(cloneObj, className)
		if not cloneObj then return end
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst.ClassName == className then
				inst:Destroy()
			end
		end
		local c = cloneObj:Clone()
		c.Parent = Lighting
	end

	restoreClone(ORIGINAL_LIGHTING.Sky, "Sky")
	restoreClone(ORIGINAL_LIGHTING.Atmosphere, "Atmosphere")
	restoreClone(ORIGINAL_LIGHTING.Bloom, "BloomEffect")
	restoreClone(ORIGINAL_LIGHTING.ColorCorrection, "ColorCorrectionEffect")
	restoreClone(ORIGINAL_LIGHTING.DepthOfField, "DepthOfFieldEffect")
	restoreClone(ORIGINAL_LIGHTING.Blur, "BlurEffect")
	restoreClone(ORIGINAL_LIGHTING.SunRays, "SunRaysEffect")

	LightingState.SelectedSky = nil
	writeLightingSaveState()
end

local function syncLightingToggles()
	if not LightingState.Enabled then
		removeSOSLightingOnly()
		return
	end

	if LightingState.SelectedSky and SKY_PRESETS[LightingState.SelectedSky] then
		applySkyPreset(LightingState.SelectedSky)
	else
		if not LightingState.Toggles.Sky then destroyIfExists("SOS_Sky") end
		if not LightingState.Toggles.Atmosphere then destroyIfExists("SOS_Atmosphere") end
		if not LightingState.Toggles.ColorCorrection then destroyIfExists("SOS_ColorCorrection") end
		if not LightingState.Toggles.Bloom then destroyIfExists("SOS_Bloom") end
		if not LightingState.Toggles.DepthOfField then destroyIfExists("SOS_DepthOfField") end
		if not LightingState.Toggles.MotionBlur then destroyIfExists("SOS_MotionBlur") end
		if not LightingState.Toggles.SunRays then destroyIfExists("SOS_SunRays") end
	end
end

--------------------------------------------------------------------
-- CAMERA APPLY
--------------------------------------------------------------------
local function resolveCameraSubject(mode)
	if not character then return nil end
	if mode == "Humanoid" then
		return humanoid
	end
	if mode == "Head" then
		return character:FindFirstChild("Head") or humanoid
	end
	if mode == "HumanoidRootPart" then
		return character:FindFirstChild("HumanoidRootPart") or humanoid
	end
	if mode == "Torso" then
		return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or humanoid
	end
	if mode == "UpperTorso" then
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or humanoid
	end
	if mode == "LowerTorso" then
		return character:FindFirstChild("LowerTorso") or humanoid
	end
	return humanoid
end

local function applyCameraSettings()
	if not camera then return end

	LocalPlayer.CameraMaxZoomDistance = camMaxZoom or INFINITE_ZOOM
	LocalPlayer.CameraMinZoomDistance = DEFAULT_CAM_MIN_ZOOM or 0.5

	if camFov then
		camera.FieldOfView = camFov
	end

	local subject = resolveCameraSubject(camSubjectMode)
	if subject then
		camera.CameraSubject = subject
	end

	if humanoid then
		humanoid.CameraOffset = camOffset
	end
end

local function resetCameraToDefaults()
	if DEFAULT_FOV and camera then
		camFov = DEFAULT_FOV
		camera.FieldOfView = DEFAULT_FOV
	end

	if DEFAULT_CAM_MIN_ZOOM ~= nil then
		LocalPlayer.CameraMinZoomDistance = DEFAULT_CAM_MIN_ZOOM
	end

	camMaxZoom = INFINITE_ZOOM
	LocalPlayer.CameraMaxZoomDistance = camMaxZoom

	camSubjectMode = DEFAULT_CAMERA_SUBJECT_MODE
	camOffset = Vector3.new(0, 0, 0)
	if humanoid then
		humanoid.CameraOffset = camOffset
	end

	applyCameraSettings()
	scheduleSave()
end

--------------------------------------------------------------------
-- PLAYER SPEED APPLY
--------------------------------------------------------------------
local function applyPlayerSpeed()
	if humanoid and playerSpeed then
		humanoid.WalkSpeed = playerSpeed
	end
end

local function resetPlayerSpeedToDefault()
	if humanoid then
		if DEFAULT_WALKSPEED == nil then
			DEFAULT_WALKSPEED = humanoid.WalkSpeed
		end
		playerSpeed = DEFAULT_WALKSPEED
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
	end
	scheduleSave()
end

--------------------------------------------------------------------
-- MIC UP VIP TOOL
--------------------------------------------------------------------
local function ownsAnyVipPass()
	for _, id in ipairs(VIP_GAMEPASSES) do
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, id)
		end)
		if ok and owned then
			return true
		end
	end
	return false
end

local function giveBetterSpeedCoil()
	if not character or not humanoid then
		notify("Better Speed Coil", "Character not ready.", 2)
		return
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then
		notify("Better Speed Coil", "Backpack not found.", 2)
		return
	end

	if backpack:FindFirstChild("Better Speed Coil") or character:FindFirstChild("Better Speed Coil") then
		notify("Better Speed Coil", "You already have it.", 2)
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "Better Speed Coil"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true

	local last = nil
	tool.Equipped:Connect(function()
		if humanoid then
			last = humanoid.WalkSpeed
			humanoid.WalkSpeed = 111
		end
	end)

	tool.Unequipped:Connect(function()
		if humanoid then
			if last then
				humanoid.WalkSpeed = last
			else
				humanoid.WalkSpeed = humanoid.WalkSpeed
			end
		end
	end)

	tool.Parent = backpack
	notify("Better Speed Coil", "Added to your inventory.", 2)
end

--------------------------------------------------------------------
-- UI: MINI ANIM PICKER (for Sins and Co/Owners)
--------------------------------------------------------------------
local function buildMiniAnimPicker(parentScroll, titleText, privateIdleMap, privateRunMap, miniTabsList)
	local header = makeText(parentScroll, titleText, 16, true)
	header.Size = UDim2.new(1, 0, 0, 22)

	local hint = makeText(parentScroll, "Only Idle and Run here. Keep it tidy or the menu will start complaining like it's on low ping.", 13, false)
	hint.Size = UDim2.new(1, 0, 0, 34)
	hint.TextColor3 = Color3.fromRGB(210, 210, 210)

	local outer = Instance.new("Frame")
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.new(1, 0, 0, 280)
	outer.Parent = parentScroll

	local tabBar = Instance.new("ScrollingFrame")
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.Position = UDim2.new(0, 0, 0, 0)
	tabBar.Size = UDim2.new(1, 0, 0, 42)
	tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabBar.ScrollBarThickness = 2
	tabBar.Parent = outer

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar

	local pageHolder = Instance.new("Frame")
	pageHolder.BackgroundTransparency = 1
	pageHolder.Position = UDim2.new(0, 0, 0, 48)
	pageHolder.Size = UDim2.new(1, 0, 1, -48)
	pageHolder.ClipsDescendants = true
	pageHolder.Parent = outer

	local miniPages = {}
	local miniButtons = {}
	local activeMini = nil

	local function makeMiniPage(name)
		local p = Instance.new("Frame")
		p.Name = name
		p.BackgroundTransparency = 1
		p.Size = UDim2.new(1, 0, 1, 0)
		p.Visible = false
		p.Parent = pageHolder
		miniPages[name] = p
		return p
	end

	local function switchMini(name)
		if activeMini == name then return end
		for n, pg in pairs(miniPages) do
			pg.Visible = (n == name)
		end
		for n, b in pairs(miniButtons) do
			setTabButtonActive(b, n == name)
		end
		activeMini = name
	end

	local list = miniTabsList or { "Animations", "Other" }
	for i, tabName in ipairs(list) do
		local b = makeButton(tabBar, tabName)
		b.Size = UDim2.new(0, (tabName == "Animations" and 130 or 120), 0, 36)
		b.LayoutOrder = i
		miniButtons[tabName] = b
		makeMiniPage(tabName)
		b.MouseButton1Click:Connect(function()
			switchMini(tabName)
		end)
	end

	local animPage = miniPages["Animations"]
	if animPage then
		local stateBar = Instance.new("ScrollingFrame")
		stateBar.BackgroundTransparency = 1
		stateBar.BorderSizePixel = 0
		stateBar.Size = UDim2.new(1, 0, 0, 42)
		stateBar.CanvasSize = UDim2.new(0, 0, 0, 0)
		stateBar.AutomaticCanvasSize = Enum.AutomaticSize.X
		stateBar.ScrollingDirection = Enum.ScrollingDirection.X
		stateBar.ScrollBarThickness = 2
		stateBar.Parent = animPage

		local stLay = Instance.new("UIListLayout")
		stLay.FillDirection = Enum.FillDirection.Horizontal
		stLay.SortOrder = Enum.SortOrder.LayoutOrder
		stLay.Padding = UDim.new(0, 10)
		stLay.Parent = stateBar

		local catBar = Instance.new("ScrollingFrame")
		catBar.BackgroundTransparency = 1
		catBar.BorderSizePixel = 0
		catBar.Position = UDim2.new(0, 0, 0, 48)
		catBar.Size = UDim2.new(1, 0, 0, 42)
		catBar.CanvasSize = UDim2.new(0, 0, 0, 0)
		catBar.AutomaticCanvasSize = Enum.AutomaticSize.X
		catBar.ScrollingDirection = Enum.ScrollingDirection.X
		catBar.ScrollBarThickness = 2
		catBar.Parent = animPage

		local catLay = Instance.new("UIListLayout")
		catLay.FillDirection = Enum.FillDirection.Horizontal
		catLay.SortOrder = Enum.SortOrder.LayoutOrder
		catLay.Padding = UDim.new(0, 10)
		catLay.Parent = catBar

		local listScroll = Instance.new("ScrollingFrame")
		listScroll.BackgroundTransparency = 1
		listScroll.BorderSizePixel = 0
		listScroll.Position = UDim2.new(0, 0, 0, 96)
		listScroll.Size = UDim2.new(1, 0, 1, -96)
		listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		listScroll.ScrollBarThickness = 4
		listScroll.Parent = animPage

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 2)
		pad.PaddingRight = UDim.new(0, 2)
		pad.Parent = listScroll

		local container = Instance.new("Frame")
		container.BackgroundTransparency = 1
		container.Size = UDim2.new(1, 0, 0, 0)
		container.Parent = listScroll

		local lay = Instance.new("UIListLayout")
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Padding = UDim.new(0, 8)
		lay.Parent = container

		local miniStateButtons = {}
		local miniCatButtons = {}

		local miniState = "Idle"
		local miniCat = "Custom"

		local function getPrivateMapForState(stateName)
			if stateName == "Idle" then return privateIdleMap end
			if stateName == "Run" then return privateRunMap end
			return nil
		end

		local function rebuildMiniList()
			for _, ch in ipairs(container:GetChildren()) do
				if ch:IsA("TextButton") or ch:IsA("TextLabel") or ch:IsA("Frame") then
					ch:Destroy()
				end
			end

			if miniCat == "Custom" then
				local map = getPrivateMapForState(miniState)
				local names = listNamesFromMap(map)
				if #names == 0 then
					local t = makeText(container, "No private animations added yet for " .. miniState .. ".", 14, true)
					t.Size = UDim2.new(1, 0, 0, 26)
					return
				end

				for _, nm in ipairs(names) do
					local b = makeButton(container, nm)
					b.Size = UDim2.new(1, 0, 0, 34)
					b.MouseButton1Click:Connect(function()
						local id = map[nm]
						if not id then return end
						stateOverrides[miniState] = "rbxassetid://" .. tostring(id)
						local ok = applyStateOverrideToAnimate(miniState, stateOverrides[miniState])
						if ok then
							notify("Anim Packs", "Set " .. miniState .. " to " .. nm, 2)
							scheduleSave()
						else
							notify("Anim Packs", "Failed to apply. (Animate script missing?)", 3)
						end
					end)
				end
				return
			end

			local names = listPackNamesForCategory(miniCat)
			for _, packName in ipairs(names) do
				local b = makeButton(container, packName)
				b.Size = UDim2.new(1, 0, 0, 34)
				b.MouseButton1Click:Connect(function()
					local id = getPackValueForState(packName, miniState)
					if not id then
						notify("Anim Packs", "That pack has no ID for: " .. miniState, 2)
						return
					end
					stateOverrides[miniState] = "rbxassetid://" .. tostring(id)
					local ok = applyStateOverrideToAnimate(miniState, stateOverrides[miniState])
					if ok then
						notify("Anim Packs", "Set " .. miniState .. " to " .. packName, 2)
						scheduleSave()
					else
						notify("Anim Packs", "Failed to apply. (Animate script missing?)", 3)
					end
				end)
			end
		end

		local function setMiniState(s)
			miniState = s
			for n, b in pairs(miniStateButtons) do
				setTabButtonActive(b, n == s)
			end
			rebuildMiniList()
		end

		local function setMiniCat(c)
			miniCat = c
			for n, b in pairs(miniCatButtons) do
				setTabButtonActive(b, n == c)
			end
			rebuildMiniList()
		end

		for _, s in ipairs({ "Idle", "Run" }) do
			local b = makeButton(stateBar, s)
			b.Size = UDim2.new(0, 110, 0, 34)
			miniStateButtons[s] = b
			b.MouseButton1Click:Connect(function()
				setMiniState(s)
			end)
		end

		for _, c in ipairs({ "Custom", "Roblox Anims", "Unreleased" }) do
			local b = makeButton(catBar, c)
			b.Size = UDim2.new(0, (c == "Roblox Anims" and 150 or 120), 0, 34)
			miniCatButtons[c] = b
			b.MouseButton1Click:Connect(function()
				setMiniCat(c)
			end)
		end

		setMiniCat("Custom")
		setMiniState("Idle")
	end

	for _, tabName in ipairs(list) do
		if tabName ~= "Animations" then
			local pg = miniPages[tabName]
			if pg then
				local t = makeText(pg, "Reserved for future stuff.", 14, true)
				t.Size = UDim2.new(1, 0, 0, 34)

				local s = makeText(pg, "Tell me what you want added here later and I will wire it in.", 13, false)
				s.Size = UDim2.new(1, 0, 0, 40)
				s.Position = UDim2.new(0, 0, 0, 34)
				s.TextColor3 = Color3.fromRGB(210, 210, 210)
			end
		end
	end

	switchMini("Animations")
end

--------------------------------------------------------------------
-- UI: BUILD
--------------------------------------------------------------------
local function createUI()
	safeDestroy(gui)

	gui = Instance.new("ScreenGui")
	gui.Name = "SOS_HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	ensureClickSoundTemplate()
	setupGlobalButtonSounds(gui)

	playIntroSoundOnly()

	fpsLabel = Instance.new("TextLabel")
	fpsLabel.Name = "FPS"
	fpsLabel.BackgroundTransparency = 1
	fpsLabel.AnchorPoint = Vector2.new(1, 1)
	fpsLabel.Position = UDim2.new(1, -6, 1, -6)
	fpsLabel.Size = UDim2.new(0, 140, 0, 18)
	fpsLabel.Font = Enum.Font.GothamBold
	fpsLabel.TextSize = 12
	fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
	fpsLabel.TextYAlignment = Enum.TextYAlignment.Bottom
	fpsLabel.Text = "fps"
	fpsLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
	fpsLabel.Parent = gui

	menuHandle = Instance.new("Frame")
	menuHandle.Name = "MenuHandle"
	menuHandle.AnchorPoint = Vector2.new(0.5, 0)
	menuHandle.Position = UDim2.new(0.5, 0, 0, 6)
	menuHandle.Size = UDim2.new(0, 560, 0, 42)
	menuHandle.BorderSizePixel = 0
	menuHandle.Parent = gui
	makeCorner(menuHandle, 16)
	makeGlass(menuHandle)
	makeStroke(menuHandle, 2)

	arrowButton = Instance.new("TextButton")
	arrowButton.Name = "Arrow"
	arrowButton.BackgroundTransparency = 1
	arrowButton.Size = UDim2.new(0, 40, 0, 40)
	arrowButton.Position = UDim2.new(0, 8, 0, 1)
	arrowButton.Text = "˄"
	arrowButton.Font = Enum.Font.GothamBold
	arrowButton.TextSize = 22
	arrowButton.TextColor3 = Color3.fromRGB(240, 240, 240)
	arrowButton.Parent = menuHandle

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -90, 1, 0)
	title.Position = UDim2.new(0, 70, 0, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Text = "SOS HUD"
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Parent = menuHandle

	menuFrame = Instance.new("Frame")
	menuFrame.Name = "Menu"
	menuFrame.AnchorPoint = Vector2.new(0.5, 0)
	menuFrame.Position = UDim2.new(0.5, 0, 0, 52)
	menuFrame.Size = UDim2.new(0, 560, 0, 390)
	menuFrame.BorderSizePixel = 0
	menuFrame.Parent = gui
	makeCorner(menuFrame, 16)
	makeGlass(menuFrame)
	makeStroke(menuFrame, 2)

	tabsBar = Instance.new("ScrollingFrame")
	tabsBar.Name = "TabsBar"
	tabsBar.BackgroundTransparency = 1
	tabsBar.BorderSizePixel = 0
	tabsBar.Position = UDim2.new(0, 14, 0, 10)
	tabsBar.Size = UDim2.new(1, -28, 0, 46)
	tabsBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabsBar.ScrollBarThickness = 2
	tabsBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabsBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabsBar.Parent = menuFrame

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Padding = UDim.new(0, 10)
	tabsLayout.Parent = tabsBar

	pagesHolder = Instance.new("Frame")
	pagesHolder.Name = "PagesHolder"
	pagesHolder.BackgroundTransparency = 1
	pagesHolder.Position = UDim2.new(0, 14, 0, 66)
	pagesHolder.Size = UDim2.new(1, -28, 1, -80)
	pagesHolder.ClipsDescendants = true
	pagesHolder.Parent = menuFrame

	local pages = {}
	local function makePage(name)
		local p = Instance.new("Frame")
		p.Name = name
		p.BackgroundTransparency = 1
		p.Size = UDim2.new(1, 0, 1, 0)
		p.Position = UDim2.new(0, 0, 0, 0)
		p.Visible = false
		p.Parent = pagesHolder

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Scroll"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ScrollBarThickness = 4
		scroll.Parent = p

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = scroll

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.Parent = scroll

		pages[name] = { Page = p, Scroll = scroll }
		return p, scroll
	end

	local infoPage, infoScroll = makePage("Info")
	local controlsPage, controlsScroll = makePage("Controls")
	local flyPage, flyScroll = makePage("Fly")
	local animPage, animScroll = makePage("Anim Packs")
	local playerPage, playerScroll = makePage("Player")
	local cameraPage, cameraScroll = makePage("Camera")
	local lightingPage, lightingScroll = makePage("Lighting")
	local serverPage, serverScroll = makePage("Server")
	local clientPage, clientScroll = makePage("Client")

	local sinsPage, sinsScroll = nil, nil
	if isSinsAllowed() then
		sinsPage, sinsScroll = makePage("Sins")
	end

	local coOwnersPage, coOwnersScroll = nil, nil
	if isCoOwnersAllowed() then
		coOwnersPage, coOwnersScroll = makePage("Co/Owners")
	end

	local micupPage, micupScroll = nil, nil
	do
		local placeIdStr = tostring(game.PlaceId)
		if MICUP_PLACE_IDS[placeIdStr] then
			micupPage, micupScroll = makePage("Mic up")
		end
	end

	----------------------------------------------------------------
	-- INFO TAB
	----------------------------------------------------------------
	do
		local header = makeText(infoScroll, "The Sins Of Scripting HUD", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		local msg = makeText(infoScroll,
			"Welcome.\n\nDiscord:\nPress to copy, or it will open if copy isn't supported.\n",
			14, false
		)
		msg.Size = UDim2.new(1, 0, 0, 90)

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 44)
		row.Parent = infoScroll

		local rowLay = Instance.new("UIListLayout")
		rowLay.FillDirection = Enum.FillDirection.Horizontal
		rowLay.Padding = UDim.new(0, 10)
		rowLay.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLay.Parent = row

		local discordBtn = makeButton(row, "(SOS Server)")
		discordBtn.Size = UDim2.new(0, 180, 0, 36)

		local linkBox = makeInput(row, "Press to copy")
		linkBox.Size = UDim2.new(1, -200, 0, 36)
		linkBox.Text = DISCORD_LINK

		discordBtn.MouseButton1Click:Connect(function()
			local copied = false
			pcall(function()
				if typeof(setclipboard) == "function" then
					setclipboard(DISCORD_LINK)
					copied = true
				end
			end)

			if copied then
				notify("SOS Server", "Copied to clipboard.", 2)
			else
				pcall(function() linkBox:CaptureFocus() end)
				pcall(function() GuiService:OpenBrowserWindow(DISCORD_LINK) end)
				notify("SOS Server", "Press to copy (use the box).", 3)
			end
		end)
	end

	----------------------------------------------------------------
	-- CONTROLS TAB
	----------------------------------------------------------------
	do
		local header = makeText(controlsScroll, "Controls", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		local info = makeText(controlsScroll, "", 14, false)
		info.Size = UDim2.new(1, 0, 0, 130)
		controlsInfoRef = info

		local hint = makeText(controlsScroll,
			"Fly keybind is now in the Fly tab. Menu keybind option removed. Less clutter, more chaos.",
			13, false
		)
		hint.Size = UDim2.new(1, 0, 0, 38)
		hint.TextColor3 = Color3.fromRGB(210, 210, 210)

		refreshFlyBindUI()
	end

	----------------------------------------------------------------
	-- FLY TAB
	----------------------------------------------------------------
	do
		-- Fly keybind controls moved here per request
		local bindHeader = makeText(flyScroll, "Fly Keybind", 16, true)
		bindHeader.Size = UDim2.new(1, 0, 0, 22)

		local bindHint = makeText(flyScroll,
			"Change the key, unbind it, or toggle the bind on/off. If you turn it off, the key does nothing.\nTip: Press Escape while rebinding to cancel.",
			13, false
		)
		bindHint.Size = UDim2.new(1, 0, 0, 46)
		bindHint.TextColor3 = Color3.fromRGB(210, 210, 210)

		local bindRow = Instance.new("Frame")
		bindRow.BackgroundTransparency = 1
		bindRow.Size = UDim2.new(1, 0, 0, 44)
		bindRow.Parent = flyScroll

		local bindLay = Instance.new("UIListLayout")
		bindLay.FillDirection = Enum.FillDirection.Horizontal
		bindLay.VerticalAlignment = Enum.VerticalAlignment.Center
		bindLay.Padding = UDim.new(0, 10)
		bindLay.Parent = bindRow

		local keyLabel = makeText(bindRow, "Key:", 14, true)
		keyLabel.Size = UDim2.new(0, 44, 1, 0)

		local keyBtn = makeButton(bindRow, getFlightKeyName())
		keyBtn.Size = UDim2.new(0, 160, 0, 36)
		flyKeyBtnRef = keyBtn

		local toggleBtn = makeButton(bindRow, flightBindEnabled and "Bind: ON" or "Bind: OFF")
		toggleBtn.Size = UDim2.new(0, 140, 0, 36)
		flyBindToggleBtnRef = toggleBtn

		local unbindBtn = makeButton(bindRow, "Unbind")
		unbindBtn.Size = UDim2.new(0, 120, 0, 36)
		flyUnbindBtnRef = unbindBtn

		keyBtn.MouseButton1Click:Connect(function()
			waitingForFlyKeybind = true
			refreshFlyBindUI()
		end)

		toggleBtn.MouseButton1Click:Connect(function()
			flightBindEnabled = not flightBindEnabled
			scheduleSave()
			refreshFlyBindUI()
		end)

		unbindBtn.MouseButton1Click:Connect(function()
			waitingForFlyKeybind = false
			flightToggleKey = nil
			scheduleSave()
			refreshFlyBindUI()
		end)

		-- One capture handler (does not toggle flight while waiting)
		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if not waitingForFlyKeybind then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

			local kc = input.KeyCode
			if kc == Enum.KeyCode.Escape then
				waitingForFlyKeybind = false
				refreshFlyBindUI()
				return
			end

			waitingForFlyKeybind = false
			flightToggleKey = kc
			scheduleSave()
			refreshFlyBindUI()
		end)

		local header = makeText(flyScroll, "Flight Emotes", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		local keyLegend = makeText(flyScroll, "A = Apply    R = Reset", 13, true)
		keyLegend.Size = UDim2.new(1, 0, 0, 18)
		keyLegend.TextColor3 = Color3.fromRGB(220, 220, 220)

		local warning = makeText(flyScroll,
			"Animation IDs for flight must be a Published Marketplace/Catalog EMOTE assetid from the Creator Store.\n(If you paste random IDs, it can fail.)\n(copy and paste id in the link of the creator store version or the chosen Emote (Wont Work With Normal Marketplace ID))",
			13, false
		)
		warning.TextColor3 = Color3.fromRGB(220, 220, 220)
		warning.Size = UDim2.new(1, 0, 0, 92)

		local function makeIdRow(labelText, getFn, setFn, resetFn)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 44)
			row.Parent = flyScroll

			local l = makeText(row, labelText, 14, true)
			l.Size = UDim2.new(0, 120, 1, 0)

			local box = makeInput(row, "rbxassetid://... or number")
			box.Size = UDim2.new(1, -240, 0, 36)
			box.Position = UDim2.new(0, 130, 0, 4)
			box.Text = getFn()

			local applyBtn = makeButton(row, "A")
			applyBtn.Size = UDim2.new(0, 70, 0, 36)
			applyBtn.AnchorPoint = Vector2.new(1, 0)
			applyBtn.Position = UDim2.new(1, -90, 0, 4)

			local resetBtn = makeButton(row, "R")
			resetBtn.Size = UDim2.new(0, 70, 0, 36)
			resetBtn.AnchorPoint = Vector2.new(1, 0)
			resetBtn.Position = UDim2.new(1, -10, 0, 4)

			applyBtn.MouseButton1Click:Connect(function()
				local parsed = toAssetIdString(box.Text)
				if not parsed then
					notify("Flight Emotes", "Invalid ID. Use rbxassetid://123 or just 123", 3)
					return
				end
				setFn(parsed)
				loadFlightTracks()
				if flying then
					stopFlightAnims()
					playFloat()
				end
				scheduleSave()
				notify("Flight Emotes", "Applied.", 2)
			end)

			resetBtn.MouseButton1Click:Connect(function()
				resetFn()
				box.Text = getFn()
				loadFlightTracks()
				if flying then
					stopFlightAnims()
					playFloat()
				end
				scheduleSave()
				notify("Flight Emotes", "Reset to default.", 2)
			end)
		end

		makeIdRow("FLOAT_ID:", function() return FLOAT_ID end, function(v) FLOAT_ID = v end, function() FLOAT_ID = DEFAULT_FLOAT_ID end)
		makeIdRow("FLY_ID:", function() return FLY_ID end, function(v) FLY_ID = v end, function() FLY_ID = DEFAULT_FLY_ID end)

		local speedHeader = makeText(flyScroll, "Fly Speed", 16, true)
		speedHeader.Size = UDim2.new(1, 0, 0, 22)

		local speedRow = Instance.new("Frame")
		speedRow.BackgroundTransparency = 1
		speedRow.Size = UDim2.new(1, 0, 0, 60)
		speedRow.Parent = flyScroll

		local speedLabel = makeText(speedRow, "Speed: " .. tostring(flySpeed), 14, true)
		speedLabel.Size = UDim2.new(1, 0, 0, 18)

		local sliderBg = Instance.new("Frame")
		sliderBg.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
		sliderBg.BackgroundTransparency = 0.15
		sliderBg.BorderSizePixel = 0
		sliderBg.Position = UDim2.new(0, 0, 0, 26)
		sliderBg.Size = UDim2.new(1, 0, 0, 10)
		sliderBg.Parent = speedRow
		makeCorner(sliderBg, 999)

		local sliderFill = Instance.new("Frame")
		sliderFill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		sliderFill.BorderSizePixel = 0
		sliderFill.Size = UDim2.new(0, 0, 1, 0)
		sliderFill.Parent = sliderBg
		makeCorner(sliderFill, 999)

		local knob = Instance.new("Frame")
		knob.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		knob.BorderSizePixel = 0
		knob.Size = UDim2.new(0, 14, 0, 14)
		knob.Parent = sliderBg
		makeCorner(knob, 999)

		local function setSpeedFromAlpha(a)
			a = clamp01(a)
			local s = minFlySpeed + (maxFlySpeed - minFlySpeed) * a
			flySpeed = math.floor(s + 0.5)
			speedLabel.Text = "Speed: " .. tostring(flySpeed)
			sliderFill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, -7, 0.5, -7)
			scheduleSave()
		end

		setSpeedFromAlpha((flySpeed - minFlySpeed) / (maxFlySpeed - minFlySpeed))

		local dragging = false
		sliderBg.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
			end
		end)
		sliderBg.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
			local a = (i.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			setSpeedFromAlpha(a)
		end)
	end

	----------------------------------------------------------------
	-- ANIM PACKS TAB
	----------------------------------------------------------------
	-- (UNCHANGED BELOW THIS POINT, except the later input handler)
	----------------------------------------------------------------

	-- The rest of your script remains unchanged from your paste
	-- NOTE: This file is huge, so to avoid your chat getting nuked by the character limit,
	-- I am not re-pasting every single unchanged line here.
	--
	-- If you want, tell me "paste full file anyway" and I will output the entire full script in one go.

	----------------------------------------------------------------
	-- IMPORTANT: INPUT SECTION UPDATED (kept at end in your file)
	----------------------------------------------------------------
end

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if waitingForFlyKeybind then return end

	if flightBindEnabled and flightToggleKey and input.KeyCode == flightToggleKey then
		if not canStartFlightNow() then return end
		if flying then stopFlying() else startFlying() end
	elseif input.KeyCode == menuToggleKey then
		if arrowButton then
			arrowButton:Activate()
		end
	end
end)

--------------------------------------------------------------------
-- RENDER LOOP (Flight + FPS)
--------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	fpsAcc = fpsAcc + dt
	fpsFrames = fpsFrames + 1
	if fpsAcc >= 0.25 then
		fpsValue = math.floor((fpsFrames / fpsAcc) + 0.5)
		fpsAcc = 0
		fpsFrames = 0
	end

	if fpsLabel then
		fpsLabel.Text = tostring(fpsValue) .. " fps"
		if fpsValue < 40 then
			fpsLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
		elseif fpsValue < 60 then
			fpsLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		elseif fpsValue < 76 then
			fpsLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
		elseif fpsValue < 121 then
			fpsLabel.TextColor3 = Color3.fromRGB(80, 255, 220)
		elseif fpsValue < 241 then
			fpsLabel.TextColor3 = Color3.fromRGB(80, 140, 255)
		else
			rainbowHue = (rainbowHue + dt * 0.6) % 1
			fpsLabel.TextColor3 = Color3.fromHSV(rainbowHue, 1, 1)
		end
	end

	if not flying or not rootPart or not camera or not bodyGyro or not bodyVel then return end

	updateMovementInput()

	local camCF = camera.CFrame
	local camLook = camCF.LookVector
	local camRight = camCF.RightVector

	local moveDir = Vector3.new(0, 0, 0)
	moveDir = moveDir + camLook * (-moveInput.Z)
	moveDir = moveDir + camRight * (moveInput.X)
	moveDir = moveDir + Vector3.new(0, verticalInput, 0)

	local moveMagnitude = moveDir.Magnitude
	local hasHorizontal = Vector3.new(moveInput.X, 0, moveInput.Z).Magnitude > 0.01

	if moveMagnitude > 0 then
		local unit = moveDir.Unit
		local targetVel = unit * flySpeed
		local alphaVel = clamp01(dt * velocityLerpRate)
		currentVelocity = currentVelocity:Lerp(targetVel, alphaVel)
	else
		local alphaIdle = clamp01(dt * idleSlowdownRate)
		currentVelocity = currentVelocity:Lerp(Vector3.new(), alphaIdle)
	end
	bodyVel.Velocity = currentVelocity

	local lookDir
	if moveMagnitude > 0.05 then
		lookDir = moveDir.Unit
	else
		lookDir = camLook.Unit
	end

	if lookDir.Magnitude < 0.01 then
		lookDir = Vector3.new(0, 0, -1)
	end

	local baseCF = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDir)

	local tiltDeg
	if moveMagnitude > 0.1 then
		tiltDeg = MOVING_TILT_DEG
	else
		tiltDeg = IDLE_TILT_DEG
	end

	if not hasHorizontal and verticalInput < 0 then
		tiltDeg = 90
	elseif not hasHorizontal and verticalInput > 0 then
		tiltDeg = 0
	end

	local targetCF = baseCF * CFrame.Angles(-math.rad(tiltDeg), 0, 0)

	if not currentGyroCFrame then
		currentGyroCFrame = targetCF
	end
	currentGyroCFrame = currentGyroCFrame:Lerp(targetCF, clamp01(dt * rotationLerpRate))
	bodyGyro.CFrame = currentGyroCFrame

	if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		local now = os.clock()
		local shouldFlyAnim = (moveMagnitude > ANIM_TO_FLY_THRESHOLD)
		local shouldFloatAnim = (moveMagnitude < ANIM_TO_FLOAT_THRESHOLD)

		if shouldFlyAnim and animMode ~= "Fly" and (now - lastAnimSwitch) >= ANIM_SWITCH_COOLDOWN then
			animMode = "Fly"
			lastAnimSwitch = now
			playFly()
		elseif shouldFloatAnim and animMode ~= "Float" and (now - lastAnimSwitch) >= ANIM_SWITCH_COOLDOWN then
			animMode = "Float"
			lastAnimSwitch = now
			playFloat()
		end
	end

	if rightShoulder and defaultShoulderC0 and character then
		local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
		if torso then
			local relDir = torso.CFrame:VectorToObjectSpace(camLook)
			local yaw = math.atan2(-relDir.Z, relDir.X)
			local pitch = math.asin(relDir.Y)

			local armCF =
				CFrame.new() *
				CFrame.Angles(0, -math.pi/2, 0) *
				CFrame.Angles(-pitch * 0.9, 0, -yaw * 0.25)

			rightShoulder.C0 = defaultShoulderC0 * armCF
		end
	end
end)

--------------------------------------------------------------------
-- MAIN
--------------------------------------------------------------------
loadSettings()
getCharacter()
createUI()
applyPlayerSpeed()
applyCameraSettings()
reapplyAllOverridesAfterRespawn()
syncLightingToggles()

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.15)
	getCharacter()

	applyPlayerSpeed()
	applyCameraSettings()
	reapplyAllOverridesAfterRespawn()
	syncLightingToggles()

	if flying then
		stopFlying()
	end
end)

notify("SOS HUD", "Loaded.", 2)

local function safeLoad(url)
    local okHttp, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not okHttp or type(body) ~= "string" then
        warn("HttpGet failed:", body)
        return
    end

    if body:find("<!DOCTYPE html>") or body:find("Not Found") then
        warn("Wrong raw URL / 404. First 200 chars:\n" .. body:sub(1, 200))
        return
    end

    local fn, compileErr = loadstring(body)
    if not fn then
        warn("Compile error:", compileErr)
        return
    end

    local okRun, runErr = pcall(fn)
    if not okRun then
        warn("Runtime error:", runErr)
        return
    end

    print("Loaded addon:", url)
end

safeLoad("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/BR05TagSystem.lua")
