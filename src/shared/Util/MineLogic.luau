--!strict
-- Pure rules for the mine: no instances, no state.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local MineLogic = {}

-- depth runs from 0 at the entrance to 1 at the back; roll is in [0, 1).
function MineLogic.rollKind(depth: number, roll: number): Types.BlockKind
	local gold = math.max(0, depth - 0.4) * 0.12
	local silver = gold + depth * 0.09
	local copper = silver + 0.08
	local barrel = copper + 0.015 + depth * 0.02

	if roll < gold then
		return "Gold"
	elseif roll < silver then
		return "Silver"
	elseif roll < copper then
		return "Copper"
	elseif roll < barrel then
		return "Barrel"
	end
	return "Rock"
end

function MineLogic.blastDamage(distance: number, radius: number): number
	local closeness = math.clamp(1 - distance / radius, 0, 1)
	return Config.DAMAGE_MIN + (Config.DAMAGE_MAX - Config.DAMAGE_MIN) * closeness
end

return MineLogic
