# dynamite

A push-your-luck mining game for Roblox, built with [Rojo](https://rojo.space).

## How to play

1. Blast into the mountain: click rock to plant dynamite, then get clear.
2. Ore in the blast is added to your haul. It gets richer the deeper you go.
3. Red barrels explode too, so one stick can set off a chain reaction.
4. Carry your haul back over the bank line to keep it.
5. When the shift ends, the mine collapses from the back towards the entrance.
   Anything you haven't banked is lost.

Getting hit by a blast costs you health and a quarter of your haul, and dying
loses all of it. That includes your own dynamite.

Banked gold buys permanent upgrades in the shop (press B).

All the tuning values live in `src/shared/Config.luau`.

## Development

1. Install the toolchain: `rokit install`
2. Install packages: `wally install`
3. Start syncing: `rojo serve`
4. In Roblox Studio, connect with the Rojo plugin.

Saving needs a published place with **Enable Studio Access to API Services** turned on
in Game Settings. Without it the game still runs, but nothing is saved between sessions.

## Structure

- `src/shared` → ReplicatedStorage/Shared — types, config, pure utilities
- `src/server` → ServerScriptService/Server — authoritative game systems
- `src/client` → StarterPlayerScripts/Client — rendering, input, UI

## Checks

- Format: `stylua src`
- Lint: `selene src`
