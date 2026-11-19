-- RodModelFactory — builds the fishing rod Tool a player holds.
-- Each rod tier gets its own look: bamboo is plain wood, the Dragon Rod
-- glows red with a golden reel. The tool's Handle is the grip; the shaft
-- points forward when equipped. RodToolService hands these out on spawn.

local GameConfig = require(script.Parent.GameConfig)

local RodModelFactory = {}

local ROD_LOOKS = {
	bamboo = { shaft = Color3.fromRGB(190, 160, 110), grip = Color3.fromRGB(140, 100, 60), reel = Color3.fromRGB(120, 120, 120), glow = false },
	wooden = { shaft = Color3.fromRGB(150, 105, 60), grip = Color3.fromRGB(100, 70, 40), reel = Color3.fromRGB(140, 140, 140), glow = false },
	steel = { shaft = Color3.fromRGB(170, 180, 190), grip = Color3.fromRGB(60, 60, 70), reel = Color3.fromRGB(200, 200, 210), glow = false },
	golden = { shaft = Color3.fromRGB(240, 200, 80), grip = Color3.fromRGB(120, 80, 30), reel = Color3.fromRGB(255, 220, 100), glow = true },
	dragon = { shaft = Color3.fromRGB(180, 50, 40), grip = Color3.fromRGB(40, 30, 30), reel = Color3.fromRGB(255, 200, 60), glow = true },
}

-- Builds a Tool for the given rod id. Returns the Tool, unparented.
function RodModelFactory.BuildRodTool(rodId)
	local rod = GameConfig.GetRodById(rodId)
	local look = ROD_LOOKS[rod.id] or ROD_LOOKS.bamboo

	local tool = Instance.new("Tool")
	tool.Name = rod.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false

	-- Grip (the Handle the hand holds).
	local grip = Instance.new("Part")
	grip.Name = "Handle"
	grip.Size = Vector3.new(0.3, 0.3, 1.4)
	grip.Color = look.grip
	grip.Material = Enum.Material.Wood
	grip.CanCollide = false
	grip.Parent = tool

	-- Shaft, angled up from the grip.
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.14, 0.14, 4.2)
	shaft.Color = look.shaft
	shaft.Material = look.glow and Enum.Material.Metal or Enum.Material.Wood
	shaft.CanCollide = false
	shaft.CFrame = CFrame.new(0, 0.9, -2.2) * CFrame.Angles(math.rad(-35), 0, 0)
	shaft.Parent = tool

	-- Reel at the base of the shaft.
	local reel = Instance.new("Part")
	reel.Name = "Reel"
	reel.Shape = Enum.PartType.Cylinder
	reel.Size = Vector3.new(0.4, 0.5, 0.5)
	reel.Color = look.reel
	reel.Material = Enum.Material.Metal
	reel.CanCollide = false
	reel.CFrame = CFrame.new(0.25, 0.2, -0.6)
	reel.Parent = tool

	-- Tip guide ring.
	local tip = Instance.new("Part")
	tip.Name = "TipGuide"
	tip.Size = Vector3.new(0.2, 0.2, 0.2)
	tip.Color = look.reel
	tip.Material = Enum.Material.Metal
	tip.CanCollide = false
	tip.CFrame = CFrame.new(0, 2.3, -3.9)
	tip.Parent = tool

	-- Weld the parts together so the tool holds its shape.
	for _, part in ipairs({ shaft, reel, tip }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = grip
		weld.Part1 = part
		weld.Parent = grip
	end

	if look.glow then
		local light = Instance.new("PointLight")
		light.Color = rod.id == "dragon" and Color3.fromRGB(255, 100, 60) or Color3.fromRGB(255, 220, 120)
		light.Range = 5
		light.Brightness = 1
		light.Parent = reel
	end

	return tool
end

return RodModelFactory
