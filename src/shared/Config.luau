--!strict
-- Tunable gameplay values. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a client-reported value from this file.

local BLOCK_SIZE = 6
local ENTRANCE_Z = 40

return table.freeze({
	AUTOSAVE_INTERVAL = 60,

	-- Round timing, in seconds.
	INTERMISSION_SECONDS = 12,
	SHIFT_SECONDS = 90,
	COLLAPSE_SECONDS = 20,

	-- Mine shape. The mine runs from ENTRANCE_Z towards +Z.
	BLOCK_SIZE = BLOCK_SIZE,
	MINE_WIDTH = 16,
	MINE_HEIGHT = 4,
	MINE_DEPTH = 24,
	FLOOR_Y = 0.2,
	ENTRANCE_Z = ENTRANCE_Z,
	STARTER_TUNNEL_DEPTH = 4,

	-- Crossing this line on the way out banks the haul.
	BANK_Z = ENTRANCE_Z - BLOCK_SIZE,
	BANK_CHECK_SECONDS = 0.25,

	-- Dynamite.
	PLANT_REACH = 18,
	FUSE_SECONDS = 2,
	BLAST_RADIUS = 10,
	BARREL_BLAST_RADIUS = 15,
	CHAIN_DELAY_SECONDS = 0.2,
	MAX_STICKS = 5,
	MAX_ACTIVE_STICKS = 3,
	STICK_REGEN_SECONDS = 3,

	-- Getting caught in a blast.
	DAMAGE_MIN = 15,
	DAMAGE_MAX = 65,
	HIT_HAUL_LOSS = 0.25,

	-- Gold per ore block.
	ORE_VALUE = table.freeze({
		Rock = 0,
		Copper = 5,
		Silver = 15,
		Gold = 50,
		Barrel = 0,
	}),
})
