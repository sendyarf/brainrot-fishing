-- ShopClient: the shop panel. Rods, baits, tank slots and fishing spots, all
-- priced from GameConfig. Buttons reflect what the player owns (EQUIPPED /
-- OWNED / BUY / locked-behind-previous-tier). Buys go to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local RodModelFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RodModelFactory"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local ShopClient = {}

local player = Players.LocalPlayer
local panel = nil
local scroll = nil
local isOpen = false

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function RodIndex(rodId)
	for i, id in ipairs(GameConfig.RodOrder) do
		if id == rodId then
			return i
		end
	end
	return 1
end

local function BaitIndex(baitId)
	for i, id in ipairs(GameConfig.BaitOrder) do
		if id == baitId then
			return i
		end
	end
	return 1
end

-- A 48x48 ViewportFrame showing the item's real 3D model (fix 12: the
-- Dex shows the fish in 3D, the shop showed nothing). The camera fits
-- the model's bounding box, so a 6-stud rod and a 1-stud bait both fill
-- the frame. Same lighting as the Dex.
local function MakePreview(parent, model)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ItemPreview"
	viewport.Size = UDim2.fromOffset(48, 48)
	viewport.Position = UDim2.new(0, 4, 0, 4)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0, -1, 0)
	viewport.Parent = parent
	if model then
		model.Parent = viewport
		local cframe, size = model:GetBoundingBox()
		local center = cframe.Position
		local maxDim = math.max(size.X, size.Y, size.Z)
		-- Distance so the model fills the frame at FOV 40 (half-FOV 20).
		local dist = (maxDim / 2) / math.tan(math.rad(20)) * 1.15
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(center + Vector3.new(1, 0.5, 1.3).Unit * dist, center)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	return viewport
end

-- Tiny voxel bait models (only the shop shows baits, so they live here).
local function BuildBaitModel(baitId)
	local model = Instance.new("Model")
	model.Name = baitId
	local function Box(name, size, pos, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = pos
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		return part
	end
	if baitId == "Bread" then
		Box("Loaf", Vector3.new(1.2, 0.7, 0.9), Vector3.new(0, 0, 0), Color3.fromRGB(235, 200, 130))
		Box("Crust", Vector3.new(1.2, 0.25, 0.9), Vector3.new(0, 0.4, 0), Color3.fromRGB(190, 140, 70))
	elseif baitId == "Worm" then
		Box("Seg1", Vector3.new(0.5, 0.4, 0.4), Vector3.new(-0.5, 0, 0), Color3.fromRGB(255, 150, 160))
		Box("Seg2", Vector3.new(0.5, 0.4, 0.4), Vector3.new(0, 0.15, 0), Color3.fromRGB(240, 130, 145))
		Box("Seg3", Vector3.new(0.5, 0.4, 0.4), Vector3.new(0.5, 0, 0), Color3.fromRGB(255, 150, 160))
	elseif baitId == "Shiny" then
		Box("Lure", Vector3.new(1, 0.5, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(200, 220, 255), Enum.Material.Metal)
		Box("Hook", Vector3.new(0.3, 0.5, 0.2), Vector3.new(0.6, -0.3, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
		Box("Eye", Vector3.new(0.2, 0.2, 0.5), Vector3.new(-0.35, 0.1, 0), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	else -- Dragon
		local orb = Box("Orb", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0, 0), Color3.fromRGB(200, 40, 50), Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		Box("SpikeT", Vector3.new(0.25, 0.5, 0.25), Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 200, 80))
		Box("SpikeL", Vector3.new(0.5, 0.25, 0.25), Vector3.new(-0.6, 0, 0), Color3.fromRGB(255, 200, 80))
		Box("SpikeR", Vector3.new(0.5, 0.25, 0.25), Vector3.new(0.6, 0, 0), Color3.fromRGB(255, 200, 80))
	end
	return model
end

-- A mini tank (glass + water) for the tank-slot row.
local function BuildTankModel()
	local model = Instance.new("Model")
	model.Name = "Tank"
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = Vector3.new(1.2, 1.2, 1.2)
	glass.Position = Vector3.new(0, 0, 0)
	glass.Color = Color3.fromRGB(200, 230, 255)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.4
	glass.Anchored = true
	glass.CanCollide = false
	glass.Parent = model
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(1, 0.9, 1)
	water.Position = Vector3.new(0, -0.1, 0)
	water.Color = Color3.fromRGB(60, 160, 220)
	water.Transparency = 0.3
	water.Anchored = true
	water.CanCollide = false
	water.Parent = model
	return model
end

-- A mini water disc in the spot's color for the spot rows.
local function BuildSpotModel(spotId)
	local spot = GameConfig.Spots[spotId]
	local model = Instance.new("Model")
	model.Name = spotId
	local disc = Instance.new("Part")
	disc.Name = "Water"
	disc.Size = Vector3.new(0.3, 1.6, 1.6)
	disc.Position = Vector3.new(0, 0, 0)
	disc.Color = spot and spot.WaterColor or Color3.fromRGB(60, 160, 220)
	disc.Material = Enum.Material.Neon
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.Parent = model
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Size = Vector3.new(0.5, 0.5, 0.5)
	rock.Position = Vector3.new(0.5, 0.3, 0.3)
	rock.Color = Color3.fromRGB(120, 120, 130)
	rock.Anchored = true
	rock.CanCollide = false
	rock.Parent = model
	return model
end

-- One shop row: 3D preview on the left, name + effect, price + button on
-- the right. `previewModel` may be nil (no preview for that row).
local function MakeRow(parent, y, name, effect, buttonText, buttonColor, onBuy, previewModel)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 56)
	row.Position = UDim2.new(0, 8, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(30, 38, 66)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row
	if previewModel then
		MakePreview(row, previewModel)
	end
	UIHelpers.NewLabel(row, "Name", name, UDim2.new(0.42, 0, 0.55, 0), UDim2.new(0, 60, 0, 4), 18, UIHelpers.TextWhite)
	UIHelpers.NewLabel(row, "Effect", effect, UDim2.new(0.6, 0, 0.4, 0), UDim2.new(0, 60, 0.55, 0), 14, UIHelpers.TextDim)
	local button = UIHelpers.NewButton(row, "Buy", buttonText, UDim2.fromOffset(130, 38), UDim2.new(1, -10, 0.5, 0), buttonColor, 16, Vector2.new(1, 0.5))
	if onBuy then
		button.MouseButton1Click:Connect(onBuy)
	end
	return row
end

local function MakeSectionTitle(parent, y, text)
	UIHelpers.NewLabel(parent, "Section" .. text, text, UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, y), 18, UIHelpers.AccentGold)
	return y + 32
end

-- Rebuilds the whole shop list from the current state.
local function RefreshShop()
	if not scroll then
		return
	end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local state = ClientState.Get()
	local y = 8

	y = MakeSectionTitle(scroll, y, "FISHING RODS")
	for _, rodId in ipairs(GameConfig.RodOrder) do
		local rod = GameConfig.Rods[rodId]
		local myIndex = RodIndex(state.Rod)
		local thisIndex = RodIndex(rodId)
		local effect = "Luck +" .. rod.Luck .. "%"
		if rod.PerfectBonus > 0 then
			effect = effect .. "  ·  Perfect zone +" .. rod.PerfectBonus .. "% wider"
		end
		if rod.MythicMult > 1 then
			effect = effect .. "  ·  Mythic chance x2"
		end
		local preview = RodModelFactory.BuildRodModel(rodId)
		if thisIndex < myIndex then
			MakeRow(scroll, y, rod.Name, effect, "OWNED", Color3.fromRGB(90, 90, 100), nil, preview)
		elseif thisIndex == myIndex then
			MakeRow(scroll, y, rod.Name, effect, "EQUIPPED", Color3.fromRGB(40, 160, 80), nil, preview)
		elseif thisIndex == myIndex + 1 then
			MakeRow(scroll, y, rod.Name, effect, UIHelpers.FormatMoney(rod.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("rod", rodId)
			end, preview)
		else
			MakeRow(scroll, y, rod.Name, effect, "LOCKED", Color3.fromRGB(90, 90, 100), nil, preview)
		end
		y = y + 62
	end

	y = MakeSectionTitle(scroll, y, "BAITS")
	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local myIndex = BaitIndex(state.Bait)
		local thisIndex = BaitIndex(baitId)
		local effect = "Luck +" .. bait.Luck .. "%"
		local preview = BuildBaitModel(baitId)
		if thisIndex < myIndex then
			MakeRow(scroll, y, bait.Name, effect, "OWNED", Color3.fromRGB(90, 90, 100), nil, preview)
		elseif thisIndex == myIndex then
			MakeRow(scroll, y, bait.Name, effect, "EQUIPPED", Color3.fromRGB(40, 160, 80), nil, preview)
		elseif thisIndex == myIndex + 1 then
			MakeRow(scroll, y, bait.Name, effect, UIHelpers.FormatMoney(bait.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("bait", baitId)
			end, preview)
		else
			MakeRow(scroll, y, bait.Name, effect, "LOCKED", Color3.fromRGB(90, 90, 100), nil, preview)
		end
		y = y + 62
	end

	y = MakeSectionTitle(scroll, y, "TANK SLOTS")
	if state.TankSlots >= GameConfig.MaxTankSlots then
		MakeRow(scroll, y, "Tank Slot", "You have all 12 tanks.", "MAX", Color3.fromRGB(90, 90, 100), nil, BuildTankModel())
	else
		local priceIndex = state.TankSlots - GameConfig.StartTankSlots + 1
		local price = GameConfig.TankSlotPrices[priceIndex] or 0
		MakeRow(scroll, y, "Tank Slot (" .. state.TankSlots .. " -> " .. (state.TankSlots + 1) .. ")", "Room for one more fish.", UIHelpers.FormatMoney(price), Color3.fromRGB(50, 90, 200), function()
			GetRemote("BuyItem"):FireServer("slot", "")
		end, BuildTankModel())
	end
	y = y + 62

	y = MakeSectionTitle(scroll, y, "FISHING SPOTS")
	for _, spotId in ipairs({ "Deep", "Abyss" }) do
		local spot = GameConfig.Spots[spotId]
		local owned = state.Spots and state.Spots[spotId]
		local effect = "Rarer fish: Mythic " .. spot.Rates.Mythic .. "% (was " .. GameConfig.Spots.Shallow.Rates.Mythic .. "%)"
		if owned then
			MakeRow(scroll, y, spot.Name, effect, "OWNED", Color3.fromRGB(40, 160, 80), nil, BuildSpotModel(spotId))
		else
			MakeRow(scroll, y, spot.Name, effect, UIHelpers.FormatMoney(spot.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("spot", spotId)
			end, BuildSpotModel(spotId))
		end
		y = y + 62
	end
	y = MakeSectionTitle(scroll, y, "ROYAL POND")
	MakeRow(scroll, y, "Royal Pond", "Mythic 10%! Opens with your first Rebirth.", state.Rebirths >= 1 and "OPEN" or "REBIRTH", state.Rebirths >= 1 and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(90, 90, 100), nil, BuildSpotModel("Royal"))
	y = y + 62

	scroll.CanvasSize = UDim2.new(0, 0, 0, y)
end

function ShopClient.Toggle()
	isOpen = not isOpen
	if isOpen then
		-- Re-fit every time the panel opens: the viewport is guaranteed
		-- valid now, even if it was (0,0) when the panel was created.
		if panel then
			panel.Size = UIHelpers.FitPanelSize(660, 480)
		end
		RefreshShop()
	end
	if panel then
		panel.Visible = isOpen
	end
end

function ShopClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")
	panel = UIHelpers.NewPanel(gui, "ShopPanel", UIHelpers.FitPanelSize(660, 480), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	panel.Visible = false
	UIHelpers.NewLabel(panel, "Title", "SHOP", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), 26, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	local closeButton = UIHelpers.NewButton(panel, "Close", "X", UDim2.fromOffset(36, 36), UDim2.new(1, -10, 0, 8), Color3.fromRGB(200, 60, 60), 18, Vector2.new(1, 0))
	closeButton.MouseButton1Click:Connect(function()
		ShopClient.Toggle()
	end)
	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ShopList"
	scroll.Size = UDim2.new(1, -16, 1, -60)
	scroll.Position = UDim2.new(0, 8, 0, 52)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 800)
	scroll.Parent = panel
	-- Rows are positioned manually in RefreshShop (no UIListLayout: it would
	-- override the computed y positions and scramble the section order).
	ClientState.Changed.Event:Connect(function()
		if isOpen then
			RefreshShop()
		end
	end)
end

return ShopClient
