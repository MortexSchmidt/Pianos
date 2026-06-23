-- Undercore - Custom Cheat Menu
-- Inject via executor

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local connections = {}
_G.UndercoreConnections = connections

local function trackConn(conn)
	table.insert(connections, conn)
	return conn
end

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

-- Sound IDs
local SOUND_INJECT = "124834506603771"
local SOUND_NOTIF = "131268007007000"
local SOUND_ERROR = "18999173729"
local SOUND_CLICK = "83465157817014"
local SOUND_HOVER = "72243701593463"
local SOUND_PAGE = { "105197111717033", "85298254384092", "114157584505971" }

local function playSound(soundId, loudness)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Parent = player.Character or player
	sound.Volume = loudness or 0.5
	sound:Play()
end

local function playRandomPageSound()
	local idx = math.random(1, #SOUND_PAGE)
	playSound(SOUND_PAGE[idx], 0.3)
end

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

	local card = data.frame
	local overlay = data.overlay

	overlay.Visible = true
	overlay.Size = UDim2.new(0, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)

	local sweepOut = TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepOut:Play()
	sweepOut.Completed:Wait()

	local slideOut = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, card.Position.Y.Offset), GroupTransparency = 1 })
	slideOut:Play()
	slideOut.Completed:Wait()
	card:Destroy()
	for i, n in ipairs(notifications) do
		if n == data then table.remove(notifications, i) break end
	end
	recalcPositions()
end

-- Notification icons
local NOTIF_ICONS = {
	info = "rbxassetid://773391098118939",
	error = "rbxassetid://773391094262923",
	success = "rbxassetid://773391086914667",
}

local function notify(title, message, duration, color, notifType)
	duration = duration or 4
	color = color or ACCENT
	notifType = notifType or "info"
	if notifType == "error" then
		playSound(SOUND_ERROR, 0.5)
	else
		playSound(SOUND_NOTIF, 0.5)
	end
	local iconId = NOTIF_ICONS[notifType] or NOTIF_ICONS.info
	local iconColor = notifType == "error" and RED or color

	local y = 0
	for _, n in ipairs(notifications) do
		if not n.dismissed then y = y + n.height + 6 end
	end

	local card = Instance.new("CanvasGroup")
	card.Size = UDim2.new(0, NOTIF_WIDTH, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = BG
	card.GroupColor3 = Color3.fromRGB(255, 255, 255)
	card.GroupTransparency = 0
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, y)
	card.Parent = container

	-- Green/accent strip (leftmost)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = 5
	bar.Parent = card

	-- Icon (right of strip)
	local iconArea = Instance.new("Frame")
	iconArea.Name = "IconArea"
	iconArea.Size = UDim2.new(0, 56, 0, 0)
	iconArea.Position = UDim2.new(0, 3, 0, 0)
	iconArea.AutomaticSize = Enum.AutomaticSize.Y
	iconArea.BackgroundTransparency = 1
	iconArea.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Name = "NotifIcon"
	icon.Size = UDim2.new(0, 36, 0, 36)
	icon.Position = UDim2.new(0, 10, 0, 14)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 6
	icon.Parent = iconArea

	-- Content (right of icon)
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -62, 0, 0)
	content.Position = UDim2.new(0, 62, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = content

	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Vertical
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
	lay.Padding = UDim.new(0, 4)
	lay.Parent = content

	local status = Instance.new("TextLabel")
	status.Font = Enum.Font.GothamBold
	status.TextSize = 10
	status.TextColor3 = color
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, 0, 0, 0)
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.Text = title:upper()
	status.Parent = content

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = TEXT_WHITE
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.TextWrapped = true
	titleLabel.Text = title
	titleLabel.Parent = content

	local msg = Instance.new("TextLabel")
	msg.Font = Enum.Font.Gotham
	msg.TextSize = 12
	msg.TextColor3 = TEXT_GRAY
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Top
	msg.BackgroundTransparency = 1
	msg.Size = UDim2.new(1, 0, 0, 0)
	msg.AutomaticSize = Enum.AutomaticSize.Y
	msg.TextWrapped = true
	msg.Text = message
	msg.Parent = content

	-- NVIDIA sweep overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "AccentOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = color
	overlay.BorderSizePixel = 0
	overlay.Visible = true
	overlay.ZIndex = 10
	overlay.Parent = card

	task.defer(function()
		task.wait()
		local height = card.AbsoluteSize.Y
		if height <= 0 then task.wait() height = card.AbsoluteSize.Y end
		local data = { frame = card, height = height, dismissed = false, overlay = overlay }
		table.insert(notifications, data)

		local slideIn = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, y) })
		slideIn:Play()
		slideIn.Completed:Wait()

		local collapse = TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 3, 1, 0) })
		collapse:Play()
		collapse.Completed:Wait()
		overlay.Visible = false

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
local openMenu, closeMenu

local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 600, 0, 400)
mainFrame.BackgroundColor3 = BG
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = false
mainFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Parent = gui

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = BG_DARK
titleBar.BorderSizePixel = 0
titleBar.Active = true
-- Dragging
local dragging = false
local dragInput
local dragStart
local startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

titleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

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
titleText.Text = "  Undercore"
titleText.Parent = titleBar

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
	closeMenu()
end)

closeBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.2)
end)

-- Left navigation
local navFrame = Instance.new("Frame")
navFrame.Size = UDim2.new(0, 140, 1, -40)
navFrame.Position = UDim2.new(0, 0, 0, 40)
navFrame.BackgroundColor3 = BG_DARK
navFrame.BorderSizePixel = 0
navFrame.Active = false
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
contentFrame.Active = false
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

local NAV_ICONS = {
	["Movement"] = "rbxassetid://773391098118939",
	["Combat"] = "rbxassetid://773391094262923",
	["Visuals"] = "rbxassetid://773391086914667",
	["Player"] = "rbxassetid://773391090508219",
	["Settings"] = "rbxassetid://773391102756043",
}

local function createNavButton(name)
	local btn = Instance.new("TextButton")
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextColor3 = TEXT_GRAY
	btn.Text = ""
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BackgroundColor3 = BG_DARK
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Parent = navFrame

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.Position = UDim2.new(0, 12, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Image = NAV_ICONS[name] or ""
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	icon.Parent = btn

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TEXT_GRAY
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -48, 0, 40)
	label.Position = UDim2.new(0, 44, 0, 0)
	label.Text = name
	label.ZIndex = 2
	label.Parent = btn

	btn.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 0.15)
	end)

	return btn, icon, label
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

local currentPage = nil
local pageSwitching = false

-- Global green indicator strip on mainFrame left edge (outside navFrame to avoid UIListLayout)
local navIndicator = Instance.new("Frame")
navIndicator.Name = "NavIndicator"
navIndicator.Size = UDim2.new(0, 3, 0, 40)
navIndicator.Position = UDim2.new(0, 0, 0, 50)
navIndicator.BackgroundColor3 = GREEN
navIndicator.BorderSizePixel = 0
navIndicator.ZIndex = 20
navIndicator.Visible = false
navIndicator.Parent = mainFrame

local function showPage(name)
	if currentPage == name then return end
	if pageSwitching then return end
	pageSwitching = true
	playRandomPageSound()

	-- Deactivate old button
	if currentPage and navButtons[currentPage] then
		local oldData = navButtons[currentPage]
		oldData.btn.TextColor3 = TEXT_GRAY
		oldData.btn.BackgroundColor3 = BG_DARK
		oldData.icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		oldData.label.TextColor3 = TEXT_GRAY
	end

	-- Page content sweep
	local sweepOverlay = Instance.new("Frame")
	sweepOverlay.Size = UDim2.new(0, 0, 1, 0)
	sweepOverlay.Position = UDim2.new(0, 0, 0, 0)
	sweepOverlay.BackgroundColor3 = GREEN
	sweepOverlay.BorderSizePixel = 0
	sweepOverlay.ZIndex = 50
	sweepOverlay.Parent = contentFrame

	local sweepIn = TweenService:Create(sweepOverlay, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepIn:Play()
	sweepIn.Completed:Wait()

	for pageName, page in pairs(pages) do
		page.Visible = (pageName == name)
	end

	-- Activate new button
	local newData = navButtons[name]
	if newData then
		newData.btn.TextColor3 = TEXT_WHITE
		newData.btn.BackgroundColor3 = BG_LIGHT
		newData.icon.ImageColor3 = GREEN
		newData.label.TextColor3 = TEXT_WHITE
	end

	-- Move indicator strip to active button position
	local btn = newData and newData.btn
	if btn then
		local targetY = btn.AbsolutePosition.Y - mainFrame.AbsolutePosition.Y
		local targetH = btn.AbsoluteSize.Y

		navIndicator.Visible = true
		navIndicator.Size = UDim2.new(0, 0, 0, targetH)
		navIndicator.Position = UDim2.new(0, 0, 0, targetY)

		local indicatorTween = TweenService:Create(navIndicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 3, 0, targetH) })
		indicatorTween:Play()
	end

	local sweepOut = TweenService:Create(sweepOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
	sweepOut:Play()
	sweepOut.Completed:Wait()
	sweepOverlay:Destroy()

	currentPage = name
	pageSwitching = false
end

-- UI helpers
local function createToggle(parent, text, callback)
	local enabled = false
	local toggling = false

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

	-- Toggle switch background
	local switchBg = Instance.new("TextButton")
	switchBg.Text = ""
	switchBg.BackgroundColor3 = BG_DARK
	switchBg.BorderSizePixel = 0
	switchBg.Size = UDim2.new(0, 40, 0, 20)
	switchBg.Position = UDim2.new(1, -50, 0.5, -10)
	switchBg.AutoButtonColor = false
	switchBg.Parent = frame

	-- Green fill (grows when ON)
	local switchFill = Instance.new("Frame")
	switchFill.Size = UDim2.new(0, 0, 1, 0)
	switchFill.BackgroundColor3 = GREEN
	switchFill.BorderSizePixel = 0
	switchFill.ZIndex = 2
	switchFill.Parent = switchBg

	-- White circle knob
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 2, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = switchBg

	local function updateVisual()
		if enabled then
			local fillTween = TweenService:Create(switchFill, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
			fillTween:Play()
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(1, -18, 0.5, -8) })
			knobTween:Play()
		else
			local fillTween = TweenService:Create(switchFill, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0) })
			fillTween:Play()
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0, 2, 0.5, -8) })
			knobTween:Play()
		end
	end

	local function doToggle()
		if toggling then return end
		toggling = true
		playRandomPageSound()
		enabled = not enabled
		updateVisual()
		if callback then callback(enabled) end
		task.wait(0.25)
		toggling = false
	end

	switchBg.MouseButton1Click:Connect(doToggle)

	frame.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 0.15)
	end)

	return { frame = frame, get = function() return enabled end, set = function(v) enabled = v updateVisual() end }
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
	trackConn(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			value = math.floor(min + rel * (max - min))
			sliderFill.Size = UDim2.new(rel, 0, 1, 0)
			label.Text = text .. ": " .. tostring(value)
			if callback then callback(value) end
		end
	end))

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
local navMovement, navMovementIcon, navMovementLabel = createNavButton("Movement")
navButtons["Movement"] = { btn = navMovement, icon = navMovementIcon, label = navMovementLabel }
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
local navCombat, navCombatIcon, navCombatLabel = createNavButton("Combat")
navButtons["Combat"] = { btn = navCombat, icon = navCombatIcon, label = navCombatLabel }
navCombat.MouseButton1Click:Connect(function() showPage("Combat") end)

createLabel(combatPage, "Combat")
local flingToggle = createToggle(combatPage, "Fling Aura", function(v) _G.Undercore.Fling = v end)
local flingPower = createSlider(combatPage, "Fling Power", 100, 5000, 1000, function(v) _G.Undercore.FlingPower = v end)
local flingRange = createSlider(combatPage, "Fling Range", 5, 50, 15, function(v) _G.Undercore.FlingRange = v end)

-- VISUAL
local visualPage = createPage("Visuals")
local navVisual, navVisualIcon, navVisualLabel = createNavButton("Visuals")
navButtons["Visuals"] = { btn = navVisual, icon = navVisualIcon, label = navVisualLabel }
navVisual.MouseButton1Click:Connect(function() showPage("Visuals") end)

createLabel(visualPage, "ESP")
local espToggle = createToggle(visualPage, "ESP Box", function(v) _G.Undercore.ESP = v end)
local espName = createToggle(visualPage, "ESP Names", function(v) _G.Undercore.ESPName = v end)
local espDist = createToggle(visualPage, "ESP Distance", function(v) _G.Undercore.ESPDist = v end)
local espHealth = createToggle(visualPage, "ESP Health", function(v) _G.Undercore.ESPHealth = v end)
local espTracer = createToggle(visualPage, "ESP Tracers", function(v) _G.Undercore.ESPTracer = v end)

-- PLAYER
local playerPage = createPage("Player")
local navPlayer, navPlayerIcon, navPlayerLabel = createNavButton("Player")
navButtons["Player"] = { btn = navPlayer, icon = navPlayerIcon, label = navPlayerLabel }
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

-- ===================
-- HARD EXIT DIALOG
-- ===================
local exitDialogGui = Instance.new("ScreenGui")
exitDialogGui.Name = "UndercoreExit"
exitDialogGui.ResetOnSpawn = false
exitDialogGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
exitDialogGui.DisplayOrder = 200
exitDialogGui.IgnoreGuiInset = true
protectGui(exitDialogGui)
exitDialogGui.Parent = uiParent

local blurFrame = Instance.new("TextButton")
blurFrame.Text = ""
blurFrame.Size = UDim2.new(1, 0, 1, 0)
blurFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blurFrame.BackgroundTransparency = 1
blurFrame.BorderSizePixel = 0
blurFrame.Visible = false
blurFrame.AutoButtonColor = false
blurFrame.Active = true
blurFrame.Modal = true
blurFrame.Parent = exitDialogGui

local blurEffect = Instance.new("BlurEffect")
blurEffect.Size = 0
blurEffect.Name = "UndercoreExitBlur"
blurEffect.Parent = game:GetService("Lighting")

local dialogFrame = Instance.new("CanvasGroup")
dialogFrame.AnchorPoint = Vector2.new(0.5, 0.5)
dialogFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
dialogFrame.Size = UDim2.new(0, 380, 0, 220)
dialogFrame.BackgroundColor3 = BG
dialogFrame.BorderSizePixel = 0
dialogFrame.Visible = false
dialogFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
dialogFrame.GroupTransparency = 1
dialogFrame.ZIndex = 10
dialogFrame.Parent = blurFrame

local dialogTitle = Instance.new("TextLabel")
dialogTitle.Font = Enum.Font.GothamBold
dialogTitle.TextSize = 16
dialogTitle.TextColor3 = TEXT_WHITE
dialogTitle.TextXAlignment = Enum.TextXAlignment.Center
dialogTitle.TextYAlignment = Enum.TextYAlignment.Center
dialogTitle.BackgroundTransparency = 1
dialogTitle.Size = UDim2.new(1, 0, 0, 40)
dialogTitle.Position = UDim2.new(0, 0, 0, 15)
dialogTitle.Text = "Undercore"
dialogTitle.Parent = dialogFrame

local dialogMsg = Instance.new("TextLabel")
dialogMsg.Font = Enum.Font.Gotham
dialogMsg.TextSize = 13
dialogMsg.TextColor3 = TEXT_GRAY
dialogMsg.TextXAlignment = Enum.TextXAlignment.Center
dialogMsg.TextYAlignment = Enum.TextYAlignment.Top
dialogMsg.BackgroundTransparency = 1
dialogMsg.Size = UDim2.new(1, -40, 0, 30)
dialogMsg.Position = UDim2.new(0, 20, 0, 55)
dialogMsg.TextWrapped = true
dialogMsg.Text = "Select an action:"
dialogMsg.Parent = dialogFrame

local cancelBtn = Instance.new("TextButton")
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 13
cancelBtn.TextColor3 = TEXT_WHITE
cancelBtn.Text = "Cancel"
cancelBtn.BackgroundColor3 = BG_LIGHT
cancelBtn.BorderSizePixel = 0
cancelBtn.Size = UDim2.new(0, 100, 0, 36)
cancelBtn.Position = UDim2.new(0, 20, 0, 145)
cancelBtn.Parent = dialogFrame

local reloadBtn = Instance.new("TextButton")
reloadBtn.Font = Enum.Font.GothamBold
reloadBtn.TextSize = 13
reloadBtn.TextColor3 = TEXT_WHITE
reloadBtn.Text = "Reload"
reloadBtn.BackgroundColor3 = ACCENT
reloadBtn.BorderSizePixel = 0
reloadBtn.Size = UDim2.new(0, 100, 0, 36)
reloadBtn.Position = UDim2.new(0.5, -50, 0, 145)
reloadBtn.Parent = dialogFrame

local confirmBtn = Instance.new("TextButton")
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.TextSize = 13
confirmBtn.TextColor3 = TEXT_WHITE
confirmBtn.Text = "Terminate"
confirmBtn.BackgroundColor3 = RED
confirmBtn.BorderSizePixel = 0
confirmBtn.Size = UDim2.new(0, 100, 0, 36)
confirmBtn.Position = UDim2.new(1, -120, 0, 145)
confirmBtn.Parent = dialogFrame

-- Info text below buttons
local infoIcon = Instance.new("ImageLabel")
infoIcon.Size = UDim2.new(0, 14, 0, 14)
infoIcon.Position = UDim2.new(0, 30, 0, 190)
infoIcon.BackgroundTransparency = 1
infoIcon.Image = "rbxassetid://773391098118939"
infoIcon.ImageColor3 = ACCENT
infoIcon.ScaleType = Enum.ScaleType.Fit
infoIcon.ZIndex = 11
infoIcon.Parent = dialogFrame

local infoText = Instance.new("TextLabel")
infoText.Font = Enum.Font.Gotham
infoText.TextSize = 11
infoText.TextColor3 = TEXT_GRAY
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Center
infoText.BackgroundTransparency = 1
infoText.Size = UDim2.new(1, -60, 0, 20)
infoText.Position = UDim2.new(0, 48, 0, 187)
infoText.Text = "All actions except Cancel will reset your character"
infoText.ZIndex = 11
infoText.Parent = dialogFrame

-- Tooltip helper for dialog buttons
local function createTooltip(btn, text)
	local tooltip = Instance.new("Frame")
	tooltip.Size = UDim2.new(0, 220, 0, 0)
	tooltip.BackgroundColor3 = BG_DARK
	tooltip.BorderSizePixel = 0
	tooltip.Visible = false
	tooltip.ZIndex = 100
	tooltip.Parent = exitDialogGui

	local infoIcon = Instance.new("ImageLabel")
	infoIcon.Size = UDim2.new(0, 16, 0, 16)
	infoIcon.Position = UDim2.new(0, 8, 0, 6)
	infoIcon.BackgroundTransparency = 1
	infoIcon.Image = "rbxassetid://773391098118939"
	infoIcon.ImageColor3 = ACCENT
	infoIcon.ScaleType = Enum.ScaleType.Fit
	infoIcon.ZIndex = 101
	infoIcon.Parent = tooltip

	local tooltipText = Instance.new("TextLabel")
	tooltipText.Font = Enum.Font.Gotham
	tooltipText.TextSize = 11
	tooltipText.TextColor3 = TEXT_WHITE
	tooltipText.TextXAlignment = Enum.TextXAlignment.Left
	tooltipText.TextYAlignment = Enum.TextYAlignment.Center
	tooltipText.BackgroundTransparency = 1
	tooltipText.Size = UDim2.new(1, -32, 1, 0)
	tooltipText.Position = UDim2.new(0, 30, 0, 0)
	tooltipText.Text = text
	tooltipText.ZIndex = 101
	tooltipText.Parent = tooltip

	local function hideTooltip()
		tooltip.Visible = false
		tooltip.Size = UDim2.new(0, 220, 0, 0)
	end

	btn.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 0.15)
		local btnPos = btn.AbsolutePosition
		local btnSize = btn.AbsoluteSize
		tooltip.Visible = true
		tooltip.Size = UDim2.new(0, 220, 0, 0)
		tooltip.Position = UDim2.new(0, btnPos.X + btnSize.X / 2 - 110, 0, btnPos.Y - 2)
		local tween = TweenService:Create(tooltip, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 220, 0, 28), Position = UDim2.new(0, btnPos.X + btnSize.X / 2 - 110, 0, btnPos.Y - 30) })
		tween:Play()
	end)

	btn.MouseLeave:Connect(function()
		hideTooltip()
	end)

	btn.MouseButton1Click:Connect(function()
		hideTooltip()
	end)
end

createTooltip(cancelBtn, "Close this dialog without any changes")
createTooltip(reloadBtn, "Restart the script with update check")
createTooltip(confirmBtn, "Fully terminate and remove all features")

local exitDialogVisible = false

local function showExitDialog()
	if exitDialogVisible then return end
	exitDialogVisible = true
	playSound(SOUND_ERROR, 0.5)

	blurFrame.Visible = true
	blurFrame.BackgroundTransparency = 1
	dialogFrame.Visible = true
	dialogFrame.Size = UDim2.new(0, 0, 0, 0)
	dialogFrame.GroupTransparency = 1

	-- Green sweep overlay on dialog
	local dialogSweep = Instance.new("Frame")
	dialogSweep.Size = UDim2.new(1, 0, 1, 0)
	dialogSweep.BackgroundColor3 = GREEN
	dialogSweep.BorderSizePixel = 0
	dialogSweep.ZIndex = 20
	dialogSweep.Parent = dialogFrame

	local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 24 })
	blurTween:Play()

	local bgTween = TweenService:Create(blurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 })
	bgTween:Play()

	local dialogTween = TweenService:Create(dialogFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 380, 0, 220), GroupTransparency = 0 })
	dialogTween:Play()

	task.wait(0.15)

	local sweepOut = TweenService:Create(dialogSweep, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
	sweepOut:Play()
	sweepOut.Completed:Wait()
	dialogSweep:Destroy()
end

local function hideExitDialog()
	if not exitDialogVisible then return end
	exitDialogVisible = false
	playRandomPageSound()

	-- Green sweep in on dialog
	local dialogSweep = Instance.new("Frame")
	dialogSweep.Size = UDim2.new(0, 0, 1, 0)
	dialogSweep.Position = UDim2.new(0, 0, 0, 0)
	dialogSweep.BackgroundColor3 = GREEN
	dialogSweep.BorderSizePixel = 0
	dialogSweep.ZIndex = 20
	dialogSweep.Parent = dialogFrame

	local sweepIn = TweenService:Create(dialogSweep, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepIn:Play()
	sweepIn.Completed:Wait()

	local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 0 })
	blurTween:Play()

	local bgTween = TweenService:Create(blurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	bgTween:Play()

	local dialogTween = TweenService:Create(dialogFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 0), GroupTransparency = 1 })
	dialogTween:Play()

	dialogTween.Completed:Wait()
	blurFrame.Visible = false
	dialogFrame.Visible = false
	dialogSweep:Destroy()
end

local espObjects = {}

local function resetAllCheats()
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.JumpHeight = 7.2
			hum.MaxHealth = 100
			hum.Health = hum.MaxHealth
			hum.PlatformStand = false
		end
		-- Restore collisions
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
		-- Remove fly body objects
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
				obj:Destroy()
			end
		end
		-- Respawn character
		if hum then
			hum.Health = 0
		end
	end
	-- Clear ESP drawings
	for _, obj in pairs(espObjects) do
		if obj.box then obj.box:Remove() end
		if obj.name then obj.name:Remove() end
		if obj.dist then obj.dist:Remove() end
		if obj.health then obj.health:Remove() end
		if obj.tracer then obj.tracer:Remove() end
	end
	espObjects = {}
end

cancelBtn.MouseButton1Click:Connect(function()
	hideExitDialog()
end)

-- Block all clicks on background while dialog is open
blurFrame.MouseButton1Click:Connect(function()
end)

reloadBtn.MouseButton1Click:Connect(function()
	hideExitDialog()

	-- Close menu with animation
	if menuVisible then
		closeMenu()
		task.wait(0.8)
	end

	-- Immediately disconnect all connections to stop input handling
	for _, conn in ipairs(_G.UndercoreConnections or {}) do
		pcall(function() conn:Disconnect() end)
	end
	_G.UndercoreConnections = nil

	-- Reset all cheats on character
	resetAllCheats()

	-- Disable all features
	_G.Undercore = {}

	-- Destroy main GUI immediately (toggle button, menu, exit dialog)
	blurEffect:Destroy()
	exitDialogGui:Destroy()
	gui:Destroy()

	-- Blue: Restarting (real delay)
	playSound(SOUND_NOTIF, 0.5)
	notify("Undercore", "Restarting script...", 3, ACCENT, "info")
	task.wait(3)

	-- Green: Script closed, relaunching (real delay)
	playSound(SOUND_INJECT, 0.8)
	notify("Undercore", "Script closed. Relaunching...", 3, GREEN, "success")
	task.wait(3)

	-- Destroy notifGui after notifications finish
	notifGui:Destroy()

	-- Actually reload the script
	local reloadUrl = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/undercore.lua"
	local ok, content = pcall(function()
		return game:HttpGet(reloadUrl, true)
	end)
	if ok and content then
		local fn, err = loadstring(content)
		if fn then
			fn()
		end
	end
end)

confirmBtn.MouseButton1Click:Connect(function()
	hideExitDialog()
	hideExitDialog = nil

	-- Close menu with animation
	if menuVisible then
		closeMenu()
		task.wait(0.8)
	end

	-- Immediately disconnect all connections to stop input handling
	for _, conn in ipairs(_G.UndercoreConnections or {}) do
		pcall(function() conn:Disconnect() end)
	end
	_G.UndercoreConnections = nil

	-- Reset all cheats on character
	resetAllCheats()

	-- Disable all features
	_G.Undercore = {}

	-- Destroy all GUIs immediately
	blurEffect:Destroy()
	exitDialogGui:Destroy()
	gui:Destroy()
	notifGui:Destroy()
end)

-- SETTINGS
local settingsPage = createPage("Settings")
local navSettings, navSettingsIcon, navSettingsLabel = createNavButton("Settings")
navButtons["Settings"] = { btn = navSettings, icon = navSettingsIcon, label = navSettingsLabel }
navSettings.MouseButton1Click:Connect(function() showPage("Settings") end)

createLabel(settingsPage, "Settings")
createLabel(settingsPage, "Toggle Key: RightShift / K / F8")
local testNotif = createToggle(settingsPage, "Test Notification", function(v)
	if v then
		notify("Undercore", "Test notification works!", 3, ACCENT, "info")
		task.wait(1)
	end
end)

local exitBtn = Instance.new("TextButton")
exitBtn.Font = Enum.Font.GothamBold
exitBtn.TextSize = 13
exitBtn.TextColor3 = TEXT_WHITE
exitBtn.Text = "TERMINATE SCRIPT"
exitBtn.BackgroundColor3 = RED
exitBtn.BorderSizePixel = 0
exitBtn.Size = UDim2.new(1, 0, 0, 36)
exitBtn.Parent = settingsPage

exitBtn.MouseButton1Click:Connect(function()
	if exitDialogVisible then return end
	playRandomPageSound()
	showExitDialog()
end)

exitBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Default page
showPage("Movement")

-- ===================
-- TOGGLE BUTTON
-- ===================
local scriptReady = false
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
toggleBtn.Visible = false
toggleBtn.Parent = gui

openMenu = function()
	playRandomPageSound()
	menuVisible = true
	mainFrame.Visible = true
	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.GroupTransparency = 1

	-- Green sweep overlay on menu
	local menuSweep = Instance.new("Frame")
	menuSweep.Size = UDim2.new(1, 0, 1, 0)
	menuSweep.BackgroundColor3 = GREEN
	menuSweep.BorderSizePixel = 0
	menuSweep.ZIndex = 100
	menuSweep.Parent = mainFrame

	local sizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 600, 0, 400), GroupTransparency = 0 })
	sizeTween:Play()

	task.wait(0.15)

	local sweepOut = TweenService:Create(menuSweep, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
	sweepOut:Play()
	sweepOut.Completed:Wait()
	menuSweep:Destroy()
end

closeMenu = function()
	playRandomPageSound()

	-- Green sweep in
	local menuSweep = Instance.new("Frame")
	menuSweep.Size = UDim2.new(0, 0, 1, 0)
	menuSweep.Position = UDim2.new(0, 0, 0, 0)
	menuSweep.BackgroundColor3 = GREEN
	menuSweep.BorderSizePixel = 0
	menuSweep.ZIndex = 100
	menuSweep.Parent = mainFrame

	local sweepIn = TweenService:Create(menuSweep, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepIn:Play()
	sweepIn.Completed:Wait()

	-- Shrink + fade out
	local sizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 0), GroupTransparency = 1 })
	sizeTween:Play()
	sizeTween.Completed:Wait()

	menuVisible = false
	mainFrame.Visible = false
	mainFrame.Size = UDim2.new(0, 600, 0, 400)
	mainFrame.GroupTransparency = 0
	menuSweep:Destroy()
end

local holdTimer = nil
local holdCancelled = false
local holdTriggered = false

local function startHold()
	holdCancelled = false
	holdTriggered = false
	holdTimer = task.delay(5, function()
		if not holdCancelled then
			holdTriggered = true
			showExitDialog()
		end
	end)
end

local function cancelHold()
	holdCancelled = true
	if holdTimer then
		task.cancel(holdTimer)
		holdTimer = nil
	end
end

-- Toggle button: click = open/close, hold 5s = terminate
toggleBtn.MouseButton1Down:Connect(function()
	startHold()
end)

toggleBtn.MouseButton1Up:Connect(function()
	cancelHold()
end)

toggleBtn.MouseLeave:Connect(function()
	cancelHold()
end)

toggleBtn.MouseButton1Click:Connect(function()
	if not scriptReady then return end
	if holdTriggered then
		holdTriggered = false
		return
	end
	if not exitDialogVisible then
		if menuVisible then closeMenu() else openMenu() end
	end
end)

toggleBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Keys
trackConn(UserInputService.InputBegan:Connect(function(input, processed)
	if not scriptReady then return end
	if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.K then
		if menuVisible then closeMenu() else openMenu() end
	elseif input.KeyCode == Enum.KeyCode.F8 then
		startHold()
	end
end))

trackConn(UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F8 then
		cancelHold()
		if holdTriggered then
			holdTriggered = false
			return
		end
		if not exitDialogVisible then
			if menuVisible then closeMenu() else openMenu() end
		end
	end
end))

-- Input handling for drag
trackConn(UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end))

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
	trackConn(RunService.RenderStepped:Connect(function()
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
	end))
end
setupFly()

-- SPEED & JUMP
trackConn(RunService.RenderStepped:Connect(function()
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
end))

-- NOCLIP
trackConn(RunService.Stepped:Connect(function()
	if not _G.Undercore.Noclip then return end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end))

-- INFINITE JUMP
trackConn(UserInputService.JumpRequest:Connect(function()
	if _G.Undercore.InfJump then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end))

-- FLING AURA
trackConn(RunService.RenderStepped:Connect(function()
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
end))

-- ESP
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
trackConn(Players.PlayerAdded:Connect(createESPForPlayer))
trackConn(Players.PlayerRemoving:Connect(removeESPForPlayer))

trackConn(RunService.RenderStepped:Connect(function()
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
end))

-- ===================
-- INJECTION SEQUENCE
-- ===================
local SCRIPT_VERSION = "1.0.1"
local VERSION_URL = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/version.txt"

task.spawn(function()
	task.wait(0.5)

	-- Step 1: Checking for updates
	playSound(SOUND_NOTIF, 0.5)
	notify("Undercore", "Checking for updates...", 3, ACCENT, "info")

	-- Actually fetch version from GitHub
	local remoteVersion = nil
	local updateAvailable = false

	pcall(function()
		remoteVersion = game:HttpGet(VERSION_URL, true)
		remoteVersion = remoteVersion:gsub("%s+", "")
		if remoteVersion ~= SCRIPT_VERSION then
			updateAvailable = true
		end
	end)

	task.wait(2)

	if updateAvailable then
		-- Step 2: Update found, installing
		playSound(SOUND_NOTIF, 0.5)
		notify("Undercore", "Update found (v" .. remoteVersion .. "). Installing...", 3, ACCENT, "info")
		task.wait(2.5)

		-- Step 3: Installation complete
		playSound(SOUND_INJECT, 0.8)
		notify("Undercore", "Installation complete. v" .. remoteVersion .. " injected.", 4, GREEN, "success")
	else
		-- No update needed
		playSound(SOUND_INJECT, 0.8)
		notify("Undercore", "Latest version (v" .. SCRIPT_VERSION .. ") injected.", 4, GREEN, "success")
	end

	task.wait(1)

	-- Reveal toggle button and enable script
	scriptReady = true
	toggleBtn.Visible = true
end)

-- Expose
_G.UndercoreNotify = notify
