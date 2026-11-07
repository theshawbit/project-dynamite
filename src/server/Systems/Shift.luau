--!strict
-- The round loop: intermission, shift, then the collapse that sweeps from the
-- back of the mine to the entrance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local MineLayout = require(ReplicatedStorage.Shared.Util.MineLayout)
local Dynamite = require(script.Parent.Dynamite)
local Hazards = require(script.Parent.Hazards)
local Mine = require(script.Parent.Mine)
local Miners = require(script.Parent.Miners)

local COLLAPSE_TICK_SECONDS = 0.4
local ROCKS_PER_TICK = 5
local MAX_SEED = 2 ^ 31 - 1

local random = Random.new()

local Shift = {}

local function setPhase(phase: Types.Phase, seconds: number): number
	local endsAt = workspace:GetServerTimeNow() + seconds
	workspace:SetAttribute("PhaseEndsAt", endsAt)
	workspace:SetAttribute("Phase", phase)
	return endsAt
end

local function waitUntil(endsAt: number)
	task.wait(math.max(0, endsAt - workspace:GetServerTimeNow()))
end

local function buryPlayersBehind(z: number)
	for _, player in Players:GetPlayers() do
		local root = Miners.rootOf(player)
		local humanoid = Miners.humanoidOf(player)
		if root and humanoid and Mine.isInside(root.Position) and root.Position.Z >= z then
			Miners.loseHaul(player, "Buried!")
			humanoid.Health = 0
		end
	end
end

local function runCollapse()
	local endsAt = setPhase("Collapse", Config.COLLAPSE_SECONDS)
	local backZ = Mine.backZ()

	while true do
		local remaining = endsAt - workspace:GetServerTimeNow()
		local alpha = math.clamp(1 - remaining / Config.COLLAPSE_SECONDS, 0, 1)
		local z = backZ + (Config.ENTRANCE_Z - backZ) * alpha

		Mine.dropRocks(z, ROCKS_PER_TICK)
		buryPlayersBehind(z)

		if remaining <= 0 then
			return
		end
		task.wait(COLLAPSE_TICK_SECONDS)
	end
end

function Shift.init() end

function Shift.start()
	while true do
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end

		local intermissionEnds = setPhase("Intermission", Config.INTERMISSION_SECONDS)
		Dynamite.reset()
		Hazards.reset()
		Miners.resetForShift()
		local layout = MineLayout.generate(random:NextInteger(1, MAX_SEED))
		Mine.rebuild(layout)
		waitUntil(intermissionEnds)

		local shiftEnds = setPhase("Shift", Config.SHIFT_SECONDS)
		if layout.hasCrystal then
			for _, player in Players:GetPlayers() do
				Miners.notify(player, "A crystal vein runs deep in this mine!")
			end
		end
		waitUntil(shiftEnds)
		runCollapse()
	end
end

return Shift
