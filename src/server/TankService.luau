-- TankService — the player's aquarium base: tank placement, fish display
-- and tank labels. Each player owns a plot on the shore; their caught fish
-- swim in glass tanks there, one fish per tank, each labelled with its
-- name, rarity and $/s. A full tank sells the new catch for cash instead.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local FishDefinitions = require(game:GetService("ReplicatedStorage").Shared.FishDefinitions)
local FishModelFactory = require(game:GetService("ReplicatedStorage").Shared.FishModelFactory)

local TankService = {}

local dataService = nil
local economyService = nil
local notifyEvent = nil

-- [userId] = { plotPosition, tanks = { [index] = tankModel } }
local playerBases = {}

local TANK_SIZE = Vector3.new(4, 3, 3)
local TANK_SPACING_X = 5
local TANK_SPACING_Z = 4
local TANKS_PER_ROW = 4

function TankService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	notifyEvent = deps.Notify
end

-- Where tank number `index` (1-based) sits inside a base plot.
local function tankPositionForIndex(plotPosition, index)
	local row = math.floor((index - 1) / TANKS_PER_ROW)
	local col = (index - 1) % TANKS_PER_ROW
	return plotPosition + Vector3.new((col - 1.5) * TANK_SPACING_X, 1.5, row * TANK_SPACING_Z)
end

-- Builds one glass tank shell (no fish yet) at a position. The tank is
-- tagged with its owner's UserId so the steal prompt on the client can
-- tell the server exactly whose tank it is (guessing by proximity fails
-- whenever the owner is away fishing).
local function buildTankShell(position, tankIndex, ownerUserId)
	local tank = Instance.new("Model")
	tank.Name = "Tank" .. tankIndex

	local ownerTag = Instance.new("IntValue")
	ownerTag.Name = "OwnerUserId"
	ownerTag.Value = ownerUserId or 0
	ownerTag.Parent = tank

	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = TANK_SIZE
	glass.Position = position
	glass.Anchored = true
	glass.CanCollide = true
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.6
	glass.Color = Color3.fromRGB(170, 220, 240)
	glass.Parent = tank

	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(TANK_SIZE.X - 0.3, TANK_SIZE.Y - 1.2, TANK_SIZE.Z - 0.3)
	water.Position = position + Vector3.new(0, -0.4, 0)
	water.Anchored = true
	water.CanCollide = false
	water.Material = Enum.Material.Water
	water.Transparency = 0.3
	water.Color = Color3.fromRGB(60, 150, 200)
	water.Parent = tank

	local frame = Instance.new("Part")
	frame.Name = "Frame"
	frame.Size = Vector3.new(TANK_SIZE.X + 0.4, 0.4, TANK_SIZE.Z + 0.4)
	frame.Position = position + Vector3.new(0, -TANK_SIZE.Y / 2 - 0.1, 0)
	frame.Anchored = true
	frame.CanCollide = true
	frame.Material = Enum.Material.Wood
	frame.Color = Color3.fromRGB(120, 85, 50)
	frame.Parent = tank

	tank.PrimaryPart = glass
	return tank
end

-- The label above a tank: name, rarity, $/s. AlwaysOnTop so the glass
-- never eats its own text (a BillboardGui sits at the part's centre).
local function buildTankLabel(tank, fishEntry)
	local fish = FishDefinitions.GetFishById(fishEntry.fishId)
	if not fish then
		return
	end
	local income = economyService.GetFishIncome(fishEntry)

	local gui = Instance.new("BillboardGui")
	gui.Name = "TankLabel"
	gui.Adornee = tank.PrimaryPart
	gui.Size = UDim2.new(0, 220, 0, 80)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0.2
	title.Text = fish.name
	title.Parent = gui

	local rarity = Instance.new("TextLabel")
	rarity.Size = UDim2.new(1, 0, 0.3, 0)
	rarity.Position = UDim2.new(0, 0, 0.4, 0)
	rarity.BackgroundTransparency = 1
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 16
	rarity.TextColor3 = FishDefinitions.GetRarityColor(fish.rarity)
	rarity.TextStrokeTransparency = 0.2
	local mutationTag = ""
	if fishEntry.mutation == "golden" then
		mutationTag = "GOLDEN "
	elseif fishEntry.mutation == "rainbow" then
		mutationTag = "RAINBOW "
	end
	rarity.Text = mutationTag .. string.upper(fish.rarity)
	rarity.Parent = gui

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.new(1, 0, 0.3, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.7, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextSize = 18
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
	incomeLabel.TextStrokeTransparency = 0.2
	incomeLabel.Text = "$" .. income .. "/s"
	incomeLabel.Parent = gui

	gui.Parent = tank
end

-- Creates the player's base plot (empty tank shells for owned slots).
function TankService.SetupBase(player, plotPosition)
	local base = {
		plotPosition = plotPosition,
		tanks = {},
	}
	playerBases[player.UserId] = base

	local data = dataService.GetData(player)
	local slotCount = data and data.tankSlots or GameConfig.STARTING_TANK_SLOTS
	for i = 1, slotCount do
		local tank = buildTankShell(tankPositionForIndex(plotPosition, i), i, player.UserId)
		tank.Parent = workspace
		base.tanks[i] = tank
	end

	-- Fill tanks from the player's saved fish.
	if data then
		for index, fishEntry in ipairs(data.fish) do
			TankService.DisplayFishInTank(player, index, fishEntry)
		end
	end
end

-- Puts a fish model + label into tank `index` of the player's base.
function TankService.DisplayFishInTank(player, index, fishEntry)
	local base = playerBases[player.UserId]
	if not base then
		return
	end
	local tank = base.tanks[index]
	if not tank then
		return
	end
	-- Clear any previous fish display in this tank.
	for _, child in ipairs(tank:GetChildren()) do
		if child:IsA("Model") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
	local fishPosition = tank.PrimaryPart.Position
	local model = FishModelFactory.BuildFishModel(fishEntry.fishId, fishEntry.mutation, CFrame.new(fishPosition))
	if model then
		model.Parent = tank
	end
	buildTankLabel(tank, fishEntry)
end

-- Adds a fish to the first empty tank. Returns true, or false + sale price
-- when the tanks are full (the catch is sold for cash instead).
function TankService.AddFishToTank(player, fishEntry)
	local data = dataService.GetData(player)
	if not data then
		return false, 0
	end
	if #data.fish >= data.tankSlots then
		local salePrice = economyService.GetFishIncome(fishEntry) * GameConfig.TANK_FULL_SELL_MULTIPLIER
		return false, salePrice
	end
	table.insert(data.fish, fishEntry)
	TankService.DisplayFishInTank(player, #data.fish, fishEntry)
	return true, 0
end

-- Removes the fish at `index` from the player's tanks (steal / monster raid).
function TankService.RemoveFishFromTank(player, index)
	local data = dataService.GetData(player)
	if not data or not data.fish[index] then
		return nil
	end
	local removed = table.remove(data.fish, index)
	-- Re-display every tank after the gap so labels stay in order.
	for i = index, #data.fish do
		TankService.DisplayFishInTank(player, i, data.fish[i])
	end
	-- Clear the now-empty last tank.
	local base = playerBases[player.UserId]
	if base and base.tanks[#data.fish + 1] then
		local tank = base.tanks[#data.fish + 1]
		for _, child in ipairs(tank:GetChildren()) do
			if child:IsA("Model") or child:IsA("BillboardGui") then
				child:Destroy()
			end
		end
	end
	return removed
end

-- Adds one more tank shell when the player buys a slot.
function TankService.AddTankSlot(player)
	local base = playerBases[player.UserId]
	if not base then
		return
	end
	local data = dataService.GetData(player)
	local slotCount = data and data.tankSlots or 0
	local tank = buildTankShell(tankPositionForIndex(base.plotPosition, slotCount), slotCount, player.UserId)
	tank.Parent = workspace
	base.tanks[slotCount] = tank
end

function TankService.GetTankCount(player)
	local data = dataService.GetData(player)
	return data and #data.fish or 0
end

function TankService.GetBasePosition(player)
	local base = playerBases[player.UserId]
	return base and base.plotPosition or nil
end

function TankService.GetCheapestFishIndex(player)
	local data = dataService.GetData(player)
	if not data or #data.fish == 0 then
		return nil
	end
	local cheapestIndex = 1
	local cheapestIncome = math.huge
	for i, fishEntry in ipairs(data.fish) do
		local income = economyService.GetFishIncome(fishEntry)
		if income < cheapestIncome then
			cheapestIncome = income
			cheapestIndex = i
		end
	end
	return cheapestIndex
end

-- Tears down a player's base when they leave (frees the plot).
function TankService.TeardownBase(player)
	local base = playerBases[player.UserId]
	if not base then
		return
	end
	for _, tank in pairs(base.tanks) do
		if tank then
			tank:Destroy()
		end
	end
	playerBases[player.UserId] = nil
end

return TankService