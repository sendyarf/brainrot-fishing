-- ShopService — every purchase in the game, validated on the server.
-- Rods, baits, tank slots and fishing spots: the server checks the price
-- against the player's real balance and applies the upgrade. The client
-- only asks; it never grants anything to itself.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local ShopService = {}

local dataService = nil
local economyService = nil
local tankService = nil
local rodToolService = nil
local notifyEvent = nil

function ShopService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	tankService = deps.TankService
	rodToolService = deps.RodToolService
	notifyEvent = deps.Notify
end

local function notify(player, message)
	if notifyEvent then
		notifyEvent:FireClient(player, message)
	end
end

-- Buys a rod by id. Rods are permanent upgrades; buying an earlier rod
-- than the one owned is refused.
function ShopService.BuyRod(player, rodId)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	local rod = GameConfig.GetRodById(rodId)
	local current = GameConfig.GetRodById(data.rod)
	local rodIndex = table.find(GameConfig.RODS, rod) or 1
	local currentIndex = table.find(GameConfig.RODS, current) or 1
	if rodIndex <= currentIndex then
		notify(player, "You already own that rod or better.")
		return false
	end
	if not economyService.SpendCash(player, rod.price) then
		notify(player, "Not enough cash for the " .. rod.name .. ".")
		return false
	end
	data.rod = rod.id
	if rodToolService then
		rodToolService.GiveRodToPlayer(player)
	end
	notify(player, "Bought the " .. rod.name .. "! Luck +" .. rod.luck .. "%")
	return true
end

function ShopService.BuyBait(player, baitId)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	local bait = GameConfig.GetBaitById(baitId)
	local current = GameConfig.GetBaitById(data.bait)
	local baitIndex = table.find(GameConfig.BAITS, bait) or 1
	local currentIndex = table.find(GameConfig.BAITS, current) or 1
	if baitIndex <= currentIndex then
		notify(player, "You already own that bait or better.")
		return false
	end
	if not economyService.SpendCash(player, bait.price) then
		notify(player, "Not enough cash for " .. bait.name .. ".")
		return false
	end
	data.bait = bait.id
	notify(player, "Bought " .. bait.name .. "! Luck +" .. bait.luck .. "%")
	return true
end

function ShopService.BuyTankSlot(player)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	if data.tankSlots >= GameConfig.MAX_TANK_SLOTS then
		notify(player, "Your base already has the maximum tanks.")
		return false
	end
	local priceIndex = data.tankSlots - GameConfig.STARTING_TANK_SLOTS + 1
	local price = GameConfig.TANK_SLOT_PRICES[priceIndex]
	if not price then
		return false
	end
	if not economyService.SpendCash(player, price) then
		notify(player, "Not enough cash for a new tank slot.")
		return false
	end
	data.tankSlots += 1
	if tankService then
		tankService.AddTankSlot(player)
	end
	notify(player, "New tank slot! Your base now holds " .. data.tankSlots .. " tanks.")
	return true
end

function ShopService.BuyFishingSpot(player, spotId)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	local spot = GameConfig.GetSpotById(spotId)
	if spotId == "shallow" then
		notify(player, "Shallow Shore is always open.")
		return false
	end
	if spotId == "royal" then
		notify(player, "The Royal Pond opens after your first rebirth.")
		return false
	end
	if data.spots[spotId] then
		notify(player, "You already own " .. spot.name .. ".")
		return false
	end
	if not economyService.SpendCash(player, spot.price) then
		notify(player, "Not enough cash for " .. spot.name .. ".")
		return false
	end
	data.spots[spotId] = true
	notify(player, spot.name .. " unlocked! Better odds await.")
	return true
end

-- One entry point for the BuyItem RemoteEvent.
function ShopService.BuyItem(player, category, itemId)
	if category == "rod" then
		return ShopService.BuyRod(player, itemId)
	elseif category == "bait" then
		return ShopService.BuyBait(player, itemId)
	elseif category == "slot" then
		return ShopService.BuyTankSlot(player)
	elseif category == "spot" then
		return ShopService.BuyFishingSpot(player, itemId)
	end
	return false
end

return ShopService
