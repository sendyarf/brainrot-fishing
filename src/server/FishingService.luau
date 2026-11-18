-- FishingService: the cast state machine. Idle -> Waiting (2-5s bobber) -> bite
-- -> Reeling (needle minigame, client reports each hit) -> landed or escaped.
-- The server rolls the catch, owns the points, and enforces the monster-event
-- 10-second reel deadline. Functions: StartCast, ResolveReel, CancelFishing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local CatchService = require(script.Parent:WaitForChild("CatchService"))
local TankService = require(script.Parent:WaitForChild("TankService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local MonsterState = require(script.Parent:WaitForChild("MonsterState"))

local FishingService = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Total luck for a catch: rod + bait + Calm Water Blessing.
local function GetTotalLuck(player)
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local luck = 0
	local rod = GameConfig.Rods[data.Rod]
	if rod then
		luck = luck + rod.Luck
	end
	local bait = GameConfig.Baits[data.Bait]
	if bait then
		luck = luck + bait.Luck
	end
	if data.BlessingUntil > os.clock() then
		luck = luck + GameConfig.BlessingLuck
	end
	return luck
end

local function GetMythicMult(player)
	local data = DataService.GetData(player)
	if not data then
		return 1
	end
	local rod = GameConfig.Rods[data.Rod]
	return rod and rod.MythicMult or 1
end

-- Lands the catch: Perfect hits each give a 5% tier-bump chance, then the fish
-- goes into a tank (or is sold if tanks are full).
local function LandCatch(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local fishing = data.Fishing
	local fishId = fishing.FishId
	local tier = fishing.Tier
	local mutation = fishing.Mutation
	-- Perfect-hit luck: each Perfect gives +5% to bump one tier up.
	for _ = 1, fishing.PerfectHits or 0 do
		if math.random(1, 100) <= GameConfig.PerfectLuckBonus then
			tier = FishDefinitions.GetNextTier(tier)
		end
	end
	if tier ~= fishing.Tier then
		local pool = FishDefinitions.FishByTier[tier]
		fishId = pool[math.random(1, #pool)]
	end
	data.Fishing = { State = "Idle" }

	local result, soldFor = TankService.AddFishToTank(player, fishId, mutation)
	local def = FishDefinitions.Fish[fishId]
	data.TotalCaught = data.TotalCaught + 1
	data.CaughtByTier[tier] = (data.CaughtByTier[tier] or 0) + 1
	DataService.UpdateCollection(player, fishId, def.Income)
	QuestService.TrackProgress(player)

	if result == "sold" then
		EconomyService.AddCash(player, soldFor)
		GetRemote("CatchBanner"):FireClient(player, {
			FishId = fishId,
			Tier = tier,
			Mutation = mutation,
			SoldFor = soldFor,
		})
	else
		GetRemote("CatchBanner"):FireClient(player, {
			FishId = fishId,
			Tier = tier,
			Mutation = mutation,
			SoldFor = 0,
		})
	end
	DataService.BroadcastState(player)
end

-- The fish escapes: 3 misses in a row, a timeout, or a cancelled cast.
local function EscapeFish(player, reason)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.Fishing = { State = "Idle" }
	GetRemote("FishingUpdate"):FireClient(player, "escaped", { Reason = reason or "It got away..." })
end

-- Starts a cast at a fishing spot. Validates: idle, not tangled, spot owned,
-- and standing near the spot.
function FishingService.StartCast(player, spotId)
	local data = DataService.GetData(player)
	if not data or data.Fishing.State ~= "Idle" then
		return
	end
	if data.TangledUntil > os.clock() then
		GetRemote("FishingUpdate"):FireClient(player, "tangled", {})
		return
	end
	local spot = GameConfig.Spots[spotId]
	if not spot then
		return
	end
	if spotId == "Royal" then
		if data.Rebirths < 1 then
			return
		end
	elseif not data.Spots[spotId] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - spot.Position).Magnitude > spot.Radius + 6 then
		return
	end

	data.Fishing = { State = "Waiting", SpotId = spotId }
	GetRemote("FishingUpdate"):FireClient(player, "cast", { SpotId = spotId })

	-- The bobber waits 2-5 seconds, then the fish bites.
	local waitTime = 2 + math.random() * 3
	task.delay(waitTime, function()
		local current = DataService.GetData(player)
		if not current or current.Fishing.State ~= "Waiting" then
			return
		end
		local luck = GetTotalLuck(player)
		local fishId, tier, mutation = CatchService.RollCatch(spotId, luck, GetMythicMult(player))
		local deadline = os.clock()
		if MonsterState.IsActive() then
			deadline = deadline + GameConfig.MonsterReelDeadline
		else
			deadline = deadline + GameConfig.ReelTimeoutSeconds
		end
		current.Fishing = {
			State = "Reeling",
			SpotId = spotId,
			FishId = fishId,
			Tier = tier,
			Mutation = mutation,
			Points = 0,
			MissStreak = 0,
			PerfectHits = 0,
			Deadline = deadline,
		}
		GetRemote("FishingUpdate"):FireClient(player, "bite", {
			Tier = tier,
			NeedleSpeed = GameConfig.ReelNeedleSpeeds[tier] or 1,
			DeadlineSeconds = deadline - os.clock(),
		})
		-- Reel timeout: the fish escapes; during the monster event the rod tangles.
		task.delay(deadline - os.clock(), function()
			local later = DataService.GetData(player)
			if not later or later.Fishing.State ~= "Reeling" then
				return
			end
			if MonsterState.IsActive() then
				later.TangledUntil = os.clock() + GameConfig.TangleSeconds
				later.Fishing = { State = "Idle" }
				GetRemote("FishingUpdate"):FireClient(player, "tangled", {})
				DataService.BroadcastState(player)
			else
				EscapeFish(player, "It got away...")
			end
		end)
	end)
end

-- Handles one reel hit from the client: Perfect = 2 points, Good = 1, Miss = 0.
-- 3 points lands the fish; 3 misses in a row lets it escape.
function FishingService.ResolveReel(player, zone)
	local data = DataService.GetData(player)
	if not data or data.Fishing.State ~= "Reeling" then
		return
	end
	local fishing = data.Fishing
	if os.clock() > fishing.Deadline then
		EscapeFish(player, "Too slow! It got away...")
		return
	end
	if zone == "Perfect" then
		fishing.Points = fishing.Points + 2
		fishing.PerfectHits = fishing.PerfectHits + 1
		fishing.MissStreak = 0
	elseif zone == "Good" then
		fishing.Points = fishing.Points + 1
		fishing.MissStreak = 0
	else
		fishing.MissStreak = fishing.MissStreak + 1
	end
	GetRemote("FishingUpdate"):FireClient(player, "hit", {
		Zone = zone,
		Points = fishing.Points,
		MissStreak = fishing.MissStreak,
	})
	if fishing.Points >= GameConfig.ReelPointsToLand then
		LandCatch(player)
	elseif fishing.MissStreak >= GameConfig.ReelMissStreakToEscape then
		EscapeFish(player, "It got away...")
	end
end

-- Cancels any in-progress fishing (death, leave, or a fresh cast request).
function FishingService.CancelFishing(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	if data.Fishing.State ~= "Idle" then
		data.Fishing = { State = "Idle" }
		GetRemote("FishingUpdate"):FireClient(player, "cancelled", {})
	end
end

Players.PlayerRemoving:Connect(function(player)
	FishingService.CancelFishing(player)
end)

return FishingService
