-- Undercore v1.9.0 - Custom Cheat Menu
-- Inject via executor

local SCRIPT_VERSION = "1.9.0"

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local previousConnections = _G.UndercoreConnections
if previousConnections then
	for _, conn in ipairs(previousConnections) do
		pcall(function() conn:Disconnect() end)
	end
end
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
for _, guiName in ipairs({ "Undercore", "UndercoreNotif", "UndercoreExit" }) do
	local oldGui = uiParent:FindFirstChild(guiName)
	if oldGui then
		pcall(function() oldGui:Destroy() end)
	end
end
local oldBlur = game:GetService("Lighting"):FindFirstChild("UndercoreExitBlur")
if oldBlur then
	pcall(function() oldBlur:Destroy() end)
end

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
local SOUND_HOVER = "72243701593463"
local SOUND_MODAL = "18999173729"
local SOUND_PAGE = { "105197111717033", "85298254384092", "114157584505971" }

local function playSound(soundId, loudness)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = loudness or 0.5
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Preload all sounds
do
	local allSounds = { SOUND_INJECT, SOUND_NOTIF, SOUND_ERROR, SOUND_HOVER, SOUND_MODAL }
	for _, id in ipairs(allSounds) do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Parent = workspace
		task.delay(5, function() pcall(function() s:Destroy() end) end)
	end
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
	info = "rbxassetid://72432575303550",
	error = "rbxassetid://117665558668208",
	success = "rbxassetid://92239767679742",
}

local function notify(title, message, duration, color, notifType)
	duration = duration or 4
	color = color or ACCENT
	notifType = notifType or "info"
	if notifType == "error" then
		playSound(SOUND_ERROR, 0.5)
	elseif notifType == "success" then
		playSound(SOUND_INJECT, 0.8)
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
	icon.Position = UDim2.new(0, 10, 0, 12)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = iconColor
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
titleText.Font = Enum.Font.Michroma
titleText.TextSize = 16
titleText.TextColor3 = TEXT_WHITE
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.Text = "Undercore"
titleText.Parent = titleBar

-- Update banner (hidden by default, shown when update is available)
local updateBanner = Instance.new("TextButton")
updateBanner.Name = "UpdateBanner"
updateBanner.BackgroundTransparency = 1
updateBanner.Size = UDim2.new(0, 220, 1, 0)
updateBanner.Position = UDim2.new(0, 130, 0, 0)
updateBanner.Text = ""
updateBanner.Visible = false
updateBanner.Parent = titleBar

local updateIcon = Instance.new("ImageLabel")
updateIcon.Name = "UpdateIcon"
updateIcon.Size = UDim2.new(0, 16, 0, 16)
updateIcon.Position = UDim2.new(0, 0, 0.5, -8)
updateIcon.BackgroundTransparency = 1
updateIcon.Image = "rbxassetid://139640004463981"
updateIcon.ImageColor3 = GREEN
updateIcon.Visible = false
updateIcon.Parent = updateBanner

local updateText = Instance.new("TextLabel")
updateText.Name = "UpdateText"
updateText.Font = Enum.Font.Gotham
updateText.TextSize = 11
updateText.TextColor3 = GREEN
updateText.TextXAlignment = Enum.TextXAlignment.Left
updateText.TextYAlignment = Enum.TextYAlignment.Center
updateText.BackgroundTransparency = 1
updateText.Size = UDim2.new(1, -20, 1, 0)
updateText.Position = UDim2.new(0, 20, 0, 0)
updateText.Text = "New update available - click to restart"
updateText.Visible = false
updateText.Parent = updateBanner

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
	["Movement"] = "rbxassetid://79374753045626",
	["Combat"] = "rbxassetid://111071395331628",
	["Visuals"] = "rbxassetid://109825947197428",
	["Player"] = "rbxassetid://114284249768955",
	["Settings"] = "rbxassetid://93982901670694",
	["About"] = "rbxassetid://72432575303550",
}

-- Preload all icons so they appear instantly
do
	local allIcons = {}
	for _, v in pairs(NOTIF_ICONS) do table.insert(allIcons, v) end
	for _, v in pairs(NAV_ICONS) do table.insert(allIcons, v) end
	for _, id in ipairs(allIcons) do
		local img = Instance.new("ImageLabel")
		img.Image = id
		img.Visible = false
		img.Parent = game:GetService("ReplicatedStorage")
		task.delay(5, function() pcall(function() img:Destroy() end) end)
	end
end

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

	-- Deactivate old button: sweep enters from RIGHT, eats indicator, exits LEFT
	if currentPage and navButtons[currentPage] then
		local oldData = navButtons[currentPage]
		local oldBtn = oldData.btn

		local oldSweep = Instance.new("Frame")
		oldSweep.Size = UDim2.new(0, 0, 1, 0)
		oldSweep.Position = UDim2.new(1, 0, 0, 0)
		oldSweep.BackgroundColor3 = GREEN
		oldSweep.BackgroundTransparency = 0
		oldSweep.BorderSizePixel = 0
		oldSweep.ZIndex = 1
		oldSweep.Parent = oldBtn

		-- Dark text on green for readability
		oldData.icon.ImageColor3 = Color3.fromRGB(20, 20, 20)
		oldData.label.TextColor3 = Color3.fromRGB(20, 20, 20)

		-- Phase 1: sweep covers button right to left
		local oldSweepIn = TweenService:Create(oldSweep, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0) })
		oldSweepIn:Play()
		oldSweepIn.Completed:Wait()

		-- Sweep reached left edge → ate the indicator
		navIndicator.Visible = false

		-- Phase 2: sweep exits left
		local oldSweepOut = TweenService:Create(oldSweep, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(-1, 0, 0, 0) })
		oldSweepOut:Play()
		oldSweepOut.Completed:Wait()
		oldSweep:Destroy()

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

	-- Activate new button: sweep enters from LEFT, indicator appears behind it, sweep exits RIGHT
	local newData = navButtons[name]
	if newData then
		local newBtn = newData.btn

		local newSweep = Instance.new("Frame")
		newSweep.Size = UDim2.new(0, 0, 1, 0)
		newSweep.Position = UDim2.new(0, 0, 0, 0)
		newSweep.BackgroundColor3 = GREEN
		newSweep.BackgroundTransparency = 0
		newSweep.BorderSizePixel = 0
		newSweep.ZIndex = 1
		newSweep.Parent = newBtn

		-- Dark text on green for readability
		newData.icon.ImageColor3 = Color3.fromRGB(20, 20, 20)
		newData.label.TextColor3 = Color3.fromRGB(20, 20, 20)

		-- Position indicator at new button but keep hidden
		local btn = newData.btn
		local targetY = btn.AbsolutePosition.Y - mainFrame.AbsolutePosition.Y
		local targetH = btn.AbsoluteSize.Y

		navIndicator.BackgroundColor3 = GREEN
		navIndicator.Size = UDim2.new(0, 3, 0, targetH)
		navIndicator.Position = UDim2.new(0, 0, 0, targetY)
		navIndicator.Visible = false

		-- Phase 1: sweep in left to right
		local newSweepIn = TweenService:Create(newSweep, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
		newSweepIn:Play()

		-- Indicator appears behind sweep as soon as sweep passes 3px (almost immediately)
		task.delay(0.02, function()
			navIndicator.Visible = true
		end)

		newSweepIn.Completed:Wait()

		-- Set active colors
		newData.btn.TextColor3 = TEXT_WHITE
		newData.btn.BackgroundColor3 = BG_LIGHT
		newData.icon.ImageColor3 = GREEN
		newData.label.TextColor3 = TEXT_WHITE

		-- Phase 2: sweep exits right, indicator stays
		local newSweepOut = TweenService:Create(newSweep, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
		newSweepOut:Play()
		newSweepOut.Completed:Wait()
		newSweep:Destroy()
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
local flySpeed = createSlider(movementPage, "Fly Speed", 10, 500, 50, function(v) _G.Undercore.FlySpeed = v end)
local speedToggle = createToggle(movementPage, "Speed", function(v) _G.Undercore.Speed = v end)
local speedVal = createSlider(movementPage, "Walk Speed", 16, 500, 50, function(v) _G.Undercore.SpeedVal = v end)
local jumpToggle = createToggle(movementPage, "Jump Power", function(v) _G.Undercore.Jump = v end)
local jumpVal = createSlider(movementPage, "Jump Power", 50, 500, 100, function(v) _G.Undercore.JumpVal = v end)
local noclipToggle = createToggle(movementPage, "Noclip", function(v) _G.Undercore.Noclip = v end)
local noFallToggle = createToggle(movementPage, "No Fall Damage", function(v) _G.Undercore.NoFall = v end)

-- COMBAT
local combatPage = createPage("Combat")
local navCombat, navCombatIcon, navCombatLabel = createNavButton("Combat")
navButtons["Combat"] = { btn = navCombat, icon = navCombatIcon, label = navCombatLabel }
navCombat.MouseButton1Click:Connect(function() showPage("Combat") end)

createLabel(combatPage, "Combat")
local flingToggle = createToggle(combatPage, "Fling Aura", function(v) _G.Undercore.Fling = v end)
local flingAutoToggle = createToggle(combatPage, "Auto Fling", function(v) _G.Undercore.FlingAuto = v end)

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
local antiFlingToggle = createToggle(playerPage, "Anti-Fling", function(v) _G.Undercore.AntiFling = v end)

-- TELEPORT SUBMENU
local teleportSubmenuVisible = false

-- Teleport button (styled like a toggle but acts as a button)
local teleportBtnFrame = Instance.new("Frame")
teleportBtnFrame.Size = UDim2.new(1, 0, 0, 35)
teleportBtnFrame.BackgroundColor3 = BG_LIGHT
teleportBtnFrame.BorderSizePixel = 0
teleportBtnFrame.Parent = playerPage

local teleportBtnLabel = Instance.new("TextLabel")
teleportBtnLabel.Font = Enum.Font.Gotham
teleportBtnLabel.TextSize = 13
teleportBtnLabel.TextColor3 = TEXT_WHITE
teleportBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
teleportBtnLabel.BackgroundTransparency = 1
teleportBtnLabel.Size = UDim2.new(1, -60, 1, 0)
teleportBtnLabel.Position = UDim2.new(0, 12, 0, 0)
teleportBtnLabel.Text = "Teleport to Player"
teleportBtnLabel.Parent = teleportBtnFrame

local teleportBtnSwitch = Instance.new("TextButton")
teleportBtnSwitch.Text = ""
teleportBtnSwitch.BackgroundColor3 = ACCENT
teleportBtnSwitch.BorderSizePixel = 0
teleportBtnSwitch.Size = UDim2.new(0, 40, 0, 20)
teleportBtnSwitch.Position = UDim2.new(1, -50, 0.5, -10)
teleportBtnSwitch.AutoButtonColor = false
teleportBtnSwitch.Parent = teleportBtnFrame

-- Submenu panel (attached to right side of mainFrame)
local teleportPanel = Instance.new("Frame")
teleportPanel.Name = "TeleportPanel"
teleportPanel.Size = UDim2.new(0, 250, 1, 0)
teleportPanel.Position = UDim2.new(1, 0, 0, 0)
teleportPanel.BackgroundColor3 = BG
teleportPanel.BorderSizePixel = 0
teleportPanel.Visible = false
teleportPanel.ZIndex = 50
teleportPanel.Parent = mainFrame

-- Divider on left edge of submenu
local teleportDivider = Instance.new("Frame")
teleportDivider.Size = UDim2.new(0, 2, 1, 0)
teleportDivider.Position = UDim2.new(0, 0, 0, 0)
teleportDivider.BackgroundColor3 = GREEN
teleportDivider.BorderSizePixel = 0
teleportDivider.ZIndex = 51
teleportDivider.Parent = teleportPanel

-- Submenu title
local teleportTitle = Instance.new("TextLabel")
teleportTitle.Font = Enum.Font.GothamBold
teleportTitle.TextSize = 14
teleportTitle.TextColor3 = ACCENT
teleportTitle.TextXAlignment = Enum.TextXAlignment.Left
teleportTitle.BackgroundTransparency = 1
teleportTitle.Size = UDim2.new(1, -20, 0, 30)
teleportTitle.Position = UDim2.new(0, 12, 0, 8)
teleportTitle.Text = "Teleport to Player"
teleportTitle.Parent = teleportPanel

-- Close button for submenu
local teleportCloseBtn = Instance.new("TextButton")
teleportCloseBtn.Font = Enum.Font.GothamBold
teleportCloseBtn.TextSize = 14
teleportCloseBtn.TextColor3 = TEXT_GRAY
teleportCloseBtn.Text = "X"
teleportCloseBtn.BackgroundColor3 = BG_DARK
teleportCloseBtn.BorderSizePixel = 0
teleportCloseBtn.Size = UDim2.new(0, 24, 0, 24)
teleportCloseBtn.Position = UDim2.new(1, -30, 0, 8)
teleportCloseBtn.Parent = teleportPanel

-- Scrollable player list
local teleportListFrame = Instance.new("ScrollingFrame")
teleportListFrame.Size = UDim2.new(1, -12, 1, -50)
teleportListFrame.Position = UDim2.new(0, 6, 0, 42)
teleportListFrame.BackgroundColor3 = BG_DARK
teleportListFrame.BorderSizePixel = 0
teleportListFrame.ScrollBarThickness = 3
teleportListFrame.ScrollBarImageColor3 = GREEN
teleportListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
teleportListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
teleportListFrame.Parent = teleportPanel

local teleportListLayout = Instance.new("UIListLayout")
teleportListLayout.FillDirection = Enum.FillDirection.Vertical
teleportListLayout.SortOrder = Enum.SortOrder.LayoutOrder
teleportListLayout.Padding = UDim.new(0, 2)
teleportListLayout.Parent = teleportListFrame

local teleportListPad = Instance.new("UIPadding")
teleportListPad.PaddingTop = UDim.new(0, 4)
teleportListPad.PaddingBottom = UDim.new(0, 4)
teleportListPad.PaddingLeft = UDim.new(0, 4)
teleportListPad.PaddingRight = UDim.new(0, 4)
teleportListPad.Parent = teleportListFrame

-- Store player entry buttons for refresh
local teleportEntries = {}

local function clearTeleportList()
	for _, entry in ipairs(teleportEntries) do
		if entry.frame then entry.frame:Destroy() end
	end
	teleportEntries = {}
end

local function refreshTeleportList()
	clearTeleportList()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local entryFrame = Instance.new("TextButton")
			entryFrame.Size = UDim2.new(1, 0, 0, 40)
			entryFrame.BackgroundColor3 = BG_LIGHT
			entryFrame.BorderSizePixel = 0
			entryFrame.Text = ""
			entryFrame.AutoButtonColor = false
			entryFrame.LayoutOrder = #teleportEntries
			entryFrame.Parent = teleportListFrame

			-- Avatar image
			local avatar = Instance.new("ImageLabel")
			avatar.Size = UDim2.new(0, 32, 0, 32)
			avatar.Position = UDim2.new(0, 4, 0.5, -16)
			avatar.BackgroundTransparency = 1
			avatar.ScaleType = Enum.ScaleType.Crop
			avatar.Parent = entryFrame

			-- Get avatar thumbnail
			task.spawn(function()
				pcall(function()
					local thumbType = Enum.ThumbnailType.HeadShot
					local thumbSize = Enum.ThumbnailSize.Size48x48
					local content, isReady = Players:GetUserThumbnailAsync(plr.UserId, thumbType, thumbSize)
					if isReady then
						avatar.Image = content
					end
				end)
			end)

			-- Player name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextSize = 12
			nameLabel.TextColor3 = TEXT_WHITE
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.new(1, -44, 0, 20)
			nameLabel.Position = UDim2.new(0, 42, 0, 4)
			nameLabel.Text = plr.DisplayName
			nameLabel.Parent = entryFrame

			-- @username
			local userLabel = Instance.new("TextLabel")
			userLabel.Font = Enum.Font.Gotham
			userLabel.TextSize = 10
			userLabel.TextColor3 = TEXT_GRAY
			userLabel.TextXAlignment = Enum.TextXAlignment.Left
			userLabel.BackgroundTransparency = 1
			userLabel.Size = UDim2.new(1, -44, 0, 14)
			userLabel.Position = UDim2.new(0, 42, 0, 22)
			userLabel.Text = "@" .. plr.Name
			userLabel.Parent = entryFrame

			-- Teleport on click
			entryFrame.MouseButton1Click:Connect(function()
				playRandomPageSound()
				local targetChar = plr.Character
				if targetChar then
					local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
					local myChar = player.Character
					if targetRoot and myChar then
						local myRoot = myChar:FindFirstChild("HumanoidRootPart")
						local myHum = myChar:FindFirstChildOfClass("Humanoid")
						if myRoot and myHum then
							pcall(function()
								myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 5)
								myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
							end)
							notify("Undercore", "Teleported to " .. plr.DisplayName, 3, GREEN, "success")
						end
					end
				end
			end)

			entryFrame.MouseEnter:Connect(function()
				playSound(SOUND_HOVER, 0.15)
				entryFrame.BackgroundColor3 = BG_DARK
			end)

			entryFrame.MouseLeave:Connect(function()
				entryFrame.BackgroundColor3 = BG_LIGHT
			end)

			table.insert(teleportEntries, { frame = entryFrame, player = plr })
		end
	end
end

local function showTeleportSubmenu()
	if teleportSubmenuVisible then return end
	teleportSubmenuVisible = true
	playRandomPageSound()

	refreshTeleportList()

	teleportPanel.Visible = true
	teleportPanel.Size = UDim2.new(0, 0, 1, 0)

	-- Green sweep overlay
	local sweep = Instance.new("Frame")
	sweep.Size = UDim2.new(0, 0, 1, 0)
	sweep.BackgroundColor3 = GREEN
	sweep.BorderSizePixel = 0
	sweep.ZIndex = 60
	sweep.Parent = teleportPanel

	local sizeTween = TweenService:Create(teleportPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 250, 1, 0) })
	sizeTween:Play()

	local sweepTween = TweenService:Create(sweep, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepTween:Play()

	task.wait(0.2)

	local sweepOut = TweenService:Create(sweep, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
	sweepOut:Play()
	sweepOut.Completed:Wait()
	sweep:Destroy()
end

local function hideTeleportSubmenu()
	if not teleportSubmenuVisible then return end
	teleportSubmenuVisible = false
	playRandomPageSound()

	-- Green sweep in
	local sweep = Instance.new("Frame")
	sweep.Size = UDim2.new(0, 0, 1, 0)
	sweep.BackgroundColor3 = GREEN
	sweep.BorderSizePixel = 0
	sweep.ZIndex = 60
	sweep.Parent = teleportPanel

	local sweepIn = TweenService:Create(sweep, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) })
	sweepIn:Play()
	sweepIn.Completed:Wait()

	local sizeTween = TweenService:Create(teleportPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 1, 0) })
	sizeTween:Play()
	sizeTween.Completed:Wait()

	teleportPanel.Visible = false
	sweep:Destroy()
end

teleportBtnSwitch.MouseButton1Click:Connect(function()
	if teleportSubmenuVisible then
		hideTeleportSubmenu()
	else
		showTeleportSubmenu()
	end
end)

teleportBtnFrame.MouseButton1Click:Connect(function()
	if teleportSubmenuVisible then
		hideTeleportSubmenu()
	else
		showTeleportSubmenu()
	end
end)

teleportCloseBtn.MouseButton1Click:Connect(function()
	hideTeleportSubmenu()
end)

teleportBtnFrame.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Refresh list when players join/leave
Players.PlayerAdded:Connect(function()
	if teleportSubmenuVisible then
		refreshTeleportList()
	end
end)
Players.PlayerRemoving:Connect(function()
	if teleportSubmenuVisible then
		refreshTeleportList()
	end
end)

local resetBtn = createToggle(playerPage, "Reset Character (click)", function(v)
	if v then
		-- Turn off all toggles visually and in _G.Undercore
		flyToggle.set(false)
		speedToggle.set(false)
		jumpToggle.set(false)
		noclipToggle.set(false)
		noFallToggle.set(false)
		flingToggle.set(false)
		flingAutoToggle.set(false)
		espToggle.set(false)
		espName.set(false)
		espDist.set(false)
		espHealth.set(false)
		espTracer.set(false)
		infJump.set(false)
		godMode.set(false)
		antiFlingToggle.set(false)

		_G.Undercore.Fly = false
		_G.Undercore.Speed = false
		_G.Undercore.Jump = false
		_G.Undercore.Noclip = false
		_G.Undercore.NoFall = false
		_G.Undercore.Fling = false
		_G.Undercore.FlingAuto = false
		_G.Undercore.ESP = false
		_G.Undercore.ESPName = false
		_G.Undercore.ESPDist = false
		_G.Undercore.ESPHealth = false
		_G.Undercore.ESPTracer = false
		_G.Undercore.InfJump = false
		_G.Undercore.GodMode = false
		_G.Undercore.AntiFling = false

		-- Reset fling state
		flingBusy = false
		autoFlingSavedPos = nil

		-- Reset fly state
		flyEnabled = false
		if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
		if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end

		-- Reset noclip state
		noclipWasOn = false

		-- Now reset character
		local char = player.Character
		if char then char:BreakJoints() end
		task.wait(0.5)
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
infoIcon.Image = "rbxassetid://72432575303550"
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
	infoIcon.Image = "rbxassetid://72432575303550"
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
		local tipX = btnPos.X + btnSize.X / 2 - 110
		local tipY = btnPos.Y - 30
		tooltip.Visible = true
		tooltip.Size = UDim2.new(0, 220, 0, 28)
		tooltip.Position = UDim2.new(0, tipX, 0, tipY)
	end)

	btn.MouseLeave:Connect(function()
		hideTooltip()
	end)

	btn.MouseButton1Click:Connect(function()
		hideTooltip()
	end)
end

local exitDialogVisible = false

local function showExitDialog()
	if exitDialogVisible then return end
	exitDialogVisible = true
	playSound(SOUND_NOTIF, 0.5)

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
	playRandomPageSound()
	hideExitDialog()
end)

cancelBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Block all clicks on background while dialog is open
blurFrame.MouseButton1Click:Connect(function()
end)

reloadBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
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
	notify("Undercore", "Restarting script...", 3, ACCENT, "info")
	task.wait(3)

	-- Green: Script closed, relaunching (real delay)
	notify("Undercore", "Script closed. Relaunching...", 3, GREEN, "success")
	task.wait(3)

	-- Destroy notifGui after notifications finish
	notifGui:Destroy()

	-- Actually reload the script
	local reloadUrl = "https://gitlab.com/api/v4/projects/neruka783-group%2FUndercore/repository/files/undercore.lua/raw?ref=main&v=" .. tostring(tick())
	local ok, content = pcall(function()
		return game:HttpGet(reloadUrl, true)
	end)
	if not ok or not content then
		-- Reload failed - try GitHub raw
		reloadUrl = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/undercore.lua?v=" .. tostring(tick())
		ok, content = pcall(function()
			return game:HttpGet(reloadUrl, true)
		end)
	end
	if ok and content then
		local fn, err = loadstring(content)
		if fn then
			fn()
		else
			print("[Undercore] Reload failed - loadstring error:", err)
		end
	else
		print("[Undercore] Reload failed - HttpGet error:", content)
	end
end)

confirmBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
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

reloadBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

confirmBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
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
	showExitDialog()
end)

exitBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- ABOUT
local aboutPage = createPage("About")
local navAbout, navAboutIcon, navAboutLabel = createNavButton("About")
navButtons["About"] = { btn = navAbout, icon = navAboutIcon, label = navAboutLabel }
navAbout.MouseButton1Click:Connect(function() showPage("About") end)

createLabel(aboutPage, "About")

local aboutTitle = Instance.new("TextLabel")
aboutTitle.Font = Enum.Font.GothamBold
aboutTitle.TextSize = 16
aboutTitle.TextColor3 = ACCENT
aboutTitle.TextXAlignment = Enum.TextXAlignment.Left
aboutTitle.BackgroundTransparency = 1
aboutTitle.Size = UDim2.new(1, -20, 0, 30)
aboutTitle.Position = UDim2.new(0, 10, 0, 35)
aboutTitle.Text = "Undercore - Custom Cheat Menu"
aboutTitle.Parent = aboutPage

local aboutVersion = Instance.new("TextLabel")
aboutVersion.Font = Enum.Font.GothamBold
aboutVersion.TextSize = 14
aboutVersion.TextColor3 = GREEN
aboutVersion.TextXAlignment = Enum.TextXAlignment.Left
aboutVersion.BackgroundTransparency = 1
aboutVersion.Size = UDim2.new(1, -20, 0, 25)
aboutVersion.Position = UDim2.new(0, 10, 0, 70)
aboutVersion.Text = "Version: " .. SCRIPT_VERSION
aboutVersion.Parent = aboutPage

local aboutDesc = Instance.new("TextLabel")
aboutDesc.Font = Enum.Font.Gotham
aboutDesc.TextSize = 13
aboutDesc.TextColor3 = TEXT_GRAY
aboutDesc.TextXAlignment = Enum.TextXAlignment.Left
aboutDesc.TextYAlignment = Enum.TextYAlignment.Top
aboutDesc.TextWrapped = true
aboutDesc.BackgroundTransparency = 1
aboutDesc.Size = UDim2.new(1, -20, 0, 120)
aboutDesc.Position = UDim2.new(0, 10, 0, 105)
aboutDesc.Text = "A custom cheat menu for Roblox featuring Fly, Speed, Noclip, ESP, Fling, Auto Fling, and more.\n\nReal-time update checking via GitLab with automatic notifications.\n\nControls:\n- Toggle menu: RightShift / K / F8\n- Toggle button: U\n- Hold F8 or U for 5s to terminate\n\nMade by Neruka"
aboutDesc.Parent = aboutPage

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

	-- Close teleport submenu if open
	if teleportSubmenuVisible then
		teleportSubmenuVisible = false
		teleportPanel.Visible = false
	end

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
	Noclip = false, NoFall = false,
	Fling = false, FlingAuto = false,
	ESP = false, ESPName = false, ESPDist = false, ESPHealth = false, ESPTracer = false,
	InfJump = false, GodMode = false, AntiFling = false,
}

-- FLY (BodyVelocity + BodyGyro, boost key, smooth, reliable)
local flyBodyVelocity
local flyBodyGyro
local flyEnabled = false
local currentFlyChar = nil

local function setupFly()
	trackConn(RunService.RenderStepped:Connect(function()
		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then return end

		-- Detect character change / respawn
		if currentFlyChar ~= char then
			currentFlyChar = char
			flyEnabled = false
			flyBodyVelocity = nil
			flyBodyGyro = nil
		end

		if not _G.Undercore.Fly then
			if flyEnabled then
				flyEnabled = false
				if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
				if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
				pcall(function()
					root.Velocity = Vector3.zero
					root.RotVelocity = Vector3.zero
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					hum.PlatformStand = false
					hum.Sit = false
					hum.WalkSpeed = _G.Undercore.Speed and _G.Undercore.SpeedVal or 16
					hum.JumpPower = 50
					hum.JumpHeight = 7.2
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				end)
			end
			return
		end

		if not flyBodyVelocity or not flyBodyVelocity.Parent then
			if flyBodyVelocity then flyBodyVelocity:Destroy() end
			if flyBodyGyro then flyBodyGyro:Destroy() end
			flyBodyVelocity = Instance.new("BodyVelocity")
			flyBodyVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
			flyBodyVelocity.Velocity = Vector3.zero
			flyBodyVelocity.Parent = root

			flyBodyGyro = Instance.new("BodyGyro")
			flyBodyGyro.MaxForce = Vector3.new(1, 1, 1) * math.huge
			flyBodyGyro.P = 1e6
			flyBodyGyro.D = 100
			flyBodyGyro.Parent = root
			flyEnabled = true
		end

		local cam = Workspace.CurrentCamera
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

		local speed = _G.Undercore.FlySpeed
		-- Boost: hold LeftCtrl for 3x speed
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			speed = speed * 3
		end

		if dir.Magnitude > 0 then
			dir = dir.Unit * speed
		end

		pcall(function()
			flyBodyVelocity.Velocity = dir
			flyBodyGyro.CFrame = cam.CFrame
			hum.PlatformStand = true
		end)
	end))
end
setupFly()

-- SPEED (WalkSpeed force-set every frame + sprint boost with LeftCtrl)
trackConn(RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if _G.Undercore.Speed then
		local speed = _G.Undercore.SpeedVal
		-- Sprint boost: hold LeftCtrl for 2x speed
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			speed = speed * 2
		end
		pcall(function() hum.WalkSpeed = speed end)
	else
		if hum.WalkSpeed ~= 16 and not _G.Undercore.Fly then
			pcall(function() hum.WalkSpeed = 16 end)
		end
	end
end))

-- JUMP & GOD MODE (force-set every frame, pcall for safety)
trackConn(RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	-- Jump: force set every frame
	if _G.Undercore.Jump then
		pcall(function()
			hum.UseJumpPower = true
			hum.JumpPower = _G.Undercore.JumpVal
			hum.JumpHeight = _G.Undercore.JumpVal / 10
		end)
	else
		if hum.JumpPower ~= 50 then
			pcall(function() hum.JumpPower = 50 end)
		end
	end

	-- God Mode: maxhealth + health regen + prevent ALL damaging states
	if _G.Undercore.GodMode then
		pcall(function()
			hum.MaxHealth = math.huge
			hum.Health = math.huge
		end)
		-- Prevent death state
		if hum:GetState() == Enum.HumanoidStateType.Dead then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.None) end)
		end
		-- Prevent ragdoll/falling down (which can lead to death)
		if hum:GetState() == Enum.HumanoidStateType.FallingDown or hum:GetState() == Enum.HumanoidStateType.Physics then
			pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		end
	else
		if hum.MaxHealth == math.huge then
			pcall(function()
				hum.MaxHealth = 100
				hum.Health = 100
			end)
		end
	end
end))

-- NOCLIP (all parts including accessories, pcall for safety, restore on disable)
local noclipWasOn = false
local noclipChar = nil
trackConn(RunService.Stepped:Connect(function()
	local char = player.Character
	if not char then return end

	-- Reset on character change
	if noclipChar ~= char then
		noclipChar = char
		noclipWasOn = false
	end

	if not _G.Undercore.Noclip then
		if noclipWasOn then
			noclipWasOn = false
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					pcall(function() part.CanCollide = true end)
				end
			end
		end
		return
	end
	noclipWasOn = true
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			pcall(function() part.CanCollide = false end)
		end
	end
end))

-- INFINITE JUMP (instant re-jump on every JumpRequest, no cooldown)
trackConn(UserInputService.JumpRequest:Connect(function(_, processed)
	if _G.Undercore.InfJump then
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if hum and root then
				pcall(function()
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
					-- Extra boost: add upward velocity for higher jump
					root.Velocity = Vector3.new(root.Velocity.X, math.max(root.Velocity.Y, _G.Undercore.Jump and _G.Undercore.JumpVal or 50), root.Velocity.Z)
				end)
			end
		end
	end
end))

-- FLING (based on zqyDSUWX/KILASIK method: teleport into target with massive velocity+rotvelocity)
local flingBusy = false
local oldFallenHeight = nil
local autoFlingSavedPos = nil
local flingChar = nil

local function flingTarget(targetPlayer, duration, returnCFrame)
	if flingBusy then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = hum and hum.RootPart
	if not hum or not root then return end

	-- Reset on character change
	if flingChar ~= char then
		flingChar = char
		flingBusy = false
	end

	local tChar = targetPlayer.Character
	if not tChar then return end
	local tHum = tChar:FindFirstChildOfClass("Humanoid")
	if not tHum then return end
	if tHum.Sit then return end
	if tHum.Health <= 0 then return end

	local tRoot = tHum.RootPart
	local tHead = tChar:FindFirstChild("Head")
	local accessory = tChar:FindFirstChildOfClass("Accessory")
	local handle = accessory and accessory:FindFirstChild("Handle")

	local targetPart = tRoot or tHead or handle
	if not targetPart then return end

	flingBusy = true
	local savedCFrame = returnCFrame or root.CFrame

	-- Safety timeout: force-reset flingBusy after 10 seconds no matter what
	local safetyTimer = task.delay(10, function()
		flingBusy = false
	end)

	-- Anti-fling bypass: increase simulation radius for physics authority
	pcall(function() setsimulationradius(1e9) end)
	pcall(function() if sethiddenproperty then sethiddenproperty(root, "SimulationRadius", 1e9) end end)

	-- Save and disable FallenPartsDestroyHeight
	if not oldFallenHeight then
		oldFallenHeight = Workspace.FallenPartsDestroyHeight
	end
	Workspace.FallenPartsDestroyHeight = 0/0

	-- Anchor local player with BodyVelocity (keeps us in place while spinning)
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.zero
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Parent = root

	-- Additional: BodyAngularVelocity on OUR root to spin us aggressively
	-- This creates massive rotational momentum that transfers to target on collision
	local bav = Instance.new("BodyAngularVelocity")
	bav.AngularVelocity = Vector3.new(0, 9e8, 0)
	bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bav.Parent = root

	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

	-- Collision-based fling: teleport OUR body into target with massive velocity
	-- Physics engine transfers our momentum to target on collision - this REPLICATES
	local function FPos(basePart, pos, ang)
		pcall(function()
			-- Teleport our root directly into the target
			root.CFrame = CFrame.new(basePart.Position) * pos * ang
			char:SetPrimaryPartCFrame(CFrame.new(basePart.Position) * pos * ang)
			-- Massive linear velocity - transfers to target on collision
			root.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
			-- Massive rotational velocity - spins target on collision
			root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
			-- Also set assembly velocities for newer physics engine
			root.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
			root.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
		end)
		-- Keep BodyAngularVelocity spinning us constantly
		pcall(function()
			bav.AngularVelocity = Vector3.new(math.random(-9e8, 9e8), 9e8, math.random(-9e8, 9e8))
		end)
	end

	local function SFBasePart(basePart)
		local timeToWait = duration or 2
		local startTime = tick()
		local angle = 0
		repeat
			if root and tHum and tHum.Health > 0 then
				angle = angle + 30
				-- Teleport directly INTO target from different angles
				-- Use random offsets to hit from all sides for maximum collision
				local rx = math.random(-3, 3)
				local rz = math.random(-3, 3)
				local ry = math.random(-2, 2)
				FPos(basePart, CFrame.new(rx, 1.5 + ry, rz), CFrame.Angles(math.rad(angle), math.rad(angle), 0))
				task.wait(0.01)
				FPos(basePart, CFrame.new(-rx, -1.5 + ry, -rz), CFrame.Angles(math.rad(angle + 90), math.rad(angle), 0))
				task.wait(0.01)
				FPos(basePart, CFrame.new(rz, 1.5 + ry, -rx), CFrame.Angles(math.rad(angle + 180), math.rad(angle + 90), 0))
				task.wait(0.01)
				FPos(basePart, CFrame.new(-rz, -1.5 + ry, rx), CFrame.Angles(math.rad(angle + 270), math.rad(angle + 180), 0))
				task.wait(0.01)
				-- Direct hit: teleport exactly on target
				FPos(basePart, CFrame.new(0, 0, 0), CFrame.Angles(math.rad(angle), math.rad(angle), math.rad(angle)))
				task.wait(0.01)
				FPos(basePart, CFrame.new(0, 1, 0), CFrame.Angles(math.rad(angle + 45), 0, math.rad(angle)))
				task.wait(0.01)
			end
		until startTime + timeToWait < tick() or not _G.Undercore.Fling or not _G.Undercore.FlingAuto
	end

	pcall(function()
		SFBasePart(targetPart)
	end)

	-- Cleanup
	bv:Destroy()
	pcall(function() bav:Destroy() end)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

	-- Restore position (only if not in auto-fling continuous mode, or if returnCFrame provided)
	if returnCFrame or not _G.Undercore.FlingAuto then
		pcall(function()
			repeat
				root.CFrame = savedCFrame * CFrame.new(0, 0.5, 0)
				char:SetPrimaryPartCFrame(savedCFrame * CFrame.new(0, 0.5, 0))
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				for _, part in ipairs(char:GetChildren()) do
					if part:IsA("BasePart") then
						part.Velocity = Vector3.zero
						part.RotVelocity = Vector3.zero
					end
				end
				task.wait()
			until (root.Position - savedCFrame.Position).Magnitude < 25
		end)
	end

	if oldFallenHeight then
		Workspace.FallenPartsDestroyHeight = oldFallenHeight
		oldFallenHeight = nil
	end

	-- Cancel safety timer
	if safetyTimer then
		task.cancel(safetyTimer)
	end

	-- Restore simulation radius
	pcall(function() setsimulationradius(100) end)

	flingBusy = false
end

-- FLING AURA: fling anyone within range (fast - 0.5s per target)
task.spawn(function()
	while true do
		task.wait(0.1)
		if not _G.Undercore.Fling or flingBusy then continue end
		local char = player.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		for _, other in ipairs(Players:GetPlayers()) do
			if not _G.Undercore.Fling or flingBusy then break end
			if other ~= player and other.Character then
				local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
				local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
				if otherRoot and otherHum and otherHum.Health > 0 then
					local dist = (otherRoot.Position - root.Position).Magnitude
					if dist <= 20 then
						flingTarget(other, 0.5)
					end
				end
			end
		end
	end
end)

-- AUTO FLING: save position on enable, cycle through all players, return on disable
task.spawn(function()
	while true do
		task.wait(0.1)
		if not _G.Undercore.FlingAuto then
			-- If auto fling just turned off, return to saved position
			if autoFlingSavedPos then
				local char = player.Character
				if char then
					local root = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")
					if root and hum then
						pcall(function()
							root.CFrame = autoFlingSavedPos * CFrame.new(0, 3, 0)
							root.Velocity = Vector3.zero
							root.RotVelocity = Vector3.zero
							root.AssemblyLinearVelocity = Vector3.zero
							root.AssemblyAngularVelocity = Vector3.zero
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end)
					end
				end
				autoFlingSavedPos = nil
			end
			continue
		end

		if flingBusy then continue end

		-- Save position when auto fling starts
		if not autoFlingSavedPos then
			local char = player.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					autoFlingSavedPos = root.CFrame
				end
			end
			continue
		end

		-- Cycle through all players and fling each one (3s per target, no return between)
		for _, other in ipairs(Players:GetPlayers()) do
			if not _G.Undercore.FlingAuto then break end
			if other ~= player and other.Character then
				local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
				if otherHum and otherHum.Health > 0 then
					flingTarget(other, 3, nil)
				end
			end
		end
	end
end)

-- NO FALL DAMAGE (prevent Landed state + cap Y velocity + cancel Freefall damage)
trackConn(RunService.Stepped:Connect(function()
	if not _G.Undercore.NoFall then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	local state = hum:GetState()

	-- Cancel Landed state (triggers fall damage)
	if state == Enum.HumanoidStateType.Landed then
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.None)
			root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
		end)
	end

	-- Cap downward velocity to prevent lethal fall
	if root.Velocity.Y < -50 then
		pcall(function()
			root.Velocity = Vector3.new(root.Velocity.X, -30, root.Velocity.Z)
		end)
	end

	-- If in Freefall and close to ground, slow down
	if state == Enum.HumanoidStateType.Freefall then
		pcall(function()
			local ray = Workspace:Raycast(root.Position, Vector3.new(0, -10, 0))
			if ray and ray.Distance < 8 then
				root.Velocity = Vector3.new(root.Velocity.X, -10, root.Velocity.Z)
			end
		end)
	end
end))

-- ANTI-FLING (aggressive: zero velocity every frame + detect and restore position)
-- Disabled while flingBusy to avoid conflict with own fling
local antiFlingLastCFrame = nil
local antiFlingLastTick = tick()
trackConn(RunService.RenderStepped:Connect(function()
	if not _G.Undercore.AntiFling then
		antiFlingLastCFrame = nil
		return
	end
	-- Skip if we're actively flinging someone
	if flingBusy then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local currentPos = root.Position
	local currentTick = tick()

	-- Initialize saved position
	if not antiFlingLastCFrame then
		antiFlingLastCFrame = root.CFrame
		antiFlingLastTick = currentTick
		return
	end

	local dt = currentTick - antiFlingLastTick

	-- Always zero out abnormal rotation
	pcall(function()
		if root.RotVelocity.Magnitude > 50 then
			root.RotVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	if dt > 0 then
		local velocity = (currentPos - antiFlingLastCFrame.Position) / dt
		-- If we're being flung (lower threshold = more sensitive)
		if velocity.Magnitude > 80 then
			pcall(function()
				root.Velocity = Vector3.zero
				root.RotVelocity = Vector3.zero
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				-- Restore position but keep current camera rotation
				root.CFrame = CFrame.new(antiFlingLastCFrame.Position) * (root.CFrame - root.CFrame.Position)
			end)
		else
			-- Update saved CFrame only when not being flung
			antiFlingLastCFrame = root.CFrame
		end
	end
	antiFlingLastTick = currentTick
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
local GITLAB_API = "https://gitlab.com/api/v4/projects/neruka783-group%2FUndercore/repository/files/"
local SCRIPT_URL_PRIMARY = GITLAB_API .. "undercore.lua/raw?ref=main"
local VERSION_URL_PRIMARY = GITLAB_API .. "version.txt/raw?ref=main"
local SCRIPT_URL_FALLBACK = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/undercore.lua"
local VERSION_URL_FALLBACK = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/version.txt"

local function fetchRemoteVersion()
	local version = nil
	pcall(function()
		version = game:HttpGet(VERSION_URL_PRIMARY .. "&v=" .. tostring(tick()), true)
		version = version:gsub("%s+", "")
	end)
	if not version or version == "" then
		pcall(function()
			local remoteScript = game:HttpGet(SCRIPT_URL_PRIMARY .. "&v=" .. tostring(tick()), true)
			version = remoteScript:match("%-%- Undercore v([%d%.]+)")
		end)
	end
	if not version or version == "" then
		pcall(function()
			version = game:HttpGet(VERSION_URL_FALLBACK .. "?v=" .. tostring(tick()), true)
			version = version:gsub("%s+", "")
		end)
	end
	if not version or version == "" then
		pcall(function()
			local remoteScript = game:HttpGet(SCRIPT_URL_FALLBACK .. "?v=" .. tostring(tick()), true)
			version = remoteScript:match("%-%- Undercore v([%d%.]+)")
		end)
	end
	return version
end

local function showUpdateBanner(remoteVer)
	updateBanner.Visible = true
	updateIcon.Visible = true
	updateText.Visible = true
end

local function hideUpdateBanner()
	updateBanner.Visible = false
	updateIcon.Visible = false
	updateText.Visible = false
end

-- Click banner to go to Settings with update dialog
updateBanner.MouseButton1Click:Connect(function()
	-- Open menu if not visible
	if not menuVisible then
		openMenu()
		task.wait(0.5)
	end
	-- Switch to Settings page
	showPage("Settings")
	task.wait(0.5)
	-- Show the update/exit dialog
	showExitDialog()
end)

task.spawn(function()
	task.wait(0.5)

	-- Step 1: Checking for updates
	notify("Undercore", "Checking for updates...", 3, ACCENT, "info")

	local remoteVersion = fetchRemoteVersion()

	task.wait(2)

	if remoteVersion and remoteVersion ~= "" then
		if remoteVersion ~= SCRIPT_VERSION then
			notify("Undercore", "Update found (v" .. remoteVersion .. "). Click banner to update.", 4, ACCENT, "info")
			showUpdateBanner(remoteVersion)
		else
			notify("Undercore", "Latest version (v" .. SCRIPT_VERSION .. ") injected.", 4, GREEN, "success")
		end
	else
		notify("Undercore", "Version check failed. Running v" .. SCRIPT_VERSION .. ".", 4, GREEN, "success")
	end

	task.wait(1)
	scriptReady = true
	toggleBtn.Visible = true

	-- Background real-time update check (every 10 seconds)
	task.spawn(function()
		while true do
			task.wait(10)
			local latestVersion = fetchRemoteVersion()
			if latestVersion and latestVersion ~= "" and latestVersion ~= SCRIPT_VERSION then
				if not updateBanner.Visible then
					showUpdateBanner(latestVersion)
					notify("Undercore", "New update available (v" .. latestVersion .. "). Click banner to update.", 5, ACCENT, "info")
				end
			end
		end
	end)
end)

-- Expose
_G.UndercoreNotify = notify
