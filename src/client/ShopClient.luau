-- ShopClient — the shop panel: rods, baits, tank slots and fishing
-- spots, each with its price and effect. Buying fires BuyItem to the
-- server, which validates the balance and applies the upgrade. The panel
-- rebuilds on every open so prices and owned states stay current.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientState = require(script.Parent.ClientState)
local UIHelpers = require(script.Parent.UIHelpers)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ShopClient = {}

local player = Players.LocalPlayer
local remotes = nil
local shopFrame = nil
local shopOpen = false

function ShopClient.Init(remoteFolder)
	remotes = remoteFolder
end

local function makeShopRow(parent, y, title, detail, priceText, owned, onBuy)
	local row = UIHelpers.MakeFrame(parent, UDim2.new(1, -16, 0, 56), UDim2.new(0, 8, 0, y),
		Color3.fromRGB(35, 42, 60), 0.1)
	UIHelpers.MakeLabel(row, UDim2.new(0.55, 0, 0, 26), UDim2.new(0, 10, 0, 4), title, 18)
	local detailLabel = UIHelpers.MakeLabel(row, UDim2.new(0.55, 0, 0, 22), UDim2.new(0, 10, 0, 28), detail, 14, UIHelpers.MUTED)
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	local button = UIHelpers.MakeButton(row, UDim2.new(0, 120, 0, 36), UDim2.new(1, -130, 0, 10),
		owned and "OWNED" or priceText, 16)
	if owned then
		button.BackgroundColor3 = Color3.fromRGB(90, 140, 90)
		button.Active = false
	else
		button.MouseButton1Click:Connect(onBuy)
	end
	return row
end

local function buildShop()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("ShopUI")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "ShopUI"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui
	end
	if shopFrame then
		shopFrame:Destroy()
	end
	shopFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 520, 0, 560), UDim2.new(0.5, -260, 0.5, -280))
	UIHelpers.MakeLabel(shopFrame, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), "SHOP", 28, UIHelpers.ACCENT)
	local closeButton = UIHelpers.MakeButton(shopFrame, UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8), "X", 20)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.MouseButton1Click:Connect(function()
		ShopClient.ToggleShop()
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -8, 1, -60)
	scroll.Position = UDim2.new(0, 4, 0, 56)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 900)
	scroll.Parent = shopFrame

	local state = ClientState.Get()
	local y = 0
	local function section(title)
		UIHelpers.MakeLabel(scroll, UDim2.new(1, 0, 0, 30), UDim2.new(0, 8, 0, y), title, 20, UIHelpers.ACCENT)
		y += 32
	end

	section("RODS")
	for _, rod in ipairs(GameConfig.RODS) do
		local owned = state.rod == rod.id
		local detail = "Luck +" .. rod.luck .. "%"
		if rod.perfectBonus > 0 then
			detail = detail .. " · Perfect +" .. math.floor(rod.perfectBonus * 100) .. "% wider"
		end
		if rod.mythicBoost > 1 then
			detail = detail .. " · Mythic chance x2"
		end
		makeShopRow(scroll, y, rod.name, detail, UIHelpers.FormatCash(rod.price), owned, function()
			remotes.BuyItem:FireServer("rod", rod.id)
			task.wait(0.3)
			if shopOpen then
				buildShop()
			end
		end)
		y += 62
	end

	section("BAITS")
	for _, bait in ipairs(GameConfig.BAITS) do
		local owned = state.bait == bait.id
		makeShopRow(scroll, y, bait.name, "Luck +" .. bait.luck .. "%", UIHelpers.FormatCash(bait.price), owned, function()
			remotes.BuyItem:FireServer("bait", bait.id)
			task.wait(0.3)
			if shopOpen then
				buildShop()
			end
		end)
		y += 62
	end

	section("TANK SLOTS")
	local priceIndex = state.tankSlots - GameConfig.STARTING_TANK_SLOTS + 1
	local slotPrice = GameConfig.TANK_SLOT_PRICES[priceIndex]
	if slotPrice then
		makeShopRow(scroll, y, "Extra Tank Slot", "Base capacity " .. state.tankSlots .. " -> " .. (state.tankSlots + 1),
			UIHelpers.FormatCash(slotPrice), false, function()
				remotes.BuyItem:FireServer("slot", "")
				task.wait(0.3)
				if shopOpen then
					buildShop()
				end
			end)
		y += 62
	else
		UIHelpers.MakeLabel(scroll, UDim2.new(1, 0, 0, 30), UDim2.new(0, 8, 0, y), "Max tanks reached (12)", 16, UIHelpers.MUTED)
		y += 34
	end

	section("FISHING SPOTS")
	for _, spotId in ipairs({ "deep", "abyss" }) do
		local spot = GameConfig.GetSpotById(spotId)
		local owned = state.spots[spotId] == true
		local odds = spot.odds
		local detail = "Mythic " .. odds.Mythic .. "% · Legendary " .. odds.Legendary .. "%"
		makeShopRow(scroll, y, spot.name, detail, UIHelpers.FormatCash(spot.price), owned, function()
			remotes.BuyItem:FireServer("spot", spotId)
			task.wait(0.3)
			if shopOpen then
				buildShop()
			end
		end)
		y += 62
	end
	-- Royal Pond is earned by rebirth, not bought.
	local royalOwned = state.rebirths >= 1
	makeShopRow(scroll, y, "Royal Pond", "Mythic 10% · Legendary 20%", royalOwned and "OPEN" or "REBIRTH",
		royalOwned, function() end)
	y += 62

	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

function ShopClient.ToggleShop()
	shopOpen = not shopOpen
	if shopOpen then
		buildShop()
	elseif shopFrame then
		shopFrame.Visible = false
		shopFrame:Destroy()
		shopFrame = nil
	end
end

return ShopClient
