-- SOS TAGS (Standalone LocalScript)
-- Put in StarterPlayerScripts

-- Markers
-- 𖺗 = SOS activation marker (script sends this on startup; anyone who sends it gets SOS tags)
-- ¬   = follow marker (your separate trigger; we reply with this when someone else sends 𖺗)
-- •   = optional joiner marker (ignored for activation)
-- AK  = ؍؍؍ or ؍

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:FindService("TextChatService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- ROLES / CONFIG
--------------------------------------------------------------------
local ROLE_COLOR = {
	Normal = Color3.fromRGB(120, 190, 235),
	Owner  = Color3.fromRGB(255, 255, 80),
	Tester = Color3.fromRGB(60, 255, 90),
	Sin    = Color3.fromRGB(235, 70, 70),
	OG     = Color3.fromRGB(160, 220, 255),
}

local OwnerNames = {
	["deniskraily"] = true,
}

local OwnerUserIds = {
	[433636433] = true,
	[196988708] = true,
}

local TesterUserIds = {
	-- leave blank for now
}

local SinProfiles = {
	[2630250935] = { SinName = "Cinna (Co-Owner)", Color = Color3.fromRGB(215, 214, 254) },
	[105995794]  = { SinName = "Lettuce" },
	[138975737]  = { SinName = "Music" },
	[9159968275] = { SinName = "Music" },
	[4659279349] = { SinName = "Trial" },
	[4495710706] = { SinName = "Code (Owned By Fed)" },
	[1575141882] = { SinName = "Heart", Color = Color3.fromRGB(255, 120, 210) },
	[118170824]  = { SinName = "Security" },
	[7870252435] = { SinName = "Security" },
	[3600244479] = { SinName = "PAWS (Tester)", Color = Color3.fromRGB(180, 1, 64) },
	[8956134409] = { SinName = "Cars (Tester)", Color = Color3.fromRGB(0, 255, 0) },
}

-- OG section (empty for now, add users like SinProfiles)
local OgProfiles = {
	-- [123456789] = { OgName = "Founding OG", Color = Color3.fromRGB(160,220,255) },
}

-- Custom tag section (empty for now)
-- NOT "SOS User" text: uses TagText
local CustomTags = {
	[7452991350] = { TagText = "XTCY", Color = Color3.fromRGB(0, 220, 0) }
	-- [123456789] = { TagText = "My Custom Title", Color = Color3.fromRGB(255,255,255) },
}

--------------------------------------------------------------------
-- MARKERS
--------------------------------------------------------------------
local SOS_ACTIVATE_MARKER = "𖺗"
local SOS_FOLLOW_MARKER = "¬"
local SOS_MARKER_JOINER = "•"

local AK_MARKER_1 = "؍؍؍"
local AK_MARKER_2 = "؍"

--------------------------------------------------------------------
-- SIZES / TIMING
--------------------------------------------------------------------
local TAG_W, TAG_H = 144, 36
local TAG_OFFSET_Y = 3

local ORB_SIZE = 18
local ORB_OFFSET_Y = 3.35

local INIT_DELAY = 0.9

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local SosUsers = {}
local AkUsers = {}

-- Local activation state (script auto-activates on startup)
local LocalActivatedThisServer = true
local StartupActivated = true

-- UI
local gui
local statsPopup
local statsPopupLabel
local broadcastPanel
local broadcastSOS
local broadcastAK

-- Owner sky overlay state
local ownerEffectRunning = false
local rainbowSkyEnabled = false
local rainbowTick = 0
local savedLightingState = nil
local overlaySky = nil

--------------------------------------------------------------------
-- HELPERS
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

local function isOwner(plr)
	return (OwnerNames[plr.Name] == true) or (OwnerUserIds[plr.UserId] == true)
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

local function ensureBroadcastPanel()
	ensureGui()
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
		statsPopup.Visible = true
	end)
end

local function trySendChat(text)
	-- TextChatService
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

	-- Legacy chat
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
-- ROLE RESOLUTION (Owner, Custom, OG, Sin, Tester, SOS)
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

	if role == "Owner" then
		return ROLE_COLOR.Owner
	end

	return ROLE_COLOR[role] or Color3.fromRGB(240, 240, 240)
end

local function getTopLine(plr, role)
	if role == "Owner" then
		return "SOS Owner"
	end
	if role == "Tester" then
		return "SOS Tester"
	end
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
	myHRP.CFrame = theirHRP.CFrame * CFrame.new(0, 0, back)
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
	btn.Activated:Connect(function()
		local holdingCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if holdingCtrl then
			showPlayerStats(plr)
		else
			teleportBehind(plr, 5)
		end
	end)
end

--------------------------------------------------------------------
-- VISUAL FX: Owner glitch image + RGB outline
--------------------------------------------------------------------
local function startRgbOutline(stroke)
	if not stroke then return end
	task.spawn(function()
		local t = 0
		while stroke and stroke.Parent do
			t += 0.03
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
			img.ImageTransparency = rng:NextNumber(0.35, 0.75)
			img.Position = UDim2.new(0, rng:NextInteger(-2, 2), 0, rng:NextInteger(-2, 2))
			task.wait(rng:NextNumber(0.05, 0.10))
		end
	end)
end

--------------------------------------------------------------------
-- VISUAL FX: Sin wavy look
--------------------------------------------------------------------
local function addSinWavyLook(parentBtn)
	local waveGrad = Instance.new("UIGradient")
	waveGrad.Rotation = 90
	waveGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
	})
	waveGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	waveGrad.Parent = parentBtn

	task.spawn(function()
		local t = 0
		while parentBtn and parentBtn.Parent do
			t += 0.06
			local y = math.sin(t) * 1.2
			parentBtn.Rotation = math.sin(t * 0.8) * 1.2
			parentBtn.Position = UDim2.new(parentBtn.Position.X.Scale, parentBtn.Position.X.Offset, parentBtn.Position.Y.Scale, parentBtn.Position.Y.Offset + y)
			waveGrad.Offset = Vector2.new(math.sin(t * 0.6) * 0.2, 0)
			task.wait(0.03)
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
						table.insert(outt, chars:sub(idx, idx))
					else
						table.insert(outt, base:sub(i, i))
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

local function destroyTagGui(char, name)
	if not char then return end
	local old = char:FindFirstChild(name)
	if old then old:Destroy() end
end

--------------------------------------------------------------------
-- TAG CREATION (SOS roles)
--------------------------------------------------------------------
local function createSosRoleTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	local role = getSosRole(plr)
	if not role then
		destroyTagGui(char, "SOS_RoleTag")
		return
	end

	local head = char:FindFirstChild("Head")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local adornee = (head and head:IsA("BasePart")) and head or ((hrp and hrp:IsA("BasePart")) and hrp or nil)
	if not adornee then return end

	destroyTagGui(char, "SOS_RoleTag")

	local color = getRoleColor(plr, role) or Color3.fromRGB(240, 240, 240)

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
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
	})
	grad.Parent = btn

	local stroke = makeStroke(btn, 2, color, 0.05)

	if role == "Owner" then
		btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		btn.BackgroundTransparency = 0.12
		addOwnerGlitchBackdrop(btn)
		stroke.Transparency = 0.05
		stroke.Thickness = 2
		startRgbOutline(stroke)
	end

	if role == "Sin" then
		addSinWavyLook(btn)
	end

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

	if role == "Owner" then
		top.TextColor3 = Color3.fromRGB(255, 255, 80)
		makeStroke(top, 1, Color3.fromRGB(0, 0, 0), 0.35)
		createOwnerGlitchText(top)
	else
		top.TextColor3 = color
	end

	local bottom = Instance.new("TextLabel")
	bottom.BackgroundTransparency = 1
	bottom.Size = UDim2.new(1, -10, 0, 16)
	bottom.Position = UDim2.new(0, 5, 0, 19)
	bottom.Font = Enum.Font.Gotham
	bottom.TextSize = 12
	bottom.TextColor3 = Color3.fromRGB(230, 230, 230)
	bottom.TextXAlignment = Enum.TextXAlignment.Center
	bottom.TextYAlignment = Enum.TextYAlignment.Center
	bottom.Text = plr.Name
	bottom.ZIndex = 3
	bottom.Parent = btn

	makeTagButtonCommon(btn, plr)
end
--------------------------------------------------------------------
-- AK ORB
--------------------------------------------------------------------
local function createAkOrbTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	if isOwner(plr) then
		destroyTagGui(char, "SOS_AKTag")
		return
	end

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
-- ACTIVATION + MARKER LOGIC
--------------------------------------------------------------------
local function onSosActivated(userId)
	if typeof(userId) ~= "number" then return end
	SosUsers[userId] = true
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		refreshAllTagsForPlayer(plr)
	end
end

local function onAkSeen(userId)
	if typeof(userId) ~= "number" then return end
	AkUsers[userId] = true
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		refreshAllTagsForPlayer(plr)
	end
end

local function replyFollowMarker(uid)
	if typeof(uid) ~= "number" then return end
	if uid == LocalPlayer.UserId then return end
	if not LocalActivatedThisServer then return end
	trySendChat(SOS_FOLLOW_MARKER) -- ¬
end

--------------------------------------------------------------------
-- OWNER FX + RAINBOW SKY (ONLY WHILE OWNER PRESENT)
--------------------------------------------------------------------
local function snapshotLighting()
	if savedLightingState then return end
	savedLightingState = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
	}
end

local function restoreLighting()
	if not savedLightingState then return end
	Lighting.Ambient = savedLightingState.Ambient
	Lighting.OutdoorAmbient = savedLightingState.OutdoorAmbient
	Lighting.Brightness = savedLightingState.Brightness
	Lighting.ClockTime = savedLightingState.ClockTime
	Lighting.FogColor = savedLightingState.FogColor
	Lighting.FogStart = savedLightingState.FogStart
	Lighting.FogEnd = savedLightingState.FogEnd
	Lighting.ColorShift_Top = savedLightingState.ColorShift_Top
	Lighting.ColorShift_Bottom = savedLightingState.ColorShift_Bottom
	savedLightingState = nil
end

local function enableOwnerSky()
	if rainbowSkyEnabled then return end
	snapshotLighting()
	rainbowSkyEnabled = true

	-- overlay sky (doesn't delete existing Sky)
	if not overlaySky then
		overlaySky = Instance.new("Sky")
		overlaySky.Name = "SOS_OwnerRainbowSky"

		-- You can replace these ids later
		overlaySky.SkyboxBk = "rbxassetid://159454299"
		overlaySky.SkyboxDn = "rbxassetid://159454296"
		overlaySky.SkyboxFt = "rbxassetid://159454293"
		overlaySky.SkyboxLf = "rbxassetid://159454286"
		overlaySky.SkyboxRt = "rbxassetid://159454300"
		overlaySky.SkyboxUp = "rbxassetid://159454288"
		overlaySky.StarCount = 3000
		overlaySky.Parent = Lighting
	end
end

local function disableOwnerSky()
	if not rainbowSkyEnabled then return end
	rainbowSkyEnabled = false

	if overlaySky then
		overlaySky:Destroy()
		overlaySky = nil
	end

	restoreLighting()
end

local function applyRainbowGalaxyLighting(dt)
	if not rainbowSkyEnabled then return end
	rainbowTick += dt

	local t = rainbowTick
	local r = (math.sin(t * 0.8) * 0.5 + 0.5)
	local g = (math.sin(t * 0.8 + 2.094) * 0.5 + 0.5)
	local b = (math.sin(t * 0.8 + 4.188) * 0.5 + 0.5)

	Lighting.Brightness = 2.2
	Lighting.ClockTime = (t * 0.4) % 24
	Lighting.Ambient = Color3.new(r * 0.25, g * 0.25, b * 0.35)
	Lighting.OutdoorAmbient = Color3.new(r * 0.15, g * 0.15, b * 0.25)
	Lighting.FogColor = Color3.new(r * 0.25, g * 0.20, b * 0.30)
	Lighting.FogStart = 0
	Lighting.FogEnd = 1200
	Lighting.ColorShift_Top = Color3.new(r * 0.35, g * 0.20, b * 0.45)
	Lighting.ColorShift_Bottom = Color3.new(r * 0.15, g * 0.30, b * 0.20)
end

RunService.RenderStepped:Connect(function(dt)
	applyRainbowGalaxyLighting(dt)
end)

local function playOwnerJoinEffect()
	if ownerEffectRunning then return end
	ownerEffectRunning = true
	ensureGui()

	local overlay = Instance.new("Frame")
	overlay.Name = "OwnerJoinGlitch"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.2
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.ZIndex = 999
	overlay.Parent = gui

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Image = "rbxassetid://5028857084"
	img.ImageTransparency = 0.55
	img.ZIndex = 1000
	img.Parent = overlay

	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.AnchorPoint = Vector2.new(0.5, 0.5)
	msg.Position = UDim2.new(0.5, 0, 0.5, 0)
	msg.Size = UDim2.new(0, 520, 0, 70)
	msg.Font = Enum.Font.GothamBlack
	msg.TextSize = 28
	msg.TextXAlignment = Enum.TextXAlignment.Center
	msg.TextYAlignment = Enum.TextYAlignment.Center
	msg.TextColor3 = Color3.fromRGB(255, 255, 80)
	msg.Text = "The SOS Owner is here"
	msg.ZIndex = 1001
	msg.Parent = overlay

	makeStroke(msg, 2, Color3.fromRGB(0, 0, 0), 0.25)

	task.spawn(function()
		local rng = Random.new()
		for _ = 1, 18 do
			img.ImageTransparency = rng:NextNumber(0.35, 0.75)
			img.Position = UDim2.new(0, rng:NextInteger(-12, 12), 0, rng:NextInteger(-12, 12))
			msg.Position = UDim2.new(0.5, rng:NextInteger(-10, 10), 0.5, rng:NextInteger(-6, 6))
			msg.TextTransparency = rng:NextNumber(0, 0.25)
			task.wait(rng:NextNumber(0.03, 0.06))
		end
	end)

	task.delay(0.75, function()
		for i = 1, 18 do
			overlay.BackgroundTransparency = 0.2 + (i / 18) * 0.8
			img.ImageTransparency = 0.55 + (i / 18) * 0.45
			msg.TextTransparency = (i / 18)
			task.wait(0.02)
		end
		overlay:Destroy()
		ownerEffectRunning = false
	end)
end

local function anyOwnerPresent()
	for _, p in ipairs(Players:GetPlayers()) do
		if isOwner(p) then
			return true
		end
	end
	return false
end

local function reconcileOwnerPresence()
	local present = anyOwnerPresent()
	if present then
		enableOwnerSky()
	else
		disableOwnerSky()
	end
end

--------------------------------------------------------------------
-- CHAT LISTENERS
--------------------------------------------------------------------
local function hookChatListeners()
	-- TextChatService listener
	if TextChatService and TextChatService.MessageReceived then
		TextChatService.MessageReceived:Connect(function(msg)
			if not msg then return end
			local text = msg.Text or ""
			local src = msg.TextSource
			if not src or not src.UserId then return end
			local uid = src.UserId

			if text == SOS_ACTIVATE_MARKER then
				onSosActivated(uid)
				replyFollowMarker(uid)
				return
			end

			if text == AK_MARKER_1 or text == AK_MARKER_2 then
				onAkSeen(uid)
				return
			end
		end)
	end

	-- Player.Chatted fallback
	local function hookChatted(plr)
		pcall(function()
			plr.Chatted:Connect(function(message)
				if message == SOS_ACTIVATE_MARKER then
					onSosActivated(plr.UserId)
					replyFollowMarker(plr.UserId)
				elseif message == AK_MARKER_1 or message == AK_MARKER_2 then
					onAkSeen(plr.UserId)
				end
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

	-- Buttons
	if broadcastSOS then
		broadcastSOS.MouseButton1Click:Connect(function()
			LocalActivatedThisServer = true
			onSosActivated(LocalPlayer.UserId)
			trySendChat(SOS_ACTIVATE_MARKER) -- 𖺗
		end)
	end

	if broadcastAK then
		broadcastAK.MouseButton1Click:Connect(function()
			onAkSeen(LocalPlayer.UserId)
			trySendChat(AK_MARKER_1) -- ؍؍؍
		end)
	end

	-- Hook players
	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayer(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		hookPlayer(plr)

		if isOwner(plr) then
			task.defer(function()
				playOwnerJoinEffect()
				reconcileOwnerPresence()
			end)
			refreshAllTagsForPlayer(plr)
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		task.defer(function()
			reconcileOwnerPresence()
		end)
	end)

	hookChatListeners()

	-- Owners already in server
	for _, plr in ipairs(Players:GetPlayers()) do
		if isOwner(plr) then
			task.defer(function()
				playOwnerJoinEffect()
			end)
			refreshAllTagsForPlayer(plr)
		end
	end

	-- Ensure sky state matches actual owners
	reconcileOwnerPresence()

	-- STARTUP: auto-activate + send activation marker
	if not StartupActivated then
		StartupActivated = true
		LocalActivatedThisServer = true
		onSosActivated(LocalPlayer.UserId)
		trySendChat(SOS_ACTIVATE_MARKER) -- 𖺗
	end
end

task.delay(INIT_DELAY, init)
