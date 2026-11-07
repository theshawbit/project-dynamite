--!strict
-- The end-of-shift summary. The server sends the totals; this only shows them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local ScaledRoot = require(script.Parent.Parent.Util.ScaledRoot)

local AMBER = Color3.fromRGB(255, 200, 40)
local DANGER = Color3.fromRGB(255, 80, 60)
local INK = Color3.fromRGB(28, 24, 22)
local WHITE = Color3.fromRGB(245, 240, 232)

local SHOW_SECONDS = 9
local OPEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local localPlayer = Players.LocalPlayer
local panel: Frame
local panelScale: UIScale
local bankedLabel: TextLabel
local lostLabel: TextLabel
local activeTween: Tween? = nil
local showToken = 0

local ResultsUI = {}

local function makeLabel(position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 28)
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextSize = textSize
	label.Parent = panel
	return label
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

local function hide()
	playScale(CLOSE_INFO, 0).Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			panel.Visible = false
		end
	end)
end

local function onSummary(banked: unknown, lost: unknown)
	if typeof(banked) ~= "number" or typeof(lost) ~= "number" then
		return
	end

	bankedLabel.Text = `Banked  {banked} gold`
	lostLabel.Text = `Lost  {lost} gold`
	panel.Visible = true
	playScale(OPEN_INFO, 1)

	showToken += 1
	local token = showToken
	task.delay(SHOW_SECONDS, function()
		if token == showToken then
			hide()
		end
	end)
end

function ResultsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DynamiteResults"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local root = ScaledRoot.create(gui)

	panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(300, 116)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 210)
	panel.BackgroundColor3 = INK
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	panelScale = Instance.new("UIScale")
	panelScale.Scale = 0
	panelScale.Parent = panel

	makeLabel(UDim2.fromOffset(0, 10), 20, WHITE).Text = "SHIFT COMPLETE"
	bankedLabel = makeLabel(UDim2.fromOffset(0, 44), 20, AMBER)
	lostLabel = makeLabel(UDim2.fromOffset(0, 74), 20, DANGER)

	Net.get("ShiftSummary").OnClientEvent:Connect(onSummary)
end

function ResultsUI.start() end

return ResultsUI
