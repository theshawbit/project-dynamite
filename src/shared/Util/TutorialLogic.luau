--!strict
-- Works out the next tip from a player's saved progress, so the guide needs no
-- saved state of its own. Buying a first upgrade ends it for good.

local Types = require(script.Parent.Parent.Types)

local TutorialLogic = {}

function TutorialLogic.step(state: Types.TutorialState): Types.TutorialStep?
	if state.upgraded or (state.phase ~= "Shift" and state.phase ~= "Collapse") then
		return nil
	end

	if state.phase == "Collapse" then
		return "Escape"
	elseif state.carried > 0 then
		return "Bank"
	elseif state.banked >= state.cheapestUpgrade then
		return "Buy"
	elseif state.banked > 0 then
		return "EarnMore"
	elseif state.sticks < state.maxSticks then
		return "StandBack"
	end
	return "Plant"
end

return TutorialLogic
