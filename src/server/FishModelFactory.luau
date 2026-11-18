-- FishModelFactory: builds each of the 9 brainrot fish as a small 3D model from parts.
-- Body + tail + fins + one signature accessory per fish, so every fish reads
-- at a glance. Naga Nila is built at 2x scale. Mutations re-skin the model:
-- Golden = glowing gold, Rainbow = neon with a rainbow particle trail.

local FishDefinitions = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FishDefinitions"))

local FishModelFactory = {}

local function MakeModelPart(model, name, className, size, offset, color, material)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

-- The signature accessory for one fish id (a few extra parts on the body).
local function AddAccessory(model, fishId, def, scale)
	local accent = def.AccentColor
	if fishId == "LeleLirico" then
		-- Two long curved whiskers (thin cylinders angled forward).
		local w1 = MakeModelPart(model, "WhiskerL", "Part", Vector3.new(0.12 * scale, 0.12 * scale, 1.6 * scale), Vector3.new(-0.3 * scale, 0.25 * scale, 1.4 * scale), accent)
		w1.CFrame = CFrame.new(Vector3.new(-0.3 * scale, 0.25 * scale, 1.4 * scale)) * CFrame.Angles(math.rad(20), math.rad(25), 0)
		local w2 = MakeModelPart(model, "WhiskerR", "Part", Vector3.new(0.12 * scale, 0.12 * scale, 1.6 * scale), Vector3.new(0.3 * scale, 0.25 * scale, 1.4 * scale), accent)
		w2.CFrame = CFrame.new(Vector3.new(0.3 * scale, 0.25 * scale, 1.4 * scale)) * CFrame.Angles(math.rad(20), math.rad(-25), 0)
	elseif fishId == "GuppyGondola" then
		-- Mini straw hat: brim disc + dome.
		local brim = MakeModelPart(model, "HatBrim", "Part", Vector3.new(0.1 * scale, 1.1 * scale, 1.1 * scale), Vector3.new(0, 0.65 * scale, 0.2 * scale), Color3.fromRGB(240, 210, 130), Enum.Material.Wood)
		brim.Shape = Enum.PartType.Cylinder
		brim.CFrame = CFrame.new(Vector3.new(0, 0.65 * scale, 0.2 * scale)) * CFrame.Angles(0, 0, math.rad(90))
		MakeModelPart(model, "HatTop", "Part", Vector3.new(0.6 * scale, 0.4 * scale, 0.6 * scale), Vector3.new(0, 0.85 * scale, 0.2 * scale), Color3.fromRGB(220, 180, 100), Enum.Material.Wood)
	elseif fishId == "MujairMaestro" then
		-- Conductor baton + bow tie.
		local baton = MakeModelPart(model, "Baton", "Part", Vector3.new(0.1 * scale, 0.1 * scale, 1.2 * scale), Vector3.new(0.5 * scale, 0.4 * scale, 1.1 * scale), Color3.fromRGB(255, 255, 255))
		baton.CFrame = CFrame.new(Vector3.new(0.5 * scale, 0.4 * scale, 1.1 * scale)) * CFrame.Angles(math.rad(-30), 0, math.rad(20))
		MakeModelPart(model, "BowTieL", "WedgePart", Vector3.new(0.4 * scale, 0.3 * scale, 0.2 * scale), Vector3.new(-0.25 * scale, -0.1 * scale, 1.05 * scale), Color3.fromRGB(200, 40, 60))
		MakeModelPart(model, "BowTieR", "WedgePart", Vector3.new(0.4 * scale, 0.3 * scale, 0.2 * scale), Vector3.new(0.25 * scale, -0.1 * scale, 1.05 * scale), Color3.fromRGB(200, 40, 60))
	elseif fishId == "PatinPianissimo" then
		-- A floating mini piano under the fish.
		MakeModelPart(model, "Piano", "Part", Vector3.new(1.4 * scale, 0.5 * scale, 0.8 * scale), Vector3.new(0, -0.75 * scale, 0.4 * scale), Color3.fromRGB(30, 30, 35))
		for i = 1, 5 do
			MakeModelPart(model, "PianoKey" .. i, "Part", Vector3.new(0.22 * scale, 0.1 * scale, 0.5 * scale), Vector3.new(-0.56 * scale + (i - 1) * 0.28 * scale, -0.45 * scale, 0.4 * scale), Color3.fromRGB(255, 255, 255))
		end
	elseif fishId == "KoiKavaleri" then
		-- Knight helmet + red plume + tiny lance.
		local helm = MakeModelPart(model, "Helmet", "Part", Vector3.new(0.9 * scale, 0.7 * scale, 0.9 * scale), Vector3.new(0, 0.6 * scale, 0.3 * scale), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
		helm.Shape = Enum.PartType.Ball
		MakeModelPart(model, "Plume", "Part", Vector3.new(0.2 * scale, 0.7 * scale, 0.2 * scale), Vector3.new(0, 1.1 * scale, 0.3 * scale), Color3.fromRGB(220, 40, 40))
		local lance = MakeModelPart(model, "Lance", "Part", Vector3.new(0.1 * scale, 0.1 * scale, 1.8 * scale), Vector3.new(0.6 * scale, 0.1 * scale, 1.2 * scale), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		lance.CFrame = CFrame.new(Vector3.new(0.6 * scale, 0.1 * scale, 1.2 * scale)) * CFrame.Angles(math.rad(10), 0, 0)
	elseif fishId == "ArwanaAstronaut" then
		-- Glass space helmet + oxygen tank.
		local helmet = MakeModelPart(model, "SpaceHelmet", "Part", Vector3.new(1.3 * scale, 1.3 * scale, 1.3 * scale), Vector3.new(0, 0.2 * scale, 0.5 * scale), Color3.fromRGB(180, 220, 255), Enum.Material.Glass)
		helmet.Shape = Enum.PartType.Ball
		helmet.Transparency = 0.4
		MakeModelPart(model, "OxygenTank", "Part", Vector3.new(0.4 * scale, 0.9 * scale, 0.4 * scale), Vector3.new(0, 0.5 * scale, -0.6 * scale), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	elseif fishId == "SidatSultan" then
		-- Golden crown + purple cape.
		MakeModelPart(model, "CrownBase", "Part", Vector3.new(0.9 * scale, 0.3 * scale, 0.9 * scale), Vector3.new(0, 0.7 * scale, 0.4 * scale), Color3.fromRGB(255, 210, 60), Enum.Material.Metal)
		for i = 1, 3 do
			MakeModelPart(model, "CrownSpike" .. i, "Part", Vector3.new(0.18 * scale, 0.4 * scale, 0.18 * scale), Vector3.new(-0.3 * scale + (i - 1) * 0.3 * scale, 1 * scale, 0.4 * scale), Color3.fromRGB(255, 210, 60), Enum.Material.Metal)
		end
		MakeModelPart(model, "Cape", "Part", Vector3.new(0.9 * scale, 0.1 * scale, 1.4 * scale), Vector3.new(0, 0.2 * scale, -1 * scale), Color3.fromRGB(120, 50, 200), Enum.Material.SmoothPlastic)
	elseif fishId == "BelutBarista" then
		-- Barista apron + a mini coffee cup held on the fin.
		MakeModelPart(model, "Apron", "Part", Vector3.new(0.8 * scale, 0.9 * scale, 0.1 * scale), Vector3.new(0, -0.1 * scale, 0.6 * scale), Color3.fromRGB(255, 245, 230))
		local cup = MakeModelPart(model, "CoffeeCup", "Part", Vector3.new(0.35 * scale, 0.4 * scale, 0.4 * scale), Vector3.new(0.6 * scale, 0.1 * scale, 0.9 * scale), Color3.fromRGB(255, 255, 255))
		cup.Shape = Enum.PartType.Cylinder
		cup.CFrame = CFrame.new(Vector3.new(0.6 * scale, 0.1 * scale, 0.9 * scale)) * CFrame.Angles(0, 0, math.rad(90))
		MakeModelPart(model, "Coffee", "Part", Vector3.new(0.28 * scale, 0.08 * scale, 0.28 * scale), Vector3.new(0.6 * scale, 0.32 * scale, 0.9 * scale), Color3.fromRGB(90, 55, 25))
	elseif fishId == "NagaNila" then
		-- Dragon horns + red crest + whiskers (built at 2x scale already).
		local h1 = MakeModelPart(model, "HornL", "Part", Vector3.new(0.25 * scale, 0.9 * scale, 0.25 * scale), Vector3.new(-0.4 * scale, 0.8 * scale, 0.6 * scale), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic)
		h1.CFrame = CFrame.new(Vector3.new(-0.4 * scale, 0.8 * scale, 0.6 * scale)) * CFrame.Angles(0, 0, math.rad(20))
		local h2 = MakeModelPart(model, "HornR", "Part", Vector3.new(0.25 * scale, 0.9 * scale, 0.25 * scale), Vector3.new(0.4 * scale, 0.8 * scale, 0.6 * scale), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic)
		h2.CFrame = CFrame.new(Vector3.new(0.4 * scale, 0.8 * scale, 0.6 * scale)) * CFrame.Angles(0, 0, math.rad(-20))
		for i = 1, 3 do
			MakeModelPart(model, "Crest" .. i, "WedgePart", Vector3.new(0.15 * scale, 0.5 * scale, 0.4 * scale), Vector3.new(0, 0.65 * scale, 0.1 * scale - (i - 1) * 0.5 * scale), Color3.fromRGB(220, 40, 40))
		end
	end
end

-- Applies a mutation skin to a finished model.
local function ApplyMutationSkin(model, mutation)
	if mutation == "Golden" then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(255, 205, 60)
				part.Material = Enum.Material.Neon
			end
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 100)
		sparkles.Parent = model.PrimaryPart
	elseif mutation == "Rainbow" then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.Neon
			end
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
		})
		emitter.Size = NumberSequence.new(0.3)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Parent = model.PrimaryPart
	end
end

-- Builds the full fish model. mutation: "None" | "Golden" | "Rainbow".
-- Fish are built at 1.4x so they read clearly inside the bigger tanks
-- (the old 1x fish looked tiny from a few steps away); Naga Nila is 1.6x.
function FishModelFactory.BuildFishModel(fishId, mutation)
	local def = FishDefinitions.Fish[fishId]
	if not def then
		return nil
	end
	local scale = 1.4
	if fishId == "NagaNila" then
		scale = 1.6
	end
	local length = 2.2
	if fishId == "SidatSultan" or fishId == "BelutBarista" then
		length = 3.0
	end

	local model = Instance.new("Model")
	model.Name = def.Name .. "Model"

	-- Body: a rounded block, slightly flattened.
	local body = MakeModelPart(model, "Body", "Part", Vector3.new(1.1 * scale, 0.9 * scale, length * scale), Vector3.new(0, 0, 0), def.BodyColor)
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	-- Tail fin: a wedge at the back.
	local tail = MakeModelPart(model, "Tail", "WedgePart", Vector3.new(0.9 * scale, 0.9 * scale, 0.9 * scale), Vector3.new(0, 0.1 * scale, -(length / 2 + 0.4) * scale), def.AccentColor)
	tail.CFrame = CFrame.new(Vector3.new(0, 0.1 * scale, -(length / 2 + 0.4) * scale)) * CFrame.Angles(math.rad(90), 0, 0)

	-- Top fin.
	MakeModelPart(model, "TopFin", "WedgePart", Vector3.new(0.15 * scale, 0.6 * scale, 1 * scale), Vector3.new(0, 0.55 * scale, -0.2 * scale), def.AccentColor)

	-- Eyes: two white balls with black pupils, front of the body.
	for _, side in ipairs({ -1, 1 }) do
		local eye = MakeModelPart(model, "Eye" .. (side < 0 and "L" or "R"), "Part", Vector3.new(0.3 * scale, 0.3 * scale, 0.3 * scale), Vector3.new(side * 0.4 * scale, 0.2 * scale, length / 2 * scale * 0.75), Color3.fromRGB(255, 255, 255))
		eye.Shape = Enum.PartType.Ball
		local pupil = MakeModelPart(model, "Pupil" .. (side < 0 and "L" or "R"), "Part", Vector3.new(0.16 * scale, 0.16 * scale, 0.16 * scale), Vector3.new(side * 0.42 * scale, 0.22 * scale, length / 2 * scale * 0.75 + 0.12 * scale), Color3.fromRGB(20, 20, 20))
		pupil.Shape = Enum.PartType.Ball
	end

	AddAccessory(model, fishId, def, scale)

	if mutation and mutation ~= "None" then
		ApplyMutationSkin(model, mutation)
	end

	return model
end

return FishModelFactory
