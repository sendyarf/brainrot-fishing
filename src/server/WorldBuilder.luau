-- WorldBuilder — builds the whole 3D lake world out of Parts at server
-- start: the lake, the shore, the wooden dock with lanterns, the three
-- fishing spots plus the Royal Pond, the eight base plots, trees, rocks,
-- a boat, and the giant lake monster (hidden until its event). The
-- sunset lighting is set here too. Everything is anchored and built
-- before the first player spawns, so nobody falls through the world.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local WorldBuilder = {}

local monsterModel = nil
local leaderboardSurface = nil

local function makePart(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = workspace
	return part
end

local function makeWater()
	local lake = makePart("Lake", GameConfig.WORLD.lakeSize, GameConfig.WORLD.lakeCenter,
		Color3.fromRGB(45, 130, 170), Enum.Material.Water)
	lake.CanCollide = false
	lake.Transparency = 0.15
	return lake
end

local function makeShore()
	makePart("Shore", GameConfig.WORLD.shoreSize, GameConfig.WORLD.shoreCenter,
		Color3.fromRGB(200, 180, 130), Enum.Material.Sand)
	-- A grassy strip where the bases sit.
	makePart("GrassStrip", Vector3.new(220, 1, 30), Vector3.new(0, -1.2, 38),
		Color3.fromRGB(110, 160, 80), Enum.Material.Grass)
end

local function makeDock()
	-- Main dock: wooden planks from the shore into the lake.
	for i = 0, 14 do
		makePart("DockPlank", Vector3.new(6, 0.5, 3), Vector3.new(0, 0.8, 18 - i * 3),
			Color3.fromRGB(140, 100, 60), Enum.Material.WoodPlanks)
	end
	-- Support posts under the dock.
	for i = 0, 4 do
		makePart("DockPost", Vector3.new(0.6, 4, 0.6), Vector3.new(-2.5, -1, 15 - i * 9),
			Color3.fromRGB(110, 80, 45), Enum.Material.Wood)
		makePart("DockPost", Vector3.new(0.6, 4, 0.6), Vector3.new(2.5, -1, 15 - i * 9),
			Color3.fromRGB(110, 80, 45), Enum.Material.Wood)
	end
	-- Lanterns along the dock: warm light for the sunset mood.
	for i = 0, 3 do
		local z = 12 - i * 12
		local post = makePart("LanternPost", Vector3.new(0.4, 3, 0.4), Vector3.new(3.2, 2.5, z),
			Color3.fromRGB(90, 70, 40), Enum.Material.Wood)
		local lamp = makePart("LanternLamp", Vector3.new(0.8, 0.8, 0.8), Vector3.new(3.2, 4.2, z),
			Color3.fromRGB(255, 200, 100), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 90)
		light.Range = 12
		light.Brightness = 2
		light.Parent = lamp
	end
	-- Spawn location on the dock, facing the lake.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DockSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = GameConfig.WORLD.spawnPosition
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(140, 100, 60)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = workspace
end

-- A wooden sign board with text on its face. SurfaceGui sits ON the face,
-- so the board can never occlude its own text (unlike a centred BillboardGui).
local function makeSignBoard(position, title, lines, width, height)
	width = width or 7
	height = height or 3.6
	local board = makePart("SignBoard", Vector3.new(width, height, 0.3), position,
		Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	local post = makePart("SignPost", Vector3.new(0.5, 2.5, 0.5),
		position + Vector3.new(0, -height / 2 - 1.2, 0), Color3.fromRGB(100, 70, 40), Enum.Material.Wood)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.3, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 34
	titleLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
	titleLabel.Text = title
	titleLabel.Parent = gui

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "BoardText"
	bodyLabel.Size = UDim2.new(1, 0, 0.7, 0)
	bodyLabel.Position = UDim2.new(0, 0, 0.3, 0)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextSize = 24
	bodyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bodyLabel.TextWrapped = true
	bodyLabel.Text = table.concat(lines, "\n")
	bodyLabel.Parent = gui

	return gui
end

local function makeSpotMarkers()
	-- Shallow Shore sign at the dock's shore end.
	makeSignBoard(Vector3.new(-5, 3.5, 16), "SHALLOW SHORE",
		{ "Free fishing", "Common fish live here" }, 6, 3)
	-- Deep Dock sign at the dock's far end.
	makeSignBoard(Vector3.new(-5, 3.5, -28), "DEEP DOCK",
		{ "$500 to unlock", "Better odds, deeper fish" }, 6, 3)
	-- Abyss Point: a small island with a wooden bridge.
	local island = makePart("AbyssIsland", Vector3.new(16, 2, 16), Vector3.new(-62, -1, -52),
		Color3.fromRGB(150, 140, 110), Enum.Material.Rock)
	for i = 0, 9 do
		makePart("BridgePlank", Vector3.new(2.5, 0.4, 2.5),
			Vector3.new(-8 - i * 5.5, 0.8, -30 - i * 2.2), Color3.fromRGB(140, 100, 60), Enum.Material.WoodPlanks)
	end
	makeSignBoard(Vector3.new(-62, 3.5, -48), "ABYSS POINT",
		{ "$2,500 to unlock", "Rare fish gather here" }, 6, 3)
	-- Royal Pond: a small glowing pond on its own island.
	local royalIsland = makePart("RoyalIsland", Vector3.new(14, 2, 14), Vector3.new(62, -1, -58),
		Color3.fromRGB(160, 150, 120), Enum.Material.Rock)
	local pond = makePart("RoyalPondWater", Vector3.new(9, 1, 9), Vector3.new(62, 0.2, -58),
		Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	pond.CanCollide = false
	local pondLight = Instance.new("PointLight")
	pondLight.Color = Color3.fromRGB(120, 220, 255)
	pondLight.Range = 18
	pondLight.Brightness = 2
	pondLight.Parent = pond
	makeSignBoard(Vector3.new(62, 3.5, -52), "ROYAL POND",
		{ "Rebirth to unlock", "Mythic fish live here" }, 6, 3)
end

local function makeBasePlots()
	for _, plot in ipairs(GameConfig.WORLD.basePlots) do
		-- A low wooden fence around each base plot.
		local fence = makePart("BaseFence", Vector3.new(24, 1, 0.4), plot + Vector3.new(0, 0.5, -7),
			Color3.fromRGB(130, 95, 55), Enum.Material.Wood)
		makePart("BaseFence", Vector3.new(0.4, 1, 14), plot + Vector3.new(-12, 0.5, 0),
			Color3.fromRGB(130, 95, 55), Enum.Material.Wood)
		makePart("BaseFence", Vector3.new(0.4, 1, 14), plot + Vector3.new(12, 0.5, 0),
			Color3.fromRGB(130, 95, 55), Enum.Material.Wood)
		-- A stone floor under the tanks.
		makePart("BaseFloor", Vector3.new(24, 0.5, 14), plot + Vector3.new(0, 0.1, 0),
			Color3.fromRGB(160, 155, 145), Enum.Material.Slate)
	end
end

local function makeDecorations()
	-- Trees on the shore.
	local treeSpots = {
		Vector3.new(-40, 0, 70), Vector3.new(-70, 0, 65), Vector3.new(30, 0, 72),
		Vector3.new(70, 0, 68), Vector3.new(-100, 0, 60), Vector3.new(100, 0, 62),
	}
	for _, spot in ipairs(treeSpots) do
		makePart("TreeTrunk", Vector3.new(1.2, 6, 1.2), spot + Vector3.new(0, 3, 0),
			Color3.fromRGB(110, 80, 45), Enum.Material.Wood)
		local leaves = makePart("TreeLeaves", Vector3.new(5, 5, 5), spot + Vector3.new(0, 8, 0),
			Color3.fromRGB(70, 140, 60), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
	end
	-- Rocks near the water.
	for _, spot in ipairs({ Vector3.new(-20, 0, 20), Vector3.new(45, 0, 25), Vector3.new(-55, 0, 15) }) do
		local rock = makePart("Rock", Vector3.new(3, 2, 3), spot, Color3.fromRGB(140, 140, 140), Enum.Material.Rock)
		rock.Shape = Enum.PartType.Ball
	end
	-- A wooden rowboat floating near the dock.
	local boat = makePart("Boat", Vector3.new(3, 1, 7), Vector3.new(10, 0.3, -15),
		Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	makePart("BoatSeat", Vector3.new(2.6, 0.3, 1), Vector3.new(10, 0.7, -15),
		Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
end

-- The giant lake monster: a huge shadow, fins and glowing eyes under the
-- water. It starts invisible and surfaces during the event. It is BIG
-- (30+ studs) and NEAR the dock (~60 studs) so players can actually see it.
local function makeMonster()
	local model = Instance.new("Model")
	model.Name = "LakeMonster"

	local shadow = Instance.new("Part")
	shadow.Name = "Shadow"
	shadow.Size = Vector3.new(34, 3, 14)
	shadow.Position = GameConfig.WORLD.monsterPosition
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Color = Color3.fromRGB(20, 40, 30)
	shadow.Transparency = 1
	shadow.Parent = model

	local fin = Instance.new("Part")
	fin.Name = "Fin"
	fin.Size = Vector3.new(6, 7, 1)
	fin.Position = GameConfig.WORLD.monsterPosition + Vector3.new(0, 4, 0)
	fin.Anchored = true
	fin.CanCollide = false
	fin.Material = Enum.Material.SmoothPlastic
	fin.Color = Color3.fromRGB(40, 140, 70)
	fin.Transparency = 1
	fin.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(2.5, 2.5, 2.5)
		eye.Shape = Enum.PartType.Ball
		eye.Position = GameConfig.WORLD.monsterPosition + Vector3.new(10, 4, side * 4)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 60, 60)
		eye.Transparency = 1
		eye.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 60, 60)
		light.Range = 25
		light.Brightness = 3
		light.Enabled = false
		light.Parent = eye
	end

	model.Parent = workspace
	monsterModel = model
	return model
end

local function makeQuestAndLeaderboardBoards()
	makeSignBoard(GameConfig.WORLD.questBoardPosition + Vector3.new(0, 3.5, 0), "QUEST BOARD",
		{ "Catch 5 fish: $150", "Earn $1,000: $300", "Catch a Rare+: $500" }, 7, 3.6)
	leaderboardSurface = makeSignBoard(GameConfig.WORLD.leaderboardPosition + Vector3.new(0, 3.5, 0),
		"TOP ANGLERS", { "No anglers yet!" }, 7, 3.6)
end

function WorldBuilder.BuildWorld()
	-- Sunset lighting: warm orange-purple sky, soft fog.
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 17.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(102, 76, 89)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 102, 115)
	Lighting.FogColor = Color3.fromRGB(200, 150, 130)
	Lighting.FogEnd = 300
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Voxel

	makeWater()
	makeShore()
	makeDock()
	makeSpotMarkers()
	makeBasePlots()
	makeDecorations()
	makeMonster()
	makeQuestAndLeaderboardBoards()
end

function WorldBuilder.GetMonsterModel()
	return monsterModel
end

function WorldBuilder.GetLeaderboardSurface()
	return leaderboardSurface
end

return WorldBuilder
