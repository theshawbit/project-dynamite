--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	gold: number,
	-- Every coin ever banked, including gold since spent. Ranks come from this.
	lifetimeGold: number,
	upgrades: { [string]: number },
	skin: string,
	ownedSkins: { [string]: boolean },
}

export type Skin = {
	id: string,
	name: string,
	description: string,
	price: number,
	rank: number,
	stick: Color3,
	spark: Color3,
	material: Enum.Material,
}

export type Rank = {
	name: string,
	lifetime: number,
	color: Color3,
}

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	basePrice: number,
}

export type Phase = "Intermission" | "Shift" | "Collapse"

export type BlockKind =
	"Rock"
	| "Copper"
	| "Silver"
	| "Gold"
	| "Crystal"
	| "Barrel"
	| "Gas"
	| "Hardrock"

export type TutorialStep = "Plant" | "StandBack" | "Bank" | "EarnMore" | "Buy" | "Escape"

-- What the first-shift guide needs to know about a player.
export type TutorialState = {
	phase: string?,
	carried: number,
	banked: number,
	sticks: number,
	maxSticks: number,
	upgraded: boolean,
	cheapestUpgrade: number,
}

-- What one blast removed from the mine.
export type CarveResult = {
	gold: number,
	barrels: { Vector3 },
	gasPockets: { Vector3 },
}

-- One shift's mine plan, keyed by grid cell index. A missing cell is empty.
export type MineLayout = {
	kinds: { [number]: BlockKind },
	hasCrystal: boolean,
}

return nil
