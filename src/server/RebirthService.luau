-- RebirthService: trade $25,000 cash for a permanent +50% income multiplier
-- (additive, max 5 rebirths) and access to the Royal Pond. Cash, rod, bait and
-- bought spots reset; fish, collection, tank slots and the multiplier stay.
-- Functions: CanRebirth, DoRebirth, GetRebirthMultiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local RebirthService = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Returns true plus a reason string when rebirth is NOT possible.
function RebirthService.CanRebirth(player)
	local data = DataService.GetData(player)
	if not data then
		return false, "No data."
	end
	if data.Rebirths >= GameConfig.RebirthMax then
		return false, "Max rebirths reached (5)."
	end
	if data.Cash < GameConfig.RebirthCost then
		return false, "Need $25,000 cash."
	end
	return true, ""
end

function RebirthService.GetRebirthMultiplier(player)
	return DataService.GetRebirthMultiplier(player)
end

-- Performs the rebirth: resets cash/rod/bait/spots, keeps fish and slots.
function RebirthService.DoRebirth(player)
	local can, reason = RebirthService.CanRebirth(player)
	local data = DataService.GetData(player)
	if not can or not data then
		GetRemote("RebirthResult"):FireClient(player, { Success = false, Message = reason })
		return
	end
	data.Cash = 0
	data.Rod = "Bamboo"
	data.Bait = "Bread"
	data.Spots.Deep = false
	data.Spots.Abyss = false
	data.Spots.Royal = true -- Royal Pond opens with the first rebirth
	data.Rebirths = data.Rebirths + 1
	data.BlessingUntil = 0
	data.TangledUntil = 0
	DataService.BroadcastState(player)
	GetRemote("RebirthResult"):FireClient(player, {
		Success = true,
		Rebirths = data.Rebirths,
		Multiplier = DataService.GetRebirthMultiplier(player),
	})
end

return RebirthService
