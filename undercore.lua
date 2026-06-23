-- Undercore - Custom Cheat Menu
-- Inject via executor

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Get UI parent
local function getUiParent()
	if gethui then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return player:WaitForChild("PlayerGui")
end
local uiParent = getUiParent()

local function protectGui(gui)
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
end

-- Colors
local BG = Color3.fromRGB(15, 15, 15)
local BG_DARK = Color3.fromRGB(22, 22, 22)
local BG_LIGHT = Color3.fromRGB(30, 30, 30)
local ACCENT = Color3.fromRGB(100, 150, 255)
local TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local TEXT_GRAY = Color3.fromRGB(150, 150, 150)
local GREEN = Color3.fromRGB(76, 175, 80)
local RED = Color3.fromRGB(220, 60, 60)

-- ===================
-- NOTIFICATION SYSTEM
-- ===================
local NOTIF_WIDTH = 300
local notifications = {}

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "UndercoreNotif"
notifGui.ResetOnSpawn = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.DisplayOrder = 100
notifGui.IgnoreGuiInset = true
protectGui(notifGui)
notifGui.Parent = uiParent

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, 0, 0, 50)
container.Size = UDim2.new(0, NOTIF_WIDTH, 1, -70)
container.BackgroundTransparency = 1
container.Parent = notifGui

local function recalcPositions()
	local y = 0
	for _, data in ipairs(notifications) do
		if not data.dismissed then
			TweenService:Create(data.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 0, 0, y) }):Play()
			y = y + data.height + 6
		end
	end
end

local function dismiss(data)
	if data.dismissed then return end
	data.dismissed = true
	local slideOut = TweenService:Create(data.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, data.frame.Position.Y.Offset), GroupTransparency = 1 })
	slideOut:Play()
	slideOut.Completed:Wait()
	data.frame:Destroy()
	for i, n in ipairs(notifications) do
		if n == data then table.remove(notifications, i) break end
	end
	recalcPositions()
end

local function notify(title, message, duration, color)
	duration = duration or 4
	color = color or ACCENT
	local y = 0
	for _, n in ipairs(notifications) do
		if not n.dismissed then y = y + n.height + 6 end
	end

	local card = Instance.new("CanvasGroup")
	card.Size = UDim2.new(0, NOTIF_WIDTH, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = BG
	card.GroupTransparency = 0
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, y)
	card.Parent = container

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = 5
	bar.Parent = card

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -3, 0, 0)
	content.Position = UDim2.new(0, 3, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = content

	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Vertical
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
	lay.Padding = UDim.new(0, 3)
	lay.Parent = content

	local status = Instance.new("TextLabel")
	status.Font = Enum.Font.GothamBold
	status.TextSize = 10
	status.TextColor3 = color
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 0)
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.Text = title:upper()
	status.Parent = content

	local msg = Instance.new("TextLabel")
	msg.Font = Enum.Font.Gotham
	msg.TextSize = 12
	msg.TextColor3 = TEXT_GRAY
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.BackgroundTransparency = 1
	msg.Size = UDim2.new(1, 0, 0, 0)
	msg.AutomaticSize = Enum.AutomaticSize.Y
	msg.TextWrapped = true
	msg.Text = message
	msg.Parent = content

	task.defer(function()
		task.wait()
		local height = card.AbsoluteSize.Y
		if height <= 0 then task.wait() height = card.AbsoluteSize.Y end
		local data = { frame = card, height = height, dismissed = false }
		table.insert(notifications, data)
		local slideIn = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, y) })
		slideIn:Play()
		slideIn.Completed:Wait()
		task.delay(duration, function() dismiss(data) end)
	end)
end

-- ===================
-- MAIN GUI
-- ===================
local gui = Instance.new("ScreenGui")
gui.Name = "Undercore"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 99
gui.IgnoreGuiInset = true
protectGui(gui)
gui.Parent = uiParent

local menuVisible = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 600, 0, 400)
mainFrame.BackgroundColor3 = BG
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = gui

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = BG_DARK
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleText = Instance.new("TextLabel")
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16
titleText.TextColor3 = TEXT_WHITE
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.Text = "Undercore"
titleText.Parent = titleBar

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(0, -15, 0.5, -3)
statusDot.BackgroundColor3 = GREEN
statusDot.BorderSizePixel = 0
statusDot.Parent = titleText

local closeBtn = Instance.new("TextButton")
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = TEXT_GRAY
closeBtn.Text = "X"
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -35, 0, 2)
closeBtn.Parent = titleBar

closeBtn.MouseButton1Click:Connect(function()
	menuVisible = false
	mainFrame.Visible = false
end)

-- Left navigation
local navFrame = Instance.new("Frame")
navFrame.Size = UDim2.new(0, 140, 1, -40)
navFrame.Position = UDim2.new(0, 0, 0, 40)
navFrame.BackgroundColor3 = BG_DARK
navFrame.BorderSizePixel = 0
navFrame.Parent = mainFrame

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 2)
navLayout.Parent = navFrame

local navPad = Instance.new("UIPadding")
navPad.PaddingTop = UDim.new(0, 10)
navPad.PaddingBottom = UDim.new(0, 10)
navPad.Parent = navFrame

-- Right content
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -140, 1, -40)
contentFrame.Position = UDim2.new(0, 140, 0, 40)
contentFrame.BackgroundColor3 = BG
contentFrame.BorderSizePixel = 0
contentFrame.Parent = mainFrame

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 15)
contentPad.PaddingBottom = UDim.new(0, 15)
contentPad.PaddingLeft = UDim.new(0, 15)
contentPad.PaddingRight = UDim.new(0, 15)
contentPad.Parent = contentFrame

-- Pages
local pages = {}
local navButtons = {}

local function createNavButton(name, iconName)
	local btn = Instance.new("TextButton")
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextColor3 = TEXT_GRAY
	btn.Text = name
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BackgroundColor3 = BG_DARK
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.Parent = navFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 15)
	pad.Parent = btn

	return btn
end

local function createPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = BG_LIGHT
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Visible = false
	page.Parent = contentFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = page

	pages[name] = page
	return page
end

local function showPage(name)
	for pageName, page in pairs(pages) do
		page.Visible = (pageName == name)
	end
	for btnName, btn in pairs(navButtons) do
		if btnName == name then
			btn.TextColor3 = TEXT_WHITE
			btn.BackgroundColor3 = BG_LIGHT
		else
			btn.TextColor3 = TEXT_GRAY
			btn.BackgroundColor3 = BG_DARK
		end
	end
end

-- UI helpers
local function createToggle(parent, text, callback)
	local enabled = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 35)
	frame.BackgroundColor3 = BG_LIGHT
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TEXT_WHITE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -60, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.Text = text
	label.Parent = frame

	local toggle = Instance.new("TextButton")
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 11
	toggle.TextColor3 = TEXT_WHITE
	toggle.Text = "OFF"
	toggle.BackgroundColor3 = RED
	toggle.BorderSizePixel = 0
	toggle.Size = UDim2.new(0, 40, 0, 20)
	toggle.Position = UDim2.new(1, -50, 0.5, -10)
	toggle.Parent = frame

	toggle.MouseButton1Click:Connect(function()
		enabled = not enabled
		if enabled then
			toggle.Text = "ON"
			toggle.BackgroundColor3 = GREEN
		else
			toggle.Text = "OFF"
			toggle.BackgroundColor3 = RED
		end
		if callback then callback(enabled) end
	end)

	return { frame = frame, get = function() return enabled end, set = function(v) enabled = v toggle.Text = v and "ON" or "OFF" toggle.BackgroundColor3 = v and GREEN or RED end }
end

local function createSlider(parent, text, min, max, default, callback)
	local value = default

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 50)
	frame.BackgroundColor3 = BG_LIGHT
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TEXT_WHITE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.new(0, 12, 0, 5)
	label.Text = text .. ": " .. tostring(default)
	label.Parent = frame

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -24, 0, 6)
	sliderBg.Position = UDim2.new(0, 12, 0, 32)
	sliderBg.BackgroundColor3 = BG_DARK
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = frame

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = ACCENT
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg

	local dragging = false
	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			value = math.floor(min + rel * (max - min))
			sliderFill.Size = UDim2.new(rel, 0, 1, 0)
			label.Text = text .. ": " .. tostring(value)
			if callback then callback(value) end
		end
	end)

	return { frame = frame, get = function() return value end }
end

local function createLabel(parent, text)
	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = ACCENT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 25)
	label.Text = text
	label.Parent = parent
	return label
end

-- ===================
-- PAGES
-- ===================

-- MOVEMENT
local movementPage = createPage("Movement")
local navMovement = createNavButton("Movement")
navButtons["Movement"] = navMovement
navMovement.MouseButton1Click:Connect(function() showPage("Movement") end)

createLabel(movementPage, "Movement")
local flyToggle = createToggle(movementPage, "Fly", function(v) _G.Undercore.Fly = v end)
local flySpeed = createSlider(movementPage, "Fly Speed", 10, 200, 50, function(v) _G.Undercore.FlySpeed = v end)
local speedToggle = createToggle(movementPage, "Speed", function(v) _G.Undercore.Speed = v end)
local speedVal = createSlider(movementPage, "Walk Speed", 16, 200, 50, function(v) _G.Undercore.SpeedVal = v end)
local jumpToggle = createToggle(movementPage, "Jump Power", function(v) _G.Undercore.Jump = v end)
local jumpVal = createSlider(movementPage, "Jump Power", 50, 300, 100, function(v) _G.Undercore.JumpVal = v end)
local noclipToggle = createToggle(movementPage, "Noclip", function(v) _G.Undercore.Noclip = v end)

-- COMBAT
local combatPage = createPage("Combat")
local navCombat = createNavButton("Combat")
navButtons["Combat"] = navCombat
navCombat.MouseButton1Click:Connect(function() showPage("Combat") end)

createLabel(combatPage, "Combat")
local flingToggle = createToggle(combatPage, "Fling Aura", function(v) _G.Undercore.Fling = v end)
local flingPower = createSlider(combatPage, "Fling Power", 100, 5000, 1000, function(v) _G.Undercore.FlingPower = v end)
local flingRange = createSlider(combatPage, "Fling Range", 5, 50, 15, function(v) _G.Undercore.FlingRange = v end)

-- VISUAL
local visualPage = createPage("Visuals")
local navVisual = createNavButton("Visuals")
navButtons["Visuals"] = navVisual
navVisual.MouseButton1Click:Connect(function() showPage("Visuals") end)

createLabel(visualPage, "ESP")
local espToggle = createToggle(visualPage, "ESP Box", function(v) _G.Undercore.ESP = v end)
local espName = createToggle(visualPage, "ESP Names", function(v) _G.Undercore.ESPName = v end)
local espDist = createToggle(visualPage, "ESP Distance", function(v) _G.Undercore.ESPDist = v end)
local espHealth = createToggle(visualPage, "ESP Health", function(v) _G.Undercore.ESPHealth = v end)
local espTracer = createToggle(visualPage, "ESP Tracers", function(v) _G.Undercore.ESPTracer = v end)

-- PLAYER
local playerPage = createPage("Player")
local navPlayer = createNavButton("Player")
navButtons["Player"] = navPlayer
navPlayer.MouseButton1Click:Connect(function() showPage("Player") end)

createLabel(playerPage, "Player")
local infJump = createToggle(playerPage, "Infinite Jump", function(v) _G.Undercore.InfJump = v end)
local godMode = createToggle(playerPage, "God Mode", function(v) _G.Undercore.GodMode = v end)
local resetBtn = createToggle(playerPage, "Reset Character (click)", function(v)
	if v then
		local char = player.Character
		if char then char:BreakJoints() end
		task.wait(0.5)
		_G.Undercore.GodMode = false
	end
end)

-- SETTINGS
local settingsPage = createPage("Settings")
local navSettings = createNavButton("Settings")
navButtons["Settings"] = navSettings
navSettings.MouseButton1Click:Connect(function() showPage("Settings") end)

createLabel(settingsPage, "Settings")
createLabel(settingsPage, "Toggle Key: RightShift / K / F8")
local testNotif = createToggle(settingsPage, "Test Notification", function(v)
	if v then
		notify("Undercore", "Test notification works!", 3, ACCENT)
		task.wait(1)
	end
end)

-- Default page
showPage("Movement")

-- ===================
-- TOGGLE BUTTON
-- ===================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Text = "U"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.TextColor3 = TEXT_WHITE
toggleBtn.BackgroundColor3 = BG_DARK
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.new(0, 32, 0, 32)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.ZIndex = 50
toggleBtn.Parent = gui

toggleBtn.MouseButton1Click:Connect(function()
	menuVisible = not menuVisible
	mainFrame.Visible = menuVisible
end)

-- Keys
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.RightShift
		or input.KeyCode == Enum.KeyCode.K
		or input.KeyCode == Enum.KeyCode.F8
	then
		menuVisible = not menuVisible
		mainFrame.Visible = menuVisible
	end
end)

-- Dragging
local dragging = false
local dragInput
local dragStart
local startPos

mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if input.Position.Y < mainFrame.AbsolutePosition.Y + 40 then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end
end)

mainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- ===================
-- FEATURES
-- ===================
_G.Undercore = {
	Fly = false, FlySpeed = 50,
	Speed = false, SpeedVal = 50,
	Jump = false, JumpVal = 100,
	Noclip = false,
	Fling = false, FlingPower = 1000, FlingRange = 15,
	ESP = false, ESPName = false, ESPDist = false, ESPHealth = false, ESPTracer = false,
	InfJump = false, GodMode = false,
}

-- FLY
local flyConn
local flyBodyVelocity
local flyBodyGyro

local function setupFly()
	RunService.RenderStepped:Connect(function()
		if not _G.Undercore.Fly then
			if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
			if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
			return
		end

		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then return end

		if not flyBodyVelocity then
			flyBodyVelocity = Instance.new("BodyVelocity")
			flyBodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 1e5
			flyBodyVelocity.Velocity = Vector3.zero
			flyBodyVelocity.Parent = root

			flyBodyGyro = Instance.new("BodyGyro")
			flyBodyGyro.MaxForce = Vector3.new(1, 1, 1) * 1e5
			flyBodyGyro.P = 1e4
			flyBodyGyro.Parent = root
		end

		local cam = Workspace.CurrentCamera
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

		if dir.Magnitude > 0 then
			dir = dir.Unit * _G.Undercore.FlySpeed
		end

		flyBodyVelocity.Velocity = dir
		flyBodyGyro.CFrame = cam.CFrame
		hum.PlatformStand = true
	end)
end
setupFly()

-- SPEED & JUMP
RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if _G.Undercore.Speed then
		hum.WalkSpeed = _G.Undercore.SpeedVal
	else
		if hum.WalkSpeed ~= 16 and not _G.Undercore.Fly then
			hum.WalkSpeed = 16
		end
	end

	if _G.Undercore.Jump then
		hum.JumpPower = _G.Undercore.JumpVal
		hum.UseJumpPower = true
	else
		if hum.JumpPower ~= 50 then
			hum.JumpPower = 50
		end
	end

	if _G.Undercore.GodMode then
		hum.MaxHealth = math.huge
		hum.Health = math.huge
	end
end)

-- NOCLIP
RunService.Stepped:Connect(function()
	if not _G.Undercore.Noclip then return end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

-- INFINITE JUMP
UserInputService.JumpRequest:Connect(function()
	if _G.Undercore.InfJump then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end)

-- FLING AURA
RunService.RenderStepped:Connect(function()
	if not _G.Undercore.Fling then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
			if otherRoot and otherHum and otherHum.Health > 0 then
				local dist = (otherRoot.Position - root.Position).Magnitude
				if dist <= _G.Undercore.FlingRange then
					otherRoot.Velocity = (otherRoot.Position - root.Position).Unit * _G.Undercore.FlingPower + Vector3.new(0, _G.Undercore.FlingPower * 0.3, 0)
					otherRoot.AngularVelocity = Vector3.new(math.random(-50, 50), math.random(-50, 50), math.random(-50, 50))
				end
			end
		end
	end
end)

-- ESP
local espObjects = {}

local function clearESP()
	for _, obj in pairs(espObjects) do
		if obj.box then obj.box:Remove() end
		if obj.name then obj.name:Remove() end
		if obj.dist then obj.dist:Remove() end
		if obj.health then obj.health:Remove() end
		if obj.tracer then obj.tracer:Remove() end
	end
	espObjects = {}
end

local function createESPForPlayer(p)
	if p == player then return end
	local box = Drawing.new("Quad")
	box.Thickness = 1
	box.Filled = false
	box.Color = ACCENT
	box.Visible = false

	local nameLbl = Drawing.new("Text")
	nameLbl.Size = 13
	nameLbl.Center = true
	nameLbl.Color = TEXT_WHITE
	nameLbl.Visible = false

	local distLbl = Drawing.new("Text")
	distLbl.Size = 12
	distLbl.Center = true
	distLbl.Color = TEXT_GRAY
	distLbl.Visible = false

	local healthBar = Drawing.new("Line")
	healthBar.Thickness = 2
	healthBar.Color = GREEN
	healthBar.Visible = false

	local tracer = Drawing.new("Line")
	tracer.Thickness = 1
	tracer.Color = ACCENT
	tracer.Visible = false

	espObjects[p] = { box = box, name = nameLbl, dist = distLbl, health = healthBar, tracer = tracer }
end

local function removeESPForPlayer(p)
	local obj = espObjects[p]
	if obj then
		if obj.box then obj.box:Remove() end
		if obj.name then obj.name:Remove() end
		if obj.dist then obj.dist:Remove() end
		if obj.health then obj.health:Remove() end
		if obj.tracer then obj.tracer:Remove() end
		espObjects[p] = nil
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	createESPForPlayer(p)
end
Players.PlayerAdded:Connect(createESPForPlayer)
Players.PlayerRemoving:Connect(removeESPForPlayer)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")

	for p, obj in pairs(espObjects) do
		if not _G.Undercore.ESP then
			obj.box.Visible = false
			obj.name.Visible = false
			obj.dist.Visible = false
			obj.health.Visible = false
			obj.tracer.Visible = false
			continue
		end

		local pChar = p.Character
		local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
		local pHead = pChar and pChar:FindFirstChild("Head")
		local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")

		if not pRoot or not pHead or not pHum or pHum.Health <= 0 then
			obj.box.Visible = false
			obj.name.Visible = false
			obj.dist.Visible = false
			obj.health.Visible = false
			obj.tracer.Visible = false
			continue
		end

		local pos, onScreen = camera:WorldToViewportPoint(pRoot.Position)
		if not onScreen then
			obj.box.Visible = false
			obj.name.Visible = false
			obj.dist.Visible = false
			obj.health.Visible = false
			obj.tracer.Visible = false
			continue
		end

		local headPos = camera:WorldToViewportPoint(pHead.Position + Vector3.new(0, 1, 0))
		local legPos = camera:WorldToViewportPoint(pRoot.Position - Vector3.new(0, 3, 0))
		local height = math.abs(headPos.Y - legPos.Y)
		local width = height * 0.5

		local topLeft = Vector2.new(pos.X - width / 2, headPos.Y)
		local topRight = Vector2.new(pos.X + width / 2, headPos.Y)
		local botLeft = Vector2.new(pos.X - width / 2, legPos.Y)
		local botRight = Vector2.new(pos.X + width / 2, legPos.Y)

		obj.box.PointA = topLeft
		obj.box.PointB = topRight
		obj.box.PointC = botRight
		obj.box.PointD = botLeft
		obj.box.Visible = true

		if _G.Undercore.ESPName then
			obj.name.Position = Vector2.new(pos.X, headPos.Y - 16)
			obj.name.Text = p.Name
			obj.name.Visible = true
		else
			obj.name.Visible = false
		end

		if _G.Undercore.ESPDist and root then
			local dist = math.floor((pRoot.Position - root.Position).Magnitude)
			obj.dist.Position = Vector2.new(pos.X, legPos.Y + 2)
			obj.dist.Text = tostring(dist) .. "m"
			obj.dist.Visible = true
		else
			obj.dist.Visible = false
		end

		if _G.Undercore.ESPHealth then
			local healthPct = pHum.Health / pHum.MaxHealth
			obj.health.From = Vector2.new(topLeft.X - 5, topLeft.Y)
			obj.health.To = Vector2.new(topLeft.X - 5, topLeft.Y + height * (1 - healthPct))
			obj.health.Color = healthPct > 0.5 and GREEN or RED
			obj.health.Visible = true
		else
			obj.health.Visible = false
		end

		if _G.Undercore.ESPTracer then
			obj.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
			obj.tracer.To = Vector2.new(pos.X, pos.Y)
			obj.tracer.Visible = true
		else
			obj.tracer.Visible = false
		end
	end
end)

-- ===================
-- INJECTION NOTIFICATION
-- ===================
task.wait(0.5)
notify("Undercore", "Script injected successfully", 4, GREEN)

-- Expose
_G.UndercoreNotify = notify
