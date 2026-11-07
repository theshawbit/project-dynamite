--!strict
-- The one list of remotes. The server creates them at startup; both sides
-- fetch them by name through Net.get.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type RemoteName = "PlantDynamite" | "BuyUpgrade" | "Blast" | "Notice" | "ShiftSummary"

local NAMES: { RemoteName } = { "PlantDynamite", "BuyUpgrade", "Blast", "Notice", "ShiftSummary" }
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
	folder.Parent = ReplicatedStorage
end

function Net.get(name: RemoteName): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
