--!strict
-- dynamite client entry point.

-- Listed by hand so startup order is fixed and every require is static.
local CONTROLLERS: { any } = {
	require(script.Controllers.Hud),
	require(script.Controllers.Planting),
	require(script.Controllers.ShopUI),
	require(script.Controllers.BlastFeedback),
}

for _, controller in CONTROLLERS do
	controller.init()
end

for _, controller in CONTROLLERS do
	task.spawn(controller.start)
end

print("[dynamite] client started")
