--!strict
-- dynamite server entry point. Two-phase bootstrap: init() all systems,
-- then start() all systems (see roblox-dev architecture guidance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

-- Listed by hand so startup order is fixed and every require is static.
local SYSTEMS: { any } = {
	require(script.Systems.Review),
	require(script.Systems.Miners),
	require(script.Systems.Mine),
	require(script.Systems.Guard),
	require(script.Systems.Hazards),
	require(script.Systems.Dynamite),
	require(script.Systems.Shop),
	require(script.Systems.Skins),
	require(script.Systems.Leaderboard),
	require(script.Systems.Shift),
}

Net.setup()

for _, system in SYSTEMS do
	system.init()
end

for _, system in SYSTEMS do
	task.spawn(system.start)
end

print("[dynamite] server started")
