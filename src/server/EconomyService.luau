-- EconomyService — the ONLY place a player's cash balance changes.
-- Every purchase, sale, quest reward and income tick flows through here,
-- so the server stays authoritative: the client never touches money.
-- Income ticks once per second: every fish in every tank pays its rate,
-- multiplied by mutations, the rebirth multiplier and any active blessing.

local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local FishDefinitions = require(game:GetService("ReplicatedStorage").Shared.FishDefinitions)

local EconomyService = {}

local dataService = nil
local stateSync = nil -- RemoteEvent, set by init
local monsterState = nil -- optional: blessing lookup

function EconomyService.Init(deps)
	dataService = deps.DataService
	stateSync = deps.StateSync
	monsterState = deps.MonsterState

	-- Income tick: every second, pay every player their $/s.
	task.spawn(function()
		while true do
			task.wait(GameConfig.INCOME_TICK_SECONDS)
			local success, err = pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					EconomyService.TickIncome(player)
				end
			end)
			if not success then
				warn("[EconomyService] Income tick failed: " .. tostring(err))
			end
		end
	end)
end

-- The income one fish pays, after its mutation multiplier.
function EconomyService.GetFishIncome(fishEntry)
	local fish = FishDefinitions.GetFishById(fishEntry.fishId)
	if not fish then
		return 0
	end
	local income = fish.income
	if fishEntry.mutation == "golden" then
		income = income * GameConfig.GOLDEN_INCOME_MULTIPLIER
	elseif fishEntry.mutation == "rainbow" then
		income = income * GameConfig.RAINBOW_INCOME_MULTIPLIER
	end
	return income
end

-- Total $/s for a player: all tank fish, times rebirth multiplier.
function EconomyService.GetIncomePerSecond(player)
	local data = dataService.GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, fishEntry in ipairs(data.fish) do
		total += EconomyService.GetFishIncome(fishEntry)
	end
	local multiplier = 1 + (data.rebirths * GameConfig.REBIRTH_MULTIPLIER_PER_LEVEL)
	return math.floor(total * multiplier + 0.5)
end

function EconomyService.GetRebirthMultiplier(player)
	local data = dataService.GetData(player)
	if not data then
		return 1
	end
	return 1 + (data.rebirths * GameConfig.REBIRTH_MULTIPLIER_PER_LEVEL)
end

-- One income tick for one player. Blessing adds +10% luck to catches,
-- not to income, so it is not applied here.
function EconomyService.TickIncome(player)
	local data = dataService.GetData(player)
	if not data then
		return
	end
	local income = EconomyService.GetIncomePerSecond(player)
	if income > 0 then
		data.cash += income
		data.totalEarned += income
		EconomyService.PushState(player)
	end
end

function EconomyService.AddCash(player, amount, reason)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	data.cash += amount
	if amount > 0 then
		data.totalEarned += amount
	end
	EconomyService.PushState(player)
	return true
end

-- Spends cash if the player can afford it. Returns true on success.
function EconomyService.SpendCash(player, amount)
	local data = dataService.GetData(player)
	if not data or data.cash < amount then
		return false
	end
	data.cash -= amount
	EconomyService.PushState(player)
	return true
end

function EconomyService.GetCash(player)
	local data = dataService.GetData(player)
	if not data then
		return 0
	end
	return data.cash
end

-- Sends the player's full state to their client for the HUD.
function EconomyService.PushState(player)
	if not stateSync then
		return
	end
	local data = dataService.GetData(player)
	if not data then
		return
	end
	local blessingActive = false
	local blessingSeconds = 0
	if monsterState then
		blessingActive, blessingSeconds = monsterState.GetBlessingForPlayer(player)
	end
	stateSync:FireClient(player, {
		cash = data.cash,
		incomePerSecond = EconomyService.GetIncomePerSecond(player),
		rebirthMultiplier = EconomyService.GetRebirthMultiplier(player),
		rebirths = data.rebirths,
		rod = data.rod,
		bait = data.bait,
		tankSlots = data.tankSlots,
		tankUsed = #data.fish,
		fish = data.fish,
		spots = data.spots,
		collection = data.collection,
		totalCaught = data.totalCaught,
		quests = data.quests,
		dailyDay = data.dailyDay,
		dailyClaimedAt = data.dailyClaimedAt,
		blessingActive = blessingActive,
		blessingSeconds = blessingSeconds,
	})
end

return EconomyService
