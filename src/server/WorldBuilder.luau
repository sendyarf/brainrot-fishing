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

-- Attaches a sign label ON a board's face (SurfaceGui), so the text reads
-- as painted on the board — like the top-1 game's ROT RANCH sign — instead
-- of floating in the air. The old BillboardGui plane sat at the board's
-- center (inside the 0.3-thick board) with AlwaysOnTop, so the text
-- rendered through everything and looked detached from the board. A
-- SurfaceGui lives on the face itself: it is occluded like the board,
-- readable only from the front, and never floats. `face` is the board
-- face the text goes on (Front = +Z by default; the base sign faces the
-- lake, so it uses Back).
local function AttachSignLabel(board, title, subtitle, titleColor, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignLabel"
	gui.Face = face or Enum.NormalId.Front
	gui.PixelsPerStud = 50
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
	titleLabel.TextWrapped = true
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
	subLabel.TextWrapped = true
	subLabel.Parent = gui
end

-- A wooden sign post with a board whose text is painted on its face.
-- The board is BIG (7 x 3.6 studs): a SurfaceGui shrinks with distance
-- like a real board, so a 4.4-stud board was unreadable at normal play
-- distance.
local function MakeSign(parent, position, title, subtitle, titleColor, face)
	local post = MakePart(parent, "SignPost", "Part", Vector3.new(0.6, 4.4, 0.6), position + Vector3.new(0, 2.2, 0), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	local board = MakePart(parent, "SignBoard", "Part", Vector3.new(7, 3.6, 0.3), position + Vector3.new(0, 5.2, 0), Color3.fromRGB(70, 45, 25), Enum.Material.WoodPlanks)
	AttachSignLabel(board, title, subtitle, titleColor, face)
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
	-- Support posts under the pier, down to the lakebed.
	for z = 24, -64, -16 do
		MakePart(pier, "PierPost", "Part", Vector3.new(0.8, 4.5, 0.8), Vector3.new(-2.4, -1.25, z), Color3.fromRGB(100, 70, 40), Enum.Material.Wood)
		MakePart(pier, "PierPost", "Part", Vector3.new(0.8, 4.5, 0.8), Vector3.new(2.4, -1.25, z), Color3.fromRGB(100, 70, 40), Enum.Material.Wood)
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
	-- Island base: a sand cylinder reaching down to the lakebed (-3.5) so
	-- the island stands IN the lake instead of floating above it.
	local sand = MakePart(island, "IslandSand", "Part", Vector3.new(4.5, 26, 26), center + Vector3.new(0, -1.3, 0), Color3.fromRGB(230, 210, 150), Enum.Material.Sand)
	sand.Shape = Enum.PartType.Cylinder
	sand.CFrame = CFrame.new(center + Vector3.new(0, -1.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
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

-- One accent color per base (10 plots): the roof, the header beam and the
-- display-table tops all wear it, so each base reads as its own colorful
-- house from across the lake.
local PlotColors = {
	Color3.fromRGB(220, 60, 60), -- red
	Color3.fromRGB(255, 140, 40), -- orange
	Color3.fromRGB(255, 210, 60), -- yellow
	Color3.fromRGB(80, 200, 80), -- green
	Color3.fromRGB(60, 200, 180), -- teal
	Color3.fromRGB(80, 140, 255), -- blue
	Color3.fromRGB(170, 90, 255), -- purple
	Color3.fromRGB(255, 120, 180), -- pink
	Color3.fromRGB(170, 220, 60), -- lime
	Color3.fromRGB(80, 220, 255), -- cyan
}

-- One player base plot: a small open-front house (cream walls, a slanted
-- accent roof, a sign over the entrance) with 3 rows of display tables —
-- the tanks sit ON the tables, not on the floor, so the base reads as a
-- neat display room. The front is open (pillars + header only) so the
-- player, the thief and the camera walk straight in, and the tanks are
-- visible from the lake through the opening. The center aisle (x -2.2..2.2)
-- runs front-to-back between the inner tables; the thief walks down it.
local function BuildBasePlot(world, index, center)
	local plot = Instance.new("Folder")
	plot.Name = "BasePlot" .. index
	plot.Parent = world
	local accent = PlotColors[((index - 1) % #PlotColors) + 1]
	local wallColor = Color3.fromRGB(245, 240, 225)
	local woodDark = Color3.fromRGB(120, 85, 50)
	-- Wooden floor (32 x 24: room for 3 rows of tables + walkable aisles).
	MakePart(plot, "PlotPad", "Part", Vector3.new(32, 0.4, 24), center + Vector3.new(0, 0.2, 0), Color3.fromRGB(170, 130, 85), Enum.Material.WoodPlanks)
	-- Walls: back + two sides, 7.5 tall, sitting on the floor (top at 0.4).
	MakePart(plot, "WallBack", "Part", Vector3.new(32, 7.5, 0.4), center + Vector3.new(0, 4.15, 12), wallColor)
	MakePart(plot, "WallLeft", "Part", Vector3.new(0.4, 7.5, 24), center + Vector3.new(-16, 4.15, 0), wallColor)
	MakePart(plot, "WallRight", "Part", Vector3.new(0.4, 7.5, 24), center + Vector3.new(16, 4.15, 0), wallColor)
	-- Front pillars + header beam (accent) over the open entrance.
	MakePart(plot, "PillarL", "Part", Vector3.new(1, 7.5, 1), center + Vector3.new(-16, 4.15, -12), woodDark, Enum.Material.Wood)
	MakePart(plot, "PillarR", "Part", Vector3.new(1, 7.5, 1), center + Vector3.new(16, 4.15, -12), woodDark, Enum.Material.Wood)
	MakePart(plot, "HeaderBeam", "Part", Vector3.new(32, 1.2, 0.8), center + Vector3.new(0, 7.2, -12), accent)
	-- Slanted roof: two 13-deep slabs at 15 degrees meeting at a ridge
	-- (y ~11.3), eaves at y ~7.9 just above the wall tops (7.9). Each
	-- slab's horizontal reach is 13*cos(15) = 12.56, so the roof covers
	-- the full 24-deep house and overhangs the walls a little on every
	-- side. Front slab tilts -15 (ridge end up), back slab +15.
	local roofFront = MakePart(plot, "RoofFront", "Part", Vector3.new(33, 0.3, 13), center + Vector3.new(0, 9.58, -6), accent)
	roofFront.CFrame = CFrame.new(center + Vector3.new(0, 9.58, -6)) * CFrame.Angles(math.rad(-15), 0, 0)
	local roofBack = MakePart(plot, "RoofBack", "Part", Vector3.new(33, 0.3, 13), center + Vector3.new(0, 9.58, 6), accent)
	roofBack.CFrame = CFrame.new(center + Vector3.new(0, 9.58, 6)) * CFrame.Angles(math.rad(15), 0, 0)
	MakePart(plot, "RoofRidge", "Part", Vector3.new(33, 0.5, 0.5), center + Vector3.new(0, 11.3, 0), accent)
	-- Owner sign hanging on the header, facing the lake (Back face = -Z).
	-- Its bottom (5.65) clears a 5-stud player walking in; the name is
	-- filled in when a player claims the plot.
	local signBoard = MakePart(plot, "OwnerSign", "Part", Vector3.new(10, 2.5, 0.3), center + Vector3.new(0, 6.9, -12.6), Color3.fromRGB(70, 45, 25), Enum.Material.WoodPlanks)
	signBoard.CanCollide = false
	AttachSignLabel(signBoard, "OPEN BASE", "Your tanks go here", Color3.fromRGB(255, 230, 170), Enum.NormalId.Back)
	-- Display tables (12): a pedestal + an accent top. The tank glass
	-- sits on the top (y 1.8) — see TankService.GetTankCenter (+3.75).
	for i, offset in ipairs(GameConfig.TankAnchors) do
		MakePart(plot, "TablePedestal" .. i, "Part", Vector3.new(1.5, 1.1, 1.5), center + offset + Vector3.new(0, 0.95, 0), woodDark, Enum.Material.Wood)
		MakePart(plot, "TableTop" .. i, "Part", Vector3.new(5.6, 0.3, 5.6), center + offset + Vector3.new(0, 1.65, 0), accent)
	end
	return plot
end

-- The lake monster's hidden parts: a dark shadow on the deep water, a fin
-- and two glowing eyes that rise during the event. They live MID-LAKE
-- (x = 18, z = -45), east of the pier, ~60 studs from the shore — the old
-- spot at z = -80 was 100+ studs from every player, so the 4-stud fin and
-- 1.4-stud eyes were invisible and the event looked like nothing happened
-- (the blessing after it proved it HAD run). Big fin, big eyes, a red glow
-- light, and the shadow sitting ON the water surface (y = 0.5, above the
-- lake top at 0.3) so the monster is unmissable when it stirs.
local function BuildMonster(world)
	local folder = Instance.new("Folder")
	folder.Name = "LakeMonster"
	folder.Parent = world
	local shadow = MakePart(folder, "MonsterShadow", "Part", Vector3.new(36, 0.4, 20), Vector3.new(18, 0.5, -43), Color3.fromRGB(10, 20, 40), Enum.Material.SmoothPlastic)
	shadow.Shape = Enum.PartType.Ball
	shadow.Transparency = 1
	shadow.CanCollide = false
	local fin = MakePart(folder, "MonsterFin", "WedgePart", Vector3.new(8, 12, 1.5), Vector3.new(18, 3, -45), Color3.fromRGB(60, 255, 130), Enum.Material.Neon)
	fin.Transparency = 1
	fin.CanCollide = false
	local eyeLeft = MakePart(folder, "MonsterEyeLeft", "Part", Vector3.new(3.5, 3.5, 3.5), Vector3.new(15, 1.8, -40), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	eyeLeft.Shape = Enum.PartType.Ball
	eyeLeft.Transparency = 1
	eyeLeft.CanCollide = false
	local eyeRight = MakePart(folder, "MonsterEyeRight", "Part", Vector3.new(3.5, 3.5, 3.5), Vector3.new(21, 1.8, -40), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	eyeRight.Shape = Enum.PartType.Ball
	eyeRight.Transparency = 1
	eyeRight.CanCollide = false
	-- A red glow disc on the water under the monster: the dark fin on dark
	-- night water was still invisible in playtests, so the event now has a
	-- glowing red halo on the surface plus a Neon green fin.
	local glowDisc = MakePart(folder, "MonsterGlowDisc", "Part", Vector3.new(0.3, 40, 24), Vector3.new(18, 0.6, -43), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
	glowDisc.Shape = Enum.PartType.Cylinder
	-- Cylinder axis is X by default; rotate it flat (axis vertical).
	glowDisc.CFrame = CFrame.new(Vector3.new(18, 0.6, -43)) * CFrame.Angles(0, 0, math.rad(90))
	glowDisc.Transparency = 1
	glowDisc.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Name = "MonsterGlow"
	glow.Color = Color3.fromRGB(255, 60, 40)
	glow.Brightness = 5
	glow.Range = 60
	glow.Enabled = false
	glow.Parent = fin
	monsterParts = { Shadow = shadow, Fin = fin, EyeLeft = eyeLeft, EyeRight = eyeRight, Glow = glow, GlowDisc = glowDisc }
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

	-- Ground: bright green meadow in four slabs that leave a real basin for
	-- the lake (x -100..100, z -130..10). The old single slab ran under the
	-- whole lake, so the "lake" was a 0.3-stud sheet lying on grass.
	MakePart(world, "GroundSouth", "Part", Vector3.new(360, 2, 140), Vector3.new(0, -1, 80), Color3.fromRGB(95, 175, 85), Enum.Material.Grass)
	MakePart(world, "GroundNorth", "Part", Vector3.new(300, 2, 20), Vector3.new(0, -1, -140), Color3.fromRGB(95, 175, 85), Enum.Material.Grass)
	MakePart(world, "GroundEast", "Part", Vector3.new(50, 2, 140), Vector3.new(125, -1, -60), Color3.fromRGB(95, 175, 85), Enum.Material.Grass)
	MakePart(world, "GroundWest", "Part", Vector3.new(50, 2, 140), Vector3.new(-125, -1, -60), Color3.fromRGB(95, 175, 85), Enum.Material.Grass)
	-- Lakebed at the bottom of the basin (top at y = -3.5).
	MakePart(world, "LakeBed", "Part", Vector3.new(200, 1, 140), Vector3.new(0, -4, -60), Color3.fromRGB(190, 175, 130), Enum.Material.Sand)
	-- Lake: deep, dark water, 3.8 studs thick (surface at y = 0.25).
	-- Players who walk in wade chest-deep on the lakebed and can jump back
	-- out (the 3.5-stud ledge is well within jump height).
	local lake = MakePart(world, "LakeWater", "Part", Vector3.new(200, 3.8, 140), Vector3.new(0, -1.65, -60), Color3.fromRGB(35, 140, 180), Enum.Material.SmoothPlastic)
	lake.Transparency = 0.18
	lake.CanCollide = false
	-- Sandy shore strip where the lake meets the land.
	MakePart(world, "ShoreSand", "Part", Vector3.new(200, 0.5, 22), Vector3.new(0, 0.1, 21), Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	-- Glowing water patches mark each fishing spot's depth — Neon so they
	-- actually glow, with a light of their own and a tall light beam rising
	-- from each one. A flat translucent disc was invisible from anywhere
	-- except right on top of it, which left players with no visible
	-- "glowing water" to walk to; the beams are visible from anywhere on
	-- the map and say "fish here" at a glance.
	for spotId, spot in pairs(GameConfig.Spots) do
		local patch = MakePart(world, spotId .. "Water", "Part", Vector3.new(0.4, 14, 14), Vector3.new(spot.Position.X, 0.4, spot.Position.Z), spot.WaterColor, Enum.Material.Neon)
		patch.Shape = Enum.PartType.Cylinder
		patch.CFrame = CFrame.new(Vector3.new(spot.Position.X, 0.4, spot.Position.Z)) * CFrame.Angles(0, 0, math.rad(90))
		patch.Transparency = 0.15
		patch.CanCollide = false
		local patchLight = Instance.new("PointLight")
		patchLight.Color = spot.WaterColor
		patchLight.Brightness = 1.5
		patchLight.Range = 20
		patchLight.Parent = patch
		local beam = MakePart(world, spotId .. "Beam", "Part", Vector3.new(1, 44, 1), Vector3.new(spot.Position.X, 22, spot.Position.Z), spot.WaterColor, Enum.Material.Neon)
		beam.Transparency = 0.65
		beam.CanCollide = false
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

	-- Spot signs (descriptive text, no prices: the price lives in the Shop,
	-- and a sign saying "$500" after the player already bought the spot was
	-- confusing).
	MakeSign(world, Vector3.new(6, 0, 26), "SHALLOW SHORE", "Free fishing. Start here!", Color3.fromRGB(140, 240, 210))
	MakeSign(world, Vector3.new(5, 1, -60), "DEEP DOCK", "Deeper water. Rare fish live here.", Color3.fromRGB(120, 190, 255))
	MakeSign(world, Vector3.new(-65, 0, -90), "ABYSS POINT", "The deep dark. Legends lurk below.", Color3.fromRGB(90, 130, 255))
	MakeSign(world, Vector3.new(65, 0, -90), "ROYAL POND", "Rebirth to fish here. Mythic 10%!", Color3.fromRGB(255, 214, 90))

	-- Quest board + top anglers board at the foot of the pier.
	MakeSign(world, Vector3.new(-9, 0, 28), "QUEST BOARD", "3 daily quests. Big rewards!", Color3.fromRGB(255, 220, 120))
	MakeSign(world, Vector3.new(9, 0, 28), "TOP ANGLERS", "Catch rare fish. Climb the lake!", Color3.fromRGB(255, 180, 180))

	-- Base plots along the shore.
	for i, center in ipairs(GameConfig.BasePlots) do
		BuildBasePlot(world, i, center)
	end

	-- Trees: a colorful mix along the shore and on the meadow. The plots
	-- are 24 deep (z 36..60), so no tree stands inside a house: the row
	-- behind the houses is at z 68, the shore row at z 30-35.
	local treeSpots = {
		{ Vector3.new(-30, 0, 35), 1.2, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(-48, 0, 68), 1.4, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(-80, 0, 30), 1.1, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(-105, 0, 68), 1.5, Color3.fromRGB(255, 200, 90) },
		{ Vector3.new(30, 0, 30), 1.3, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(52, 0, 68), 1.1, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(84, 0, 32), 1.4, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(108, 0, 68), 1.2, Color3.fromRGB(255, 200, 90) },
		{ Vector3.new(-120, 0, -10), 1.5, Color3.fromRGB(60, 170, 80) },
		{ Vector3.new(120, 0, -12), 1.3, Color3.fromRGB(70, 180, 90) },
		{ Vector3.new(-60, 0, 85), 1.2, Color3.fromRGB(255, 150, 180) },
		{ Vector3.new(60, 0, 88), 1.4, Color3.fromRGB(60, 170, 80) },
	}
	for _, spec in ipairs(treeSpots) do
		MakeTree(world, spec[1], spec[2], spec[3])
	end

	-- Rocks near the waterline (on the shore, not floating in the lake).
	for _, spec in ipairs({
		{ Vector3.new(-18, 0.4, 28), 1.4 },
		{ Vector3.new(22, 0.4, 30), 1.1 },
		{ Vector3.new(-95, 0.4, 18), 1.8 },
		{ Vector3.new(96, 0.4, 20), 1.5 },
		{ Vector3.new(-40, 0.4, 12), 1.2 },
		{ Vector3.new(44, 0.4, 14), 1.6 },
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
