--!strict
-- The review list. Suspicious players are recorded here for the developer to
-- look at; nothing in the game bans anyone. Lag can look like cheating, so a
-- person decides, using Creator Dashboard > Safety > Bans.
--
-- Entries live in the "ReviewList" DataStore, keyed by UserId, and can be
-- read in Creator Dashboard > Data Stores. A "held" player is kept off the
-- Top Miners board until the entry is cleared.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "ReviewList"
local FLUSH_SECONDS = 60

type Pending = { reasons: { [string]: number }, hold: boolean }

export type Entry = {
	name: string,
	reasons: { [string]: number },
	held: boolean,
	lastFlagged: number,
}

local store: DataStore? = nil
local held: { [Player]: boolean } = {}
local pending: { [Player]: Pending } = {}

local Review = {}

local function flush(player: Player)
	local entry = pending[player]
	pending[player] = nil
	-- Studio's test players have negative ids and are never saved.
	if not entry or not store or player.UserId <= 0 then
		return
	end

	local activeStore = store
	local name = player.Name
	local ok, err = pcall(function()
		activeStore:UpdateAsync(tostring(player.UserId), function(old: Entry?): Entry
			local updated: Entry = old
				or { name = name, reasons = {}, held = false, lastFlagged = 0 }
			updated.name = name
			updated.held = updated.held or entry.hold
			updated.lastFlagged = os.time()
			for reason, count in entry.reasons do
				updated.reasons[reason] = (updated.reasons[reason] or 0) + count
			end
			return updated
		end)
	end)
	if not ok then
		warn(`[dynamite] review save failed: {err}`)
	end
end

local function loadHold(player: Player)
	if not store or player.UserId <= 0 then
		return
	end
	local activeStore = store
	local ok, result = pcall(function()
		return activeStore:GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(result) == "table" and result.held == true and player.Parent == Players then
		held[player] = true
	end
end

-- Records a reason against the player. hold keeps them off the global board.
function Review.flag(player: Player, reason: string, hold: boolean)
	warn(`[dynamite] review: {player.Name} ({player.UserId}) {reason}`)
	if hold then
		held[player] = true
	end

	local entry = pending[player]
	if not entry then
		entry = { reasons = {}, hold = false }
		pending[player] = entry
	end
	entry.reasons[reason] = (entry.reasons[reason] or 0) + 1
	entry.hold = entry.hold or hold
end

function Review.isHeld(player: Player): boolean
	return held[player] == true
end

function Review.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[dynamite] review store unavailable: {result}`)
	end

	Players.PlayerAdded:Connect(loadHold)
	for _, player in Players:GetPlayers() do
		task.spawn(loadHold, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		held[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			flush(player)
		end
	end)
end

function Review.start()
	while true do
		task.wait(FLUSH_SECONDS)
		for player in pending do
			flush(player)
		end
	end
end

return Review
