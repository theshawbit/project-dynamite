--!strict
-- Buys and equips dynamite skins. The client sends only a skin id; the price,
-- the rank needed and the player's gold all come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RankLogic = require(ReplicatedStorage.Shared.Util.RankLogic)
local SkinLogic = require(ReplicatedStorage.Shared.Util.SkinLogic)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Miners = require(script.Parent.Miners)

local Skins = {}

local function onSelectRequest(player: Player, id: unknown)
	if not RateLimit.allow(player, "SelectSkin", 4, 4) then
		return
	end

	-- Type.
	if typeof(id) ~= "string" then
		return
	end

	-- Permission: the skin exists. Rank, ownership and price are checked by
	-- Miners.selectSkin against the saved profile.
	local skin = SkinLogic.find(id)
	if not skin then
		return
	end

	local result = Miners.selectSkin(player, skin)
	if result == "Bought" then
		Miners.notify(player, `Bought {skin.name}!`)
	elseif result == "Equipped" then
		Miners.notify(player, `{skin.name} equipped`)
	elseif result == "Locked" then
		Miners.notify(player, `Reach {RankLogic.get(skin.rank).name} to unlock {skin.name}`)
	end
end

function Skins.init()
	Net.get("SelectSkin").OnServerEvent:Connect(onSelectRequest)
end

function Skins.start() end

return Skins
