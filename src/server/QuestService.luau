-- QuestService: 3 daily quests that reset every session (fresh progress on join).
-- Progress is computed from the player's totals, so it can never drift:
-- catches from TotalCaught, earnings from TotalEarned, rare catches from the
-- tier counts. Functions: TrackProgress, ClaimQuestReward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local QuestService = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Computes one quest's progress from the player's totals.
local function ComputeProgress(data, questId)
	if questId == "catch5" then
		return data.TotalCaught
	elseif questId == "earn1000" then
		return data.TotalEarned
	elseif questId == "rare1" then
		local counts = data.CaughtByTier
		return (counts.Rare or 0) + (counts.Epic or 0) + (counts.Legendary or 0) + (counts.Mythic or 0)
	end
	return 0
end

-- Syncs every quest's stored progress from the player's totals.
function QuestService.TrackProgress(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	for _, quest in ipairs(data.Quests) do
		quest.Progress = ComputeProgress(data, quest.Id)
	end
end

-- Claims a finished quest's reward (once per quest per session).
function QuestService.ClaimQuestReward(player, questId)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	QuestService.TrackProgress(player)
	local configQuest = nil
	for _, quest in ipairs(GameConfig.Quests) do
		if quest.Id == questId then
			configQuest = quest
			break
		end
	end
	if not configQuest then
		return
	end
	for _, quest in ipairs(data.Quests) do
		if quest.Id == questId then
			if quest.Claimed then
				GetRemote("QuestResult"):FireClient(player, { Success = false, Message = "Already claimed." })
				return
			end
			if quest.Progress < configQuest.Target then
				GetRemote("QuestResult"):FireClient(player, { Success = false, Message = "Quest not finished yet." })
				return
			end
			quest.Claimed = true
			data.Cash = data.Cash + configQuest.Reward
			data.TotalEarned = data.TotalEarned + configQuest.Reward
			DataService.BroadcastState(player)
			GetRemote("QuestResult"):FireClient(player, {
				Success = true,
				Message = "Quest complete! +$" .. configQuest.Reward,
			})
			return
		end
	end
end

return QuestService
