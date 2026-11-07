--!strict
-- The shop: upgrades, then dynamite skins. It shows what the server has
-- published and requests purchases; the server decides whether each goes
-- through.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RankLogic = require(ReplicatedStorage.Shared.Util.RankLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Util.UpgradeLogic)

local AMBER = Color3.fromRGB(255, 200, 40)
local CARD = Color3.fromRGB(46, 40, 36)
local DISABLED = Color3.fromRGB(80, 74, 70)
local INK = Color3.fromRGB(28, 24, 22)
local MUTED = Color3.fromRGB(190, 180, 170)
local WHITE = Color3.fromRGB(245, 240, 232)

local OPEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Row = {
	upgrade: Types.Upgrade,
	levelLabel: TextLabel,
	buyButton: TextButton,
}

type SkinRow = {
	skin: Types.Skin,
	statusLabel: TextLabel,
	button: TextButton,
}

local localPlayer = Players.LocalPlayer
local rows: { Row } = {}
local skinRows: { SkinRow } = {}
local panel: Frame
local panelScale: UIScale
local goldLabel: TextLabel
local activeTween: Tween? = nil
local isOpen = false

local ShopUI = {}

local function makeText(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function styleButton(button: TextButton, text: string, enabled: boolean)
	button.Text = text
	button.BackgroundColor3 = if enabled then AMBER else DISABLED
	button.TextColor3 = if enabled then INK else MUTED
	button.AutoButtonColor = enabled
	button.Active = enabled
end

local function refreshSkins(gold: number)
	local rankIndex = localPlayer:GetAttribute("Rank")
	local rank = if typeof(rankIndex) == "number" then rankIndex else 1
	local equipped = localPlayer:GetAttribute("Skin")

	for _, row in skinRows do
		local skin = row.skin
		local owned = localPlayer:GetAttribute(`Skin_{skin.id}`) == true
		if skin.rank > rank then
			row.statusLabel.Text = `Needs {RankLogic.get(skin.rank).name} rank`
			styleButton(row.button, "LOCKED", false)
		elseif equipped == skin.id then
			row.statusLabel.Text = "Equipped"
			styleButton(row.button, "EQUIPPED", false)
		elseif owned then
			row.statusLabel.Text = "Owned"
			styleButton(row.button, "EQUIP", true)
		else
			row.statusLabel.Text = "Not owned"
			styleButton(row.button, `{skin.price} gold`, gold >= skin.price)
		end
	end
end

local function refresh()
	goldLabel.Text = `{localPlayer:GetAttribute("Banked") or 0} gold`
	local gold = localPlayer:GetAttribute("Banked") or 0
	refreshSkins(gold)

	for _, row in rows do
		local upgrade = row.upgrade
		local level = localPlayer:GetAttribute(`Level_{upgrade.id}`) or 0
		local maxed = level >= upgrade.maxLevel
		local price = UpgradeLogic.price(upgrade, level)
		local canBuy = not maxed and gold >= price

		row.levelLabel.Text = `Level {level}/{upgrade.maxLevel}`
		styleButton(row.buyButton, if maxed then "MAX" else `{price} gold`, canBuy)
	end
end

local function playScale(info: TweenInfo, target: number): Tween
	if activeTween then
		activeTween:Cancel()
	end
	local tween = TweenService:Create(panelScale, info, { Scale = target })
	activeTween = tween
	tween:Play()
	return tween
end

local function setOpen(open: boolean)
	isOpen = open
	if open then
		refresh()
		panel.Visible = true
		playScale(OPEN_INFO, 1)
	else
		playScale(CLOSE_INFO, 0).Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				panel.Visible = false
			end
		end)
	end
end

local function makeCard(parent: Instance, order: number): Frame
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -10, 0, 78)
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	card.Parent = parent
	round(card, 8)
	return card
end

local function makeCardButton(card: Frame): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(100, 44)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = card
	round(button, 8)
	return button
end

local function makeHeading(parent: Instance, text: string, order: number)
	local heading = makeText(parent, UDim2.new(1, -10, 0, 28), UDim2.new(), 18, AMBER)
	heading.LayoutOrder = order
	heading.TextYAlignment = Enum.TextYAlignment.Bottom
	heading.Text = text
end

local function makeSkinRow(parent: Instance, skin: Types.Skin, order: number)
	local card = makeCard(parent, order)

	-- A swatch in the stick's colour, edged with its spark colour.
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(14, 54)
	swatch.Position = UDim2.fromOffset(12, 12)
	swatch.BackgroundColor3 = skin.stick
	swatch.BorderSizePixel = 0
	swatch.Parent = card
	round(swatch, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = skin.spark
	stroke.Thickness = 2
	stroke.Parent = swatch

	makeText(card, UDim2.new(1, -150, 0, 22), UDim2.fromOffset(38, 8), 17, WHITE).Text = skin.name
	local description =
		makeText(card, UDim2.new(1, -150, 0, 18), UDim2.fromOffset(38, 30), 13, MUTED)
	description.Text = skin.description
	description.TextTruncate = Enum.TextTruncate.AtEnd
	local statusLabel =
		makeText(card, UDim2.new(1, -150, 0, 18), UDim2.fromOffset(38, 52), 13, AMBER)

	local button = makeCardButton(card)
	button.Activated:Connect(function()
		if button.Active then
			Net.get("SelectSkin"):FireServer(skin.id)
		end
	end)

	table.insert(skinRows, { skin = skin, statusLabel = statusLabel, button = button })
end

local function makeRow(parent: Instance, upgrade: Types.Upgrade, order: number)
	local card = makeCard(parent, order)

	makeText(card, UDim2.new(1, -124, 0, 22), UDim2.fromOffset(12, 8), 17, WHITE).Text =
		upgrade.name

	local description =
		makeText(card, UDim2.new(1, -124, 0, 18), UDim2.fromOffset(12, 30), 13, MUTED)
	description.Text = upgrade.description
	description.TextTruncate = Enum.TextTruncate.AtEnd

	local levelLabel =
		makeText(card, UDim2.new(1, -124, 0, 18), UDim2.fromOffset(12, 52), 13, AMBER)

	local buyButton = makeCardButton(card)

	buyButton.Activated:Connect(function()
		if buyButton.Active then
			Net.get("BuyUpgrade"):FireServer(upgrade.id)
		end
	end)

	table.insert(rows, { upgrade = upgrade, levelLabel = levelLabel, buyButton = buyButton })
end

local function buildPanel(gui: ScreenGui)
	panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(0.9, 0.7)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = INK
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	round(panel, 12)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 440)
	limit.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Scale = 0
	panelScale.Parent = panel

	makeText(panel, UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(16, 12), 22, AMBER).Text = "Shop"
	goldLabel = makeText(panel, UDim2.new(0.5, -60, 0, 30), UDim2.new(0.5, 0, 0, 12), 17, WHITE)
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(36, 36)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 9)
	closeButton.BackgroundColor3 = CARD
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = WHITE
	closeButton.TextSize = 16
	closeButton.Parent = panel
	round(closeButton, 8)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -24, 1, -68)
	list.Position = UDim2.fromOffset(16, 56)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	makeHeading(list, "Upgrades", nextOrder())
	for _, upgrade in Config.UPGRADES do
		makeRow(list, upgrade, nextOrder())
	end
	makeHeading(list, "Dynamite Skins", nextOrder())
	for _, skin in Config.SKINS do
		makeSkinRow(list, skin, nextOrder())
	end
end

local function onToggle(
	_: string,
	state: Enum.UserInputState,
	_: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		setOpen(not isOpen)
	end
	return Enum.ContextActionResult.Pass
end

function ShopUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DynamiteShop"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local openButton = Instance.new("TextButton")
	openButton.Size = UDim2.fromOffset(120, 40)
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.new(0, 12, 1, -140)
	openButton.BackgroundColor3 = AMBER
	openButton.BorderSizePixel = 0
	openButton.Font = Enum.Font.GothamBold
	openButton.Text = if touchOnly then "Shop" else "Shop (B)"
	openButton.TextColor3 = INK
	openButton.TextSize = 17
	openButton.Parent = gui
	round(openButton, 8)
	openButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	buildPanel(gui)

	localPlayer:GetAttributeChangedSignal("Banked"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("Rank"):Connect(refresh)
	localPlayer:GetAttributeChangedSignal("Skin"):Connect(refresh)
	for _, skin in Config.SKINS do
		localPlayer:GetAttributeChangedSignal(`Skin_{skin.id}`):Connect(refresh)
	end
	for _, upgrade in Config.UPGRADES do
		localPlayer:GetAttributeChangedSignal(`Level_{upgrade.id}`):Connect(refresh)
	end
	ContextActionService:BindAction(
		"ToggleShop",
		onToggle,
		false,
		Enum.KeyCode.B,
		Enum.KeyCode.ButtonY
	)
	refresh()
end

function ShopUI.start() end

return ShopUI
