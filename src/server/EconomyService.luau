-- EconomyService: the ONLY place cash changes. Every purchase, sale, reward and
-- income tick goes through here so the economy stays server-authoritative.
-- Functions: AddCash, SpendCash, TickIncome.

local DataService = require(script.Parent:WaitForChild("DataService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local EconomyService = {}

-- Adds cash (income, sales, rewards). Always broadcasts the new state.
function EconomyService.AddCash(player, amount)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.Cash = data.Cash + amount
	data.TotalEarned = data.TotalEarned + amount
	DataService.BroadcastState(player)
end

-- Spends cash if the player can afford it. Returns true on success.
function EconomyService.SpendCash(player, amount)
	local data = DataService.GetData(player)
	if not data or data.Cash < amount then
		return false
	end
	data.Cash = data.Cash - amount
	DataService.BroadcastState(player)
	return true
end

-- One income tick: every player's tanks pay out for one second.
function EconomyService.TickIncome()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local data = DataService.GetData(player)
		if data then
			local income = DataService.GetIncomePerSecond(player)
			if income > 0 then
				data.Cash = data.Cash + income
				data.TotalEarned = data.TotalEarned + income
			end
			QuestService.TrackProgress(player)
			DataService.BroadcastState(player)
		end
	end
end

-- Starts the 1-second income loop.
function EconomyService.StartIncomeLoop()
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickSeconds)
			EconomyService.TickIncome()
		end
	end)
end

return EconomyService
