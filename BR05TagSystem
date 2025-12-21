-- SOS TAGS (Standalone LocalScript)
-- Put in StarterPlayerScripts
-- SOS marker: ¬ (primary) and • (joiner)
-- AK marker: ؍؍؍ or ؍
-- New behavior:
--   - 𖺗 is EXECUTED symbol
--   - If someone else says 𖺗, you send ¬ once per sender
-- UI:
--   - Bottom-left broadcast buttons: SOS + AK

--------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:FindService("TextChatService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------
-- ROLES / CONFIG
--------------------------------------------------------------------
local ROLE_COLOR = {
	Normal = Color3.fromRGB(120, 190, 235),
	Owner  = Color3.fromRGB(255, 255, 80),
	Tester = Color3.fromRGB(60, 255, 90),
	Sin    = Color3.fromRGB(235, 70, 70),
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
	[2630250935] = { SinName = "Cinna" },
	[105995794]  = { SinName = "Lettuce" },
	[138975737]  = { SinName = "Music" },
	[9159968275] = { SinName = "Music" },
	[4659279349] = { SinName = "Trial" },
	[4495710706] = { SinName = "Games Design" },
	[1575141882] = { SinName = "Heart", Color = Color3.fromRGB(255, 120, 210) },
}

local SOS_MARKER_PRIMARY = "¬"
local SOS_MARKER_JOINER  = "•"
local AK_MARKER_1 = "؍؍؍"
local AK_MARKER_2 = "؍"

-- Executed symbol
local EXECUTED_SYMBOL = "𖺗"

-- tag sizing (smaller)
local TAG_W, TAG_H = 144, 36
local TAG_OFFSET_Y = 3

local ORB_SIZE = 18
local ORB_OFFSET_Y = 3.35

-- delayed init so it never blocks other UI
local INIT_DELAY = 0.9

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local SosUsers = {}
local AkUsers = {}

-- Auto-reply tracking (do not spam)
local SentPrimaryForExecutedUserId = {}

local gui
local statsPopup
local statsPopupLabel

-- Bottom-left broadcast UI
local broadcastPanel
local broadcastSOS
local broadcastAK

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

local function getSosRole(plr)
	if not plr then return nil end

	if isOwner(plr) then
		return "Owner"
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
		if prof and prof.Color then
			return prof.Color
		end
	end
	if role == "Owner" then
		return ROLE_COLOR.Owner
	end
	return ROLE_COLOR[role]
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
	return "SOS User"
end

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

local function destroyTagGui(char, name)
	if not char then return end
	local old = char:FindFirstChild(name)
	if old then
		old:Destroy()
	end
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
		statsPopup.Visible = false
	end)
end

local function showPlayerStats(plr)
	ensureStatsPopup()
	if not statsPopup then return end

	local ageDays = plr.AccountAge or 0
	local role = getSosRole(plr)
	local roleLine = role and getTopLine(plr, role) or "No SOS role tag"
	local akLine = AkUsers[plr.UserId] and "AK: Yes" or "AK: No"

	local txt = ""
	txt = txt .. "User: " .. plr.Name .. "\n"
	txt = txt .. "UserId: " .. tostring(plr.UserId) .. "\n"
	txt = txt .. "AccountAge: " .. tostring(ageDays) .. " days\n\n"
	txt = txt .. "SOS Role: " .. roleLine .. "\n"
	txt = txt .. akLine .. "\n"

	statsPopupLabel.Text = txt
	statsPopup.Visible = true
end

local function createOwnerGlitch(label)
	if not label then return end

	local base = label.Text
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
	local rng = Random.new()

	task.spawn(function()
		while label and label.Parent do
			task.wait(rng:NextNumber(0.08, 0.14))

			if not label.Parent then break end
			if rng:NextNumber() < 0.55 then
				local outt = {}
				for i = 1, #base do
					if rng:NextNumber() < 0.22 then
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

			label.TextTransparency = (rng:NextNumber() < 0.12) and 0.15 or 0
		end
	end)
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

	if role == "Owner" then
		btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		btn.BackgroundTransparency = 0.12

		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 12)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
		})
		grad.Parent = btn

		makeStroke(btn, 2, Color3.fromRGB(0, 0, 0), 0.15)
	else
		btn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
		btn.BackgroundTransparency = 0.22

		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
		})
		grad.Parent = btn

		makeStroke(btn, 2, color, 0.05)
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
	top.Parent = btn

	if role == "Owner" then
		top.TextColor3 = Color3.fromRGB(255, 255, 80)
		makeStroke(top, 1, Color3.fromRGB(0, 0, 0), 0.35)
		createOwnerGlitch(top)
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

local function onSosSeen(userId)
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

local function maybeSendPrimaryForExecuted(uid)
	if typeof(uid) ~= "number" then return end
	if uid == LocalPlayer.UserId then return end
	if SentPrimaryForExecutedUserId[uid] then return end

	SentPrimaryForExecutedUserId[uid] = true
	trySendChat(SOS_MARKER_PRIMARY) -- send ¬
end

local function hookChatListeners()
	-- TextChatService listener
	if TextChatService and TextChatService.MessageReceived then
		TextChatService.MessageReceived:Connect(function(msg)
			if not msg then return end
			local text = msg.Text or ""
			local src = msg.TextSource
			if not src or not src.UserId then return end

			local uid = src.UserId

			-- Existing SOS markers (tag logic unchanged)
			if text == SOS_MARKER_PRIMARY or text == SOS_MARKER_JOINER then
				onSosSeen(uid)
				return
			end

			-- Existing AK markers (tag logic unchanged)
			if text == AK_MARKER_1 or text == AK_MARKER_2 then
				onAkSeen(uid)
				return
			end

			-- New: executed symbol triggers our ¬ reply (only for other people)
			if text == EXECUTED_SYMBOL then
				maybeSendPrimaryForExecuted(uid)
				return
			end
		end)
	end

	-- Player.Chatted fallback
	local function hookChatted(plr)
		pcall(function()
			plr.Chatted:Connect(function(message)
				if message == SOS_MARKER_PRIMARY or message == SOS_MARKER_JOINER then
					onSosSeen(plr.UserId)
				elseif message == AK_MARKER_1 or message == AK_MARKER_2 then
					onAkSeen(plr.UserId)
				elseif message == EXECUTED_SYMBOL then
					maybeSendPrimaryForExecuted(plr.UserId)
				end
			end)
		end)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookChatted(plr)
	end
	Players.PlayerAdded:Connect(hookChatted)
end

local function init()
	ensureStatsPopup()
	ensureBroadcastPanel()

	-- Wire broadcast buttons (UI only)
	if broadcastSOS then
		broadcastSOS.MouseButton1Click:Connect(function()
			onSosSeen(LocalPlayer.UserId)
			trySendChat(SOS_MARKER_PRIMARY) -- ¬
		end)
	end

	if broadcastAK then
		broadcastAK.MouseButton1Click:Connect(function()
			onAkSeen(LocalPlayer.UserId)
			trySendChat(AK_MARKER_1) -- ؍؍؍
		end)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayer(plr)
	end
	Players.PlayerAdded:Connect(hookPlayer)

	hookChatListeners()

	-- Owners show immediately even without SOS marker
	for _, plr in ipairs(Players:GetPlayers()) do
		if isOwner(plr) then
			refreshAllTagsForPlayer(plr)
		end
	end

	-- Broadcast on startup (unchanged behavior: you broadcast your normal markers)
	onSosSeen(LocalPlayer.UserId)
	onAkSeen(LocalPlayer.UserId)
	trySendChat(SOS_MARKER_PRIMARY)
	trySendChat(AK_MARKER_1)
end

task.delay(INIT_DELAY, init)
