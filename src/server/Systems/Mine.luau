--!strict
-- Owns the mountain: builds the block grid from a shift's layout, removes
-- blocks in a blast, refills them in a cave-in, and answers questions about
-- where things are relative to the mine.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MineLayout = require(ReplicatedStorage.Shared.Util.MineLayout)
local Types = require(ReplicatedStorage.Shared.Types)

-- Hard rock survives its first blast as cracked rock. crackedBy holds the
-- id of the blast chain that cracked it.
type Cell = { part: Part, kind: Types.BlockKind, crackedBy: number? }

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
	Crystal = { color = Color3.fromRGB(110, 230, 255), material = Enum.Material.Neon },
	Barrel = { color = Color3.fromRGB(200, 30, 30), material = Enum.Material.SmoothPlastic },
	-- Close to rock on purpose: sharp eyes spot the olive tint.
	Gas = { color = Color3.fromRGB(96, 104, 66), material = Enum.Material.Slate },
	Hardrock = { color = Color3.fromRGB(52, 46, 50), material = Enum.Material.Basalt },
}

local CRACKED_COLOR = Color3.fromRGB(190, 85, 40)
local CRACKED_MATERIAL = Enum.Material.CrackedLava

local cells: { [number]: Cell } = {}
local random = Random.new()
local mineFolder: Folder
local blockFolder: Folder
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Include

local Mine = {}

local cellIndex = MineLayout.index
local inGrid = MineLayout.inGrid

local function cellCenter(i: number, j: number, k: number): Vector3
	return Vector3.new(
		(i + 0.5) * SIZE - HALF_WIDTH,
		Config.FLOOR_Y + (j + 0.5) * SIZE,
		Config.ENTRANCE_Z + (k + 0.5) * SIZE
	)
end

local function toCell(position: Vector3): (number, number, number)
	return math.floor((position.X + HALF_WIDTH) / SIZE),
		math.floor((position.Y - Config.FLOOR_Y) / SIZE),
		math.floor((position.Z - Config.ENTRANCE_Z) / SIZE)
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

function Mine.rebuild(layout: Types.MineLayout)
	blockFolder:ClearAllChildren()
	table.clear(cells)

	local built = 0
	for k = 0, DEPTH - 1 do
		for j = 0, HEIGHT - 1 do
			for i = 0, WIDTH - 1 do
				local index = cellIndex(i, j, k)
				local kind = layout.kinds[index]
				if kind then
					local part = makeBlock(kind, cellCenter(i, j, k))
					cells[index] = { part = part, kind = kind }

					built += 1
					if built % BLOCKS_PER_FRAME == 0 then
						task.wait()
					end
				end
			end
		end
	end
end

-- blastId is shared by a stick and every barrel or gas blast it sets off, so
-- one chain can crack hard rock but only a later blast can break it.
function Mine.carve(center: Vector3, radius: number, blastId: number): Types.CarveResult
	local result: Types.CarveResult = { gold = 0, barrels = {}, gasPockets = {} }
	local reach = math.ceil(radius / SIZE)
	local ci, cj, ck = toCell(center)

	for k = ck - reach, ck + reach do
		for j = cj - reach, cj + reach do
			for i = ci - reach, ci + reach do
				local index = cellIndex(i, j, k)
				local cell = if inGrid(i, j, k) then cells[index] else nil
				local inBlast = cell and (cellCenter(i, j, k) - center).Magnitude <= radius
				local holds = cell
					and cell.kind == "Hardrock"
					and (cell.crackedBy == nil or cell.crackedBy == blastId)
				if cell and inBlast and holds then
					if not cell.crackedBy then
						cell.crackedBy = blastId
						cell.part.Color = CRACKED_COLOR
						cell.part.Material = CRACKED_MATERIAL
					end
				elseif cell and inBlast then
					result.gold += Config.ORE_VALUE[cell.kind]
					if cell.kind == "Barrel" then
						table.insert(result.barrels, cell.part.Position)
					elseif cell.kind == "Gas" then
						table.insert(result.gasPockets, cell.part.Position)
					end
					cell.part:Destroy()
					cells[index] = nil
				end
			end
		end
	end

	return result
end

-- Fills empty cells near a point with rock, as a cave-in. Cells holding a
-- player or the entrance tunnel stay open, so nobody is sealed inside rock
-- and the way in is never blocked. Returns how many cells were filled.
function Mine.refill(center: Vector3, radius: number, keepClear: { Vector3 }): number
	local filled = 0
	local reach = math.ceil(radius / SIZE)
	local ci, cj, ck = toCell(center)

	for k = math.max(ck - reach, Config.STARTER_TUNNEL_DEPTH), ck + reach do
		for j = cj - reach, cj + reach do
			for i = ci - reach, ci + reach do
				local index = cellIndex(i, j, k)
				local position = cellCenter(i, j, k)
				local open = inGrid(i, j, k)
					and not cells[index]
					and (position - center).Magnitude <= radius
				if open then
					for _, spot in keepClear do
						if (position - spot).Magnitude <= SIZE then
							open = false
							break
						end
					end
				end
				if open then
					cells[index] = { part = makeBlock("Rock", position), kind = "Rock" }
					filled += 1
				end
			end
		end
	end

	return filled
end

-- True when the point is inside a block that still exists.
function Mine.isSolidAt(position: Vector3): boolean
	local i, j, k = toCell(position)
	return inGrid(i, j, k) and cells[cellIndex(i, j, k)] ~= nil
end

-- True when nothing in the mine blocks the straight line from one point to a
-- target on a block's surface. The ray may stop a little short of the target,
-- since the target itself sits on the block it hits.
function Mine.canSee(from: Vector3, target: Vector3): boolean
	local offset = target - from
	local distance = offset.Magnitude
	if distance < 0.01 then
		return true
	end
	local hit = workspace:Raycast(from, offset.Unit * (distance + 1), sightParams)
	return hit == nil or (hit.Position - target).Magnitude <= Config.PLANT_SIGHT_TOLERANCE
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

-- 0 at the entrance, 1 at the back wall.
function Mine.depthOf(position: Vector3): number
	return math.clamp((position.Z - Config.ENTRANCE_Z) / (DEPTH * SIZE), 0, 1)
end

function Mine.ceilingY(): number
	return Config.FLOOR_Y + HEIGHT * SIZE
end

-- Falling rock spread across the mine's width at one depth. Purely visual.
function Mine.dropRocks(z: number, count: number)
	Mine.dropRocksAround(Vector3.new(0, 0, z), HALF_WIDTH, 0, count)
end

-- Falling rock scattered around a point. Purely visual.
function Mine.dropRocksAround(center: Vector3, spreadX: number, spreadZ: number, count: number)
	local top = Mine.ceilingY()
	for _ = 1, count do
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Size = Vector3.one * random:NextNumber(3, 6)
		rock.Position = Vector3.new(
			math.clamp(center.X + random:NextNumber(-spreadX, spreadX), -HALF_WIDTH, HALF_WIDTH),
			top + 4,
			center.Z + random:NextNumber(-spreadZ, spreadZ)
		)
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
	sightParams.FilterDescendantsInstances = { blockFolder }
	buildYard()
	mineFolder.Parent = workspace
end

function Mine.start() end

return Mine
