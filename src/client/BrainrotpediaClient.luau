-- BrainrotpediaClient: the collection dex. A 3x3 grid of the 9 fish: caught
-- fish show in full color with their best $/s; uncaught fish are dark
-- silhouettes with "???". Catching all 9 pays the $2,000 Master Angler bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local BrainrotpediaClient = {}

local player = Players.LocalPlayer
local panel = nil
local grid = nil
local headerLabel = nil
local isOpen = false

-- A tiny fish icon: body oval + tail diamond + eye (or a dark silhouette
-- when uncaught). The old plain grey oval read as a blob, not a fish.
local function MakeFishIcon(parent, def, discovered)
	local icon = Instance.new("Frame")
	icon.Name = "FishIcon"
	icon.Size = UDim2.fromOffset(64, 34)
	icon.Position = UDim2.new(0.5, 0, 0, 10)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Parent = parent
	local bodyColor = discovered and def.BodyColor or Color3.fromRGB(40, 40, 55)
	local accentColor = discovered and def.AccentColor or Color3.fromRGB(40, 40, 55)
	local tail = Instance.new("Frame")
	tail.Size = UDim2.fromOffset(16, 16)
	tail.Position = UDim2.new(0, 0, 0.5, 0)
	tail.AnchorPoint = Vector2.new(0, 0.5)
	tail.Rotation = 45
	tail.BackgroundColor3 = accentColor
	tail.BorderSizePixel = 0
	tail.Parent = icon
	local body = Instance.new("Frame")
	body.Size = UDim2.fromOffset(46, 30)
	body.Position = UDim2.new(0, 12, 0.5, 0)
	body.AnchorPoint = Vector2.new(0, 0.5)
	body.BackgroundColor3 = bodyColor
	body.BorderSizePixel = 0
	body.Parent = icon
	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0.5, 0)
	bodyCorner.Parent = body
	if discovered then
		local eye = Instance.new("Frame")
		eye.Size = UDim2.fromOffset(8, 8)
		eye.Position = UDim2.new(0, 46, 0, 8)
		eye.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		eye.BorderSizePixel = 0
		eye.Parent = icon
		local eyeCorner = Instance.new("UICorner")
		eyeCorner.CornerRadius = UDim.new(0.5, 0)
		eyeCorner.Parent = eye
		local pupil = Instance.new("Frame")
		pupil.Size = UDim2.fromOffset(4, 4)
		pupil.Position = UDim2.new(0, 48, 0, 10)
		pupil.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		pupil.BorderSizePixel = 0
		pupil.Parent = icon
		local pupilCorner = Instance.new("UICorner")
		pupilCorner.CornerRadius = UDim.new(0.5, 0)
		pupilCorner.Parent = pupil
	end
	return icon
end

local function RefreshDex()
	if not grid then
		return
	end
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local state = ClientState.Get()
	local collection = state.Collection or {}
	local caught = 0
	for _ in pairs(collection) do
		caught = caught + 1
	end
	headerLabel.Text = "BRAINROTPEDIA  " .. caught .. "/9"
	for i, fishId in ipairs(FishDefinitions.AllFishIds) do
		local def = FishDefinitions.Fish[fishId]
		local best = collection[fishId]
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(190, 118)
		card.Position = UDim2.new(0, 10 + col * 200, 0, 10 + row * 128)
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
		MakeFishIcon(card, def, best ~= nil)
		UIHelpers.NewLabel(card, "Name", best and def.Name or "???", UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 0, 50), 17, best and UIHelpers.TextWhite or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
		UIHelpers.NewLabel(card, "Rarity", best and def.Rarity:upper() or "UNDISCOVERED", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 76), 14, best and FishDefinitions.RarityColors[def.Rarity] or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
		UIHelpers.NewLabel(card, "Income", best and ("Best: " .. UIHelpers.FormatMoney(best) .. "/s") or "Catch it to reveal", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 96), 13, best and UIHelpers.AccentGreen or UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
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
	headerLabel = UIHelpers.NewLabel(panel, "Title", "BRAINROTPEDIA  0/9", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), 24, UIHelpers.AccentGold)
	headerLabel.TextXAlignment = Enum.TextXAlignment.Center
	local closeButton = UIHelpers.NewButton(panel, "Close", "X", UDim2.fromOffset(36, 36), UDim2.new(1, -10, 0, 8), Color3.fromRGB(200, 60, 60), 18, Vector2.new(1, 0))
	closeButton.MouseButton1Click:Connect(function()
		BrainrotpediaClient.Toggle()
	end)
	UIHelpers.NewLabel(panel, "Bonus", "Catch all 9 fish: +" .. UIHelpers.FormatMoney(GameConfig.CollectionBonus) .. " and the MASTER ANGLER title!", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 46), 15, UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
	-- The grid scrolls: on a short viewport the fitted panel is too small
	-- for all 3 card rows, and the bottom row used to be cut off.
	grid = Instance.new("ScrollingFrame")
	grid.Name = "DexGrid"
	grid.Size = UDim2.new(1, -20, 1, -80)
	grid.Position = UDim2.new(0, 10, 0, 74)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new(0, 0, 0, 394)
	grid.Parent = panel
	ClientState.Changed.Event:Connect(function()
		if isOpen then
			RefreshDex()
		end
	end)
end

return BrainrotpediaClient
