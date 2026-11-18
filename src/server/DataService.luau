-- DataService: the ONE place player state lives. Every other service reads and
-- writes through here; nothing else keeps its own copy of cash, tanks or rods.
-- Persists to a DataStore (pcall-wrapped: a Studio playtest without API access
-- simply keeps session-only data). Also broadcasts the state snapshot the HUD
-- reads, and awards offline earnings + the Master Angler collection bonus.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local MonsterState = require(script.Parent:WaitForChild("MonsterState"))

local DataService = {}

local playerData = {}
local usedPlots = {}
local store = nil
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore("BrainrotFishingV1")
end)
if storeOk then
	store = storeResult
end

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Default state for a brand-new player.
local function DefaultData()
	local quests = {}
	for _, quest in ipairs(GameConfig.Quests) do
		table.insert(quests, { Id = quest.Id, Progress = 0, Claimed = false })
	end
	return {
		Cash = 0,
		Rod = "Bamboo",
		Bait = "Bread",
		TankSlots = GameConfig.StartTankSlots,
		Tanks = {}, -- { FishId, Mutation } per occupied tank, in tank order
		Spots = { Shallow = true, Deep = false, Abyss = false, Royal = false },
		Rebirths = 0,
		LockUntil = 0,
		LockCooldownUntil = 0,
		BlessingUntil = 0,
		TangledUntil = 0,
		Quests = quests,
		Collection = {}, -- fishId -> best $/s ever caught
		CaughtByTier = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 },
		TotalCaught = 0,
		TotalEarned = 0,
		CollectionBonusClaimed = false,
		DailyStreak = 0,
		LastDailyClaimDay = 0,
		PlotIndex = 0,
		Fishing = { State = "Idle" },
	}
end

function DataService.GetData(player)
	return playerData[player]
end

-- Income per second: every fish in tanks x mutation x rebirth multiplier.
function DataService.GetIncomePerSecond(player)
	local data = playerData[player]
	if not data then
		return 0
	end
	local total = 0
	for _, tank in ipairs(data.Tanks) do
		local def = FishDefinitions.Fish[tank.FishId]
		if def then
			local income = def.Income
			if tank.Mutation == "Golden" then
				income = income * GameConfig.MutationMultipliers.Golden
			elseif tank.Mutation == "Rainbow" then
				income = income * GameConfig.MutationMultipliers.Rainbow
			end
			total = total + income
		end
	end
	return total * (1 + data.Rebirths * GameConfig.RebirthBonusPer)
end

function DataService.GetRebirthMultiplier(player)
	local data = playerData[player]
	if not data then
		return 1
	end
	return 1 + data.Rebirths * GameConfig.RebirthBonusPer
end

-- Assigns the next free base plot along the shore.
local function AssignPlot(player, data)
	for i = 1, #GameConfig.BasePlots do
		if not usedPlots[i] then
			usedPlots[i] = player
			data.PlotIndex = i
			return
		end
	end
	data.PlotIndex = 1 -- full server: share plot 1 (should not happen at 10 plots)
end

-- Loads saved data (or defaults), assigns a plot, awards offline earnings.
function DataService.LoadPlayerData(player)
	local data = DefaultData()
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			for key, value in pairs(saved) do
				if data[key] ~= nil and key ~= "Fishing" and key ~= "Quests" then
					data[key] = value
				end
			end
			-- Offline earnings: 50% of income while away, capped.
			local lastSeen = saved.LastSeen or 0
			if lastSeen > 0 and #data.Tanks > 0 then
				playerData[player] = data
				local income = DataService.GetIncomePerSecond(player)
				local awaySeconds = math.min(os.time() - lastSeen, 8 * 3600)
				local earnings = math.floor(income * awaySeconds * GameConfig.OfflineEarningsRate)
				earnings = math.min(earnings, GameConfig.OfflineEarningsCap)
				if earnings > 0 then
					data.Cash = data.Cash + earnings
					task.spawn(function()
						task.wait(2)
						GetRemote("OfflineEarnings"):FireClient(player, earnings)
					end)
				end
			end
		end
	end
	AssignPlot(player, data)
	playerData[player] = data
	return data
end

-- Saves the player's data (called on leave and on autosave).
function DataService.SavePlayerData(player)
	local data = playerData[player]
	if not data or not store then
		return
	end
	local toSave = {
		Cash = data.Cash,
		Rod = data.Rod,
		Bait = data.Bait,
		TankSlots = data.TankSlots,
		Tanks = data.Tanks,
		Spots = data.Spots,
		Rebirths = data.Rebirths,
		Collection = data.Collection,
		CaughtByTier = data.CaughtByTier,
		TotalCaught = data.TotalCaught,
		TotalEarned = data.TotalEarned,
		CollectionBonusClaimed = data.CollectionBonusClaimed,
		DailyStreak = data.DailyStreak,
		LastDailyClaimDay = data.LastDailyClaimDay,
		LastSeen = os.time(),
	}
	pcall(function()
		store:SetAsync("player_" .. player.UserId, toSave)
	end)
end

-- Frees the player's plot and drops their state when they leave.
function DataService.RemovePlayerData(player)
	local data = playerData[player]
	if data and data.PlotIndex > 0 and usedPlots[data.PlotIndex] == player then
		usedPlots[data.PlotIndex] = nil
	end
	playerData[player] = nil
end

-- Records a catch in the Brainrotpedia collection; awards the full-set bonus.
function DataService.UpdateCollection(player, fishId, income)
	local data = playerData[player]
	if not data then
		return
	end
	local best = data.Collection[fishId] or 0
	if income > best then
		data.Collection[fishId] = income
	end
	-- Full collection (9/9): +$2,000 and the Master Angler title.
	local count = 0
	for _ in pairs(data.Collection) do
		count = count + 1
	end
	if count >= 9 and not data.CollectionBonusClaimed then
		data.CollectionBonusClaimed = true
		data.Cash = data.Cash + GameConfig.CollectionBonus
		DataService.GrantMasterAnglerTitle(player)
		GetRemote("CollectionComplete"):FireClient(player, GameConfig.CollectionBonus)
	end
end

-- Puts a "Master Angler" title above the player's head.
function DataService.GrantMasterAnglerTitle(player)
	local function attach(character)
		local head = character:FindFirstChild("Head")
		if not head or head:FindFirstChild("MasterAnglerTitle") then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "MasterAnglerTitle"
		gui.Size = UDim2.fromOffset(160, 36)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "MASTER ANGLER"
		label.TextColor3 = Color3.fromRGB(255, 210, 60)
		label.TextSize = 18
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
	end
	if player.Character then
		attach(player.Character)
	end
	player.CharacterAdded:Connect(attach)
end

-- Builds the serializable snapshot the client HUD reads, and fires it.
function DataService.BroadcastState(player)
	local data = playerData[player]
	if not data then
		return
	end
	local now = os.clock()
	local tanks = {}
	for _, tank in ipairs(data.Tanks) do
		local def = FishDefinitions.Fish[tank.FishId]
		local income = def and def.Income or 0
		if tank.Mutation == "Golden" then
			income = income * GameConfig.MutationMultipliers.Golden
		elseif tank.Mutation == "Rainbow" then
			income = income * GameConfig.MutationMultipliers.Rainbow
		end
		table.insert(tanks, { FishId = tank.FishId, Mutation = tank.Mutation, Income = income })
	end
	local quests = {}
	for _, quest in ipairs(data.Quests) do
		table.insert(quests, { Id = quest.Id, Progress = quest.Progress, Claimed = quest.Claimed })
	end
	local snapshot = {
		Cash = data.Cash,
		Income = DataService.GetIncomePerSecond(player),
		Rod = data.Rod,
		Bait = data.Bait,
		TankSlots = data.TankSlots,
		TankCount = #data.Tanks,
		Tanks = tanks,
		Spots = data.Spots,
		Rebirths = data.Rebirths,
		RebirthMultiplier = DataService.GetRebirthMultiplier(player),
		LockRemaining = math.max(0, data.LockUntil - now),
		LockCooldownRemaining = math.max(0, data.LockCooldownUntil - now),
		BlessingRemaining = math.max(0, data.BlessingUntil - now),
		TangledRemaining = math.max(0, data.TangledUntil - now),
		MonsterNextIn = MonsterState.GetSecondsUntilNext(),
		MonsterPhase = MonsterState.GetPhase(),
		Quests = quests,
		Collection = data.Collection,
		CaughtByTier = data.CaughtByTier,
		TotalCaught = data.TotalCaught,
		TotalEarned = data.TotalEarned,
		PlotIndex = data.PlotIndex,
		DailyStreak = data.DailyStreak,
		LastDailyClaimDay = data.LastDailyClaimDay,
	}
	GetRemote("StateSync"):FireClient(player, snapshot)
end

-- Broadcasts to every player (used after monster events).
function DataService.BroadcastAll()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.BroadcastState(player)
	end
end

return DataService
