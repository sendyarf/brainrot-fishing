-- init.server.luau — server entry point for Brainrot Fishing.
-- Rojo turns this file's folder into a Script named "Server", so every
-- ModuleScript beside it is a CHILD of this script: require them with
-- script:WaitForChild, never script.Parent (that is ServerScriptService
-- and hangs forever). This script creates the RemoteEvents, requires
-- every service, wires the remotes, and handles player join/leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- All server modules are children of this Script.
local DataService = require(script:WaitForChild("DataService"))
local EconomyService = require(script:WaitForChild("EconomyService"))
local CatchService = require(script:WaitForChild("CatchService"))
local TankService = require(script:WaitForChild("TankService"))
local FishingService = require(script:WaitForChild("FishingService"))
local ShopService = require(script:WaitForChild("ShopService"))
local StealService = require(script:WaitForChild("StealService"))
local MonsterState = require(script:WaitForChild("MonsterState"))
local MonsterEventService = require(script:WaitForChild("MonsterEventService"))
local RebirthService = require(script:WaitForChild("RebirthService"))
local QuestService = require(script:WaitForChild("QuestService"))
local DailyRewardService = require(script:WaitForChild("DailyRewardService"))
local LeaderboardService = require(script:WaitForChild("LeaderboardService"))
local RodToolService = require(script:WaitForChild("RodToolService"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- ---------------------------------------------------------------------------
-- RemoteEvents (client <-> server). Created once, before any player joins.
-- ---------------------------------------------------------------------------

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "RemoteEvents"
remoteFolder.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local CastFish = makeRemote("CastFish")
local ReelResult = makeRemote("ReelResult")
local BuyItem = makeRemote("BuyItem")
local StealFish = makeRemote("StealFish")
local LockBase = makeRemote("LockBase")
local DoRebirth = makeRemote("DoRebirth")
local ClaimQuest = makeRemote("ClaimQuest")
local ClaimDaily = makeRemote("ClaimDaily")
local StateSync = makeRemote("StateSync")
local CatchBanner = makeRemote("CatchBanner")
local MonsterPhase = makeRemote("MonsterPhase")
local StealAlert = makeRemote("StealAlert")
local Notify = makeRemote("Notify")
local LeaderboardUpdate = makeRemote("LeaderboardUpdate")

-- ---------------------------------------------------------------------------
-- Service wiring
-- ---------------------------------------------------------------------------

DataService.Init()

EconomyService.Init({
	DataService = DataService,
	StateSync = StateSync,
	MonsterState = MonsterState,
})

TankService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	Notify = Notify,
})

FishingService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	CatchService = CatchService,
	TankService = TankService,
	QuestService = QuestService,
	MonsterState = MonsterState,
	CatchBanner = CatchBanner,
	Notify = Notify,
})

ShopService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	TankService = TankService,
	RodToolService = RodToolService,
	Notify = Notify,
})

StealService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	TankService = TankService,
	Notify = Notify,
	StealAlert = StealAlert,
})

MonsterEventService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	TankService = TankService,
	StealService = StealService,
	MonsterState = MonsterState,
	MonsterPhase = MonsterPhase,
	Notify = Notify,
})

RebirthService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	RodToolService = RodToolService,
	Notify = Notify,
})

QuestService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	Notify = Notify,
})

DailyRewardService.Init({
	DataService = DataService,
	EconomyService = EconomyService,
	Notify = Notify,
})

LeaderboardService.Init({
	DataService = DataService,
	LeaderboardUpdate = LeaderboardUpdate,
})

RodToolService.Init({
	DataService = DataService,
})

-- ---------------------------------------------------------------------------
-- World + remote handlers
-- ---------------------------------------------------------------------------

WorldBuilder.BuildWorld()
MonsterEventService.SetMonsterModel(WorldBuilder.GetMonsterModel())
LeaderboardService.SetBoardSurface(WorldBuilder.GetLeaderboardSurface())

CastFish.OnServerEvent:Connect(function(player, spotId)
	FishingService.StartCast(player, spotId)
end)

ReelResult.OnServerEvent:Connect(function(player, success, points, perfectHits)
	FishingService.ResolveReel(player, success, points, perfectHits)
end)

BuyItem.OnServerEvent:Connect(function(player, category, itemId)
	ShopService.BuyItem(player, category, itemId)
end)

StealFish.OnServerEvent:Connect(function(player, ownerUserId, tankIndex)
	StealService.CompleteSteal(player, ownerUserId, tankIndex)
end)

LockBase.OnServerEvent:Connect(function(player)
	StealService.LockBase(player)
end)

DoRebirth.OnServerEvent:Connect(function(player)
	RebirthService.DoRebirth(player)
end)

ClaimQuest.OnServerEvent:Connect(function(player, questId)
	QuestService.ClaimQuestReward(player, questId)
end)

ClaimDaily.OnServerEvent:Connect(function(player)
	DailyRewardService.ClaimDailyReward(player)
end)

-- ---------------------------------------------------------------------------
-- Player lifecycle
-- ---------------------------------------------------------------------------

local usedPlots = {} -- [plotIndex] = userId

local function assignPlot(player)
	for i, plot in ipairs(GameConfig.WORLD.basePlots) do
		if not usedPlots[i] then
			usedPlots[i] = player.UserId
			return plot, i
		end
	end
	-- More players than plots: share the last plot's area, offset aside.
	return GameConfig.WORLD.basePlots[#GameConfig.WORLD.basePlots] + Vector3.new(0, 0, 18), 0
end

local function onPlayerAdded(player)
	local data = DataService.LoadPlayerData(player)
	local plotPosition, plotIndex = assignPlot(player)
	TankService.SetupBase(player, plotPosition)
	player:SetAttribute("PlotIndex", plotIndex)

	-- Offline earnings for returning players, then the first state sync.
	DailyRewardService.PayOfflineEarnings(player)
	EconomyService.PushState(player)
	LeaderboardService.RefreshLeaderboard()

	player.CharacterAdded:Connect(function()
		RodToolService.OnCharacterAdded(player)
	end)
	-- If the character already exists, hand the rod out now.
	if player.Character then
		RodToolService.GiveRodToPlayer(player)
	end
end

local function onPlayerRemoving(player)
	FishingService.CancelFishing(player)
	TankService.TeardownBase(player)
	local plotIndex = player:GetAttribute("PlotIndex") or 0
	if plotIndex > 0 then
		usedPlots[plotIndex] = nil
	end
	DataService.SavePlayerData(player)
	DataService.ClearData(player)
	FishingService.ClearPlayer(player)
	StealService.ClearPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Players who joined before this script ran (Studio playtest edge case).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[Brainrot Fishing] Server ready. Tight lines!")
