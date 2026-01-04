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

local flightToggleKey = Enum.KeyCode.F

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
		Version = 1,
		UserId = LocalPlayer.UserId,

		FLOAT_ID = FLOAT_ID,
		FLY_ID = FLY_ID,
		FlySpeed = flySpeed,

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
	["Gojo"] = 139000839803032,
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
	["Fake R6"] = 101293881003047,
	["Gojo"] = 82260970223217,
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
-- When you later say "put these idles in Sins" or "put these runs in Co/Owners"
-- I will add them right here.
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
-- Same method style as Anim Packs, but smaller and only Idle/Run
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

	-- Animations page content
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

	-- Fill placeholders so Co/Owners has room for future tabs
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

	-- NEW tabs pages
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

	local flyName = (flightToggleKey and flightToggleKey.Name) or "UNBOUND"

	local info = makeText(controlsScroll,
		"PC:\n- Fly Toggle: " .. flyName .. "\n- Move: WASD + Q/E\n\nMobile:\n- Use the Fly button (bottom-right)\n- Use the top arrow to open/close the menu",
		14, false
	)
	info.Size = UDim2.new(1, 0, 0, 130)

	local bindRow = Instance.new("Frame")
	bindRow.BackgroundTransparency = 1
	bindRow.Size = UDim2.new(1, 0, 0, 74)
	bindRow.Parent = controlsScroll

	local function makeBindLine(labelText, getKeyFn, setKeyFn, allowUnbind)
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 32)
		line.Parent = bindRow

		local l = makeText(line, labelText, 14, true)
		l.Size = UDim2.new(0, 170, 1, 0)

		local function keyName()
			local k = getKeyFn()
			return (k and k.Name) or "UNBOUND"
		end

		local btn = makeButton(line, keyName())
		btn.Size = UDim2.new(0, 110, 0, 30)
		btn.Position = UDim2.new(0, 180, 0, 1)

		local unbindBtn = nil
		if allowUnbind then
			unbindBtn = makeButton(line, "Unbind")
			unbindBtn.Size = UDim2.new(0, 90, 0, 30)
			unbindBtn.Position = UDim2.new(0, 296, 0, 1)
		end

		local hint = makeText(line, "Click then press a key", 12, false)
		hint.Size = UDim2.new(1, -410, 1, 0)
		hint.Position = UDim2.new(0, 395, 0, 0)
		hint.TextColor3 = Color3.fromRGB(190, 190, 190)

		local waiting = false
		btn.MouseButton1Click:Connect(function()
			waiting = true
			btn.Text = "..."
		end)

		if unbindBtn then
			unbindBtn.MouseButton1Click:Connect(function()
				waiting = false
				setKeyFn(nil)
				btn.Text = keyName()

				local fly = keyName()
				info.Text =
					"PC:\n- Fly Toggle: " .. fly .. "\n- Move: WASD + Q/E\n\nMobile:\n- Use the Fly button (bottom-right)\n- Use the top arrow to open/close the menu"

				scheduleSave()
			end)
		end

		UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			if not waiting then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			waiting = false
			setKeyFn(input.KeyCode)
			btn.Text = keyName()

			local fly = keyName()
			info.Text =
				"PC:\n- Fly Toggle: " .. fly .. "\n- Move: WASD + Q/E\n\nMobile:\n- Use the Fly button (bottom-right)\n- Use the top arrow to open/close the menu"

			scheduleSave()
		end)
	end

	makeBindLine(
		"Flight Toggle Key:",
		function() return flightToggleKey end,
		function(k) flightToggleKey = k end,
		true
	)
end


	----------------------------------------------------------------
	-- FLY TAB
	----------------------------------------------------------------
	do
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
-- ANIM PACKS TAB (Reset now restores your avatar animations properly)
----------------------------------------------------------------
do
	-- Cache your avatar's Animate IDs (from the actual Animate script on your character)
	-- so "Reset" can always go back to what your avatar had, even if Roblox returns 0s.
	local function getAvatarCache()
		if typeof(_G) ~= "table" then return nil end
		_G.__SOS_AvatarAnimCache = _G.__SOS_AvatarAnimCache or {}
		return _G.__SOS_AvatarAnimCache
	end

	local function readAnimateIds()
		local animate = getAnimateScript()
		if not animate then return nil end

		local function safeGet(folderName, childName)
			local f = animate:FindFirstChild(folderName)
			if not f then return nil end
			local a = f:FindFirstChild(childName)
			if a and a:IsA("Animation") then
				return a.AnimationId
			end
			return nil
		end

		local function safeGetDirect(childName)
			local a = animate:FindFirstChild(childName)
			if a and a:IsA("Animation") then
				return a.AnimationId
			end
			return nil
		end

		return {
			Idle1 = safeGet("idle", "Animation1"),
			Idle2 = safeGet("idle", "Animation2"),
			Walk  = safeGet("walk", "WalkAnim"),
			Run   = safeGet("run", "RunAnim"),
			Jump  = safeGet("jump", "JumpAnim"),
			Climb = safeGet("climb", "ClimbAnim"),
			Fall  = safeGet("fall", "FallAnim"),

			Swim = safeGet("swim", "Swim"),
			SwimIdle = safeGet("swim", "SwimIdle"),
			SwimDirect = safeGetDirect("swim"),
		}
	end

	local function captureAvatarAnimateIds()
		local cache = getAvatarCache()
		if not cache then return false end

		local ids = readAnimateIds()
		if not ids then return false end

		cache.Idle1 = ids.Idle1
		cache.Idle2 = ids.Idle2
		cache.Walk  = ids.Walk
		cache.Run   = ids.Run
		cache.Jump  = ids.Jump
		cache.Climb = ids.Climb
		cache.Fall  = ids.Fall
		cache.Swim = ids.Swim
		cache.SwimIdle = ids.SwimIdle
		cache.SwimDirect = ids.SwimDirect

		cache.__captured = true
		return true
	end

	local function applyAnimateIdsFromCache()
		local cache = getAvatarCache()
		if not cache or not cache.__captured then return false end

		local animate = getAnimateScript()
		if not animate or not humanoid then return false end

		local function setIf(folderName, childName, value)
			if not value then return end
			local f = animate:FindFirstChild(folderName)
			if not f then return end
			local a = f:FindFirstChild(childName)
			if a and a:IsA("Animation") then
				a.AnimationId = value
			end
		end

		local function setDirect(childName, value)
			if not value then return end
			local a = animate:FindFirstChild(childName)
			if a and a:IsA("Animation") then
				a.AnimationId = value
			end
		end

		animate.Disabled = true
		stopAllPlayingTracks(humanoid)

		setIf("idle", "Animation1", cache.Idle1)
		setIf("idle", "Animation2", cache.Idle2)
		setIf("walk", "WalkAnim", cache.Walk)
		setIf("run", "RunAnim", cache.Run)
		setIf("jump", "JumpAnim", cache.Jump)
		setIf("climb", "ClimbAnim", cache.Climb)
		setIf("fall", "FallAnim", cache.Fall)

		setIf("swim", "Swim", cache.Swim)
		setIf("swim", "SwimIdle", cache.SwimIdle)
		setDirect("swim", cache.SwimDirect)

		animate.Disabled = false
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)

		return true
	end

	-- Best-effort: also try Roblox avatar description apply (this can fix cases where Animate got nuked)
	local function resetToAvatarAnimations()
		for k, _ in pairs(stateOverrides) do
			stateOverrides[k] = nil
		end

		local didSomething = false

		-- Try applying avatar description (may be blocked in some games, so it's wrapped)
		local okDesc, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
		end)
		if okDesc and desc and humanoid then
			local okApply = pcall(function()
				humanoid:ApplyDescription(desc)
			end)
			if okApply then
				didSomething = true
				task.delay(0.2, function()
					captureAvatarAnimateIds()
				end)
			end
		end

		-- Always fallback to our captured cache (this is the reliable "your avatar anims at spawn" reset)
		if applyAnimateIdsFromCache() then
			didSomething = true
		end

		if didSomething then
			scheduleSave()
			return true
		end

		return false, "Could not restore avatar animations. (Animate missing or not captured yet)"
	end

	-- Capture as soon as possible when this tab builds, and again whenever appearance loads
	captureAvatarAnimateIds()
	if LocalPlayer and LocalPlayer.CharacterAppearanceLoaded then
		LocalPlayer.CharacterAppearanceLoaded:Connect(function()
			task.delay(0.05, function()
				captureAvatarAnimateIds()
			end)
		end)
	end
	LocalPlayer.CharacterAdded:Connect(function()
		task.delay(0.25, function()
			captureAvatarAnimateIds()
		end)
	end)

	local header = makeText(animScroll, "Anim Packs", 16, true)
	header.Size = UDim2.new(1, 0, 0, 22)

	-- Reset row at the top
	do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 44)
		row.Parent = animScroll

		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.VerticalAlignment = Enum.VerticalAlignment.Center
		lay.Padding = UDim.new(0, 10)
		lay.Parent = row

		local resetBtn = makeButton(row, "Reset to Avatar")
		resetBtn.Size = UDim2.new(0, 170, 0, 36)

		local hint = makeText(row, "Restores what your avatar had equipped (not the menu).", 13, false)
		hint.Size = UDim2.new(1, -190, 1, 0)
		hint.TextColor3 = Color3.fromRGB(210, 210, 210)

		resetBtn.MouseButton1Click:Connect(function()
			local ok, err = resetToAvatarAnimations()
			if ok then
				notify("Anim Packs", "Reset to your avatar animations.", 2)
			else
				notify("Anim Packs", err or "Reset failed.", 3)
			end
		end)
	end

	local help = makeText(animScroll, "Pick a STATE, then pick a pack name to change only that state.", 13, false)
	help.Size = UDim2.new(1, 0, 0, 34)
	help.TextColor3 = Color3.fromRGB(210, 210, 210)

	local animStateBar = Instance.new("ScrollingFrame")
	animStateBar.BackgroundTransparency = 1
	animStateBar.BorderSizePixel = 0
	animStateBar.Size = UDim2.new(1, 0, 0, 44)
	animStateBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	animStateBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	animStateBar.ScrollingDirection = Enum.ScrollingDirection.X
	animStateBar.ScrollBarThickness = 2
	animStateBar.Parent = animScroll

	local stLayout = Instance.new("UIListLayout")
	stLayout.FillDirection = Enum.FillDirection.Horizontal
	stLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stLayout.Padding = UDim.new(0, 12)
	stLayout.Parent = animStateBar

	local animCategoryBar = Instance.new("ScrollingFrame")
	animCategoryBar.BackgroundTransparency = 1
	animCategoryBar.BorderSizePixel = 0
	animCategoryBar.Size = UDim2.new(1, 0, 0, 44)
	animCategoryBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	animCategoryBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	animCategoryBar.ScrollingDirection = Enum.ScrollingDirection.X
	animCategoryBar.ScrollBarThickness = 2
	animCategoryBar.Parent = animScroll

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.SortOrder = Enum.SortOrder.LayoutOrder
	catLayout.Padding = UDim.new(0, 12)
	catLayout.Parent = animCategoryBar

	local animListScroll = Instance.new("ScrollingFrame")
	animListScroll.BackgroundTransparency = 1
	animListScroll.BorderSizePixel = 0
	animListScroll.Size = UDim2.new(1, 0, 0, 250)
	animListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	animListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	animListScroll.ScrollBarThickness = 4
	animListScroll.Parent = animScroll

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 2)
	pad.Parent = animListScroll

	local animListContainer = Instance.new("Frame")
	animListContainer.BackgroundTransparency = 1
	animListContainer.Size = UDim2.new(1, 0, 0, 0)
	animListContainer.Parent = animListScroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = animListContainer

	local function animateListPop()
		animListContainer.Position = UDim2.new(0, 26, 0, 0)
		tween(animListContainer, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		})
	end

	local stateButtons = {}
	local categoryButtons = {}

	local function rebuildPackList()
		for _, ch in ipairs(animListContainer:GetChildren()) do
			if ch:IsA("TextButton") or ch:IsA("TextLabel") or ch:IsA("Frame") then
				ch:Destroy()
			end
		end

		if lastChosenCategory == "Custom" then
			if lastChosenState == "Walk" then
				local t = makeText(animListContainer, "Custom is not available for Walk.", 14, true)
				t.Size = UDim2.new(1, 0, 0, 28)
				animateListPop()
				return
			end

			local names = listCustomNamesForState(lastChosenState)
			if #names == 0 then
				local t = makeText(animListContainer, "No Custom animations for: " .. lastChosenState, 14, true)
				t.Size = UDim2.new(1, 0, 0, 28)
				animateListPop()
				return
			end

			for _, nm in ipairs(names) do
				local b = makeButton(animListContainer, nm)
				b.Size = UDim2.new(1, 0, 0, 36)
				b.MouseButton1Click:Connect(function()
					local id = getCustomIdForState(nm, lastChosenState)
					if not id then return end
					stateOverrides[lastChosenState] = "rbxassetid://" .. tostring(id)
					local ok = applyStateOverrideToAnimate(lastChosenState, stateOverrides[lastChosenState])
					if ok then
						notify("Anim Packs", "Set " .. lastChosenState .. " to " .. nm, 2)
						scheduleSave()
					else
						notify("Anim Packs", "Failed to apply. (Animate script missing?)", 3)
					end
				end)
			end

			animateListPop()
			return
		end

		local names = listPackNamesForCategory(lastChosenCategory)
		for _, packName in ipairs(names) do
			local b = makeButton(animListContainer, packName)
			b.Size = UDim2.new(1, 0, 0, 36)
			b.MouseButton1Click:Connect(function()
				local id = getPackValueForState(packName, lastChosenState)
				if not id then
					notify("Anim Packs", "That pack has no ID for: " .. lastChosenState, 2)
					return
				end
				stateOverrides[lastChosenState] = "rbxassetid://" .. tostring(id)
				local ok = applyStateOverrideToAnimate(lastChosenState, stateOverrides[lastChosenState])
				if ok then
					notify("Anim Packs", "Set " .. lastChosenState .. " to " .. packName, 2)
					scheduleSave()
				else
					notify("Anim Packs", "Failed to apply. (Animate script missing?)", 3)
				end
			end)
		end

		animateListPop()
	end

	local function setCategory(catName)
		if lastChosenState == "Walk" and catName == "Custom" then
			catName = "Roblox Anims"
		end
		lastChosenCategory = catName
		for n, btn in pairs(categoryButtons) do
			setTabButtonActive(btn, n == catName)
		end
		rebuildPackList()
		scheduleSave()
	end

	local function setState(stateName)
		lastChosenState = stateName
		for n, btn in pairs(stateButtons) do
			setTabButtonActive(btn, n == stateName)
		end

		if lastChosenState == "Walk" and lastChosenCategory == "Custom" then
			lastChosenCategory = "Roblox Anims"
			for n, btn in pairs(categoryButtons) do
				setTabButtonActive(btn, n == lastChosenCategory)
			end
		end

		rebuildPackList()
		scheduleSave()
	end

	local states = { "Idle", "Walk", "Run", "Jump", "Climb", "Fall", "Swim" }
	for _, sName in ipairs(states) do
		local b = makeButton(animStateBar, sName)
		b.Size = UDim2.new(0, 110, 0, 36)
		stateButtons[sName] = b
		b.MouseButton1Click:Connect(function()
			setState(sName)
		end)
	end

	local cats = { "Roblox Anims", "Unreleased", "Custom" }
	for _, cName in ipairs(cats) do
		local b = makeButton(animCategoryBar, cName)
		b.Size = UDim2.new(0, (cName == "Roblox Anims" and 160 or 130), 0, 36)
		categoryButtons[cName] = b
		b.MouseButton1Click:Connect(function()
			setCategory(cName)
		end)
	end

	setCategory(lastChosenCategory)
	setState(lastChosenState)
end


----------------------------------------------------------------
-- PLAYER TAB (full block, UPDATED: BHOP menu moved, draggable title bar, menu toggle, blocks flight while BHOP enabled)
----------------------------------------------------------------
do
	local header = makeText(playerScroll, "Player", 16, true)
	header.Size = UDim2.new(1, 0, 0, 22)

	local info = makeText(playerScroll, "WalkSpeed changer. Reset uses the game's default speed for you.", 13, false)
	info.Size = UDim2.new(1, 0, 0, 34)
	info.TextColor3 = Color3.fromRGB(210, 210, 210)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 76)
	row.Parent = playerScroll

	local speedLabel = makeText(row, "Speed: " .. tostring(playerSpeed or 16), 14, true)
	speedLabel.Size = UDim2.new(1, 0, 0, 18)

	local sliderBg = Instance.new("Frame")
	sliderBg.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	sliderBg.BackgroundTransparency = 0.15
	sliderBg.BorderSizePixel = 0
	sliderBg.Position = UDim2.new(0, 0, 0, 26)
	sliderBg.Size = UDim2.new(1, 0, 0, 10)
	sliderBg.Parent = row
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

	local resetBtn = makeButton(row, "Reset")
	resetBtn.Size = UDim2.new(0, 100, 0, 34)
	resetBtn.AnchorPoint = Vector2.new(1, 0)
	resetBtn.Position = UDim2.new(1, 0, 0, 42)

	local function setSpeedFromAlpha(a)
		a = clamp01(a)
		local s = 2 + (500 - 2) * a
		playerSpeed = math.floor(s + 0.5)
		speedLabel.Text = "Speed: " .. tostring(playerSpeed)
		sliderFill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -7, 0.5, -7)
		applyPlayerSpeed()
		scheduleSave()
	end

	local function alphaFromSpeed(s)
		s = math.clamp(s, 2, 500)
		return (s - 2) / (500 - 2)
	end

	setSpeedFromAlpha(alphaFromSpeed(playerSpeed or 16))

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

	resetBtn.MouseButton1Click:Connect(function()
		resetPlayerSpeedToDefault()
		setSpeedFromAlpha(alphaFromSpeed(playerSpeed or 16))
		notify("Player", "Speed reset.", 2)
	end)

	----------------------------------------------------------------
	-- Car Animations (button hook)
	----------------------------------------------------------------
	local carHeader = makeText(playerScroll, "Car Animations", 16, true)
	carHeader.Size = UDim2.new(1, 0, 0, 22)

	local carHint = makeText(playerScroll, "Press Stop before changing animations.", 13, false)
	carHint.Size = UDim2.new(1, 0, 0, 34)
	carHint.TextColor3 = Color3.fromRGB(210, 210, 210)

	local carBtn = makeButton(playerScroll, "Look Mum im a Car")
	carBtn.Size = UDim2.new(0, 240, 0, 40)

	local function startCarUI()
		if typeof(_G) == "table" and typeof(_G.SOS_StartCarUI) == "function" then
			_G.SOS_StartCarUI()
			return true
		end
		notify("Car Animations", "Car UI not wired yet. Tell me and I will embed it here.", 4)
		return false
	end

	carBtn.MouseButton1Click:Connect(function()
		startCarUI()
	end)

	----------------------------------------------------------------
	-- BHOP (themed menu, opened via Player tab button, draggable, moved out the way, blocks flight while enabled)
	----------------------------------------------------------------
	local bhopHeader = makeText(playerScroll, "Bhop", 16, true)
	bhopHeader.Size = UDim2.new(1, 0, 0, 22)

	local bhopHint = makeText(playerScroll, "CS 1.6 style movement. Open the menu to enable and tweak settings.", 13, false)
	bhopHint.Size = UDim2.new(1, 0, 0, 34)
	bhopHint.TextColor3 = Color3.fromRGB(210, 210, 210)

	local bhopBtn = makeButton(playerScroll, "Bhop")
	bhopBtn.Size = UDim2.new(0, 240, 0, 40)

	local bhopGui = nil
	local bhopHandle = nil
	local bhopFrame = nil
	local bhopArrow = nil
	local bhopOpen = false
	local bhopTween = nil

	local bhopEnabled = false
	local bhopBodyVel = nil

	local bhopCharacter = nil
	local bhopHumanoid = nil
	local bhopRoot = nil

	local bhopOriginalWalkSpeed = nil
	local bhopOriginalJumpPower = nil

	local isTyping = false
	local maxSpeedReached = 0

	local bhopConfig = {
		GROUND_FRICTION = 6,
		GROUND_ACCELERATE = 10,
		AIR_ACCELERATE = 16,
		GROUND_SPEED = 16,
		AIR_CAP = 10,
		JUMP_POWER = 50,
		STOP_SPEED = 1,
	}

	local bhopCurrentVel = Vector3.new(0, 0, 0)

	UserInputService.TextBoxFocused:Connect(function()
		isTyping = true
	end)
	UserInputService.TextBoxFocusReleased:Connect(function()
		isTyping = false
	end)

	local function bhopTryStopFlight()
		if typeof(_G) ~= "table" then return end

		_G.SOS_BlockFlight = bhopEnabled and true or false
		_G.SOS_BlockFlightReason = bhopEnabled and "Bhop active" or nil

		if bhopEnabled then
			if typeof(_G.SOS_SetFlightEnabled) == "function" then
				pcall(function()
					_G.SOS_SetFlightEnabled(false, "Bhop active")
				end)
			end
			if typeof(_G.SOS_StopFlight) == "function" then
				pcall(function()
					_G.SOS_StopFlight("Bhop active")
				end)
			end
		end
	end

	local function bhopGetRefs()
		bhopCharacter = LocalPlayer.Character
		if not bhopCharacter then return false end
		bhopHumanoid = bhopCharacter:FindFirstChildOfClass("Humanoid")
		bhopRoot = bhopCharacter:FindFirstChild("HumanoidRootPart")
		if not bhopHumanoid or not bhopRoot then return false end
		return true
	end

	local function bhopEnsureBodyVel()
		if not bhopRoot then return end
		if bhopBodyVel and bhopBodyVel.Parent == bhopRoot then return end
		if bhopBodyVel then pcall(function() bhopBodyVel:Destroy() end) end

		bhopBodyVel = Instance.new("BodyVelocity")
		bhopBodyVel.Name = "SOS_BhopVelocity"
		bhopBodyVel.MaxForce = Vector3.new(0, 0, 0)
		bhopBodyVel.P = 10000
		bhopBodyVel.Velocity = Vector3.new(0, 0, 0)
		bhopBodyVel.Parent = bhopRoot
	end

	local function bhopIsGrounded()
		if not bhopRoot or not bhopCharacter then return false end

		local rayOrigin = bhopRoot.Position
		local rayDirection = Vector3.new(0, -4, 0)

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { bhopCharacter }
		params.FilterType = Enum.RaycastFilterType.Blacklist

		return workspace:Raycast(rayOrigin, rayDirection, params) ~= nil
	end

	local function bhopGetWishDir()
		if isTyping then
			return Vector3.new(0, 0, 0)
		end

		local cam = workspace.CurrentCamera
		if not cam then return Vector3.new(0, 0, 0) end

		local moveVector = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + cam.CFrame.RightVector end

		moveVector = Vector3.new(moveVector.X, 0, moveVector.Z)
		if moveVector.Magnitude > 0 then
			return moveVector.Unit
		end
		return Vector3.new(0, 0, 0)
	end

	local function bhopAirAccelerate(wishDir, wishSpeed, accel, dt)
		local currentSpeed = bhopCurrentVel:Dot(wishDir)
		local addSpeed = wishSpeed - currentSpeed
		if addSpeed <= 0 then return end
		local accelSpeed = math.min(accel * wishSpeed * dt, addSpeed)
		bhopCurrentVel = bhopCurrentVel + wishDir * accelSpeed
	end

	local function bhopGroundAccelerate(wishDir, wishSpeed, accel, dt)
		local currentSpeed = bhopCurrentVel:Dot(wishDir)
		local addSpeed = wishSpeed - currentSpeed
		if addSpeed <= 0 then return end
		local accelSpeed = math.min(accel * dt * wishSpeed, addSpeed)
		bhopCurrentVel = bhopCurrentVel + wishDir * accelSpeed
	end

	local function bhopApplyFriction(dt)
		local speed = bhopCurrentVel.Magnitude
		if speed < 0.1 then
			bhopCurrentVel = Vector3.new(0, 0, 0)
			return
		end

		local control = speed < bhopConfig.STOP_SPEED and bhopConfig.STOP_SPEED or speed
		local drop = control * bhopConfig.GROUND_FRICTION * dt
		local newSpeed = math.max(speed - drop, 0)

		if speed > 0 then
			bhopCurrentVel = bhopCurrentVel * (newSpeed / speed)
		end
	end

	local bhopDebugLine = nil
	local function bhopUpdateDebug(speed, grounded)
		if not bhopDebugLine then return end
		if speed > maxSpeedReached then
			maxSpeedReached = speed
		end
		local g = grounded and "GROUNDED" or "IN AIR"
		bhopDebugLine.Text = string.format("Status: %s  |  Speed: %.1f  |  Max: %.1f", g, speed, maxSpeedReached)
	end

	local function bhopSetEnabled(on)
		if not bhopGetRefs() then
			notify("Bhop", "Character not ready.", 2)
			return
		end

		bhopEnsureBodyVel()

		bhopEnabled = on and true or false
		maxSpeedReached = 0
		bhopTryStopFlight()

		if bhopEnabled then
			bhopOriginalWalkSpeed = bhopHumanoid.WalkSpeed
			bhopOriginalJumpPower = bhopHumanoid.JumpPower

			bhopHumanoid.WalkSpeed = 0
			bhopHumanoid.JumpPower = 0

			bhopCurrentVel = Vector3.new(0, 0, 0)
			bhopBodyVel.MaxForce = Vector3.new(100000, 0, 100000)
			bhopBodyVel.Velocity = Vector3.new(0, 0, 0)

			notify("Bhop", "Enabled. Flight blocked.", 2)
		else
			if bhopOriginalWalkSpeed ~= nil then
				bhopHumanoid.WalkSpeed = bhopOriginalWalkSpeed
			end
			if bhopOriginalJumpPower ~= nil then
				bhopHumanoid.JumpPower = bhopOriginalJumpPower
			end

			bhopBodyVel.MaxForce = Vector3.new(0, 0, 0)
			bhopBodyVel.Velocity = Vector3.new(0, 0, 0)

			bhopCurrentVel = Vector3.new(0, 0, 0)
			notify("Bhop", "Disabled.", 2)
		end
	end

	local function bhopPhysicsStep(dt)
		if bhopEnabled then
			bhopTryStopFlight()
		end

		if not bhopEnabled then
			if bhopRoot then
				local v = bhopRoot.Velocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				bhopUpdateDebug(speed, bhopIsGrounded())
			end
			return
		end

		if not bhopRoot or not bhopHumanoid or not bhopBodyVel then return end

		local wishDir = bhopGetWishDir()
		local onGround = bhopIsGrounded()

		if onGround then
			bhopApplyFriction(dt)
			bhopGroundAccelerate(wishDir, bhopConfig.GROUND_SPEED, bhopConfig.GROUND_ACCELERATE, dt)

			if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not isTyping then
				bhopRoot.Velocity = Vector3.new(bhopCurrentVel.X, bhopConfig.JUMP_POWER, bhopCurrentVel.Z)
			end
		else
			bhopAirAccelerate(wishDir, bhopConfig.AIR_CAP, bhopConfig.AIR_ACCELERATE, dt)
		end

		bhopBodyVel.Velocity = Vector3.new(bhopCurrentVel.X, 0, bhopCurrentVel.Z)
		bhopUpdateDebug(bhopCurrentVel.Magnitude, onGround)
	end

	local function bhopBuildMenu()
		if bhopGui and bhopGui.Parent then
			return
		end

		bhopGui = Instance.new("ScreenGui")
		bhopGui.Name = "SOS_BhopMenu"
		bhopGui.ResetOnSpawn = false
		bhopGui.IgnoreGuiInset = true
		bhopGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		bhopGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

		setupGlobalButtonSounds(bhopGui)

		bhopHandle = Instance.new("Frame")
		bhopHandle.Name = "Handle"
		bhopHandle.AnchorPoint = Vector2.new(0, 0)
		bhopHandle.Position = UDim2.new(1, -460, 0, 120)
		bhopHandle.Size = UDim2.new(0, 420, 0, 42)
		bhopHandle.BorderSizePixel = 0
		bhopHandle.Parent = bhopGui
		makeCorner(bhopHandle, 16)
		makeGlass(bhopHandle)
		makeStroke(bhopHandle, 2)

		local titleBar = Instance.new("TextButton")
		titleBar.Name = "TitleBar"
		titleBar.BackgroundTransparency = 1
		titleBar.Text = ""
		titleBar.Size = UDim2.new(1, 0, 1, 0)
		titleBar.Parent = bhopHandle

		bhopArrow = Instance.new("TextButton")
		bhopArrow.Name = "Arrow"
		bhopArrow.BackgroundTransparency = 1
		bhopArrow.Size = UDim2.new(0, 40, 0, 40)
		bhopArrow.Position = UDim2.new(0, 8, 0, 1)
		bhopArrow.Text = "˄"
		bhopArrow.Font = Enum.Font.GothamBold
		bhopArrow.TextSize = 22
		bhopArrow.TextColor3 = Color3.fromRGB(240, 240, 240)
		bhopArrow.Parent = bhopHandle

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -90, 1, 0)
		title.Position = UDim2.new(0, 70, 0, 0)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.Text = "Bhop"
		title.TextColor3 = Color3.fromRGB(245, 245, 245)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Parent = bhopHandle

		bhopFrame = Instance.new("Frame")
		bhopFrame.Name = "Menu"
		bhopFrame.AnchorPoint = Vector2.new(0, 0)
		bhopFrame.Position = UDim2.new(1, -460, 0, 166)
		bhopFrame.Size = UDim2.new(0, 420, 0, 360)
		bhopFrame.BorderSizePixel = 0
		bhopFrame.Parent = bhopGui
		makeCorner(bhopFrame, 16)
		makeGlass(bhopFrame)
		makeStroke(bhopFrame, 2)

		local function clampToScreen()
			local cam = workspace.CurrentCamera
			if not cam then return end
			local v = cam.ViewportSize
			local x = bhopHandle.Position.X.Offset
			local y = bhopHandle.Position.Y.Offset

			x = math.clamp(x, 10 - (v.X), v.X - bhopHandle.Size.X.Offset - 10)
			y = math.clamp(y, 10, v.Y - bhopHandle.Size.Y.Offset - 10)

			bhopHandle.Position = UDim2.new(0, x, 0, y)
			bhopFrame.Position = UDim2.new(0, x, 0, y + bhopHandle.Size.Y.Offset + 4)
		end

		local dragOn = false
		local dragStart = nil
		local startPos = nil

		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragOn = true
				dragStart = input.Position
				startPos = bhopHandle.Position
			end
		end)

		titleBar.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragOn = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragOn then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local delta = input.Position - dragStart

			local newX = startPos.X.Offset + delta.X
			local newY = startPos.Y.Offset + delta.Y

			bhopHandle.Position = UDim2.new(0, newX, 0, newY)
			bhopFrame.Position = UDim2.new(0, newX, 0, newY + bhopHandle.Size.Y.Offset + 4)
			clampToScreen()
		end)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Scroll"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ScrollBarThickness = 4
		scroll.Parent = bhopFrame

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = scroll

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.Parent = scroll

		local statusRow = Instance.new("Frame")
		statusRow.BackgroundTransparency = 1
		statusRow.Size = UDim2.new(1, 0, 0, 44)
		statusRow.Parent = scroll

		local statusLay = Instance.new("UIListLayout")
		statusLay.FillDirection = Enum.FillDirection.Horizontal
		statusLay.VerticalAlignment = Enum.VerticalAlignment.Center
		statusLay.Padding = UDim.new(0, 10)
		statusLay.Parent = statusRow

		local enableBtn = makeButton(statusRow, "Enable")
		enableBtn.Size = UDim2.new(0, 140, 0, 40)

		local disableBtn = makeButton(statusRow, "Disable")
		disableBtn.Size = UDim2.new(0, 140, 0, 40)

		bhopDebugLine = makeText(scroll, "Status: GROUNDED  |  Speed: 0.0  |  Max: 0.0", 13, true)
		bhopDebugLine.Size = UDim2.new(1, 0, 0, 22)
		bhopDebugLine.TextColor3 = Color3.fromRGB(220, 220, 220)

		local cfgHeader = makeText(scroll, "Config", 15, true)
		cfgHeader.Size = UDim2.new(1, 0, 0, 20)

		local function makeCfgRow(labelText, key, minV, maxV, step)
			local r = Instance.new("Frame")
			r.BackgroundTransparency = 1
			r.Size = UDim2.new(1, 0, 0, 44)
			r.Parent = scroll

			local l = makeText(r, labelText, 13, true)
			l.Size = UDim2.new(0, 160, 1, 0)

			local minus = makeButton(r, "-")
			minus.Size = UDim2.new(0, 40, 0, 36)
			minus.Position = UDim2.new(0, 170, 0, 4)

			local box = makeInput(r, "")
			box.Size = UDim2.new(0, 120, 0, 36)
			box.Position = UDim2.new(0, 220, 0, 4)
			box.Text = tostring(bhopConfig[key])

			local plus = makeButton(r, "+")
			plus.Size = UDim2.new(0, 40, 0, 36)
			plus.Position = UDim2.new(0, 350, 0, 4)

			local function setValue(v)
				v = tonumber(v)
				if not v then return end
				v = math.clamp(v, minV, maxV)
				if step and step > 0 then
					v = math.floor((v / step) + 0.5) * step
				end
				bhopConfig[key] = v
				box.Text = tostring(v)
			end

			minus.MouseButton1Click:Connect(function()
				setValue((bhopConfig[key] or 0) - step)
			end)
			plus.MouseButton1Click:Connect(function()
				setValue((bhopConfig[key] or 0) + step)
			end)
			box.FocusLost:Connect(function()
				setValue(tonumber(box.Text))
			end)
		end

		makeCfgRow("Ground Friction", "GROUND_FRICTION", 0, 10000, 1)
		makeCfgRow("Ground Accel", "GROUND_ACCELERATE", 1, 10000, 1)
		makeCfgRow("Air Accel", "AIR_ACCELERATE", 1, 100000, 1)
		makeCfgRow("Ground Speed", "GROUND_SPEED", 1, 10000, 1)
		makeCfgRow("Air Cap", "AIR_CAP", 0, 10000, 1)
		makeCfgRow("Jump Power", "JUMP_POWER", 1, 10000, 1)
		makeCfgRow("Stop Speed", "STOP_SPEED", 0, 10000, 1)

		enableBtn.MouseButton1Click:Connect(function()
			bhopSetEnabled(true)
		end)
		disableBtn.MouseButton1Click:Connect(function()
			bhopSetEnabled(false)
		end)

		local function setMenuVisible(visible, instant)
			bhopOpen = visible
			bhopArrow.Text = visible and "˅" or "˄"

			if bhopTween then
				pcall(function() bhopTween:Cancel() end)
				bhopTween = nil
			end

			if instant then
				bhopFrame.Visible = visible
				bhopFrame.BackgroundTransparency = visible and 0.18 or 1
				return
			end

			if visible then
				bhopFrame.Visible = true
				bhopFrame.BackgroundTransparency = 1
				bhopTween = tween(bhopFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.18
				})
			else
				bhopTween = tween(bhopFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1
				})
				bhopTween.Completed:Connect(function()
					if not bhopOpen then
						bhopFrame.Visible = false
					end
				end)
			end
		end

		bhopArrow.MouseButton1Click:Connect(function()
			setMenuVisible(not bhopOpen, false)
		end)

		setMenuVisible(false, true)
		clampToScreen()
	end

	bhopBtn.MouseButton1Click:Connect(function()
		bhopBuildMenu()
		if not bhopGui then return end

		local show = not (bhopHandle and bhopHandle.Visible)
		if bhopHandle then bhopHandle.Visible = show end
		if bhopFrame then bhopFrame.Visible = show and bhopOpen or false end

		if not show then
			bhopSetEnabled(false)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not bhopGui then return end
		bhopPhysicsStep(dt)
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.15)
		bhopGetRefs()
		bhopEnsureBodyVel()
		bhopSetEnabled(false)
	end)

	----------------------------------------------------------------
	-- VISIBILITY (sub-section inside Player tab)
	----------------------------------------------------------------
	local visHeader = makeText(playerScroll, "Visibility", 16, true)
	visHeader.Size = UDim2.new(1, 0, 0, 22)

	local visHint = makeText(playerScroll, "Forces parts (and accessories attached to them) to stay visible in first person.", 13, false)
	visHint.Size = UDim2.new(1, 0, 0, 34)
	visHint.TextColor3 = Color3.fromRGB(210, 210, 210)

	local visRow = Instance.new("Frame")
	visRow.BackgroundTransparency = 1
	visRow.Size = UDim2.new(1, 0, 0, 44)
	visRow.Parent = playerScroll

	local visLay = Instance.new("UIListLayout")
	visLay.FillDirection = Enum.FillDirection.Horizontal
	visLay.VerticalAlignment = Enum.VerticalAlignment.Center
	visLay.Padding = UDim.new(0, 10)
	visLay.Parent = visRow

	local armsBtn = makeButton(visRow, "Arms: OFF")
	armsBtn.Size = UDim2.new(0, 160, 0, 40)

	local bodyBtn = makeButton(visRow, "Body: OFF")
	bodyBtn.Size = UDim2.new(0, 160, 0, 40)

	local legsBtn = makeButton(visRow, "Legs: OFF")
	legsBtn.Size = UDim2.new(0, 160, 0, 40)

	local visState = {
		arms = false,
		body = false,
		legs = false,
		conn = nil,
	}

	local function isArmPartName(n)
		if n == "LeftUpperArm" or n == "LeftLowerArm" or n == "LeftHand" then return true end
		if n == "RightUpperArm" or n == "RightLowerArm" or n == "RightHand" then return true end
		if n == "Left Arm" or n == "Right Arm" then return true end
		return false
	end

	local function isLegPartName(n)
		if n == "LeftUpperLeg" or n == "LeftLowerLeg" or n == "LeftFoot" then return true end
		if n == "RightUpperLeg" or n == "RightLowerLeg" or n == "RightFoot" then return true end
		if n == "Left Leg" or n == "Right Leg" then return true end
		return false
	end

	local function isBodyPartName(n)
		if n == "UpperTorso" or n == "LowerTorso" or n == "Head" then return true end
		if n == "Torso" or n == "Head" then return true end
		return false
	end

	local function collectTargetParts(char)
		local parts = {}
		if not char then return parts end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				local n = d.Name
				if (visState.arms and isArmPartName(n))
					or (visState.legs and isLegPartName(n))
					or (visState.body and isBodyPartName(n))
				then
					table.insert(parts, d)
				end
			end
		end
		return parts
	end

	local function buildPartSet(parts)
		local set = {}
		for _, p in ipairs(parts) do
			set[p] = true
		end
		return set
	end

	local function accessoryAttachedToParts(accessory, partSet)
		if not accessory or not accessory:IsA("Accessory") then return false end
		local handle = accessory:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then return false end

		for _, w in ipairs(handle:GetDescendants()) do
			if w:IsA("Weld") or w:IsA("Motor6D") then
				local p0 = w.Part0
				local p1 = w.Part1
				if (p0 and partSet[p0]) or (p1 and partSet[p1]) then
					return true
				end
			elseif w:IsA("WeldConstraint") then
				local p0 = w.Part0
				local p1 = w.Part1
				if (p0 and partSet[p0]) or (p1 and partSet[p1]) then
					return true
				end
			end
		end

		for _, j in ipairs(handle:GetJoints()) do
			if j:IsA("Weld") or j:IsA("Motor6D") then
				local p0 = j.Part0
				local p1 = j.Part1
				if (p0 and partSet[p0]) or (p1 and partSet[p1]) then
					return true
				end
			elseif j:IsA("WeldConstraint") then
				local p0 = j.Part0
				local p1 = j.Part1
				if (p0 and partSet[p0]) or (p1 and partSet[p1]) then
					return true
				end
			end
		end

		return false
	end

	local function refreshVisButtons()
		armsBtn.Text = visState.arms and "Arms: ON" or "Arms: OFF"
		bodyBtn.Text = visState.body and "Body: ON" or "Body: OFF"
		legsBtn.Text = visState.legs and "Legs: ON" or "Legs: OFF"

		setTabButtonActive(armsBtn, visState.arms)
		setTabButtonActive(bodyBtn, visState.body)
		setTabButtonActive(legsBtn, visState.legs)
	end

	local function ensureVisLoop()
		local anyOn = visState.arms or visState.body or visState.legs

		if visState.conn then
			if anyOn then
				return
			end
			visState.conn:Disconnect()
			visState.conn = nil
		end

		if not anyOn then
			return
		end

		visState.conn = RunService.RenderStepped:Connect(function()
			local char = LocalPlayer.Character
			if not char then return end

			local parts = collectTargetParts(char)
			local set = buildPartSet(parts)

			for _, p in ipairs(parts) do
				p.LocalTransparencyModifier = 0
			end

			for _, ch in ipairs(char:GetChildren()) do
				if ch:IsA("Accessory") then
					if accessoryAttachedToParts(ch, set) then
						local h = ch:FindFirstChild("Handle")
						if h and h:IsA("BasePart") then
							h.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end)
	end

	armsBtn.MouseButton1Click:Connect(function()
		visState.arms = not visState.arms
		refreshVisButtons()
		ensureVisLoop()
	end)

	bodyBtn.MouseButton1Click:Connect(function()
		visState.body = not visState.body
		refreshVisButtons()
		ensureVisLoop()
	end)

	legsBtn.MouseButton1Click:Connect(function()
		visState.legs = not visState.legs
		refreshVisButtons()
		ensureVisLoop()
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		if visState.conn then
			task.wait(0.1)
			ensureVisLoop()
		end
	end)

	refreshVisButtons()
end

	----------------------------------------------------------------
	-- LIGHTING TAB (unchanged)
	----------------------------------------------------------------
	do
		local header = makeText(lightingScroll, "Lighting", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		readLightingSaveState()

		local topRow = Instance.new("Frame")
		topRow.BackgroundTransparency = 1
		topRow.Size = UDim2.new(1, 0, 0, 44)
		topRow.Parent = lightingScroll

		local topLay = Instance.new("UIListLayout")
		topLay.FillDirection = Enum.FillDirection.Horizontal
		topLay.Padding = UDim.new(0, 10)
		topLay.Parent = topRow

		local enableBtn = makeButton(topRow, LightingState.Enabled and "Enabled" or "Disabled")
		enableBtn.Size = UDim2.new(0, 140, 0, 36)

		local resetBtn = makeButton(topRow, "Reset Lighting")
		resetBtn.Size = UDim2.new(0, 160, 0, 36)

		enableBtn.MouseButton1Click:Connect(function()
			LightingState.Enabled = not LightingState.Enabled
			enableBtn.Text = LightingState.Enabled and "Enabled" or "Disabled"
			writeLightingSaveState()
			syncLightingToggles()
		end)

		resetBtn.MouseButton1Click:Connect(function()
			resetLightingToOriginal()
			notify("Lighting", "Reset.", 2)
		end)

		local skyHeader = makeText(lightingScroll, "Sky Presets", 15, true)
		skyHeader.Size = UDim2.new(1, 0, 0, 20)

		local skyBar = Instance.new("ScrollingFrame")
		skyBar.BackgroundTransparency = 1
		skyBar.BorderSizePixel = 0
		skyBar.Size = UDim2.new(1, 0, 0, 44)
		skyBar.CanvasSize = UDim2.new(0, 0, 0, 0)
		skyBar.AutomaticCanvasSize = Enum.AutomaticSize.X
		skyBar.ScrollingDirection = Enum.ScrollingDirection.X
		skyBar.ScrollBarThickness = 2
		skyBar.Parent = lightingScroll

		local skyLayout = Instance.new("UIListLayout")
		skyLayout.FillDirection = Enum.FillDirection.Horizontal
		skyLayout.SortOrder = Enum.SortOrder.LayoutOrder
		skyLayout.Padding = UDim.new(0, 10)
		skyLayout.Parent = skyBar

		local skyButtons = {}

		local function setSkyActive(name)
			for k, b in pairs(skyButtons) do
				setTabButtonActive(b, k == name)
			end
		end

		for name, _ in pairs(SKY_PRESETS) do
			local b = makeButton(skyBar, name)
			b.Size = UDim2.new(0, 190, 0, 36)
			skyButtons[name] = b
			b.MouseButton1Click:Connect(function()
				setSkyActive(name)
				applySkyPreset(name)
				notify("Lighting", "Applied: " .. name, 2)
			end)
		end

		local fxHeader = makeText(lightingScroll, "Effects", 15, true)
		fxHeader.Size = UDim2.new(1, 0, 0, 20)

		local function makeToggle(nameKey, labelText)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 40)
			row.Parent = lightingScroll

			local btn = makeButton(row, "")
			btn.Size = UDim2.new(0, 220, 0, 36)
			btn.Position = UDim2.new(0, 0, 0, 2)

			local function refresh()
				btn.Text = (LightingState.Toggles[nameKey] and "ON: " or "OFF: ") .. labelText
				setTabButtonActive(btn, LightingState.Toggles[nameKey])
			end

			btn.MouseButton1Click:Connect(function()
				LightingState.Toggles[nameKey] = not LightingState.Toggles[nameKey]
				writeLightingSaveState()
				syncLightingToggles()
				refresh()
			end)

			refresh()
		end

		makeToggle("Sky", "Sky")
		makeToggle("Atmosphere", "Atmosphere")
		makeToggle("ColorCorrection", "Color Correction")
		makeToggle("Bloom", "Bloom")
		makeToggle("DepthOfField", "Depth Of Field")
		makeToggle("MotionBlur", "Motion Blur")
		makeToggle("SunRays", "Sun Rays")

		if LightingState.SelectedSky and SKY_PRESETS[LightingState.SelectedSky] then
			setSkyActive(LightingState.SelectedSky)
			if LightingState.Enabled then
				applySkyPreset(LightingState.SelectedSky)
			end
		end
	end

	----------------------------------------------------------------
	-- MIC UP TAB (unchanged)
	----------------------------------------------------------------
	if micupScroll then
		local header = makeText(micupScroll, "Mic up", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		local msg = makeText(micupScroll,
			"For those of you who play this game hopefully your not a P£D0 also dont be weird and enjoy this tab\n(Some Stuff Will Be Added Soon)",
			14, false
		)
		msg.Size = UDim2.new(1, 0, 0, 120)

		local coilBtn = makeButton(micupScroll, "Better Speed Coil")
		coilBtn.Size = UDim2.new(0, 220, 0, 40)

		coilBtn.MouseButton1Click:Connect(function()
			if ownsAnyVipPass() then
				giveBetterSpeedCoil()
			else
				notify("VIP Required", "You need VIP First.", 3)
			end
		end)
	end

	----------------------------------------------------------------
	-- SERVER TAB (unchanged)
	----------------------------------------------------------------
	do
		local header = makeText(serverScroll, "Server", 16, true)
		header.Size = UDim2.new(1, 0, 0, 22)

		local controls = makeText(serverScroll, "Controls\n- Rejoin: same server\n- Server Hop: best-effort (highest players).", 14, false)
		controls.Size = UDim2.new(1, 0, 0, 56)

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 44)
		row.Parent = serverScroll

		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.Padding = UDim.new(0, 10)
		lay.Parent = row

		local rejoinBtn = makeButton(row, "Rejoin (Same Server)")
		rejoinBtn.Size = UDim2.new(0, 230, 0, 36)

		local hopBtn = makeButton(row, "Server Hop")
		hopBtn.Size = UDim2.new(0, 140, 0, 36)

		rejoinBtn.MouseButton1Click:Connect(function()
			notify("Server", "Rejoining same server...", 2)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
		end)

		hopBtn.MouseButton1Click:Connect(function()
			notify("Server", "Searching servers...", 2)

			task.spawn(function()
				local placeId = game.PlaceId
				local cursor = ""
				local best = nil

				for _ = 1, 3 do
					local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"
					if cursor ~= "" then
						url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
					end

					local ok, res = pcall(function()
						return HttpService:GetAsync(url)
					end)

					if not ok then
						notify("Server Hop", "HTTP failed. (HttpEnabled might be off)", 4)
						pcall(function()
							TeleportService:Teleport(placeId, LocalPlayer)
						end)
						return
					end

					local data = HttpService:JSONDecode(res)
					for _, srv in ipairs(data.data or {}) do
						if srv.id and srv.id ~= game.JobId then
							if not best or (srv.playing or 0) > (best.playing or 0) then
								best = srv
							end
						end
					end

					cursor = data.nextPageCursor or ""
					if cursor == "" then break end
				end

				if best and best.id then
					notify("Server Hop", "Teleporting...", 2)
					pcall(function()
						TeleportService:TeleportToPlaceInstance(placeId, best.id, LocalPlayer)
					end)
				else
					notify("Server Hop", "No server found. Trying normal teleport.", 3)
					pcall(function()
						TeleportService:Teleport(placeId, LocalPlayer)
					end)
				end
			end)
		end)
	end

	----------------------------------------------------------------
	-- CLIENT TAB (unchanged)
	----------------------------------------------------------------
	do
		local t = makeText(clientScroll, "Controls\n(Coming soon)", 14, true)
		t.Size = UDim2.new(1, 0, 0, 50)
	end

	----------------------------------------------------------------
	-- SINS TAB (now with mini tabs + Animations)
	----------------------------------------------------------------
	if sinsScroll then
		buildMiniAnimPicker(
			sinsScroll,
			"Sins",
			SinsIdle,
			SinsRun,
			{ "Animations", "Notes" }
		)
	end

	----------------------------------------------------------------
	-- CO/OWNERS TAB (now with mini tabs + Animations, room for more)
	----------------------------------------------------------------
	if coOwnersScroll then
		buildMiniAnimPicker(
			coOwnersScroll,
			"Co/Owners",
			CoOwnersIdle,
			CoOwnersRun,
			{ "Animations", "Tools", "Settings" }
		)
	end

	----------------------------------------------------------------
	-- Tabs buttons + switching
	----------------------------------------------------------------
	local tabButtons = {}
	local activePageName = "Info"

	local function switchPage(pageName)
		if pageName == activePageName then return end
		local newPg = pages[pageName]
		local oldPg = pages[activePageName]
		if not newPg then return end

		for n, btn in pairs(tabButtons) do
			setTabButtonActive(btn, n == pageName)
		end

		local newFrame = newPg.Page
		local oldFrame = oldPg and oldPg.Page or nil

		newFrame.Visible = true
		newFrame.Position = UDim2.new(0, 26, 0, 0)

		tween(newFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		})

		if oldFrame then
			local twn = tween(oldFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, -26, 0, 0)
			})
			twn.Completed:Connect(function()
				oldFrame.Visible = false
				oldFrame.Position = UDim2.new(0, 0, 0, 0)
			end)
		end

		activePageName = pageName
	end

	local function addTabButton(pageName, order, w)
		local b = makeButton(tabsBar, pageName)
		b.LayoutOrder = order or 1
		b.Size = UDim2.new(0, w or 120, 0, 38)
		tabButtons[pageName] = b

		b.MouseButton1Click:Connect(function()
			switchPage(pageName)
		end)
	end

	addTabButton("Info", 1)
	addTabButton("Controls", 2, 130)
	addTabButton("Fly", 3)
	addTabButton("Anim Packs", 4, 140)
	addTabButton("Player", 5)
	addTabButton("Camera", 6)
	addTabButton("Lighting", 7)
	addTabButton("Server", 8)
	addTabButton("Client", 9)

	if sinsPage then
		addTabButton("Sins", 10, 120)
	end
	if coOwnersPage then
		addTabButton("Co/Owners", 11, 140)
	end
	if micupPage then
		addTabButton("Mic up", 12, 120)
	end

	pages["Info"].Page.Visible = true
	setTabButtonActive(tabButtons["Info"], true)
----------------------------------------------------------------
-- MOBILE UI SCALE (menu half size, top bar quarter size)
-- Paste this inside createUI() right before the "Menu toggle (arrow)" section
----------------------------------------------------------------
do
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile and menuFrame and menuHandle then
		local menuScale = 0.5
		local barScale = 0.25

		local baseMenuW = menuFrame.Size.X.Offset
		local baseMenuH = menuFrame.Size.Y.Offset

		local baseBarW = menuHandle.Size.X.Offset
		local baseBarH = menuHandle.Size.Y.Offset

		local newMenuW = math.max(240, math.floor(baseMenuW * menuScale + 0.5))
		local newMenuH = math.max(170, math.floor(baseMenuH * menuScale + 0.5))

		local newBarW = math.max(220, math.floor(baseBarW * menuScale + 0.5))
		local newBarH = math.max(24,  math.floor(baseBarH * barScale + 0.5))

		menuHandle.Size = UDim2.new(0, newBarW, 0, newBarH)

		menuFrame.Size = UDim2.new(0, newMenuW, 0, newMenuH)
		menuFrame.Position = UDim2.new(0.5, 0, 0, menuHandle.Position.Y.Offset + newBarH + 4)

		if arrowButton then
			local ab = math.max(24, math.floor(newBarH))
			arrowButton.Size = UDim2.new(0, ab, 0, ab)
			arrowButton.Position = UDim2.new(0, 6, 0, 0)
			arrowButton.TextSize = math.max(14, math.floor(ab * 0.6))
		end

		for _, ch in ipairs(menuHandle:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch.TextSize = math.max(12, math.floor(newBarH * 0.55))
				ch.Position = UDim2.new(0, 40, 0, 0)
				ch.Size = UDim2.new(1, -50, 1, 0)
				break
			end
		end
	end
end

	----------------------------------------------------------------
	-- Menu toggle (arrow), starts CLOSED and reliable
	----------------------------------------------------------------
	menuOpen = false
	menuFrame.Visible = false
	arrowButton.Text = "˄"

	local openPos = menuFrame.Position
	local closedPos = UDim2.new(openPos.X.Scale, openPos.X.Offset, openPos.Y.Scale, openPos.Y.Offset - (menuFrame.Size.Y.Offset + 10))

	local function setMenu(open, instant)
		menuOpen = open
		arrowButton.Text = open and "˅" or "˄"

		if menuTween then
			pcall(function() menuTween:Cancel() end)
			menuTween = nil
		end

		if instant then
			menuFrame.Visible = open
			menuFrame.Position = open and openPos or closedPos
			menuFrame.BackgroundTransparency = open and 0.18 or 1
			return
		end

		if open then
			menuFrame.Visible = true
			menuFrame.Position = closedPos
			menuFrame.BackgroundTransparency = 1
			menuTween = tween(menuFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = openPos,
				BackgroundTransparency = 0.18
			})
		else
			menuTween = tween(menuFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = closedPos,
				BackgroundTransparency = 1
			})
			menuTween.Completed:Connect(function()
				if not menuOpen then
					menuFrame.Visible = false
				end
			end)
		end
	end

	arrowButton.MouseButton1Click:Connect(function()
		setMenu(not menuOpen, false)
	end)

	setMenu(false, true)

	----------------------------------------------------------------
	-- Mobile Fly button (only on mobile)
	----------------------------------------------------------------
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		mobileFlyButton = makeButton(gui, "Fly")
		mobileFlyButton.Name = "MobileFly"
		mobileFlyButton.AnchorPoint = Vector2.new(1, 1)
		mobileFlyButton.Position = MOBILE_FLY_POS
		mobileFlyButton.Size = MOBILE_FLY_SIZE
		mobileFlyButton.TextSize = 18

		mobileFlyButton.MouseButton1Click:Connect(function()
			if flying then stopFlying() else startFlying() end
		end)
	end

	applyPlayerSpeed()
	applyCameraSettings()
	syncLightingToggles()
end

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == flightToggleKey then
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

-- Bear Poo Menu Single UserId Buttons + Hidden Slash Commands
-- Paste this at the very end of your SOS HUD LocalScript (StarterPlayerScripts)
-- Only UserId 2440542440 can see the menu and use it
-- Buttons trigger everything locally (so nothing shows in public chat)
-- Also supports hidden slash commands /bp and /bearpoo if the place uses TextChatService

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local lp = Players.LocalPlayer
if not lp then
	return
end

local TARGET_USER_ID = 2440542440
if lp.UserId ~= TARGET_USER_ID then
	return
end

-- Anti spam settings
local GLOBAL_MIN_GAP = 0.20
local WINDOW_SECONDS = 10
local WINDOW_MAX_COMMANDS = 10

local COOLDOWN = {
	help = 1.2,
	menu = 0.8,
	status = 0.8,
	stink = 0.7,
	trail = 0.7,
	fart = 0.7,
	alloff = 1.1,
	splat = 2.5,
}

local state = {
	MenuVisible = true,
	StinkCloud = false,
	PooTrail = false,
	FartStep = false,
}

local currentChar = nil
local emitters = {}
local trailConn = nil
local fartConn = nil

local lastGlobalUse = 0
local lastCmdUse = {}
local windowTimes = {}
local lastWarn = 0

local function now()
	return os.clock()
end

local function canRunCommand(cmdKey)
	local t = now()

	if (t - lastGlobalUse) < GLOBAL_MIN_GAP then
		return false
	end

	local cd = COOLDOWN[cmdKey] or 0.8
	local last = lastCmdUse[cmdKey] or 0
	if (t - last) < cd then
		return false
	end

	for i = #windowTimes, 1, -1 do
		if (t - windowTimes[i]) > WINDOW_SECONDS then
			table.remove(windowTimes, i)
		end
	end

	if #windowTimes >= WINDOW_MAX_COMMANDS then
		return false
	end

	lastGlobalUse = t
	lastCmdUse[cmdKey] = t
	table.insert(windowTimes, t)
	return true
end

local function warnThrottle(msg)
	local t = now()
	if (t - lastWarn) > 1.6 then
		lastWarn = t
		warn(msg)
	end
end

local function sysMsg(text)
	local ok = false

	if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local chans = TextChatService:FindFirstChild("TextChannels")
		local general = chans and chans:FindFirstChild("RBXGeneral")
		if general and general.DisplaySystemMessage then
			ok = pcall(function()
				general:DisplaySystemMessage("[BearPoo] " .. tostring(text))
			end)
		end
	end

	if ok then return end

	pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = "[BearPoo] " .. tostring(text),
		})
	end)
end

-- British teen humour, low frequency:
-- If anyone asks, this is wildlife management. Very serious. Extremely mature.

local function getHRP(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function clearEmitter(key)
	local obj = emitters[key]
	if obj then
		obj:Destroy()
		emitters[key] = nil
	end
end

local function attachStinkCloud(char)
	local hrp = getHRP(char)
	if not hrp then return end

	clearEmitter("StinkCloud")

	local att = Instance.new("Attachment")
	att.Name = "BearPoo_StinkAttachment"
	att.Parent = hrp

	local pe = Instance.new("ParticleEmitter")
	pe.Name = "BearPoo_StinkCloud"
	pe.Parent = att
	pe.Rate = 18
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(0.4, 1.1)
	pe.SpreadAngle = Vector2.new(140, 140)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	pe.Color = ColorSequence.new(Color3.fromRGB(90, 62, 34), Color3.fromRGB(140, 100, 55))
	pe.ZOffset = -1

	emitters["StinkCloud"] = att
end

local function stopStinkCloud()
	clearEmitter("StinkCloud")
end

local function spawnPooPuff(whereCFrame)
	local p = Instance.new("Part")
	p.Name = "BearPoo_Puff"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = Vector3.new(0.9, 0.25, 0.9)
	p.CFrame = whereCFrame
	p.Color = Color3.fromRGB(95, 63, 35)
	p.Material = Enum.Material.Mud
	p.Transparency = 0.05
	p.Parent = workspace
	Debris:AddItem(p, 2.2)

	local att = Instance.new("Attachment")
	att.Parent = p

	local pe = Instance.new("ParticleEmitter")
	pe.Parent = att
	pe.Rate = 0
	pe.Speed = NumberRange.new(1.6, 2.6)
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Color = ColorSequence.new(Color3.fromRGB(110, 78, 45))
	pe:Emit(10)
end

local function startPooTrail(char)
	if trailConn then
		trailConn:Disconnect()
		trailConn = nil
	end

	local hrp = getHRP(char)
	if not hrp then return end

	local lastDrop = 0
	trailConn = RunService.Heartbeat:Connect(function(dt)
		if not state.PooTrail then return end
		if not currentChar or currentChar ~= char then return end

		lastDrop += dt
		if lastDrop < 0.18 then
			return
		end
		lastDrop = 0

		local cf = hrp.CFrame * CFrame.new(0, -2.6, 1.2)
		spawnPooPuff(cf)
	end)
end

local function stopPooTrail()
	if trailConn then
		trailConn:Disconnect()
		trailConn = nil
	end
end

local function startFartSteps(char)
	if fartConn then
		fartConn:Disconnect()
		fartConn = nil
	end

	local hum = getHumanoid(char)
	if not hum then return end

	local last = 0
	fartConn = RunService.Heartbeat:Connect(function(dt)
		if not state.FartStep then return end
		if not currentChar or currentChar ~= char then return end

		last += dt
		if last < 0.6 then
			return
		end
		last = 0

		if hum.MoveDirection.Magnitude > 0.2 then
			local hrp = getHRP(char)
			if hrp then
				local s = Instance.new("Sound")
				s.Name = "BearPoo_FartStep"
				s.SoundId = "rbxassetid://9113420777"
				s.Volume = 0.18
				s.PlaybackSpeed = 0.95 + (math.random() * 0.15)
				s.Parent = hrp
				s:Play()
				Debris:AddItem(s, 2)
			end
		end
	end)
end

local function stopFartSteps()
	if fartConn then
		fartConn:Disconnect()
		fartConn = nil
	end
end

local function cleanupAll()
	stopStinkCloud()
	stopPooTrail()
	stopFartSteps()
end

local function applyAllForChar(char)
	currentChar = char

	if state.StinkCloud then
		attachStinkCloud(char)
	else
		stopStinkCloud()
	end

	if state.PooTrail then
		startPooTrail(char)
	else
		stopPooTrail()
	end

	if state.FartStep then
		startFartSteps(char)
	else
		stopFartSteps()
	end
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BearPooMenuGui"
gui.ResetOnSpawn = false
gui.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "BearPooFrame"
frame.Size = UDim2.new(0, 270, 0, 250)
frame.Position = UDim2.new(1, -290, 0, 90)
frame.BackgroundColor3 = Color3.fromRGB(26, 24, 22)
frame.BackgroundTransparency = 0.12
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = frame

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)
pad.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 235, 225)
title.Text = "🐻 Bear Poo Menu"
title.Parent = frame

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Size = UDim2.new(1, 0, 0, 16)
sub.Position = UDim2.new(0, 0, 0, 24)
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(200, 190, 175)
sub.Text = "Buttons are local. Optional: /bp help"
sub.Parent = frame

local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.Size = UDim2.new(1, 0, 1, -44)
holder.Position = UDim2.new(0, 0, 0, 44)
holder.Parent = frame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = holder

local function makeButton(text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(55, 46, 35)
	b.BackgroundTransparency = 0.05
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(245, 240, 230)
	b.Text = text
	b.Parent = holder

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = b

	return b
end

local btnStink = makeButton("Stink Cloud: OFF")
local btnTrail = makeButton("Poo Trail: OFF")
local btnFart = makeButton("Fart Steps: OFF")
local btnSplat = makeButton("Splat (cooldown)")
local btnAllOff = makeButton("All Off")
local btnStatus = makeButton("Status")
local btnHelp = makeButton("Help")
local btnMenu = makeButton("Hide Menu")

local function setMenuVisible(on)
	state.MenuVisible = on and true or false
	frame.Visible = state.MenuVisible
end

local function refreshButtons()
	btnStink.Text = "Stink Cloud: " .. (state.StinkCloud and "ON" or "OFF")
	btnTrail.Text = "Poo Trail: " .. (state.PooTrail and "ON" or "OFF")
	btnFart.Text = "Fart Steps: " .. (state.FartStep and "ON" or "OFF")
	btnMenu.Text = state.MenuVisible and "Hide Menu" or "Show Menu"
end

refreshButtons()

-- Command handler (used by buttons and slash commands)
local function doHelp()
	sysMsg("Buttons are local. Slash commands: /bp help, /bp stink on|off|toggle, /bp trail on|off|toggle, /bp fart on|off|toggle, /bp splat, /bp alloff, /bp status, /bp menu")
end

local function doStatus()
	sysMsg("Stink=" .. tostring(state.StinkCloud) .. " Trail=" .. tostring(state.PooTrail) .. " FartSteps=" .. tostring(state.FartStep))
end

local function setToggleFromArg(current, arg)
	arg = string.lower(tostring(arg or "toggle"))
	if arg == "on" then
		return true
	end
	if arg == "off" then
		return false
	end
	return not current
end

local function handleCommand(cmd, arg)
	cmd = string.lower(tostring(cmd or "help"))

	if cmd == "help" then
		if not canRunCommand("help") then return warnThrottle("BearPoo: Slow down.") end
		doHelp()
		return
	end

	if cmd == "menu" then
		if not canRunCommand("menu") then return warnThrottle("BearPoo: Slow down.") end
		setMenuVisible(not state.MenuVisible)
		refreshButtons()
		sysMsg("Menu " .. (state.MenuVisible and "shown" or "hidden") .. ".")
		return
	end

	if cmd == "status" then
		if not canRunCommand("status") then return warnThrottle("BearPoo: Slow down.") end
		doStatus()
		return
	end

	if cmd == "stink" then
		if not canRunCommand("stink") then return warnThrottle("BearPoo: Slow down.") end
		state.StinkCloud = setToggleFromArg(state.StinkCloud, arg)
		if currentChar then applyAllForChar(currentChar) end
		refreshButtons()
		sysMsg("Stink Cloud " .. (state.StinkCloud and "ON" or "OFF"))
		return
	end

	if cmd == "trail" then
		if not canRunCommand("trail") then return warnThrottle("BearPoo: Slow down.") end
		state.PooTrail = setToggleFromArg(state.PooTrail, arg)
		if currentChar then applyAllForChar(currentChar) end
		refreshButtons()
		sysMsg("Poo Trail " .. (state.PooTrail and "ON" or "OFF"))
		return
	end

	if cmd == "fart" then
		if not canRunCommand("fart") then return warnThrottle("BearPoo: Slow down.") end
		state.FartStep = setToggleFromArg(state.FartStep, arg)
		if currentChar then applyAllForChar(currentChar) end
		refreshButtons()
		sysMsg("Fart Steps " .. (state.FartStep and "ON" or "OFF"))
		return
	end

	if cmd == "alloff" then
		if not canRunCommand("alloff") then return warnThrottle("BearPoo: Slow down.") end
		state.StinkCloud = false
		state.PooTrail = false
		state.FartStep = false
		if currentChar then applyAllForChar(currentChar) end
		refreshButtons()
		sysMsg("All effects OFF.")
		return
	end

	if cmd == "splat" then
		if not canRunCommand("splat") then return warnThrottle("BearPoo: Splat is on cooldown.") end

		local char = lp.Character
		if not char then return end
		local hrp = getHRP(char)
		if not hrp then return end

		spawnPooPuff(hrp.CFrame * CFrame.new(0, -2.6, 1.6))

		local s = Instance.new("Sound")
		s.Name = "BearPoo_Splat"
		s.SoundId = "rbxassetid://9113420777"
		s.Volume = 0.35
		s.PlaybackSpeed = 0.8 + (math.random() * 0.2)
		s.Parent = hrp
		s:Play()
		Debris:AddItem(s, 2)

		sysMsg("Splat deployed.")
		return
	end

	if not canRunCommand("help") then return end
	sysMsg("Unknown command. Press Help.")
end

-- Button wiring (each one has its own button)
btnStink.MouseButton1Click:Connect(function()
	handleCommand("stink", "toggle")
end)

btnTrail.MouseButton1Click:Connect(function()
	handleCommand("trail", "toggle")
end)

btnFart.MouseButton1Click:Connect(function()
	handleCommand("fart", "toggle")
end)

btnSplat.MouseButton1Click:Connect(function()
	handleCommand("splat", "")
end)

btnAllOff.MouseButton1Click:Connect(function()
	handleCommand("alloff", "")
end)

btnStatus.MouseButton1Click:Connect(function()
	handleCommand("status", "")
end)

btnHelp.MouseButton1Click:Connect(function()
	handleCommand("help", "")
end)

btnMenu.MouseButton1Click:Connect(function()
	handleCommand("menu", "")
end)

-- Hidden slash commands support (optional)
local function splitWords(s)
	local out = {}
	for w in string.gmatch(tostring(s or ""), "%S+") do
		table.insert(out, w)
	end
	return out
end

local function setupTextChatCommand()
	if not TextChatService or TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		sysMsg("New chat not detected. Buttons still work. Slash commands disabled.")
		return false
	end

	local commandsFolder = TextChatService:FindFirstChild("TextChatCommands")
	if not commandsFolder then
		commandsFolder = Instance.new("Folder")
		commandsFolder.Name = "TextChatCommands"
		commandsFolder.Parent = TextChatService
	end

	local existing = commandsFolder:FindFirstChild("BearPooCommand")
	if existing then
		existing:Destroy()
	end

	local cmdObj = Instance.new("TextChatCommand")
	cmdObj.Name = "BearPooCommand"
	cmdObj.PrimaryAlias = "/bp"
	cmdObj.SecondaryAlias = "/bearpoo"
	cmdObj.AutocompleteVisible = false
	cmdObj.Parent = commandsFolder

	cmdObj.Triggered:Connect(function(originTextSource, unfilteredText)
		if not originTextSource or originTextSource.UserId ~= lp.UserId then
			return
		end

		local words = splitWords(string.lower(tostring(unfilteredText or "")))
		local alias = words[1] or ""
		if alias ~= "/bp" and alias ~= "/bearpoo" then
			return
		end

		local subCmd = words[2] or "help"
		local arg = words[3] or "toggle"
		handleCommand(subCmd, arg)
	end)

	return true
end

-- Character handling
local function onChar(char)
	cleanupAll()
	applyAllForChar(char)
	refreshButtons()
end

if lp.Character then
	onChar(lp.Character)
end

lp.CharacterAdded:Connect(onChar)
lp.CharacterRemoving:Connect(function()
	cleanupAll()
	currentChar = nil
end)

setupTextChatCommand()
sysMsg("Loaded. Buttons are ready.")


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

local player = game.Players.LocalPlayer
local TRIGGER = "؍"
local SOUND_ID = "rbxassetid://7147226095"
local PLAY_COUNT = 1

player.Chatted:Connect(function(message)
    if message == TRIGGER then
        local sound = Instance.new("Sound")
        sound.SoundId = SOUND_ID
        sound.Volume = 10 -- max volume
        sound.Looped = false

        -- Parent to Camera so it plays directly in headphones
        sound.Parent = workspace.CurrentCamera

        for i = 1, PLAY_COUNT do
            sound:Play()
            sound.Ended:Wait()
        end

        sound:Destroy()
    end
end)

safeLoad("https://raw.githubusercontent.com/BR05Lua/SOS/refs/heads/main/BR05TagSystem.lua")
