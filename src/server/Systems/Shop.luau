--!strict
-- Sells upgrades. The client sends only an upgrade id; the price, the player's
-- level and their gold all come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UpgradeLogic = require(ReplicatedStorage.Shared.Util.UpgradeLogic)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Miners = require(script.Parent.Miners)

local Shop = {}

local function onBuyRequest(player: Player, id: unknown)
	if not RateLimit.allow(player, "BuyUpgrade", 4, 4) then
		return
	end

	-- Type.
	if typeof(id) ~= "string" then
		return
	end

	-- Permission: the upgrade exists, and the player's profile has loaded.
	local upgrade = UpgradeLogic.find(id)
	local level = Miners.levelOf(player, id)
	if not upgrade or not level then
		return
	end

	-- Plausibility: below max level and able to afford it.
	if level >= upgrade.maxLevel then
		return
	end
	if Miners.purchase(player, upgrade.id, UpgradeLogic.price(upgrade, level)) then
		Miners.notify(player, `{upgrade.name} upgraded to level {level + 1}!`)
	end
end

function Shop.init()
	Net.get("BuyUpgrade").OnServerEvent:Connect(onBuyRequest)
end

function Shop.start() end

return Shop
