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
	return plotCenter + anchor + Vector3.new(0, 1.9, 0)
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

local function BuildTankLabel(glass, fishId, mutation, income, locked, tankIndex)
	local def = FishDefinitions.Fish[fishId]
	local gui = Instance.new("BillboardGui")
	gui.Name = "TankLabel"
	gui.Size = UDim2.fromOffset(150, 72)
	-- Three staggered label heights, so neighbouring tanks never collide
	-- even when five tanks in a row are viewed at an angle (the old two
	-- heights still stacked into an unreadable jumble). Labels are narrower
	-- too: at 5.2-stud tank spacing, a 180px label is wider than the gap
	-- between two tanks on screen.
	local labelHeights = { 2.6, 3.5, 4.4 }
	gui.StudsOffset = Vector3.new(0, labelHeights[(tankIndex - 1) % 3 + 1], 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = true
	gui.Parent = glass

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLine"
	nameLabel.Size = UDim2.new(1, 0, 0.38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 17
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLine"
	rarityLabel.Position = UDim2.new(0, 0, 0.38, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.31, 0)
	rarityLabel.BackgroundTransparency = 1
	local rarityText = def.Rarity:upper()
	if mutation == "Golden" then
		rarityText = "GOLDEN " .. rarityText
	elseif mutation == "Rainbow" then
		rarityText = "RAINBOW " .. rarityText
	end
	if locked then
		rarityText = rarityText .. "  [LOCKED]"
	end
	rarityLabel.Text = rarityText
	rarityLabel.TextColor3 = FishDefinitions.RarityColors[def.Rarity]
	rarityLabel.TextSize = 14
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Parent = gui

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLine"
	incomeLabel.Position = UDim2.new(0, 0, 0.69, 0)
	incomeLabel.Size = UDim2.new(1, 0, 0.31, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "$" .. income .. "/s"
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
	incomeLabel.TextSize = 15
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextStrokeTransparency = 0.3
	incomeLabel.Parent = gui

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
	-- Swim radius from the fish's body length, so long fish (eels, Naga)
	-- stay inside the glass instead of poking through it. 2.5 is the
	-- half-width of the 5-stud tank.
	local swimRadius = 0.45
	if fishModel then
		local body = fishModel:FindFirstChild("Body")
		if body then
			swimRadius = math.clamp(2.5 - math.max(body.Size.X, body.Size.Z) / 2, 0.12, 0.55)
		end
	end

	local label = BuildTankLabel(glass, tank.FishId, tank.Mutation, income, locked, tankIndex)

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

-- Shows or hides the lock visuals on all of a player's tanks.
function TankService.SetLockVisual(player, locked)
	local visuals = tankVisuals[player]
	if not visuals then
		return
	end
	local data = DataService.GetData(player)
	for i, visual in ipairs(visuals) do
		if visual.LockPart then
			visual.LockPart.Transparency = locked and 0 or 1
		end
		if visual.Prompt then
			visual.Prompt.Enabled = not locked
		end
		if visual.Label and data and data.Tanks[i] then
			local tank = data.Tanks[i]
			local def = FishDefinitions.Fish[tank.FishId]
			local rarityLine = visual.Label:FindFirstChild("RarityLine")
			if rarityLine and def then
				local text = def.Rarity:upper()
				if tank.Mutation == "Golden" then
					text = "GOLDEN " .. text
				elseif tank.Mutation == "Rainbow" then
					text = "RAINBOW " .. text
				end
				if locked then
					text = text .. "  [LOCKED]"
				end
				rarityLine.Text = text
			end
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
					local body = model:FindFirstChild("Body")
					if body then
						body.Color = Color3.fromHSV((os.clock() * 0.15 + visual.BobPhase) % 1, 0.75, 1)
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
