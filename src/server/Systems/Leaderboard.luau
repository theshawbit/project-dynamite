--!strict
-- The Top Miners board in the yard. Lifetime gold goes to an OrderedDataStore
-- that every server shares, so the board ranks miners across the whole game.
-- The value written comes from the server's own Lifetime attribute, never
-- from a client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "LifetimeGold"
local AMBER = Color3.fromRGB(255, 200, 40)
local INK = Color3.fromRGB(28, 24, 22)
local MUTED = Color3.fromRGB(170, 160, 150)
local WHITE = Color3.fromRGB(245, 240, 232)
local BOARD_SIZE = Vector3.new(20, 14, 1)
local PIXELS_PER_STUD = 25
local ROW_HEIGHT = 26

type Row = { name: TextLabel, gold: TextLabel }

local store: OrderedDataStore? = nil
-- Last value saved per UserId, so unchanged totals are not written again.
local written: { [number]: number } = {}
local names: { [number]: string } = {}
local rows: { Row } = {}
local statusLabel: TextLabel

local Leaderboard = {}

local function makeText(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	textSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextSize = textSize
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildBoard()
	local position = Config.LEADERBOARD_POSITION
	local board = Instance.new("Part")
	board.Name = "TopMinersBoard"
	board.Size = BOARD_SIZE
	-- Turn the board towards the spawn so new players see it straight on.
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local target = if spawn then spawn.Position else Vector3.new(0, 0, Config.BANK_Z)
	board.CFrame = CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
	board.Anchored = true
	board.CanTouch = false
	board.Color = INK
	board.Material = Enum.Material.Wood

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Parent = board

	makeText(gui, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 8), 34, AMBER).Text = "TOP MINERS"
	makeText(gui, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 50), 16, MUTED).Text =
		"Lifetime gold, every server"

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -48, 0, Config.LEADERBOARD_SIZE * ROW_HEIGHT)
	list.Position = UDim2.fromOffset(24, 80)
	list.BackgroundTransparency = 1
	list.Parent = gui

	for index = 1, Config.LEADERBOARD_SIZE do
		local top = (index - 1) * ROW_HEIGHT
		local name =
			makeText(list, UDim2.new(0.7, 0, 0, ROW_HEIGHT), UDim2.fromOffset(0, top), 22, WHITE)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local gold =
			makeText(list, UDim2.new(0.3, 0, 0, ROW_HEIGHT), UDim2.new(0.7, 0, 0, top), 22, AMBER)
		gold.TextXAlignment = Enum.TextXAlignment.Right
		rows[index] = { name = name, gold = gold }
	end

	statusLabel = makeText(list, UDim2.fromScale(1, 1), UDim2.new(), 18, MUTED)
	statusLabel.Text = "Loading..."

	board.Parent = workspace
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = if ok and typeof(name) == "string" then name else `Miner {userId}`
	names[userId] = resolved
	return resolved
end

local function save(player: Player)
	local lifetime = player:GetAttribute("Lifetime")
	local userId = player.UserId
	-- Studio's test players have negative ids and are kept off the board.
	if not store or userId <= 0 or typeof(lifetime) ~= "number" or written[userId] == lifetime then
		return
	end

	local value = math.floor(lifetime)
	local activeStore = store
	local ok, err = pcall(function()
		activeStore:SetAsync(tostring(userId), value)
	end)
	if ok then
		written[userId] = value
	else
		warn(`[dynamite] leaderboard save failed: {err}`)
	end
end

local function refresh()
	if not store then
		return
	end

	local activeStore = store
	local ok, result = pcall(function()
		return activeStore:GetSortedAsync(false, Config.LEADERBOARD_SIZE):GetCurrentPage()
	end)
	if not ok then
		warn(`[dynamite] leaderboard read failed: {result}`)
		statusLabel.Text = "Leaderboard unavailable"
		return
	end

	local entries = result :: { { key: string, value: number } }
	for index, row in rows do
		local entry = entries[index]
		local userId = entry and tonumber(entry.key)
		if entry and userId then
			row.name.Text = `{index}. {nameOf(userId)}`
			row.gold.Text = `{entry.value}`
		else
			row.name.Text = ""
			row.gold.Text = ""
		end
	end
	statusLabel.Text = if #entries == 0 then "Bank gold to get on the board" else ""
end

function Leaderboard.init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[dynamite] leaderboard store unavailable: {result}`)
	end

	buildBoard()
	if not store then
		statusLabel.Text = "Leaderboard unavailable"
	end

	Players.PlayerRemoving:Connect(save)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

function Leaderboard.start()
	while true do
		for _, player in Players:GetPlayers() do
			save(player)
		end
		refresh()
		task.wait(Config.LEADERBOARD_REFRESH_SECONDS)
	end
end

return Leaderboard
