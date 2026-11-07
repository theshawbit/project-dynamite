--!strict
-- Pure rank rules: which rank a lifetime gold total earns, and what comes next.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local RankLogic = {}

-- 1 for the first rank, counting up.
function RankLogic.index(lifetime: number): number
	local reached = 1
	for index, rank in Config.RANKS do
		if lifetime >= rank.lifetime then
			reached = index
		end
	end
	return reached
end

function RankLogic.get(index: number): Types.Rank
	return Config.RANKS[math.clamp(index, 1, #Config.RANKS)]
end

-- nil once the top rank is reached.
function RankLogic.nextAfter(index: number): Types.Rank?
	return Config.RANKS[index + 1]
end

return RankLogic
