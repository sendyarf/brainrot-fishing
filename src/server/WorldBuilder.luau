-- WorldBuilder: builds the entire 3D sunset lake world from parts at server start.
-- Rojo-first: no Studio-saved place, everything here is code, so the world is
-- reproducible from the repository alone. One call: WorldBuilder.BuildWorld().

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local WorldBuilder = {}

local monsterParts = {}

-- Creates one anchored part with the given properties.
local function MakePart(parent, name, className, size, position, color, material)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

-- A wooden plank: warm brown, slightly varied so the pier reads as planks.
local function MakePlank(parent, name, size, position, rotationY)
	local part = MakePart(
		parent,
		name,
		"Part",
		size,
		position,
		Color3.fromRGB(165, 120, 70),
		Enum.Material.WoodPlanks
	)
	if rotationY then
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, rotationY, 0)
	end
	return part
end

-- A glowing lantern on a wooden post (warm point light for the sunset mood).
local function MakeLantern(parent, position)
	local post = MakePart(parent, "LanternPost", "Part", Vector3.new(0.5, 4, 0.5), position + Vector3.new(0, 2, 0), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	local lamp = MakePart(parent, "LanternLamp", "Part", Vector3.new(1, 1.2, 1), position + Vector3.new(0, 4.6, 0), Color3.fromRGB(255, 200, 100), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = lamp
	post.CanCollide = false
	return lamp
end

-- A simple colorful tree: brown trunk + 2-3 bright foliage spheres.
local function MakeTree(parent, position, scale, foliageColor)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	tree.Parent = parent
	local trunk = MakePart(tree, "Trunk", "Part", Vector3.new(1.2 * scale, 5 * scale, 1.2 * scale), position + Vector3.new(0, 2.5 * scale, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
	trunk.CanCollide = false
	local leaf1 = MakePart(tree, "Leaves", "Part", Vector3.new(5 * scale, 4 * scale, 5 * scale), position + Vector3.new(0, 6.5 * scale, 0), foliageColor, Enum.Material.SmoothPlastic)
	leaf1.Shape = Enum.PartType.Ball
	leaf1.CanCollide = false
	local leaf2 = MakePart(tree, "LeavesTop", "Part", Vector3.new(3.5 * scale, 3 * scale, 3.5 * scale), position + Vector3.new(0.8 * scale, 9 * scale, 0), foliageColor, Enum.Material.SmoothPlastic)
	leaf2.Shape = Enum.PartType.Ball
	leaf2.CanCollide = false
	return tree
end

-- A grey boulder near the shore.
local function MakeRock(parent, position, scale)
	local rock = MakePart(parent, "Rock", "Part", Vector3.new(2.5 * scale, 1.8 * scale, 2.2 * scale), position, Color3.fromRGB(140, 140, 150), Enum.Material.Slate)
	rock.Shape = Enum.PartType.Ball
	return rock
end

-- A floating sign post with a readable BillboardGui label.
local function MakeSign(parent, position, title, subtitle, titleColor)
	local post = MakePart(parent, "SignPost", "Part", Vector3.new(0.6, 3.4, 0.6), position + Vector3.new(0, 1.7, 0), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	local board = MakePart(parent, "SignBoard", "Part", Vector3.new(4.4, 2.4, 0.3), position + Vector3.new(0, 4.2, 0), Color3.fromRGB(90, 60, 35), Enum.Material.WoodPlanks)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SignLabel"
	-- Size in STUDS (Scale), not pixels: the label is exactly the board's
	-- size (4.4 x 2.4), so the text sits ON the board and shrinks with
	-- distance like the board does. A fromOffset size stays the same pixel
	-- size on screen at any distance, which made every sign a giant wall
	-- of floating text. MaxDistance hides far signs so the horizon stays clean.
	gui.Size = UDim2.new(4.4, 0, 2.4, 0)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = false
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = titleColor or Color3.fromRGB(255, 230, 170)
	titleLabel.TextSize = 30
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.Parent = gui
	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.new(0, 0, 0.55, 0)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = subtitle or ""
	subLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	subLabel.TextSize = 20
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextScaled = true
	subLabel.Parent = gui
	post.CanCollide = false
	board.CanCollide = false
	return board
end

-- Builds the wooden pier from the shore out into the lake, with lanterns.
local function BuildPier(world)
	local pier = Instance.new("Folder")
	pier.Name = "Pier"
	pier.Parent = world
	-- Planks from z = 28 (shore) to z = -66 (deep water), 6 studs wide.
	for z = 28, -66, -4 do
		MakePlank(pier, "PierPlank", Vector3.new(6, 0.6, 3.8), Vector3.new(0, 0.7, z))
	end
	-- Side rails.
	MakePart(pier, "RailLeft", "Part", Vector3.new(0.4, 1, 96), Vector3.new(-3, 1.5, -19), Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
	MakePart(pier, "RailRight", "Part", Vector3.new(0.4, 1, 96), Vector3.new(3, 1.5, -19), Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
	-- Support posts under the pier.
	for z = 24, -64, -16 do
		MakePart(pier, "PierPost", "Part", Vector3.new(0.8, 3, 0.8), Vector3.new(-2.4, -0.5, z), Color3.fromRGB(100, 70, 40), Enum.Material.Wood)
		MakePart(pier, "PierPost", "Part", Vector3.new(0.8, 3, 0.8), Vector3.new(2.4, -0.5, z), Color3.fromRGB(100, 70, 40), Enum.Material.Wood)
	end
	-- Lanterns along the pier.
	for _, z in ipairs({ 24, 0, -24, -48, -64 }) do
		MakeLantern(pier, Vector3.new(-3.4, 1, z))
		MakeLantern(pier, Vector3.new(3.4, 1, z))
	end
	-- Wide platform at the pier end (Deep Dock).
	for x = -4, 4, 4 do
		MakePlank(pier, "DockPlank", Vector3.new(4, 0.6, 10), Vector3.new(x, 0.7, -68))
	end
end

-- Builds the diagonal wooden bridge from the pier to Abyss Island.
local function BuildBridge(world)
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = world
	local startPos = Vector3.new(-3, 0.7, -44)
	local endPos = Vector3.new(-66, 0.7, -90)
	local steps = 16
	for i = 0, steps do
		local t = i / steps
		local pos = startPos:Lerp(endPos, t)
		MakePlank(bridge, "BridgePlank", Vector3.new(4, 0.5, 4.5), pos, math.rad(-45))
	end
	MakeLantern(bridge, Vector3.new(-24, 1, -58))
	MakeLantern(bridge, Vector3.new(-48, 1, -78))
end

-- A small round island with one tree; kind = "Abyss" (dark rock) or "Royal" (glowing pond).
local function BuildIsland(world, center, kind)
	local island = Instance.new("Folder")
	island.Name = kind .. "Island"
	island.Parent = world
	local sand = MakePart(island, "IslandSand", "Part", Vector3.new(1.5, 26, 26), center + Vector3.new(0, 0.2, 0), Color3.fromRGB(230, 210, 150), Enum.Material.Sand)
	sand.Shape = Enum.PartType.Cylinder
	sand.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	if kind == "Abyss" then
		MakeRock(island, center + Vector3.new(-6, 1, -4), 2.2)
		MakeRock(island, center + Vector3.new(7, 1, 5), 1.6)
		MakeTree(island, center + Vector3.new(5, 1, -6), 1.1, Color3.fromRGB(40, 120, 90))
		MakeSign(island, center + Vector3.new(0, 1, 6), "ABYSS POINT", "Deep water. Rare fish.", Color3.fromRGB(120, 180, 255))
	else
		-- Royal Pond: a glowing golden pool in the middle of the island.
		local pond = MakePart(island, "RoyalPondWater", "Part", Vector3.new(0.6, 12, 12), center + Vector3.new(0, 1.1, 0), Color3.fromRGB(255, 214, 90), Enum.Material.Neon)
		pond.Shape = Enum.PartType.Cylinder
		pond.CFrame = CFrame.new(center + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pond.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 210, 100)
		glow.Brightness = 2
		glow.Range = 22
		glow.Parent = pond
		MakeTree(island, center + Vector3.new(-7, 1, -5), 1.2, Color3.fromRGB(255, 170, 220))
		MakeTree(island, center + Vector3.new(7, 1, 6), 1.0, Color3.fromRGB(255, 200, 120))
		MakeSign(island, center + Vector3.new(0, 1, 8), "ROYAL POND", "Rebirth anglers only.", Color3.fromRGB(255, 220, 100))
	end
	return island
end

-- One player base plot: low wooden fence, a name sign, and tank anchor pads.
local function BuildBasePlot(world, index, center)
	local plot = Instance.new("Folder")
	plot.Name = "BasePlot" .. index
	plot.Parent = world
	-- Grass pad under the plot.
	MakePart(plot, "PlotPad", "Part", Vector3.new(20, 0.4, 12), center + Vector3.new(0, 0.2, 0), Color3.fromRGB(110, 190, 90), Enum.Material.Grass)
	-- Low wooden fence around three sides (open toward the lake).
	MakePart(plot, "FenceBack", "Part", Vector3.new(20, 1.2, 0.4), center + Vector3.new(0, 0.8, 6), Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	MakePart(plot, "FenceLeft", "Part", Vector3.new(0.4, 1.2, 12), center + Vector3.new(-10, 0.8, 0), Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	MakePart(plot, "FenceRight", "Part", Vector3.new(0.4, 1.2, 12), center + Vector3.new(10, 0.8, 0), Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
	-- Owner sign (the name is filled in when a player claims the plot).
	local sign = MakeSign(plot, center + Vector3.new(0, 0, 7.5), "OPEN BASE", "Your tanks go here", Color3.fromRGB(255, 230, 170))
	sign.Name = "OwnerSign"
	-- Tank anchor pads (12): small stone slabs the glass tanks sit on.
	for i, offset in ipairs(GameConfig.TankAnchors) do
		MakePart(plot, "TankPad" .. i, "Part", Vector3.new(2.8, 0.3, 2.2), center + offset + Vector3.new(0, 0.55, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Slate)
	end
	return plot
end

-- The lake monster's hidden parts: a dark shadow under the deep water,
-- a fin and two glowing eyes that rise during the event.
local function BuildMonster(world)
	local folder = Instance.new("Folder")
	folder.Name = "LakeMonster"
	folder.Parent = world
	local shadow = MakePart(folder, "MonsterShadow", "Part", Vector3.new(30, 0.4, 16), Vector3.new(0, 0.3, -80), Color3.fromRGB(10, 20, 40), Enum.Material.SmoothPlastic)
	shadow.Shape = Enum.PartType.Ball
	shadow.Transparency = 1
	shadow.CanCollide = false
	local fin = MakePart(folder, "MonsterFin", "WedgePart", Vector3.new(4, 6, 1), Vector3.new(0, 1.5, -80), Color3.fromRGB(20, 120, 70), Enum.Material.SmoothPlastic)
	fin.Transparency = 1
	fin.CanCollide = false
	local eyeLeft = MakePart(folder, "MonsterEyeLeft", "Part", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-2.5, 1, -74), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	eyeLeft.Shape = Enum.PartType.Ball
	eyeLeft.Transparency = 1
	eyeLeft.CanCollide = false
	local eyeRight = MakePart(folder, "MonsterEyeRight", "Part", Vector3.new(1.4, 1.4, 1.4), Vector3.new(2.5, 1, -74), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	eyeRight.Shape = Enum.PartType.Ball
	eyeRight.Transparency = 1
	eyeRight.CanCollide = false
	monsterParts = { Shadow = shadow, Fin = fin, EyeLeft = eyeLeft, EyeRight = eyeRight }
end

-- A small wooden rowboat floating near the pier.
local function BuildBoat(world)
	local boat = Instance.new("Folder")
	boat.Name = "Rowboat"
	boat.Parent = world
	local hull = MakePart(boat, "BoatHull", "Part", Vector3.new(3, 1.2, 7), Vector3.new(14, 0.4, -20), Color3.fromRGB(150, 100, 55), Enum.Material.WoodPlanks)
	hull.CanCollide = false
	MakePart(boat, "BoatBench", "Part", Vector3.new(2.6, 0.3, 1), Vector3.new(14, 1, -20), Color3.fromRGB(120, 80, 45), Enum.Material.Wood).CanCollide = false
	local mast = MakePart(boat, "BoatMast", "Part", Vector3.new(0.3, 4, 0.3), Vector3.new(14, 2.5, -21), Color3.fromRGB(120, 80, 45), Enum.Material.Wood)
	mast.CanCollide = false
	MakePart(boat, "BoatFlag", "Part", Vector3.new(1.6, 1, 0.1), Vector3.new(14.8, 4, -21), Color3.fromRGB(255, 80, 80), Enum.Material.SmoothPlastic).CanCollide = false
end

-- The main build: ground, lake, shore, pier, islands, bases, decor, monster.
function WorldBuilder.BuildWorld()
	local workspace = game:GetService("Workspace")
	local world = Instance.new("Folder")
	world.Name = "BrainrotFishingWorld"
	world.Parent = workspace

	-- Ground: bright green meadow.
	MakePart(world, "Ground", "Part", Vector3.new(300, 2, 300), Vector3.new(0, -1, 0), Color3.fromRGB(95, 175, 85), Enum.Material.Grass)
	-- Lake: big translucent teal sheet over the north half.
	local lake = MakePart(world, "LakeWater", "Part", Vector3.new(200, 1, 140), Vector3.new(0, -0.2, -60), Color3.fromRGB(45, 160, 190), Enum.Material.SmoothPlastic)
	lake.Transparency = 0.25
	lake.CanCollide = false
	-- Sandy shore strip where the lake meets the land.
	MakePart(world, "ShoreSand", "Part", Vector3.new(200, 0.5, 22), Vector3.new(0, 0.1, 20), Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	-- Colored water patches mark each fishing spot's depth.
	for spotId, spot in pairs(GameConfig.Spots) do
		local patch = MakePart(world, spotId .. "Water", "Part", Vector3.new(0.4, 14, 14), Vector3.new(spot.Position.X, 0.4, spot.Position.Z), spot.WaterColor, Enum.Material.SmoothPlastic)
		patch.Shape = Enum.PartType.Cylinder
		patch.CFrame = CFrame.new(Vector3.new(spot.Position.X, 0.4, spot.Position.Z)) * CFrame.Angles(0, 0, math.rad(90))
		patch.Transparency = 0.35
		patch.CanCollide = false
	end

	BuildPier(world)
	BuildBridge(world)
	BuildIsland(world, Vector3.new(-70, 0, -95), "Abyss")
	BuildIsland(world, Vector3.new(70, 0, -95), "Royal")
	BuildBoat(world)

	-- Spawn: right on the pier, rod already in hand.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PierSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 1.2, 18)
	spawn.Color = Color3.fromRGB(165, 120, 70)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Neutral = true -- no teams in this game: anyone may use this spawn
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = world

	-- Spot signs.
	MakeSign(world, Vector3.new(6, 0, 26), "SHALLOW SHORE", "Free fishing. Start here!", Color3.fromRGB(140, 240, 210))
	MakeSign(world, Vector3.new(5, 1, -60), "DEEP DOCK", "Deeper water. $500 in the Shop.", Color3.fromRGB(120, 190, 255))

	-- Quest board + top anglers board at the foot of the pier.
	MakeSign(world, Vector3.new(-9, 0, 28), "QUEST BOARD", "3 daily quests. Big rewards!", Color3.fromRGB(255, 220, 120))
	MakeSign(world, Vector3.new(9, 0, 28), "TOP ANGLERS", "Catch rare fish. Climb the lake!", Color3.fromRGB(255, 180, 180))

	-- Base plots along the shore.
	for i, center in ipairs(GameConfig.BasePlots) do
		BuildBasePlot(world, i, center)
	end

	-- Trees: a colorful mix along the shore and on the meadow.
	local treeSpots = {
		{ Vector3.new(-30, 0, 35), 1.2, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(-48, 0, 60), 1.4, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(-80, 0, 30), 1.1, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(-105, 0, 55), 1.5, Color3.fromRGB(255, 200, 90) },
		{ Vector3.new(30, 0, 36), 1.3, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(52, 0, 62), 1.1, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(84, 0, 32), 1.4, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(108, 0, 58), 1.2, Color3.fromRGB(255, 200, 90) },
		{ Vector3.new(-120, 0, -10), 1.5, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(120, 0, -12), 1.3, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(-60, 0, 85), 1.2, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(60, 0, 88), 1.4, Color3.fromRGB(60, 170, 80) },
	}
	for _, spec in ipairs(treeSpots) do
		MakeTree(world, spec[1], spec[2], spec[3])
	end

	-- Rocks near the waterline.
	for _, spec in ipairs({
		{ Vector3.new(-18, 0.4, 28), 1.4 },
		{ Vector3.new(22, 0.4, 30), 1.1 },
		{ Vector3.new(-95, 0.4, 18), 1.8 },
		{ Vector3.new(96, 0.4, 20), 1.5 },
		{ Vector3.new(-40, 0.4, -5), 1.2 },
		{ Vector3.new(44, 0.4, -8), 1.6 },
	}) do
		MakeRock(world, spec[1], spec[2])
	end

	-- Lanterns along the shore path.
	for _, x in ipairs({ -20, -8, 8, 20, -70, -40, 40, 70 }) do
		MakeLantern(world, Vector3.new(x, 0, 34))
	end

	BuildMonster(world)

	-- Sunset haze.
	local lighting = game:GetService("Lighting")
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SunsetHaze"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 170, 130)
	atmosphere.Decay = Color3.fromRGB(140, 90, 160)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.5
	atmosphere.Parent = lighting

	return world
end

-- Returns the monster's parts so MonsterEventService can show/hide them.
function WorldBuilder.GetMonsterParts()
	return monsterParts
end

return WorldBuilder
