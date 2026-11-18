-- TankService: the aquarium. Places caught fish into glass tanks on the player's
-- base plot, builds the tank visuals (glass, water, swimming 3D fish, name +
-- rarity + $/s label, steal prompt), and sells overflow when tanks are full.
-- Functions: AddFishToTank, RemoveFishFromTank, GetTankCount, SellOverflowFish,
-- RebuildPlayerTanks, ClearPlayerTanks, SetLockVisual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local FishModelFactory = require(script.Parent:WaitForChild("FishModelFactory"))

local TankService = {}

-- tankVisuals[player] = array of { Folder, FishModel, Label lines, Prompt,
-- LockPart, Center, Angle, Radius, Speed, BobPhase, Mutation, FishId }
local tankVisuals = {}

local function GetTankCenter(player, tankIndex)
	local data = DataService.GetData(player)
	if not data then
		return Vector3.new(0, 2, 48)
	end
	local plotCenter = GameConfig.BasePlots[data.PlotIndex] or GameConfig.BasePlots[1]
	local anchor = GameConfig.TankAnchors[tankIndex] or Vector3.new(0, 0, 0)
	-- +3.75: the glass bottom (center - 1.95) sits on the 1.8-stud display
	-- table in the house base. The old +1.9 put the tank on the floor.
	return plotCenter + anchor + Vector3.new(0, 3.75, 0)
end

-- The farthest any part of a voxel model reaches from its pivot, in XZ.
-- Voxel fish have no single "Body" part to measure, and the nose, tail
-- and accessories stick out past the body block — so measure the real
-- silhouette: for every part, the farthest corner from the pivot. Model
-- parts are axis-aligned, so the 4 XZ corners are exact.
local function GetModelReach(model)
	local pivot = model:GetPivot().Position
	local reach = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local rel = part.Position - pivot
			local hx, hz = part.Size.X / 2, part.Size.Z / 2
			for _, cx in ipairs({ -hx, hx }) do
				for _, cz in ipairs({ -hz, hz }) do
					local dx, dz = rel.X + cx, rel.Z + cz
					reach = math.max(reach, math.sqrt(dx * dx + dz * dz))
				end
			end
		end
	end
	return reach
end

-- Keeps the plot's owner sign showing the live tank count ("Tanks: 2/3").
-- The sign was only set on join, so it read 0/3 forever after the first catch.
local function UpdatePlotSign(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local world = game:GetService("Workspace"):FindFirstChild("BrainrotFishingWorld")
	local plot = world and world:FindFirstChild("BasePlot" .. data.PlotIndex)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("SignLabel")
	local sub = gui and gui:FindFirstChild("Subtitle")
	if sub then
		sub.Text = "Tanks: " .. #data.Tanks .. "/" .. data.TankSlots
	end
end

local function BuildTankLabel(glass, fishId, mutation, income, tankIndex)
	local def = FishDefinitions.Fish[fishId]
	local gui = Instance.new("BillboardGui")
	gui.Name = "TankLabel"
	-- Compact two-line label (was 150x72 with three lines): at 11/11 tanks
	-- the old labels were wider than the gap between tanks and stacked into
	-- an unreadable jumble (playtest 19 Nov). Line 1 = name, line 2 =
	-- rarity + $/s. The lock state is NOT in the label anymore — the gold
	-- padlock block on top of the tank already shows it.
	gui.Size = UDim2.fromOffset(130, 44)
	-- Stagger by GRID position, not tank index: row = (index-1)//4, col =
	-- (index-1)%4, height = heights[(row+col)%3+1]. The old index%3 stagger
	-- repeated every 3 tanks, so tanks in adjacent rows shared a height and
	-- still collided on screen. With (row+col)%3, any two tanks that share
	-- a row or a column always sit at different heights.
	local row = math.floor((tankIndex - 1) / 4)
	local col = (tankIndex - 1) % 4
	local labelHeights = { 2.6, 3.7, 4.8 }
	gui.StudsOffset = Vector3.new(0, labelHeights[(row + col) % 3 + 1], 0)
	gui.MaxDistance = 35
	gui.AlwaysOnTop = true
	gui.Parent = glass

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLine"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = gui

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLine"
	infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
	infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
	infoLabel.BackgroundTransparency = 1
	local infoText = def.Rarity:upper()
	if mutation == "Golden" then
		infoText = "GOLDEN " .. infoText
	elseif mutation == "Rainbow" then
		infoText = "RAINBOW " .. infoText
	end
	infoText = infoText .. " · $" .. income .. "/s"
	infoLabel.Text = infoText
	infoLabel.TextColor3 = FishDefinitions.RarityColors[def.Rarity]
	infoLabel.TextSize = 12
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextStrokeTransparency = 0.3
	infoLabel.Parent = gui

	return gui
end

-- Builds one tank's visuals at its anchor: glass box, water, fish, label, prompt.
local function CreateTankVisual(player, tankIndex, tank)
	local center = GetTankCenter(player, tankIndex)
	local def = FishDefinitions.Fish[tank.FishId]
	local income = def and def.Income or 0
	if tank.Mutation == "Golden" then
		income = income * GameConfig.MutationMultipliers.Golden
	elseif tank.Mutation == "Rainbow" then
		income = income * GameConfig.MutationMultipliers.Rainbow
	end
	local data = DataService.GetData(player)
	local locked = data and data.LockUntil > os.clock() or false

	local folder = Instance.new("Folder")
	folder.Name = "Tank" .. tankIndex
	folder.Parent = game:GetService("Workspace"):FindFirstChild("BrainrotFishingWorld")

	-- Bigger tanks (5 x 4.5 x 5) for the bigger 1.9x fish: the old 4.2-stud
	-- tanks made every fish look small from a few steps away.
	local glass = Instance.new("Part")
	glass.Name = "TankGlass"
	glass.Size = Vector3.new(5, 4.5, 5)
	glass.Position = center + Vector3.new(0, 0.3, 0)
	glass.Color = Color3.fromRGB(200, 230, 255)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.6
	glass.Anchored = true
	glass.CanCollide = false
	glass.Parent = folder

	-- A Neon rim around the glass top edge in the fish's rarity color
	-- (gold for a Golden mutation, white for Rainbow): a row of bases
	-- reads as a rainbow from across the lake, and a thief can spot a
	-- Mythic tank at a glance. The X-rims are 4.8 long so their ends
	-- meet the Z-rims' inner faces exactly (no overlap, no z-fight).
	local rimColor = def and FishDefinitions.RarityColors[def.Rarity] or Color3.fromRGB(200, 200, 200)
	if tank.Mutation == "Golden" then
		rimColor = Color3.fromRGB(255, 210, 60)
	elseif tank.Mutation == "Rainbow" then
		rimColor = Color3.fromRGB(255, 255, 255)
	end
	local rim = Instance.new("Folder")
	rim.Name = "RarityRim"
	rim.Parent = folder
	for _, z in ipairs({ -2.5, 2.5 }) do
		local edge = Instance.new("Part")
		edge.Name = "RimX"
		edge.Size = Vector3.new(4.8, 0.15, 0.2)
		edge.Position = center + Vector3.new(0, 2.475, z)
		edge.Color = rimColor
		edge.Material = Enum.Material.Neon
		edge.Anchored = true
		edge.CanCollide = false
		edge.Parent = rim
	end
	for _, x in ipairs({ -2.5, 2.5 }) do
		local edge = Instance.new("Part")
		edge.Name = "RimZ"
		edge.Size = Vector3.new(0.2, 0.15, 5.4)
		edge.Position = center + Vector3.new(x, 2.475, 0)
		edge.Color = rimColor
		edge.Material = Enum.Material.Neon
		edge.Anchored = true
		edge.CanCollide = false
		edge.Parent = rim
	end

	local water = Instance.new("Part")
	water.Name = "TankWater"
	water.Size = Vector3.new(4.7, 3.9, 4.7)
	water.Position = center + Vector3.new(0, 0.1, 0)
	water.Color = Color3.fromRGB(60, 170, 220)
	water.Material = Enum.Material.SmoothPlastic
	water.Transparency = 0.35
	water.Anchored = true
	water.CanCollide = false
	water.Parent = folder

	local fishModel = FishModelFactory.BuildFishModel(tank.FishId, tank.Mutation)
	if fishModel then
		fishModel.Parent = folder
		fishModel:PivotTo(CFrame.new(center))
	end
	-- Swim radius from the fish's real silhouette (nose/tail/accessories),
	-- so long fish (eels, Naga, the croc) stay inside the glass instead of
	-- poking through it when they turn. 2.5 is the half-width of the
	-- 5-stud tank; 0.1 is clearance for the glass.
	local swimRadius = 0.45
	if fishModel then
		swimRadius = math.clamp(2.5 - GetModelReach(fishModel) - 0.1, 0.12, 0.55)
	end

	local label = BuildTankLabel(glass, tank.FishId, tank.Mutation, income, tankIndex)

	-- Gold padlock block on top of the tank, visible while the base is locked.
	local lockPart = Instance.new("Part")
	lockPart.Name = "LockIndicator"
	lockPart.Size = Vector3.new(0.7, 0.7, 0.25)
	lockPart.Position = center + Vector3.new(0, 3, 0)
	lockPart.Color = Color3.fromRGB(255, 210, 60)
	lockPart.Material = Enum.Material.Neon
	lockPart.Anchored = true
	lockPart.CanCollide = false
	lockPart.Transparency = locked and 0 or 1
	lockPart.Parent = folder

	-- Steal prompt (server handles the hold; thieves only, unlocked tanks only).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal Fish"
	prompt.ObjectText = def and def.Name or "Fish"
	prompt.HoldDuration = GameConfig.StealHoldSeconds
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not locked
	prompt.Parent = glass
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt:SetAttribute("TankIndex", tankIndex)

	return {
		Folder = folder,
		FishModel = fishModel,
		Label = label,
		Prompt = prompt,
		LockPart = lockPart,
		Center = center,
		Angle = math.random() * math.pi * 2,
		Radius = swimRadius,
		Speed = 0.5 + math.random() * 0.4,
		BobPhase = math.random() * math.pi * 2,
		Mutation = tank.Mutation,
		FishId = tank.FishId,
	}
end

-- Rebuilds every tank visual for a player from their data (used on join and
-- after any removal, so tank order always matches the data).
function TankService.RebuildPlayerTanks(player)
	TankService.ClearPlayerTanks(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local visuals = {}
	for i, tank in ipairs(data.Tanks) do
		visuals[i] = CreateTankVisual(player, i, tank)
	end
	tankVisuals[player] = visuals
	UpdatePlotSign(player)
end

-- Destroys all tank visuals for a player (used on leave and before a rebuild).
function TankService.ClearPlayerTanks(player)
	local visuals = tankVisuals[player]
	if visuals then
		for _, visual in ipairs(visuals) do
			if visual.Folder then
				visual.Folder:Destroy()
			end
		end
	end
	tankVisuals[player] = nil
end

function TankService.GetTankCount(player)
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	return #data.Tanks
end

-- Sells a fish for $/s x 100 (tank-full overflow or a full thief tank).
function TankService.SellOverflowFish(player, fishId, mutation)
	local def = FishDefinitions.Fish[fishId]
	if not def then
		return 0
	end
	local income = def.Income
	if mutation == "Golden" then
		income = income * GameConfig.MutationMultipliers.Golden
	elseif mutation == "Rainbow" then
		income = income * GameConfig.MutationMultipliers.Rainbow
	end
	return income * GameConfig.OverflowSellMultiplier
end

-- Adds a fish to the first free tank. Returns "added" or "sold" + sale value.
function TankService.AddFishToTank(player, fishId, mutation)
	local data = DataService.GetData(player)
	if not data then
		return "failed", 0
	end
	if #data.Tanks >= data.TankSlots then
		return "sold", TankService.SellOverflowFish(player, fishId, mutation)
	end
	table.insert(data.Tanks, { FishId = fishId, Mutation = mutation })
	local visuals = tankVisuals[player] or {}
	visuals[#data.Tanks] = CreateTankVisual(player, #data.Tanks, data.Tanks[#data.Tanks])
	tankVisuals[player] = visuals
	UpdatePlotSign(player)
	return "added", 0
end

-- Removes the fish at tankIndex (steal / monster raid). Returns its data.
function TankService.RemoveFishFromTank(player, tankIndex)
	local data = DataService.GetData(player)
	if not data or not data.Tanks[tankIndex] then
		return nil
	end
	local removed = data.Tanks[tankIndex]
	table.remove(data.Tanks, tankIndex)
	TankService.RebuildPlayerTanks(player)
	return removed
end

-- Returns the tank index holding the player's cheapest fish (for monster raids).
function TankService.GetCheapestTankIndex(player)
	local data = DataService.GetData(player)
	if not data or #data.Tanks == 0 then
		return nil
	end
	local cheapestIndex = 1
	local cheapestIncome = math.huge
	for i, tank in ipairs(data.Tanks) do
		local def = FishDefinitions.Fish[tank.FishId]
		local income = def and def.Income or 0
		if tank.Mutation == "Golden" then
			income = income * GameConfig.MutationMultipliers.Golden
		elseif tank.Mutation == "Rainbow" then
			income = income * GameConfig.MutationMultipliers.Rainbow
		end
		if income < cheapestIncome then
			cheapestIncome = income
			cheapestIndex = i
		end
	end
	return cheapestIndex
end

-- Shows or hides the lock visuals on all of a player's tanks. The label no
-- longer carries [LOCKED] (fix 13) — the gold padlock block is the indicator.
function TankService.SetLockVisual(player, locked)
	local visuals = tankVisuals[player]
	if not visuals then
		return
	end
	for _, visual in ipairs(visuals) do
		if visual.LockPart then
			visual.LockPart.Transparency = locked and 0 or 1
		end
		if visual.Prompt then
			visual.Prompt.Enabled = not locked
		end
	end
end

-- Returns the world position of a player's tank (for steal distance checks).
function TankService.GetTankPosition(player, tankIndex)
	return GetTankCenter(player, tankIndex)
end

-- Returns the world position of a player's base plot (for monster guard checks).
function TankService.GetBasePosition(player)
	local data = DataService.GetData(player)
	if not data then
		return Vector3.new(0, 0, 48)
	end
	return GameConfig.BasePlots[data.PlotIndex] or GameConfig.BasePlots[1]
end

-- One shared heartbeat: every tank fish swims a slow circle and bobs.
-- Rainbow fish cycle their body hue.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator = accumulator + dt
	if accumulator < 0.08 then
		return
	end
	local step = accumulator
	accumulator = 0
	for _, visuals in pairs(tankVisuals) do
		for _, visual in ipairs(visuals) do
			local model = visual.FishModel
			if model and model.PrimaryPart then
				visual.Angle = visual.Angle + visual.Speed * step
				local x = math.cos(visual.Angle) * visual.Radius
				local z = math.sin(visual.Angle) * visual.Radius * 0.6
				local y = math.sin(os.clock() * 1.5 + visual.BobPhase) * 0.15
				local yaw = -visual.Angle - math.pi / 2
				model:PivotTo(CFrame.new(visual.Center + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0))
				if visual.Mutation == "Rainbow" then
					-- The body shimmers; fins and accessories keep their
					-- colors. Every body run is named Body* (BodyMid,
					-- BodyNose, BodyLog, BodyCroc, ...).
					local hue = Color3.fromHSV((os.clock() * 0.15 + visual.BobPhase) % 1, 0.75, 1)
					for _, part in ipairs(model:GetDescendants()) do
						if part:IsA("BasePart") and part.Name:sub(1, 4) == "Body" then
							part.Color = hue
						end
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	TankService.ClearPlayerTanks(player)
end)

return TankService
