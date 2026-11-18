-- RodToolService: the visible fishing rod the character holds.
-- The fishing system never showed a rod: the character cast with empty
-- hands. This service builds a Tool per player (grip + shaft + reel + tip,
-- welded to the Handle) in the current rod's colors, and keeps it equipped:
-- on spawn, on rod purchase, when a cast starts, and if the player
-- unequips it. A Tool is the standard Roblox way to hold an object —
-- equipping raises the right arm into the hold pose automatically, with no
-- custom animation needed. The shaft points up along the Handle's +Y axis
-- with the default grip, the classic held-rod look.
--
-- HOLSTER: the player can put the rod away (H key or the HOLSTER button in
-- the HUD) — the tool goes back to the Backpack and stays there until the
-- player draws it again or casts. The old behavior re-equipped the rod 0.3s
-- after any unequip, so the rod could never be put away at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local RodToolService = {}

-- holstered[player] = true while the rod is put away. The re-equip logic
-- and purchases respect it; casting clears it (a cast needs the rod).
local holstered = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Colors per rod tier (shaft, grip, reel, shaft material).
local RodColors = {
	Bamboo = { Shaft = Color3.fromRGB(170, 130, 80), Grip = Color3.fromRGB(120, 85, 50), Reel = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Wood },
	Wooden = { Shaft = Color3.fromRGB(140, 95, 55), Grip = Color3.fromRGB(100, 70, 40), Reel = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Wood },
	Steel = { Shaft = Color3.fromRGB(150, 155, 165), Grip = Color3.fromRGB(60, 60, 70), Reel = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal },
	Golden = { Shaft = Color3.fromRGB(255, 210, 60), Grip = Color3.fromRGB(180, 140, 40), Reel = Color3.fromRGB(255, 220, 100), Material = Enum.Material.Metal },
	Dragon = { Shaft = Color3.fromRGB(180, 40, 50), Grip = Color3.fromRGB(80, 20, 30), Reel = Color3.fromRGB(255, 170, 60), Material = Enum.Material.SmoothPlastic },
}

local function MakeRodPart(tool, handle, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	if shape then
		part.Shape = shape
	end
	part.Parent = tool
	if part ~= handle then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = handle
	end
	return part
end

-- Builds the rod Tool for a rod id (not parented). Parts are placed
-- relative to the Handle at the origin, then welded to it, so the whole
-- rod follows the hand when equipped.
function RodToolService.BuildRodTool(rodId)
	local def = GameConfig.Rods[rodId] or GameConfig.Rods.Bamboo
	local colors = RodColors[rodId] or RodColors.Bamboo
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool:SetAttribute("RodTool", true)
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- casting is E, not a tool click
	tool.RequiresHandle = true

	-- Grip the hand holds (the Tool's Handle), 1.4 tall.
	local handle = MakeRodPart(tool, nil, "Handle", Vector3.new(0.35, 1.4, 0.35), CFrame.new(0, 0, 0), colors.Grip, Enum.Material.Wood)
	-- Shaft: 5-stud cylinder along +Y from the top of the grip.
	local shaftCFrame = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	MakeRodPart(tool, handle, "Shaft", Vector3.new(5, 0.18, 0.18), shaftCFrame, colors.Shaft, colors.Material, Enum.PartType.Cylinder)
	-- Tip: thin lighter section at the top.
	local tipCFrame = CFrame.new(0, 6.0, 0) * CFrame.Angles(0, 0, math.rad(90))
	MakeRodPart(tool, handle, "Tip", Vector3.new(0.8, 0.1, 0.1), tipCFrame, colors.Shaft, colors.Material, Enum.PartType.Cylinder)
	-- Reel body on the front of the grip + a small crank knob.
	MakeRodPart(tool, handle, "Reel", Vector3.new(0.5, 0.5, 0.35), CFrame.new(0, 0.45, 0.32), colors.Reel, Enum.Material.Metal)
	MakeRodPart(tool, handle, "ReelKnob", Vector3.new(0.35, 0.14, 0.14), CFrame.new(0.4, 0.45, 0.32), colors.Reel, Enum.Material.Metal, Enum.PartType.Cylinder)
	return tool
end

-- Finds the player's rod tool, whether equipped or in the Backpack.
function RodToolService.FindRodTool(player)
	for _, container in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("RodTool") then
					return child
				end
			end
		end
	end
	return nil
end

-- Equips the rod (builds it first if it does not exist yet).
function RodToolService.EquipRod(player)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local tool = RodToolService.FindRodTool(player)
	if not tool then
		local data = DataService.GetData(player)
		tool = RodToolService.BuildRodTool(data and data.Rod or "Bamboo")
		tool.Parent = player:FindFirstChild("Backpack") or player
	end
	if tool.Parent ~= character then
		humanoid:EquipTool(tool)
	end
end

-- Re-equips the rod if it is sitting unequipped in the Backpack.
-- A cast calls this, and a cast needs the rod: it clears the holster.
function RodToolService.EnsureEquipped(player)
	local character = player.Character
	if not character then
		return
	end
	if holstered[player] then
		holstered[player] = nil
		GetRemote("RodHolster"):FireClient(player, false)
	end
	local tool = RodToolService.FindRodTool(player)
	if tool and tool.Parent ~= character then
		RodToolService.EquipRod(player)
	elseif not tool then
		RodToolService.EquipRod(player)
	end
end

-- Rebuilds the rod after a purchase (new tier, new look). A holstered rod
-- is rebuilt into the Backpack, not forced back into the hand.
function RodToolService.RefreshRod(player)
	local old = RodToolService.FindRodTool(player)
	if old then
		old:Destroy()
	end
	if holstered[player] then
		local data = DataService.GetData(player)
		local tool = RodToolService.BuildRodTool(data and data.Rod or "Bamboo")
		tool.Parent = player:FindFirstChild("Backpack") or player
	else
		RodToolService.EquipRod(player)
	end
end

-- Puts the rod away (true) or draws it again (false). Called from the
-- client's H key / HOLSTER button via the RodHolster remote. The state is
-- fired back so the HUD button always matches the server.
function RodToolService.SetHolstered(player, value)
	holstered[player] = value and true or nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if value then
		if humanoid then
			humanoid:UnequipTools()
		end
	else
		RodToolService.EquipRod(player)
	end
	GetRemote("RodHolster"):FireClient(player, value and true or false)
end

-- Hooks spawn + unequip for every player, including ones already in game.
function RodToolService.Init()
	local function OnCharacterAdded(player, character)
		-- Data loads in OnPlayerAdded (async DataStore read), so wait for
		-- it before building the rod; default to Bamboo after 5 seconds.
		local data = nil
		for _ = 1, 50 do
			data = DataService.GetData(player)
			if data then
				break
			end
			task.wait(0.1)
		end
		RodToolService.EquipRod(player)
		-- A fresh spawn always starts with the rod in hand.
		holstered[player] = nil
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Unequipped:Connect(function(tool)
			if tool:GetAttribute("RodTool") and not holstered[player] then
				-- The rod is the character's identity in a fishing game:
				-- put it back in hand if the player toggles it off, unless
				-- they deliberately holstered it (H key / HOLSTER button).
				task.wait(0.3)
				local backpack = player:FindFirstChild("Backpack")
				if tool.Parent == backpack and character.Parent and not holstered[player] then
					RodToolService.EquipRod(player)
				end
			end
		end)
	end
	local function OnPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			OnCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(OnCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(OnPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		holstered[player] = nil
	end)
end

return RodToolService
