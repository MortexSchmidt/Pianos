-- NVIDIA-style TALENTLESS Menu + Notification System
-- Inject via executor

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- Colors
local ACCENT = Color3.fromRGB(255, 200, 0) -- yellow accent
local CARD_BLACK = Color3.fromRGB(12, 12, 12)
local CARD_DARK = Color3.fromRGB(18, 18, 18)
local TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local TEXT_GRAY = Color3.fromRGB(160, 160, 160)
local STRIP_WIDTH = 3

-- ===================
-- NOTIFICATION SYSTEM
-- ===================
local NOTIF_WIDTH = 320
local MARGIN_TOP = 50
local GAP = 6
local notifications = {}

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "NvidiaNotifGui"
notifGui.ResetOnSpawn = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.DisplayOrder = 100
notifGui.Parent = CoreGui

local container = Instance.new("Frame")
container.Name = "NotificationContainer"
container.AnchorPoint = Vector2.new(1, 0)
container.Position = UDim2.new(1, 0, 0, MARGIN_TOP)
container.Size = UDim2.new(0, NOTIF_WIDTH, 1, -MARGIN_TOP - 20)
container.BackgroundTransparency = 1
container.Parent = notifGui

local function recalcPositions()
	local y = 0
	for _, data in ipairs(notifications) do
		if not data.dismissed then
			TweenService:Create(
				data.frame,
				TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, 0, 0, y) }
			):Play()
			y = y + data.height + GAP
		end
	end
end

local function dismiss(data)
	if data.dismissed then return end
	data.dismissed = true

	local card = data.frame
	local overlay = data.greenOverlay

	overlay.Visible = true
	overlay.Size = UDim2.new(0, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)

	local sweepOut = TweenService:Create(
		overlay,
		TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, 0, 1, 0) }
	)
	sweepOut:Play()
	sweepOut.Completed:Wait()

	local slideOut = TweenService:Create(
		card,
		TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, card.Position.Y.Offset), GroupTransparency = 1 }
	)
	slideOut:Play()
	slideOut.Completed:Wait()
	card:Destroy()

	for i, n in ipairs(notifications) do
		if n == data then
			table.remove(notifications, i)
			break
		end
	end
	recalcPositions()
end

local function notify(title, message, duration, status)
	duration = duration or 5
	status = status or "SYSTEM"

	local y = 0
	for _, n in ipairs(notifications) do
		if not n.dismissed then
			y = y + n.height + GAP
		end
	end

	local card = Instance.new("CanvasGroup")
	card.Name = "Notification"
	card.Size = UDim2.new(0, NOTIF_WIDTH, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = CARD_BLACK
	card.BackgroundTransparency = 0
	card.GroupTransparency = 0
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0, NOTIF_WIDTH + 10, 0, y)
	card.Parent = container

	local strip = Instance.new("Frame")
	strip.Name = "AccentStrip"
	strip.Size = UDim2.new(0, STRIP_WIDTH, 1, 0)
	strip.Position = UDim2.new(0, 0, 0, 0)
	strip.BackgroundColor3 = ACCENT
	strip.BorderSizePixel = 0
	strip.ZIndex = 5
	strip.Parent = card

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -STRIP_WIDTH, 0, 0)
	content.Position = UDim2.new(0, STRIP_WIDTH, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 4)
	layout.Parent = content

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 10
	statusLabel.TextColor3 = ACCENT
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, 0, 0, 0)
	statusLabel.AutomaticSize = Enum.AutomaticSize.Y
	statusLabel.Text = status:upper()
	statusLabel.Parent = content

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
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

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextSize = 12
	messageLabel.TextColor3 = TEXT_GRAY
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.BackgroundTransparency = 1
	messageLabel.Size = UDim2.new(1, 0, 0, 0)
	messageLabel.AutomaticSize = Enum.AutomaticSize.Y
	messageLabel.TextWrapped = true
	messageLabel.Text = message
	messageLabel.Parent = content

	local overlay = Instance.new("Frame")
	overlay.Name = "AccentOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = ACCENT
	overlay.BorderSizePixel = 0
	overlay.Visible = true
	overlay.ZIndex = 10
	overlay.Parent = card

	task.defer(function()
		task.wait()
		local height = card.AbsoluteSize.Y
		if height <= 0 then
			task.wait()
			height = card.AbsoluteSize.Y
		end

		local data = { frame = card, height = height, dismissed = false, greenOverlay = overlay }
		table.insert(notifications, data)

		local slideIn = TweenService:Create(
			card,
			TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, 0, 0, y) }
		)
		slideIn:Play()
		slideIn.Completed:Wait()

		local collapse = TweenService:Create(
			overlay,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, STRIP_WIDTH, 1, 0) }
		)
		collapse:Play()
		collapse.Completed:Wait()
		overlay.Visible = false

		task.delay(duration, function()
			dismiss(data)
		end)
	end)
end

-- ===================
-- MENU UI (NVIDIA style)
-- ===================
local menuGui = Instance.new("ScreenGui")
menuGui.Name = "NvidiaMenuGui"
menuGui.ResetOnSpawn = false
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.DisplayOrder = 99
menuGui.Parent = CoreGui

local menuVisible = false

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 475, 0, 300)
mainFrame.BackgroundColor3 = CARD_BLACK
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = menuGui

-- Accent strip on left
local menuStrip = Instance.new("Frame")
menuStrip.Name = "AccentStrip"
menuStrip.Size = UDim2.new(0, STRIP_WIDTH, 1, 0)
menuStrip.Position = UDim2.new(0, 0, 0, 0)
menuStrip.BackgroundColor3 = ACCENT
menuStrip.BorderSizePixel = 0
menuStrip.ZIndex = 5
menuStrip.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, -STRIP_WIDTH, 0, 45)
titleBar.Position = UDim2.new(0, STRIP_WIDTH, 0, 0)
titleBar.BackgroundColor3 = CARD_DARK
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 18
titleText.TextColor3 = TEXT_WHITE
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.BackgroundTransparency = 1
titleText.Size = UDim2.new(1, -80, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.Text = "TALENTLESS"
titleText.Parent = titleBar

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, -20, 0.5, -4)
statusDot.AnchorPoint = Vector2.new(0, 0)
statusDot.BackgroundColor3 = ACCENT
statusDot.BorderSizePixel = 0
statusDot.Parent = titleText

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = TEXT_GRAY
closeText = "X"
closeBtn.Text = "X"
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.Parent = titleBar

closeBtn.MouseButton1Click:Connect(function()
	menuVisible = false
	mainFrame.Visible = false
end)

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Name = "Content"
contentArea.Size = UDim2.new(1, -STRIP_WIDTH, 1, -45)
contentArea.Position = UDim2.new(0, STRIP_WIDTH, 0, 45)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 15)
contentPadding.PaddingBottom = UDim.new(0, 15)
contentPadding.PaddingLeft = UDim.new(0, 15)
contentPadding.PaddingRight = UDim.new(0, 15)
contentPadding.Parent = contentArea

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
contentLayout.Padding = UDim.new(0, 10)
contentLayout.Parent = contentArea

-- Song info
local songInfoLabel = Instance.new("TextLabel")
songInfoLabel.Name = "SongInfo"
songInfoLabel.Font = Enum.Font.Gotham
songInfoLabel.TextSize = 13
songInfoLabel.TextColor3 = TEXT_GRAY
songInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
songInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
songInfoLabel.BackgroundTransparency = 1
songInfoLabel.Size = UDim2.new(1, 0, 0, 0)
songInfoLabel.AutomaticSize = Enum.AutomaticSize.Y
songInfoLabel.TextWrapped = true
songInfoLabel.Text = "No song loaded"
songInfoLabel.Parent = contentArea

-- BPM display
local bpmFrame = Instance.new("Frame")
bpmFrame.Name = "BPMFrame"
bpmFrame.Size = UDim2.new(1, 0, 0, 40)
bpmFrame.BackgroundColor3 = CARD_DARK
bpmFrame.BorderSizePixel = 0
bpmFrame.Parent = contentArea

local bpmLabel = Instance.new("TextLabel")
bpmLabel.Name = "BPM"
bpmLabel.Font = Enum.Font.GothamBold
bpmLabel.TextSize = 20
bpmLabel.TextColor3 = ACCENT
bpmLabel.TextXAlignment = Enum.TextXAlignment.Center
bpmLabel.TextYAlignment = Enum.TextYAlignment.Center
bpmLabel.BackgroundTransparency = 1
bpmLabel.Size = UDim2.new(1, 0, 1, 0)
bpmLabel.Text = "BPM: --"
bpmLabel.Parent = bpmFrame

-- Buttons
local function createButton(text, color)
	local btn = Instance.new("TextButton")
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = TEXT_WHITE
	btn.Text = text
	btn.BackgroundColor3 = color or CARD_DARK
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, 35)
	btn.Parent = contentArea

	local btnStrip = Instance.new("Frame")
	btnStrip.Name = "AccentStrip"
	btnStrip.Size = UDim2.new(0, STRIP_WIDTH, 1, 0)
	btnStrip.Position = UDim2.new(0, 0, 0, 0)
	btnStrip.BackgroundColor3 = ACCENT
	btnStrip.BorderSizePixel = 0
	btnStrip.ZIndex = 5
	btnStrip.Parent = btn

	return btn
end

local playBtn = createButton("PLAY", CARD_DARK)
local stopBtn = createButton("STOP", CARD_DARK)
local loadBtn = createButton("LOAD TALENTLESS", CARD_DARK)

-- Toggle key (RightShift)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
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
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
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
-- INJECTION NOTIFICATION
-- ===================
task.wait(1)
notify("TALENTLESS", "Скрипт успешно заинжекчен", 5, "INJECTED")

-- Load button
loadBtn.MouseButton1Click:Connect(function()
	notify("TALENTLESS", "Загрузка основного скрипта...", 3, "LOADING")
	local success, err = pcall(function()
		loadstring(game:HttpGet("https://hellohellohell0.com/talentless-raw/TALENTLESS.lua", true))()
	end)
	if success then
		notify("TALENTLESS", "Скрипт загружен успешно", 3, "SUCCESS")
	else
		notify("TALENTLESS", "Ошибка: " .. tostring(err), 4, "ERROR")
	end
end)

-- Expose
_G.Notify = notify
