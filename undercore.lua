-- Undercore v2.4.0 - Custom Cheat Menu
-- Inject via executor

local SCRIPT_VERSION = "2.4.0"
local terminated = false

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

-- Colors (OMSIMP VS Code dark theme)
local BG = Color3.fromRGB(10, 10, 10)           -- #0a0a0a main bg
local BG_DARK = Color3.fromRGB(13, 13, 13)       -- #0d0d0d activity bar / sidebar
local BG_LIGHT = Color3.fromRGB(18, 18, 18)      -- #121212 panel
local CARD_BG = Color3.fromRGB(22, 22, 22)       -- #161616 card
local CARD_HOVER = Color3.fromRGB(30, 30, 30)    -- #1e1e1e card hover
local LIST_HOVER = Color3.fromRGB(26, 26, 26)    -- #1a1a1a list hover
local LIST_ACTIVE = Color3.fromRGB(34, 34, 34)   -- #222222 list active
local BORDER_COLOR = Color3.fromRGB(26, 26, 26)  -- #1a1a1a border
local ACCENT = Color3.fromRGB(37, 99, 235)       -- #2563eb blue accent
local ACCENT_HOVER = Color3.fromRGB(59, 130, 246)-- #3b82f6 accent hover
local TEXT_WHITE = Color3.fromRGB(255, 255, 255) -- #ffffff bright text
local TEXT_GRAY = Color3.fromRGB(136, 136, 136)  -- #888888 muted text
local TEXT_NORMAL = Color3.fromRGB(224, 224, 224)-- #e0e0e0 normal text
local GREEN = Color3.fromRGB(34, 197, 94)        -- #22c55e success
local RED = Color3.fromRGB(239, 68, 68)          -- #ef4444 error
local WARNING = Color3.fromRGB(245, 158, 11)     -- #f59e0b warning

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

	local slideOut = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, card.Position.Y.Offset), GroupTransparency = 1 })
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
	card.BackgroundColor3 = CARD_BG
	card.GroupColor3 = Color3.fromRGB(255, 255, 255)
	card.GroupTransparency = 0
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, y)
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Icon area (left padding, no strip)
	local iconArea = Instance.new("Frame")
	iconArea.Name = "IconArea"
	iconArea.Size = UDim2.new(0, 48, 0, 0)
	iconArea.Position = UDim2.new(0, 12, 0, 0)
	iconArea.AutomaticSize = Enum.AutomaticSize.Y
	iconArea.BackgroundTransparency = 1
	iconArea.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Name = "NotifIcon"
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 4, 0, 14)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = iconColor
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 6
	icon.Parent = iconArea

	-- Content (right of icon)
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -72, 0, 0)
	content.Position = UDim2.new(0, 60, 0, 0)
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
local openMenu, closeMenu

local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 640, 0, 420)
mainFrame.BackgroundColor3 = BG
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = false
mainFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Parent = gui

-- Title bar (flat, minimal)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = BG
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
titleText.Font = Enum.Font.GothamMedium
titleText.TextSize = 13
titleText.TextColor3 = TEXT_GRAY
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 14, 0, 0)
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
updateIcon.ImageColor3 = ACCENT
updateIcon.Visible = false
updateIcon.Parent = updateBanner

local updateText = Instance.new("TextLabel")
updateText.Name = "UpdateText"
updateText.Font = Enum.Font.Gotham
updateText.TextSize = 11
updateText.TextColor3 = ACCENT
updateText.TextXAlignment = Enum.TextXAlignment.Left
updateText.TextYAlignment = Enum.TextYAlignment.Center
updateText.BackgroundTransparency = 1
updateText.Size = UDim2.new(1, -20, 1, 0)
updateText.Position = UDim2.new(0, 20, 0, 0)
updateText.Text = "New update available - click to restart"
updateText.Visible = false
updateText.Parent = updateBanner

-- Left navigation (icon-only sidebar, VS Code style)
local navFrame = Instance.new("Frame")
navFrame.Size = UDim2.new(0, 48, 1, -36)
navFrame.Position = UDim2.new(0, 0, 0, 36)
navFrame.BackgroundColor3 = BG_DARK
navFrame.BorderSizePixel = 0
navFrame.Active = false
navFrame.Parent = mainFrame

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 4)
navLayout.Parent = navFrame

local navPad = Instance.new("UIPadding")
navPad.PaddingTop = UDim.new(0, 8)
navPad.PaddingBottom = UDim.new(0, 8)
navPad.Parent = navFrame

-- Right content
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -48, 1, -36)
contentFrame.Position = UDim2.new(0, 48, 0, 36)
contentFrame.BackgroundColor3 = BG_LIGHT
contentFrame.BorderSizePixel = 0
contentFrame.Active = false
contentFrame.Parent = mainFrame

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 16)
contentPad.PaddingBottom = UDim.new(0, 16)
contentPad.PaddingLeft = UDim.new(0, 16)
contentPad.PaddingRight = UDim.new(0, 16)
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
	btn.Size = UDim2.new(0, 40, 0, 40)
	btn.Parent = navFrame

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.Position = UDim2.new(0.5, -11, 0.5, -11)
	icon.BackgroundTransparency = 1
	icon.Image = NAV_ICONS[name] or ""
	icon.ImageColor3 = TEXT_GRAY
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	icon.Parent = btn

	-- Tooltip on hover
	local tooltip = Instance.new("TextLabel")
	tooltip.Font = Enum.Font.Gotham
	tooltip.TextSize = 12
	tooltip.TextColor3 = TEXT_WHITE
	tooltip.TextXAlignment = Enum.TextXAlignment.Left
	tooltip.TextYAlignment = Enum.TextYAlignment.Center
	tooltip.BackgroundColor3 = CARD_BG
	tooltip.BorderSizePixel = 0
	tooltip.Size = UDim2.new(0, 80, 0, 24)
	tooltip.Position = UDim2.new(1, 6, 0.5, -12)
	tooltip.Visible = false
	tooltip.ZIndex = 100
	tooltip.Text = "  " .. name
	tooltip.Parent = btn

	btn.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 0.15)
		tooltip.Visible = true
		if btn.BackgroundColor3 ~= CARD_HOVER then
			icon.ImageColor3 = TEXT_NORMAL
		end
	end)

	btn.MouseLeave:Connect(function()
		tooltip.Visible = false
		if btn.BackgroundColor3 ~= CARD_HOVER then
			icon.ImageColor3 = TEXT_GRAY
		end
	end)

	return btn, icon, tooltip
end

local function createPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = CARD_HOVER
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

-- Active nav indicator (blue accent bar on left edge)
local navIndicator = Instance.new("Frame")
navIndicator.Name = "NavIndicator"
navIndicator.Size = UDim2.new(0, 3, 0, 40)
navIndicator.Position = UDim2.new(0, 0, 0, 50)
navIndicator.BackgroundColor3 = ACCENT
navIndicator.BorderSizePixel = 0
navIndicator.ZIndex = 20
navIndicator.Visible = false
navIndicator.Parent = mainFrame

-- Forward declarations for visual preview panel (defined later)
local showVisualPreview
local hideVisualPreview

local function showPage(name)
	if currentPage == name then return end
	if pageSwitching then return end
	pageSwitching = true
	playRandomPageSound()

	-- Auto-close visual preview when leaving Visuals page
	if currentPage == "Visuals" and name ~= "Visuals" and hideVisualPreview then
		task.spawn(function() hideVisualPreview() end)
	end

	-- Deactivate old button
	if currentPage and navButtons[currentPage] then
		local oldData = navButtons[currentPage]
		oldData.btn.BackgroundColor3 = BG_DARK
		oldData.icon.ImageColor3 = TEXT_GRAY
	end

	-- Fade content
	local fadeOverlay = Instance.new("Frame")
	fadeOverlay.Size = UDim2.new(1, 0, 1, 0)
	fadeOverlay.BackgroundColor3 = BG_LIGHT
	fadeOverlay.BorderSizePixel = 0
	fadeOverlay.BackgroundTransparency = 1
	fadeOverlay.ZIndex = 50
	fadeOverlay.Parent = contentFrame

	local fadeIn = TweenService:Create(fadeOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()

	for pageName, page in pairs(pages) do
		page.Visible = (pageName == name)
	end

	-- Activate new button
	local newData = navButtons[name]
	if newData then
		newData.btn.BackgroundColor3 = CARD_HOVER
		newData.icon.ImageColor3 = TEXT_WHITE

		-- Position indicator at new button
		local btn = newData.btn
		local targetY = btn.AbsolutePosition.Y - mainFrame.AbsolutePosition.Y
		local targetH = btn.AbsoluteSize.Y
		navIndicator.Size = UDim2.new(0, 3, 0, targetH)
		navIndicator.Position = UDim2.new(0, 0, 0, targetY)
		navIndicator.Visible = true
	end

	local fadeOut = TweenService:Create(fadeOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	fadeOverlay:Destroy()

	currentPage = name
	pageSwitching = false

	-- Auto-open visual preview when entering Visuals page
	if name == "Visuals" and showVisualPreview then
		task.spawn(function() showVisualPreview() end)
	end
end

-- UI helpers
local function createToggle(parent, text, callback)
	local enabled = false
	local toggling = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 38)
	frame.BackgroundColor3 = CARD_BG
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TEXT_NORMAL
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -60, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.Text = text
	label.Parent = frame

	-- Toggle switch background (pill shape)
	local switchBg = Instance.new("TextButton")
	switchBg.Text = ""
	switchBg.BackgroundColor3 = CARD_HOVER
	switchBg.BorderSizePixel = 0
	switchBg.Size = UDim2.new(0, 44, 0, 24)
	switchBg.Position = UDim2.new(1, -54, 0.5, -12)
	switchBg.AutoButtonColor = false
	switchBg.Parent = frame

	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchBg

	-- White circle knob
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = UDim2.new(0, 3, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = switchBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local function updateVisual()
		if enabled then
			switchBg.BackgroundColor3 = ACCENT
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(1, -21, 0.5, -9) })
			knobTween:Play()
		else
			switchBg.BackgroundColor3 = CARD_HOVER
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0, 3, 0.5, -9) })
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
	frame.Size = UDim2.new(1, 0, 0, 54)
	frame.BackgroundColor3 = CARD_BG
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TEXT_NORMAL
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.new(0, 14, 0, 8)
	label.Text = text .. ": " .. tostring(default)
	label.Parent = frame

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -28, 0, 4)
	sliderBg.Position = UDim2.new(0, 14, 0, 36)
	sliderBg.BackgroundColor3 = CARD_HOVER
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = frame

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(1, 0)
	sliderCorner.Parent = sliderBg

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = ACCENT
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = sliderFill

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
	label.TextColor3 = TEXT_WHITE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 28)
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

createLabel(visualPage, "MM2 ESP")
local espRole = createToggle(visualPage, "ESP Role Text", function(v) _G.Undercore.ESPRole = v end)
local espRoleColor = createToggle(visualPage, "ESP Role Colors", function(v) _G.Undercore.ESPRoleColor = v end)
local espMurdererHighlight = createToggle(visualPage, "Highlight Murderer", function(v) _G.Undercore.ESPMurdererHL = v end)

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

-- SPECTATE/FOLLOW SUBMENU
local spectateSubmenuVisible = false
local showSpectateSubmenu
local hideSpectateSubmenu
local spectateTarget = nil
local spectateEnabled = false

-- Teleport button (styled like a toggle but acts as a button)
local teleportBtnFrame = Instance.new("TextButton")
teleportBtnFrame.Text = ""
teleportBtnFrame.AutoButtonColor = false
teleportBtnFrame.Size = UDim2.new(1, 0, 0, 38)
teleportBtnFrame.BackgroundColor3 = CARD_BG
teleportBtnFrame.BorderSizePixel = 0
teleportBtnFrame.Parent = playerPage

local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 6)
teleportCorner.Parent = teleportBtnFrame

local teleportBtnLabel = Instance.new("TextLabel")
teleportBtnLabel.Font = Enum.Font.Gotham
teleportBtnLabel.TextSize = 13
teleportBtnLabel.TextColor3 = TEXT_NORMAL
teleportBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
teleportBtnLabel.TextYAlignment = Enum.TextYAlignment.Center
teleportBtnLabel.BackgroundTransparency = 1
teleportBtnLabel.Size = UDim2.new(1, -20, 1, 0)
teleportBtnLabel.Position = UDim2.new(0, 14, 0, 0)
teleportBtnLabel.Text = "Teleport to Player"
teleportBtnLabel.Parent = teleportBtnFrame

-- Submenu panel (parented to gui, not mainFrame, because CanvasGroup clips children)
local teleportPanel = Instance.new("Frame")
teleportPanel.Name = "TeleportPanel"
teleportPanel.Size = UDim2.new(0, 250, 0, 400)
teleportPanel.Position = UDim2.new(0, 0, 0, 0)
teleportPanel.BackgroundColor3 = BG
teleportPanel.BorderSizePixel = 0
teleportPanel.Visible = false
teleportPanel.ZIndex = 50
teleportPanel.Parent = gui

local teleportPanelCorner = Instance.new("UICorner")
teleportPanelCorner.CornerRadius = UDim.new(0, 8)
teleportPanelCorner.Parent = teleportPanel

-- Sync teleport panel position with mainFrame (follows when dragged)
-- mainFrame: AnchorPoint(0.5,0.5), Position(0.5,0, 0.5,0), Size(640,420)
-- Top-left of mainFrame = (centerX - 320, centerY - 210)
-- Right edge = centerX + 320
-- Teleport panel (AnchorPoint 0,0) goes at (right edge, top-left Y)
trackConn(RunService.RenderStepped:Connect(function()
	if teleportPanel.Visible then
		teleportPanel.Position = UDim2.new(
			0.5, mainFrame.Position.X.Offset + 320,
			0.5, mainFrame.Position.Y.Offset - 210
		)
		teleportPanel.Size = UDim2.new(0, 250, 0, 420)
	end
end))

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

-- Scrollable player list
local teleportListFrame = Instance.new("ScrollingFrame")
teleportListFrame.Size = UDim2.new(1, -12, 1, -50)
teleportListFrame.Position = UDim2.new(0, 6, 0, 42)
teleportListFrame.BackgroundColor3 = BG_DARK
teleportListFrame.BorderSizePixel = 0
teleportListFrame.ScrollBarThickness = 3
teleportListFrame.ScrollBarImageColor3 = CARD_HOVER
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
			entryFrame.BackgroundColor3 = CARD_BG
			entryFrame.BorderSizePixel = 0
			entryFrame.Text = ""
			entryFrame.AutoButtonColor = false
			entryFrame.LayoutOrder = #teleportEntries
			entryFrame.Parent = teleportListFrame

			local entryCorner = Instance.new("UICorner")
			entryCorner.CornerRadius = UDim.new(0, 6)
			entryCorner.Parent = entryFrame

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
			nameLabel.TextColor3 = TEXT_NORMAL
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
							notify("Undercore", "Teleported to " .. plr.DisplayName, 3, ACCENT, "info")
						end
					end
				end
			end)

			entryFrame.MouseEnter:Connect(function()
				playSound(SOUND_HOVER, 0.15)
				entryFrame.BackgroundColor3 = CARD_HOVER
			end)

			entryFrame.MouseLeave:Connect(function()
				entryFrame.BackgroundColor3 = CARD_BG
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

	local panelHeight = 420
	teleportPanel.Visible = true
	teleportPanel.Size = UDim2.new(0, 0, 0, panelHeight)

	local sizeTween = TweenService:Create(teleportPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 250, 0, panelHeight) })
	sizeTween:Play()
	sizeTween.Completed:Wait()
end

local function hideTeleportSubmenu()
	if not teleportSubmenuVisible then return end
	teleportSubmenuVisible = false
	playRandomPageSound()

	local sizeTween = TweenService:Create(teleportPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 420) })
	sizeTween:Play()
	sizeTween.Completed:Wait()

	teleportPanel.Visible = false
end

teleportBtnFrame.MouseButton1Click:Connect(function()
	if teleportSubmenuVisible then
		hideTeleportSubmenu()
	else
		showTeleportSubmenu()
	end
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

-- ===================
-- SPECTATE / FOLLOW SUBMENU
-- ===================

-- Spectate button (styled like teleport button)
local spectateBtnFrame = Instance.new("TextButton")
spectateBtnFrame.Text = ""
spectateBtnFrame.AutoButtonColor = false
spectateBtnFrame.Size = UDim2.new(1, 0, 0, 38)
spectateBtnFrame.BackgroundColor3 = CARD_BG
spectateBtnFrame.BorderSizePixel = 0
spectateBtnFrame.Parent = playerPage

local spectateCorner = Instance.new("UICorner")
spectateCorner.CornerRadius = UDim.new(0, 6)
spectateCorner.Parent = spectateBtnFrame

local spectateBtnLabel = Instance.new("TextLabel")
spectateBtnLabel.Font = Enum.Font.Gotham
spectateBtnLabel.TextSize = 13
spectateBtnLabel.TextColor3 = TEXT_NORMAL
spectateBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
spectateBtnLabel.TextYAlignment = Enum.TextYAlignment.Center
spectateBtnLabel.BackgroundTransparency = 1
spectateBtnLabel.Size = UDim2.new(1, -20, 1, 0)
spectateBtnLabel.Position = UDim2.new(0, 14, 0, 0)
spectateBtnLabel.Text = "Spectate / Follow Player"
spectateBtnLabel.Parent = spectateBtnFrame

-- Spectate panel (parented to gui, like teleport panel)
local spectatePanel = Instance.new("Frame")
spectatePanel.Name = "SpectatePanel"
spectatePanel.Size = UDim2.new(0, 250, 0, 420)
spectatePanel.Position = UDim2.new(0, 0, 0, 0)
spectatePanel.BackgroundColor3 = BG
spectatePanel.BorderSizePixel = 0
spectatePanel.Visible = false
spectatePanel.ZIndex = 50
spectatePanel.Parent = gui

local spectatePanelCorner = Instance.new("UICorner")
spectatePanelCorner.CornerRadius = UDim.new(0, 8)
spectatePanelCorner.Parent = spectatePanel

-- Sync spectate panel position with mainFrame (left side, top aligned)
trackConn(RunService.RenderStepped:Connect(function()
	if spectatePanel.Visible then
		spectatePanel.Position = UDim2.new(
			0.5, mainFrame.Position.X.Offset - 320 - 260,
			0.5, mainFrame.Position.Y.Offset - 210
		)
		spectatePanel.Size = UDim2.new(0, 250, 0, 420)
	end
end))

-- Spectate panel title
local spectateTitle = Instance.new("TextLabel")
spectateTitle.Font = Enum.Font.GothamBold
spectateTitle.TextSize = 14
spectateTitle.TextColor3 = ACCENT
spectateTitle.TextXAlignment = Enum.TextXAlignment.Left
spectateTitle.BackgroundTransparency = 1
spectateTitle.Size = UDim2.new(1, -20, 0, 30)
spectateTitle.Position = UDim2.new(0, 12, 0, 8)
spectateTitle.Text = "Follow Player"
spectateTitle.Parent = spectatePanel

-- Status label showing current target
local spectateStatus = Instance.new("TextLabel")
spectateStatus.Font = Enum.Font.Gotham
spectateStatus.TextSize = 11
spectateStatus.TextColor3 = TEXT_GRAY
spectateStatus.TextXAlignment = Enum.TextXAlignment.Left
spectateStatus.BackgroundTransparency = 1
spectateStatus.Size = UDim2.new(1, -20, 0, 16)
spectateStatus.Position = UDim2.new(0, 12, 0, 30)
spectateStatus.Text = "No target selected"
spectateStatus.Parent = spectatePanel

-- Scrollable player list
local spectateListFrame = Instance.new("ScrollingFrame")
spectateListFrame.Size = UDim2.new(1, -12, 1, -100)
spectateListFrame.Position = UDim2.new(0, 6, 0, 52)
spectateListFrame.BackgroundColor3 = BG_DARK
spectateListFrame.BorderSizePixel = 0
spectateListFrame.ScrollBarThickness = 3
spectateListFrame.ScrollBarImageColor3 = CARD_HOVER
spectateListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
spectateListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
spectateListFrame.Parent = spectatePanel

local spectateListLayout = Instance.new("UIListLayout")
spectateListLayout.FillDirection = Enum.FillDirection.Vertical
spectateListLayout.SortOrder = Enum.SortOrder.LayoutOrder
spectateListLayout.Padding = UDim.new(0, 2)
spectateListLayout.Parent = spectateListFrame

local spectateListPad = Instance.new("UIPadding")
spectateListPad.PaddingTop = UDim.new(0, 4)
spectateListPad.PaddingBottom = UDim.new(0, 4)
spectateListPad.PaddingLeft = UDim.new(0, 4)
spectateListPad.PaddingRight = UDim.new(0, 4)
spectateListPad.Parent = spectateListFrame

-- Stop following button
local stopFollowBtn = Instance.new("TextButton")
stopFollowBtn.Font = Enum.Font.GothamBold
stopFollowBtn.TextSize = 12
stopFollowBtn.TextColor3 = TEXT_WHITE
stopFollowBtn.Text = "Stop Following"
stopFollowBtn.BackgroundColor3 = RED
stopFollowBtn.BorderSizePixel = 0
stopFollowBtn.Size = UDim2.new(1, -12, 0, 32)
stopFollowBtn.Position = UDim2.new(0, 6, 1, -38)
stopFollowBtn.Visible = false
stopFollowBtn.Parent = spectatePanel

local stopFollowCorner = Instance.new("UICorner")
stopFollowCorner.CornerRadius = UDim.new(0, 6)
stopFollowCorner.Parent = stopFollowBtn

-- Store spectate entries
local spectateEntries = {}

local function clearSpectateList()
	for _, entry in ipairs(spectateEntries) do
		if entry.frame then entry.frame:Destroy() end
	end
	spectateEntries = {}
end

local function refreshSpectateList()
	clearSpectateList()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local entryFrame = Instance.new("TextButton")
			entryFrame.Size = UDim2.new(1, 0, 0, 40)
			entryFrame.BackgroundColor3 = CARD_BG
			entryFrame.BorderSizePixel = 0
			entryFrame.Text = ""
			entryFrame.AutoButtonColor = false
			entryFrame.LayoutOrder = #spectateEntries
			entryFrame.Parent = spectateListFrame

			local entryCorner = Instance.new("UICorner")
			entryCorner.CornerRadius = UDim.new(0, 6)
			entryCorner.Parent = entryFrame

			local avatar = Instance.new("ImageLabel")
			avatar.Size = UDim2.new(0, 32, 0, 32)
			avatar.Position = UDim2.new(0, 4, 0.5, -16)
			avatar.BackgroundTransparency = 1
			avatar.ScaleType = Enum.ScaleType.Crop
			avatar.Parent = entryFrame

			task.spawn(function()
				pcall(function()
					local content, isReady = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					if isReady then avatar.Image = content end
				end)
			end)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextSize = 12
			nameLabel.TextColor3 = TEXT_NORMAL
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.new(1, -44, 0, 20)
			nameLabel.Position = UDim2.new(0, 42, 0, 4)
			nameLabel.Text = plr.DisplayName
			nameLabel.Parent = entryFrame

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

			-- Follow indicator (checkmark when actively following this player)
			local followIcon = Instance.new("ImageLabel")
			followIcon.Size = UDim2.new(0, 16, 0, 16)
			followIcon.Position = UDim2.new(1, -22, 0.5, -8)
			followIcon.BackgroundTransparency = 1
			followIcon.Image = "rbxassetid://92239767679742"
			followIcon.ImageColor3 = ACCENT
			followIcon.ScaleType = Enum.ScaleType.Fit
			followIcon.Visible = false
			followIcon.Parent = entryFrame

			entryFrame.MouseButton1Click:Connect(function()
				playRandomPageSound()
				spectateTarget = plr
				spectateEnabled = true
				spectateStatus.Text = "Following: " .. plr.DisplayName
				stopFollowBtn.Visible = true
				notify("Undercore", "Now following " .. plr.DisplayName, 3, ACCENT, "info")
				-- Update all follow icons
				for _, e in ipairs(spectateEntries) do
					if e.icon then
						e.icon.Visible = (e.player == plr)
					end
					if e.frame then
						e.frame.BackgroundColor3 = (e.player == plr) and CARD_HOVER or CARD_BG
					end
				end
			end)

			entryFrame.MouseEnter:Connect(function()
				playSound(SOUND_HOVER, 0.15)
				if spectateTarget ~= plr then
					entryFrame.BackgroundColor3 = CARD_HOVER
				end
			end)

			entryFrame.MouseLeave:Connect(function()
				if spectateTarget ~= plr then
					entryFrame.BackgroundColor3 = CARD_BG
				end
			end)

			table.insert(spectateEntries, { frame = entryFrame, player = plr, icon = followIcon })
		end
	end
end

-- Stop following button handler
stopFollowBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	spectateEnabled = false
	spectateTarget = nil
	spectateStatus.Text = "No target selected"
	stopFollowBtn.Visible = false
	for _, e in ipairs(spectateEntries) do
		if e.icon then e.icon.Visible = false end
		if e.frame then e.frame.BackgroundColor3 = CARD_BG end
	end
	notify("Undercore", "Stopped following", 3, ACCENT, "info")
end)

stopFollowBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Show/hide functions
showSpectateSubmenu = function()
	if spectateSubmenuVisible then return end
	spectateSubmenuVisible = true
	playRandomPageSound()
	refreshSpectateList()
	spectatePanel.Visible = true
	spectatePanel.Size = UDim2.new(0, 0, 0, 420)
	local sizeTween = TweenService:Create(spectatePanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 250, 0, 420) })
	sizeTween:Play()
	sizeTween.Completed:Wait()
end

hideSpectateSubmenu = function()
	if not spectateSubmenuVisible then return end
	spectateSubmenuVisible = false
	playRandomPageSound()
	local sizeTween = TweenService:Create(spectatePanel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 420) })
	sizeTween:Play()
	sizeTween.Completed:Wait()
	spectatePanel.Visible = false
end

spectateBtnFrame.MouseButton1Click:Connect(function()
	if spectateSubmenuVisible then
		hideSpectateSubmenu()
	else
		showSpectateSubmenu()
	end
end)

spectateBtnFrame.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 0.15)
end)

-- Refresh spectate list when players join/leave
Players.PlayerAdded:Connect(function()
	if spectateSubmenuVisible then
		refreshSpectateList()
	end
end)
Players.PlayerRemoving:Connect(function(p)
	if p == spectateTarget then
		spectateEnabled = false
		spectateTarget = nil
		spectateStatus.Text = "No target selected"
		stopFollowBtn.Visible = false
		notify("Undercore", "Target left, stopped following", 3, WARNING, "info")
	end
	if spectateSubmenuVisible then
		refreshSpectateList()
	end
end)

-- FOLLOW LOGIC: copy target's movements with zero delay
trackConn(RunService.RenderStepped:Connect(function()
	if not spectateEnabled or not spectateTarget then return end

	local targetChar = spectateTarget.Character
	if not targetChar then return end
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local myChar = player.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end

	-- Copy exact CFrame (position + rotation) with slight offset behind
	myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 6)

	-- Copy Humanoid state (walk speed, jump, etc)
	local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
	local myHum = myChar:FindFirstChildOfClass("Humanoid")
	if targetHum and myHum then
		myHum.WalkSpeed = targetHum.WalkSpeed
		-- Copy jump state
		if targetHum:GetState() == Enum.HumanoidStateType.Jumping then
			myHum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		-- Copy sit state
		myHum.Sit = targetHum.Sit
	end

	-- Copy shift lock (camera offset) by matching target's facing direction
	-- The CFrame copy already handles rotation, so facing direction is matched

	-- Copy animations if possible
	local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
	local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and myHumanoid then
		local targetAnimator = targetHumanoid:FindFirstChildOfClass("Animator")
		local myAnimator = myHumanoid:FindFirstChildOfClass("Animator")
		if targetAnimator and myAnimator then
			-- Track and play same animations
			for _, track in ipairs(targetAnimator:GetPlayingAnimationTracks()) do
				local found = false
				for _, myTrack in ipairs(myAnimator:GetPlayingAnimationTracks()) do
					if myTrack.Animation and track.Animation and myTrack.Animation == track.Animation then
						found = true
						break
					end
				end
				if not found and track.Animation then
					pcall(function()
						myAnimator:LoadAnimation(track.Animation):Play()
					end)
				end
			end
		end
	end
end))

-- VISUAL PREVIEW PANEL (auto-opens on Visuals page, like teleport submenu)
local visualPreviewVisible = false

do

local visualPanel = Instance.new("Frame")
visualPanel.Name = "VisualPreviewPanel"
visualPanel.Size = UDim2.new(0, 250, 0, 400)
visualPanel.Position = UDim2.new(0, 0, 0, 0)
visualPanel.BackgroundColor3 = BG
visualPanel.BorderSizePixel = 0
visualPanel.Visible = false
visualPanel.ZIndex = 50
visualPanel.Parent = gui

local visualPanelCorner = Instance.new("UICorner")
visualPanelCorner.CornerRadius = UDim.new(0, 8)
visualPanelCorner.Parent = visualPanel

-- Sync visual panel position with mainFrame (right side, top aligned)
trackConn(RunService.RenderStepped:Connect(function()
	if visualPanel.Visible then
		visualPanel.Position = UDim2.new(
			0.5, mainFrame.Position.X.Offset + 320,
			0.5, mainFrame.Position.Y.Offset - 210
		)
		visualPanel.Size = UDim2.new(0, 250, 0, 420)
	end
end))

-- Title
local visualPreviewTitle = Instance.new("TextLabel")
visualPreviewTitle.Font = Enum.Font.GothamBold
visualPreviewTitle.TextSize = 14
visualPreviewTitle.TextColor3 = ACCENT
visualPreviewTitle.TextXAlignment = Enum.TextXAlignment.Left
visualPreviewTitle.BackgroundTransparency = 1
visualPreviewTitle.Size = UDim2.new(1, -20, 0, 30)
visualPreviewTitle.Position = UDim2.new(0, 12, 0, 8)
visualPreviewTitle.Text = "ESP Preview"
visualPreviewTitle.Parent = visualPanel

-- ViewportFrame for 3D character preview
local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Size = UDim2.new(1, -12, 0, 200)
viewportFrame.Position = UDim2.new(0, 6, 0, 38)
viewportFrame.BackgroundColor3 = BG_DARK
viewportFrame.BorderSizePixel = 0
viewportFrame.Parent = visualPanel

-- Build 2012 blocky grey R15 dummy character
local dummyModel = Instance.new("Model")
dummyModel.Name = "PreviewDummy"

local GREY = Color3.fromRGB(160, 160, 160)

local function makePart(name, size, pos, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Color = GREY
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent
	return part
end

-- R15 body parts (blocky 2012 style)
local dRoot = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 5, 0), dummyModel)
local dHead = makePart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 6.5, 0), dummyModel)
local dTorso = makePart("UpperTorso", Vector3.new(2, 1, 1), Vector3.new(0, 5.5, 0), dummyModel)
local dLowerTorso = makePart("LowerTorso", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), dummyModel)
local dLUpperArm = makePart("LeftUpperArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, 5.5, 0), dummyModel)
local dLLowerArm = makePart("LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, 4.5, 0), dummyModel)
local dLHand = makePart("LeftHand", Vector3.new(1, 1, 1), Vector3.new(-1.5, 3.5, 0), dummyModel)
local dRUpperArm = makePart("RightUpperArm", Vector3.new(1, 1, 1), Vector3.new(1.5, 5.5, 0), dummyModel)
local dRLowerArm = makePart("RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, 4.5, 0), dummyModel)
local dRHand = makePart("RightHand", Vector3.new(1, 1, 1), Vector3.new(1.5, 3.5, 0), dummyModel)
local dLUpperLeg = makePart("LeftUpperLeg", Vector3.new(1, 1, 1), Vector3.new(-0.5, 3.5, 0), dummyModel)
local dLLowerLeg = makePart("LeftLowerLeg", Vector3.new(1, 1, 1), Vector3.new(-0.5, 2.5, 0), dummyModel)
local dLFoot = makePart("LeftFoot", Vector3.new(1, 1, 1), Vector3.new(-0.5, 1.5, 0), dummyModel)
local dRUpperLeg = makePart("RightUpperLeg", Vector3.new(1, 1, 1), Vector3.new(0.5, 3.5, 0), dummyModel)
local dRLowerLeg = makePart("RightLowerLeg", Vector3.new(1, 1, 1), Vector3.new(0.5, 2.5, 0), dummyModel)
local dRFoot = makePart("RightFoot", Vector3.new(1, 1, 1), Vector3.new(0.5, 1.5, 0), dummyModel)

-- Add Humanoid so it looks like a character
local dHum = Instance.new("Humanoid")
dHum.Health = 100
dHum.MaxHealth = 100
dHum.Parent = dummyModel

dummyModel.Parent = viewportFrame

-- Camera for viewport
local vpCamera = Instance.new("Camera")
vpCamera.CFrame = CFrame.new(Vector3.new(0, 4, 12), Vector3.new(0, 4, 0))
viewportFrame.CurrentCamera = vpCamera
vpCamera.Parent = viewportFrame

-- ESP preview overlay (2D frames drawn on top of viewport)
local espPreviewContainer = Instance.new("Frame")
espPreviewContainer.Size = UDim2.new(1, 0, 1, 0)
espPreviewContainer.BackgroundTransparency = 1
espPreviewContainer.Parent = viewportFrame

-- ESP box preview (Frame border)
local previewBox = Instance.new("Frame")
previewBox.BorderSizePixel = 1
previewBox.BorderColor3 = ACCENT
previewBox.BackgroundTransparency = 1
previewBox.Visible = false
previewBox.Parent = espPreviewContainer

-- ESP health bar preview (vertical line on left)
local previewHealth = Instance.new("Frame")
previewHealth.BorderSizePixel = 0
previewHealth.BackgroundColor3 = GREEN
previewHealth.Visible = false
previewHealth.Parent = espPreviewContainer

-- ESP name preview
local previewName = Instance.new("TextLabel")
previewName.Font = Enum.Font.Gotham
previewName.TextSize = 13
previewName.TextColor3 = TEXT_WHITE
previewName.BackgroundTransparency = 1
previewName.Size = UDim2.new(0, 100, 0, 16)
previewName.Position = UDim2.new(0.5, -50, 0, 0)
previewName.Visible = false
previewName.Parent = espPreviewContainer

-- ESP role preview
local previewRole = Instance.new("TextLabel")
previewRole.Font = Enum.Font.Gotham
previewRole.TextSize = 12
previewRole.TextColor3 = ACCENT
previewRole.BackgroundTransparency = 1
previewRole.Size = UDim2.new(0, 100, 0, 14)
previewRole.Position = UDim2.new(0.5, -50, 0, 0)
previewRole.Visible = false
previewRole.Parent = espPreviewContainer

-- ESP distance preview
local previewDist = Instance.new("TextLabel")
previewDist.Font = Enum.Font.Gotham
previewDist.TextSize = 12
previewDist.TextColor3 = TEXT_GRAY
previewDist.BackgroundTransparency = 1
previewDist.Size = UDim2.new(0, 60, 0, 14)
previewDist.Position = UDim2.new(0.5, -30, 1, -14)
previewDist.Visible = false
previewDist.Parent = espPreviewContainer

-- ESP tracer preview (line from bottom center to box)
local previewTracer = Instance.new("Frame")
previewTracer.BorderSizePixel = 1
previewTracer.BorderColor3 = ACCENT
previewTracer.BackgroundColor3 = ACCENT
previewTracer.Visible = false
previewTracer.Parent = espPreviewContainer

-- Update ESP preview positions based on dummy position in viewport
local previewRoleCycle = 0
local previewRoles = { "Innocent", "Sheriff", "Murderer" }
local previewRoleColors = { GREEN, ACCENT, RED }

trackConn(RunService.RenderStepped:Connect(function()
	if not visualPanel.Visible then return end

	-- Cycle role every 3 seconds for preview
	previewRoleCycle = previewRoleCycle + 0.01
	local roleIdx = math.floor(previewRoleCycle % 3) + 1
	local currentRole = previewRoles[roleIdx]
	local currentRoleColor = previewRoleColors[roleIdx]

	-- Get dummy head and root screen position
	local cam = viewportFrame.CurrentCamera
	if not cam then return end

	local headPos, headOnScreen = cam:WorldToViewportPoint(dHead.Position + Vector3.new(0, 1, 0))
	local rootPos, rootOnScreen = cam:WorldToViewportPoint(dRoot.Position - Vector3.new(0, 3, 0))

	if not headOnScreen and not rootOnScreen then
		previewBox.Visible = false
		previewHealth.Visible = false
		previewName.Visible = false
		previewRole.Visible = false
		previewDist.Visible = false
		previewTracer.Visible = false
		return
	end

	local vpSize = viewportFrame.AbsoluteSize
	local height = math.abs(headPos.Y - rootPos.Y)
	local width = height * 0.5

	-- Scale to viewport frame
	local boxX = vpSize.X / 2 - width / 2
	local boxY = headPos.Y
	-- Clamp to viewport bounds
	if boxY < 0 then boxY = 0 end

	-- ESP Box
	if _G.Undercore.ESP then
		previewBox.Size = UDim2.new(0, width, 0, height)
		previewBox.Position = UDim2.new(0, boxX, 0, boxY)
		if _G.Undercore.ESPRoleColor then
			previewBox.BorderColor3 = currentRoleColor
		elseif _G.Undercore.ESPMurdererHL and currentRole == "Murderer" then
			previewBox.BorderColor3 = RED
		else
			previewBox.BorderColor3 = ACCENT
		end
		previewBox.Visible = true
	else
		previewBox.Visible = false
	end

	-- ESP Name
	if _G.Undercore.ESP and _G.Undercore.ESPName then
		previewName.Position = UDim2.new(0, vpSize.X / 2 - 50, 0, boxY - 18)
		previewName.Text = "Player1"
		previewName.TextColor3 = _G.Undercore.ESPRoleColor and currentRoleColor or TEXT_WHITE
		previewName.Visible = true
	else
		previewName.Visible = false
	end

	-- ESP Role
	if _G.Undercore.ESP and _G.Undercore.ESPRole then
		previewRole.Position = UDim2.new(0, vpSize.X / 2 - 50, 0, boxY - 32)
		previewRole.Text = "[" .. currentRole .. "]"
		previewRole.TextColor3 = currentRoleColor
		previewRole.Visible = true
	else
		previewRole.Visible = false
	end

	-- ESP Distance
	if _G.Undercore.ESP and _G.Undercore.ESPDist then
		previewDist.Position = UDim2.new(0, vpSize.X / 2 - 30, 0, boxY + height + 2)
		previewDist.Text = "15m"
		previewDist.Visible = true
	else
		previewDist.Visible = false
	end

	-- ESP Health bar
	if _G.Undercore.ESP and _G.Undercore.ESPHealth then
		previewHealth.Size = UDim2.new(0, 3, 0, height * 0.8)
		previewHealth.Position = UDim2.new(0, boxX - 5, 0, boxY)
		previewHealth.BackgroundColor3 = GREEN
		previewHealth.Visible = true
	else
		previewHealth.Visible = false
	end

	-- ESP Tracer
	if _G.Undercore.ESP and _G.Undercore.ESPTracer then
		local tracerStartX = vpSize.X / 2
		local tracerStartY = vpSize.Y
		local tracerEndX = vpSize.X / 2
		local tracerEndY = boxY + height / 2
		local dX = tracerEndX - tracerStartX
		local dY = tracerEndY - tracerStartY
		local len = math.sqrt(dX * dX + dY * dY)
		local angle = math.atan2(dY, dX)
		previewTracer.Size = UDim2.new(0, len, 0, 1)
		previewTracer.Position = UDim2.new(0, tracerStartX, 0, tracerStartY)
		previewTracer.Rotation = math.deg(angle)
		if _G.Undercore.ESPRoleColor then
			previewTracer.BorderColor3 = currentRoleColor
			previewTracer.BackgroundColor3 = currentRoleColor
		else
			previewTracer.BorderColor3 = ACCENT
			previewTracer.BackgroundColor3 = ACCENT
		end
		previewTracer.Visible = true
	else
		previewTracer.Visible = false
	end
end))

-- ESP toggle buttons inside preview panel
local previewBtnY = 248
local previewButtons = {}

local function createPreviewButton(text, getY, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -12, 0, 28)
	btn.Position = UDim2.new(0, 6, 0, getY)
	btn.BackgroundColor3 = BG_DARK
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.TextColor3 = TEXT_GRAY
	btn.Text = text
	btn.AutoButtonColor = false
	btn.Parent = visualPanel

	btn.MouseButton1Click:Connect(function()
		playRandomPageSound()
		callback()
	end)

	btn.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 0.15)
	end)

	return btn
end

local function updatePreviewButtonStyle(btn, active)
	if active then
		btn.BackgroundColor3 = ACCENT
		btn.TextColor3 = TEXT_WHITE
	else
		btn.BackgroundColor3 = BG_DARK
		btn.TextColor3 = TEXT_GRAY
	end
end

local pBtnY = 248
local function nextBtnY()
	local y = pBtnY
	pBtnY = pBtnY + 32
	return y
end

local previewBtnBox = createPreviewButton("ESP Box", nextBtnY(), function()
	_G.Undercore.ESP = not _G.Undercore.ESP
	espToggle.set(_G.Undercore.ESP)
	updatePreviewButtonStyle(previewBtnBox, _G.Undercore.ESP)
end)

local previewBtnName = createPreviewButton("ESP Names", nextBtnY(), function()
	_G.Undercore.ESPName = not _G.Undercore.ESPName
	espName.set(_G.Undercore.ESPName)
	updatePreviewButtonStyle(previewBtnName, _G.Undercore.ESPName)
end)

local previewBtnDist = createPreviewButton("ESP Distance", nextBtnY(), function()
	_G.Undercore.ESPDist = not _G.Undercore.ESPDist
	espDist.set(_G.Undercore.ESPDist)
	updatePreviewButtonStyle(previewBtnDist, _G.Undercore.ESPDist)
end)

local previewBtnHealth = createPreviewButton("ESP Health", nextBtnY(), function()
	_G.Undercore.ESPHealth = not _G.Undercore.ESPHealth
	espHealth.set(_G.Undercore.ESPHealth)
	updatePreviewButtonStyle(previewBtnHealth, _G.Undercore.ESPHealth)
end)

local previewBtnTracer = createPreviewButton("ESP Tracers", nextBtnY(), function()
	_G.Undercore.ESPTracer = not _G.Undercore.ESPTracer
	espTracer.set(_G.Undercore.ESPTracer)
	updatePreviewButtonStyle(previewBtnTracer, _G.Undercore.ESPTracer)
end)

-- Show/hide functions for visual preview panel
showVisualPreview = function()
	if visualPreviewVisible then return end
	visualPreviewVisible = true
	playRandomPageSound()

	visualPanel.Visible = true
	visualPanel.Size = UDim2.new(0, 0, 0, 420)

	local sizeTween = TweenService:Create(visualPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 250, 0, 420) })
	sizeTween:Play()
	sizeTween.Completed:Wait()
end

hideVisualPreview = function()
	if not visualPreviewVisible then return end
	visualPreviewVisible = false
	playRandomPageSound()

	local sizeTween = TweenService:Create(visualPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 420) })
	sizeTween:Play()
	sizeTween.Completed:Wait()

	visualPanel.Visible = false
end

end -- do block for visual preview panel

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
		espRole.set(false)
		espRoleColor.set(false)
		espMurdererHighlight.set(false)
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
		_G.Undercore.ESPRole = false
		_G.Undercore.ESPRoleColor = false
		_G.Undercore.ESPMurdererHL = false
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
local showExitDialog
local hideExitDialog
local exitDialogVisible = false
local espObjects = {}

do
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
dialogFrame.BackgroundColor3 = CARD_BG
dialogFrame.BorderSizePixel = 0
dialogFrame.Visible = false
dialogFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
dialogFrame.GroupTransparency = 1
dialogFrame.ZIndex = 10
dialogFrame.Parent = blurFrame

local dialogCorner = Instance.new("UICorner")
dialogCorner.CornerRadius = UDim.new(0, 8)
dialogCorner.Parent = dialogFrame

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
cancelBtn.TextColor3 = TEXT_NORMAL
cancelBtn.Text = "Cancel"
cancelBtn.BackgroundColor3 = CARD_HOVER
cancelBtn.BorderSizePixel = 0
cancelBtn.Size = UDim2.new(0, 100, 0, 36)
cancelBtn.Position = UDim2.new(0, 20, 0, 145)
cancelBtn.Parent = dialogFrame

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 6)
cancelCorner.Parent = cancelBtn

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

local reloadCorner = Instance.new("UICorner")
reloadCorner.CornerRadius = UDim.new(0, 6)
reloadCorner.Parent = reloadBtn

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

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 6)
confirmCorner.Parent = confirmBtn

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

local function showExitDialogImpl()
	if exitDialogVisible then return end
	exitDialogVisible = true
	playSound(SOUND_NOTIF, 0.5)

	blurFrame.Visible = true
	blurFrame.BackgroundTransparency = 1
	dialogFrame.Visible = true
	dialogFrame.Size = UDim2.new(0, 0, 0, 0)
	dialogFrame.GroupTransparency = 1

	local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 24 })
	blurTween:Play()

	local bgTween = TweenService:Create(blurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 })
	bgTween:Play()

	local dialogTween = TweenService:Create(dialogFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 380, 0, 220), GroupTransparency = 0 })
	dialogTween:Play()
end

local function hideExitDialogImpl()
	if not exitDialogVisible then return end
	exitDialogVisible = false

	local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = 0 })
	blurTween:Play()

	local bgTween = TweenService:Create(blurFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	bgTween:Play()

	local dialogTween = TweenService:Create(dialogFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 0, 0, 0), GroupTransparency = 1 })
	dialogTween:Play()

	dialogTween.Completed:Wait()
	blurFrame.Visible = false
	dialogFrame.Visible = false
end

local function resetAllCheats()
	spectateEnabled = false
	spectateTarget = nil
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
		if obj.role then obj.role:Remove() end
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

	-- Stop background loops during reload
	terminated = true

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

	-- Mark as terminated to stop all background loops
	terminated = true

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

showExitDialog = showExitDialogImpl
hideExitDialog = hideExitDialogImpl
end -- do block for exit dialog

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
exitBtn.Size = UDim2.new(1, 0, 0, 38)
exitBtn.Parent = settingsPage

local exitBtnCorner = Instance.new("UICorner")
exitBtnCorner.CornerRadius = UDim.new(0, 6)
exitBtnCorner.Parent = exitBtn

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
aboutVersion.TextColor3 = ACCENT
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
toggleBtn.TextColor3 = TEXT_GRAY
toggleBtn.BackgroundColor3 = BG_DARK
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.new(0, 32, 0, 32)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.ZIndex = 50
toggleBtn.Visible = false
toggleBtn.Parent = gui

local toggleBtnCorner = Instance.new("UICorner")
toggleBtnCorner.CornerRadius = UDim.new(0, 6)
toggleBtnCorner.Parent = toggleBtn

openMenu = function()
	playRandomPageSound()
	menuVisible = true
	mainFrame.Visible = true
	mainFrame.Size = UDim2.new(0, 640, 0, 0)
	mainFrame.GroupTransparency = 1

	local sizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 640, 0, 420), GroupTransparency = 0 })
	sizeTween:Play()
	sizeTween.Completed:Wait()
end

closeMenu = function()
	playRandomPageSound()

	-- Close teleport submenu if open (with animation)
	if teleportSubmenuVisible then
		hideTeleportSubmenu()
	end

	-- Close spectate submenu if open (with animation)
	if spectateSubmenuVisible then
		hideSpectateSubmenu()
	end

	-- Close visual preview panel if open (with animation)
	if visualPreviewVisible then
		hideVisualPreview()
	end

	local sizeTween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Size = UDim2.new(0, 640, 0, 0), GroupTransparency = 1 })
	sizeTween:Play()
	sizeTween.Completed:Wait()

	menuVisible = false
	mainFrame.Visible = false
	mainFrame.Size = UDim2.new(0, 640, 0, 420)
	mainFrame.GroupTransparency = 0
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
	ESPRole = false, ESPRoleColor = false, ESPMurdererHL = false,
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

-- FLING (KILASIK method: BodyVelocity anchor + teleport into target + collision impulse)
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

	-- Safety timeout
	local safetyTimer = task.delay(10, function()
		flingBusy = false
	end)

	-- Save position when our velocity is low (not already being flung)
	if root.Velocity.Magnitude < 50 then
		savedCFrame = root.CFrame
	end

	-- Switch camera to target
	if tHead then
		Workspace.CurrentCamera.CameraSubject = tHead
	elseif handle then
		Workspace.CurrentCamera.CameraSubject = handle
	elseif tHum then
		Workspace.CurrentCamera.CameraSubject = tHum
	end

	-- Disable FallenPartsDestroyHeight
	if not oldFallenHeight then
		oldFallenHeight = Workspace.FallenPartsDestroyHeight
	end
	Workspace.FallenPartsDestroyHeight = 0/0

	-- BodyVelocity anchors us in place inside target - all collision impulse goes to target
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.zero
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Parent = root

	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

	-- FPos: teleport our root into target and set massive velocity + rotvelocity
	local function FPos(basePart, pos, ang)
		pcall(function()
			root.CFrame = CFrame.new(basePart.Position) * pos * ang
			char:SetPrimaryPartCFrame(CFrame.new(basePart.Position) * pos * ang)
			root.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
			root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
		end)
	end

	-- SFBasePart: rapidly teleport into target from alternating offsets
	local function SFBasePart(basePart)
		local timeToWait = duration or 2
		local startTime = tick()
		local angle = 0
		repeat
			if root and tHum and tHum.Health > 0 then
				if basePart.Velocity.Magnitude < 50 then
					angle = angle + 100
					FPos(basePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, 1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0) + tHum.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
				else
					FPos(basePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, -tHum.WalkSpeed), CFrame.Angles(0, 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, 1.5, tHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
					task.wait()
					FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
					task.wait()
				end
			end
		until startTime + timeToWait < tick() or not _G.Undercore.Fling or not _G.Undercore.FlingAuto
	end

	pcall(function()
		SFBasePart(targetPart)
	end)

	-- Cleanup
	bv:Destroy()
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
	Workspace.CurrentCamera.CameraSubject = hum

	-- Restore position (loop until close to saved position)
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

	if safetyTimer then
		task.cancel(safetyTimer)
	end

	flingBusy = false
end

-- FLING AURA: fling anyone within range (fast - 0.5s per target)
task.spawn(function()
	while not terminated do
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

-- AUTO FLING: continuously cycle through all players (KILASIK pattern)
task.spawn(function()
	while not terminated do
		task.wait(0.1)
		if not _G.Undercore.FlingAuto then
			-- Return to saved position when auto fling turns off
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

		-- Cycle through all players and fling each one (2s per target, 0.1s between)
		for _, other in ipairs(Players:GetPlayers()) do
			if not _G.Undercore.FlingAuto or terminated then break end
			if other ~= player and other.Character then
				local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
				if otherHum and otherHum.Health > 0 and not otherHum.Sit then
					flingTarget(other, 2, nil)
					task.wait(0.1)
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

-- ANTI-FLING (refactored: collision disable + impulse zeroing + position restore)
-- Disabled while flingBusy to avoid conflict with own fling
local antiFlingLastCFrame = nil
local antiFlingLastTick = tick()

trackConn(RunService.Stepped:Connect(function()
	if not _G.Undercore.AntiFling then
		antiFlingLastCFrame = nil
		return
	end
	-- Skip if we're actively flinging someone
	if flingBusy then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	-- 1. Disable collision with any player whose velocity is abnormally high
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local otherVel = otherRoot.AssemblyLinearVelocity
				if otherVel.Magnitude > 200 then
					-- Set CanCollide false on our parts to avoid collision impulse
					for _, myPart in ipairs(char:GetDescendants()) do
						if myPart:IsA("BasePart") and myPart.CanCollide then
							pcall(function() myPart.CanCollide = false end)
							-- Restore collision after delay
							task.delay(1, function()
								pcall(function() myPart.CanCollide = true end)
							end)
						end
					end
				end
			end
		end
	end

	-- 2. Zero out abnormal velocity/rotation on our root
	pcall(function()
		if root.AssemblyLinearVelocity.Magnitude > 300 then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Velocity = Vector3.zero
		end
		if root.AssemblyAngularVelocity.Magnitude > 50 then
			root.AssemblyAngularVelocity = Vector3.zero
			root.RotVelocity = Vector3.zero
		end
	end)

	-- 3. Position restore if we got moved significantly
	local currentPos = root.Position
	local currentTick = tick()

	if not antiFlingLastCFrame then
		antiFlingLastCFrame = root.CFrame
		antiFlingLastTick = currentTick
		return
	end

	local dt = currentTick - antiFlingLastTick
	if dt > 0 then
		local velocity = (currentPos - antiFlingLastCFrame.Position) / dt
		if velocity.Magnitude > 100 then
			-- Being flung - restore position, keep camera rotation
			pcall(function()
				root.CFrame = CFrame.new(antiFlingLastCFrame.Position) * (root.CFrame - root.CFrame.Position)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.Velocity = Vector3.zero
				root.RotVelocity = Vector3.zero
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		else
			antiFlingLastCFrame = root.CFrame
		end
	end
	antiFlingLastTick = currentTick
end))

-- MM2 ROLE DETECTION
local ROLE_MURDERER = "Murderer"
local ROLE_SHERIFF = "Sheriff"
local ROLE_INNOCENT = "Innocent"
local ROLE_HERO = "Hero"
local ROLE_UNKNOWN = "?"

local ROLE_COLORS = {
	[ROLE_MURDERER] = RED,
	[ROLE_SHERIFF] = ACCENT,
	[ROLE_INNOCENT] = GREEN,
	[ROLE_HERO] = Color3.fromRGB(255, 170, 0),
	[ROLE_UNKNOWN] = TEXT_GRAY,
}

local function getMM2Role(plr)
	local char = plr.Character
	if not char then return ROLE_UNKNOWN end
	-- Check for knife (murderer weapon) in character
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") then
			local name = item.Name:lower()
			if name:match("knife") or name:match("blade") or name:match("dagger") or name:match("machete") then
				return ROLE_MURDERER
			end
			if name:match("gun") or name:match("pistol") or name:match("revolver") or name:match("sheriff") then
				return ROLE_SHERIFF
			end
		end
	end
	-- Check backpack for weapons
	local backpack = plr:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				local name = item.Name:lower()
				if name:match("knife") or name:match("blade") or name:match("dagger") or name:match("machete") then
					return ROLE_MURDERER
				end
				if name:match("gun") or name:match("pistol") or name:match("revolver") or name:match("sheriff") then
					return ROLE_SHERIFF
				end
			end
		end
	end
	return ROLE_INNOCENT
end

-- ESP
local function clearESP()
	for _, obj in pairs(espObjects) do
		if obj.box then obj.box:Remove() end
		if obj.name then obj.name:Remove() end
		if obj.dist then obj.dist:Remove() end
		if obj.health then obj.health:Remove() end
		if obj.tracer then obj.tracer:Remove() end
		if obj.role then obj.role:Remove() end
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

	local roleLbl = Drawing.new("Text")
	roleLbl.Size = 12
	roleLbl.Center = true
	roleLbl.Color = TEXT_GRAY
	roleLbl.Visible = false

	espObjects[p] = { box = box, name = nameLbl, dist = distLbl, health = healthBar, tracer = tracer, role = roleLbl }
end

local function removeESPForPlayer(p)
	local obj = espObjects[p]
	if obj then
		if obj.box then obj.box:Remove() end
		if obj.name then obj.name:Remove() end
		if obj.dist then obj.dist:Remove() end
		if obj.health then obj.health:Remove() end
		if obj.tracer then obj.tracer:Remove() end
		if obj.role then obj.role:Remove() end
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
		-- Hide everything if ESP is off
		if not _G.Undercore.ESP then
			obj.box.Visible = false
			obj.name.Visible = false
			obj.dist.Visible = false
			obj.health.Visible = false
			obj.tracer.Visible = false
			obj.role.Visible = false
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
			obj.role.Visible = false
			continue
		end

		local pos, onScreen = camera:WorldToViewportPoint(pRoot.Position)
		if not onScreen then
			obj.box.Visible = false
			obj.name.Visible = false
			obj.dist.Visible = false
			obj.health.Visible = false
			obj.tracer.Visible = false
			obj.role.Visible = false
			continue
		end

		-- MM2 role detection
		local role = getMM2Role(p)
		local roleColor = ROLE_COLORS[role] or ACCENT

		-- Determine box/tracer color: role-based if enabled, otherwise ACCENT
		local espColor = ACCENT
		if _G.Undercore.ESPRoleColor then
			espColor = roleColor
		end

		-- Murderer highlight: thicker box + brighter color
		if _G.Undercore.ESPMurdererHL and role == ROLE_MURDERER then
			obj.box.Thickness = 3
			obj.box.Color = RED
		else
			obj.box.Thickness = 1
			obj.box.Color = espColor
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
			obj.name.Color = _G.Undercore.ESPRoleColor and roleColor or TEXT_WHITE
			obj.name.Visible = true
		else
			obj.name.Visible = false
		end

		-- MM2 Role text
		if _G.Undercore.ESPRole then
			obj.role.Position = Vector2.new(pos.X, headPos.Y - 30)
			obj.role.Text = "[" .. role .. "]"
			obj.role.Color = roleColor
			obj.role.Visible = true
		else
			obj.role.Visible = false
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
			obj.tracer.Color = espColor
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
		while not terminated do
			task.wait(10)
			if terminated then break end
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
