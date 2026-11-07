--!strict
-- A full-screen frame that shrinks everything inside it on short screens, so
-- layouts written in pixels still fit a phone held sideways. The frame is
-- made 1/scale the size of the screen and then scaled down, so it still
-- covers exactly the screen and offset positions shrink with everything else.

local REFERENCE_HEIGHT = 720
-- Below this, text gets too small to read on a phone.
local MIN_SCALE = 0.75

local ScaledRoot = {}

function ScaledRoot.create(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "ScaledRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local function update()
		local camera = workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else REFERENCE_HEIGHT
		local factor = math.clamp(height / REFERENCE_HEIGHT, MIN_SCALE, 1)
		scale.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end

	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end

	root.Parent = gui
	return root
end

-- Phones and tablets with no keyboard get the touch layout.
function ScaledRoot.isTouchOnly(): boolean
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return ScaledRoot
