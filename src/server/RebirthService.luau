-- RebirthService — the prestige reset. At $25,000 cash a player can
-- rebirth: cash, rod, bait and bought spots reset, but every fish, the
-- collection, the tank slots and the rebirth multiplier stay. Each
-- rebirth adds +50% income (additive, up to x3.5 at 5 rebirths) and the
-- first one opens the Royal Pond, the best fishing spot in the game.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local RebirthService = {}

local dataService = nil
local economyService = nil
local rodToolService = nil
local notifyEvent = nil

function RebirthService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	rodToolService = deps.RodToolService
	notifyEvent = deps.Notify
end

function RebirthService.CanRebirth(player)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	if data.rebirths >= GameConfig.MAX_REBIRTHS then
		return false
	end
	return data.cash >= GameConfig.REBIRTH_CASH_REQUIRED
end

function RebirthService.GetRebirthMultiplier(player)
	local data = dataService.GetData(player)
	if not data then
		return 1
	end
	return 1 + (data.rebirths * GameConfig.REBIRTH_MULTIPLIER_PER_LEVEL)
end

function RebirthService.DoRebirth(player)
	if not RebirthService.CanRebirth(player) then
		if notifyEvent then
			notifyEvent:FireClient(player, "You need $25,000 cash to rebirth.")
		end
		return false
	end
	local data = dataService.GetData(player)

	-- Reset the grind, keep the collection.
	data.cash = 0
	data.rod = "bamboo"
	data.bait = "bread"
	data.spots = { deep = false, abyss = false }
	data.rebirths += 1

	if rodToolService then
		rodToolService.GiveRodToPlayer(player)
	end

	local multiplier = RebirthService.GetRebirthMultiplier(player)
	if notifyEvent then
		local message = "REBIRTH! Income multiplier is now x" .. string.format("%.1f", multiplier) .. "."
		if data.rebirths == 1 then
			message = message .. " The Royal Pond is now open!"
		end
		notifyEvent:FireClient(player, message)
	end
	economyService.PushState(player)
	return true
end

return RebirthService
