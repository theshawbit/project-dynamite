--!strict
-- Pure skin rules, shared so the shop shows exactly what the server allows.

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local SkinLogic = {}

function SkinLogic.find(id: string): Types.Skin?
	for _, skin in Config.SKINS do
		if skin.id == id then
			return skin
		end
	end
	return nil
end

-- The skin to draw for an id, falling back to the default for unknown ids.
function SkinLogic.resolve(id: unknown): Types.Skin
	local skin = if typeof(id) == "string" then SkinLogic.find(id) else nil
	return skin or SkinLogic.find(Config.DEFAULT_SKIN) :: Types.Skin
end

-- Free skins are owned as soon as their rank is reached.
function SkinLogic.isOwned(skin: Types.Skin, owned: { [string]: boolean }): boolean
	return skin.price == 0 or owned[skin.id] == true
end

return SkinLogic
