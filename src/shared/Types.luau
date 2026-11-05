--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	coins: number,
}

export type Phase = "Intermission" | "Shift" | "Collapse"

export type BlockKind = "Rock" | "Copper" | "Silver" | "Gold" | "Barrel"

-- What one blast removed from the mine.
export type CarveResult = {
	gold: number,
	barrels: { Vector3 },
}

return nil
