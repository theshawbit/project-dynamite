--!strict
-- Planting, fuses, blasts and chain reactions from barrels and gas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MineLogic = require(ReplicatedStorage.Shared.Util.MineLogic)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Hazards = require(script.Parent.Hazards)
local Guard = require(script.Parent.Guard)
local Mine = require(script.Parent.Mine)
local Miners = require(script.Parent.Miners)

local MAX_COORDINATE = 10000
-- Sight lines are tried from head height and from about where the camera
-- sits, so a spot the player can see on screen is plantable.
local SIGHT_HEIGHTS = { 1.5, 4.5 }
local REGEN_TICK_SECONDS = 0.25

local active: { [Player]: number } = {}
local stickFolder: Folder
-- Bumped on every reset so fuses and chains from the last shift do nothing.
local generation = 0
-- Each planted stick starts a new blast chain with its own id.
local lastBlastId = 0

local Dynamite = {}

-- Only the owner is hurt. Other miners still feel the knockback on their own
-- screens, but their health and haul are safe from someone else's dynamite.
local function hurtOwner(owner: Player, center: Vector3, radius: number)
	local root = Miners.rootOf(owner)
	local humanoid = Miners.humanoidOf(owner)
	if not root or not humanoid then
		return
	end

	local distance = (root.Position - center).Magnitude
	if distance <= radius then
		humanoid:TakeDamage(MineLogic.blastDamage(distance, radius))
		if humanoid.Health > 0 then
			Miners.dropHaul(owner)
		end
	end
end

local function detonate(owner: Player, center: Vector3, radius: number, blastId: number)
	local skin = Miners.skinOf(owner)
	local result = Mine.carve(center, radius, blastId)
	Miners.addCarried(owner, result.gold)

	local explosion = Instance.new("Explosion")
	explosion.Position = center
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace

	Net.getUnreliable("Blast"):FireAllClients(center, radius, skin.id)
	hurtOwner(owner, center, radius)

	local chainGeneration = generation
	local function chain(position: Vector3, chainRadius: number)
		task.delay(Config.CHAIN_DELAY_SECONDS, function()
			if chainGeneration == generation then
				detonate(owner, position, chainRadius, blastId)
			end
		end)
	end

	for _, barrel in result.barrels do
		chain(barrel, Config.BARREL_BLAST_RADIUS)
	end
	-- Checked before this blast's own gas is released, so a freshly opened
	-- pocket lingers as a cloud instead of going off at once.
	local cloud = Hazards.takeCloudAt(center)
	if cloud then
		chain(cloud, Config.GAS_BLAST_RADIUS)
	end

	Hazards.afterBlast(center, result)
end

local function makeStick(position: Vector3, skin: Types.Skin): Part
	local stick = Instance.new("Part")
	stick.Name = "Stick"
	stick.Shape = Enum.PartType.Cylinder
	stick.Size = Vector3.new(2.4, 0.8, 0.8)
	stick.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	stick.Anchored = true
	stick.CanCollide = false
	stick.CanTouch = false
	stick.CanQuery = false
	stick.Color = skin.stick
	stick.Material = skin.material

	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = skin.spark
	sparks.Parent = stick

	stick.Parent = stickFolder
	return stick
end

local function plant(player: Player, position: Vector3)
	active[player] = (active[player] or 0) + 1
	local stick = makeStick(position, Miners.skinOf(player))
	local fuseGeneration = generation
	local radius = Miners.blastRadiusOf(player)

	task.delay(Config.FUSE_SECONDS, function()
		stick:Destroy()
		if fuseGeneration ~= generation then
			return
		end
		if active[player] then
			active[player] -= 1
		end
		lastBlastId += 1
		detonate(player, position, radius, lastBlastId)
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
	if not Guard.check(player) then
		return
	end
	local seen = false
	for _, height in SIGHT_HEIGHTS do
		if Mine.canSee(root.Position + Vector3.yAxis * height, position) then
			seen = true
			break
		end
	end
	if not seen then
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
		Miners.regenSticks(task.wait(REGEN_TICK_SECONDS))
	end
end

return Dynamite
