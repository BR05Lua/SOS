-- SOS TAGS Standalone LocalScript
-- Put in StarterPlayerScripts

-- Markers
-- Activation marker: 𖺗
-- Reply marker: ¬
-- AK markers: ؍؍؍ or ؍ (detected with contains-match too)

-- Behavior
-- 1) If someone sends 𖺗, that sender gets SOS tags.
-- 2) Your client replies with ¬ ONLY after:
--    - it has seen the first 𖺗 already (global warmup), AND
--    - it has NOT replied to that sender before (ONE ¬ per person per join), AND
--    - the sender is NOT you.
--    Reply-per-person resets when they leave and rejoin.
-- 3) If someone sends ¬, that sender also gets SOS tags.
-- 4) AK orb only shows if the player is SOS activated AND AK activated. Owners never show AK orb.

-- UI
-- Bottom-left broadcast buttons only visible to:
-- - Owner(s)
-- - Sin of Cinna (UserId 2630250935)

-- FX
-- Owner + Cinna get intense speed trails (only while moving).
--   Owner = rainbow trails. Cinna = light blue faded to red.
--   Trail length grows with speed, capped at 20 studs.

-- Owner arrival
-- When an Owner is present, non-owners see a quick glitch screen:
--   Text: "He has Arrived"
--   Sound: rbxassetid://136954512002069
-- Rainbow sky effect REMOVED completely.

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:FindService("TextChatService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local SOS_ACTIVATE_MARKER = "𖺗"
local SOS_REPLY_MARKER = "¬"
local SOS_JOINER_MARKER = "•"

local AK_MARKER_1 = "؍؍؍"
local AK_MARKER_2 = "؍"

local INIT_DELAY = 0.9

-- Tag sizing (smaller)
local TAG_W, TAG_H = 144, 36
local TAG_OFFSET_Y = 3

local ORB_SIZE = 18
local ORB_OFFSET_Y = 3.35

--------------------------------------------------------------------
-- OWNER ARRIVAL (NO SKY)
--------------------------------------------------------------------
local OWNER_ARRIVAL_TEXT = "He has Arrived"
local OWNER_ARRIVAL_SOUND_ID = "rbxassetid://136954512002069"

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

local TesterUserIds = {
	-- leave blank
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
	[7452991350] = { SinName = "XTCY", Color = Color3.fromRGB(0, 220, 0) },
	[3600244479] = { SinName = "PAWS", Color = Color3.fromRGB(180, 1, 64) },
	[8956134409] = { SinName = "Cars", Color = Color3.fromRGB(0, 255, 0) },
}

-- OG profiles (empty by default)
local OgProfiles = {
		[8956134409] = { OGName = "BR05", Color = Color3.fromRGB(255, 0, 0) }
	-- [123456789] = { OgName = "OG", Color = Color3.fromRGB(160,220,255) },
}

-- Custom tag profiles (empty by default)
local CustomTags = {
	[2630250935] = { TagText = "Co-Owner", Color = Color3.fromRGB(255,255,255) }
	-- [123456789] = { TagText = "Custom Title", Color = Color3.fromRGB(255,255,255) },
}

--------------------------------------------------------------------
-- SPEED TRAILS (Owner + Cinna)
--------------------------------------------------------------------
local TRAIL_FOLDER_NAME = "SOS_RunTrails"
local TRAIL_MAX_STUDS = 20
local TRAIL_LEN_PER_SPEED = 0.7
local TRAIL_MIN_SPEED = 1.5

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local SosUsers = {}
local AkUsers = {}

-- Warmup: do NOT auto-reply on the very first activation we see
local SeenFirstActivation = false

-- Reply only once per person per join
local RepliedToActivationUserId = {}

local gui
local statsPopup
local statsPopupLabel

local broadcastPanel
local broadcastSOS
local broadcastAK

-- Owner arrival state
local ownerPresenceAnnounced = false

-- Trail connections
local TrailsConnByUserId = {}

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

local function notify(titleText, bodyText, seconds)
	ensureGui()
	local dur = seconds or 2.2

	local box = Instance.new("Frame")
	box.Name = "SOS_Notify"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 18)
	box.Size = UDim2.new(0, 420, 0, 70)
	box.BorderSizePixel = 0
	box.Parent = gui
	makeCorner(box, 14)
	makeGlass(box)
	makeStroke(box, 2, Color3.fromRGB(200, 40, 40), 0.12)
	box.ZIndex = 2000

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 14, 0, 8)
	title.Size = UDim2.new(1, -28, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245, 245, 245)
	title.Text = titleText or "Notice"
	title.ZIndex = 2001
	title.Parent = box

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 14, 0, 30)
	body.Size = UDim2.new(1, -28, 0, 34)
	body.Font = Enum.Font.Gotham
	body.TextSize = 14
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(225, 225, 225)
	body.Text = bodyText or ""
	body.ZIndex = 2001
	body.Parent = box

	task.delay(dur, function()
		if box and box.Parent then
			box:Destroy()
		end
	end)
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
	return (OwnerNames[plr.Name] == true) or (OwnerUserIds[plr.UserId] == true)
end

local function canSeeBroadcastButtons()
	if isOwner(LocalPlayer) then
		return true
	end
	return LocalPlayer.UserId == 2630250935
end

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
	if old then
		old:Destroy()
	end
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
	if role == "Owner" then return "SOS Owner" end
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
-- CLICK ACTIONS + STATS
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
	btn.Activated:Connect(act)
end

--------------------------------------------------------------------
-- VISUAL FX (Owner glitch + RGB outline, Sin wavy)
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

--------------------------------------------------------------------
-- SPEED TRAILS (INTENSE)
--------------------------------------------------------------------
local function disconnectTrailsConn(userId)
	local c = TrailsConnByUserId[userId]
	if c then
		pcall(function() c:Disconnect() end)
	end
	TrailsConnByUserId[userId] = nil
end

local function clearRunTrails(plr)
	if not plr or not plr.Character then return end
	disconnectTrailsConn(plr.UserId)

	local folder = plr.Character:FindFirstChild(TRAIL_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

local function makeTrailOnPart(part, parentFolder)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0, -math.max(part.Size.Z * 0.5, 0.2))
	a0.Parent = part

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, 0,  math.max(part.Size.Z * 0.5, 0.2))
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

local function applyOwnerRainbow(trail, hue)
	local c0 = Color3.fromHSV(hue % 1, 1, 1)
	local c1 = Color3.fromHSV((hue + 0.18) % 1, 1, 1)
	trail.Color = ColorSequence.new(c0, c1)
end

local function applyCinnaBlueToRed(trail)
	trail.Color = ColorSequence.new(
		Color3.fromRGB(200, 235, 255),
		Color3.fromRGB(255, 120, 120)
	)
end

local function ensureRunTrails(plr, role)
	if not plr or not plr.Character then return end

	local isSpecial = (role == "Owner") or (plr.UserId == 2630250935)
	if not isSpecial then
		clearRunTrails(plr)
		return
	end

	local char = plr.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	clearRunTrails(plr)

	local folder = Instance.new("Folder")
	folder.Name = TRAIL_FOLDER_NAME
	folder.Parent = char

	local trails = {}
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" then
			trails[#trails + 1] = makeTrailOnPart(inst, folder)
		end
	end

	local hue = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not folder or not folder.Parent then
			disconnectTrailsConn(plr.UserId)
			return
		end
		if not hum.Parent or not hrp.Parent then
			disconnectTrailsConn(plr.UserId)
			return
		end

		local speed = hrp.Velocity.Magnitude
		local moving = speed > TRAIL_MIN_SPEED

		for _, tr in ipairs(trails) do
			tr.Enabled = moving
		end
		if not moving then return end

		local desiredLen = math.clamp(speed * TRAIL_LEN_PER_SPEED, 0, TRAIL_MAX_STUDS)
		local lifetime = desiredLen / math.max(speed, 1)
		lifetime = math.clamp(lifetime, 0.10, 0.45)

		for _, tr in ipairs(trails) do
			tr.Lifetime = lifetime
			if role == "Owner" then
				hue = (hue + dt * 0.95) % 1
				applyOwnerRainbow(tr, hue)
			else
				applyCinnaBlueToRed(tr)
			end
		end
	end)

	TrailsConnByUserId[plr.UserId] = conn
end
--------------------------------------------------------------------
-- OWNER ARRIVAL GLITCH SCREEN
--------------------------------------------------------------------
local function playOwnerArrivalSound(parentGui)
	local s = Instance.new("Sound")
	s.Name = "OwnerArrivalSfx"
	s.SoundId = OWNER_ARRIVAL_SOUND_ID
	s.Volume = 0.9
	s.Looped = false
	s.Parent = parentGui
	pcall(function() s:Play() end)
	task.delay(6, function()
		if s and s.Parent then s:Destroy() end
	end)
end

local function showOwnerArrivalGlitch()
	ensureGui()

	-- Owners don't see the glitch screen (they just get a notify)
	if isOwner(LocalPlayer) then
		notify("SOS", "Owner arrival effect triggered for others.", 3)
		return
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "OwnerArrivalOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BorderSizePixel = 0
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.15
	overlay.ZIndex = 5000
	overlay.Parent = gui

	local noise = Instance.new("ImageLabel")
	noise.Name = "Noise"
	noise.BackgroundTransparency = 1
	noise.Size = UDim2.new(1, 0, 1, 0)
	noise.Position = UDim2.new(0, 0, 0, 0)
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

	playOwnerArrivalSound(gui)

	task.spawn(function()
		local rng = Random.new()
		local t0 = os.clock()
		while overlay and overlay.Parent and (os.clock() - t0) < 1.2 do
			local jx = rng:NextInteger(-10, 10)
			local jy = rng:NextInteger(-8, 8)
			msg.Position = UDim2.new(0.5, jx, 0.5, jy)
			noise.Rotation = rng:NextInteger(0, 360)
			noise.ImageTransparency = rng:NextNumber(0.30, 0.75)
			overlay.BackgroundTransparency = rng:NextNumber(0.05, 0.25)
			task.wait(rng:NextNumber(0.03, 0.06))
		end

		if overlay and overlay.Parent then
			overlay:Destroy()
		end
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
	if present and not ownerPresenceAnnounced then
		ownerPresenceAnnounced = true
		showOwnerArrivalGlitch()
	elseif not present then
		ownerPresenceAnnounced = false
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
	ensureRunTrails(plr, role)

	if not role then
		destroyTagGui(char, "SOS_RoleTag")
		return
	end

	local head = char:FindFirstChild("Head")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local adornee = (head and head:IsA("BasePart")) and head or ((hrp and hrp:IsA("BasePart")) and hrp or nil)
	if not adornee then return end

	destroyTagGui(char, "SOS_RoleTag")

	local color = getRoleColor(plr, role)

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

local function createAkOrbTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	if isOwner(plr) then
		destroyTagGui(char, "SOS_AKTag")
		return
	end

	if not SosUsers[plr.UserId] then
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
-- SOS + AK UPDATES
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

local function textHasAk(text)
	if type(text) ~= "string" then return false end
	if text == AK_MARKER_1 or text == AK_MARKER_2 then return true end
	if text:find(AK_MARKER_1, 1, true) then return true end
	if text:find(AK_MARKER_2, 1, true) then return true end
	return false
end

--------------------------------------------------------------------
-- CHAT LISTENERS (reply once per person per join)
--------------------------------------------------------------------
local function maybeReplyToActivation(uid)
	if typeof(uid) ~= "number" then return end
	if uid == LocalPlayer.UserId then return end

	if not SeenFirstActivation then
		SeenFirstActivation = true
		return
	end

	if RepliedToActivationUserId[uid] then
		return
	end

	RepliedToActivationUserId[uid] = true
	trySendChat(SOS_REPLY_MARKER)
end

local function hookChatListeners()
	if TextChatService and TextChatService.MessageReceived then
		TextChatService.MessageReceived:Connect(function(msg)
			if not msg then return end
			local text = msg.Text or ""
			local src = msg.TextSource
			if not src or not src.UserId then return end
			local uid = src.UserId

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
		end)
	end

	local function hookChatted(plr)
		pcall(function()
			plr.Chatted:Connect(function(message)
				if message == SOS_ACTIVATE_MARKER then
					onSosActivated(plr.UserId)
					maybeReplyToActivation(plr.UserId)
				elseif message == SOS_REPLY_MARKER then
					onSosActivated(plr.UserId)
				elseif textHasAk(message) then
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
		task.defer(reconcileOwnerPresence)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		if plr then
			clearRunTrails(plr)
			RepliedToActivationUserId[plr.UserId] = nil
		end
		task.defer(reconcileOwnerPresence)
	end)

	hookChatListeners()

	reconcileOwnerPresence()

	onSosActivated(LocalPlayer.UserId)
	trySendChat(SOS_ACTIVATE_MARKER)

	print("SOS Tags loaded. Activation 𖺗. Reply ¬ once per person per join. AK contains-match. No rainbow sky.")
end

task.delay(INIT_DELAY, init)
