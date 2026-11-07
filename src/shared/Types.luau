--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	gold: number,
	upgrades: { [string]: number },
}

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	basePrice: number,
}

export type Phase = "Intermission" | "Shift" | "Collapse"

export type BlockKind = "Rock" | "Copper" | "Silver" | "Gold" | "Crystal" | "Barrel" | "Gas"

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
