--!strict
-- Planting, fuses, blasts and barrel chain reactions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MineLogic = require(ReplicatedStorage.Shared.Util.MineLogic)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Mine = require(script.Parent.Mine)
local Miners = require(script.Parent.Miners)

local MAX_COORDINATE = 10000

local active: { [Player]: number } = {}
local stickFolder: Folder
-- Bumped on every reset so fuses and chains from the last shift do nothing.
local generation = 0

local Dynamite = {}

local function hurtPlayers(center: Vector3, radius: number)
	for _, player in Players:GetPlayers() do
		local root = Miners.rootOf(player)
		local humanoid = Miners.humanoidOf(player)
		if root and humanoid then
			local distance = (root.Position - center).Magnitude
			if distance <= radius then
				humanoid:TakeDamage(MineLogic.blastDamage(distance, radius))
				if humanoid.Health > 0 then
					Miners.dropHaul(player, Config.HIT_HAUL_LOSS)
				end
			end
		end
	end
end

local function detonate(owner: Player, center: Vector3, radius: number)
	local result = Mine.carve(center, radius)
	Miners.addCarried(owner, result.gold)

	local explosion = Instance.new("Explosion")
	explosion.Position = center
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace

	Net.get("Blast"):FireAllClients(center, radius)
	hurtPlayers(center, radius)

	local chainGeneration = generation
	for _, barrel in result.barrels do
		task.delay(Config.CHAIN_DELAY_SECONDS, function()
			if chainGeneration == generation then
				detonate(owner, barrel, Config.BARREL_BLAST_RADIUS)
			end
		end)
	end
end

local function makeStick(position: Vector3): Part
	local stick = Instance.new("Part")
	stick.Name = "Stick"
	stick.Shape = Enum.PartType.Cylinder
	stick.Size = Vector3.new(2.4, 0.8, 0.8)
	stick.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	stick.Anchored = true
	stick.CanCollide = false
	stick.CanTouch = false
	stick.CanQuery = false
	stick.Color = Color3.fromRGB(190, 30, 30)
	stick.Material = Enum.Material.SmoothPlastic

	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 170, 40)
	sparks.Parent = stick

	stick.Parent = stickFolder
	return stick
end

local function plant(player: Player, position: Vector3)
	active[player] = (active[player] or 0) + 1
	local stick = makeStick(position)
	local fuseGeneration = generation

	task.delay(Config.FUSE_SECONDS, function()
		stick:Destroy()
		if fuseGeneration ~= generation then
			return
		end
		if active[player] then
			active[player] -= 1
		end
		detonate(player, position, Config.BLAST_RADIUS)
	end)
end

local function onPlantRequest(player: Player, position: unknown)
	if not RateLimit.allow(player, "PlantDynamite", 4, 4) then
		return
	end

	-- Type.
	if typeof(position) ~= "Vector3" then
		return
	end

	-- Range: NaN fails every comparison, so this rejects it along with infinity.
	local inRange = math.abs(position.X) <= MAX_COORDINATE
		and math.abs(position.Y) <= MAX_COORDINATE
		and math.abs(position.Z) <= MAX_COORDINATE
	if not inRange then
		return
	end

	-- Permission.
	local phase = workspace:GetAttribute("Phase")
	if phase ~= "Shift" and phase ~= "Collapse" then
		return
	end
	local root = Miners.rootOf(player)
	if not root or not Miners.humanoidOf(player) then
		return
	end

	-- Plausibility.
	if (root.Position - position).Magnitude > Config.PLANT_REACH then
		return
	end
	if not Mine.isWorkArea(root.Position) or not Mine.isOnBlock(position) then
		return
	end
	if (active[player] or 0) >= Config.MAX_ACTIVE_STICKS then
		return
	end
	if not Miners.spendStick(player) then
		return
	end

	plant(player, position)
end

function Dynamite.reset()
	generation += 1
	table.clear(active)
	stickFolder:ClearAllChildren()
end

function Dynamite.init()
	stickFolder = Instance.new("Folder")
	stickFolder.Name = "Dynamite"
	stickFolder.Parent = workspace

	Net.get("PlantDynamite").OnServerEvent:Connect(onPlantRequest)
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)
end

function Dynamite.start()
	while true do
		task.wait(Config.STICK_REGEN_SECONDS)
		Miners.regenSticks()
	end
end

return Dynamite
