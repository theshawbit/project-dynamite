--!strict
-- Aims and requests plants. The marker only helps the player aim; the server
-- makes every decision about whether a stick is actually placed.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local ACTION = "PlantDynamite"
local AIM_DISTANCE = 300
local IN_REACH = Color3.fromRGB(90, 255, 120)
local OUT_OF_REACH = Color3.fromRGB(255, 80, 60)

local localPlayer = Players.LocalPlayer
local raycastParams = RaycastParams.new()
local marker: Part
local aimPosition: Vector3? = nil

local Planting = {}

local function canPlantNow(): boolean
	local phase = workspace:GetAttribute("Phase")
	return phase == "Shift" or phase == "Collapse"
end

local function rootPosition(): Vector3?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function aimRay(camera: Camera): Ray
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	local viewport = camera.ViewportSize
	return camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
end

local function updateAim()
	aimPosition = nil
	marker.Transparency = 1

	local camera = workspace.CurrentCamera
	local root = rootPosition()
	if not camera or not root or not canPlantNow() then
		return
	end

	local ray = aimRay(camera)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, raycastParams)
	if not hit then
		return
	end

	local inReach = (hit.Position - root).Magnitude <= Config.PLANT_REACH
	marker.Position = hit.Position
	marker.Color = if inReach then IN_REACH else OUT_OF_REACH
	marker.Transparency = 0.2
	if inReach then
		aimPosition = hit.Position
	end
end

local function onAction(
	_: string,
	state: Enum.UserInputState,
	_: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and aimPosition then
		Net.get("PlantDynamite"):FireServer(aimPosition)
	end
	return Enum.ContextActionResult.Pass
end

function Planting.init()
	marker = Instance.new("Part")
	marker.Name = "AimMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.one * 1.2
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Transparency = 1
	marker.Parent = workspace

	local mine = workspace:WaitForChild("Mine")
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { mine:WaitForChild("Blocks") }

	ContextActionService:BindAction(
		ACTION,
		onAction,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION, "Plant")
end

function Planting.start()
	RunService.RenderStepped:Connect(updateAim)
end

return Planting
