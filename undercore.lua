-- Undercore v3.0.0 - Piano Autoplayer
-- Based on TALENTLESS piano engine by hellohellohell012321
-- Inject via executor

local SCRIPT_VERSION = "3.0.0"
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

-- Colors (Material 3 Dark Theme)
local M3_SURFACE = Color3.fromRGB(28, 27, 31)       -- #1C1B1F surface
local M3_SURFACE_VAR = Color3.fromRGB(73, 69, 79)    -- #49454F surface variant
local M3_SURFACE_CONTAINER = Color3.fromRGB(33, 31, 38) -- #211F26 surface container
local M3_SURFACE_CONTAINER_HIGH = Color3.fromRGB(54, 50, 57) -- #363239 high container
local M3_PRIMARY = Color3.fromRGB(208, 188, 255)     -- #D0BCFF primary
local M3_ON_PRIMARY = Color3.fromRGB(56, 30, 114)    -- #381E72 on primary
local M3_PRIMARY_CONTAINER = Color3.fromRGB(79, 55, 139) -- #4F378B primary container
local M3_ON_PRIMARY_CONTAINER = Color3.fromRGB(234, 221, 255) -- #EADDFF on primary container
local M3_SECONDARY = Color3.fromRGB(204, 194, 220)   -- #CCC2DC secondary
local M3_SECONDARY_CONTAINER = Color3.fromRGB(74, 68, 88) -- #4A4458 secondary container
local M3_TERTIARY = Color3.fromRGB(239, 184, 200)    -- #EFB8C8 tertiary
local M3_TERTIARY_CONTAINER = Color3.fromRGB(125, 82, 96) -- #7D5260 tertiary container
local M3_ERROR = Color3.fromRGB(242, 184, 181)       -- #F2B8B5 error
local M3_ERROR_CONTAINER = Color3.fromRGB(140, 29, 24) -- #8C1D18 error container
local M3_ON_ERROR = Color3.fromRGB(96, 20, 16)       -- #601410 on error
local M3_ON_SURFACE = Color3.fromRGB(230, 224, 233)  -- #E6E0E9 on surface
local M3_ON_SURFACE_VAR = Color3.fromRGB(202, 196, 208) -- #CAC4D0 on surface variant
local M3_OUTLINE = Color3.fromRGB(147, 143, 153)     -- #938F99 outline
local M3_OUTLINE_VAR = Color3.fromRGB(73, 69, 79)    -- #49454F outline variant

-- Aliases (only keep used ones to save local registers)
local ACCENT = M3_PRIMARY
local TEXT_WHITE = M3_ON_SURFACE
local TEXT_GRAY = M3_ON_SURFACE_VAR
local GREEN = Color3.fromRGB(169, 253, 163)
local RED = M3_ERROR
local WARNING = Color3.fromRGB(255, 216, 107)

-- Sound IDs
local SOUND_INJECT = "124834506603771"
local SOUND_NOTIF = "85513921738461"
local SOUND_SUCCESS = "134998934323294"
local SOUND_ERROR = "80779065737564"
local SOUND_HOVER = "81092680156069"
local SOUND_MODAL = "18999173729"
local SOUND_PAGE = { "98884317334085" }

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
	local allSounds = { SOUND_INJECT, SOUND_NOTIF, SOUND_SUCCESS, SOUND_ERROR, SOUND_HOVER, SOUND_MODAL }
	for _, id in ipairs(allSounds) do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Parent = workspace
		task.delay(5, function() pcall(function() s:Destroy() end) end)
	end
end

local function playRandomPageSound()
	local idx = math.random(1, #SOUND_PAGE)
	playSound(SOUND_PAGE[idx], 1.5)
end

-- Notification icons (top-level so preloader can access them)
local NOTIF_ICONS = {
	info = "rbxassetid://72432575303550",
	error = "rbxassetid://117665558668208",
	success = "rbxassetid://137280763593602",
}

-- ===================
-- NOTIFICATION SYSTEM
-- ===================
local notify
do
local NOTIF_WIDTH = 340
local notifications = {}

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "UndercoreNotif"
notifGui.ResetOnSpawn = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.DisplayOrder = 100
notifGui.IgnoreGuiInset = true
protectGui(notifGui)
notifGui.Parent = uiParent

local NOTIF_GAP = 16
local NOTIF_BOTTOM = 12

-- Full-screen container so card positions are relative to screen, not a small frame
local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, 0)
container.Position = UDim2.new(0, 0, 0, 0)
container.BackgroundTransparency = 1
container.Parent = notifGui

local function recalcPositions()
	local y = 0
	for i = #notifications, 1, -1 do
		local data = notifications[i]
		if not data.dismissed then
			TweenService:Create(data.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -y - data.height - NOTIF_BOTTOM) }):Play()
			y = y + data.height + NOTIF_GAP
		end
	end
end

local function dismiss(data)
	if data.dismissed then return end
	data.dismissed = true

	local card = data.frame
	local currentY = card.Position.Y.Offset

	-- Slide up slightly + fade out smoothly (more negative = higher on screen)
	local slideUp = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { 
		Position = UDim2.new(0.5, 0, 1, currentY + 30),
		GroupTransparency = 1 
	})
	slideUp:Play()
	slideUp.Completed:Wait()
	card:Destroy()
	for i, n in ipairs(notifications) do
		if n == data then table.remove(notifications, i) break end
	end
	recalcPositions()
end

local NOTIF_COLORS = {
	info = WARNING,
	error = RED,
	success = GREEN,
}

notify = function(title, message, duration, color, notifType)
	duration = duration or 4
	notifType = notifType or "info"
	color = NOTIF_COLORS[notifType] or color or WARNING
	if notifType == "error" then
		playSound(SOUND_ERROR, 0.5)
	elseif notifType == "success" then
		playSound(SOUND_SUCCESS, 0.8)
	else
		playSound(SOUND_NOTIF, 0.5)
	end
	local iconId = NOTIF_ICONS[notifType] or NOTIF_ICONS.info

	local y = 0
	for _, n in ipairs(notifications) do
		if not n.dismissed then y = y + n.height + NOTIF_GAP end
	end

	local card = Instance.new("CanvasGroup")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Size = UDim2.new(0, NOTIF_WIDTH, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0.5, 0, 1, 50)
	card.GroupTransparency = 1
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card

	-- Icon on left, vertically centered
	local icon = Instance.new("ImageLabel")
	icon.Name = "NotifIcon"
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 16, 0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image = iconId
	icon.ImageColor3 = color
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 6
	icon.Parent = card

	-- M3: no right strip, use subtle left accent dot instead
	local accentDot = Instance.new("Frame")
	accentDot.Name = "AccentDot"
	accentDot.Size = UDim2.new(0, 8, 0, 8)
	accentDot.AnchorPoint = Vector2.new(0, 0.5)
	accentDot.Position = UDim2.new(0, 44, 0.5, 0)
	accentDot.BackgroundColor3 = color
	accentDot.BorderSizePixel = 0
	accentDot.ZIndex = 6
	accentDot.Visible = false
	accentDot.Parent = card

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = accentDot

	-- Content
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -72, 0, 0)
	content.Position = UDim2.new(0, 52, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = content

	local msg = Instance.new("TextLabel")
	msg.Font = Enum.Font.BuilderSans
	msg.TextSize = 14
	msg.TextColor3 = M3_ON_SURFACE
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
		-- Measure height reliably using TextService
		local textWidth = NOTIF_WIDTH - 72 - 16
		local textSize = TextService:GetTextSize(message, 14, Enum.Font.BuilderSans, Vector2.new(textWidth, math.huge))
		local height = textSize.Y + 32
		if height < 56 then
			height = 56
		end
		local data = { frame = card, height = height, dismissed = false }
		table.insert(notifications, 1, data)

		local targetY = 0
		for _, n in ipairs(notifications) do
			if n ~= data and not n.dismissed then targetY = targetY + n.height + NOTIF_GAP end
		end

		local slideIn = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { 
			Position = UDim2.new(0.5, 0, 1, -targetY - height - NOTIF_BOTTOM),
			GroupTransparency = 0 
		})
		slideIn:Play()
		slideIn.Completed:Wait()

		task.delay(duration, function() dismiss(data) end)
	end)
end
end -- notification system do block

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
mainFrame.BackgroundColor3 = M3_SURFACE
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = false
mainFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.Parent = gui

-- M3 large rounded corners + shadow (no need to keep references)
do
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 28)
mainCorner.Parent = mainFrame

local mainShadow = Instance.new("UIStroke")
mainShadow.Color = Color3.fromRGB(0, 0, 0)
mainShadow.Thickness = 0
mainShadow.Transparency = 0.8
mainShadow.Parent = mainFrame
end

-- Title bar (M3 top app bar style)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = M3_SURFACE
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = mainFrame

-- Dragging + update banner (scoped to free registers)
local updateBanner
local updateIcon
local updateText
do
local dragging = false
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

trackConn(UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if dragging then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end
end))

local titleLogo = Instance.new("ImageLabel")
titleLogo.Name = "Logo"
titleLogo.Size = UDim2.new(0, 22, 0, 22)
titleLogo.Position = UDim2.new(0, 12, 0.5, -11)
titleLogo.BackgroundTransparency = 1
titleLogo.Image = "rbxassetid://78552548457734"
titleLogo.ScaleType = Enum.ScaleType.Fit
titleLogo.ImageColor3 = M3_PRIMARY
titleLogo.ZIndex = 5
titleLogo.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Font = Enum.Font.BuilderSansMedium
titleText.TextSize = 16
titleText.TextColor3 = M3_PRIMARY
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 42, 0, 0)
titleText.Text = "Undercore"
titleText.Parent = titleBar

updateBanner = Instance.new("TextButton")
updateBanner.Name = "UpdateBanner"
updateBanner.BackgroundTransparency = 1
updateBanner.Size = UDim2.new(0, 220, 1, 0)
updateBanner.Position = UDim2.new(0, 130, 0, 0)
updateBanner.Text = ""
updateBanner.Visible = false
updateBanner.Parent = titleBar

updateIcon = Instance.new("ImageLabel")
updateIcon.Name = "UpdateIcon"
updateIcon.Size = UDim2.new(0, 16, 0, 16)
updateIcon.Position = UDim2.new(0, 0, 0.5, -8)
updateIcon.BackgroundTransparency = 1
updateIcon.Image = "rbxassetid://139640004463981"
updateIcon.ImageColor3 = ACCENT
updateIcon.Visible = false
updateIcon.Parent = updateBanner

updateText = Instance.new("TextLabel")
updateText.Name = "UpdateText"
updateText.Font = Enum.Font.BuilderSans
updateText.TextSize = 11
updateText.TextColor3 = M3_PRIMARY
updateText.TextXAlignment = Enum.TextXAlignment.Left
updateText.TextYAlignment = Enum.TextYAlignment.Center
updateText.BackgroundTransparency = 1
updateText.Size = UDim2.new(1, -20, 1, 0)
updateText.Position = UDim2.new(0, 20, 0, 0)
updateText.Text = "New update available - click to restart"
updateText.Visible = false
updateText.Parent = updateBanner
end

-- Left navigation (M3 navigation rail)
local navFrame = Instance.new("ScrollingFrame")
navFrame.Size = UDim2.new(0, 56, 1, -48)
navFrame.Position = UDim2.new(0, 0, 0, 48)
navFrame.ScrollBarThickness = 0
navFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
navFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
navFrame.BackgroundColor3 = M3_SURFACE
navFrame.BorderSizePixel = 0
navFrame.Active = false
navFrame.Parent = mainFrame

do
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 2)
navLayout.Parent = navFrame

local navPad = Instance.new("UIPadding")
navPad.PaddingTop = UDim.new(0, 4)
navPad.PaddingBottom = UDim.new(0, 4)
navPad.Parent = navFrame
end

-- Right content (M3 surface)
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -56, 1, -48)
contentFrame.Position = UDim2.new(0, 56, 0, 48)
contentFrame.BackgroundColor3 = M3_SURFACE
contentFrame.BorderSizePixel = 0
contentFrame.Active = false
contentFrame.Parent = mainFrame

do
local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 16)
contentPad.PaddingBottom = UDim.new(0, 16)
contentPad.PaddingLeft = UDim.new(0, 16)
contentPad.PaddingRight = UDim.new(0, 16)
contentPad.Parent = contentFrame
end

-- Pages
local pages = {}
local navButtons = {}

local NAV_ICONS = {
	["Songs"] = "rbxassetid://93101474340373",
	["Player"] = "rbxassetid://95237403972033",
	["Market"] = "rbxassetid://108927893786063",
	["Keybinds"] = "rbxassetid://93982901670694",
	["Settings"] = "rbxassetid://93982901670694",
	["About"] = "rbxassetid://78552548457734",
}

-- Preload all icons so they appear instantly
do
	local allIcons = {}
	for _, v in pairs(NOTIF_ICONS) do table.insert(allIcons, v) end
	for _, v in pairs(NAV_ICONS) do table.insert(allIcons, v) end
	table.insert(allIcons, "rbxassetid://78552548457734")
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
	btn.Font = Enum.Font.BuilderSansMedium
	btn.TextSize = 13
	btn.TextColor3 = M3_ON_SURFACE_VAR
	btn.Text = ""
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BackgroundColor3 = M3_SURFACE
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(0, 44, 0, 44)
	btn.AutoButtonColor = false
	btn.Parent = navFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 22)
	btnCorner.Parent = btn

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.Position = UDim2.new(0.5, -11, 0.5, -11)
	icon.BackgroundTransparency = 1
	icon.Image = NAV_ICONS[name] or ""
	icon.ImageColor3 = M3_ON_SURFACE_VAR
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	icon.Parent = btn

	-- Tooltip on hover (launcher-style, parented to mainFrame to avoid clipping)
	local tooltip = Instance.new("TextLabel")
	tooltip.Font = Enum.Font.BuilderSansMedium
	tooltip.TextSize = 12
	tooltip.TextColor3 = M3_ON_SURFACE
	tooltip.TextXAlignment = Enum.TextXAlignment.Left
	tooltip.TextYAlignment = Enum.TextYAlignment.Center
	tooltip.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
	tooltip.BorderSizePixel = 0
	tooltip.Size = UDim2.new(0, 0, 0, 32)
	tooltip.Position = UDim2.new(0, 56, 0, 0)
	tooltip.Visible = false
	tooltip.ZIndex = 100
	tooltip.Text = "  " .. name
	tooltip.Parent = mainFrame
	tooltip.ClipsDescendants = true

	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 16)
	tooltipCorner.Parent = tooltip

	local tooltipShowing = false
	local tooltipTween

	btn.MouseEnter:Connect(function()
		playSound(SOUND_HOVER, 1.0)
		tooltipShowing = true
		-- Position tooltip at the button's actual Y inside mainFrame
		local mainPos = mainFrame.AbsolutePosition
		local btnPos = btn.AbsolutePosition
		local btnSize = btn.AbsoluteSize
		tooltip.Position = UDim2.new(0, 56, 0, btnPos.Y - mainPos.Y + btnSize.Y / 2 - 16)
		tooltip.Size = UDim2.new(0, 0, 0, 32)
		tooltip.Visible = true
		tooltip.BackgroundTransparency = 1
		tooltip.TextTransparency = 1
		-- Animate in: slide right + fade in
		if tooltipTween then tooltipTween:Cancel() end
		tooltipTween = TweenService:Create(tooltip, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 100, 0, 32),
			BackgroundTransparency = 0,
			TextTransparency = 0,
		})
		tooltipTween:Play()
		if currentPage ~= name then
			icon.ImageColor3 = M3_ON_SURFACE
			btn.BackgroundColor3 = M3_SURFACE_CONTAINER
		end
	end)

	btn.MouseLeave:Connect(function()
		tooltipShowing = false
		-- Animate out: slide left + fade out
		if tooltipTween then tooltipTween:Cancel() end
		tooltipTween = TweenService:Create(tooltip, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 32),
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tooltipTween:Play()
		tooltipTween.Completed:Connect(function()
			if not tooltipShowing then
				tooltip.Visible = false
			end
		end)
		if currentPage ~= name then
			icon.ImageColor3 = M3_ON_SURFACE_VAR
			btn.BackgroundColor3 = M3_SURFACE
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
	page.ScrollBarThickness = 6
	page.ScrollBarImageColor3 = M3_PRIMARY
	page.ScrollBarImageTransparency = 0.3
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Visible = false
	page.Parent = contentFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = page

	pages[name] = page
	return page
end

local currentPage = nil
local pageSwitching = false

local function showPage(name)
	if currentPage == name then return end
	if pageSwitching then return end
	pageSwitching = true
	playRandomPageSound()

	-- Deactivate old button
	if currentPage and navButtons[currentPage] then
		local oldData = navButtons[currentPage]
		oldData.btn.BackgroundColor3 = M3_SURFACE
		oldData.icon.ImageColor3 = M3_ON_SURFACE_VAR
	end

	-- Fade content
	local fadeOverlay = Instance.new("Frame")
	fadeOverlay.Size = UDim2.new(1, 0, 1, 0)
	fadeOverlay.BackgroundColor3 = M3_SURFACE
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
		newData.icon.ImageColor3 = M3_ON_SURFACE
	end

	local fadeOut = TweenService:Create(fadeOverlay, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	fadeOverlay:Destroy()

	currentPage = name
	pageSwitching = false
end

-- UI helpers
local function createToggle(parent, text, callback)
	local enabled = false
	local toggling = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 56)
	frame.BackgroundColor3 = M3_SURFACE_CONTAINER
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 14
	label.TextColor3 = M3_ON_SURFACE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -72, 1, 0)
	label.Position = UDim2.new(0, 16, 0, 0)
	label.Text = text
	label.Parent = frame

	-- M3 switch: track + thumb
	local switchBg = Instance.new("TextButton")
	switchBg.Text = ""
	switchBg.BackgroundColor3 = M3_SURFACE_VAR
	switchBg.BorderSizePixel = 0
	switchBg.Size = UDim2.new(0, 52, 0, 32)
	switchBg.Position = UDim2.new(1, -68, 0.5, -16)
	switchBg.AutoButtonColor = false
	switchBg.Parent = frame

	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = switchBg

	-- M3 switch outline (unselected state)
	local switchOutline = Instance.new("UIStroke")
	switchOutline.Color = M3_OUTLINE
	switchOutline.Thickness = 2
	switchOutline.Transparency = 0
	switchOutline.Parent = switchBg

	-- M3 thumb (circle)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 4, 0.5, -8)
	knob.BackgroundColor3 = M3_OUTLINE
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = switchBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local function updateVisual()
		if enabled then
			switchBg.BackgroundColor3 = M3_PRIMARY
			switchOutline.Transparency = 1
			knob.BackgroundColor3 = M3_ON_PRIMARY
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(1, -28, 0.5, -12), Size = UDim2.new(0, 24, 0, 24) })
			knobTween:Play()
		else
			switchBg.BackgroundColor3 = M3_SURFACE_VAR
			switchOutline.Transparency = 0
			knob.BackgroundColor3 = M3_OUTLINE
			local knobTween = TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0, 4, 0.5, -8), Size = UDim2.new(0, 16, 0, 16) })
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
		playSound(SOUND_HOVER, 1.0)
	end)

	local listeners = {}
	return {
		frame = frame,
		get = function() return enabled end,
		set = function(v)
			enabled = v
			updateVisual()
			for _, cb in ipairs(listeners) do
				cb(enabled)
			end
		end,
		onChange = function(cb) table.insert(listeners, cb) end,
	}
end

local function createSlider(parent, text, min, max, default, callback)
	local value = default

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 56)
	frame.BackgroundColor3 = M3_SURFACE_CONTAINER
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 14
	label.TextColor3 = M3_ON_SURFACE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 0, 24)
	label.Position = UDim2.new(0, 16, 0, 8)
	label.Text = text .. ": " .. tostring(default)
	label.Parent = frame

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -32, 0, 4)
	sliderBg.Position = UDim2.new(0, 16, 0, 38)
	sliderBg.BackgroundColor3 = M3_SURFACE_VAR
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = frame

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(1, 0)
	sliderCorner.Parent = sliderBg

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	sliderFill.BackgroundColor3 = M3_PRIMARY
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
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 14
	label.TextColor3 = M3_ON_SURFACE_VAR
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 32)
	label.Text = text
	label.Parent = parent
	return label
end

-- ===================
-- KEYBIND SYSTEM + EDIT MODE
-- ===================
local keybinds = {}
local keybindEntries = {}
local keybindItems = {}
local editMode = false
local editModeOverlay, editModeHint
local draggableElements = {}
local listeningForKey = false
local keyCaptureCallback = nil

-- Edit mode overlay ScreenGui
local editModeGui = Instance.new("ScreenGui")
editModeGui.Name = "UndercoreEditMode"
editModeGui.IgnoreGuiInset = true
editModeGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
editModeGui.ResetOnSpawn = false
protectGui(editModeGui)
editModeGui.Parent = uiParent

editModeOverlay = Instance.new("Frame")
editModeOverlay.Name = "EditModeOverlay"
editModeOverlay.Size = UDim2.new(1, 0, 1, 0)
editModeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
editModeOverlay.BackgroundTransparency = 0.5
editModeOverlay.BorderSizePixel = 0
editModeOverlay.Visible = false
editModeOverlay.ZIndex = 5
editModeOverlay.Parent = editModeGui

editModeHint = Instance.new("Frame")
editModeHint.Name = "EditModeHint"
editModeHint.Size = UDim2.new(0, 420, 0, 48)
editModeHint.Position = UDim2.new(1, -440, 1, -62)
editModeHint.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
editModeHint.BackgroundTransparency = 0
editModeHint.BorderSizePixel = 0
editModeHint.Visible = false
editModeHint.ZIndex = 10
editModeHint.Parent = editModeGui

do
local editModeHintCorner = Instance.new("UICorner")
editModeHintCorner.CornerRadius = UDim.new(0, 16)
editModeHintCorner.Parent = editModeHint

local editModeHintStroke = Instance.new("UIStroke")
editModeHintStroke.Color = M3_OUTLINE
editModeHintStroke.Thickness = 1
editModeHintStroke.Transparency = 0
editModeHintStroke.Parent = editModeHint

local editModeHintText = Instance.new("TextLabel")
editModeHintText.Font = Enum.Font.BuilderSansMedium
editModeHintText.TextSize = 14
editModeHintText.TextColor3 = M3_ON_SURFACE
editModeHintText.TextXAlignment = Enum.TextXAlignment.Left
editModeHintText.TextYAlignment = Enum.TextYAlignment.Center
editModeHintText.BackgroundTransparency = 1
editModeHintText.Size = UDim2.new(1, -130, 1, 0)
editModeHintText.Position = UDim2.new(0, 16, 0, 0)
editModeHintText.Text = "Edit Mode вЂ” press to exit"
editModeHintText.ZIndex = 11
editModeHintText.Parent = editModeHint

local backspaceBadge = Instance.new("TextLabel")
backspaceBadge.Font = Enum.Font.BuilderSansMedium
backspaceBadge.TextSize = 12
backspaceBadge.TextColor3 = M3_ON_SURFACE
backspaceBadge.TextXAlignment = Enum.TextXAlignment.Center
backspaceBadge.TextYAlignment = Enum.TextYAlignment.Center
backspaceBadge.BackgroundColor3 = M3_SURFACE_VAR
backspaceBadge.BorderSizePixel = 0
backspaceBadge.Size = UDim2.new(0, 90, 0, 28)
backspaceBadge.Position = UDim2.new(1, -104, 0.5, -14)
backspaceBadge.Text = "Backspace"
backspaceBadge.ZIndex = 11
backspaceBadge.Parent = editModeHint

local backspaceBadgeCorner = Instance.new("UICorner")
backspaceBadgeCorner.CornerRadius = UDim.new(0, 14)
backspaceBadgeCorner.Parent = backspaceBadge
end

-- On-screen keybind display
local keybindGui = Instance.new("ScreenGui")
keybindGui.Name = "UndercoreKeybinds"
keybindGui.IgnoreGuiInset = true
keybindGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
keybindGui.ResetOnSpawn = false
protectGui(keybindGui)
keybindGui.Parent = uiParent

local keybindFrame = Instance.new("Frame")
keybindFrame.Name = "KeybindFrame"
keybindFrame.Size = UDim2.new(0, 180, 0, 0)
keybindFrame.Position = UDim2.new(1, -190, 1, -60)
keybindFrame.AnchorPoint = Vector2.new(0, 1)
keybindFrame.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
keybindFrame.BackgroundTransparency = 0.05
keybindFrame.BorderSizePixel = 0
keybindFrame.AutomaticSize = Enum.AutomaticSize.Y
keybindFrame.Visible = false
keybindFrame.Parent = keybindGui

do
local keybindFrameCorner = Instance.new("UICorner")
keybindFrameCorner.CornerRadius = UDim.new(0, 16)
keybindFrameCorner.Parent = keybindFrame

local keybindTitle = Instance.new("TextLabel")
keybindTitle.Font = Enum.Font.BuilderSansMedium
keybindTitle.TextSize = 12
keybindTitle.TextColor3 = M3_ON_SURFACE_VAR
keybindTitle.TextXAlignment = Enum.TextXAlignment.Center
keybindTitle.BackgroundTransparency = 1
keybindTitle.Size = UDim2.new(1, 0, 0, 24)
keybindTitle.Text = "KEYBINDS"
keybindTitle.Parent = keybindFrame

local keybindListLayout = Instance.new("UIListLayout")
keybindListLayout.FillDirection = Enum.FillDirection.Vertical
keybindListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
keybindListLayout.Padding = UDim.new(0, 4)
keybindListLayout.Parent = keybindFrame

local keybindPadding = Instance.new("UIPadding")
keybindPadding.PaddingTop = UDim.new(0, 6)
keybindPadding.PaddingBottom = UDim.new(0, 6)
keybindPadding.PaddingLeft = UDim.new(0, 8)
keybindPadding.PaddingRight = UDim.new(0, 8)
keybindPadding.Parent = keybindFrame
end

local function keyCodeName(keyCode)
	local name = tostring(keyCode)
	return name:gsub("Enum.KeyCode.", ""):gsub("Left", "L"):gsub("Right", "R")
end

local function updateKeybindDisplay()
	local anyVisible = false
	for _, item in ipairs(keybindItems) do
		if item.Visible then
			anyVisible = true
			break
		end
	end
	keybindFrame.Visible = anyVisible
end

local function unbindToggle(toggleRef)
	for i = #keybindEntries, 1, -1 do
		local entry = keybindEntries[i]
		if entry.toggle == toggleRef then
			keybinds[entry.keyCode] = nil
			if entry.item then entry.item:Destroy() end
			table.remove(keybindEntries, i)
			for j, item in ipairs(keybindItems) do
				if item == entry.item then
					table.remove(keybindItems, j)
					break
				end
			end
		end
	end
	updateKeybindDisplay()
end

local function bindKeyToToggle(keyCode, name, toggleRef)
	if keyCode == Enum.KeyCode.Unknown or keyCode == Enum.KeyCode.Backspace then
		unbindToggle(toggleRef)
		return
	end
	unbindToggle(toggleRef)
	if keybinds[keyCode] then
		unbindToggle(keybinds[keyCode].toggle)
	end
	registerKeybind(keyCode, name, toggleRef)
end

local function registerKeybind(keyCode, name, toggleRef, action)
	if keybinds[keyCode] then return end
	local entry = { keyCode = keyCode, name = name, toggle = toggleRef, action = action }
	table.insert(keybindEntries, entry)
	keybinds[keyCode] = entry

	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, 0, 0, 22)
	item.BackgroundColor3 = M3_SURFACE_CONTAINER
	item.BorderSizePixel = 0
	item.Visible = false
	item.Parent = keybindFrame

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 8)
	itemCorner.Parent = item

	local keyBadge = Instance.new("TextLabel")
	keyBadge.Font = Enum.Font.BuilderSansMedium
	keyBadge.TextSize = 11
	keyBadge.TextColor3 = M3_ON_PRIMARY
	keyBadge.TextXAlignment = Enum.TextXAlignment.Center
	keyBadge.TextYAlignment = Enum.TextYAlignment.Center
	keyBadge.BackgroundColor3 = M3_PRIMARY
	keyBadge.BorderSizePixel = 0
	keyBadge.Size = UDim2.new(0, 0, 0, 18)
	keyBadge.AutomaticSize = Enum.AutomaticSize.X
	keyBadge.Position = UDim2.new(0, 4, 0.5, -9)
	keyBadge.Text = "  " .. keyCodeName(keyCode) .. "  "
	keyBadge.Parent = item

	local keyBadgeCorner = Instance.new("UICorner")
	keyBadgeCorner.CornerRadius = UDim.new(0, 9)
	keyBadgeCorner.Parent = keyBadge

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Font = Enum.Font.BuilderSans
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = M3_ON_SURFACE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -50, 1, 0)
	nameLabel.Position = UDim2.new(0, 48, 0, 0)
	nameLabel.Text = name
	nameLabel.Parent = item

	table.insert(keybindItems, item)
	entry.item = item

	if toggleRef and toggleRef.onChange then
		toggleRef.onChange(function(v)
			item.Visible = v
			updateKeybindDisplay()
		end)
	end
end

local function makeDraggable(element)
	local dragStartPos, startPos, dragInput
	local isDragging = false

	element.InputBegan:Connect(function(input)
		if not editMode then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStartPos = input.Position
			startPos = element.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isDragging = false
				end
			end)
		end
	end)

	element.InputChanged:Connect(function(input)
		if not editMode then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	trackConn(UserInputService.InputChanged:Connect(function(input)
		if not editMode then return end
		if input == dragInput and isDragging then
			local delta = input.Position - dragStartPos
			element.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))

	table.insert(draggableElements, element)
end

-- Apply draggable behavior to UI elements created before makeDraggable was defined
makeDraggable(mainFrame)
makeDraggable(keybindFrame)

local function setEditMode(enabled)
	editMode = enabled
	if editModeOverlay then
		editModeOverlay.Visible = enabled
	end
	if editModeHint then
		editModeHint.Visible = enabled
	end
	if enabled then
		if not menuVisible then openMenu() end
		notify("Undercore", "Edit mode enabled. Drag UI elements. Press Backspace to exit.", 4, ACCENT, "info")
	else
		notify("Undercore", "Edit mode disabled.", 3, GREEN, "success")
	end
end


-- ===================
-- PIANO ENGINE
-- ===================
local VirtualInputManager = game:GetService("VirtualInputManager")

local NOTE_MAPPINGS = {
	["C"] = {[1] = "1", [2] = "8", [3] = "t", [4] = "s", [5] = "l", [6] = "m"},
	["C#"] = {[1] = "!", [2] = "*", [3] = "T", [4] = "S", [5] = "L"},
	["D"] = {[1] = "2", [2] = "9", [3] = "y", [4] = "d", [5] = "z"},
	["D#"] = {[1] = "@", [2] = "(", [3] = "Y", [4] = "D", [5] = "Z"},
	["E"] = {[1] = "3", [2] = "0", [3] = "u", [4] = "f", [5] = "x"},
	["F"] = {[1] = "4", [2] = "q", [3] = "i", [4] = "g", [5] = "c"},
	["F#"] = {[1] = "$", [2] = "Q", [3] = "I", [4] = "G", [5] = "C"},
	["G"] = {[1] = "5", [2] = "w", [3] = "o", [4] = "h", [5] = "v"},
	["G#"] = {[1] = "%", [2] = "W", [3] = "O", [4] = "H", [5] = "V"},
	["A"] = {[1] = "6", [2] = "e", [3] = "p", [4] = "j", [5] = "b"},
	["A#"] = {[1] = "^", [2] = "E", [3] = "P", [4] = "J", [5] = "B"},
	["B"] = {[1] = "7", [2] = "r", [3] = "a", [4] = "k", [5] = "n"}
}

local KEY_MAPPINGS = {
	["1"] = Enum.KeyCode.One, ["!"] = Enum.KeyCode.One,
	["2"] = Enum.KeyCode.Two, ["@"] = Enum.KeyCode.Two,
	["3"] = Enum.KeyCode.Three, ["#"] = Enum.KeyCode.Three,
	["4"] = Enum.KeyCode.Four, ["$"] = Enum.KeyCode.Four,
	["5"] = Enum.KeyCode.Five, ["%"] = Enum.KeyCode.Five,
	["6"] = Enum.KeyCode.Six, ["^"] = Enum.KeyCode.Six,
	["7"] = Enum.KeyCode.Seven, ["&"] = Enum.KeyCode.Seven,
	["8"] = Enum.KeyCode.Eight, ["*"] = Enum.KeyCode.Eight,
	["9"] = Enum.KeyCode.Nine, ["("] = Enum.KeyCode.Nine,
	["0"] = Enum.KeyCode.Zero, [")"] = Enum.KeyCode.Zero,
	["q"] = Enum.KeyCode.Q, ["Q"] = Enum.KeyCode.Q,
	["w"] = Enum.KeyCode.W, ["W"] = Enum.KeyCode.W,
	["e"] = Enum.KeyCode.E, ["E"] = Enum.KeyCode.E,
	["r"] = Enum.KeyCode.R, ["R"] = Enum.KeyCode.R,
	["t"] = Enum.KeyCode.T, ["T"] = Enum.KeyCode.T,
	["y"] = Enum.KeyCode.Y, ["Y"] = Enum.KeyCode.Y,
	["u"] = Enum.KeyCode.U, ["U"] = Enum.KeyCode.U,
	["i"] = Enum.KeyCode.I, ["I"] = Enum.KeyCode.I,
	["o"] = Enum.KeyCode.O, ["O"] = Enum.KeyCode.O,
	["p"] = Enum.KeyCode.P, ["P"] = Enum.KeyCode.P,
	["a"] = Enum.KeyCode.A, ["A"] = Enum.KeyCode.A,
	["s"] = Enum.KeyCode.S, ["S"] = Enum.KeyCode.S,
	["d"] = Enum.KeyCode.D, ["D"] = Enum.KeyCode.D,
	["f"] = Enum.KeyCode.F, ["F"] = Enum.KeyCode.F,
	["g"] = Enum.KeyCode.G, ["G"] = Enum.KeyCode.G,
	["h"] = Enum.KeyCode.H, ["H"] = Enum.KeyCode.H,
	["j"] = Enum.KeyCode.J, ["J"] = Enum.KeyCode.J,
	["k"] = Enum.KeyCode.K, ["K"] = Enum.KeyCode.K,
	["l"] = Enum.KeyCode.L, ["L"] = Enum.KeyCode.L,
	["z"] = Enum.KeyCode.Z, ["Z"] = Enum.KeyCode.Z,
	["x"] = Enum.KeyCode.X, ["X"] = Enum.KeyCode.X,
	["c"] = Enum.KeyCode.C, ["C"] = Enum.KeyCode.C,
	["v"] = Enum.KeyCode.V, ["V"] = Enum.KeyCode.V,
	["b"] = Enum.KeyCode.B, ["B"] = Enum.KeyCode.B,
	["n"] = Enum.KeyCode.N, ["N"] = Enum.KeyCode.N,
	["m"] = Enum.KeyCode.M, ["M"] = Enum.KeyCode.M
}

local SHIFT_KEYS = {
	"!","@","#","$","%","^","&","*","(",")",
	"Q","W","E","R","T","Y","U","I","O","P",
	"A","S","D","F","G","H","J","K","L","Z",
	"X","C","V","B","N","M"
}

local pianoState = {
	songPlaying = false,
	songPaused = false,
	bpm = 120,
	errorMargin = 0,
	stopFlag = true,
	currentSongName = "None",
	resumeEvent = Instance.new("BindableEvent"),
	songThread = nil,
	finishCallback = nil,
}

local function isShiftKey(key)
	for _, sk in ipairs(SHIFT_KEYS) do
		if sk == key then return true end
	end
	return false
end

local function enginePressKey(keys, beats, bpm)
	if pianoState.stopFlag then return end
	local shiftRequired, nonShift = {}, {}
	local ctrlRequired = false
	if keys:sub(1, 5) == "Ctrl+" then
		ctrlRequired = true
		keys = keys:sub(6)
	end
	for i = 1, #keys do
		local key = keys:sub(i, i)
		table.insert(isShiftKey(key) and shiftRequired or nonShift, key)
	end
	for _, key in ipairs(nonShift) do
		local shiftApplied = false
		if math.random(1, 500) <= pianoState.errorMargin * 100 then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
			shiftApplied = true
		end
		coroutine.wrap(function()
			if ctrlRequired then
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
			end
			VirtualInputManager:SendKeyEvent(true, KEY_MAPPINGS[key], false, game)
			if ctrlRequired then
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
			end
			if shiftApplied then
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
			end
			local maxRan = (beats / bpm) * 60 / 2
			local waittime = (beats / bpm) * 60 - math.random() * maxRan
			task.wait(waittime)
			VirtualInputManager:SendKeyEvent(false, KEY_MAPPINGS[key], false, game)
		end)()
		if pianoState.errorMargin ~= 0 and math.random() < 0.5 then
			task.wait(math.random() * pianoState.errorMargin / 3)
		end
	end
	if #shiftRequired > 0 then
		for _, key in ipairs(shiftRequired) do
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
			local unshiftApplied = false
			if math.random(1, 500) <= pianoState.errorMargin * 100 then
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
				unshiftApplied = true
			end
			coroutine.wrap(function()
				if ctrlRequired then
					VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
				end
				VirtualInputManager:SendKeyEvent(true, KEY_MAPPINGS[key], false, game)
				if ctrlRequired then
					VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
				end
				if not unshiftApplied then
					VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
				end
				local maxRan = (beats / bpm) * 60 / 2
				local waittime = (beats / bpm) * 60 - math.random() * maxRan
				task.wait(waittime)
				VirtualInputManager:SendKeyEvent(false, KEY_MAPPINGS[key], false, game)
			end)()
			if pianoState.errorMargin ~= 0 and math.random() < 0.5 then
				task.wait(math.random() * pianoState.errorMargin / 3)
			end
		end
	end
	if ctrlRequired then
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
	end
	if pianoState.errorMargin ~= 0 then
		task.wait(math.random() * (pianoState.errorMargin * 2))
	end
end

local function enginePressnote(note, octave, beats, bpm)
	if pianoState.stopFlag then return end
	if pianoState.songPaused then pianoState.resumeEvent.Event:Wait() end
	local key = NOTE_MAPPINGS[note] and NOTE_MAPPINGS[note][octave]
	if key then
		coroutine.wrap(function() enginePressKey(key, beats, bpm) end)()
	end
end

local function engineRest(beats, bpm)
	if pianoState.stopFlag then return end
	if pianoState.songPaused then pianoState.resumeEvent.Event:Wait() end
	local waitTime = (beats / bpm) * 60
	if pianoState.errorMargin == 0 then
		task.wait(waitTime)
	else
		local randomOffset = (math.random() * 2 - 1) * (pianoState.errorMargin / 2)
		task.wait(waitTime + randomOffset)
	end
end

local function engineKeypress(keys, beats, bpm)
	if pianoState.stopFlag then return end
	if pianoState.songPaused then pianoState.resumeEvent.Event:Wait() end
	coroutine.wrap(function() enginePressKey(keys, beats, bpm) end)()
end

local function enginePedalDown()
	if pianoState.stopFlag then return end
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
end

local function enginePedalUp()
	if pianoState.stopFlag then return end
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

local function stopSong()
	pianoState.stopFlag = true
	pianoState.songPlaying = false
	pianoState.songPaused = false
	if pianoState.songThread then
		pcall(function() task.cancel(pianoState.songThread) end)
		pianoState.songThread = nil
	end
end

local function playSong(songCode, songName, bpm)
	stopSong()
	pianoState.stopFlag = false
	pianoState.songPlaying = true
	pianoState.songPaused = false
	pianoState.currentSongName = songName or "Unknown"
	pianoState.bpm = bpm or 120
	local bpm_val = pianoState.bpm
	local function pressnote(note, octave, beats) enginePressnote(note, octave, beats, bpm_val) end
	local function rest(beats) engineRest(beats, bpm_val) end
	local function keypress(keys, beats) engineKeypress(keys, beats, bpm_val) end
	local function pedalDown() enginePedalDown() end
	local function pedalUp() enginePedalUp() end
	local function adjustVelocity(vel)
		if pianoState.stopFlag then return end
		local velocityMap = "58qrupdhl"
		vel = math.clamp(vel, 0, 1)
		local topress
		if vel < 0.27 then topress = "2"
		elseif vel >= 0.88 then topress = "c"
		else
			local index = math.floor((vel - 0.27) / 0.61 * (#velocityMap - 2)) + 2
			topress = velocityMap:sub(index, index)
		end
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
		VirtualInputManager:SendKeyEvent(true, KEY_MAPPINGS[topress], false, game)
		VirtualInputManager:SendKeyEvent(false, KEY_MAPPINGS[topress], false, game)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
	end
	local fn, err = loadstring(songCode)
	if not fn then
		notify("Undercore", "Failed to load song: " .. tostring(err), 4, RED, "error")
		pianoState.stopFlag = true
		pianoState.songPlaying = false
		return
	end
	setfenv(fn, setmetatable({
		pressnote = pressnote, rest = rest, keypress = keypress,
		pedalDown = pedalDown, pedalUp = pedalUp,
		adjustVelocity = adjustVelocity, bpm = bpm_val,
	}, {__index = getfenv()}))
	pianoState.songThread = task.spawn(function()
		fn()
		pianoState.songPlaying = false
		pianoState.stopFlag = true
		if pianoState.finishCallback then pianoState.finishCallback() end
		notify("Undercore", "Song finished: " .. pianoState.currentSongName, 3, GREEN, "success")
	end)
end

local function pauseSong()
	pianoState.songPaused = not pianoState.songPaused
	if not pianoState.songPaused then pianoState.resumeEvent:Fire() end
end

-- ===================
-- BUILT-IN SONGS
-- ===================
local BUILTIN_SONGS = {
	{ name = "Golden Hour", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/GOLDEN_HOUR", bpm = 120 },
	{ name = "Fur Elise", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/FUR_ELIASE", bpm = 120 },
	{ name = "Megalovania", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/MEGALOVANIA", bpm = 120 },
	{ name = "Comptine d'un autre ete", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/COMPTINE", bpm = 120 },
	{ name = "Rush E", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/RUSH_E", bpm = 120 },
	{ name = "Canon in D", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/CANON_IN_D", bpm = 120 },
	{ name = "Interstellar", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/INTERSTELLAR", bpm = 120 },
	{ name = "Moonlight Sonata", url = "https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/SONGS/MOONLIGHT_SONATA", bpm = 120 },
}

-- ===================
-- SONGS PAGE
-- ===================
local songsPage = createPage("Songs")
local navSongs, navSongsIcon, navSongsLabel = createNavButton("Songs")
navButtons["Songs"] = { btn = navSongs, icon = navSongsIcon, label = navSongsLabel }
navSongs.MouseButton1Click:Connect(function() showPage("Songs") end)

createLabel(songsPage, "Songs")

local songSearchBox = Instance.new("TextBox")
songSearchBox.Font = Enum.Font.BuilderSans
songSearchBox.TextSize = 14
songSearchBox.TextColor3 = M3_ON_SURFACE
songSearchBox.PlaceholderText = "Search songs..."
songSearchBox.PlaceholderColor3 = M3_ON_SURFACE_VAR
songSearchBox.Text = ""
songSearchBox.BackgroundColor3 = M3_SURFACE_CONTAINER
songSearchBox.BorderSizePixel = 0
songSearchBox.Size = UDim2.new(1, 0, 0, 40)
songSearchBox.Parent = songsPage

local songSearchCorner = Instance.new("UICorner")
songSearchCorner.CornerRadius = UDim.new(0, 16)
songSearchCorner.Parent = songSearchBox

local songSearchPad = Instance.new("UIPadding")
songSearchPad.PaddingLeft = UDim.new(0, 12)
songSearchPad.PaddingRight = UDim.new(0, 12)
songSearchPad.Parent = songSearchBox

local songListFrame = Instance.new("ScrollingFrame")
songListFrame.Size = UDim2.new(1, 0, 0, 300)
songListFrame.BackgroundTransparency = 1
songListFrame.BorderSizePixel = 0
songListFrame.ScrollBarThickness = 6
songListFrame.ScrollBarImageColor3 = M3_PRIMARY
songListFrame.ScrollBarImageTransparency = 0.3
songListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
songListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
songListFrame.Parent = songsPage

local songListLayout = Instance.new("UIListLayout")
songListLayout.FillDirection = Enum.FillDirection.Vertical
songListLayout.SortOrder = Enum.SortOrder.LayoutOrder
songListLayout.Padding = UDim.new(0, 4)
songListLayout.Parent = songListFrame

local songEntries = {}
local selectedSong = nil

local function refreshSongList(filter)
	filter = (filter or ""):lower()
	for _, entry in ipairs(songEntries) do
		if entry.frame then entry.frame:Destroy() end
	end
	songEntries = {}
	for i, song in ipairs(BUILTIN_SONGS) do
		if filter == "" or song.name:lower():find(filter, 1, true) then
			local entryFrame = Instance.new("TextButton")
			entryFrame.Text = ""
			entryFrame.AutoButtonColor = false
			entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER
			entryFrame.BorderSizePixel = 0
			entryFrame.Size = UDim2.new(1, 0, 0, 44)
			entryFrame.LayoutOrder = i
			entryFrame.Parent = songListFrame
			local entryCorner = Instance.new("UICorner")
			entryCorner.CornerRadius = UDim.new(0, 16)
			entryCorner.Parent = entryFrame
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Font = Enum.Font.BuilderSansMedium
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = M3_ON_SURFACE
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextYAlignment = Enum.TextYAlignment.Center
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.new(1, -80, 1, 0)
			nameLabel.Position = UDim2.new(0, 14, 0, 0)
			nameLabel.Text = song.name
			nameLabel.Parent = entryFrame
			local bpmLabel = Instance.new("TextLabel")
			bpmLabel.Font = Enum.Font.BuilderSans
			bpmLabel.TextSize = 12
			bpmLabel.TextColor3 = M3_ON_SURFACE_VAR
			bpmLabel.TextXAlignment = Enum.TextXAlignment.Right
			bpmLabel.TextYAlignment = Enum.TextYAlignment.Center
			bpmLabel.BackgroundTransparency = 1
			bpmLabel.Size = UDim2.new(0, 60, 1, 0)
			bpmLabel.Position = UDim2.new(1, -74, 0, 0)
			bpmLabel.Text = tostring(song.bpm) .. " BPM"
			bpmLabel.Parent = entryFrame
			entryFrame.MouseButton1Click:Connect(function()
				playRandomPageSound()
				selectedSong = song
				for _, e in ipairs(songEntries) do e.frame.BackgroundColor3 = M3_SURFACE_CONTAINER end
				entryFrame.BackgroundColor3 = M3_PRIMARY_CONTAINER
				notify("Undercore", "Selected: " .. song.name, 2, ACCENT, "info")
			end)
			entryFrame.MouseEnter:Connect(function()
				if entryFrame.BackgroundColor3 ~= M3_PRIMARY_CONTAINER then
					entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
				end
			end)
			entryFrame.MouseLeave:Connect(function()
				if entryFrame.BackgroundColor3 == M3_SURFACE_CONTAINER_HIGH then
					entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER
				end
			end)
			table.insert(songEntries, { frame = entryFrame, song = song })
		end
	end
end

songSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	refreshSongList(songSearchBox.Text)
end)

refreshSongList("")

-- Custom song input
createLabel(songsPage, "Custom Song")

local customSongBox = Instance.new("TextBox")
customSongBox.Font = Enum.Font.BuilderSans
customSongBox.TextSize = 13
customSongBox.TextColor3 = M3_ON_SURFACE
customSongBox.PlaceholderText = "Paste song URL or code here..."
customSongBox.PlaceholderColor3 = M3_ON_SURFACE_VAR
customSongBox.Text = ""
customSongBox.BackgroundColor3 = M3_SURFACE_CONTAINER
customSongBox.BorderSizePixel = 0
customSongBox.Size = UDim2.new(1, 0, 0, 80)
customSongBox.TextWrapped = true
customSongBox.MultiLine = true
customSongBox.ClearTextOnFocus = false
customSongBox.Parent = songsPage

local customSongCorner = Instance.new("UICorner")
customSongCorner.CornerRadius = UDim.new(0, 16)
customSongCorner.Parent = customSongBox

local customSongPad = Instance.new("UIPadding")
customSongPad.PaddingLeft = UDim.new(0, 12)
customSongPad.PaddingRight = UDim.new(0, 12)
customSongPad.PaddingTop = UDim.new(0, 8)
customSongPad.PaddingBottom = UDim.new(0, 8)
customSongPad.Parent = customSongBox

local customBpmLabel = Instance.new("TextLabel")
customBpmLabel.Font = Enum.Font.BuilderSansMedium
customBpmLabel.TextSize = 13
customBpmLabel.TextColor3 = M3_ON_SURFACE_VAR
customBpmLabel.TextXAlignment = Enum.TextXAlignment.Left
customBpmLabel.BackgroundTransparency = 1
customBpmLabel.Size = UDim2.new(0, 80, 0, 32)
customBpmLabel.Text = "BPM:"
customBpmLabel.Parent = songsPage

local customBpmBox = Instance.new("TextBox")
customBpmBox.Font = Enum.Font.BuilderSans
customBpmBox.TextSize = 14
customBpmBox.TextColor3 = M3_ON_SURFACE
customBpmBox.Text = "120"
customBpmBox.BackgroundColor3 = M3_SURFACE_CONTAINER
customBpmBox.BorderSizePixel = 0
customBpmBox.Size = UDim2.new(0, 80, 0, 32)
customBpmBox.Position = UDim2.new(0, 80, 0, 0)
customBpmBox.Parent = songsPage

local customBpmCorner = Instance.new("UICorner")
customBpmCorner.CornerRadius = UDim.new(0, 16)
customBpmCorner.Parent = customBpmBox

local playCustomBtn = Instance.new("TextButton")
playCustomBtn.Font = Enum.Font.BuilderSansMedium
playCustomBtn.TextSize = 14
playCustomBtn.TextColor3 = M3_ON_PRIMARY
playCustomBtn.Text = "Play Custom"
playCustomBtn.BackgroundColor3 = M3_PRIMARY
playCustomBtn.BorderSizePixel = 0
playCustomBtn.Size = UDim2.new(0, 120, 0, 32)
playCustomBtn.Position = UDim2.new(1, -128, 0, 0)
playCustomBtn.Parent = songsPage

local playCustomCorner = Instance.new("UICorner")
playCustomCorner.CornerRadius = UDim.new(0, 16)
playCustomCorner.Parent = playCustomBtn

playCustomBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	local input = customSongBox.Text
	if input == "" then
		notify("Undercore", "Please paste song code or URL.", 3, WARNING, "error")
		return
	end
	local bpm = tonumber(customBpmBox.Text) or 120
	local code = input
	if input:sub(1, 4) == "http" then
		notify("Undercore", "Fetching song...", 2, ACCENT, "info")
		local ok, result = pcall(function() return game:HttpGet(input, true) end)
		if not ok or not result then
			notify("Undercore", "Failed to fetch song.", 3, RED, "error")
			return
		end
		code = result
	end
	selectedSong = { name = "Custom Song", url = "", bpm = bpm }
	playSong(code, "Custom Song", bpm)
	notify("Undercore", "Playing: Custom Song", 3, GREEN, "success")
end)

playCustomBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

-- ===================
-- PLAYER PAGE
-- ===================
local playerPage = createPage("Player")
local navPlayer, navPlayerIcon, navPlayerLabel = createNavButton("Player")
navButtons["Player"] = { btn = navPlayer, icon = navPlayerIcon, label = navPlayerLabel }
navPlayer.MouseButton1Click:Connect(function() showPage("Player") end)

createLabel(playerPage, "Player")

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Font = Enum.Font.BuilderSansMedium
nowPlayingLabel.TextSize = 16
nowPlayingLabel.TextColor3 = M3_PRIMARY
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Size = UDim2.new(1, 0, 0, 32)
nowPlayingLabel.Text = "Now Playing: None"
nowPlayingLabel.Parent = playerPage

local function updateNowPlaying()
	nowPlayingLabel.Text = "Now Playing: " .. pianoState.currentSongName
end

pianoState.finishCallback = updateNowPlaying

-- BPM control
local bpmControlFrame = Instance.new("Frame")
bpmControlFrame.Size = UDim2.new(1, 0, 0, 48)
bpmControlFrame.BackgroundColor3 = M3_SURFACE_CONTAINER
bpmControlFrame.BorderSizePixel = 0
bpmControlFrame.Parent = playerPage

local bpmControlCorner = Instance.new("UICorner")
bpmControlCorner.CornerRadius = UDim.new(0, 16)
bpmControlCorner.Parent = bpmControlFrame

local bpmDownBtn = Instance.new("TextButton")
bpmDownBtn.Font = Enum.Font.BuilderSansBold
bpmDownBtn.TextSize = 18
bpmDownBtn.TextColor3 = M3_ON_SURFACE
bpmDownBtn.Text = "-"
bpmDownBtn.BackgroundColor3 = M3_SURFACE_VAR
bpmDownBtn.BorderSizePixel = 0
bpmDownBtn.Size = UDim2.new(0, 40, 0, 32)
bpmDownBtn.Position = UDim2.new(0, 8, 0.5, -16)
bpmDownBtn.Parent = bpmControlFrame

local bpmDownCorner = Instance.new("UICorner")
bpmDownCorner.CornerRadius = UDim.new(0, 16)
bpmDownCorner.Parent = bpmDownBtn

local bpmDisplay = Instance.new("TextLabel")
bpmDisplay.Font = Enum.Font.BuilderSansMedium
bpmDisplay.TextSize = 16
bpmDisplay.TextColor3 = M3_ON_SURFACE
bpmDisplay.TextXAlignment = Enum.TextXAlignment.Center
bpmDisplay.BackgroundTransparency = 1
bpmDisplay.Size = UDim2.new(0, 100, 0, 32)
bpmDisplay.Position = UDim2.new(0, 56, 0.5, -16)
bpmDisplay.Text = "BPM: 120"
bpmDisplay.Parent = bpmControlFrame

local bpmUpBtn = Instance.new("TextButton")
bpmUpBtn.Font = Enum.Font.BuilderSansBold
bpmUpBtn.TextSize = 18
bpmUpBtn.TextColor3 = M3_ON_SURFACE
bpmUpBtn.Text = "+"
bpmUpBtn.BackgroundColor3 = M3_SURFACE_VAR
bpmUpBtn.BorderSizePixel = 0
bpmUpBtn.Size = UDim2.new(0, 40, 0, 32)
bpmUpBtn.Position = UDim2.new(0, 164, 0.5, -16)
bpmUpBtn.Parent = bpmControlFrame

local bpmUpCorner = Instance.new("UICorner")
bpmUpCorner.CornerRadius = UDim.new(0, 16)
bpmUpCorner.Parent = bpmUpBtn

local function updateBpmDisplay()
	bpmDisplay.Text = "BPM: " .. tostring(pianoState.bpm)
end

bpmDownBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	pianoState.bpm = math.max(20, pianoState.bpm - 10)
	updateBpmDisplay()
end)

bpmUpBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	pianoState.bpm = math.min(500, pianoState.bpm + 10)
	updateBpmDisplay()
end)

bpmDownBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)
bpmUpBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

-- Error margin slider
local errorSlider = createSlider(playerPage, "Error Margin", 0, 100, 0, function(v)
	pianoState.errorMargin = v / 100
end)

-- Play / Pause / Stop buttons
local controlsRow = Instance.new("Frame")
controlsRow.Size = UDim2.new(1, 0, 0, 48)
controlsRow.BackgroundTransparency = 1
controlsRow.BorderSizePixel = 0
controlsRow.Parent = playerPage

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.FillDirection = Enum.FillDirection.Horizontal
controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
controlsLayout.Padding = UDim.new(0, 8)
controlsLayout.Parent = controlsRow

local playBtn = Instance.new("TextButton")
playBtn.Font = Enum.Font.BuilderSansMedium
playBtn.TextSize = 14
playBtn.TextColor3 = M3_ON_PRIMARY
playBtn.Text = "Play"
playBtn.BackgroundColor3 = M3_PRIMARY
playBtn.BorderSizePixel = 0
playBtn.Size = UDim2.new(0, 100, 0, 40)
playBtn.Parent = controlsRow

local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 20)
playCorner.Parent = playBtn

local pauseBtn = Instance.new("TextButton")
pauseBtn.Font = Enum.Font.BuilderSansMedium
pauseBtn.TextSize = 14
pauseBtn.TextColor3 = M3_ON_SURFACE
pauseBtn.Text = "Pause"
pauseBtn.BackgroundColor3 = M3_SURFACE_VAR
pauseBtn.BorderSizePixel = 0
pauseBtn.Size = UDim2.new(0, 100, 0, 40)
pauseBtn.Parent = controlsRow

local pauseCorner = Instance.new("UICorner")
pauseCorner.CornerRadius = UDim.new(0, 20)
pauseCorner.Parent = pauseBtn

local stopBtn = Instance.new("TextButton")
stopBtn.Font = Enum.Font.BuilderSansMedium
stopBtn.TextSize = 14
stopBtn.TextColor3 = M3_ON_ERROR
stopBtn.Text = "Stop"
stopBtn.BackgroundColor3 = M3_ERROR_CONTAINER
stopBtn.BorderSizePixel = 0
stopBtn.Size = UDim2.new(0, 100, 0, 40)
stopBtn.Parent = controlsRow

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 20)
stopCorner.Parent = stopBtn

playBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	if not selectedSong then
		notify("Undercore", "Select a song from the Songs tab first.", 3, WARNING, "error")
		return
	end
	if pianoState.songPlaying then
		notify("Undercore", "A song is already playing. Stop it first.", 3, WARNING, "error")
		return
	end
	notify("Undercore", "Loading: " .. selectedSong.name, 2, ACCENT, "info")
	local ok, code = pcall(function() return game:HttpGet(selectedSong.url, true) end)
	if not ok or not code then
		notify("Undercore", "Failed to fetch song.", 3, RED, "error")
		return
	end
	playSong(code, selectedSong.name, selectedSong.bpm)
	updateNowPlaying()
	notify("Undercore", "Playing: " .. selectedSong.name, 3, GREEN, "success")
end)

pauseBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	if not pianoState.songPlaying then
		notify("Undercore", "No song is playing.", 2, WARNING, "error")
		return
	end
	pauseSong()
	if pianoState.songPaused then
		pauseBtn.Text = "Resume"
		notify("Undercore", "Paused.", 2, ACCENT, "info")
	else
		pauseBtn.Text = "Pause"
		notify("Undercore", "Resumed.", 2, GREEN, "success")
	end
end)

stopBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	stopSong()
	pauseBtn.Text = "Pause"
	updateNowPlaying()
	notify("Undercore", "Stopped.", 2, ACCENT, "info")
end)

playBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)
pauseBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)
stopBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

-- ===================
-- MARKET PAGE
-- ===================
local marketPage = createPage("Market")
local navMarket, navMarketIcon, navMarketLabel = createNavButton("Market")
navButtons["Market"] = { btn = navMarket, icon = navMarketIcon, label = navMarketLabel }
navMarket.MouseButton1Click:Connect(function() showPage("Market") end)

createLabel(marketPage, "Market")

local marketDesc = Instance.new("TextLabel")
marketDesc.Font = Enum.Font.BuilderSans
marketDesc.TextSize = 13
marketDesc.TextColor3 = M3_ON_SURFACE_VAR
marketDesc.TextXAlignment = Enum.TextXAlignment.Left
marketDesc.TextWrapped = true
marketDesc.BackgroundTransparency = 1
marketDesc.Size = UDim2.new(1, 0, 0, 40)
marketDesc.Text = "Browse and play songs shared by the community. Songs are fetched from the server."
marketDesc.Parent = marketPage

local refreshMarketBtn = Instance.new("TextButton")
refreshMarketBtn.Font = Enum.Font.BuilderSansMedium
refreshMarketBtn.TextSize = 13
refreshMarketBtn.TextColor3 = M3_ON_PRIMARY
refreshMarketBtn.Text = "Refresh"
refreshMarketBtn.BackgroundColor3 = M3_PRIMARY
refreshMarketBtn.BorderSizePixel = 0
refreshMarketBtn.Size = UDim2.new(0, 100, 0, 32)
refreshMarketBtn.Parent = marketPage

local refreshMarketCorner = Instance.new("UICorner")
refreshMarketCorner.CornerRadius = UDim.new(0, 16)
refreshMarketCorner.Parent = refreshMarketBtn

refreshMarketBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

local marketListFrame = Instance.new("ScrollingFrame")
marketListFrame.Size = UDim2.new(1, 0, 0, 300)
marketListFrame.BackgroundTransparency = 1
marketListFrame.BorderSizePixel = 0
marketListFrame.ScrollBarThickness = 6
marketListFrame.ScrollBarImageColor3 = M3_PRIMARY
marketListFrame.ScrollBarImageTransparency = 0.3
marketListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
marketListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
marketListFrame.Parent = marketPage

local marketListLayout = Instance.new("UIListLayout")
marketListLayout.FillDirection = Enum.FillDirection.Vertical
marketListLayout.SortOrder = Enum.SortOrder.LayoutOrder
marketListLayout.Padding = UDim.new(0, 4)
marketListLayout.Parent = marketListFrame

local marketEntries = {}
local MARKET_URL = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/market_songs.json"

local function clearMarketList()
	for _, entry in ipairs(marketEntries) do
		if entry.frame then entry.frame:Destroy() end
	end
	marketEntries = {}
end

local function refreshMarketList()
	clearMarketList()
	notify("Undercore", "Fetching market songs...", 2, ACCENT, "info")
	local ok, result = pcall(function()
		return game:HttpGet(MARKET_URL .. "?v=" .. tostring(tick()), true)
	end)
	if not ok or not result or result == "" then
		local placeholder = Instance.new("TextLabel")
		placeholder.Font = Enum.Font.BuilderSans
		placeholder.TextSize = 13
		placeholder.TextColor3 = M3_ON_SURFACE_VAR
		placeholder.TextXAlignment = Enum.TextXAlignment.Center
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(1, 0, 0, 40)
		placeholder.Text = "No songs available. Market server not yet configured."
		placeholder.Parent = marketListFrame
		table.insert(marketEntries, { frame = placeholder })
		return
	end
	local songs = {}
	pcall(function()
		songs = game:GetService("HttpService"):JSONDecode(result)
	end)
	if type(songs) ~= "table" or #songs == 0 then
		local placeholder = Instance.new("TextLabel")
		placeholder.Font = Enum.Font.BuilderSans
		placeholder.TextSize = 13
		placeholder.TextColor3 = M3_ON_SURFACE_VAR
		placeholder.TextXAlignment = Enum.TextXAlignment.Center
		placeholder.BackgroundTransparency = 1
		placeholder.Size = UDim2.new(1, 0, 0, 40)
		placeholder.Text = "No songs found on market."
		placeholder.Parent = marketListFrame
		table.insert(marketEntries, { frame = placeholder })
		return
	end
	for i, song in ipairs(songs) do
		local entryFrame = Instance.new("TextButton")
		entryFrame.Text = ""
		entryFrame.AutoButtonColor = false
		entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER
		entryFrame.BorderSizePixel = 0
		entryFrame.Size = UDim2.new(1, 0, 0, 56)
		entryFrame.LayoutOrder = i
		entryFrame.Parent = marketListFrame
		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 16)
		entryCorner.Parent = entryFrame
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Font = Enum.Font.BuilderSansMedium
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = M3_ON_SURFACE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -80, 0, 20)
		nameLabel.Position = UDim2.new(0, 14, 0, 8)
		nameLabel.Text = song.name or "Unknown"
		nameLabel.Parent = entryFrame
		local uploaderLabel = Instance.new("TextLabel")
		uploaderLabel.Font = Enum.Font.BuilderSans
		uploaderLabel.TextSize = 12
		uploaderLabel.TextColor3 = M3_ON_SURFACE_VAR
		uploaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		uploaderLabel.TextYAlignment = Enum.TextYAlignment.Top
		uploaderLabel.BackgroundTransparency = 1
		uploaderLabel.Size = UDim2.new(1, -80, 0, 16)
		uploaderLabel.Position = UDim2.new(0, 14, 0, 30)
		uploaderLabel.Text = "By: " .. (song.uploader or "Unknown") .. "  |  " .. tostring(song.bpm or 120) .. " BPM"
		uploaderLabel.Parent = entryFrame
		local playIcon = Instance.new("ImageLabel")
		playIcon.Size = UDim2.new(0, 20, 0, 20)
		playIcon.Position = UDim2.new(1, -34, 0.5, -10)
		playIcon.BackgroundTransparency = 1
		playIcon.Image = "rbxassetid://95237403972033"
		playIcon.ScaleType = Enum.ScaleType.Fit
		playIcon.ImageColor3 = M3_PRIMARY
		playIcon.Parent = entryFrame
		entryFrame.MouseButton1Click:Connect(function()
			playRandomPageSound()
			if pianoState.songPlaying then stopSong() end
			notify("Undercore", "Loading: " .. (song.name or "Unknown"), 2, ACCENT, "info")
			local ok2, code = pcall(function() return game:HttpGet(song.url, true) end)
			if not ok2 or not code then
				notify("Undercore", "Failed to fetch song.", 3, RED, "error")
				return
			end
			playSong(code, song.name or "Unknown", song.bpm or 120)
			updateNowPlaying()
			notify("Undercore", "Playing: " .. (song.name or "Unknown"), 3, GREEN, "success")
		end)
		entryFrame.MouseEnter:Connect(function()
			entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
		end)
		entryFrame.MouseLeave:Connect(function()
			entryFrame.BackgroundColor3 = M3_SURFACE_CONTAINER
		end)
		table.insert(marketEntries, { frame = entryFrame, song = song })
	end
	notify("Undercore", "Loaded " .. #songs .. " market songs.", 3, GREEN, "success")
end

refreshMarketBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	refreshMarketList()
end)

-- Upload section
createLabel(marketPage, "Share a Song")

local shareUrlBox = Instance.new("TextBox")
shareUrlBox.Font = Enum.Font.BuilderSans
shareUrlBox.TextSize = 13
shareUrlBox.TextColor3 = M3_ON_SURFACE
shareUrlBox.PlaceholderText = "Song URL (raw link to .txt file)"
shareUrlBox.PlaceholderColor3 = M3_ON_SURFACE_VAR
shareUrlBox.Text = ""
shareUrlBox.BackgroundColor3 = M3_SURFACE_CONTAINER
shareUrlBox.BorderSizePixel = 0
shareUrlBox.Size = UDim2.new(1, 0, 0, 36)
shareUrlBox.Parent = marketPage

local shareUrlCorner = Instance.new("UICorner")
shareUrlCorner.CornerRadius = UDim.new(0, 16)
shareUrlCorner.Parent = shareUrlBox

local shareUrlPad = Instance.new("UIPadding")
shareUrlPad.PaddingLeft = UDim.new(0, 12)
shareUrlPad.PaddingRight = UDim.new(0, 12)
shareUrlPad.Parent = shareUrlBox

local shareNameBox = Instance.new("TextBox")
shareNameBox.Font = Enum.Font.BuilderSans
shareNameBox.TextSize = 13
shareNameBox.TextColor3 = M3_ON_SURFACE
shareNameBox.PlaceholderText = "Song name"
shareNameBox.PlaceholderColor3 = M3_ON_SURFACE_VAR
shareNameBox.Text = ""
shareNameBox.BackgroundColor3 = M3_SURFACE_CONTAINER
shareNameBox.BorderSizePixel = 0
shareNameBox.Size = UDim2.new(1, -130, 0, 36)
shareNameBox.Parent = marketPage

local shareNameCorner = Instance.new("UICorner")
shareNameCorner.CornerRadius = UDim.new(0, 16)
shareNameCorner.Parent = shareNameBox

local shareNamePad = Instance.new("UIPadding")
shareNamePad.PaddingLeft = UDim.new(0, 12)
shareNamePad.PaddingRight = UDim.new(0, 12)
shareNamePad.Parent = shareNameBox

local shareBpmBox = Instance.new("TextBox")
shareBpmBox.Font = Enum.Font.BuilderSans
shareBpmBox.TextSize = 13
shareBpmBox.TextColor3 = M3_ON_SURFACE
shareBpmBox.PlaceholderText = "BPM"
shareBpmBox.PlaceholderColor3 = M3_ON_SURFACE_VAR
shareBpmBox.Text = "120"
shareBpmBox.BackgroundColor3 = M3_SURFACE_CONTAINER
shareBpmBox.BorderSizePixel = 0
shareBpmBox.Size = UDim2.new(0, 60, 0, 36)
shareBpmBox.Position = UDim2.new(1, -128, 0, 0)
shareBpmBox.Parent = marketPage

local shareBpmCorner = Instance.new("UICorner")
shareBpmCorner.CornerRadius = UDim.new(0, 16)
shareBpmCorner.Parent = shareBpmBox

local shareBpmPad = Instance.new("UIPadding")
shareBpmPad.PaddingLeft = UDim.new(0, 12)
shareBpmPad.PaddingRight = UDim.new(0, 12)
shareBpmPad.Parent = shareBpmBox

local copyShareBtn = Instance.new("TextButton")
copyShareBtn.Font = Enum.Font.BuilderSansMedium
copyShareBtn.TextSize = 14
copyShareBtn.TextColor3 = M3_ON_PRIMARY
copyShareBtn.Text = "Copy Share Code"
copyShareBtn.BackgroundColor3 = M3_PRIMARY
copyShareBtn.BorderSizePixel = 0
copyShareBtn.Size = UDim2.new(1, 0, 0, 40)
copyShareBtn.Parent = marketPage

local copyShareCorner = Instance.new("UICorner")
copyShareCorner.CornerRadius = UDim.new(0, 20)
copyShareCorner.Parent = copyShareBtn

copyShareBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	local url = shareUrlBox.Text
	local name = shareNameBox.Text
	local bpm = shareBpmBox.Text
	if url == "" or name == "" then
		notify("Undercore", "Fill in URL and song name.", 3, WARNING, "error")
		return
	end
	local shareCode = name .. "|" .. url .. "|" .. (bpm or "120")
	if setclipboard then
		setclipboard(shareCode)
		notify("Undercore", "Share code copied to clipboard!", 3, GREEN, "success")
	else
		notify("Undercore", "Share code: " .. shareCode, 5, ACCENT, "info")
	end
end)

copyShareBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

-- ===================
-- SETTINGS PAGE
-- ===================
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

local editModeBtn = Instance.new("TextButton")
editModeBtn.Font = Enum.Font.BuilderSansMedium
editModeBtn.TextSize = 14
editModeBtn.TextColor3 = M3_ON_PRIMARY
editModeBtn.Text = "EDIT INTERFACE (RightShift + E)"
editModeBtn.BackgroundColor3 = M3_PRIMARY
editModeBtn.BorderSizePixel = 0
editModeBtn.Size = UDim2.new(1, 0, 0, 48)
editModeBtn.Parent = settingsPage

local editModeBtnCorner = Instance.new("UICorner")
editModeBtnCorner.CornerRadius = UDim.new(0, 20)
editModeBtnCorner.Parent = editModeBtn

editModeBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	setEditMode(not editMode)
end)

editModeBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

local stopAllBtn = Instance.new("TextButton")
stopAllBtn.Font = Enum.Font.BuilderSansMedium
stopAllBtn.TextSize = 14
stopAllBtn.TextColor3 = M3_ON_ERROR
stopAllBtn.Text = "STOP ALL SONGS"
stopAllBtn.BackgroundColor3 = M3_ERROR_CONTAINER
stopAllBtn.BorderSizePixel = 0
stopAllBtn.Size = UDim2.new(1, 0, 0, 48)
stopAllBtn.Parent = settingsPage

local stopAllCorner = Instance.new("UICorner")
stopAllCorner.CornerRadius = UDim.new(0, 20)
stopAllCorner.Parent = stopAllBtn

stopAllBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	stopSong()
	pauseBtn.Text = "Pause"
	updateNowPlaying()
	notify("Undercore", "All songs stopped.", 3, ACCENT, "info")
end)

stopAllBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

local exitBtn = Instance.new("TextButton")
exitBtn.Font = Enum.Font.BuilderSansMedium
exitBtn.TextSize = 14
exitBtn.TextColor3 = M3_ON_ERROR
exitBtn.Text = "TERMINATE SCRIPT"
exitBtn.BackgroundColor3 = M3_ERROR
exitBtn.BorderSizePixel = 0
exitBtn.Size = UDim2.new(1, 0, 0, 48)
exitBtn.Parent = settingsPage

local exitBtnCorner = Instance.new("UICorner")
exitBtnCorner.CornerRadius = UDim.new(0, 20)
exitBtnCorner.Parent = exitBtn

exitBtn.MouseButton1Click:Connect(function()
	if exitDialogVisible then return end
	showExitDialog()
end)

exitBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

-- ===================
-- KEYBINDS PAGE
-- ===================
local keybindsPage = createPage("Keybinds")
local navKeybinds, navKeybindsIcon, navKeybindsLabel = createNavButton("Keybinds")
navButtons["Keybinds"] = { btn = navKeybinds, icon = navKeybindsIcon, label = navKeybindsLabel }
navKeybinds.MouseButton1Click:Connect(function() showPage("Keybinds") end)

createLabel(keybindsPage, "Keybinds")
createLabel(keybindsPage, "Click a button and press a key to bind. Backspace to unbind.")

local bindableActions = {
	{ name = "Play Selected Song", action = function()
		if selectedSong and not pianoState.songPlaying then
			local ok, code = pcall(function() return game:HttpGet(selectedSong.url, true) end)
			if ok and code then
				playSong(code, selectedSong.name, selectedSong.bpm)
				updateNowPlaying()
			end
		end
	end },
	{ name = "Stop Song", action = function()
		stopSong()
		pauseBtn.Text = "Pause"
		updateNowPlaying()
	end },
	{ name = "Pause/Resume", action = function()
		if pianoState.songPlaying then
			pauseSong()
			pauseBtn.Text = pianoState.songPaused and "Resume" or "Pause"
		end
	end },
	{ name = "BPM +10", action = function()
		pianoState.bpm = math.min(500, pianoState.bpm + 10)
		updateBpmDisplay()
	end },
	{ name = "BPM -10", action = function()
		pianoState.bpm = math.max(20, pianoState.bpm - 10)
		updateBpmDisplay()
	end },
}

for _, feature in ipairs(bindableActions) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = M3_SURFACE_CONTAINER
	row.BorderSizePixel = 0
	row.Parent = keybindsPage

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 16)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Font = Enum.Font.BuilderSansMedium
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = M3_ON_SURFACE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -110, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.Text = feature.name
	nameLabel.Parent = row

	local bindBtn = Instance.new("TextButton")
	bindBtn.Font = Enum.Font.BuilderSansMedium
	bindBtn.TextSize = 11
	bindBtn.TextColor3 = M3_ON_SURFACE
	bindBtn.BackgroundColor3 = M3_SURFACE_CONTAINER
	bindBtn.BorderSizePixel = 0
	bindBtn.Size = UDim2.new(0, 90, 0, 26)
	bindBtn.Position = UDim2.new(1, -102, 0.5, -13)
	bindBtn.AutoButtonColor = false
	bindBtn.Text = "UNBOUND"
	bindBtn.Parent = row

	local bindBtnCorner = Instance.new("UICorner")
	bindBtnCorner.CornerRadius = UDim.new(0, 13)
	bindBtnCorner.Parent = bindBtn

	local function updateText()
		for _, entry in ipairs(keybindEntries) do
			if entry.action == feature.action then
				bindBtn.Text = keyCodeName(entry.keyCode)
				bindBtn.BackgroundColor3 = M3_PRIMARY
				return
			end
		end
		bindBtn.Text = "UNBOUND"
		bindBtn.BackgroundColor3 = M3_SURFACE_CONTAINER
	end

	bindBtn.MouseButton1Click:Connect(function()
		playRandomPageSound()
		bindBtn.Text = "..."
		bindBtn.BackgroundColor3 = M3_TERTIARY
		listeningForKey = true
		keyCaptureCallback = function(keyCode)
			if keyCode == Enum.KeyCode.Unknown or keyCode == Enum.KeyCode.Backspace then
				for i = #keybindEntries, 1, -1 do
					if keybindEntries[i].action == feature.action then
						keybinds[keybindEntries[i].keyCode] = nil
						if keybindEntries[i].item then keybindEntries[i].item:Destroy() end
						table.remove(keybindEntries, i)
					end
				end
			else
				for i = #keybindEntries, 1, -1 do
					if keybindEntries[i].action == feature.action then
						keybinds[keybindEntries[i].keyCode] = nil
						if keybindEntries[i].item then keybindEntries[i].item:Destroy() end
						table.remove(keybindEntries, i)
					end
				end
				if keybinds[keyCode] then keybinds[keyCode] = nil end
				registerKeybind(keyCode, feature.name, nil, feature.action)
			end
			updateText()
		end
	end)

	bindBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)
end

-- ===================
-- ABOUT PAGE
-- ===================
local aboutPage = createPage("About")
local navAbout, navAboutIcon, navAboutLabel = createNavButton("About")
navButtons["About"] = { btn = navAbout, icon = navAboutIcon, label = navAboutLabel }
navAbout.MouseButton1Click:Connect(function() showPage("About") end)

createLabel(aboutPage, "About")

local aboutLogoRow = Instance.new("Frame")
aboutLogoRow.Size = UDim2.new(1, 0, 0, 40)
aboutLogoRow.BackgroundTransparency = 1
aboutLogoRow.BorderSizePixel = 0
aboutLogoRow.Parent = aboutPage

local aboutLogo = Instance.new("ImageLabel")
aboutLogo.Size = UDim2.new(0, 28, 0, 28)
aboutLogo.Position = UDim2.new(0, 10, 0.5, -14)
aboutLogo.BackgroundTransparency = 1
aboutLogo.Image = "rbxassetid://78552548457734"
aboutLogo.ScaleType = Enum.ScaleType.Fit
aboutLogo.Parent = aboutLogoRow

local aboutTitle = Instance.new("TextLabel")
aboutTitle.Font = Enum.Font.BuilderSansMedium
aboutTitle.TextSize = 16
aboutTitle.TextColor3 = M3_PRIMARY
aboutTitle.TextXAlignment = Enum.TextXAlignment.Left
aboutTitle.BackgroundTransparency = 1
aboutTitle.Size = UDim2.new(1, -48, 0, 40)
aboutTitle.Position = UDim2.new(0, 44, 0, 0)
aboutTitle.Text = "Undercore - Piano Autoplayer"
aboutTitle.Parent = aboutLogoRow

local aboutVersion = Instance.new("TextLabel")
aboutVersion.Font = Enum.Font.BuilderSans
aboutVersion.TextSize = 13
aboutVersion.TextColor3 = M3_ON_SURFACE_VAR
aboutVersion.TextXAlignment = Enum.TextXAlignment.Left
aboutVersion.BackgroundTransparency = 1
aboutVersion.Size = UDim2.new(1, 0, 0, 24)
aboutVersion.Text = "Version " .. SCRIPT_VERSION
aboutVersion.Parent = aboutPage

local aboutDesc = Instance.new("TextLabel")
aboutDesc.Font = Enum.Font.BuilderSans
aboutDesc.TextSize = 13
aboutDesc.TextColor3 = M3_ON_SURFACE_VAR
aboutDesc.TextXAlignment = Enum.TextXAlignment.Left
aboutDesc.TextWrapped = true
aboutDesc.BackgroundTransparency = 1
aboutDesc.Size = UDim2.new(1, 0, 0, 48)
aboutDesc.Text = "Piano autoplayer for Roblox Virtual Piano. Based on the TALENTLESS engine by hellohellohell012321. Play MIDI songs, browse the market, and share your music."
aboutDesc.Parent = aboutPage

local aboutSpacer = Instance.new("Frame")
aboutSpacer.Size = UDim2.new(1, 0, 0, 8)
aboutSpacer.BackgroundTransparency = 1
aboutSpacer.Parent = aboutPage

createLabel(aboutPage, "Support Us")

local supportDesc = Instance.new("TextLabel")
supportDesc.Font = Enum.Font.BuilderSans
supportDesc.TextSize = 13
supportDesc.TextColor3 = M3_ON_SURFACE_VAR
supportDesc.TextXAlignment = Enum.TextXAlignment.Left
supportDesc.TextWrapped = true
supportDesc.BackgroundTransparency = 1
supportDesc.Size = UDim2.new(1, 0, 0, 32)
supportDesc.Text = "Enjoying Undercore? Consider supporting development."
supportDesc.Parent = aboutPage

local donateBtn = Instance.new("TextButton")
donateBtn.Font = Enum.Font.BuilderSansMedium
donateBtn.TextSize = 14
donateBtn.TextColor3 = M3_ON_PRIMARY
donateBtn.BackgroundColor3 = M3_PRIMARY
donateBtn.AutoButtonColor = false
donateBtn.BorderSizePixel = 0
donateBtn.Size = UDim2.new(1, 0, 0, 36)
donateBtn.Text = "  Donate"
donateBtn.TextXAlignment = Enum.TextXAlignment.Left
donateBtn.TextYAlignment = Enum.TextYAlignment.Center
donateBtn.Parent = aboutPage

local donateCorner = Instance.new("UICorner")
donateCorner.CornerRadius = UDim.new(0, 18)
donateCorner.Parent = donateBtn

local donateIcon = Instance.new("ImageLabel")
donateIcon.Size = UDim2.new(0, 18, 0, 18)
donateIcon.Position = UDim2.new(1, -28, 0.5, -9)
donateIcon.BackgroundTransparency = 1
donateIcon.Image = "rbxassetid://136952031423283"
donateIcon.ScaleType = Enum.ScaleType.Fit
donateIcon.ImageColor3 = M3_ON_PRIMARY
donateIcon.Parent = donateBtn

donateBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	if setclipboard then
		setclipboard("https://www.donationalerts.com/r/neruka")
		notify("Undercore", "Donation link copied to clipboard!", 4, GREEN, "success")
	else
		notify("Undercore", "Visit: donationalerts.com/r/neruka", 6, ACCENT, "info")
	end
end)

donateBtn.MouseEnter:Connect(function()
	playSound(SOUND_HOVER, 1.0)
	TweenService:Create(donateBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = M3_PRIMARY_CONTAINER }):Play()
	TweenService:Create(donateIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageColor3 = M3_ON_PRIMARY_CONTAINER }):Play()
end)

donateBtn.MouseLeave:Connect(function()
	TweenService:Create(donateBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = M3_PRIMARY }):Play()
	TweenService:Create(donateIcon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageColor3 = M3_ON_PRIMARY }):Play()
end)

createLabel(aboutPage, "Controls")

local controlsText = Instance.new("TextLabel")
controlsText.Font = Enum.Font.BuilderSans
controlsText.TextSize = 13
controlsText.TextColor3 = M3_ON_SURFACE_VAR
controlsText.TextXAlignment = Enum.TextXAlignment.Left
controlsText.TextWrapped = true
controlsText.BackgroundTransparency = 1
controlsText.Size = UDim2.new(1, 0, 0, 56)
controlsText.Text = "Toggle menu: RightShift / K / F8\nToggle button: U\nHold F8 or U for 5s to terminate"
controlsText.Parent = aboutPage

createLabel(aboutPage, "Credits")

local creditsText = Instance.new("TextLabel")
creditsText.Font = Enum.Font.BuilderSans
creditsText.TextSize = 13
creditsText.TextColor3 = M3_ON_SURFACE_VAR
creditsText.TextXAlignment = Enum.TextXAlignment.Left
creditsText.TextWrapped = true
creditsText.BackgroundTransparency = 1
creditsText.Size = UDim2.new(1, 0, 0, 40)
creditsText.Text = "Piano engine: TALENTLESS by hellohellohell012321\nUI: Undercore by neruka"
creditsText.Parent = aboutPage

-- Default page
showPage("Songs")

-- ===================
-- HARD EXIT DIALOG
-- ===================
local showExitDialog
local hideExitDialog
local exitDialogVisible = false

local function initExitDialog()
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
dialogFrame.BackgroundColor3 = M3_SURFACE_CONTAINER_HIGH
dialogFrame.BorderSizePixel = 0
dialogFrame.Visible = false
dialogFrame.GroupColor3 = Color3.fromRGB(255, 255, 255)
dialogFrame.GroupTransparency = 1
dialogFrame.ZIndex = 10
dialogFrame.Parent = blurFrame

local dialogCorner = Instance.new("UICorner")
dialogCorner.CornerRadius = UDim.new(0, 28)
dialogCorner.Parent = dialogFrame

local dialogTitle = Instance.new("TextLabel")
dialogTitle.Font = Enum.Font.BuilderSansMedium
dialogTitle.TextSize = 18
dialogTitle.TextColor3 = M3_ON_SURFACE
dialogTitle.TextXAlignment = Enum.TextXAlignment.Center
dialogTitle.TextYAlignment = Enum.TextYAlignment.Center
dialogTitle.BackgroundTransparency = 1
dialogTitle.Size = UDim2.new(1, 0, 0, 40)
dialogTitle.Position = UDim2.new(0, 0, 0, 15)
dialogTitle.Text = "Undercore"
dialogTitle.Parent = dialogFrame

local dialogMsg = Instance.new("TextLabel")
dialogMsg.Font = Enum.Font.BuilderSans
dialogMsg.TextSize = 14
dialogMsg.TextColor3 = M3_ON_SURFACE_VAR
dialogMsg.TextXAlignment = Enum.TextXAlignment.Center
dialogMsg.TextYAlignment = Enum.TextYAlignment.Top
dialogMsg.BackgroundTransparency = 1
dialogMsg.Size = UDim2.new(1, -40, 0, 30)
dialogMsg.Position = UDim2.new(0, 20, 0, 55)
dialogMsg.TextWrapped = true
dialogMsg.Text = "Select an action:"
dialogMsg.Parent = dialogFrame

local cancelBtn = Instance.new("TextButton")
cancelBtn.Font = Enum.Font.BuilderSansMedium
cancelBtn.TextSize = 14
cancelBtn.TextColor3 = M3_ON_SURFACE
cancelBtn.Text = "Cancel"
cancelBtn.BackgroundColor3 = M3_SURFACE_VAR
cancelBtn.BorderSizePixel = 0
cancelBtn.Size = UDim2.new(0, 100, 0, 40)
cancelBtn.Position = UDim2.new(0, 20, 0, 145)
cancelBtn.Parent = dialogFrame

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 20)
cancelCorner.Parent = cancelBtn

local reloadBtn = Instance.new("TextButton")
reloadBtn.Font = Enum.Font.BuilderSansMedium
reloadBtn.TextSize = 14
reloadBtn.TextColor3 = M3_ON_PRIMARY
reloadBtn.Text = "Reload"
reloadBtn.BackgroundColor3 = M3_PRIMARY
reloadBtn.BorderSizePixel = 0
reloadBtn.Size = UDim2.new(0, 100, 0, 40)
reloadBtn.Position = UDim2.new(0.5, -50, 0, 145)
reloadBtn.Parent = dialogFrame

local reloadCorner = Instance.new("UICorner")
reloadCorner.CornerRadius = UDim.new(0, 20)
reloadCorner.Parent = reloadBtn

local confirmBtn = Instance.new("TextButton")
confirmBtn.Font = Enum.Font.BuilderSansMedium
confirmBtn.TextSize = 14
confirmBtn.TextColor3 = M3_ON_ERROR
confirmBtn.Text = "Terminate"
confirmBtn.BackgroundColor3 = M3_ERROR
confirmBtn.BorderSizePixel = 0
confirmBtn.Size = UDim2.new(0, 100, 0, 40)
confirmBtn.Position = UDim2.new(1, -120, 0, 145)
confirmBtn.Parent = dialogFrame

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 20)
confirmCorner.Parent = confirmBtn

local infoText = Instance.new("TextLabel")
infoText.Font = Enum.Font.BuilderSans
infoText.TextSize = 12
infoText.TextColor3 = M3_ON_SURFACE_VAR
infoText.TextXAlignment = Enum.TextXAlignment.Center
infoText.TextYAlignment = Enum.TextYAlignment.Center
infoText.BackgroundTransparency = 1
infoText.Size = UDim2.new(1, -40, 0, 20)
infoText.Position = UDim2.new(0, 20, 0, 190)
infoText.Text = "Terminate stops all songs and closes the script"
infoText.Parent = dialogFrame

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

cancelBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	hideExitDialog()
end)

cancelBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

blurFrame.MouseButton1Click:Connect(function() end)

reloadBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	hideExitDialog()
	stopSong()
	terminated = true
	if menuVisible then
		closeMenu()
		task.wait(0.8)
	end
	for _, conn in ipairs(_G.UndercoreConnections or {}) do
		pcall(function() conn:Disconnect() end)
	end
	_G.UndercoreConnections = nil
	blurEffect:Destroy()
	exitDialogGui:Destroy()
	gui:Destroy()
	notify("Undercore", "Restarting script...", 3, ACCENT, "info")
	task.wait(3)
	notify("Undercore", "Script closed. Relaunching...", 3, GREEN, "success")
	task.wait(3)
	notifGui:Destroy()
	local reloadUrl = "https://gitlab.com/api/v4/projects/neruka783-group%2FUndercore/repository/files/undercore.lua/raw?ref=main&v=" .. tostring(tick())
	local ok, content = pcall(function() return game:HttpGet(reloadUrl, true) end)
	if not ok or not content then
		reloadUrl = "https://raw.githubusercontent.com/MortexSchmidt/Pianos/main/undercore.lua?v=" .. tostring(tick())
		ok, content = pcall(function() return game:HttpGet(reloadUrl, true) end)
	end
	if ok and content then
		local fn, err = loadstring(content)
		if fn then fn() else print("[Undercore] Reload failed - loadstring error:", err) end
	else
		print("[Undercore] Reload failed - HttpGet error:", content)
	end
end)

confirmBtn.MouseButton1Click:Connect(function()
	playRandomPageSound()
	hideExitDialog()
	hideExitDialog = nil
	terminated = true
	stopSong()
	if menuVisible then
		closeMenu()
		task.wait(0.8)
	end
	for _, conn in ipairs(_G.UndercoreConnections or {}) do
		pcall(function() conn:Disconnect() end)
	end
	_G.UndercoreConnections = nil
	blurEffect:Destroy()
	exitDialogGui:Destroy()
	gui:Destroy()
	notifGui:Destroy()
end)

reloadBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)
confirmBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

showExitDialog = showExitDialogImpl
hideExitDialog = hideExitDialogImpl
end -- initExitDialog function
initExitDialog()

-- ===================
-- TOGGLE BUTTON
-- ===================
local scriptReady = false
local toggleBtn
local function initToggleButton()
	toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Text = ""
toggleBtn.AutoButtonColor = false
toggleBtn.BackgroundColor3 = M3_SURFACE_CONTAINER
toggleBtn.BorderSizePixel = 0
toggleBtn.Size = UDim2.new(0, 40, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0, 10)
toggleBtn.ZIndex = 50
toggleBtn.Visible = false
toggleBtn.Parent = gui
makeDraggable(toggleBtn)

local toggleBtnIcon = Instance.new("ImageLabel")
toggleBtnIcon.Name = "Logo"
toggleBtnIcon.Size = UDim2.new(0, 24, 0, 24)
toggleBtnIcon.Position = UDim2.new(0.5, -12, 0.5, -12)
toggleBtnIcon.BackgroundTransparency = 1
toggleBtnIcon.Image = "rbxassetid://78552548457734"
toggleBtnIcon.ScaleType = Enum.ScaleType.Fit
toggleBtnIcon.ZIndex = 51
toggleBtnIcon.Parent = toggleBtn

local toggleBtnCorner = Instance.new("UICorner")
toggleBtnCorner.CornerRadius = UDim.new(0, 20)
toggleBtnCorner.Parent = toggleBtn

local toggleBtnStroke = Instance.new("UIStroke")
toggleBtnStroke.Color = M3_OUTLINE
toggleBtnStroke.Thickness = 1
toggleBtnStroke.Transparency = 0
toggleBtnStroke.Parent = toggleBtn

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

toggleBtn.MouseButton1Down:Connect(function() startHold() end)
toggleBtn.MouseButton1Up:Connect(function() cancelHold() end)
toggleBtn.MouseLeave:Connect(function() cancelHold() end)

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

toggleBtn.MouseEnter:Connect(function() playSound(SOUND_HOVER, 1.0) end)

trackConn(UserInputService.InputBegan:Connect(function(input, processed)
	if not scriptReady then return end
	if editMode and input.KeyCode == Enum.KeyCode.Backspace then
		setEditMode(false)
		return
	end
	if input.KeyCode == Enum.KeyCode.E and UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		setEditMode(not editMode)
		return
	end
	if listeningForKey then
		listeningForKey = false
		if keyCaptureCallback then
			keyCaptureCallback(input.KeyCode)
		end
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.K then
		if menuVisible then closeMenu() else openMenu() end
	elseif input.KeyCode == Enum.KeyCode.F8 then
		startHold()
	elseif keybinds[input.KeyCode] then
		local bind = keybinds[input.KeyCode]
		if bind.toggle then
			bind.toggle.set(not bind.toggle.get())
		elseif bind.action then
			bind.action()
		end
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

trackConn(UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end))

end -- initToggleButton function
initToggleButton()

-- ===================
-- INJECTION SEQUENCE
-- ===================
local function initInjection()
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

updateBanner.MouseButton1Click:Connect(function()
	if not menuVisible then
		openMenu()
		task.wait(0.5)
	end
	showPage("Settings")
	task.wait(0.5)
	showExitDialog()
end)

task.spawn(function()
	task.wait(0.5)
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

end -- initInjection function
initInjection()

-- Expose
_G.UndercoreNotify = notify
