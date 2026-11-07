--!strict
-- Gas pockets and cave-ins. Blasts start both of them. They run on the server
-- and show up as server parts, so clients only ever watch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Mine = require(script.Parent.Mine)
local Miners = require(script.Parent.Miners)

type Cloud = { part: Part, center: Vector3, endsAt: number }

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local GAS_COLOR = Color3.fromRGB(150, 200, 70)
local DUST_COLOR = Color3.fromRGB(150, 130, 110)
local GAS_TICK_SECONDS = 0.5
local CAVE_IN_ROCKS = 8
local WARN_RANGE_FACTOR = 3

local clouds: { Cloud } = {}
local hazardFolder: Folder
local random = Random.new()
-- Bumped on every reset so cave-ins from the last shift do nothing.
local generation = 0
local nextCaveInAt = 0

local Hazards = {}

local function makeEffectPart(name: string, position: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	return part
end

local function makeSmoke(parent: Part, color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = parent
	return emitter
end

-- Calls back for each living player whose character is within range.
local function forPlayersNear(
	center: Vector3,
	radius: number,
	callback: (Player, BasePart, Humanoid) -> ()
)
	for _, player in Players:GetPlayers() do
		local root = Miners.rootOf(player)
		local humanoid = Miners.humanoidOf(player)
		if
			root
			and humanoid
			and humanoid.Health > 0
			and (root.Position - center).Magnitude <= radius
		then
			callback(player, root, humanoid)
		end
	end
end

local function warnNear(center: Vector3, radius: number, text: string)
	forPlayersNear(center, radius * WARN_RANGE_FACTOR, function(player)
		Miners.notify(player, text)
	end)
end

local function releaseGas(center: Vector3)
	local radius = Config.GAS_CLOUD_RADIUS
	local part = makeEffectPart("GasCloud", center, Vector3.one * radius * 2)
	part.Shape = Enum.PartType.Ball
	part.Color = GAS_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.75

	local smoke = makeSmoke(part, GAS_COLOR)
	smoke.Size = NumberSequence.new(3, 6)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Rate = 12

	part.Parent = hazardFolder
	table.insert(clouds, {
		part = part,
		center = center,
		endsAt = os.clock() + Config.GAS_CLOUD_SECONDS,
	})
	warnNear(center, radius, "Gas pocket! Get clear, or blast it to ignite")
end

local function collapseRoof(center: Vector3)
	local keepClear: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = Miners.rootOf(player)
		if root then
			table.insert(keepClear, root.Position)
		end
	end

	forPlayersNear(center, Config.CAVE_IN_RADIUS, function(player, _, humanoid)
		humanoid:TakeDamage(Config.CAVE_IN_DAMAGE)
		if humanoid.Health > 0 then
			Miners.dropHaul(player)
		end
	end)

	if Mine.refill(center, Config.CAVE_IN_RADIUS, keepClear) > 0 then
		Mine.dropRocksAround(center, Config.CAVE_IN_RADIUS, Config.CAVE_IN_RADIUS, CAVE_IN_ROCKS)
	end
end

-- Dust and a rumble give players a moment to run before the roof comes down.
local function startCaveIn(center: Vector3)
	local radius = Config.CAVE_IN_RADIUS
	local warning = makeEffectPart(
		"CaveInWarning",
		Vector3.new(center.X, Mine.ceilingY() - 1, center.Z),
		Vector3.new(radius * 2, 1, radius * 2)
	)

	local dust = makeSmoke(warning, DUST_COLOR)
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.Size = NumberSequence.new(1, 3)
	dust.Transparency = NumberSequence.new(0.3, 1)
	dust.Lifetime = NumberRange.new(1, 1.5)
	dust.Speed = NumberRange.new(6, 12)
	dust.Acceleration = Vector3.new(0, -20, 0)
	dust.Rate = 60

	local rumble = Instance.new("Sound")
	rumble.SoundId = `rbxassetid://{Config.SOUNDS.Rumble.id}`
	rumble.Volume = Config.SOUNDS.Rumble.volume
	rumble.RollOffMaxDistance = 80
	rumble.Parent = warning

	warning.Parent = hazardFolder
	rumble:Play()
	warnNear(center, radius, "Cave-in! Move!")

	local caveGeneration = generation
	task.delay(Config.CAVE_IN_WARNING_SECONDS, function()
		warning:Destroy()
		if caveGeneration == generation and workspace:GetAttribute("Phase") == "Shift" then
			collapseRoof(center)
		end
	end)
end

-- If a blast lands inside a gas cloud, the cloud is used up and its center is
-- returned so the caller can set off the bigger gas blast there.
function Hazards.takeCloudAt(position: Vector3): Vector3?
	for index, cloud in clouds do
		if (cloud.center - position).Magnitude <= Config.GAS_CLOUD_RADIUS then
			cloud.part:Destroy()
			table.remove(clouds, index)
			return cloud.center
		end
	end
	return nil
end

-- Called after every blast with what the blast removed.
function Hazards.afterBlast(center: Vector3, result: Types.CarveResult)
	for _, pocket in result.gasPockets do
		releaseGas(pocket)
	end

	local now = os.clock()
	if
		workspace:GetAttribute("Phase") ~= "Shift"
		or not Mine.isInside(center)
		or now < nextCaveInAt
	then
		return
	end

	local chance = Config.CAVE_IN_CHANCE + Mine.depthOf(center) * Config.CAVE_IN_CHANCE_PER_DEPTH
	if random:NextNumber() < chance then
		nextCaveInAt = now + Config.CAVE_IN_COOLDOWN_SECONDS
		local spread = Config.CAVE_IN_RADIUS
		startCaveIn(
			Vector3.new(
				center.X + random:NextNumber(-spread, spread),
				Config.FLOOR_Y + Config.BLOCK_SIZE,
				center.Z + random:NextNumber(-spread, spread)
			)
		)
	end
end

function Hazards.reset()
	generation += 1
	nextCaveInAt = 0
	table.clear(clouds)
	hazardFolder:ClearAllChildren()
end

function Hazards.init()
	hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "Hazards"
	hazardFolder.Parent = workspace
end

function Hazards.start()
	while true do
		local deltaTime = task.wait(GAS_TICK_SECONDS)
		local now = os.clock()
		for index = #clouds, 1, -1 do
			local cloud = clouds[index]
			if now >= cloud.endsAt then
				cloud.part:Destroy()
				table.remove(clouds, index)
			else
				forPlayersNear(cloud.center, Config.GAS_CLOUD_RADIUS, function(_, _, humanoid)
					humanoid:TakeDamage(Config.GAS_DAMAGE_PER_SECOND * deltaTime)
				end)
			end
		end
	end
end

return Hazards
