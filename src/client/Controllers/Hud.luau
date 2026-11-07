--!strict
-- Renders the round and the player's numbers. Everything shown comes from
-- attributes the server publishes, so a late joiner starts with correct values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local AMBER = Color3.fromRGB(255, 200, 40)
local DANGER = Color3.fromRGB(255, 80, 60)
local PANEL = Color3.fromRGB(28, 24, 22)
local WHITE = Color3.fromRGB(245, 240, 232)
local NOTICE_SECONDS = 2.5
local STAT_TEXT_SIZE = 20
local POP_TEXT_SIZE = 26
local POP_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

local HEADLINES = {
	Intermission = "NEXT SHIFT",
	Shift = "SHIFT",
	Collapse = "COLLAPSE! GET OUT!",
}

local localPlayer = Players.LocalPlayer
local phaseLabel: TextLabel
local timerLabel: TextLabel
local haulLabel: TextLabel
local bankLabel: TextLabel
local sticksLabel: TextLabel
local noticeLabel: TextLabel
local hintLabel: TextLabel
local noticeToken = 0
local shownGold: { [TextLabel]: number } = {}

local Hud = {}

local function makeLabel(parent: Instance, size: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextSize = textSize
	label.Text = ""
	label.Parent = parent
	return label
end

local function makePanel(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.Position = position
	panel.AnchorPoint = anchor
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	return panel
end

local function showGold(label: TextLabel, name: string, value: number)
	label.Text = `{name}  {value}`

	local previous = shownGold[label]
	shownGold[label] = value
	if previous and value > previous then
		label.TextSize = STAT_TEXT_SIZE
		TweenService:Create(label, POP_INFO, { TextSize = POP_TEXT_SIZE }):Play()
	end
end

local function refreshStats()
	local carried = localPlayer:GetAttribute("Carried") or 0
	local banked = localPlayer:GetAttribute("Banked") or 0
	local sticks = localPlayer:GetAttribute("Sticks") or 0
	local maxSticks = localPlayer:GetAttribute("MaxSticks") or Config.MAX_STICKS
	showGold(haulLabel, "Haul", carried)
	showGold(bankLabel, "Banked", banked)
	sticksLabel.Text = `Dynamite  {sticks}/{maxSticks}`
end

local function refreshPhase()
	local phase = workspace:GetAttribute("Phase")
	phaseLabel.Text = HEADLINES[phase] or ""
	phaseLabel.TextColor3 = if phase == "Collapse" then DANGER else AMBER
	hintLabel.Visible = phase == "Intermission"
end

local function showNotice(text: unknown)
	if typeof(text) ~= "string" then
		return
	end

	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = text
	noticeLabel.TextTransparency = 0
	noticeLabel.TextStrokeTransparency = 0.3

	task.delay(NOTICE_SECONDS, function()
		if token == noticeToken then
			local fade = TweenInfo.new(0.4)
			TweenService:Create(noticeLabel, fade, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
	end)
end

local function refreshTimer()
	local endsAt = workspace:GetAttribute("PhaseEndsAt")
	if typeof(endsAt) == "number" then
		local seconds = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		timerLabel.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	end
end

function Hud.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DynamiteHud"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local top =
		makePanel(gui, UDim2.fromOffset(260, 72), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	phaseLabel = makeLabel(top, UDim2.new(1, 0, 0, 28), 18, AMBER)
	phaseLabel.Position = UDim2.fromOffset(0, 6)
	timerLabel = makeLabel(top, UDim2.new(1, 0, 0, 34), 30, WHITE)
	timerLabel.Position = UDim2.fromOffset(0, 32)

	local stats =
		makePanel(gui, UDim2.fromOffset(220, 96), UDim2.new(0, 12, 1, -12), Vector2.new(0, 1))
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.Parent = stats
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.Parent = stats

	haulLabel = makeLabel(stats, UDim2.new(1, 0, 0, 26), STAT_TEXT_SIZE, AMBER)
	bankLabel = makeLabel(stats, UDim2.new(1, 0, 0, 26), STAT_TEXT_SIZE, WHITE)
	sticksLabel = makeLabel(stats, UDim2.new(1, 0, 0, 26), STAT_TEXT_SIZE, WHITE)
	for _, label in { haulLabel, bankLabel, sticksLabel } do
		label.TextXAlignment = Enum.TextXAlignment.Left
	end

	noticeLabel = makeLabel(gui, UDim2.new(1, -32, 0, 40), 26, WHITE)
	noticeLabel.AnchorPoint = Vector2.new(0.5, 0)
	noticeLabel.Position = UDim2.new(0.5, 0, 0, 96)
	noticeLabel.TextStrokeColor3 = PANEL
	noticeLabel.TextTransparency = 1
	noticeLabel.TextStrokeTransparency = 1

	hintLabel = makeLabel(gui, UDim2.new(1, -32, 0, 60), 20, WHITE)
	hintLabel.AnchorPoint = Vector2.new(0.5, 0)
	hintLabel.Position = UDim2.new(0.5, 0, 0, 140)
	hintLabel.TextWrapped = true
	hintLabel.TextStrokeColor3 = PANEL
	hintLabel.TextStrokeTransparency = 0.3
	hintLabel.Text = "Click rock to plant dynamite. Ore gets richer the deeper you go.\n"
		.. "Carry your haul back over the bank line before the mine collapses!"

	for _, name in { "Carried", "Banked", "Sticks", "MaxSticks" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	Net.get("Notice").OnClientEvent:Connect(showNotice)

	refreshStats()
	refreshPhase()
end

function Hud.start()
	RunService.Heartbeat:Connect(refreshTimer)
end

return Hud
