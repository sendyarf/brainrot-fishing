-- DataService — the ONLY module that talks to DataStores.
-- Player data (cash, fish, gear, rebirths, collection, quests, daily
-- rewards) is loaded once on join, kept in memory while the player is
-- in the server, and saved on leave plus every 60 seconds. If DataStores
-- are unavailable (Studio without API access), the game still runs fully
-- on in-memory data and warns once in the output.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local DataService = {}

local DATASTORE_NAME = "BrainrotFishingPlayerDataV1"
local AUTOSAVE_INTERVAL_SECONDS = 60

local store = nil
local storeAvailable = false
local warnedOnce = false

local playerData = {} -- [userId] = data table

local function defaultData()
	return {
		cash = GameConfig.STARTING_CASH,
		fish = {}, -- array of {fishId, mutation}
		rod = "bamboo",
		bait = "bread",
		tankSlots = GameConfig.STARTING_TANK_SLOTS,
		spots = { deep = false, abyss = false },
		rebirths = 0,
		collection = {}, -- [fishId] = best income per second ever caught
		totalEarned = 0,
		totalCaught = 0,
		rareCaught = 0,
		quests = {}, -- [questId] = {progress, claimed}
		dailyDay = 0, -- 0 means no daily reward claimed yet
		dailyClaimedAt = 0, -- os.time() of the last daily claim
		lastSeen = os.time(),
	}
end

-- Fill in any missing fields so old saves and partial loads stay valid.
local function migrateData(data)
	local fresh = defaultData()
	if type(data) ~= "table" then
		return fresh
	end
	for key, value in pairs(fresh) do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and result then
		store = result
		storeAvailable = true
	else
		if not warnedOnce then
			warnedOnce = true
			warn("[DataService] DataStore unavailable; running on in-memory data only.")
		end
	end

	-- Autosave loop: wrapped in pcall so one error never kills the loop.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			local success, err = pcall(function()
				for _, player in ipairs(Players:GetPlayers()) do
					DataService.SavePlayerData(player)
				end
			end)
			if not success then
				warn("[DataService] Autosave failed: " .. tostring(err))
			end
		end
	end)
end

function DataService.LoadPlayerData(player)
	local userId = player.UserId
	local data = defaultData()
	if storeAvailable then
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. userId)
		end)
		if ok and saved then
			data = migrateData(saved)
		elseif not ok then
			warn("[DataService] Load failed for " .. player.Name .. "; using fresh data.")
		end
	end
	playerData[userId] = data
	return data
end

function DataService.SavePlayerData(player)
	local userId = player.UserId
	local data = playerData[userId]
	if not data then
		return false
	end
	data.lastSeen = os.time()
	if not storeAvailable then
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. userId, data)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

function DataService.GetData(player)
	return playerData[player.UserId]
end

function DataService.GetDataByUserId(userId)
	return playerData[userId]
end

function DataService.ClearData(player)
	playerData[player.UserId] = nil
end

return DataService
