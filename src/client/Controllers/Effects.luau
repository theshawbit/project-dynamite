--!strict
-- Sounds and particles. Everything here is cosmetic and reacts to state the
-- server already publishes, so nothing in this file can change a result.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SkinLogic = require(ReplicatedStorage.Shared.Util.SkinLogic)

type SoundSpec = { id: number, volume: number }

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/fire_sparks_main.dds"
local CHIP_TEXTURE = "rbxasset://textures/particles/SquareParticle.png"

local DUST = Color3.fromRGB(150, 130, 110)
local ROCK = Color3.fromRGB(90, 78, 68)

-- Long enough for the blast sound to finish before its part is removed.
local BLAST_PART_SECONDS = 10
local BLAST_HEARING_RANGE = 220
local FUSE_FULL_VOLUME_RANGE = 25
local FUSE_HEARING_RANGE = 90
local RUMBLE_FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
local DUST_HEIGHT = 16

local localPlayer = Players.LocalPlayer
local random = Random.new()

local coinSound: Sound
local bankSound: Sound
local upgradeSound: Sound
local rumbleSound: Sound
local rumbleTween: Tween? = nil
local dustPart: Part
local dustEmitter: ParticleEmitter

local Effects = {}

local function makeSound(spec: SoundSpec, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = `rbxassetid://{spec.id}`
	sound.Volume = spec.volume
	sound.Parent = parent
	return sound
end

local function makeEffectPart(size: Vector3): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	return part
end

local function makeBurst(parent: Instance, texture: string, color: Color3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

local function playBlast(center: Vector3, radius: number, sparkColor: Color3)
	local part = makeEffectPart(Vector3.one)
	part.Position = center
	part.Parent = workspace

	local smoke = makeBurst(part, SMOKE_TEXTURE, DUST)
	smoke.Size = NumberSequence.new(radius * 0.3, radius * 0.9)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.8, 1.6)
	smoke.Speed = NumberRange.new(8, 20)
	smoke.Drag = 3

	local sparks = makeBurst(part, SPARK_TEXTURE, sparkColor)
	sparks.Size = NumberSequence.new(0.7, 0)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(30, 60)

	local chips = makeBurst(part, CHIP_TEXTURE, ROCK)
	chips.Size = NumberSequence.new(0.7)
	chips.Rotation = NumberRange.new(0, 360)
	chips.RotSpeed = NumberRange.new(-200, 200)
	chips.Lifetime = NumberRange.new(0.6, 1)
	chips.Speed = NumberRange.new(25, 45)
	chips.Acceleration = Vector3.new(0, -80, 0)

	smoke:Emit(20)
	sparks:Emit(30)
	chips:Emit(16)

	local boom = makeSound(Config.SOUNDS.Blast, part)
	boom.RollOffMaxDistance = BLAST_HEARING_RANGE
	boom.PlaybackSpeed = random:NextNumber(0.9, 1.1)
	boom:Play()

	Debris:AddItem(part, BLAST_PART_SECONDS)
end

-- The skin id only picks a spark colour; unknown ids fall back to the default.
local function onBlast(center: unknown, radius: unknown, skinId: unknown)
	if typeof(center) == "Vector3" and typeof(radius) == "number" then
		playBlast(center, radius, SkinLogic.resolve(skinId).spark)
	end
end

-- Sticks are server parts, so this sound is removed along with its stick.
local function onStickAdded(stick: Instance)
	if stick:IsA("BasePart") then
		local fuse = makeSound(Config.SOUNDS.Fuse, stick)
		fuse.Looped = true
		fuse.RollOffMinDistance = FUSE_FULL_VOLUME_RANGE
		fuse.RollOffMaxDistance = FUSE_HEARING_RANGE
		fuse:Play()
	end
end

-- The first value is only the saved total loading, so it never plays a sound.
local function playOnIncrease(attribute: string, sound: Sound)
	local last = localPlayer:GetAttribute(attribute)
	localPlayer:GetAttributeChangedSignal(attribute):Connect(function()
		local previous = last
		local value = localPlayer:GetAttribute(attribute)
		last = value
		if typeof(previous) == "number" and typeof(value) == "number" and value > previous then
			sound:Play()
		end
	end)
end

local function fadeRumble(volume: number)
	if rumbleTween then
		rumbleTween:Cancel()
	end
	local tween = TweenService:Create(rumbleSound, RUMBLE_FADE, { Volume = volume })
	rumbleTween = tween
	tween:Play()
end

local function refreshPhase()
	local collapsing = workspace:GetAttribute("Phase") == "Collapse"
	dustEmitter.Enabled = collapsing

	if collapsing then
		rumbleSound:Play()
		fadeRumble(Config.SOUNDS.Rumble.volume)
	elseif rumbleSound.Playing then
		fadeRumble(0)
	end
end

local function makeCollapseDust()
	dustPart = makeEffectPart(Vector3.new(50, 1, 50))
	dustPart.Parent = workspace

	dustEmitter = Instance.new("ParticleEmitter")
	dustEmitter.Texture = SMOKE_TEXTURE
	dustEmitter.Color = ColorSequence.new(DUST)
	dustEmitter.Shape = Enum.ParticleEmitterShape.Box
	dustEmitter.EmissionDirection = Enum.NormalId.Bottom
	dustEmitter.Size = NumberSequence.new(1, 3)
	dustEmitter.Transparency = NumberSequence.new(0.5, 1)
	dustEmitter.Lifetime = NumberRange.new(1.5, 2.5)
	dustEmitter.Speed = NumberRange.new(4, 10)
	dustEmitter.Acceleration = Vector3.new(0, -12, 0)
	dustEmitter.Rate = 40
	dustEmitter.Enabled = false
	dustEmitter.Parent = dustPart
end

local function updateDust()
	local camera = workspace.CurrentCamera
	if dustEmitter.Enabled and camera then
		dustPart.Position = camera.CFrame.Position + Vector3.yAxis * DUST_HEIGHT
	end
end

function Effects.init()
	coinSound = makeSound(Config.SOUNDS.Coin, SoundService)
	bankSound = makeSound(Config.SOUNDS.Bank, SoundService)
	upgradeSound = makeSound(Config.SOUNDS.Upgrade, SoundService)
	rumbleSound = makeSound(Config.SOUNDS.Rumble, SoundService)
	rumbleSound.Looped = true
	rumbleSound.Volume = 0
	makeCollapseDust()

	playOnIncrease("Carried", coinSound)
	playOnIncrease("Banked", bankSound)
	playOnIncrease("Rank", upgradeSound)
	for _, upgrade in Config.UPGRADES do
		playOnIncrease(`Level_{upgrade.id}`, upgradeSound)
	end

	Net.get("Blast").OnClientEvent:Connect(onBlast)
	workspace:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	refreshPhase()
end

function Effects.start()
	RunService.RenderStepped:Connect(updateDust)

	local sticks = workspace:WaitForChild("Dynamite")
	sticks.ChildAdded:Connect(onStickAdded)
	for _, stick in sticks:GetChildren() do
		onStickAdded(stick)
	end
end

return Effects
