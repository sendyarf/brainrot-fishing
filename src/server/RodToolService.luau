-- RodToolService — hands the player their fishing rod Tool and swaps it
-- when they buy a better rod. The rod is a Tool in the Backpack: the
-- player equips it (it starts equipped) and clicks or presses E to cast.
-- Only one rod at a time; the old tool is removed on upgrade.

local Players = game:GetService("Players")
local RodModelFactory = require(game:GetService("ReplicatedStorage").Shared.RodModelFactory)

local RodToolService = {}

local dataService = nil

function RodToolService.Init(deps)
	dataService = deps.DataService
end

-- Gives the player the tool for their current rod, removing any old rod.
function RodToolService.GiveRodToPlayer(player)
	local data = dataService.GetData(player)
	if not data then
		return
	end
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	-- Remove the old rod from the backpack and the character.
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and string.find(child.Name, "Rod") then
					child:Destroy()
				end
			end
		end
	end
	local tool = RodModelFactory.BuildRodTool(data.rod)
	tool.Parent = backpack
	-- Auto-equip so a new player can cast within seconds of spawning.
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

-- Re-gives the rod when the character respawns (tools do not survive death).
function RodToolService.OnCharacterAdded(player)
	task.wait(0.5)
	RodToolService.GiveRodToPlayer(player)
end

return RodToolService
