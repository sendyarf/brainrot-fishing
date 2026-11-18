-- BrainrotpediaClient: the collection dex. A 3-column grid of all 12
-- brainrot: each card shows the SAME 3D voxel model that swims in the
-- tanks (a ViewportFrame built by the shared FishModelFactory), so the dex
-- and the base never disagree — like the top-1 game, where the dex and the
-- pen show the same object. Caught fish show in full color with their best
-- $/s; uncaught fish are dark silhouettes with "???". Catching all 12 pays
-- the $2,000 Master Angler bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local FishModelFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishModelFactory"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local BrainrotpediaClient = {}

local player = Players.LocalPlayer
local panel = nil
local grid = nil
local headerLabel = nil
local isOpen = false
local lastCollectionKey = nil

-- A ViewportFrame showing the fish's real 3D model (the same builder the
-- tanks use). Side view, slightly from the front: the fish's length reads
-- horizontally in the wide frame. Uncaught fish are silhouetted (all parts
-- dark) so the shape still shows but the colors stay a mystery.
local function MakeFishViewport(parent, fishId, discovered)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "FishViewport"
	viewport.Size = UDim2.fromOffset(170, 64)
	viewport.Position = UDim2.new(0.5, 0, 0, 8)
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0, -1, 0)
	viewport.Parent = parent
	local model = FishModelFactory.BuildFishModel(fishId, "None")
	if model then
		if not discovered then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = Color3.fromRGB(40, 40, 55)
					part.Material = Enum.Material.SmoothPlastic
					part.Transparency = 0
				end
			end
		end
		model.Parent = viewport
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(4.5, 0.8, 1.2), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

-- A fingerprint of the collection (which fish + best $/s each): RefreshDex
-- rebuilds 12 voxel models, so it only runs when the collection actually
-- changes, not on every money tick while the dex is open.
local function CollectionKey(collection)
	local parts = {}
	for _, fishId in ipairs(FishDefinitions.AllFishIds) do
		local best = collection[fishId]
		if best then
			table.insert(parts, fishId .. "=" .. best)
		end
	end
	return table.concat(parts, ",")
end

local function RefreshDex()
	if not grid then
		return
	end
	local state = ClientState.Get()
	local collection = state.Collection or {}
	local key = CollectionKey(collection)
	if key == lastCollectionKey then
		return
	end
	lastCollectionKey = key
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local caught = 0
	for _ in pairs(collection) do
		caught = caught + 1
	end
	local total = #FishDefinitions.AllFishIds
	headerLabel.Text = "BRAINROTPEDIA  " .. caught .. "/" .. total
	for i, fishId in ipairs(FishDefinitions.AllFishIds) do
		local def = FishDefinitions.Fish[fishId]
		local best = collection[fishId]
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(190, 128)
		card.Position = UDim2.new(0, 10 + col * 200, 0, 10 + row * 138)
		card.BackgroundColor3 = best and Color3.fromRGB(30, 38, 66) or Color3.fromRGB(15, 18, 32)
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.Parent = grid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = best and FishDefinitions.RarityColors[def.Rarity] or Color3.fromRGB(70, 70, 90)
		stroke.Thickness = 2
		stroke.Parent = card
		MakeFishViewport(card, fishId, best ~= nil)
		UIHelpers.NewLabel(card, "Name", best and def.Name or "???", UDim2.new(1, -12, 0, 22), UDim2.new(0, 6, 0, 74), 16, best and UIHelpers.TextWhite or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
		UIHelpers.NewLabel(card, "Rarity", best and def.Rarity:upper() or "UNDISCOVERED", UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 0, 94), 13, best and FishDefinitions.RarityColors[def.Rarity] or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
		UIHelpers.NewLabel(card, "Income", best and ("Best: " .. UIHelpers.FormatMoney(best) .. "/s") or "Catch it to reveal", UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 0, 110), 12, best and UIHelpers.AccentGreen or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
	end
end

function BrainrotpediaClient.Toggle()
	isOpen = not isOpen
	if isOpen then
		if panel then
			panel.Size = UIHelpers.FitPanelSize(640, 480)
		end
		RefreshDex()
	end
	if panel then
		panel.Visible = isOpen
	end
end

function BrainrotpediaClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")
	panel = UIHelpers.NewPanel(gui, "DexPanel", UIHelpers.FitPanelSize(640, 480), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	panel.Visible = false
	headerLabel = UIHelpers.NewLabel(panel, "Title", "BRAINROTPEDIA  0/" .. #FishDefinitions.AllFishIds, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), 24, UIHelpers.AccentGold)
	headerLabel.TextXAlignment = Enum.TextXAlignment.Center
	local closeButton = UIHelpers.NewButton(panel, "Close", "X", UDim2.fromOffset(36, 36), UDim2.new(1, -10, 0, 8), Color3.fromRGB(200, 60, 60), 18, Vector2.new(1, 0))
	closeButton.MouseButton1Click:Connect(function()
		BrainrotpediaClient.Toggle()
	end)
	UIHelpers.NewLabel(panel, "Bonus", "Catch all " .. #FishDefinitions.AllFishIds .. " fish: +" .. UIHelpers.FormatMoney(GameConfig.CollectionBonus) .. " and the MASTER ANGLER title!", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 46), 15, UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
	-- The grid scrolls: on a short viewport the fitted panel is too small
	-- for all 4 card rows, and the bottom row used to be cut off.
	grid = Instance.new("ScrollingFrame")
	grid.Name = "DexGrid"
	grid.Size = UDim2.new(1, -20, 1, -80)
	grid.Position = UDim2.new(0, 10, 0, 74)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new(0, 0, 0, 562)
	grid.Parent = panel
	ClientState.Changed.Event:Connect(function()
		if isOpen then
			RefreshDex()
		end
	end)
end

return BrainrotpediaClient
