--!strict
-- Camera shake and knockback. Both are cosmetic: damage and lost gold are
-- decided on the server, so skipping this code gains a cheater nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local SHAKE_RANGE = 80
local SHAKE_DECAY = 3
local COLLAPSE_RUMBLE = 0.25
local KNOCKBACK_SPEED = 55
local KNOCKBACK_LIFT = 25

local localPlayer = Players.LocalPlayer
local random = Random.new()
local shake = 0

local BlastFeedback = {}

local function onBlast(center: unknown, radius: unknown)
	if typeof(center) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local offset = root.Position - center
	local distance = offset.Magnitude
	shake = math.max(shake, 1.5 * math.clamp(1 - distance / SHAKE_RANGE, 0, 1))

	if distance <= radius and distance > 0.1 then
		local away = offset.Unit * KNOCKBACK_SPEED
		root.AssemblyLinearVelocity += away + Vector3.yAxis * KNOCKBACK_LIFT
	end
end

local function updateShake(deltaTime: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	shake = math.max(0, shake - SHAKE_DECAY * deltaTime)
	local rumble = if workspace:GetAttribute("Phase") == "Collapse" then COLLAPSE_RUMBLE else 0
	local strength = math.max(shake, rumble)
	humanoid.CameraOffset = Vector3.new(
		random:NextNumber(-strength, strength),
		random:NextNumber(-strength, strength),
		0
	)
end

function BlastFeedback.init()
	Net.getUnreliable("Blast").OnClientEvent:Connect(onBlast)
end

function BlastFeedback.start()
	RunService.RenderStepped:Connect(updateShake)
end

return BlastFeedback
