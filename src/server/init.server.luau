-- init.server.luau: Brainrot Fishing server bootstrap.
-- Order matters: build the world first, then create the RemoteEvents, then
-- require the services (they WaitForChild the events), then wire the handlers.
--
-- ROJO GOTCHA: this is an init.server.luau file, so Rojo turns the src/server
-- folder itself into the "Server" Script, and every sibling ModuleScript is a
-- CHILD of this script. Require them via script:WaitForChild — script.Parent
-- is ServerScriptService, where they will never appear. The old script.Parent
-- form hung this whole script forever on line 1: no world, no RemoteEvents,
-- no services, and players spawned with no ground and fell to their deaths.
-- (The ModuleScripts themselves correctly use script.Parent, because for
-- them script.Parent IS this Server script.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Build the 3D world (lake, pier, islands, base plots, monster).
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
WorldBuilder.BuildWorld()

-- 2. Create every RemoteEvent the client and server share.
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "RemoteEvents"
remoteEvents.Parent = ReplicatedStorage
local remoteNames = {
	"StateSync",
	"FishingUpdate",
	"CatchBanner",
	"MonsterEvent",
	"StealUpdate",
	"ShopResult",
	"RebirthResult",
	"QuestResult",
	"OfflineEarnings",
	"CollectionComplete",
	"DailyRewardResult",
	"CastFish",
	"ReelResult",
	"BuyItem",
	"LockBase",
	"DoRebirth",
	"ClaimQuest",
	"ClaimDaily",
}
for _, name in ipairs(remoteNames) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteEvents
end
local function GetRemote(name)
	return remoteEvents:WaitForChild(name)
end

-- 3. Require the services (they find the RemoteEvents already created).
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataService = require(script:WaitForChild("DataService"))
local EconomyService = require(script:WaitForChild("EconomyService"))
local FishingService = require(script:WaitForChild("FishingService"))
local TankService = require(script:WaitForChild("TankService"))
local ShopService = require(script:WaitForChild("ShopService"))
local StealService = require(script:WaitForChild("StealService"))
local MonsterEventService = require(script:WaitForChild("MonsterEventService"))
local RebirthService = require(script:WaitForChild("RebirthService"))
local QuestService = require(script:WaitForChild("QuestService"))

-- 4. Wire the client -> server handlers.
GetRemote("CastFish").OnServerEvent:Connect(function(player, spotId)
	FishingService.StartCast(player, spotId)
end)
GetRemote("ReelResult").OnServerEvent:Connect(function(player, zone)
	FishingService.ResolveReel(player, zone)
end)
GetRemote("BuyItem").OnServerEvent:Connect(function(player, category, itemId)
	if category == "rod" then
		ShopService.BuyRod(player, itemId)
	elseif category == "bait" then
		ShopService.BuyBait(player, itemId)
	elseif category == "slot" then
		ShopService.BuyTankSlot(player)
	elseif category == "spot" then
		ShopService.BuyFishingSpot(player, itemId)
	end
end)
GetRemote("LockBase").OnServerEvent:Connect(function(player)
	StealService.LockBase(player)
end)
GetRemote("DoRebirth").OnServerEvent:Connect(function(player)
	RebirthService.DoRebirth(player)
end)
GetRemote("ClaimQuest").OnServerEvent:Connect(function(player, questId)
	QuestService.ClaimQuestReward(player, questId)
end)

-- Daily reward: one claim per day, escalating with the streak (max 7 days).
local function ClaimDailyReward(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local today = math.floor(os.time() / 86400)
	if data.LastDailyClaimDay >= today then
		GetRemote("DailyRewardResult"):FireClient(player, { Success = false, Message = "Come back tomorrow!" })
		return
	end
	if data.LastDailyClaimDay == today - 1 then
		data.DailyStreak = data.DailyStreak + 1
	else
		data.DailyStreak = 1
	end
	data.DailyStreak = math.min(data.DailyStreak, #GameConfig.DailyRewards)
	data.LastDailyClaimDay = today
	local reward = GameConfig.DailyRewards[data.DailyStreak]
	data.Cash = data.Cash + reward
	data.TotalEarned = data.TotalEarned + reward
	DataService.BroadcastState(player)
	GetRemote("DailyRewardResult"):FireClient(player, {
		Success = true,
		Reward = reward,
		Streak = data.DailyStreak,
	})
end
GetRemote("ClaimDaily").OnServerEvent:Connect(ClaimDailyReward)

-- 5. Steal prompts: every tank's ProximityPrompt feeds StealService.
local function ConnectStealPrompt(prompt)
	if prompt.Name ~= "StealPrompt" then
		return
	end
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local ownerUserId = prompt:GetAttribute("OwnerUserId")
		local tankIndex = prompt:GetAttribute("TankIndex")
		local owner = ownerUserId and Players:GetPlayerByUserId(ownerUserId) or nil
		if owner and tankIndex then
			StealService.StartSteal(player, owner, tankIndex)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		StealService.ReleaseHold(player)
	end)
end
game:GetService("Workspace").DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
		ConnectStealPrompt(descendant)
	end
end)

-- 6. Player lifecycle.
local function SetPlotSign(plotIndex, title, subtitle)
	local world = game:GetService("Workspace"):FindFirstChild("BrainrotFishingWorld")
	if not world then
		return
	end
	local plot = world:FindFirstChild("BasePlot" .. plotIndex)
	local sign = plot and plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("SignLabel")
	if gui then
		local titleLabel = gui:FindFirstChild("Title")
		local subLabel = gui:FindFirstChild("Subtitle")
		if titleLabel then
			titleLabel.Text = title
		end
		if subLabel then
			subLabel.Text = subtitle
		end
	end
end

local function OnPlayerAdded(player)
	local data = DataService.LoadPlayerData(player)
	TankService.RebuildPlayerTanks(player)
	SetPlotSign(data.PlotIndex, player.Name .. "'s Base", "Tanks: " .. #data.Tanks .. "/" .. data.TankSlots)
	if data.CollectionBonusClaimed then
		DataService.GrantMasterAnglerTitle(player)
	end
	DataService.BroadcastState(player)
	-- Dying cancels any in-progress fishing.
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			FishingService.CancelFishing(player)
		end)
		-- Spawn safety net: put the character on the pier even if the
		-- SpawnLocation is ever missed, and rescue any fall into the void
		-- (a character below y = -50 is teleported back, never left falling).
		local root = character:WaitForChild("HumanoidRootPart")
		root.CFrame = CFrame.new(GameConfig.SpawnPosition)
		task.spawn(function()
			while character.Parent do
				task.wait(0.5)
				if root.Parent and root.Position.Y < -50 then
					root.CFrame = CFrame.new(GameConfig.SpawnPosition)
				end
			end
		end)
	end)
end

local function OnPlayerRemoving(player)
	FishingService.CancelFishing(player)
	DataService.SavePlayerData(player)
	local data = DataService.GetData(player)
	if data then
		SetPlotSign(data.PlotIndex, "OPEN BASE", "Your tanks go here")
	end
	DataService.RemovePlayerData(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, player)
end

-- 7. Start the loops: income tick, monster scheduler, autosave.
EconomyService.StartIncomeLoop()
MonsterEventService.ScheduleNextEvent()
task.spawn(function()
	while true do
		task.wait(GameConfig.AutosaveSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.SavePlayerData(player)
		end
	end
end)

print("Brainrot Fishing server started: world built, services live.")
