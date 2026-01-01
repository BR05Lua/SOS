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

--------------------------------------------------------------------
-- ARRIVAL FX
--------------------------------------------------------------------
local OWNER_ARRIVAL_TEXT = "He has Arrived"
local OWNER_ARRIVAL_SOUND_ID = "rbxassetid://136954512002069"

local COOWNER_ARRIVAL_TEXT = "Hes Behind You"
local COOWNER_ARRIVAL_SOUND_ID = "rbxassetid://119023903778140"

-- Sins intro defaults
local SIN_ARRIVAL_DEFAULT_SOUND_ID = "rbxassetid://9118823105"

-- Optional per user intros (text popup, glitchy, no full overlay)
-- CustomUserIntros[UserId] = { Text = "Hello", SoundId = "rbxassetid://123", TextColor = Color3.fromRGB(255,255,255) }
local CustomUserIntros = {

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

}

local SinProfiles = {
	[105995794]  = { SinName = "Lettuce" },
	[138975737]  = { SinName = "Music" },
	[9159968275] = { SinName = "Music" },
	[4659279349] = { SinName = "Trial" },
	[4495710706] = { SinName = "Games Design" },
	[1575141882] = { SinName = "Heart", Color = Color3.fromRGB(255, 120, 210) },
	[118170824]  = { SinName = "Security" },
	[7870252435] = { SinName = "Security" },
	[3600244479] = { SinName = "PAWS", Color = Color3.fromRGB(180, 1, 64) },
	[8956134409] = { SinName = "Cars", Color = Color3.fromRGB(0, 255, 0) },

	-- Optional intro overrides per Sin
	-- [123] = { SinName = "Chaos", ArrivalText = "Chaos Walks In", ArrivalSoundId = "rbxassetid://123" },
}

local OgProfiles = {

}

local CustomTags = {
	[8299334811] = { TagText = "OG Fake Cinny", Color = Color3.fromRGB(6, 255, 169) },
	[7452991350] = { TagText = "OG XTCY", Color = Color3.fromRGB(200, 0, 0) },
	[9072904295] = { TagText = "OG XTCY", Color = Color3.fromRGB(200, 0, 0) },
	[7444930172] = { TagText = "OG XTCY", Color = Color3.fromRGB(200, 0, 0) },
	[2630250935] = { TagText = "Co-Owner", Color = Color3.fromRGB(172, 233, 255) },
	[754232813]  = { TagText = "OG Ghoul" },
	[4689208231] = { TagText = "OG Shiroyasha", Color = Color3.fromRGB(255, 255, 255) },
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
-- Also works: "BLUE_SPIN", "PURPLE_SCROLL", "BLACK_SOLID", "WHITE_SOLID", "RAINBOW_SPIN", "RAINBOW_SCROLL"
--------------------------------------------------------------------
local TagPresets = {}

local function addPreset(name, t)
	TagPresets[name] = t
end

do
	-- Simple monos
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

	-- Rainbow modes
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

	-- Full rainbow colour wheel presets
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
-- TAG EFFECT PROFILES (FAST ASSIGN)
-- Quick usage examples:
-- TagEffectProfiles[UserId] = { Preset = "BLUE_SCROLL" }
-- TagEffectProfiles[UserId] = { Preset = "BLACK_SOLID", TopTextColor = Color3.fromRGB(255,0,0) }
-- TagEffectProfiles[UserId] = { Preset = "PURPLE_SCROLL", Effects = { "Pulse", "Scanline" } }
--------------------------------------------------------------------
local TagEffectProfiles = {
	-- Your requested one:
	-- Purple to Black to White
	-- Yellow top text
	-- Pulse and Scanline
	-- Gradient affects outline too
	[754232813] = {
		Gradient1 = Color3.fromRGB(140, 0, 255),
		Gradient2 = Color3.fromRGB(0, 0, 0),
		Gradient3 = Color3.fromRGB(255, 255, 255),
		SpinGradient = false,
		ScrollGradient = false,
		TopTextColor = Color3.fromRGB(255, 255, 0),
		BottomTextColor = Color3.fromRGB(220, 220, 220),
		Effects = { "Pulse", "Scanline" },
	},
}

--------------------------------------------------------------------
-- ROLE DEFAULTS (used when user has no TagEffectProfiles entry)
--------------------------------------------------------------------
local RoleEffectPresets = {
	Owner = {
		Preset = "BLACK_SOLID",
		Effects = { "OwnerGlitchBackdrop", "OwnerGlitchText", "RgbOutline", "Scanline", "Shimmer" },
		TopTextColor = Color3.fromRGB(255, 255, 80),
		BottomTextColor = Color3.fromRGB(235, 235, 235),
		ScrollGradient = true,
	},
	Sin = {
		Preset = "RED_SCROLL",
		Effects = { "Shimmer", "BounceText" },
	},
	Tester = {
		Preset = "GREEN_SCROLL",
		Effects = { "Shimmer" },
	},
	OG = {
		Preset = "SKY_SCROLL",
		Effects = { "Shimmer" },
	},
	Custom = {
		Preset = "GREY_STEEL",
		Effects = { "Scanline" },
	},
	Normal = {
		Preset = "GREY_STEEL",
		Effects = {},
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

local ownerPresenceAnnounced = false
local coOwnerPresenceAnnounced = false

local FxConnByUserId = {}
local TagFxConnByUserId = {}

local SinIntroShown = {}
local CustomIntroShown = {}

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
	return plr and CoOwners[plr.UserId] == true
end

local function canSeeBroadcastButtons()
	if isOwner(LocalPlayer) then
		return true
	end
	return isCoOwner(LocalPlayer)
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
-- BROADCAST UI (simple)
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
		if prof and prof.SinName and #prof.SinName > 0 then
			return "The Sin of " .. prof.SinName
		end
		return "The Sin of ???"
	end

	if role == "OG" then
		local prof = OgProfiles[plr.UserId]
		if prof and prof.OgName and #prof.OgName > 0 then
			return prof.OgName
		end
		return "OG"
	end

	if role == "Custom" then
		local prof = CustomTags[plr.UserId]
		if prof and prof.TagText and #prof.TagText > 0 then
			return prof.TagText
		end
		return "Custom"
	end

	return "SOS User"
end

--------------------------------------------------------------------
-- CLICK ACTIONS
--------------------------------------------------------------------
local function teleportBehind(plr, studsBack)
	if not plr or plr == LocalPlayer then return end

	local myChar = LocalPlayer.Character
	local theirChar = plr.Character
	if not myChar or not theirChar then return end

	local myHRP = myChar:FindFirstChild("HumanoidRootPart")
	local theirHRP = theirChar:FindFirstChild("HumanoidRootPart")
	if not myHRP or not theirHRP then return end

	local back = studsBack or 5
	local targetCf = theirHRP.CFrame * CFrame.new(0, 0, back)

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
			teleportBehind(plr, 5)
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
-- TAG FX SYSTEM (gradient background + gradient outline + easy presets)
-- Effects supported:
-- "Pulse"
-- "Scanline"
-- "Sparkles"
-- "Shimmer"
-- "Shake"
-- "Flicker"
-- "RainbowText"
-- "BounceText"
-- "RgbOutline"
-- "OwnerGlitchBackdrop"
-- "OwnerGlitchText"
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
	-- if b is provided, b wins
	if type(b) == "table" then
		return b
	end
	return a or {}
end

local function resolveTagProfile(plr, role, roleColor)
	local out = {}
	local rolePreset = RoleEffectPresets[role] or RoleEffectPresets.Normal or {}

	-- Start from role preset
	local base = {}
	if type(rolePreset.Preset) == "string" and TagPresets[rolePreset.Preset] then
		base = TagPresets[rolePreset.Preset]
	end

	-- Apply role overrides (Effects and text colours)
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

	-- Now apply user profile
	local userProf = TagEffectProfiles[plr.UserId]
	if userProf then
		-- If user selects a preset, that becomes their base
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

		-- User overrides
		if userProf.Gradient1 then out.Gradient1 = userProf.Gradient1 end
		if userProf.Gradient2 then out.Gradient2 = userProf.Gradient2 end
		if userProf.Gradient3 ~= nil then out.Gradient3 = userProf.Gradient3 end
		if userProf.SpinGradient ~= nil then out.SpinGradient = userProf.SpinGradient end
		if userProf.ScrollGradient ~= nil then out.ScrollGradient = userProf.ScrollGradient end
		if userProf.TopTextColor then out.TopTextColor = userProf.TopTextColor end
		if userProf.BottomTextColor then out.BottomTextColor = userProf.BottomTextColor end
		out.Effects = mergeEffects(out.Effects, userProf.Effects)
	end

	-- Defaults if missing
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

	-- Background gradient
	baseGrad.Color = buildGradientSequence(profile.Gradient1, profile.Gradient2, profile.Gradient3)

	-- Outline gradient (this is what you asked for)
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

	-- Text colours are separate from gradient
	if topLabel then topLabel.TextColor3 = profile.TopTextColor end
	if bottomLabel then bottomLabel.TextColor3 = profile.BottomTextColor end

	-- Owner glitch visuals inside tag
	if hasEffect(effects, "OwnerGlitchBackdrop") then
		if not btn:FindFirstChild("OwnerGlitchImg") then
			addOwnerGlitchBackdrop(btn)
		end
	end
	if hasEffect(effects, "OwnerGlitchText") and topLabel then
		createOwnerGlitchText(topLabel)
	end

	-- If RGB outline is enabled, remove stroke gradient because they fight
	if hasEffect(effects, "RgbOutline") and stroke then
		local sg = stroke:FindFirstChild("StrokeGradient")
		if sg then sg:Destroy() end
		strokeGrad = nil
		startRgbOutline(stroke)
	end

	-- Scanlines overlay
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

	-- Sparkles overlay
	local sparkle = btn:FindFirstChild("Sparkles")
	if hasEffect(effects, "Sparkles") then
		if not sparkle then
			sparkle = Instance.new("ImageLabel")
			sparkle.Name = "Sparkles"
			sparkle.BackgroundTransparency = 1
			sparkle.Size = UDim2.new(1, 0, 1, 0)
			sparkle.Position = UDim2.new(0, 0, 0, 0)
			sparkle.ZIndex = 2
			sparkle.Image = "rbxassetid://3912352814"
			sparkle.ImageTransparency = 0.78
			sparkle.Parent = btn
		end
	else
		if sparkle then sparkle:Destroy() end
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

		-- Spin gradient
		if profile.SpinGradient then
			baseGrad.Rotation = (baseGrad.Rotation + dt * 120) % 360
			if strokeGrad then strokeGrad.Rotation = baseGrad.Rotation end
		end

		-- Scroll gradient and shimmer
		if profile.ScrollGradient or hasEffect(effects, "Shimmer") then
			local off = math.sin(t * 1.8) * 0.25
			baseGrad.Offset = Vector2.new(off, 0)
			if strokeGrad then strokeGrad.Offset = baseGrad.Offset end
		end

		-- Pulse
		if hasEffect(effects, "Pulse") then
			local s = 1 + (math.sin(t * 5.0) * 0.02)
			btn.Size = UDim2.new(baseBtnSize.X.Scale, baseBtnSize.X.Offset * s, baseBtnSize.Y.Scale, baseBtnSize.Y.Offset * s)
		else
			btn.Size = baseBtnSize
		end

		-- Shake
		if hasEffect(effects, "Shake") then
			btn.Rotation = baseBtnRot + (math.sin(t * 25) * 0.8)
		else
			btn.Rotation = baseBtnRot
		end

		-- Flicker (top text)
		if hasEffect(effects, "Flicker") and topLabel then
			local v = (math.sin(t * 22) * 0.5 + 0.5)
			topLabel.TextTransparency = (v > 0.88) and 0.25 or 0
		elseif topLabel then
			topLabel.TextTransparency = 0
		end

		-- RainbowText (only if you want it, but text colour override will win if you set TopTextColor)
		if hasEffect(effects, "RainbowText") and topLabel and (profile.TopTextColor == nil) then
			local h = (t * 0.35) % 1
			topLabel.TextColor3 = Color3.fromHSV(h, 1, 1)
		end

		-- Bounce top text
		if hasEffect(effects, "BounceText") and topLabel then
			local y = math.sin(t * 6) * 1.2
			topLabel.Position = UDim2.new(0, 5, 0, 3 + y)
		elseif topLabel then
			topLabel.Position = UDim2.new(0, 5, 0, 3)
		end

		-- Scanline movement
		if scan then
			local g = scan:FindFirstChildOfClass("UIGradient")
			if g then
				g.Offset = Vector2.new(0, (t * 0.6) % 1)
			end
		end

		-- Sparkles shimmer
		if sparkle then
			sparkle.ImageTransparency = 0.70 + (math.sin(t * 3.0) * 0.12)
		end

		-- Force independent text colours every frame
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
	conn = RunService.RenderStepped:Connect(function(dt)
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
-- ARRIVAL INTROS
--------------------------------------------------------------------
local function playArrivalSound(parentGui, soundId)
	local s = Instance.new("Sound")
	s.Name = "ArrivalSfx"
	s.SoundId = soundId
	s.Volume = 0.9
	s.Looped = false
	s.Parent = parentGui
	pcall(function() s:Play() end)
	task.delay(6, function()
		if s and s.Parent then s:Destroy() end
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
		playArrivalSound(gui, soundId)
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

	local overlay = Instance.new("Frame")
	overlay.Name = "OwnerArrivalOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BorderSizePixel = 0
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.15
	overlay.ZIndex = 5000
	overlay.Parent = gui

	local noise = Instance.new("ImageLabel")
	noise.Name = "Noise"
	noise.BackgroundTransparency = 1
	noise.Size = UDim2.new(1, 0, 1, 0)
	noise.Image = "rbxassetid://5028857084"
	noise.ImageTransparency = 0.5
	noise.ZIndex = 5001
	noise.Parent = overlay

	local msg = Instance.new("TextLabel")
	msg.Name = "Msg"
	msg.BackgroundTransparency = 1
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.new(0, 700, 0, 120)
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 44
	msg.Text = OWNER_ARRIVAL_TEXT
	msg.TextColor3 = Color3.fromRGB(255, 255, 80)
	msg.TextStrokeTransparency = 0.25
	msg.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	msg.ZIndex = 5002
	msg.Parent = overlay

	playArrivalSound(gui, OWNER_ARRIVAL_SOUND_ID)

	task.spawn(function()
		local rng = Random.new()
		local t0 = os.clock()
		while overlay and overlay.Parent and (os.clock() - t0) < 1.2 do
			msg.Position = UDim2.new(0.5, rng:NextInteger(-10, 10), 0.5, rng:NextInteger(-8, 8))
			noise.Rotation = rng:NextInteger(0, 360)
			noise.ImageTransparency = rng:NextNumber(0.30, 0.75)
			overlay.BackgroundTransparency = rng:NextNumber(0.05, 0.25)
			task.wait(rng:NextNumber(0.03, 0.06))
		end
		if overlay and overlay.Parent then overlay:Destroy() end
	end)
end

local function showCoOwnerArrivalGlitch()
	ensureGui()
	if isCoOwner(LocalPlayer) or isOwner(LocalPlayer) then return end

	local overlay = Instance.new("Frame")
	overlay.Name = "CoOwnerArrivalOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BorderSizePixel = 0
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BackgroundTransparency = 0.35
	overlay.ZIndex = 5000
	overlay.Parent = gui

	local noise = Instance.new("ImageLabel")
	noise.Name = "Noise"
	noise.BackgroundTransparency = 1
	noise.Size = UDim2.new(1, 0, 1, 0)
	noise.Image = "rbxassetid://5028857084"
	noise.ImageTransparency = 0.55
	noise.ZIndex = 5001
	noise.Parent = overlay

	local msg = Instance.new("TextLabel")
	msg.Name = "Msg"
	msg.BackgroundTransparency = 1
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.new(0, 740, 0, 120)
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 44
	msg.Text = COOWNER_ARRIVAL_TEXT
	msg.TextColor3 = Color3.fromRGB(0, 0, 0)
	msg.TextStrokeTransparency = 0.65
	msg.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	msg.ZIndex = 5002
	msg.Parent = overlay

	playArrivalSound(gui, COOWNER_ARRIVAL_SOUND_ID)

	task.spawn(function()
		local rng = Random.new()
		local t0 = os.clock()
		while overlay and overlay.Parent and (os.clock() - t0) < 1.0 do
			msg.Position = UDim2.new(0.5, rng:NextInteger(-12, 12), 0.5, rng:NextInteger(-10, 10))
			noise.Rotation = rng:NextInteger(0, 360)
			noise.ImageTransparency = rng:NextNumber(0.35, 0.78)
			overlay.BackgroundTransparency = rng:NextNumber(0.10, 0.55)
			task.wait(rng:NextNumber(0.03, 0.06))
		end
		if overlay and overlay.Parent then overlay:Destroy() end
	end)
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
	if plr.UserId == LocalPlayer.UserId then return end
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

	-- Keep Sin wobble
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
-- SOS + AK UPDATES
--------------------------------------------------------------------
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

local function textHasAk(text)
	if type(text) ~= "string" then return false end
	if text == AK_MARKER_1 or text == AK_MARKER_2 then return true end
	if text:find(AK_MARKER_1, 1, true) then return true end
	if text:find(AK_MARKER_2, 1, true) then return true end
	return false
end

--------------------------------------------------------------------
-- COMMANDS (OWNER/COOWNER ONLY)
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
	ensureStatsPopup()
	ensureBroadcastPanel()

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
	end)

	Players.PlayerRemoving:Connect(function(plr)
		if plr then
			clearSpecialFx(plr)
			disconnectTagFxConn(plr.UserId)
			RepliedToActivationUserId[plr.UserId] = nil
			SinIntroShown[plr.UserId] = nil
			CustomIntroShown[plr.UserId] = nil
		end
		task.defer(reconcilePresence)
	end)

	hookChatListeners()
	reconcilePresence()

	onSosActivated(LocalPlayer.UserId)
	trySendChat(SOS_ACTIVATE_MARKER)

	print("SOS Tags loaded. Presets ready.")
end

task.delay(INIT_DELAY, init)

--------------------------------------------------------------------
-- QUICK HOW TO GIVE SOMEONE A TAG FAST (EXAMPLES)
-- Put these in TagEffectProfiles:
--
-- TagEffectProfiles[123] = { Preset = "RED_SCROLL" }
-- TagEffectProfiles[123] = { Preset = "BLUE_SPIN" }
-- TagEffectProfiles[123] = { Preset = "BLACK_SOLID" }
-- TagEffectProfiles[123] = { Preset = "WHITE_SOLID" }
-- TagEffectProfiles[123] = { Preset = "RAINBOW_SPIN" }
-- TagEffectProfiles[123] = { Preset = "RAINBOW_SCROLL" }
--
-- You can also override text colours:
-- TagEffectProfiles[123] = { Preset = "RED_SCROLL", TopTextColor = Color3.fromRGB(255,255,0), BottomTextColor = Color3.fromRGB(255,255,255) }
--
-- And add effects:
-- TagEffectProfiles[123] = { Preset = "PURPLE_SCROLL", Effects = { "Pulse", "Scanline", "Sparkles" } }
--------------------------------------------------------------------
