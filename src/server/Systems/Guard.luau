--!strict
-- Keeps the server's own idea of where each miner can be. Roblox lets every
-- player's computer move their own character, so a cheat can teleport or
-- walk through rock; this catches both, snaps the miner back to their last
-- good spot, and refuses banking and planting for a moment.
--
-- Movement is judged sideways only, so falling never counts. A burst budget
-- absorbs blast knockback; a teleport or a sustained speed hack empties it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Mine = require(script.Parent.Mine)
local Review = require(script.Parent.Review)

type Track = {
	character: Model,
	lastGood: CFrame,
	lastPosition: Vector3,
	lastTime: number,
	budget: number,
	blockedUntil: number,
}

local DEFAULT_WALK_SPEED = 16

local tracks: { [Player]: Track } = {}
local strikes: { [Player]: number } = {}

local Guard = {}

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function startTrack(character: Model, root: BasePart): Track
	return {
		character = character,
		lastGood = root.CFrame,
		lastPosition = root.Position,
		lastTime = os.clock(),
		budget = Config.GUARD_BURST_STUDS,
		blockedUntil = 0,
	}
end

local function strike(player: Player, reason: string)
	local count = (strikes[player] or 0) + 1
	strikes[player] = count
	-- One slip can be lag; repeated ones are worth a look.
	if count >= Config.GUARD_STRIKES_TO_REVIEW then
		Review.flag(player, reason, false)
	end
end

-- Samples the player's position now. Returns true when it can be trusted for
-- banking and planting. Safe to call as often as needed.
function Guard.check(player: Player): boolean
	local character = player.Character
	local root = character and rootOf(character)
	if not character or not root then
		return false
	end

	local track = tracks[player]
	-- A new character starts fresh: spawning is a legitimate teleport.
	if not track or track.character ~= character then
		tracks[player] = startTrack(character, root)
		return true
	end

	local now = os.clock()
	local deltaTime = now - track.lastTime
	if deltaTime <= 0 then
		return now >= track.blockedUntil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local walkSpeed = if humanoid then humanoid.WalkSpeed else DEFAULT_WALK_SPEED
	local offset = root.Position - track.lastPosition
	local moved = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local allowed = walkSpeed * Config.GUARD_SPEED_MARGIN * deltaTime

	track.budget = math.min(
		Config.GUARD_BURST_STUDS,
		track.budget + Config.GUARD_BURST_REFILL * deltaTime - math.max(0, moved - allowed)
	)
	track.lastPosition = root.Position
	track.lastTime = now

	-- The mine is rebuilt during intermission, so rock may appear around anyone
	-- still standing where it goes.
	local inRock = workspace:GetAttribute("Phase") ~= "Intermission"
		and Mine.isSolidAt(root.Position)
	local reason = if track.budget < 0
		then "moved too fast"
		elseif inRock then "stood inside rock"
		else nil

	if reason then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = track.lastGood
		track.lastPosition = track.lastGood.Position
		track.budget = 0
		track.blockedUntil = now + Config.GUARD_BLOCK_SECONDS
		strike(player, reason)
		return false
	end

	track.lastGood = root.CFrame
	return now >= track.blockedUntil
end

function Guard.init()
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
		strikes[player] = nil
	end)
end

function Guard.start()
	while true do
		task.wait(Config.GUARD_CHECK_SECONDS)
		for _, player in Players:GetPlayers() do
			Guard.check(player)
		end
	end
end

return Guard
