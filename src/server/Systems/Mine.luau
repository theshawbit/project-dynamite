--!strict
-- Owns the mountain: builds the block grid, removes blocks in a blast, and
-- answers questions about where things are relative to the mine.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MineLogic = require(ReplicatedStorage.Shared.Util.MineLogic)
local Types = require(ReplicatedStorage.Shared.Types)

type Cell = { part: Part, kind: Types.BlockKind }

local SIZE = Config.BLOCK_SIZE
local WIDTH = Config.MINE_WIDTH
local HEIGHT = Config.MINE_HEIGHT
local DEPTH = Config.MINE_DEPTH
local HALF_WIDTH = WIDTH * SIZE / 2
local BACK_Z = Config.ENTRANCE_Z + DEPTH * SIZE
local BLOCKS_PER_FRAME = 256

local LOOKS: { [Types.BlockKind]: { color: Color3, material: Enum.Material } } = {
	Rock = { color = Color3.fromRGB(84, 72, 64), material = Enum.Material.Slate },
	Copper = { color = Color3.fromRGB(214, 120, 62), material = Enum.Material.Metal },
	Silver = { color = Color3.fromRGB(190, 215, 235), material = Enum.Material.Metal },
	Gold = { color = Color3.fromRGB(255, 200, 40), material = Enum.Material.Neon },
	Barrel = { color = Color3.fromRGB(200, 30, 30), material = Enum.Material.SmoothPlastic },
}

local cells: { [number]: Cell } = {}
local random = Random.new()
local mineFolder: Folder
local blockFolder: Folder

local Mine = {}

local function cellIndex(i: number, j: number, k: number): number
	return i + j * WIDTH + k * WIDTH * HEIGHT
end

local function cellCenter(i: number, j: number, k: number): Vector3
	return Vector3.new(
		(i + 0.5) * SIZE - HALF_WIDTH,
		Config.FLOOR_Y + (j + 0.5) * SIZE,
		Config.ENTRANCE_Z + (k + 0.5) * SIZE
	)
end

local function inGrid(i: number, j: number, k: number): boolean
	return i >= 0 and i < WIDTH and j >= 0 and j < HEIGHT and k >= 0 and k < DEPTH
end

local function toCell(position: Vector3): (number, number, number)
	return math.floor((position.X + HALF_WIDTH) / SIZE),
		math.floor((position.Y - Config.FLOOR_Y) / SIZE),
		math.floor((position.Z - Config.ENTRANCE_Z) / SIZE)
end

local function isStarterTunnel(i: number, j: number, k: number): boolean
	local centered = i == WIDTH / 2 - 1 or i == WIDTH / 2
	return centered and j < 2 and k < Config.STARTER_TUNNEL_DEPTH
end

local function makeBlock(kind: Types.BlockKind, position: Vector3): Part
	local look = LOOKS[kind]
	local part = Instance.new("Part")
	part.Name = kind
	part.Size = Vector3.one * SIZE
	part.Position = position
	part.Anchored = true
	part.CanTouch = false
	part.CastShadow = false
	part.Color = look.color
	part.Material = look.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = blockFolder
	return part
end

local function buildYard()
	local length = DEPTH * SIZE + 4 * SIZE

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(WIDTH * SIZE + 4 * SIZE, 1, length)
	floor.Position = Vector3.new(0, Config.FLOOR_Y - 0.5, BACK_Z + 2 * SIZE - length / 2)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(58, 50, 45)
	floor.Material = Enum.Material.Ground
	floor.Parent = mineFolder

	local bankLine = Instance.new("Part")
	bankLine.Name = "BankLine"
	bankLine.Size = Vector3.new(WIDTH * SIZE + 4 * SIZE, 0.2, 1.5)
	bankLine.Position = Vector3.new(0, Config.FLOOR_Y + 0.1, Config.BANK_Z)
	bankLine.Anchored = true
	bankLine.CanCollide = false
	bankLine.CanQuery = false
	bankLine.Color = Color3.fromRGB(255, 200, 40)
	bankLine.Material = Enum.Material.Neon
	bankLine.Parent = mineFolder

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(240, 44)
	sign.StudsOffset = Vector3.new(0, 7, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "BANK LINE"
	label.TextColor3 = Color3.fromRGB(255, 200, 40)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = sign
	sign.Parent = bankLine
end

function Mine.rebuild()
	blockFolder:ClearAllChildren()
	table.clear(cells)

	local built = 0
	for k = 0, DEPTH - 1 do
		local depth = k / (DEPTH - 1)
		for j = 0, HEIGHT - 1 do
			for i = 0, WIDTH - 1 do
				if not isStarterTunnel(i, j, k) then
					local kind = MineLogic.rollKind(depth, random:NextNumber())
					local part = makeBlock(kind, cellCenter(i, j, k))
					cells[cellIndex(i, j, k)] = { part = part, kind = kind }

					built += 1
					if built % BLOCKS_PER_FRAME == 0 then
						task.wait()
					end
				end
			end
		end
	end
end

function Mine.carve(center: Vector3, radius: number): Types.CarveResult
	local result: Types.CarveResult = { gold = 0, barrels = {} }
	local reach = math.ceil(radius / SIZE)
	local ci, cj, ck = toCell(center)

	for k = ck - reach, ck + reach do
		for j = cj - reach, cj + reach do
			for i = ci - reach, ci + reach do
				local index = cellIndex(i, j, k)
				local cell = if inGrid(i, j, k) then cells[index] else nil
				if cell and (cellCenter(i, j, k) - center).Magnitude <= radius then
					result.gold += Config.ORE_VALUE[cell.kind]
					if cell.kind == "Barrel" then
						table.insert(result.barrels, cell.part.Position)
					end
					cell.part:Destroy()
					cells[index] = nil
				end
			end
		end
	end

	return result
end

-- True when the position sits on the surface of a block that still exists.
function Mine.isOnBlock(position: Vector3): boolean
	local ci, cj, ck = toCell(position)
	for k = ck - 1, ck + 1 do
		for j = cj - 1, cj + 1 do
			for i = ci - 1, ci + 1 do
				if
					inGrid(i, j, k)
					and cells[cellIndex(i, j, k)]
					and (cellCenter(i, j, k) - position).Magnitude <= SIZE
				then
					return true
				end
			end
		end
	end
	return false
end

-- True for the mine and the yard in front of it. Standing beside or behind
-- the mountain does not count, so nobody can blast in through the side walls.
function Mine.isWorkArea(position: Vector3): boolean
	return math.abs(position.X) <= HALF_WIDTH and position.Z <= BACK_Z
end

function Mine.isInside(position: Vector3): boolean
	return Mine.isWorkArea(position) and position.Z >= Config.ENTRANCE_Z
end

function Mine.backZ(): number
	return BACK_Z
end

-- Falling rock at the collapse front. Purely visual.
function Mine.dropRocks(z: number, count: number)
	local top = Config.FLOOR_Y + HEIGHT * SIZE
	for _ = 1, count do
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Size = Vector3.one * random:NextNumber(3, 6)
		rock.Position = Vector3.new(random:NextNumber(-HALF_WIDTH, HALF_WIDTH), top + 4, z)
		rock.Color = LOOKS.Rock.color
		rock.Material = LOOKS.Rock.material
		rock.CanTouch = false
		rock.CanQuery = false
		rock.Parent = mineFolder
		Debris:AddItem(rock, 2.5)
	end
end

function Mine.init()
	mineFolder = Instance.new("Folder")
	mineFolder.Name = "Mine"
	blockFolder = Instance.new("Folder")
	blockFolder.Name = "Blocks"
	blockFolder.Parent = mineFolder
	buildYard()
	mineFolder.Parent = workspace
end

function Mine.start() end

return Mine
