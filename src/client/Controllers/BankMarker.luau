--!strict
-- A marker that shows through the mountain while the player is carrying gold,
-- so the way back to the Bank Line is always clear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AMBER = Color3.fromRGB(255, 200, 40)
local INK = Color3.fromRGB(28, 24, 22)
local MARKER_HEIGHT = 12

local localPlayer = Players.LocalPlayer
local marker: BillboardGui
local label: TextLabel

local BankMarker = {}

local function refresh()
	local carried = localPlayer:GetAttribute("Carried")
	local carrying = typeof(carried) == "number" and carried > 0
	marker.Enabled = carrying
	if carrying then
		label.Text = `BANK {carried} GOLD HERE`
	end
end

function BankMarker.init()
	local anchor = Instance.new("Part")
	anchor.Name = "BankMarker"
	anchor.Size = Vector3.one
	anchor.Position = Vector3.new(0, Config.FLOOR_Y + MARKER_HEIGHT, Config.BANK_Z)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(260, 36)
	marker.AlwaysOnTop = true
	marker.Enabled = false
	marker.Parent = anchor

	label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = INK
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = AMBER
	label.TextSize = 18
	label.Parent = marker

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	localPlayer:GetAttributeChangedSignal("Carried"):Connect(refresh)
	refresh()
end

function BankMarker.start() end

return BankMarker
