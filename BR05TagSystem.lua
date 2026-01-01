-- SOS TAGS Standalone LocalScript
-- Put in StarterPlayerScripts

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:FindService("TextChatService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local SOS_ACTIVATE_MARKER = "𖺗"
local SOS_REPLY_MARKER = "¬"

local AK_MARKER_1 = "؍؍؍"
local AK_MARKER_2 = "؍"

local INIT_DELAY = 0.9

-- Tag sizing
local TAG_W, TAG_H = 144, 36
local TAG_OFFSET_Y = 3

local ORB_SIZE = 18
local ORB_OFFSET_Y = 6.2

-- Refresh button settings
local REFRESH_EVENT_NAME = "event_modify_refresh"
local REFRESH_HOTKEY = Enum.KeyCode.RightControl

--------------------------------------------------------------------
-- ARRIVAL FX + POPUPS
--------------------------------------------------------------------
local OWNER_ARRIVAL_TEXT = "He has Arrived"
local OWNER_ARRIVAL_SOUND_ID = "rbxassetid://136954512002069"

local COOWNER_ARRIVAL_TEXT = "Hes Behind You"
local COOWNER_ARRIVAL_SOUND_ID = "rbxassetid://119023903778140"

-- Sins intro defaults
local SIN_ARRIVAL_DEFAULT_SOUND_ID = "rbxassetid://87617059556991"

-- Intro sound volume tuning
local INTRO_VOLUME_MULT = 0.30

-- SOS activation join ping
local SOS_JOIN_PING_SOUND_ID = "rbxassetid://5773338685"
local SOS_JOIN_PING_VOLUME = 0.10

-- Optional per user intros (text popup, glitchy)
-- CustomUserIntros[UserId] = { Text = "Hello", SoundId = "rbxassetid://123", TextColor = Color3.fromRGB(255,255,255) }
local CustomUserIntros = {
	[7452991350] = {
		Text = "XTCY Has Been Summoned.",
		SoundId = "rbxassetid://120403072198402",
		TextColor = Color3.fromRGB(200, 0, 0),
	},
}

--------------------------------------------------------------------
-- ROLES DATA
--------------------------------------------------------------------
local ROLE_COLOR = {
	Normal = Color3.fromRGB(120, 190, 235),
	Owner  = Color3.fromRGB(255, 255, 80),
	Tester = Color3.fromRGB(60, 255, 90),
	Sin    = Color3.fromRGB(235, 70, 70),
	OG     = Color3.fromRGB(160, 220, 255),
	Custom = Color3.fromRGB(245, 245, 245),
}

local OwnerNames = {
	["deniskraily"] = true,
}

local OwnerUserIds = {
	[433636433] = true,
	[196988708] = true,
	[4926923208] = true,
}

local CoOwners = {
	[2630250935] = true,
	[9253548067] = true,
	[5348319883] = true,
}

local TesterUserIds = {
	-- leave blank
}

local SinProfiles = {
	[105995794]  = { SinName = "Lettuce" },
	[138975737]  = { SinName = "Music" },
	[9159968275] = { SinName = "Music" },
	[4659279349] = { SinName = "Trial" },
	[4495710706] = { SinName = "Games Design" },
	[1575141882] = { SinName = "Heart" },
	[118170824]  = { SinName = "Security" },
	[7870252435] = { SinName = "Security" },
	[3600244479] = { SinName = "PAWS" },
	[8956134409] = { SinName = "Cars" },

	-- Optional intro overrides per Sin:
	-- [123] = { SinName = "Chaos", ArrivalText = "Chaos Walks In", ArrivalSoundId = "rbxassetid://123" },
}

local OgProfiles = {
	-- keep blank unless you use it
}

-- Current CustomTags userIds you asked to keep
local CustomTags = {
	[8299334811] = { TagText = "OG Fake Cinny" },
	[7452991350] = { TagText = "OG XTCY" },
	[9072904295] = { TagText = "OG XTCY" },
	[7444930172] = { TagText = "OG XTCY" },
	[2630250935] = { TagText = "Co-Owner" },
	[754232813]  = { TagText = "OG Ghoul" },
	[4689208231] = { TagText = "OG Shiroyasha" },
	[4689208231] = { TagText = "OG Audio Sam" },
}

--------------------------------------------------------------------
-- SPECIAL FX (Owner and CoOwner trails/light/glitch aura)
--------------------------------------------------------------------
local FX_FOLDER_NAME = "SOS_SpecialFX"

local CMD_OWNER_ON = "Owner_on"
local CMD_OWNER_OFF = "Owner_off"
local CMD_COOWNER_ON = "CoOwner_on"
local CMD_COOWNER_OFF = "CoOwner_off"

local CMD_OWNER_COLOR_PREFIX = "Owner_color:"
local CMD_COOWNER_COLOR_PREFIX = "CoOwner_color:"

local CMD_OWNER_FX_PREFIX = "Owner_fx:"
local CMD_COOWNER_FX_PREFIX = "CoOwner_fx:"

--------------------------------------------------------------------
-- TAG PRESETS (EASY NAMES)
-- Use: TagEffectProfiles[UserId] = { Preset = "RED_SCROLL" }
--------------------------------------------------------------------
local TagPresets = {}

local function addPreset(name, t)
	TagPresets[name] = t
end

do
	addPreset("BLACK_SOLID", {
		Gradient1 = Color3.fromRGB(0, 0, 0),
		Gradient2 = Color3.fromRGB(0, 0, 0),
		Gradient3 = Color3.fromRGB(0, 0, 0),
		SpinGradient = false,
		ScrollGradient = false,
		TopTextColor = Color3.fromRGB(255, 255, 255),
		BottomTextColor = Color3.fromRGB(200, 200, 200),
		Effects = {},
	})

	addPreset("WHITE_SOLID", {
		Gradient1 = Color3.fromRGB(255, 255, 255),
		Gradient2 = Color3.fromRGB(255, 255, 255),
		Gradient3 = Color3.fromRGB(255, 255, 255),
		SpinGradient = false,
		ScrollGradient = false,
		TopTextColor = Color3.fromRGB(25, 25, 25),
		BottomTextColor = Color3.fromRGB(55, 55, 55),
		Effects = {},
	})

	addPreset("GREY_STEEL", {
		Gradient1 = Color3.fromRGB(55, 55, 65),
		Gradient2 = Color3.fromRGB(10, 10, 12),
		Gradient3 = Color3.fromRGB(90, 90, 105),
		SpinGradient = false,
		ScrollGradient = true,
		TopTextColor = Color3.fromRGB(245, 245, 245),
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Scanline" },
	})

	addPreset("RAINBOW_SPIN", {
		Gradient1 = Color3.fromRGB(255, 0, 0),
		Gradient2 = Color3.fromRGB(0, 255, 0),
		Gradient3 = Color3.fromRGB(0, 140, 255),
		SpinGradient = true,
		ScrollGradient = false,
		TopTextColor = Color3.fromRGB(245, 245, 245),
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Shimmer" },
	})

	addPreset("RAINBOW_SCROLL", {
		Gradient1 = Color3.fromRGB(255, 0, 0),
		Gradient2 = Color3.fromRGB(0, 255, 0),
		Gradient3 = Color3.fromRGB(0, 140, 255),
		SpinGradient = false,
		ScrollGradient = true,
		TopTextColor = Color3.fromRGB(245, 245, 245),
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Scanline" },
	})

	local wheel = {
		{ "RED",    0/12 },
		{ "ORANGE", 1/12 },
		{ "AMBER",  2/12 },
		{ "YELLOW", 3/12 },
		{ "LIME",   4/12 },
		{ "GREEN",  5/12 },
		{ "MINT",   6/12 },
		{ "CYAN",   7/12 },
		{ "SKY",    8/12 },
		{ "BLUE",   9/12 },
		{ "PURPLE", 10/12 },
		{ "PINK",   11/12 },
	}

	for _, item in ipairs(wheel) do
		local baseName = item[1]
		local h = item[2]
		local c1 = Color3.fromHSV(h, 1, 1)
		local c2 = Color3.fromHSV((h + 0.08) % 1, 1, 1)
		local c3 = Color3.fromHSV((h + 0.16) % 1, 1, 1)

		addPreset(baseName .. "_SCROLL", {
			Gradient1 = c1, Gradient2 = c2, Gradient3 = c3,
			SpinGradient = false,
			ScrollGradient = true,
			TopTextColor = Color3.fromRGB(245, 245, 245),
			BottomTextColor = Color3.fromRGB(220, 220, 220),
			Effects = { "Shimmer" },
		})

		addPreset(baseName .. "_SPIN", {
			Gradient1 = c1, Gradient2 = c2, Gradient3 = c3,
			SpinGradient = true,
			ScrollGradient = false,
			TopTextColor = Color3.fromRGB(245, 245, 245),
			BottomTextColor = Color3.fromRGB(220, 220, 220),
			Effects = { "Shimmer" },
		})
	end
end

--------------------------------------------------------------------
-- TAG EFFECT PROFILES
--------------------------------------------------------------------
local YELLOW = Color3.fromRGB(255, 255, 0)
local LIGHT_BLUE = Color3.fromRGB(120, 190, 235)
local RED = Color3.fromRGB(255, 60, 60)
local DARK_RED = Color3.fromRGB(140, 0, 0)

local TagEffectProfiles = {
	-- Ghoul (754232813): purple, white, black
	[754232813] = {
		Gradient1 = Color3.fromRGB(140, 0, 255),
		Gradient2 = Color3.fromRGB(255, 255, 255),
		Gradient3 = Color3.fromRGB(0, 0, 0),
		SpinGradient = false,
		ScrollGradient = false,
		TopTextColor = YELLOW,
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Pulse", "Scanline" },
	},

	-- XTCY (7452991350): red, dark red, red
	[7452991350] = {
		Gradient1 = RED,
		Gradient2 = DARK_RED,
		Gradient3 = RED,
		SpinGradient = false,
		ScrollGradient = true,
		TopTextColor = YELLOW,
		BottomTextColor = Color3.fromRGB(240, 240, 240),
		Effects = { "Scanline", "Shimmer" },
	},
	
	-- Sam (4689208231): whatever style
	[4689208231] = {
		Gradient1 = BLUE,
		Gradient2 = PURPLE,
		Gradient3 = BLACK,
		SpinGradient = false,
		ScrollGradient = true,
		TopTextColor = YELLOW,
		BottomTextColor = Color3.fromRGB(240, 240, 240),
		Effects = { "Scanline", "Shimmer" },
	},


	-- Other current CustomTags IDs: yellow text
	[8299334811] = { Preset = "SKY_SCROLL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Shimmer" } },
	[9072904295] = { Preset = "RED_SCROLL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Shimmer" } },
	[7444930172] = { Preset = "RED_SCROLL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Shimmer" } },

	-- CoOwner (2630250935)
	[2630250935] = { Preset = "GREY_STEEL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Scanline", "Shimmer" } },

	-- Shiroyasha (4689208231)
	[4689208231] = {
		Gradient1 = Color3.fromRGB(255, 255, 255),
		Gradient2 = Color3.fromRGB(255, 255, 255),
		Gradient3 = Color3.fromRGB(0, 0, 0),
		SpinGradient = false,
		ScrollGradient = false,
		TopTextColor = YELLOW,
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Pulse", "Scanline", "BounceText" },
	},

	-- Owners explicit
	[433636433] = { Preset = "BLACK_SOLID", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "OwnerGlitchBackdrop", "OwnerGlitchText", "RgbOutline", "Scanline", "Shimmer" }, ScrollGradient = true },
	[196988708] = { Preset = "BLACK_SOLID", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "OwnerGlitchBackdrop", "OwnerGlitchText", "RgbOutline", "Scanline", "Shimmer" }, ScrollGradient = true },
	[4926923208] = { Preset = "BLACK_SOLID", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "OwnerGlitchBackdrop", "OwnerGlitchText", "RgbOutline", "Scanline", "Shimmer" }, ScrollGradient = true },

	-- Other CoOwners
	[9253548067] = { Preset = "GREY_STEEL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Scanline", "Shimmer" } },
	[5348319883] = { Preset = "GREY_STEEL", TopTextColor = YELLOW, BottomTextColor = Color3.fromRGB(235, 235, 235), Effects = { "Scanline", "Shimmer" } },
}

--------------------------------------------------------------------
-- ROLE DEFAULTS
--------------------------------------------------------------------
local RoleEffectPresets = {
	Owner = {
		Preset = "BLACK_SOLID",
		Effects = { "OwnerGlitchBackdrop", "OwnerGlitchText", "RgbOutline", "Scanline", "Shimmer" },
		TopTextColor = YELLOW,
		BottomTextColor = Color3.fromRGB(235, 235, 235),
		ScrollGradient = true,
	},
	Sin = {
		Gradient1 = RED,
		Gradient2 = Color3.fromRGB(0, 0, 0),
		Gradient3 = RED,
		SpinGradient = false,
		ScrollGradient = true,
		TopTextColor = Color3.fromRGB(235, 70, 70),
		BottomTextColor = Color3.fromRGB(235, 235, 235),
		Effects = { "Scanline", "Shimmer" },
	},
	Tester = {
		Preset = "GREEN_SCROLL",
		Effects = { "Shimmer" },
		TopTextColor = YELLOW,
	},
	OG = {
		Preset = "SKY_SCROLL",
		Effects = { "Shimmer" },
		TopTextColor = YELLOW,
	},
	Custom = {
		Preset = "GREY_STEEL",
		Effects = { "Scanline" },
		TopTextColor = YELLOW,
	},
	Normal = {
		Preset = "GREY_STEEL",
		Effects = {},
		TopTextColor = LIGHT_BLUE,
		BottomTextColor = Color3.fromRGB(230, 230, 230),
	},
}

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local SosUsers = {}
local AkUsers = {}

local SeenFirstActivation = false
local RepliedToActivationUserId = {}

local FxEnabled = {
	Owner = true,
	CoOwner = true,
}

local FxColorMode = {
	Owner = "Rainbow",
	CoOwner = "Rainbow",
}

local FxMode = {
	Owner = "Lines",
	CoOwner = "Glitch",
}

local gui
local statsPopup
local statsPopupLabel

local broadcastPanel
local broadcastSOS
local broadcastAK

local sfxPanel
local sfxOnBtn
local sfxOffBtn

local trailPanel
local trailArrow
local trailOpen = false
local trailTween = nil

local refreshBtn
local refreshTip
local refreshTipConn

local ownerPresenceAnnounced = false
local coOwnerPresenceAnnounced = false

local FxConnByUserId = {}
local TagFxConnByUserId = {}

local SinIntroShown = {}
local CustomIntroShown = {}

local JoinPopupByUserId = {}

--------------------------------------------------------------------
-- UI HELPERS
--------------------------------------------------------------------
local function makeCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end

local function makeStroke(parent, thickness, color, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0.25
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
end

local function ensureGui()
	if gui and gui.Parent then return gui end
	gui = Instance.new("ScreenGui")
	gui.Name = "SOS_Tags_UI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function makeButton(parent, txt)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = txt or "Button"
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
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

local function isOwner(plr)
	return plr and ((OwnerNames[plr.Name] == true) or (OwnerUserIds[plr.UserId] == true))
end

local function isCoOwner(plr)
	return plr and (CoOwners[plr.UserId] == true)
end

local function canSeeBroadcastButtons()
	return isOwner(LocalPlayer) or isCoOwner(LocalPlayer)
end

local function canSeeTrailMenu()
	return isOwner(LocalPlayer) or isCoOwner(LocalPlayer)
end

--------------------------------------------------------------------
-- CHAT SEND
--------------------------------------------------------------------
local function trySendChat(text)
	do
		local ok, sent = pcall(function()
			if TextChatService and TextChatService.TextChannels then
				local general = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
				if general and general.SendAsync then
					general:SendAsync(text)
					return true
				end
			end
			return false
		end)
		if ok and sent == true then
			return true
		end
	end

	do
		local ok, sent = pcall(function()
			local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			if events then
				local say = events:FindFirstChild("SayMessageRequest")
				if say and say.FireServer then
					say:FireServer(text, "All")
					return true
				end
			end
			return false
		end)
		if ok and sent == true then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------
-- REFRESH EVENT + BUTTON (TOP RIGHT ABOVE PLAYERLIST)
--------------------------------------------------------------------
local function findRefreshEvent()
	local inst = ReplicatedStorage:FindFirstChild(REFRESH_EVENT_NAME)
	if inst then return inst end
	-- fallback search
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d.Name == REFRESH_EVENT_NAME then
			return d
		end
	end
	return nil
end

local function refreshAllTags()
	for _, p in ipairs(Players:GetPlayers()) do
		if p and p.Character then
			-- refresh tags after server refresh so they do not vanish
			task.defer(function()
				-- this function exists later, but defer is fine
			end)
		end
	end
end

local function ensureRefreshTooltip()
	ensureGui()
	if refreshTip and refreshTip.Parent then return end

	refreshTip = Instance.new("TextLabel")
	refreshTip.Name = "RefreshTooltip"
	refreshTip.BackgroundTransparency = 0.15
	refreshTip.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	refreshTip.BorderSizePixel = 0
	refreshTip.Visible = false
	refreshTip.ZIndex = 9000
	refreshTip.Font = Enum.Font.Gotham
	refreshTip.TextSize = 12
	refreshTip.TextColor3 = Color3.fromRGB(255, 255, 255)
	refreshTip.TextStrokeTransparency = 0.65
	refreshTip.TextXAlignment = Enum.TextXAlignment.Left
	refreshTip.TextYAlignment = Enum.TextYAlignment.Center
	refreshTip.Text = "Tip: you can also trigger it with ctrl"
	refreshTip.Size = UDim2.new(0, 260, 0, 22)
	refreshTip.Parent = gui

	makeCorner(refreshTip, 10)
	makeStroke(refreshTip, 1, Color3.fromRGB(200, 40, 40), 0.25)
end

local function showRefreshTooltip()
	ensureRefreshTooltip()
	if not refreshTip then return end
	refreshTip.Visible = true

	if refreshTipConn then
		pcall(function() refreshTipConn:Disconnect() end)
		refreshTipConn = nil
	end

	refreshTipConn = RunService.RenderStepped:Connect(function()
		if not refreshTip or not refreshTip.Parent then
			pcall(function() refreshTipConn:Disconnect() end)
			refreshTipConn = nil
			return
		end
		local m = UserInputService:GetMouseLocation()
		refreshTip.Position = UDim2.new(0, m.X + 16, 0, m.Y + 10)
	end)
end

local function hideRefreshTooltip()
	if refreshTipConn then
		pcall(function() refreshTipConn:Disconnect() end)
		refreshTipConn = nil
	end
	if refreshTip then
		refreshTip.Visible = false
	end
end

local refreshDebounce = false

local function doRefresh()
	if refreshDebounce then return end
	refreshDebounce = true

	local ev = findRefreshEvent()
	if ev then
		if ev:IsA("RemoteEvent") then
			pcall(function() ev:FireServer() end)
		elseif ev:IsA("BindableEvent") then
			pcall(function() ev:Fire() end)
		elseif ev:IsA("RemoteFunction") then
			pcall(function() ev:InvokeServer() end)
		end
	end

	-- Rebuild tags shortly after refresh so they do not go invisible.
	task.delay(0.15, function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p and p.Character then
				task.defer(function()
					-- refreshAllTagsForPlayer exists later, this closure will run after it's defined
					if _G.__SOS_REFRESH_TAGS_FOR_PLAYER then
						_G.__SOS_REFRESH_TAGS_FOR_PLAYER(p)
					end
				end)
			end
		end
		refreshDebounce = false
	end)
end

local function ensureRefreshButton()
	ensureGui()
	if refreshBtn and refreshBtn.Parent then return end

	refreshBtn = Instance.new("TextButton")
	refreshBtn.Name = "RefreshButton"
	refreshBtn.AnchorPoint = Vector2.new(1, 0)
	-- This sits top right, above the PlayerList area
	refreshBtn.Position = UDim2.new(1, -18, 0, 20)
	refreshBtn.Size = UDim2.new(0, 140, 0, 36)
	refreshBtn.BorderSizePixel = 0
	refreshBtn.AutoButtonColor = true
	refreshBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	refreshBtn.BackgroundTransparency = 0.18
	refreshBtn.Text = "Refresh"
	refreshBtn.Font = Enum.Font.GothamBold
	refreshBtn.TextSize = 14
	refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	refreshBtn.Parent = gui

	makeCorner(refreshBtn, 12)
	makeStroke(refreshBtn, 2, Color3.fromRGB(200, 40, 40), 0.15)

	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.10),
		NumberSequenceKeypoint.new(1, 0.22),
	})
	g.Parent = refreshBtn

	refreshBtn.MouseButton1Click:Connect(function()
		doRefresh()
	end)

	refreshBtn.MouseEnter:Connect(function()
		showRefreshTooltip()
	end)

	refreshBtn.MouseLeave:Connect(function()
		hideRefreshTooltip()
	end)

	-- RightControl hotkey triggers the same action
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= REFRESH_HOTKEY then return end
		if refreshBtn and refreshBtn.Parent then
			refreshBtn:Activate()
		else
			doRefresh()
		end
	end)
end

--------------------------------------------------------------------
-- BROADCAST UI
--------------------------------------------------------------------
local function ensureBroadcastPanel()
	ensureGui()

	if not canSeeBroadcastButtons() then
		if broadcastPanel and broadcastPanel.Parent then
			broadcastPanel:Destroy()
		end
		broadcastPanel = nil
		broadcastSOS = nil
		broadcastAK = nil
		return
	end

	if broadcastPanel and broadcastPanel.Parent then return end

	broadcastPanel = Instance.new("Frame")
	broadcastPanel.Name = "BroadcastPanel"
	broadcastPanel.AnchorPoint = Vector2.new(0, 1)
	broadcastPanel.Position = UDim2.new(0, 10, 1, -10)
	broadcastPanel.Size = UDim2.new(0, 220, 0, 48)
	broadcastPanel.BorderSizePixel = 0
	broadcastPanel.Parent = gui
	makeCorner(broadcastPanel, 14)
	makeGlass(broadcastPanel)
	makeStroke(broadcastPanel, 2, Color3.fromRGB(200, 40, 40), 0.1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = broadcastPanel

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = broadcastPanel

	broadcastSOS = makeButton(broadcastPanel, "Broadcast SOS")
	broadcastSOS.Size = UDim2.new(0, 100, 0, 32)

	broadcastAK = makeButton(broadcastPanel, "Broadcast AK")
	broadcastAK.Size = UDim2.new(0, 100, 0, 32)
end

--------------------------------------------------------------------
-- SFX PANEL (OWNER OR COOWNER)
--------------------------------------------------------------------
local function ensureSfxPanel()
	ensureGui()

	local show = isOwner(LocalPlayer) or isCoOwner(LocalPlayer)
	if not show then
		if sfxPanel and sfxPanel.Parent then sfxPanel:Destroy() end
		sfxPanel, sfxOnBtn, sfxOffBtn = nil, nil, nil
		return
	end

	if sfxPanel and sfxPanel.Parent then return end

	sfxPanel = Instance.new("Frame")
	sfxPanel.Name = "SfxPanel"
	sfxPanel.AnchorPoint = Vector2.new(0, 1)
	sfxPanel.Position = UDim2.new(0, 10, 1, -64)
	sfxPanel.Size = UDim2.new(0, 220, 0, 44)
	sfxPanel.BorderSizePixel = 0
	sfxPanel.Parent = gui
	makeCorner(sfxPanel, 14)
	makeGlass(sfxPanel)
	makeStroke(sfxPanel, 2, Color3.fromRGB(200, 40, 40), 0.1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = sfxPanel

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = sfxPanel

	sfxOnBtn = makeButton(sfxPanel, "SFX ON")
	sfxOnBtn.Size = UDim2.new(0, 100, 0, 30)

	sfxOffBtn = makeButton(sfxPanel, "SFX OFF")
	sfxOffBtn.Size = UDim2.new(0, 100, 0, 30)

	sfxOnBtn.MouseButton1Click:Connect(function()
		if isOwner(LocalPlayer) then
			FxEnabled.Owner = true
			trySendChat(CMD_OWNER_ON)
		elseif isCoOwner(LocalPlayer) then
			FxEnabled.CoOwner = true
			trySendChat(CMD_COOWNER_ON)
		end
	end)

	sfxOffBtn.MouseButton1Click:Connect(function()
		if isOwner(LocalPlayer) then
			FxEnabled.Owner = false
			trySendChat(CMD_OWNER_OFF)
		elseif isCoOwner(LocalPlayer) then
			FxEnabled.CoOwner = false
			trySendChat(CMD_COOWNER_OFF)
		end
	end)
end

--------------------------------------------------------------------
-- TRAIL MENU (SLIDE OUT) WITH FX MODE BUTTONS
--------------------------------------------------------------------
local function makeColorChip(parent, label, color3, onClick)
	local b = Instance.new("TextButton")
	b.Name = "Chip_" .. label
	b.Size = UDim2.new(0, 34, 0, 24)
	b.BackgroundColor3 = color3
	b.BackgroundTransparency = 0.05
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = parent
	makeCorner(b, 8)
	makeStroke(b, 1, Color3.fromRGB(0, 0, 0), 0.35)

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 1, 0)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 10
	t.TextColor3 = Color3.fromRGB(245, 245, 245)
	t.TextStrokeTransparency = 0.6
	t.Text = label
	t.Parent = b

	b.MouseButton1Click:Connect(onClick)
	return b
end

local function ensureTrailMenu()
	ensureGui()

	if not canSeeTrailMenu() then
		if trailPanel and trailPanel.Parent then trailPanel:Destroy() end
		trailPanel, trailArrow = nil, nil
		trailOpen = false
		trailTween = nil
		return
	end

	if trailPanel and trailPanel.Parent then
		return
	end

	local PANEL_W, PANEL_H = 270, 240
	local ARROW_W = 34

	trailPanel = Instance.new("Frame")
	trailPanel.Name = "SOS_TrailsPanel"
	trailPanel.AnchorPoint = Vector2.new(0, 0.5)
	trailPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	trailPanel.Position = UDim2.new(0, -(PANEL_W - ARROW_W), 0.5, 0)
	trailPanel.BorderSizePixel = 0
	trailPanel.Parent = gui
	makeCorner(trailPanel, 16)
	makeGlass(trailPanel)
	makeStroke(trailPanel, 2, Color3.fromRGB(200, 40, 40), 0.10)

	trailArrow = Instance.new("TextButton")
	trailArrow.Name = "Arrow"
	trailArrow.AnchorPoint = Vector2.new(1, 0.5)
	trailArrow.Size = UDim2.new(0, ARROW_W, 0, 46)
	trailArrow.Position = UDim2.new(1, 0, 0.5, 0)
	trailArrow.BorderSizePixel = 0
	trailArrow.AutoButtonColor = true
	trailArrow.Text = ">"
	trailArrow.Font = Enum.Font.GothamBlack
	trailArrow.TextSize = 18
	trailArrow.TextColor3 = Color3.fromRGB(245, 245, 245)
	trailArrow.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	trailArrow.BackgroundTransparency = 0.18
	trailArrow.Parent = trailPanel
	makeCorner(trailArrow, 14)
	makeStroke(trailArrow, 2, Color3.fromRGB(200, 40, 40), 0.15)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 12, 0, 10)
	title.Size = UDim2.new(1, -(ARROW_W + 18), 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.Text = "Trails"
	title.Parent = trailPanel

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 12, 0, 34)
	sub.Size = UDim2.new(1, -(ARROW_W + 18), 0, 18)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(200, 200, 200)
	sub.Text = isOwner(LocalPlayer) and "Owner controls" or "CoOwner controls"
	sub.Parent = trailPanel

	local btnRow = Instance.new("Frame")
	btnRow.BackgroundTransparency = 1
	btnRow.Position = UDim2.new(0, 10, 0, 62)
	btnRow.Size = UDim2.new(1, -(ARROW_W + 20), 0, 36)
	btnRow.Parent = trailPanel

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.Parent = btnRow

	local onBtn = makeButton(btnRow, "ON")
	onBtn.Size = UDim2.new(0, 90, 0, 32)

	local offBtn = makeButton(btnRow, "OFF")
	offBtn.Size = UDim2.new(0, 90, 0, 32)

	local fxLabel = Instance.new("TextLabel")
	fxLabel.BackgroundTransparency = 1
	fxLabel.Position = UDim2.new(0, 12, 0, 104)
	fxLabel.Size = UDim2.new(1, -(ARROW_W + 18), 0, 16)
	fxLabel.Font = Enum.Font.GothamBold
	fxLabel.TextSize = 12
	fxLabel.TextXAlignment = Enum.TextXAlignment.Left
	fxLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	fxLabel.Text = "Effect"
	fxLabel.Parent = trailPanel

	local fxRow = Instance.new("Frame")
	fxRow.BackgroundTransparency = 1
	fxRow.Position = UDim2.new(0, 10, 0, 124)
	fxRow.Size = UDim2.new(1, -(ARROW_W + 20), 0, 36)
	fxRow.Parent = trailPanel

	local fxLayout = Instance.new("UIListLayout")
	fxLayout.FillDirection = Enum.FillDirection.Horizontal
	fxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fxLayout.Padding = UDim.new(0, 10)
	fxLayout.Parent = fxRow

	local fxLines = makeButton(fxRow, "Lines")
	fxLines.Size = UDim2.new(0, 66, 0, 32)
	local fxLight = makeButton(fxRow, "Light")
	fxLight.Size = UDim2.new(0, 66, 0, 32)
	local fxGlitch = makeButton(fxRow, "Glitch")
	fxGlitch.Size = UDim2.new(0, 66, 0, 32)

	local colorsLabel = Instance.new("TextLabel")
	colorsLabel.BackgroundTransparency = 1
	colorsLabel.Position = UDim2.new(0, 12, 0, 168)
	colorsLabel.Size = UDim2.new(1, -(ARROW_W + 18), 0, 16)
	colorsLabel.Font = Enum.Font.GothamBold
	colorsLabel.TextSize = 12
	colorsLabel.TextXAlignment = Enum.TextXAlignment.Left
	colorsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	colorsLabel.Text = "Colour"
	colorsLabel.Parent = trailPanel

	local colorArea = Instance.new("Frame")
	colorArea.BackgroundTransparency = 1
	colorArea.Position = UDim2.new(0, 10, 0, 188)
	colorArea.Size = UDim2.new(1, -(ARROW_W + 20), 0, 42)
	colorArea.Parent = trailPanel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 34, 0, 24)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = colorArea

	local function sendOn()
		if isOwner(LocalPlayer) then
			FxEnabled.Owner = true
			trySendChat(CMD_OWNER_ON)
		elseif isCoOwner(LocalPlayer) then
			FxEnabled.CoOwner = true
			trySendChat(CMD_COOWNER_ON)
		end
	end

	local function sendOff()
		if isOwner(LocalPlayer) then
			FxEnabled.Owner = false
			trySendChat(CMD_OWNER_OFF)
		elseif isCoOwner(LocalPlayer) then
			FxEnabled.CoOwner = false
			trySendChat(CMD_COOWNER_OFF)
		end
	end

	local function sendColor(mode)
		if isOwner(LocalPlayer) then
			FxColorMode.Owner = mode
			trySendChat(CMD_OWNER_COLOR_PREFIX .. mode)
		elseif isCoOwner(LocalPlayer) then
			FxColorMode.CoOwner = mode
			trySendChat(CMD_COOWNER_COLOR_PREFIX .. mode)
		end
	end

	local function sendFxMode(mode)
		if isOwner(LocalPlayer) then
			FxMode.Owner = mode
			trySendChat(CMD_OWNER_FX_PREFIX .. mode)
		elseif isCoOwner(LocalPlayer) then
			FxMode.CoOwner = mode
			trySendChat(CMD_COOWNER_FX_PREFIX .. mode)
		end
	end

	onBtn.MouseButton1Click:Connect(sendOn)
	offBtn.MouseButton1Click:Connect(sendOff)

	fxLines.MouseButton1Click:Connect(function() sendFxMode("Lines") end)
	fxLight.MouseButton1Click:Connect(function() sendFxMode("Lighting") end)
	fxGlitch.MouseButton1Click:Connect(function() sendFxMode("Glitch") end)

	local palette = {
		{ "RGB", Color3.fromRGB(30, 30, 30), "Rainbow" },
		{ "ICE", Color3.fromRGB(180, 245, 255), "Ice" },
		{ "RED", Color3.fromRGB(255, 60, 60), "Red" },
		{ "GRN", Color3.fromRGB(60, 255, 120), "Neon" },
		{ "YEL", Color3.fromRGB(255, 220, 80), "Sun" },
		{ "PRP", Color3.fromRGB(160, 120, 255), "Violet" },
		{ "WHT", Color3.fromRGB(245, 245, 245), "White" },
		{ "SLV", Color3.fromRGB(170, 170, 170), "Silver" },
	}

	for _, item in ipairs(palette) do
		local label, col, mode = item[1], item[2], item[3]
		makeColorChip(colorArea, label, col, function()
			sendColor(mode)
		end)
	end

	local openPos = UDim2.new(0, 10, 0.5, 0)
	local closedPos = UDim2.new(0, -(PANEL_W - ARROW_W), 0.5, 0)

	local function setTrailMenu(open)
		trailOpen = open
		trailArrow.Text = open and "<" or ">"

		if trailTween then
			pcall(function() trailTween:Cancel() end)
			trailTween = nil
		end

		trailTween = TweenService:Create(
			trailPanel,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = open and openPos or closedPos }
		)
		trailTween:Play()
	end

	trailArrow.MouseButton1Click:Connect(function()
		setTrailMenu(not trailOpen)
	end)

	trailOpen = false
	trailArrow.Text = ">"
end

--------------------------------------------------------------------
-- STATS POPUP
--------------------------------------------------------------------
local function ensureStatsPopup()
	ensureGui()
	if statsPopup and statsPopup.Parent then return end

	statsPopup = Instance.new("Frame")
	statsPopup.Name = "SOS_StatsPopup"
	statsPopup.AnchorPoint = Vector2.new(0.5, 0.5)
	statsPopup.Position = UDim2.new(0.5, 0, 0.5, 0)
	statsPopup.Size = UDim2.new(0, 380, 0, 170)
	statsPopup.BorderSizePixel = 0
	statsPopup.Visible = false
	statsPopup.Parent = gui
	makeCorner(statsPopup, 14)
	makeGlass(statsPopup)
	makeStroke(statsPopup, 2, Color3.fromRGB(200, 40, 40), 0.1)

	statsPopupLabel = Instance.new("TextLabel")
	statsPopupLabel.BackgroundTransparency = 1
	statsPopupLabel.Size = UDim2.new(1, -18, 1, -54)
	statsPopupLabel.Position = UDim2.new(0, 9, 0, 10)
	statsPopupLabel.Font = Enum.Font.Gotham
	statsPopupLabel.TextSize = 14
	statsPopupLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	statsPopupLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsPopupLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsPopupLabel.TextWrapped = true
	statsPopupLabel.Text = ""
	statsPopupLabel.Parent = statsPopup

	local closeBtn = makeButton(statsPopup, "Close")
	closeBtn.AnchorPoint = Vector2.new(0.5, 1)
	closeBtn.Position = UDim2.new(0.5, 0, 1, -10)
	closeBtn.Size = UDim2.new(0, 140, 0, 34)
	closeBtn.MouseButton1Click:Connect(function()
		statsPopup.Visible = false
	end)
end

local function destroyTagGui(char, name)
	if not char then return end
	local old = char:FindFirstChild(name)
	if old then old:Destroy() end
end

--------------------------------------------------------------------
-- ROLE RESOLUTION
--------------------------------------------------------------------
local function getSosRole(plr)
	if not plr then return nil end

	if isOwner(plr) then
		return "Owner"
	end

	if CustomTags[plr.UserId] then
		return "Custom"
	end

	if OgProfiles[plr.UserId] then
		return "OG"
	end

	if not SosUsers[plr.UserId] then
		return nil
	end

	if TesterUserIds[plr.UserId] then
		return "Tester"
	end

	if SinProfiles[plr.UserId] then
		return "Sin"
	end

	return "Normal"
end

local function getRoleColor(plr, role)
	if role == "Sin" then
		local prof = SinProfiles[plr.UserId]
		if prof and prof.Color then return prof.Color end
	end
	if role == "OG" then
		local prof = OgProfiles[plr.UserId]
		if prof and prof.Color then return prof.Color end
	end
	if role == "Custom" then
		local prof = CustomTags[plr.UserId]
		if prof and prof.Color then return prof.Color end
	end
	return ROLE_COLOR[role] or Color3.fromRGB(240, 240, 240)
end

local function getTopLine(plr, role)
	if role == "Owner" then return "Owner" end
	if role == "Tester" then return "SOS Tester" end

	if role == "Sin" then
		local prof = SinProfiles[plr.UserId]
		if prof and prof.SinName and #tostring(prof.SinName) > 0 then
			return "The Sin of " .. tostring(prof.SinName)
		end
		return "The Sin of ???"
	end

	if role == "OG" then
		local prof = OgProfiles[plr.UserId]
		if prof and prof.OgName and #tostring(prof.OgName) > 0 then
			return tostring(prof.OgName)
		end
		return "OG"
	end

	if role == "Custom" then
		local prof = CustomTags[plr.UserId]
		if prof and prof.TagText and #tostring(prof.TagText) > 0 then
			return tostring(prof.TagText)
		end
		return "Custom"
	end

	return "SOS User"
end

--------------------------------------------------------------------
-- CLICK ACTIONS
--------------------------------------------------------------------
local function teleportToPlayer(plr)
	if not plr or plr == LocalPlayer then return end

	local myChar = LocalPlayer.Character
	local theirChar = plr.Character
	if not myChar or not theirChar then return end

	local myHRP = myChar:FindFirstChild("HumanoidRootPart")
	local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
	if not myHRP or not theirHRP then return end

	local targetCf = theirHRP.CFrame * CFrame.new(0, 0, -4)

	pcall(function()
		if myChar.PivotTo then
			myChar:PivotTo(targetCf)
		else
			myHRP.CFrame = targetCf
		end
	end)
end

local function showPlayerStats(plr)
	ensureStatsPopup()
	if not statsPopup then return end

	local ageDays = plr.AccountAge or 0
	local role = getSosRole(plr)
	local roleLine = role and getTopLine(plr, role) or "No SOS tag"
	local akLine = AkUsers[plr.UserId] and "AK: Yes" or "AK: No"

	local txt = ""
	txt = txt .. "User: " .. plr.Name .. "\n"
	txt = txt .. "UserId: " .. tostring(plr.UserId) .. "\n"
	txt = txt .. "AccountAge: " .. tostring(ageDays) .. " days\n\n"
	txt = txt .. "Role: " .. roleLine .. "\n"
	txt = txt .. akLine .. "\n"

	statsPopupLabel.Text = txt
	statsPopup.Visible = true
end

local function makeTagButtonCommon(btn, plr)
	local function act()
		local holdingCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if holdingCtrl then
			showPlayerStats(plr)
		else
			teleportToPlayer(plr)
		end
	end

	btn.MouseButton1Click:Connect(act)
	pcall(function()
		btn.Activated:Connect(act)
	end)
end

--------------------------------------------------------------------
-- TAG VISUAL HELPERS
--------------------------------------------------------------------
local function startRgbOutline(stroke)
	if not stroke then return end
	task.spawn(function()
		local t = 0
		while stroke and stroke.Parent do
			t = t + 0.03
			local r = math.floor((math.sin(t * 2.0) * 0.5 + 0.5) * 255)
			local g = math.floor((math.sin(t * 2.0 + 2.094) * 0.5 + 0.5) * 255)
			local b = math.floor((math.sin(t * 2.0 + 4.188) * 0.5 + 0.5) * 255)
			stroke.Color = Color3.fromRGB(r, g, b)
			task.wait(0.03)
		end
	end)
end

local function addOwnerGlitchBackdrop(parentBtn)
	local img = Instance.new("ImageLabel")
	img.Name = "OwnerGlitchImg"
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Position = UDim2.new(0, 0, 0, 0)
	img.Image = "rbxassetid://5028857084"
	img.ImageTransparency = 0.55
	img.ZIndex = 1
	img.Parent = parentBtn

	local grad = Instance.new("UIGradient")
	grad.Rotation = 0
	grad.Parent = img

	task.spawn(function()
		local rng = Random.new()
		while img and img.Parent do
			grad.Rotation = rng:NextInteger(0, 360)
			img.ImageTransparency = rng:NextNumber(0.30, 0.78)
			img.Position = UDim2.new(0, rng:NextInteger(-3, 3), 0, rng:NextInteger(-3, 3))
			task.wait(rng:NextNumber(0.04, 0.09))
		end
	end)
end

local function createOwnerGlitchText(label)
	if not label then return end
	local base = label.Text
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
	local rng = Random.new()

	task.spawn(function()
		while label and label.Parent do
			task.wait(rng:NextNumber(0.05, 0.10))
			if not label.Parent then break end

			if rng:NextNumber() < 0.70 then
				local outt = {}
				for i = 1, #base do
					if rng:NextNumber() < 0.28 then
						local idx = rng:NextInteger(1, #chars)
						outt[#outt + 1] = chars:sub(idx, idx)
					else
						outt[#outt + 1] = base:sub(i, i)
					end
				end
				label.Text = table.concat(outt)
			else
				label.Text = base
			end

			label.TextTransparency = (rng:NextNumber() < 0.18) and 0.2 or 0
		end
	end)
end

local function addSinWavyLook(parentBtn)
	local waveGrad = Instance.new("UIGradient")
	waveGrad.Rotation = 90
	waveGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
	})
	waveGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	waveGrad.Parent = parentBtn

	task.spawn(function()
		local t = 0
		while parentBtn and parentBtn.Parent do
			t = t + 0.05
			waveGrad.Offset = Vector2.new(math.sin(t) * 0.25, 0)
			parentBtn.Rotation = math.sin(t * 0.9) * 1.2
			task.wait(0.03)
		end
	end)
end

--------------------------------------------------------------------
-- TAG FX SYSTEM
--------------------------------------------------------------------
local function disconnectTagFxConn(userId)
	local c = TagFxConnByUserId[userId]
	if c then
		pcall(function() c:Disconnect() end)
	end
	TagFxConnByUserId[userId] = nil
end

local function hasEffect(effects, name)
	if type(effects) ~= "table" then return false end
	for _, v in ipairs(effects) do
		if v == name then return true end
	end
	return false
end

local function buildGradientSequence(c1, c2, c3)
	local a = c1 or Color3.fromRGB(24, 24, 30)
	local b = c2 or Color3.fromRGB(10, 10, 12)

	if c3 then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, a),
			ColorSequenceKeypoint.new(0.5, b),
			ColorSequenceKeypoint.new(1.0, c3),
		})
	end

	return ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, a),
		ColorSequenceKeypoint.new(1.0, b),
	})
end

local function mergeEffects(a, b)
	if type(b) == "table" then
		return b
	end
	return a or {}
end

local function resolveTagProfile(plr, role, roleColor)
	local out = {}
	local rolePreset = RoleEffectPresets[role] or RoleEffectPresets.Normal or {}

	local base = {}
	if type(rolePreset.Preset) == "string" and TagPresets[rolePreset.Preset] then
		base = TagPresets[rolePreset.Preset]
	end

	out.Gradient1 = base.Gradient1
	out.Gradient2 = base.Gradient2
	out.Gradient3 = base.Gradient3
	out.SpinGradient = base.SpinGradient
	out.ScrollGradient = base.ScrollGradient
	out.TopTextColor = base.TopTextColor
	out.BottomTextColor = base.BottomTextColor
	out.Effects = base.Effects

	if rolePreset.Gradient1 then out.Gradient1 = rolePreset.Gradient1 end
	if rolePreset.Gradient2 then out.Gradient2 = rolePreset.Gradient2 end
	if rolePreset.Gradient3 ~= nil then out.Gradient3 = rolePreset.Gradient3 end
	if rolePreset.SpinGradient ~= nil then out.SpinGradient = rolePreset.SpinGradient end
	if rolePreset.ScrollGradient ~= nil then out.ScrollGradient = rolePreset.ScrollGradient end
	if rolePreset.TopTextColor then out.TopTextColor = rolePreset.TopTextColor end
	if rolePreset.BottomTextColor then out.BottomTextColor = rolePreset.BottomTextColor end
	out.Effects = mergeEffects(out.Effects, rolePreset.Effects)

	local userProf = TagEffectProfiles[plr.UserId]
	if userProf then
		if type(userProf.Preset) == "string" and TagPresets[userProf.Preset] then
			local p = TagPresets[userProf.Preset]
			out.Gradient1 = p.Gradient1
			out.Gradient2 = p.Gradient2
			out.Gradient3 = p.Gradient3
			out.SpinGradient = p.SpinGradient
			out.ScrollGradient = p.ScrollGradient
			out.TopTextColor = p.TopTextColor
			out.BottomTextColor = p.BottomTextColor
			out.Effects = p.Effects
		end

		if userProf.Gradient1 then out.Gradient1 = userProf.Gradient1 end
		if userProf.Gradient2 then out.Gradient2 = userProf.Gradient2 end
		if userProf.Gradient3 ~= nil then out.Gradient3 = userProf.Gradient3 end
		if userProf.SpinGradient ~= nil then out.SpinGradient = userProf.SpinGradient end
		if userProf.ScrollGradient ~= nil then out.ScrollGradient = userProf.ScrollGradient end
		if userProf.TopTextColor then out.TopTextColor = userProf.TopTextColor end
		if userProf.BottomTextColor then out.BottomTextColor = userProf.BottomTextColor end
		out.Effects = mergeEffects(out.Effects, userProf.Effects)
	end

	if not out.Gradient1 then out.Gradient1 = Color3.fromRGB(24, 24, 30) end
	if not out.Gradient2 then out.Gradient2 = Color3.fromRGB(10, 10, 12) end
	if out.SpinGradient == nil then out.SpinGradient = false end
	if out.ScrollGradient == nil then out.ScrollGradient = false end
	if type(out.Effects) ~= "table" then out.Effects = {} end

	if not out.TopTextColor then out.TopTextColor = roleColor end
	if not out.BottomTextColor then out.BottomTextColor = Color3.fromRGB(230, 230, 230) end

	return out
end

local function applyTagEffects(plr, role, btn, baseGrad, stroke, topLabel, bottomLabel, roleColor)
	if not plr or not btn or not baseGrad then return end
	disconnectTagFxConn(plr.UserId)

	local profile = resolveTagProfile(plr, role, roleColor)
	local effects = profile.Effects

	baseGrad.Color = buildGradientSequence(profile.Gradient1, profile.Gradient2, profile.Gradient3)

	local strokeGrad = nil
	if stroke then
		strokeGrad = stroke:FindFirstChild("StrokeGradient")
		if not strokeGrad then
			strokeGrad = Instance.new("UIGradient")
			strokeGrad.Name = "StrokeGradient"
			strokeGrad.Parent = stroke
		end
		strokeGrad.Rotation = baseGrad.Rotation
		strokeGrad.Offset = baseGrad.Offset
		strokeGrad.Color = buildGradientSequence(profile.Gradient1, profile.Gradient2, profile.Gradient3)
	end

	if topLabel then topLabel.TextColor3 = profile.TopTextColor end
	if bottomLabel then bottomLabel.TextColor3 = profile.BottomTextColor end

	if hasEffect(effects, "OwnerGlitchBackdrop") then
		if not btn:FindFirstChild("OwnerGlitchImg") then
			addOwnerGlitchBackdrop(btn)
		end
	end
	if hasEffect(effects, "OwnerGlitchText") and topLabel then
		createOwnerGlitchText(topLabel)
	end

	if hasEffect(effects, "RgbOutline") and stroke then
		local sg = stroke:FindFirstChild("StrokeGradient")
		if sg then sg:Destroy() end
		strokeGrad = nil
		startRgbOutline(stroke)
	end

	local scan = btn:FindFirstChild("Scanlines")
	if hasEffect(effects, "Scanline") then
		if not scan then
			scan = Instance.new("ImageLabel")
			scan.Name = "Scanlines"
			scan.BackgroundTransparency = 1
			scan.Size = UDim2.new(1, 0, 1, 0)
			scan.Position = UDim2.new(0, 0, 0, 0)
			scan.ZIndex = 2
			scan.Image = "rbxassetid://5028857084"
			scan.ImageTransparency = 0.88
			scan.Parent = btn

			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 120))
			g.Parent = scan
		end
	else
		if scan then scan:Destroy() end
	end

	local t = 0
	local baseBtnSize = btn.Size
	local baseBtnRot = btn.Rotation

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not btn or not btn.Parent then
			disconnectTagFxConn(plr.UserId)
			return
		end

		t = t + dt

		if profile.SpinGradient then
			baseGrad.Rotation = (baseGrad.Rotation + dt * 120) % 360
			if strokeGrad then strokeGrad.Rotation = baseGrad.Rotation end
		end

		if profile.ScrollGradient or hasEffect(effects, "Shimmer") then
			local off = math.sin(t * 1.8) * 0.25
			baseGrad.Offset = Vector2.new(off, 0)
			if strokeGrad then strokeGrad.Offset = baseGrad.Offset end
		end

		if hasEffect(effects, "Pulse") then
			local s = 1 + (math.sin(t * 5.0) * 0.02)
			btn.Size = UDim2.new(baseBtnSize.X.Scale, baseBtnSize.X.Offset * s, baseBtnSize.Y.Scale, baseBtnSize.Y.Offset * s)
		else
			btn.Size = baseBtnSize
		end

		if hasEffect(effects, "Shake") then
			btn.Rotation = baseBtnRot + (math.sin(t * 25) * 0.8)
		else
			btn.Rotation = baseBtnRot
		end

		if hasEffect(effects, "BounceText") and topLabel then
			local y = math.sin(t * 6) * 1.2
			topLabel.Position = UDim2.new(0, 5, 0, 3 + y)
		elseif topLabel then
			topLabel.Position = UDim2.new(0, 5, 0, 3)
		end

		if scan then
			local g = scan:FindFirstChildOfClass("UIGradient")
			if g then
				g.Offset = Vector2.new(0, (t * 0.6) % 1)
			end
		end

		if topLabel then topLabel.TextColor3 = profile.TopTextColor end
		if bottomLabel then bottomLabel.TextColor3 = profile.BottomTextColor end
	end)

	TagFxConnByUserId[plr.UserId] = conn
end

--------------------------------------------------------------------
-- SPECIAL FX CORE (Lines / Lighting / Glitch aura)
--------------------------------------------------------------------
local function disconnectFxConn(userId)
	local c = FxConnByUserId[userId]
	if c then
		pcall(function() c:Disconnect() end)
	end
	FxConnByUserId[userId] = nil
end

local function clearSpecialFx(plr)
	if not plr or not plr.Character then return end
	disconnectFxConn(plr.UserId)
	local folder = plr.Character:FindFirstChild(FX_FOLDER_NAME)
	if folder then folder:Destroy() end
end

local function makeTrailOnPart(part, parentFolder)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0, -math.max(part.Size.Z * 0.5, 0.2))
	a0.Parent = part

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, 0, math.max(part.Size.Z * 0.5, 0.2))
	a1.Parent = part

	local tr = Instance.new("Trail")
	tr.Name = "RunTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.FaceCamera = true
	tr.LightEmission = 1
	tr.Brightness = 2
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.45, 0.22),
		NumberSequenceKeypoint.new(1, 1.00),
	})
	tr.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.6, 0.25),
		NumberSequenceKeypoint.new(1, 0.00),
	})
	tr.Lifetime = 0.12
	tr.Enabled = false
	tr.Parent = parentFolder

	return tr
end

local function resolveFxMode(isOwnerRole)
	return isOwnerRole and (FxMode.Owner or "Lines") or (FxMode.CoOwner or "Lines")
end

local function ensureSpecialFx(plr, role)
	if not plr or not plr.Character then return end

	local isOwnerRole = (role == "Owner")
	local isCoOwnerRole = isCoOwner(plr)
	local isSpecial = isOwnerRole or isCoOwnerRole

	if not isSpecial then
		clearSpecialFx(plr)
		return
	end

	local enabled = isOwnerRole and (FxEnabled.Owner ~= false) or (FxEnabled.CoOwner ~= false)
	if not enabled then
		clearSpecialFx(plr)
		return
	end

	local char = plr.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	clearSpecialFx(plr)

	local folder = Instance.new("Folder")
	folder.Name = FX_FOLDER_NAME
	folder.Parent = char

	local mode = resolveFxMode(isOwnerRole)
	local trails = nil
	local light = nil
	local hl = nil

	if mode == "Lines" then
		trails = {}
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" then
				trails[#trails + 1] = makeTrailOnPart(inst, folder)
			end
		end
	elseif mode == "Lighting" then
		light = Instance.new("PointLight")
		light.Name = "SOS_FxLight"
		light.Range = 16
		light.Brightness = 0
		light.Enabled = true
		light.Parent = hrp
	elseif mode == "Glitch" then
		hl = Instance.new("Highlight")
		hl.Name = "SOS_FxHighlight"
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0.1
		hl.Parent = folder
		hl.Adornee = char
	end

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not folder or not folder.Parent then
			disconnectFxConn(plr.UserId)
			return
		end

		local speed = hrp.Velocity.Magnitude
		local moving = speed > 1.5

		if trails then
			for _, tr in ipairs(trails) do
				tr.Enabled = moving
			end
		end

		if light then
			light.Brightness = moving and 2.6 or 0
			light.Color = Color3.fromRGB(200, 235, 255)
		end

		if hl then
			local pulse = (math.sin(os.clock() * 10) * 0.5 + 0.5)
			hl.FillTransparency = 0.25 + (pulse * 0.35)
			hl.OutlineTransparency = 0.05 + (pulse * 0.25)
			hl.FillColor = Color3.fromRGB(255, 255, 255)
			hl.OutlineColor = Color3.fromRGB(255, 60, 60)
		end
	end)

	FxConnByUserId[plr.UserId] = conn
end

--------------------------------------------------------------------
-- ARRIVAL INTROS AND JOIN POPUP
--------------------------------------------------------------------
local function playArrivalSound(parentGui, soundId, volume)
	if not soundId or soundId == "" then return end
	local s = Instance.new("Sound")
	s.Name = "ArrivalSfx"
	s.SoundId = soundId
	s.Volume = volume or 0.9
	s.Looped = false
	s.Parent = parentGui
	pcall(function() s:Play() end)
	task.delay(6, function()
		if s and s.Parent then s:Destroy() end
	end)
end

local function showJoinTpPopup(plr)
	if not plr then return end
	if plr.UserId == LocalPlayer.UserId then return end

	ensureGui()

	local old = JoinPopupByUserId[plr.UserId]
	if old and old.Parent then old:Destroy() end
	JoinPopupByUserId[plr.UserId] = nil

	local frame = Instance.new("Frame")
	frame.Name = "SOS_JoinPopup"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.08, 0)
	frame.Size = UDim2.new(0, 520, 0, 70)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 7000
	frame.Parent = gui
	makeCorner(frame, 14)
	makeStroke(frame, 2, Color3.fromRGB(200, 40, 40), 0.55)

	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
	})
	grad.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 16, 0, 10)
	title.Size = UDim2.new(1, -160, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.TextTransparency = 1
	title.ZIndex = 7001
	title.Text = plr.Name .. " Has Joined"
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 16, 0, 34)
	hint.Size = UDim2.new(1, -160, 0, 18)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(200, 200, 200)
	hint.TextTransparency = 1
	hint.ZIndex = 7001
	hint.Text = "Press to tp to them"
	hint.Parent = frame

	local tpBtn = Instance.new("TextButton")
	tpBtn.Name = "TP"
	tpBtn.AnchorPoint = Vector2.new(1, 0.5)
	tpBtn.Position = UDim2.new(1, -14, 0.5, 0)
	tpBtn.Size = UDim2.new(0, 120, 0, 42)
	tpBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	tpBtn.BackgroundTransparency = 1
	tpBtn.BorderSizePixel = 0
	tpBtn.AutoButtonColor = true
	tpBtn.Text = "TP"
	tpBtn.Font = Enum.Font.GothamBlack
	tpBtn.TextSize = 16
	tpBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
	tpBtn.TextTransparency = 1
	tpBtn.ZIndex = 7002
	tpBtn.Parent = frame
	makeCorner(tpBtn, 12)
	makeStroke(tpBtn, 2, Color3.fromRGB(200, 40, 40), 0.35)

	tpBtn.MouseButton1Click:Connect(function()
		teleportToPlayer(plr)
	end)

	JoinPopupByUserId[plr.UserId] = frame

	local tinf = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tout = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local t1 = TweenService:Create(frame, tinf, { BackgroundTransparency = 0.15 })
	local t2 = TweenService:Create(title, tinf, { TextTransparency = 0 })
	local t3 = TweenService:Create(hint, tinf, { TextTransparency = 0 })
	local t4 = TweenService:Create(tpBtn, tinf, { BackgroundTransparency = 0.18, TextTransparency = 0 })

	t1:Play()
	t2:Play()
	t3:Play()
	t4:Play()

	task.delay(1.65, function()
		if not frame or not frame.Parent then return end
		local o1 = TweenService:Create(frame, tout, { BackgroundTransparency = 1 })
		local o2 = TweenService:Create(title, tout, { TextTransparency = 1 })
		local o3 = TweenService:Create(hint, tout, { TextTransparency = 1 })
		local o4 = TweenService:Create(tpBtn, tout, { BackgroundTransparency = 1, TextTransparency = 1 })

		o1:Play()
		o2:Play()
		o3:Play()
		o4:Play()

		task.delay(0.25, function()
			if frame and frame.Parent then frame:Destroy() end
		end)
	end)
end

local function showGlitchTextPopup(text, soundId, textColor)
	ensureGui()
	if type(text) ~= "string" or text == "" then return end

	local frame = Instance.new("Frame")
	frame.Name = "SOS_GlitchTextIntro"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0, 720, 0, 120)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.ZIndex = 6000
	frame.Parent = gui
	makeCorner(frame, 16)
	makeStroke(frame, 2, Color3.fromRGB(200, 40, 40), 0.35)

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 1, -20)
	label.Position = UDim2.new(0, 10, 0, 10)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 42
	label.TextWrapped = true
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(245, 245, 245)
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.ZIndex = 6001
	label.Parent = frame

	if soundId and soundId ~= "" then
		playArrivalSound(gui, soundId, 0.9 * INTRO_VOLUME_MULT)
	end

	local base = text
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
	local rng = Random.new()
	local t0 = os.clock()

	task.spawn(function()
		while frame and frame.Parent do
			if (os.clock() - t0) > 1.15 then break end

			frame.Position = UDim2.new(0.5, rng:NextInteger(-10, 10), 0.5, rng:NextInteger(-8, 8))

			if rng:NextNumber() < 0.75 then
				local outt = {}
				for i = 1, #base do
					if rng:NextNumber() < 0.22 then
						local idx = rng:NextInteger(1, #chars)
						outt[#outt + 1] = chars:sub(idx, idx)
					else
						outt[#outt + 1] = base:sub(i, i)
					end
				end
				label.Text = table.concat(outt)
			else
				label.Text = base
			end

			label.TextTransparency = (rng:NextNumber() < 0.18) and 0.2 or 0
			frame.BackgroundTransparency = rng:NextNumber(0.28, 0.50)

			task.wait(rng:NextNumber(0.03, 0.06))
		end

		if frame and frame.Parent then frame:Destroy() end
	end)
end

local function showOwnerArrivalGlitch()
	ensureGui()
	if isOwner(LocalPlayer) or isCoOwner(LocalPlayer) then return end
	showGlitchTextPopup(OWNER_ARRIVAL_TEXT, OWNER_ARRIVAL_SOUND_ID, Color3.fromRGB(255, 255, 80))
end

local function showCoOwnerArrivalGlitch()
	ensureGui()
	if isCoOwner(LocalPlayer) or isOwner(LocalPlayer) then return end
	showGlitchTextPopup(COOWNER_ARRIVAL_TEXT, COOWNER_ARRIVAL_SOUND_ID, Color3.fromRGB(0, 0, 0))
end

local function tryShowSinIntro(userId)
	local plr = Players:GetPlayerByUserId(userId)
	if not plr then return end
	if plr.UserId == LocalPlayer.UserId then return end
	if SinIntroShown[userId] then return end
	SinIntroShown[userId] = true

	local prof = SinProfiles[userId]
	local sinName = (prof and prof.SinName) and tostring(prof.SinName) or "Unknown"
	local introText = (prof and prof.ArrivalText) or ("The Sin of " .. sinName .. " Has Arrived")
	local introSound = (prof and prof.ArrivalSoundId) or SIN_ARRIVAL_DEFAULT_SOUND_ID

	showGlitchTextPopup(introText, introSound, Color3.fromRGB(235, 70, 70))
end

local function tryShowCustomUserIntro(userId)
	local plr = Players:GetPlayerByUserId(userId)
	if not plr then return end
	if CustomIntroShown[userId] then return end

	local intro = CustomUserIntros[userId]
	if not intro then return end

	CustomIntroShown[userId] = true

	local introText = intro.Text or (plr.Name .. " Has Joined")
	local introSound = intro.SoundId
	local introColor = intro.TextColor or Color3.fromRGB(245, 245, 245)

	showGlitchTextPopup(introText, introSound, introColor)
end

local function anyOwnerPresent()
	for _, p in ipairs(Players:GetPlayers()) do
		if isOwner(p) then return true end
	end
	return false
end

local function anyCoOwnerPresent()
	for _, p in ipairs(Players:GetPlayers()) do
		if isCoOwner(p) then return true end
	end
	return false
end

local function reconcilePresence()
	local ownerPresent = anyOwnerPresent()
	if ownerPresent and not ownerPresenceAnnounced then
		ownerPresenceAnnounced = true
		showOwnerArrivalGlitch()
	elseif not ownerPresent then
		ownerPresenceAnnounced = false
	end

	local coPresent = anyCoOwnerPresent()
	if coPresent and not coOwnerPresenceAnnounced then
		coOwnerPresenceAnnounced = true
		showCoOwnerArrivalGlitch()
	elseif not coPresent then
		coOwnerPresenceAnnounced = false
	end
end

--------------------------------------------------------------------
-- TAGS
--------------------------------------------------------------------
local function createSosRoleTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	local role = getSosRole(plr)
	ensureSpecialFx(plr, role)

	if not role then
		disconnectTagFxConn(plr.UserId)
		destroyTagGui(char, "SOS_RoleTag")
		return
	end

	local head = char:FindFirstChild("Head")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local adornee = (head and head:IsA("BasePart")) and head or ((hrp and hrp:IsA("BasePart")) and hrp or nil)
	if not adornee then return end

	disconnectTagFxConn(plr.UserId)
	destroyTagGui(char, "SOS_RoleTag")

	local roleColor = getRoleColor(plr, role)

	local bb = Instance.new("BillboardGui")
	bb.Name = "SOS_RoleTag"
	bb.Adornee = adornee
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, TAG_W, 0, TAG_H)
	bb.StudsOffset = Vector3.new(0, TAG_OFFSET_Y, 0)
	bb.Parent = char

	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = bb
	makeCorner(btn, 10)

	btn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	btn.BackgroundTransparency = 0.22

	local grad = Instance.new("UIGradient")
	grad.Name = "BaseGradient"
	grad.Rotation = 90
	grad.Parent = btn

	local stroke = makeStroke(btn, 2, roleColor, 0.05)

	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, -10, 0, 18)
	top.Position = UDim2.new(0, 5, 0, 3)
	top.Font = Enum.Font.GothamBold
	top.TextSize = 13
	top.TextXAlignment = Enum.TextXAlignment.Center
	top.TextYAlignment = Enum.TextYAlignment.Center
	top.Text = getTopLine(plr, role)
	top.ZIndex = 3
	top.Parent = btn

	local bottom = Instance.new("TextLabel")
	bottom.BackgroundTransparency = 1
	bottom.Size = UDim2.new(1, -10, 0, 16)
	bottom.Position = UDim2.new(0, 5, 0, 19)
	bottom.Font = Enum.Font.Gotham
	bottom.TextSize = 12
	bottom.TextXAlignment = Enum.TextXAlignment.Center
	bottom.TextYAlignment = Enum.TextYAlignment.Center
	bottom.Text = plr.Name
	bottom.ZIndex = 4
	bottom.Parent = btn

	if role == "Sin" then
		addSinWavyLook(btn)
	end

	applyTagEffects(plr, role, btn, grad, stroke, top, bottom, roleColor)

	makeTagButtonCommon(btn, plr)
end

local function createAkOrbTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	if not AkUsers[plr.UserId] then
		destroyTagGui(char, "SOS_AKTag")
		return
	end

	local head = char:FindFirstChild("Head")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local adornee = (head and head:IsA("BasePart")) and head or ((hrp and hrp:IsA("BasePart")) and hrp or nil)
	if not adornee then return end

	destroyTagGui(char, "SOS_AKTag")

	local bb = Instance.new("BillboardGui")
	bb.Name = "SOS_AKTag"
	bb.Adornee = adornee
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, ORB_SIZE, 0, ORB_SIZE)
	bb.StudsOffset = Vector3.new(0, ORB_OFFSET_Y, 0)
	bb.Parent = char

	local btn = Instance.new("TextButton")
	btn.Name = "ClickArea"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BorderSizePixel = 0
	btn.Text = "AK"
	btn.AutoButtonColor = true
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 10
	btn.TextXAlignment = Enum.TextXAlignment.Center
	btn.TextYAlignment = Enum.TextYAlignment.Center
	btn.TextColor3 = Color3.fromRGB(255, 60, 60)
	btn.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	btn.BackgroundTransparency = 0.12
	btn.Parent = bb
	makeCorner(btn, 999)
	makeStroke(btn, 1, Color3.fromRGB(0, 0, 0), 0.25)

	makeTagButtonCommon(btn, plr)
end

local function refreshAllTagsForPlayer(plr)
	if not plr or not plr.Character then return end
	createSosRoleTag(plr)
	createAkOrbTag(plr)
end

-- Expose for the refresh button debounce rebuild (keeps tags from vanishing after refresh event)
_G.__SOS_REFRESH_TAGS_FOR_PLAYER = refreshAllTagsForPlayer

local function hookPlayer(plr)
	if not plr then return end
	plr.CharacterAdded:Connect(function()
		task.wait(0.12)
		refreshAllTagsForPlayer(plr)
	end)
	if plr.Character then
		task.defer(function()
			refreshAllTagsForPlayer(plr)
		end)
	end
end

--------------------------------------------------------------------
-- SOS AND AK UPDATES
--------------------------------------------------------------------
local function textHasAk(text)
	if type(text) ~= "string" then return false end
	if text == AK_MARKER_1 or text == AK_MARKER_2 then return true end
	if text:find(AK_MARKER_1, 1, true) then return true end
	if text:find(AK_MARKER_2, 1, true) then return true end
	return false
end

local function onSosActivated(userId)
	if typeof(userId) ~= "number" then return end
	SosUsers[userId] = true

	if SinProfiles[userId] then
		tryShowSinIntro(userId)
	end

	tryShowCustomUserIntro(userId)

	local plr = Players:GetPlayerByUserId(userId)
	if plr then refreshAllTagsForPlayer(plr) end
end

local function onAkSeen(userId)
	if typeof(userId) ~= "number" then return end
	AkUsers[userId] = true
	local plr = Players:GetPlayerByUserId(userId)
	if plr then refreshAllTagsForPlayer(plr) end
end

--------------------------------------------------------------------
-- COMMANDS (OWNER COOWNER ONLY)
--------------------------------------------------------------------
local function applyCommandFrom(uid, text)
	local plr = Players:GetPlayerByUserId(uid)

	if text == CMD_OWNER_ON and plr and isOwner(plr) then
		FxEnabled.Owner = true
		if plr.Character then refreshAllTagsForPlayer(plr) end
		return true
	end
	if text == CMD_OWNER_OFF and plr and isOwner(plr) then
		FxEnabled.Owner = false
		for _, p in ipairs(Players:GetPlayers()) do
			if isOwner(p) then clearSpecialFx(p) end
		end
		return true
	end

	if text == CMD_COOWNER_ON and plr and isCoOwner(plr) then
		FxEnabled.CoOwner = true
		if plr.Character then refreshAllTagsForPlayer(plr) end
		return true
	end
	if text == CMD_COOWNER_OFF and plr and isCoOwner(plr) then
		FxEnabled.CoOwner = false
		if plr then clearSpecialFx(plr) end
		return true
	end

	if text:sub(1, #CMD_OWNER_COLOR_PREFIX) == CMD_OWNER_COLOR_PREFIX and plr and isOwner(plr) then
		local mode = text:sub(#CMD_OWNER_COLOR_PREFIX + 1)
		if mode ~= "" then FxColorMode.Owner = mode end
		return true
	end

	if text:sub(1, #CMD_COOWNER_COLOR_PREFIX) == CMD_COOWNER_COLOR_PREFIX and plr and isCoOwner(plr) then
		local mode = text:sub(#CMD_COOWNER_COLOR_PREFIX + 1)
		if mode ~= "" then FxColorMode.CoOwner = mode end
		return true
	end

	if text:sub(1, #CMD_OWNER_FX_PREFIX) == CMD_OWNER_FX_PREFIX and plr and isOwner(plr) then
		local mode = text:sub(#CMD_OWNER_FX_PREFIX + 1)
		if mode ~= "" then FxMode.Owner = mode end
		return true
	end

	if text:sub(1, #CMD_COOWNER_FX_PREFIX) == CMD_COOWNER_FX_PREFIX and plr and isCoOwner(plr) then
		local mode = text:sub(#CMD_COOWNER_FX_PREFIX + 1)
		if mode ~= "" then FxMode.CoOwner = mode end
		return true
	end

	return false
end

--------------------------------------------------------------------
-- CHAT HANDLING
--------------------------------------------------------------------
local function maybeReplyToActivation(uid)
	if typeof(uid) ~= "number" then return end
	if uid == LocalPlayer.UserId then return end

	if not SeenFirstActivation then
		SeenFirstActivation = true
		return
	end

	if RepliedToActivationUserId[uid] then return end

	RepliedToActivationUserId[uid] = true
	trySendChat(SOS_REPLY_MARKER)
end

local function handleIncoming(uid, text)
	if typeof(uid) ~= "number" then return end
	if type(text) ~= "string" then return end

	if applyCommandFrom(uid, text) then return end

	if text == SOS_ACTIVATE_MARKER then
		local plr = Players:GetPlayerByUserId(uid)
		if plr and uid ~= LocalPlayer.UserId then
			playArrivalSound(gui or ensureGui(), SOS_JOIN_PING_SOUND_ID, SOS_JOIN_PING_VOLUME)
			showJoinTpPopup(plr)
		end

		onSosActivated(uid)
		maybeReplyToActivation(uid)
		return
	end

	if text == SOS_REPLY_MARKER then
		onSosActivated(uid)
		return
	end

	if textHasAk(text) then
		onAkSeen(uid)
		return
	end
end

local function hookChatListeners()
	if TextChatService and TextChatService.MessageReceived then
		TextChatService.MessageReceived:Connect(function(msg)
			if not msg then return end
			local text = msg.Text or ""
			local src = msg.TextSource
			if not src or not src.UserId then return end
			handleIncoming(src.UserId, text)
		end)
	end

	local function hookChatted(plr)
		pcall(function()
			plr.Chatted:Connect(function(message)
				handleIncoming(plr.UserId, message)
			end)
		end)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookChatted(plr)
	end
	Players.PlayerAdded:Connect(hookChatted)
end

--------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------
local function init()
	print("SOS init ran")

	ensureGui()
	ensureStatsPopup()
	ensureBroadcastPanel()
	ensureSfxPanel()
	ensureTrailMenu()
	ensureRefreshButton()

	if broadcastSOS then
		broadcastSOS.MouseButton1Click:Connect(function()
			onSosActivated(LocalPlayer.UserId)
			trySendChat(SOS_ACTIVATE_MARKER)
		end)
	end

	if broadcastAK then
		broadcastAK.MouseButton1Click:Connect(function()
			onAkSeen(LocalPlayer.UserId)
			trySendChat(AK_MARKER_1)
		end)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayer(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		hookPlayer(plr)
		RepliedToActivationUserId[plr.UserId] = nil
		task.defer(reconcilePresence)

		task.delay(0.2, function()
			tryShowCustomUserIntro(plr.UserId)
		end)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		if plr then
			clearSpecialFx(plr)
			disconnectTagFxConn(plr.UserId)
			RepliedToActivationUserId[plr.UserId] = nil
			SinIntroShown[plr.UserId] = nil
			CustomIntroShown[plr.UserId] = nil

			local p = JoinPopupByUserId[plr.UserId]
			if p and p.Parent then p:Destroy() end
			JoinPopupByUserId[plr.UserId] = nil
		end
		task.defer(reconcilePresence)
	end)

	hookChatListeners()
	reconcilePresence()

	onSosActivated(LocalPlayer.UserId)
	trySendChat(SOS_ACTIVATE_MARKER)

	-- If the refresh event is missing, still keep the button, it just won't fire anything.
	local ev = findRefreshEvent()
	if not ev then
		warn("Refresh event not found: " .. REFRESH_EVENT_NAME)
	end

	-- British humour safety check: if this breaks, it's not my fault, it's Roblox.
	print("SOS Tags loaded. Refresh button ready. RightControl hotkey enabled.")
end

task.delay(INIT_DELAY, init)
