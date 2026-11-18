-- ShopService: every purchase is validated on the server (balance, ownership,
-- ordering) before anything changes. The client only asks; the server decides.
-- Functions: BuyRod, BuyBait, BuyTankSlot, BuyFishingSpot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local ShopService = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function NotifyPurchase(player, success, message)
	GetRemote("ShopResult"):FireClient(player, { Success = success, Message = message })
end

-- Returns the rod's index in the upgrade order (Bamboo = 1).
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

-- Buys a rod (must be the next tier up; rods are a ladder, not a menu).
function ShopService.BuyRod(player, rodId)
	local data = DataService.GetData(player)
	local rod = GameConfig.Rods[rodId]
	if not data or not rod then
		return
	end
	if RodIndex(rodId) <= RodIndex(data.Rod) then
		NotifyPurchase(player, false, "You already own that rod or better.")
		return
	end
	if RodIndex(rodId) > RodIndex(data.Rod) + 1 then
		NotifyPurchase(player, false, "Buy the previous rod first.")
		return
	end
	if not EconomyService.SpendCash(player, rod.Price) then
		NotifyPurchase(player, false, "Not enough cash.")
		return
	end
	data.Rod = rodId
	DataService.BroadcastState(player)
	NotifyPurchase(player, true, rod.Name .. " equipped! Luck +" .. rod.Luck .. "%.")
end

-- Buys a bait (same ladder rule as rods).
function ShopService.BuyBait(player, baitId)
	local data = DataService.GetData(player)
	local bait = GameConfig.Baits[baitId]
	if not data or not bait then
		return
	end
	if BaitIndex(baitId) <= BaitIndex(data.Bait) then
		NotifyPurchase(player, false, "You already own that bait or better.")
		return
	end
	if BaitIndex(baitId) > BaitIndex(data.Bait) + 1 then
		NotifyPurchase(player, false, "Buy the previous bait first.")
		return
	end
	if not EconomyService.SpendCash(player, bait.Price) then
		NotifyPurchase(player, false, "Not enough cash.")
		return
	end
	data.Bait = baitId
	DataService.BroadcastState(player)
	NotifyPurchase(player, true, bait.Name .. " equipped! Luck +" .. bait.Luck .. "%.")
end

-- Buys one more tank slot (sequential prices, max 12 slots).
function ShopService.BuyTankSlot(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	if data.TankSlots >= GameConfig.MaxTankSlots then
		NotifyPurchase(player, false, "Your aquarium is full (12 tanks).")
		return
	end
	local priceIndex = data.TankSlots - GameConfig.StartTankSlots + 1
	local price = GameConfig.TankSlotPrices[priceIndex]
	if not price then
		return
	end
	if not EconomyService.SpendCash(player, price) then
		NotifyPurchase(player, false, "Not enough cash.")
		return
	end
	data.TankSlots = data.TankSlots + 1
	DataService.BroadcastState(player)
	NotifyPurchase(player, true, "New tank slot! You now have " .. data.TankSlots .. " tanks.")
end

-- Buys a fishing spot (Deep Dock $500, Abyss Point $2,500; permanent).
function ShopService.BuyFishingSpot(player, spotId)
	local data = DataService.GetData(player)
	local spot = GameConfig.Spots[spotId]
	if not data or not spot then
		return
	end
	if spotId == "Shallow" or spotId == "Royal" then
		NotifyPurchase(player, false, "That spot can't be bought here.")
		return
	end
	if data.Spots[spotId] then
		NotifyPurchase(player, false, "You already own that spot.")
		return
	end
	if not EconomyService.SpendCash(player, spot.Price) then
		NotifyPurchase(player, false, "Not enough cash.")
		return
	end
	data.Spots[spotId] = true
	DataService.BroadcastState(player)
	NotifyPurchase(player, true, spot.Name .. " unlocked! Better fish await.")
end

return ShopService
