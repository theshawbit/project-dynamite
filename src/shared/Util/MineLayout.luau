--!strict
-- Plans a fresh mine for each shift: scattered ore, hollow caverns and a few
-- rich veins. Pure: the same seed always plans the same mine.

local Config = require(script.Parent.Parent.Config)
local MineLogic = require(script.Parent.MineLogic)
local Types = require(script.Parent.Parent.Types)

local WIDTH = Config.MINE_WIDTH
local HEIGHT = Config.MINE_HEIGHT
local DEPTH = Config.MINE_DEPTH

local MineLayout = {}

function MineLayout.index(i: number, j: number, k: number): number
	return i + j * WIDTH + k * WIDTH * HEIGHT
end

function MineLayout.inGrid(i: number, j: number, k: number): boolean
	return i >= 0 and i < WIDTH and j >= 0 and j < HEIGHT and k >= 0 and k < DEPTH
end

-- The open tunnel at the entrance that every shift starts with.
function MineLayout.isStarterTunnel(i: number, j: number, k: number): boolean
	local centered = i == WIDTH / 2 - 1 or i == WIDTH / 2
	return centered and j < 2 and k < Config.STARTER_TUNNEL_DEPTH
end

local function carveCaverns(kinds: { [number]: Types.BlockKind }, random: Random)
	for _ = 1, random:NextInteger(Config.CAVERNS_MIN, Config.CAVERNS_MAX) do
		local ci = random:NextInteger(1, WIDTH - 2)
		local cj = random:NextInteger(0, HEIGHT - 1)
		local ck = random:NextInteger(Config.STARTER_TUNNEL_DEPTH + 3, DEPTH - 2)
		local radius = random:NextNumber(1, 1.8)
		local reach = math.ceil(radius)

		for k = ck - reach, ck + reach do
			for j = cj - reach, cj + reach do
				for i = ci - reach, ci + reach do
					local distance = Vector3.new(i - ci, j - cj, k - ck).Magnitude
					if MineLayout.inGrid(i, j, k) and distance <= radius then
						kinds[MineLayout.index(i, j, k)] = nil
					end
				end
			end
		end
	end
end

-- A vein wanders one cell at a time from a random start deep in the mine.
local function growVein(
	kinds: { [number]: Types.BlockKind },
	random: Random,
	kind: Types.BlockKind,
	length: number
)
	local i = random:NextInteger(0, WIDTH - 1)
	local j = random:NextInteger(0, HEIGHT - 1)
	local k = random:NextInteger(math.floor(DEPTH * Config.VEIN_START_DEPTH), DEPTH - 1)

	for _ = 1, length do
		if not MineLayout.isStarterTunnel(i, j, k) then
			kinds[MineLayout.index(i, j, k)] = kind
		end

		local step = if random:NextNumber() < 0.5 then -1 else 1
		local axis = random:NextInteger(1, 3)
		if axis == 1 then
			i = math.clamp(i + step, 0, WIDTH - 1)
		elseif axis == 2 then
			j = math.clamp(j + step, 0, HEIGHT - 1)
		else
			k = math.clamp(k + step, 0, DEPTH - 1)
		end
	end
end

function MineLayout.generate(seed: number): Types.MineLayout
	local random = Random.new(seed)
	local kinds: { [number]: Types.BlockKind } = {}

	for k = 0, DEPTH - 1 do
		local depth = k / (DEPTH - 1)
		for j = 0, HEIGHT - 1 do
			for i = 0, WIDTH - 1 do
				if not MineLayout.isStarterTunnel(i, j, k) then
					kinds[MineLayout.index(i, j, k)] =
						MineLogic.rollKind(depth, random:NextNumber())
				end
			end
		end
	end

	carveCaverns(kinds, random)

	for _ = 1, Config.GOLD_VEINS do
		growVein(
			kinds,
			random,
			"Gold",
			random:NextInteger(Config.GOLD_VEIN_LENGTH_MIN, Config.GOLD_VEIN_LENGTH_MAX)
		)
	end

	local hasCrystal = random:NextNumber() < Config.CRYSTAL_VEIN_CHANCE
	if hasCrystal then
		growVein(
			kinds,
			random,
			"Crystal",
			random:NextInteger(Config.CRYSTAL_VEIN_LENGTH_MIN, Config.CRYSTAL_VEIN_LENGTH_MAX)
		)
	end

	return { kinds = kinds, hasCrystal = hasCrystal }
end

return MineLayout
