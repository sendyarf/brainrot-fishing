-- QuestService — three daily quests that pay cash for playing.
-- Progress is tracked from the game's own events (catches, earnings,
-- rare catches) and resets every new session, so a fresh visit always
-- has goals. Rewards are claimed with a button and paid by the server.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local QuestService = {}

local dataService = nil
local economyService = nil
local notifyEvent = nil

function QuestService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	notifyEvent = deps.Notify
end

-- The quest progress entry for a player, created on first use.
local function getQuestEntry(data, questId)
	local entry = data.quests[questId]
	if not entry then
		entry = { progress = 0, claimed = false }
		data.quests[questId] = entry
	end
	return entry
end

-- Adds progress to every quest of the given kind. The "earned" kind is
-- fed from totalEarned, so it is computed rather than incremented.
function QuestService.TrackProgress(player, kind, amount)
	local data = dataService.GetData(player)
	if not data then
		return
	end
	for _, quest in ipairs(GameConfig.QUESTS) do
		if quest.kind == kind then
			local entry = getQuestEntry(data, quest.id)
			if kind == "earned" then
				entry.progress = math.min(data.totalEarned, quest.goal)
			else
				entry.progress = math.min(entry.progress + amount, quest.goal)
			end
		end
	end
	-- Earnings also feed the earn quest whenever cash ticks in.
	if kind ~= "earned" then
		for _, quest in ipairs(GameConfig.QUESTS) do
			if quest.kind == "earned" then
				local entry = getQuestEntry(data, quest.id)
				entry.progress = math.min(data.totalEarned, quest.goal)
			end
		end
	end
	economyService.PushState(player)
end

-- Claims a finished quest's cash reward. One claim per quest per session.
function QuestService.ClaimQuestReward(player, questId)
	local data = dataService.GetData(player)
	if not data then
		return false
	end
	local quest = GameConfig.GetQuestById(questId)
	if not quest then
		return false
	end
	local entry = getQuestEntry(data, questId)
	if entry.claimed then
		return false
	end
	if entry.progress < quest.goal then
		return false
	end
	entry.claimed = true
	economyService.AddCash(player, quest.reward, "quest_reward")
	if notifyEvent then
		notifyEvent:FireClient(player, "Quest complete: " .. quest.name .. " (+$" .. quest.reward .. ")")
	end
	return true
end

return QuestService
