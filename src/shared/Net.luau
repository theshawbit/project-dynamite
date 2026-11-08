--!strict
-- The one list of remotes. The server creates them at startup; both sides
-- fetch them by name through Net.get, or Net.getUnreliable for the
-- effect-only events where a dropped message doesn't matter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteName = "PlantDynamite" | "BuyUpgrade" | "SelectSkin" | "Notice" | "ShiftSummary"

-- Sent unreliably: cheaper on the network, and a lost blast effect is harmless.
export type UnreliableName = "Blast"

local NAMES: { RemoteName } =
	{ "PlantDynamite", "BuyUpgrade", "SelectSkin", "Notice", "ShiftSummary" }
local UNRELIABLE_NAMES: { UnreliableName } = { "Blast" }
local FOLDER_NAME = "Remotes"

local Net = {}

function Net.setup()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in UNRELIABLE_NAMES do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Net.get(name: RemoteName): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.getUnreliable(name: UnreliableName): UnreliableRemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

return Net
