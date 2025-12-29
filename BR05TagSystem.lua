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
--   Owner default = rainbow trails.
--   Cinna default = light blue faded to red.
--   Trail length grows with speed, capped at 20 studs.

-- Owner arrival
-- When an Owner is present, non-owners see a quick glitch screen:
--   Text: "He has Arrived"
--   Sound: rbxassetid://136954512002069

-- Co-Owner arrival
-- When Co-Owner is present, non-owners/non-coowners see a quick glitch screen:
--   Text: "Hes Behind You"
--   Sound: rbxassetid://119023903778140
--   Flash white

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

-- Tag sizing (smaller)
local TAG_W, TAG_H = 144, 36
local TAG_OFFSET_Y = 3

local ORB_SIZE = 18
local ORB_OFFSET_Y = 3.35

--------------------------------------------------------------------
-- ARRIVAL FX
--------------------------------------------------------------------
local OWNER_ARRIVAL_TEXT = "He has Arrived"
local OWNER_ARRIVAL_SOUND_ID = "rbxassetid://136954512002069"

local COOWNER_ARRIVAL_TEXT = "Hes Behind You"
local COOWNER_ARRIVAL_SOUND_ID = "rbxassetid://119023903778140"

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

-- OG profiles (optional)
local OgProfiles = {
	-- [123456789] = { OgName = "OG", Color = Color3.fromRGB(160,220,255) },
}

-- Custom tag profiles (used for Co-Owner)
local CustomTags = {
	[2630250935] = { TagText = "Co-Owner", Color = Color3.fromRGB(245, 245, 245) },
}

--------------------------------------------------------------------
-- SPEED TRAILS (Owner + Cinna)
--------------------------------------------------------------------
local TRAIL_FOLDER_NAME = "SOS_RunTrails"
local TRAIL_MAX_STUDS = 20
local TRAIL_LEN_PER_SPEED = 0.7
local TRAIL_MIN_SPEED = 1.5

-- Commands (sent in chat by buttons)
local CMD_OWNER_ON = "Owner_on"
local CMD_OWNER_OFF = "Owner_off"
local CMD_COOWNER_ON = "CoOwner_on"
local CMD_COOWNER_OFF = "CoOwner_off"

-- Optional color commands (also sent by the slide-out menu)
local CMD_OWNER_COLOR_PREFIX = "Owner_color:"
local CMD_COOWNER_COLOR_PREFIX = "CoOwner_color:"

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local SosUsers = {}
local AkUsers = {}

-- Warmup: do NOT auto-reply on the very first activation we see
local SeenFirstActivation = false

-- Reply only once per person per join
local RepliedToActivationUserId = {}

-- Trails toggle + color modes, synced via chat commands
local TrailsEnabled = {
	Owner = true,
	CoOwner = true,
}
local TrailColorMode = {
	Owner = "Rainbow",
	CoOwner = "BlueRed",
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

-- Owner/CoOwner presence state
local ownerPresenceAnnounced = false
local coOwnerPresenceAnnounced = false

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
	return plr and ((OwnerNames[plr.Name] == true) or (OwnerUserIds[plr.UserId] == true))
end

local function isCoOwner(plr)
	return plr and (plr.UserId == 2630250935)
end

local function canSeeBroadcastButtons()
	if isOwner(LocalPlayer) then
		return true
	end
	return LocalPlayer.UserId == 2630250935
end
--------------------------------------------------------------------
-- LEFT SLIDE-OUT MENU (SOS HUD STYLE)
--------------------------------------------------------------------
local trailPanel
local trailArrow
local trailOpen = false
local trailTween = nil

local function canSeeTrailMenu()
	return isOwner(LocalPlayer) or isCoOwner(LocalPlayer)
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

	local PANEL_W, PANEL_H = 250, 170
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
	sub.Text = isOwner(LocalPlayer) and "Owner controls" or "Co-Owner controls"
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

	local colorsLabel = Instance.new("TextLabel")
	colorsLabel.BackgroundTransparency = 1
	colorsLabel.Position = UDim2.new(0, 12, 0, 104)
	colorsLabel.Size = UDim2.new(1, -(ARROW_W + 18), 0, 16)
	colorsLabel.Font = Enum.Font.GothamBold
	colorsLabel.TextSize = 12
	colorsLabel.TextXAlignment = Enum.TextXAlignment.Left
	colorsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	colorsLabel.Text = "Colour"
	colorsLabel.Parent = trailPanel

	local colorRow = Instance.new("Frame")
	colorRow.BackgroundTransparency = 1
	colorRow.Position = UDim2.new(0, 10, 0, 124)
	colorRow.Size = UDim2.new(1, -(ARROW_W + 20), 0, 36)
	colorRow.Parent = trailPanel

	local colorLayout = Instance.new("UIListLayout")
	colorLayout.FillDirection = Enum.FillDirection.Horizontal
	colorLayout.SortOrder = Enum.SortOrder.LayoutOrder
	colorLayout.Padding = UDim.new(0, 10)
	colorLayout.Parent = colorRow

	local c1 = makeButton(colorRow, "1")
	c1.Size = UDim2.new(0, 50, 0, 32)
	local c2 = makeButton(colorRow, "2")
	c2.Size = UDim2.new(0, 50, 0, 32)
	local c3 = makeButton(colorRow, "3")
	c3.Size = UDim2.new(0, 50, 0, 32)

	local function sendOn()
		if isOwner(LocalPlayer) then
			TrailsEnabled.Owner = true
			trySendChat(CMD_OWNER_ON)
		elseif isCoOwner(LocalPlayer) then
			TrailsEnabled.CoOwner = true
			trySendChat(CMD_COOWNER_ON)
		end
	end

	local function sendOff()
		if isOwner(LocalPlayer) then
			TrailsEnabled.Owner = false
			trySendChat(CMD_OWNER_OFF)
		elseif isCoOwner(LocalPlayer) then
			TrailsEnabled.CoOwner = false
			trySendChat(CMD_COOWNER_OFF)
		end
	end

	local function sendColor(mode)
		if isOwner(LocalPlayer) then
			TrailColorMode.Owner = mode
			trySendChat(CMD_OWNER_COLOR_PREFIX .. mode)
		elseif isCoOwner(LocalPlayer) then
			TrailColorMode.CoOwner = mode
			trySendChat(CMD_COOWNER_COLOR_PREFIX .. mode)
		end
	end

	onBtn.MouseButton1Click:Connect(sendOn)
	offBtn.MouseButton1Click:Connect(sendOff)

	if isOwner(LocalPlayer) then
		c1.Text = "RGB"
		c2.Text = "YLW"
		c3.Text = "RED"
		c1.MouseButton1Click:Connect(function() sendColor("Rainbow") end)
		c2.MouseButton1Click:Connect(function() sendColor("Yellow") end)
		c3.MouseButton1Click:Connect(function() sendColor("Red") end)
	else
		c1.Text = "B/R"
		c2.Text = "CYN"
		c3.Text = "GRN"
		c1.MouseButton1Click:Connect(function() sendColor("BlueRed") end)
		c2.MouseButton1Click:Connect(function() sendColor("Cyan") end)
		c3.MouseButton1Click:Connect(function() sendColor("Green") end)
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
-- BROADCAST UI (UNCHANGED SOS/AK)
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
-- SFX COMMAND BUTTONS (OWNER OR CO-OWNER ONLY, EACH SEES OWN)
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
			TrailsEnabled.Owner = true
			trySendChat(CMD_OWNER_ON)
		elseif isCoOwner(LocalPlayer) then
			TrailsEnabled.CoOwner = true
			trySendChat(CMD_COOWNER_ON)
		end
	end)

	sfxOffBtn.MouseButton1Click:Connect(function()
		if isOwner(LocalPlayer) then
			TrailsEnabled.Owner = false
			trySendChat(CMD_OWNER_OFF)
		elseif isCoOwner(LocalPlayer) then
			TrailsEnabled.CoOwner = false
			trySendChat(CMD_COOWNER_OFF)
		end
	end)
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
	if old then
		old:Destroy()
	end
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
	pcall(function()
		btn.Activated:Connect(act)
	end)
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

local function setTrailStatic(trail, c0, c1)
	trail.Color = ColorSequence.new(c0, c1 or c0)
end

local function resolveOwnerMode()
	return TrailColorMode.Owner or "Rainbow"
end

local function resolveCoOwnerMode()
	return TrailColorMode.CoOwner or "BlueRed"
end

local function applyOwnerMode(trail, hue)
	local mode = resolveOwnerMode()
	if mode == "Rainbow" then
		applyOwnerRainbow(trail, hue)
	elseif mode == "Yellow" then
		setTrailStatic(trail, Color3.fromRGB(255, 255, 80), Color3.fromRGB(255, 220, 60))
	elseif mode == "Red" then
		setTrailStatic(trail, Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 120, 120))
	else
		applyOwnerRainbow(trail, hue)
	end
end

local function applyCoOwnerMode(trail)
	local mode = resolveCoOwnerMode()
	if mode == "BlueRed" then
		setTrailStatic(trail, Color3.fromRGB(200, 235, 255), Color3.fromRGB(255, 120, 120))
	elseif mode == "Cyan" then
		setTrailStatic(trail, Color3.fromRGB(120, 255, 255), Color3.fromRGB(80, 180, 255))
	elseif mode == "Green" then
		setTrailStatic(trail, Color3.fromRGB(120, 255, 120), Color3.fromRGB(40, 200, 90))
	else
		setTrailStatic(trail, Color3.fromRGB(200, 235, 255), Color3.fromRGB(255, 120, 120))
	end
end

local function ensureRunTrails(plr, role)
	if not plr or not plr.Character then return end

	local isOwnerRole = (role == "Owner")
	local isCinnaRole = (plr.UserId == 2630250935)

	local enabled = true
	if isOwnerRole then
		enabled = TrailsEnabled.Owner ~= false
	elseif isCinnaRole then
		enabled = TrailsEnabled.CoOwner ~= false
	end

	local isSpecial = isOwnerRole or isCinnaRole
	if (not isSpecial) or (not enabled) then
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

		-- live enable check (in case commands toggled)
		if isOwnerRole and TrailsEnabled.Owner == false then
			clearRunTrails(plr)
			return
		end
		if isCinnaRole and TrailsEnabled.CoOwner == false then
			clearRunTrails(plr)
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
			if isOwnerRole then
				hue = (hue + dt * 0.95) % 1
				applyOwnerMode(tr, hue)
			else
				applyCoOwnerMode(tr)
			end
		end
	end)

	TrailsConnByUserId[plr.UserId] = conn
end

--------------------------------------------------------------------
-- ARRIVAL GLITCH SCREENS
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

local function showOwnerArrivalGlitch()
	ensureGui()
	if isOwner(LocalPlayer) then
		return
	end

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
	if isCoOwner(LocalPlayer) or isOwner(LocalPlayer) then
		return
	end

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

local function anyOwnerPresent()
	for _, p in ipairs(Players:GetPlayers()) do
		if isOwner(p) then
			return true
		end
	end
	return false
end

local function anyCoOwnerPresent()
	for _, p in ipairs(Players:GetPlayers()) do
		if isCoOwner(p) then
			return true
		end
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

	-- Username line (fixed to always show)
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
	bottom.ZIndex = 4
	bottom.Parent = btn

	makeTagButtonCommon(btn, plr)
end

local function createAkOrbTag(plr)
	if not plr then return end
	local char = plr.Character
	if not char then return end

	-- Owners never show AK orb
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
-- CHAT HANDLING (ACTIVATION + COMMANDS)
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

local function applyCommandFrom(uid, text)
	local plr = Players:GetPlayerByUserId(uid)

	-- Owner commands only accepted if sender is owner
	if text == CMD_OWNER_ON and plr and isOwner(plr) then
		TrailsEnabled.Owner = true
		for _, p in ipairs(Players:GetPlayers()) do
			if isOwner(p) and p.Character then
				refreshAllTagsForPlayer(p)
			end
		end
		return true
	end
	if text == CMD_OWNER_OFF and plr and isOwner(plr) then
		TrailsEnabled.Owner = false
		for _, p in ipairs(Players:GetPlayers()) do
			if isOwner(p) then
				clearRunTrails(p)
			end
		end
		return true
	end

	-- CoOwner commands only accepted if sender is coowner
	if text == CMD_COOWNER_ON and plr and isCoOwner(plr) then
		TrailsEnabled.CoOwner = true
		if plr then refreshAllTagsForPlayer(plr) end
		return true
	end
	if text == CMD_COOWNER_OFF and plr and isCoOwner(plr) then
		TrailsEnabled.CoOwner = false
		if plr then clearRunTrails(plr) end
		return true
	end

	-- Color commands (optional)
	if text:sub(1, #CMD_OWNER_COLOR_PREFIX) == CMD_OWNER_COLOR_PREFIX and plr and isOwner(plr) then
		local mode = text:sub(#CMD_OWNER_COLOR_PREFIX + 1)
		if mode ~= "" then
			TrailColorMode.Owner = mode
			if plr then refreshAllTagsForPlayer(plr) end
		end
		return true
	end

	if text:sub(1, #CMD_COOWNER_COLOR_PREFIX) == CMD_COOWNER_COLOR_PREFIX and plr and isCoOwner(plr) then
		local mode = text:sub(#CMD_COOWNER_COLOR_PREFIX + 1)
		if mode ~= "" then
			TrailColorMode.CoOwner = mode
			if plr then refreshAllTagsForPlayer(plr) end
		end
		return true
	end

	return false
end

local function handleIncoming(uid, text)
	if typeof(uid) ~= "number" then return end
	if type(text) ~= "string" then return end

	-- Commands first (so they do not affect SOS/AK state)
	if applyCommandFrom(uid, text) then
		return
	end

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
	ensureSfxPanel()
	ensureTrailMenu()

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
			clearRunTrails(plr)
			RepliedToActivationUserId[plr.UserId] = nil
		end
		task.defer(reconcilePresence)
	end)

	hookChatListeners()

	reconcilePresence()

	-- Local auto activation (unchanged)
	onSosActivated(LocalPlayer.UserId)
	trySendChat(SOS_ACTIVATE_MARKER)

	print("SOS Tags loaded. Activation 𖺗. Reply ¬ once per person per join. AK contains-match.")
end

task.delay(INIT_DELAY, init)
