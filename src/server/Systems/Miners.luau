--!strict
-- Owns each player's haul, bank and dynamite supply. The server tables here
-- are the truth; attributes and leaderstats only mirror them for display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

type MinerState = {
	carried: number,
	banked: number,
	sticks: number,
	bankedStat: IntValue,
}

local states: { [Player]: MinerState } = {}

local Miners = {}

local function publish(player: Player, state: MinerState)
	player:SetAttribute("Carried", state.carried)
	player:SetAttribute("Banked", state.banked)
	player:SetAttribute("Sticks", state.sticks)
	state.bankedStat.Value = state.banked
end

function Miners.notify(player: Player, text: string)
	Net.get("Notice"):FireClient(player, text)
end

function Miners.rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Returns the humanoid only while the character is alive.
function Miners.humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

function Miners.addCarried(player: Player, gold: number)
	local state = states[player]
	if state and gold > 0 then
		state.carried += gold
		publish(player, state)
	end
end

function Miners.dropHaul(player: Player, fraction: number)
	local state = states[player]
	if state and state.carried > 0 then
		local lost = math.ceil(state.carried * fraction)
		state.carried -= lost
		publish(player, state)
		Miners.notify(player, `Blast hit! Dropped {lost} gold`)
	end
end

function Miners.loseHaul(player: Player, reason: string)
	local state = states[player]
	if state and state.carried > 0 then
		local lost = state.carried
		state.carried = 0
		publish(player, state)
		Miners.notify(player, `{reason} Lost {lost} gold`)
	end
end

function Miners.spendStick(player: Player): boolean
	local state = states[player]
	if not state or state.sticks <= 0 then
		return false
	end
	state.sticks -= 1
	publish(player, state)
	return true
end

function Miners.regenSticks()
	for player, state in states do
		if state.sticks < Config.MAX_STICKS then
			state.sticks += 1
			publish(player, state)
		end
	end
end

-- A new shift: haul is wiped, the bank is kept, supply is refilled.
function Miners.resetForShift()
	for player, state in states do
		state.carried = 0
		state.sticks = Config.MAX_STICKS
		publish(player, state)
	end
end

local function bank(player: Player, state: MinerState)
	local amount = state.carried
	state.banked += amount
	state.carried = 0
	publish(player, state)
	Miners.notify(player, `Banked {amount} gold!`)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		Miners.loseHaul(player, "You died!")
	end)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local bankedStat = Instance.new("IntValue")
	bankedStat.Name = "Gold"
	bankedStat.Parent = leaderstats
	leaderstats.Parent = player

	local state: MinerState = {
		carried = 0,
		banked = 0,
		sticks = Config.MAX_STICKS,
		bankedStat = bankedStat,
	}
	states[player] = state
	publish(player, state)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function Miners.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function Miners.start()
	while true do
		task.wait(Config.BANK_CHECK_SECONDS)
		for player, state in states do
			local root = Miners.rootOf(player)
			if state.carried > 0 and root and root.Position.Z < Config.BANK_Z then
				bank(player, state)
			end
		end
	end
end

return Miners
