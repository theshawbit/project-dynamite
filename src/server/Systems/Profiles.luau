--!strict
-- The only module that touches saved data. ProfileStore handles session
-- locking, autosave and flushing on shutdown; gameplay code mutates the table
-- Profiles.load returns and never calls a DataStore directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Util.UpgradeLogic)

local CURRENT_VERSION = 2

local TEMPLATE: Types.PlayerProfile = {
	version = CURRENT_VERSION,
	gold = 0,
	lifetimeGold = 0,
	upgrades = {},
}

local store = ProfileStore.New("PlayerData", TEMPLATE)
local profiles: { [Player]: any } = {}

local Profiles = {}

-- Version 1 saves had no lifetime total. It is rebuilt from the gold they
-- hold plus everything already spent in the shop, so early players keep the
-- rank they earned.
local function migrate(data: Types.PlayerProfile)
	if data.version < 2 then
		local spent = 0
		for _, upgrade in Config.UPGRADES do
			spent += UpgradeLogic.spentOn(upgrade, data.upgrades[upgrade.id] or 0)
		end
		data.lifetimeGold = math.max(data.lifetimeGold, data.gold + spent)
		data.version = 2
	end
end

-- Yields. Returns nil if the player left or was kicked, so a failed load can
-- never start them on a blank profile that would overwrite their real save.
function Profiles.load(player: Player): Types.PlayerProfile?
	local profile = store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		if player.Parent == Players then
			player:Kick("Your save couldn't be loaded. Please rejoin in a moment.")
		end
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	profiles[player] = profile
	return profile.Data
end

function Profiles.release(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

return Profiles
