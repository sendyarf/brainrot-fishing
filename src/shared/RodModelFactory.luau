-- RodModelFactory: builds the visible fishing rod model (grip + shaft +
-- reel + tip) for a rod id. Shared so the server (RodToolService, which
-- wraps it in a Tool the character holds) and the client (ShopClient,
-- which shows it in a ViewportFrame preview) use the SAME model — the
-- shop preview is the rod the player will hold, not a lookalike.
-- Fix 12: the Dex shows the fish in 3D, the shop showed nothing.

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local RodModelFactory = {}

-- Colors per rod tier (shaft, grip, reel, shaft material).
local RodColors = {
	Bamboo = { Shaft = Color3.fromRGB(170, 130, 80), Grip = Color3.fromRGB(120, 85, 50), Reel = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Wood },
	Wooden = { Shaft = Color3.fromRGB(140, 95, 55), Grip = Color3.fromRGB(100, 70, 40), Reel = Color3.fromRGB(90, 90, 90), Material = Enum.Material.Wood },
	Steel = { Shaft = Color3.fromRGB(150, 155, 165), Grip = Color3.fromRGB(60, 60, 70), Reel = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal },
	Golden = { Shaft = Color3.fromRGB(255, 210, 60), Grip = Color3.fromRGB(180, 140, 40), Reel = Color3.fromRGB(255, 220, 100), Material = Enum.Material.Metal },
	Dragon = { Shaft = Color3.fromRGB(180, 40, 50), Grip = Color3.fromRGB(80, 20, 30), Reel = Color3.fromRGB(255, 170, 60), Material = Enum.Material.SmoothPlastic },
}

local function MakePart(model, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

-- Builds the rod Model for a rod id (not parented). Parts are placed
-- relative to the Handle (grip) at the origin, so the rod stands ~6.4
-- studs tall along +Y. The caller decides the use: RodToolService moves
-- the parts into a Tool (unanchored + welded), ShopClient drops the
-- whole Model into a ViewportFrame.
function RodModelFactory.BuildRodModel(rodId)
	local def = GameConfig.Rods[rodId] or GameConfig.Rods.Bamboo
	local colors = RodColors[rodId] or RodColors.Bamboo
	local model = Instance.new("Model")
	model.Name = def.Name
	-- Grip the hand holds (the Tool's Handle), 1.4 tall.
	MakePart(model, "Handle", Vector3.new(0.35, 1.4, 0.35), CFrame.new(0, 0, 0), colors.Grip, Enum.Material.Wood)
	-- Shaft: 5-stud cylinder along +Y from the top of the grip.
	MakePart(model, "Shaft", Vector3.new(5, 0.18, 0.18), CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), colors.Shaft, colors.Material, Enum.PartType.Cylinder)
	-- Tip: thin lighter section at the top.
	MakePart(model, "Tip", Vector3.new(0.8, 0.1, 0.1), CFrame.new(0, 6.0, 0) * CFrame.Angles(0, 0, math.rad(90)), colors.Shaft, colors.Material, Enum.PartType.Cylinder)
	-- Reel body on the front of the grip + a small crank knob.
	MakePart(model, "Reel", Vector3.new(0.5, 0.5, 0.35), CFrame.new(0, 0.45, 0.32), colors.Reel, Enum.Material.Metal)
	MakePart(model, "ReelKnob", Vector3.new(0.35, 0.14, 0.14), CFrame.new(0.4, 0.45, 0.32), colors.Reel, Enum.Material.Metal, Enum.PartType.Cylinder)
	model.PrimaryPart = model:FindFirstChild("Handle")
	return model
end

return RodModelFactory
