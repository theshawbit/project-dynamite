--!strict
-- Owns each player's haul, gold, upgrades and dynamite supply. Gold and
-- upgrade levels live in the saved profile; attributes and leaderstats only
-- mirror them for display. Until a profile loads, the player has no state and
-- every function here does nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Util.UpgradeLogic)
local Profiles = require(script.Parent.Profiles)

type MinerState = {
	data: Types.PlayerProfile,
	carried: number,
	sticks: number,
	regenProgress: number,
	shiftBanked: number,
	shiftLost: number,
	goldStat: IntValue,
}

local states: { [Player]: MinerState } = {}
local loading: { [Player]: boolean } = {}

local Miners = {}

local function levelIn(state: MinerState, id: string): number
	return state.data.upgrades[id] or 0
end

local function maxSticksOf(state: MinerState): number
	return UpgradeLogic.maxSticks(levelIn(state, "Pack"))
end

local function publish(player: Player, state: MinerState)
	player:SetAttribute("Carried", state.carried)
	player:SetAttribute("Banked", state.data.gold)
	player:SetAttribute("Sticks", state.sticks)
	player:SetAttribute("MaxSticks", maxSticksOf(state))
	for _, upgrade in Config.UPGRADES do
		player:SetAttribute(`Level_{upgrade.id}`, levelIn(state, upgrade.id))
	end
	state.goldStat.Value = state.data.gold
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

function Miners.dropHaul(player: Player)
	local state = states[player]
	if state and state.carried > 0 then
		local fraction = UpgradeLogic.haulLoss(levelIn(state, "Boots"))
		local lost = math.ceil(state.carried * fraction)
		state.carried -= lost
		state.shiftLost += lost
		publish(player, state)
		Miners.notify(player, `Blast hit! Dropped {lost} gold`)
	end
end

function Miners.loseHaul(player: Player, reason: string)
	local state = states[player]
	if state and state.carried > 0 then
		local lost = state.carried
		state.carried = 0
		state.shiftLost += lost
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

function Miners.regenSticks(deltaSeconds: number)
	for player, state in states do
		if state.sticks >= maxSticksOf(state) then
			state.regenProgress = 0
		else
			state.regenProgress += deltaSeconds
			if state.regenProgress >= UpgradeLogic.regenSeconds(levelIn(state, "Resupply")) then
				state.regenProgress = 0
				state.sticks += 1
				publish(player, state)
			end
		end
	end
end

function Miners.blastRadiusOf(player: Player): number
	local state = states[player]
	return UpgradeLogic.blastRadius(if state then levelIn(state, "BlastRadius") else 0)
end

-- Returns nil until the player's profile has loaded.
function Miners.levelOf(player: Player, id: string): number?
	local state = states[player]
	return if state then levelIn(state, id) else nil
end

function Miners.purchase(player: Player, id: string, price: number): boolean
	local state = states[player]
	if not state or state.data.gold < price then
		return false
	end
	state.data.gold -= price
	state.data.upgrades[id] = levelIn(state, id) + 1
	publish(player, state)
	return true
end

-- A new shift: last shift is reported, haul is wiped, gold is kept and supply
-- is refilled. Haul still unbanked at this point counts as lost.
function Miners.resetForShift()
	for player, state in states do
		local lost = state.shiftLost + state.carried
		if state.shiftBanked > 0 or lost > 0 then
			Net.get("ShiftSummary"):FireClient(player, state.shiftBanked, lost)
		end

		state.shiftBanked = 0
		state.shiftLost = 0
		state.carried = 0
		state.sticks = maxSticksOf(state)
		state.regenProgress = 0
		publish(player, state)
	end
end

local function bank(player: Player, state: MinerState)
	local amount = state.carried
	state.data.gold += amount
	state.shiftBanked += amount
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
	if loading[player] or states[player] then
		return
	end

	loading[player] = true
	local data = Profiles.load(player)
	loading[player] = nil
	if not data then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local goldStat = Instance.new("IntValue")
	goldStat.Name = "Gold"
	goldStat.Parent = leaderstats
	leaderstats.Parent = player

	local state: MinerState = {
		data = data,
		carried = 0,
		sticks = UpgradeLogic.maxSticks(data.upgrades.Pack or 0),
		regenProgress = 0,
		shiftBanked = 0,
		shiftLost = 0,
		goldStat = goldStat,
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
		Profiles.release(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
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
