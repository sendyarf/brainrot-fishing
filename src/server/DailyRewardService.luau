-- DailyRewardService — two reasons to come back tomorrow: a 7-day daily
-- reward streak and offline earnings. Daily rewards pay escalating cash
-- once per day; offline earnings pay 50% of the player's income for the
-- hours they were away (capped at $5,000 and 12 hours). Both are
-- computed from os.time(), so they work across sessions and servers.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local DailyRewardService = {}

local dataService = nil
local economyService = nil
local notifyEvent = nil

local SECONDS_PER_DAY = 86400

function DailyRewardService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	notifyEvent = deps.Notify
end

-- Which day of the week (1-7) the player is on. Day 0 means unclaimed.
function DailyRewardService.GetCurrentDailyDay(player)
	local data = dataService.GetData(player)
	if not data then
		return 1
	end
	return math.min(data.dailyDay + 1, #GameConfig.DAILY_REWARDS)
end

function DailyRewardService.CanClaimDaily(player)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	if data.dailyClaimedAt == 0 then
		return true
	end
	local now = os.time()
	local lastDay = math.floor(data.dailyClaimedAt / SECONDS_PER_DAY)
	local today = math.floor(now / SECONDS_PER_DAY)
	return today > lastDay
end

function DailyRewardService.ClaimDailyReward(player)
	if not DailyRewardService.CanClaimDaily(player) then
		return false
	end
	local data = dataService.GetData(player)
	local day = DailyRewardService.GetCurrentDailyDay(player)
	local reward = GameConfig.DAILY_REWARDS[day] or GameConfig.DAILY_REWARDS[1]
	data.dailyDay = day
	data.dailyClaimedAt = os.time()
	economyService.AddCash(player, reward, "daily_reward")
	if notifyEvent then
		notifyEvent:FireClient(player, "Daily reward day " .. day .. ": +$" .. reward .. "!")
	end
	return true
end

-- Pays the player for the time they were away: 50% of their income rate
-- for up to 12 hours, capped at $5,000. Called once when they join.
function DailyRewardService.PayOfflineEarnings(player)
	local data = dataService.GetData(player)
	if not data then
		return 0
	end
	local lastSeen = data.lastSeen or os.time()
	local awaySeconds = os.time() - lastSeen
	if awaySeconds < 60 then
		return 0 -- just rejoined; nothing to pay
	end
	local awayHours = math.min(awaySeconds / 3600, GameConfig.OFFLINE_EARNINGS_MAX_HOURS)
	local income = economyService.GetIncomePerSecond(player)
	if income <= 0 then
		return 0
	end
	local payout = math.floor(income * awayHours * 3600 * GameConfig.OFFLINE_EARNINGS_RATE)
	payout = math.min(payout, GameConfig.OFFLINE_EARNINGS_CAP)
	if payout > 0 then
		economyService.AddCash(player, payout, "offline_earnings")
		if notifyEvent then
			notifyEvent:FireClient(player, "Welcome back! Your fish earned $" .. payout .. " while you were away.")
		end
	end
	return payout
end

return DailyRewardService
