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

	-- Mine layouts. Every shift gets fresh hollow caverns and rich veins.
	CAVERNS_MIN = 2,
	CAVERNS_MAX = 4,
	GOLD_VEINS = 2,
	GOLD_VEIN_LENGTH_MIN = 4,
	GOLD_VEIN_LENGTH_MAX = 7,
	CRYSTAL_VEIN_CHANCE = 0.25,
	CRYSTAL_VEIN_LENGTH_MIN = 3,
	CRYSTAL_VEIN_LENGTH_MAX = 5,
	-- Veins start somewhere past this share of the mine's depth.
	VEIN_START_DEPTH = 0.45,

	-- Gas pockets release a cloud that hurts anyone inside it. Blasting the
	-- cloud ignites it.
	GAS_CLOUD_RADIUS = 9,
	GAS_CLOUD_SECONDS = 10,
	GAS_DAMAGE_PER_SECOND = 12,
	GAS_BLAST_RADIUS = 16,

	-- Any blast inside the mine can bring the roof down nearby. The chance
	-- grows towards the back of the mine.
	CAVE_IN_CHANCE = 0.06,
	CAVE_IN_CHANCE_PER_DEPTH = 0.14,
	CAVE_IN_RADIUS = 8,
	CAVE_IN_WARNING_SECONDS = 1.5,
	CAVE_IN_DAMAGE = 35,
	CAVE_IN_COOLDOWN_SECONDS = 6,

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

	-- Upgrades. Each level changes the base value above by this much.
	UPGRADE_PRICE_GROWTH = 1.7,
	BLAST_RADIUS_PER_LEVEL = 1.5,
	REGEN_SECONDS_PER_LEVEL = 0.4,
	HAUL_LOSS_PER_LEVEL = 0.04,
	ORE_BONUS_PER_LEVEL = 0.1,
	HAZARD_DAMAGE_CUT_PER_LEVEL = 0.12,
	UPGRADES = table.freeze({
		{
			id = "BlastRadius",
			name = "Bigger Blasts",
			description = "Your dynamite reaches further",
			maxLevel = 5,
			basePrice = 100,
		},
		{
			id = "Resupply",
			name = "Quick Resupply",
			description = "New sticks arrive sooner",
			maxLevel = 5,
			basePrice = 80,
		},
		{
			id = "Pack",
			name = "Bigger Pack",
			description = "Carry one more stick per level",
			maxLevel = 5,
			basePrice = 60,
		},
		{
			id = "Boots",
			name = "Sturdy Boots",
			description = "Drop less haul when a blast hits you",
			maxLevel = 5,
			basePrice = 60,
		},
		{
			id = "Luck",
			name = "Lucky Strike",
			description = "Every ore pays 10% more per level",
			maxLevel = 5,
			basePrice = 120,
		},
		{
			id = "HardHat",
			name = "Hard Hat",
			description = "Gas and cave-ins hurt less",
			maxLevel = 5,
			basePrice = 90,
		},
	}),

	-- Ranks are earned with lifetime gold: every coin ever banked, spent or not.
	RANKS = table.freeze({
		table.freeze({ name = "Greenhorn", lifetime = 0, color = Color3.fromRGB(200, 195, 185) }),
		table.freeze({ name = "Digger", lifetime = 500, color = Color3.fromRGB(214, 120, 62) }),
		table.freeze({ name = "Blaster", lifetime = 2000, color = Color3.fromRGB(235, 80, 60) }),
		table.freeze({ name = "Foreman", lifetime = 6000, color = Color3.fromRGB(190, 215, 235) }),
		table.freeze({
			name = "Demolitionist",
			lifetime = 15000,
			color = Color3.fromRGB(255, 200, 40),
		}),
		table.freeze({ name = "Legend", lifetime = 40000, color = Color3.fromRGB(110, 230, 255) }),
	}),

	-- The Top Miners board in the yard, shared by every server.
	LEADERBOARD_SIZE = 10,
	LEADERBOARD_REFRESH_SECONDS = 60,
	LEADERBOARD_POSITION = Vector3.new(-30, 7.2, ENTRANCE_Z - 2 * BLOCK_SIZE - 14),

	-- Audio from Roblox's licensed APM and Pro Sound Effects libraries.
	SOUNDS = table.freeze({
		Fuse = table.freeze({ id = 1843927436, volume = 1.5 }),
		Blast = table.freeze({ id = 9114224800, volume = 0.8 }),
		Coin = table.freeze({ id = 9113849011, volume = 0.5 }),
		Bank = table.freeze({ id = 9113728042, volume = 0.6 }),
		Upgrade = table.freeze({ id = 9126073001, volume = 0.5 }),
		Rumble = table.freeze({ id = 9112775181, volume = 0.8 }),
	}),

	-- Gold per ore block.
	ORE_VALUE = table.freeze({
		Rock = 0,
		Copper = 5,
		Silver = 15,
		Gold = 50,
		Crystal = 120,
		Barrel = 0,
		Gas = 0,
	}),
})
