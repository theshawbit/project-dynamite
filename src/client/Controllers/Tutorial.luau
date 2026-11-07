--!strict
-- Shows new players one tip at a time. The tips follow published attributes,
-- so a rejoining player picks up wherever their saved progress puts them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local TutorialLogic = require(ReplicatedStorage.Shared.Util.TutorialLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local ScaledRoot = require(script.Parent.Parent.Util.ScaledRoot)

local AMBER = Color3.fromRGB(255, 200, 40)
local INK = Color3.fromRGB(28, 24, 22)

local localPlayer = Players.LocalPlayer
local tipLabel: TextLabel
local cheapestUpgrade = math.huge

local Tutorial = {}

local function tipFor(step: Types.TutorialStep): string
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if step == "Plant" then
		return if touchOnly
			then "Aim at rock and tap Plant to place dynamite"
			else "Click rock to plant dynamite"
	elseif step == "StandBack" then
		return "Stand back! Blasts hurt you too. Bright ore is worth gold"
	elseif step == "Bank" then
		return "Carry your haul back over the Bank Line to keep it"
	elseif step == "EarnMore" then
		return `Banked! Reach {cheapestUpgrade} gold to buy your first upgrade`
	elseif step == "Buy" then
		return if touchOnly
			then "Tap Shop to buy your first upgrade"
			else "Press B to buy your first upgrade"
	end
	return "The mine is collapsing! Get out past the Bank Line"
end

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function hasUpgrade(): boolean
	for _, upgrade in Config.UPGRADES do
		if numberAttribute(`Level_{upgrade.id}`) > 0 then
			return true
		end
	end
	return false
end

local function refresh()
	-- MaxSticks is missing until the player's save has loaded.
	local maxSticks = numberAttribute("MaxSticks")
	local phase = workspace:GetAttribute("Phase")
	local step = if maxSticks > 0
		then TutorialLogic.step({
			phase = if typeof(phase) == "string" then phase else nil,
			carried = numberAttribute("Carried"),
			banked = numberAttribute("Banked"),
			sticks = numberAttribute("Sticks"),
			maxSticks = maxSticks,
			upgraded = hasUpgrade(),
			cheapestUpgrade = cheapestUpgrade,
		})
		else nil

	tipLabel.Visible = step ~= nil
	if step then
		tipLabel.Text = tipFor(step)
	end
end

function Tutorial.init()
	for _, upgrade in Config.UPGRADES do
		cheapestUpgrade = math.min(cheapestUpgrade, upgrade.basePrice)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DynamiteTutorial"
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local root = ScaledRoot.create(gui)

	tipLabel = Instance.new("TextLabel")
	tipLabel.Size = UDim2.new(1, -32, 0, 56)
	tipLabel.AnchorPoint = Vector2.new(0.5, 0)
	tipLabel.Position = UDim2.new(0.5, 0, 0, 140)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Font = Enum.Font.GothamBold
	tipLabel.TextColor3 = AMBER
	tipLabel.TextSize = 22
	tipLabel.TextStrokeColor3 = INK
	tipLabel.TextStrokeTransparency = 0.3
	tipLabel.TextWrapped = true
	tipLabel.Visible = false
	tipLabel.Parent = root

	for _, name in { "Carried", "Banked", "Sticks", "MaxSticks" } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, upgrade in Config.UPGRADES do
		localPlayer:GetAttributeChangedSignal(`Level_{upgrade.id}`):Connect(refresh)
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(refresh)
	refresh()
end

function Tutorial.start() end

return Tutorial
