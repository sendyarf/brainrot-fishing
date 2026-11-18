-- ShopClient: the shop panel. Rods, baits, tank slots and fishing spots, all
-- priced from GameConfig. Buttons reflect what the player owns (EQUIPPED /
-- OWNED / BUY / locked-behind-previous-tier). Buys go to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
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

-- One shop row: name + effect on the left, price + button on the right.
local function MakeRow(parent, y, name, effect, buttonText, buttonColor, onBuy)
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
	UIHelpers.NewLabel(row, "Name", name, UDim2.new(0.42, 0, 0.55, 0), UDim2.new(0, 12, 0, 4), 18, UIHelpers.TextWhite)
	UIHelpers.NewLabel(row, "Effect", effect, UDim2.new(0.6, 0, 0.4, 0), UDim2.new(0, 12, 0.55, 0), 14, UIHelpers.TextDim)
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
		if thisIndex < myIndex then
			MakeRow(scroll, y, rod.Name, effect, "OWNED", Color3.fromRGB(90, 90, 100), nil)
		elseif thisIndex == myIndex then
			MakeRow(scroll, y, rod.Name, effect, "EQUIPPED", Color3.fromRGB(40, 160, 80), nil)
		elseif thisIndex == myIndex + 1 then
			MakeRow(scroll, y, rod.Name, effect, UIHelpers.FormatMoney(rod.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("rod", rodId)
			end)
		else
			MakeRow(scroll, y, rod.Name, effect, "LOCKED", Color3.fromRGB(90, 90, 100), nil)
		end
		y = y + 62
	end

	y = MakeSectionTitle(scroll, y, "BAITS")
	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local myIndex = BaitIndex(state.Bait)
		local thisIndex = BaitIndex(baitId)
		local effect = "Luck +" .. bait.Luck .. "%"
		if thisIndex < myIndex then
			MakeRow(scroll, y, bait.Name, effect, "OWNED", Color3.fromRGB(90, 90, 100), nil)
		elseif thisIndex == myIndex then
			MakeRow(scroll, y, bait.Name, effect, "EQUIPPED", Color3.fromRGB(40, 160, 80), nil)
		elseif thisIndex == myIndex + 1 then
			MakeRow(scroll, y, bait.Name, effect, UIHelpers.FormatMoney(bait.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("bait", baitId)
			end)
		else
			MakeRow(scroll, y, bait.Name, effect, "LOCKED", Color3.fromRGB(90, 90, 100), nil)
		end
		y = y + 62
	end

	y = MakeSectionTitle(scroll, y, "TANK SLOTS")
	if state.TankSlots >= GameConfig.MaxTankSlots then
		MakeRow(scroll, y, "Tank Slot", "You have all 12 tanks.", "MAX", Color3.fromRGB(90, 90, 100), nil)
	else
		local priceIndex = state.TankSlots - GameConfig.StartTankSlots + 1
		local price = GameConfig.TankSlotPrices[priceIndex] or 0
		MakeRow(scroll, y, "Tank Slot (" .. state.TankSlots .. " -> " .. (state.TankSlots + 1) .. ")", "Room for one more fish.", UIHelpers.FormatMoney(price), Color3.fromRGB(50, 90, 200), function()
			GetRemote("BuyItem"):FireServer("slot", "")
		end)
	end
	y = y + 62

	y = MakeSectionTitle(scroll, y, "FISHING SPOTS")
	for _, spotId in ipairs({ "Deep", "Abyss" }) do
		local spot = GameConfig.Spots[spotId]
		local owned = state.Spots and state.Spots[spotId]
		local effect = "Rarer fish: Mythic " .. spot.Rates.Mythic .. "% (was " .. GameConfig.Spots.Shallow.Rates.Mythic .. "%)"
		if owned then
			MakeRow(scroll, y, spot.Name, effect, "OWNED", Color3.fromRGB(40, 160, 80), nil)
		else
			MakeRow(scroll, y, spot.Name, effect, UIHelpers.FormatMoney(spot.Price), Color3.fromRGB(50, 90, 200), function()
				GetRemote("BuyItem"):FireServer("spot", spotId)
			end)
		end
		y = y + 62
	end
	y = MakeSectionTitle(scroll, y, "ROYAL POND")
	MakeRow(scroll, y, "Royal Pond", "Mythic 10%! Opens with your first Rebirth.", state.Rebirths >= 1 and "OPEN" or "REBIRTH", state.Rebirths >= 1 and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(90, 90, 100), nil)
	y = y + 62

	scroll.CanvasSize = UDim2.new(0, 0, 0, y)
end

function ShopClient.Toggle()
	isOpen = not isOpen
	if isOpen then
		RefreshShop()
	end
	if panel then
		panel.Visible = isOpen
	end
end

function ShopClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")
	panel = UIHelpers.NewPanel(gui, "ShopPanel", UDim2.fromOffset(660, 480), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
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
