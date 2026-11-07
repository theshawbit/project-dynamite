--!strict
-- Pure upgrade rules, shared so the shop can show the prices the server charges.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local UpgradeLogic = {}

function UpgradeLogic.find(id: string): Types.Upgrade?
	for _, upgrade in Config.UPGRADES do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

-- Price of the next level, rounded to the nearest 5 gold.
function UpgradeLogic.price(upgrade: Types.Upgrade, level: number): number
	local raw = upgrade.basePrice * Config.UPGRADE_PRICE_GROWTH ^ level
	return math.floor(raw / 5 + 0.5) * 5
end

function UpgradeLogic.blastRadius(level: number): number
	return Config.BLAST_RADIUS + level * Config.BLAST_RADIUS_PER_LEVEL
end

function UpgradeLogic.regenSeconds(level: number): number
	return Config.STICK_REGEN_SECONDS - level * Config.REGEN_SECONDS_PER_LEVEL
end

function UpgradeLogic.maxSticks(level: number): number
	return Config.MAX_STICKS + level
end

function UpgradeLogic.haulLoss(level: number): number
	return Config.HIT_HAUL_LOSS - level * Config.HAUL_LOSS_PER_LEVEL
end

function UpgradeLogic.oreBonus(level: number): number
	return 1 + level * Config.ORE_BONUS_PER_LEVEL
end

function UpgradeLogic.hazardDamageScale(level: number): number
	return 1 - level * Config.HAZARD_DAMAGE_CUT_PER_LEVEL
end

-- Total gold paid for the first `level` levels of an upgrade.
function UpgradeLogic.spentOn(upgrade: Types.Upgrade, level: number): number
	local total = 0
	for paid = 0, math.min(level, upgrade.maxLevel) - 1 do
		total += UpgradeLogic.price(upgrade, paid)
	end
	return total
end

return UpgradeLogic
