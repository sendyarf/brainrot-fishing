-- FishModelFactory — builds a voxel fish model out of Parts, one per fish.
-- Every fish gets a body, a tail fin, a belly and eyes, plus the accessory
-- that makes it readable at a glance (a crown, a helmet, a piano...).
-- Mutations recolour the model: Golden shines gold, Rainbow cycles hues.
-- Used by the server for tank displays and by the client for the dex.

local FishDefinitions = require(script.Parent.FishDefinitions)

local FishModelFactory = {}

local function makePart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function addEyes(model, body, scale)
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Vector3.new(0.22 * scale, 0.22 * scale, 0.1 * scale), Color3.fromRGB(20, 20, 20))
		eye.CFrame = body.CFrame * CFrame.new(0.55 * scale, 0.25 * scale, side * 0.42 * scale)
		eye.Parent = model
	end
end

-- Accessory builders. Each adds the fish's signature prop to the model.
local function addWhiskers(model, body, scale)
	for _, side in ipairs({ -1, 1 }) do
		local whisker = makePart("Whisker", Vector3.new(0.08 * scale, 0.08 * scale, 1.4 * scale), Color3.fromRGB(220, 220, 210))
		whisker.CFrame = body.CFrame * CFrame.new(0.9 * scale, -0.1 * scale, side * 0.3 * scale)
			* CFrame.Angles(0, side * 0.5, 0.4)
		whisker.Parent = model
	end
end

local function addStrawHat(model, body, scale)
	local brim = makePart("HatBrim", Vector3.new(1.3 * scale, 0.08 * scale, 1.3 * scale), Color3.fromRGB(230, 200, 120))
	brim.CFrame = body.CFrame * CFrame.new(0, 0.55 * scale, 0)
	brim.Parent = model
	local top = makePart("HatTop", Vector3.new(0.6 * scale, 0.3 * scale, 0.6 * scale), Color3.fromRGB(210, 180, 100))
	top.CFrame = body.CFrame * CFrame.new(0, 0.72 * scale, 0)
	top.Parent = model
end

local function addTrumpet(model, body, scale)
	local horn = makePart("Trumpet", Vector3.new(0.9 * scale, 0.18 * scale, 0.18 * scale), Color3.fromRGB(255, 210, 60))
	horn.CFrame = body.CFrame * CFrame.new(1.1 * scale, 0, 0)
	horn.Parent = model
	local bell = makePart("TrumpetBell", Vector3.new(0.25 * scale, 0.5 * scale, 0.5 * scale), Color3.fromRGB(255, 210, 60))
	bell.CFrame = body.CFrame * CFrame.new(1.6 * scale, 0, 0)
	bell.Parent = model
end

local function addBaton(model, body, scale)
	local baton = makePart("Baton", Vector3.new(0.08 * scale, 1.1 * scale, 0.08 * scale), Color3.fromRGB(240, 240, 230))
	baton.CFrame = body.CFrame * CFrame.new(0.4 * scale, 0.8 * scale, 0.4 * scale) * CFrame.Angles(0, 0, 0.6)
	baton.Parent = model
	local bowtie = makePart("BowTie", Vector3.new(0.3 * scale, 0.25 * scale, 0.5 * scale), Color3.fromRGB(30, 30, 40))
	bowtie.CFrame = body.CFrame * CFrame.new(0.75 * scale, -0.2 * scale, 0)
	bowtie.Parent = model
end

local function addPiano(model, body, scale)
	local piano = makePart("Piano", Vector3.new(1.6 * scale, 0.5 * scale, 1.0 * scale), Color3.fromRGB(25, 25, 30))
	piano.CFrame = body.CFrame * CFrame.new(0, -0.55 * scale, 0)
	piano.Parent = model
	for i = 1, 5 do
		local key = makePart("PianoKey", Vector3.new(0.22 * scale, 0.08 * scale, 0.4 * scale), Color3.fromRGB(250, 250, 245))
		key.CFrame = body.CFrame * CFrame.new(-0.6 * scale + (i - 1) * 0.3 * scale, -0.26 * scale, 0.35 * scale)
		key.Parent = model
	end
end

local function addGuitar(model, body, scale)
	local neck = makePart("GuitarNeck", Vector3.new(1.2 * scale, 0.12 * scale, 0.12 * scale), Color3.fromRGB(150, 100, 60))
	neck.CFrame = body.CFrame * CFrame.new(0.6 * scale, 0.3 * scale, 0.3 * scale) * CFrame.Angles(0, 0, 0.7)
	neck.Parent = model
	local guitarBody = makePart("GuitarBody", Vector3.new(0.7 * scale, 0.6 * scale, 0.25 * scale), Color3.fromRGB(200, 60, 50))
	guitarBody.CFrame = body.CFrame * CFrame.new(0, 0, 0.45 * scale)
	guitarBody.Parent = model
end

local function addKnightGear(model, body, scale)
	local helm = makePart("Helm", Vector3.new(0.7 * scale, 0.6 * scale, 0.7 * scale), Color3.fromRGB(180, 185, 195))
	helm.CFrame = body.CFrame * CFrame.new(0.3 * scale, 0.55 * scale, 0)
	helm.Parent = model
	local plume = makePart("Plume", Vector3.new(0.15 * scale, 0.6 * scale, 0.15 * scale), Color3.fromRGB(220, 40, 40))
	plume.CFrame = body.CFrame * CFrame.new(0.3 * scale, 1.0 * scale, 0)
	plume.Parent = model
	local lance = makePart("Lance", Vector3.new(1.8 * scale, 0.08 * scale, 0.08 * scale), Color3.fromRGB(160, 120, 70))
	lance.CFrame = body.CFrame * CFrame.new(0.8 * scale, 0.1 * scale, 0.5 * scale)
	lance.Parent = model
end

local function addHelmet(model, body, scale)
	local dome = makePart("SpaceHelmet", Vector3.new(1.0 * scale, 1.0 * scale, 1.0 * scale), Color3.fromRGB(180, 220, 255))
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.4
	dome.CFrame = body.CFrame * CFrame.new(0.3 * scale, 0.2 * scale, 0)
	dome.Parent = model
	local tank = makePart("OxygenTank", Vector3.new(0.35 * scale, 0.8 * scale, 0.35 * scale), Color3.fromRGB(220, 220, 220))
	tank.CFrame = body.CFrame * CFrame.new(-0.5 * scale, 0.3 * scale, 0)
	tank.Parent = model
end

local function addCrown(model, body, scale)
	local crown = makePart("Crown", Vector3.new(0.7 * scale, 0.4 * scale, 0.7 * scale), Color3.fromRGB(255, 210, 60))
	crown.Material = Enum.Material.Metal
	crown.CFrame = body.CFrame * CFrame.new(0.2 * scale, 0.6 * scale, 0)
	crown.Parent = model
	for i = 1, 3 do
		local spike = makePart("CrownSpike", Vector3.new(0.14 * scale, 0.35 * scale, 0.14 * scale), Color3.fromRGB(255, 210, 60))
		spike.Material = Enum.Material.Metal
		spike.CFrame = body.CFrame * CFrame.new(-0.05 * scale + (i - 1) * 0.25 * scale, 0.9 * scale, 0)
		spike.Parent = model
	end
end

local function addCoffee(model, body, scale)
	local apron = makePart("Apron", Vector3.new(0.9 * scale, 0.5 * scale, 0.1 * scale), Color3.fromRGB(60, 50, 45))
	apron.CFrame = body.CFrame * CFrame.new(0.2 * scale, -0.3 * scale, 0.4 * scale)
	apron.Parent = model
	local cup = makePart("CoffeeCup", Vector3.new(0.3 * scale, 0.35 * scale, 0.3 * scale), Color3.fromRGB(255, 255, 255))
	cup.CFrame = body.CFrame * CFrame.new(0.7 * scale, -0.1 * scale, 0.5 * scale)
	cup.Parent = model
end

local function addGong(model, body, scale)
	local gong = makePart("Gong", Vector3.new(0.15 * scale, 1.1 * scale, 1.1 * scale), Color3.fromRGB(255, 200, 50))
	gong.Material = Enum.Material.Metal
	gong.CFrame = body.CFrame * CFrame.new(-0.9 * scale, 0.1 * scale, 0)
	gong.Parent = model
end

local function addHorns(model, body, scale)
	for _, side in ipairs({ -1, 1 }) do
		local horn = makePart("DragonHorn", Vector3.new(0.25 * scale, 1.0 * scale, 0.25 * scale), Color3.fromRGB(250, 240, 210))
		horn.CFrame = body.CFrame * CFrame.new(0.5 * scale, 0.8 * scale, side * 0.35 * scale)
			* CFrame.Angles(0, 0, side * 0.4)
		horn.Parent = model
	end
	local crest = makePart("DragonCrest", Vector3.new(1.2 * scale, 0.5 * scale, 0.12 * scale), Color3.fromRGB(255, 80, 60))
	crest.CFrame = body.CFrame * CFrame.new(-0.2 * scale, 0.55 * scale, 0)
	crest.Parent = model
end

local ACCESSORY_BUILDERS = {
	whiskers = addWhiskers,
	strawhat = addStrawHat,
	trumpet = addTrumpet,
	baton = addBaton,
	piano = addPiano,
	guitar = addGuitar,
	knight = addKnightGear,
	helmet = addHelmet,
	crown = addCrown,
	coffee = addCoffee,
	gong = addGong,
	horns = addHorns,
}

-- Builds a fish model at the given CFrame. Mutation is "none", "golden"
-- or "rainbow". Returns the Model; the caller parents it.
function FishModelFactory.BuildFishModel(fishId, mutation, cframe)
	local fish = FishDefinitions.GetFishById(fishId)
	if not fish then
		return nil
	end

	local scale = 1
	if fish.rarity == "Mythic" then
		scale = 2 -- Naga Nila is twice the size of the other fish
	end

	local model = Instance.new("Model")
	model.Name = fish.name

	local bodyColor = fish.bodyColor
	local bodyMaterial = Enum.Material.SmoothPlastic
	if mutation == "golden" then
		bodyColor = Color3.fromRGB(255, 210, 60)
		bodyMaterial = Enum.Material.Metal
	elseif mutation == "rainbow" then
		bodyColor = Color3.fromRGB(255, 100, 180)
		bodyMaterial = Enum.Material.Neon
	end

	-- Body: a chunky voxel fish.
	local body = makePart("Body", Vector3.new(1.6 * scale, 0.9 * scale, 0.7 * scale), bodyColor, bodyMaterial)
	body.CFrame = cframe
	body.Parent = model
	model.PrimaryPart = body

	-- Belly stripe.
	local belly = makePart("Belly", Vector3.new(1.2 * scale, 0.3 * scale, 0.72 * scale), fish.bellyColor)
	belly.CFrame = cframe * CFrame.new(-0.1 * scale, -0.35 * scale, 0)
	belly.Parent = model

	-- Tail fin.
	local tail = makePart("TailFin", Vector3.new(0.5 * scale, 1.0 * scale, 0.12 * scale), fish.bellyColor)
	tail.CFrame = cframe * CFrame.new(-1.0 * scale, 0, 0) * CFrame.Angles(0, 0.5, 0)
	tail.Parent = model

	-- Dorsal fin.
	local dorsal = makePart("DorsalFin", Vector3.new(0.7 * scale, 0.4 * scale, 0.12 * scale), fish.bellyColor)
	dorsal.CFrame = cframe * CFrame.new(-0.1 * scale, 0.6 * scale, 0)
	dorsal.Parent = model

	addEyes(model, body, scale)

	local builder = ACCESSORY_BUILDERS[fish.accessory]
	if builder then
		builder(model, body, scale)
	end

	-- Mutation glow: a soft point light so mutated fish stand out in tanks.
	if mutation == "golden" or mutation == "rainbow" then
		local light = Instance.new("PointLight")
		light.Color = mutation == "golden" and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(255, 120, 200)
		light.Range = 6
		light.Brightness = 1.5
		light.Parent = body
	end

	return model
end

return FishModelFactory
