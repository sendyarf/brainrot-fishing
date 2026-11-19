-- MonsterEventService — the lake monster event, this game's named threat.
-- Every 4-6 minutes the Naga Nila stirs: a 15-second warning (darkening
-- sky, banner, countdown), then 30 seconds of chaos (the monster surfaces,
-- reels have a 10-second limit, unguarded tanks can be raided), then the
-- lake calms and every player gets the Calm Water Blessing (+10% luck
-- for 60 seconds). Locked bases and guarded tanks are immune to raids.
-- The scheduler loop is wrapped in pcall: one error must never stop the
-- event from ever firing again.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local FishDefinitions = require(game:GetService("ReplicatedStorage").Shared.FishDefinitions)

local MonsterEventService = {}

local dataService = nil
local economyService = nil
local tankService = nil
local stealService = nil
local monsterState = nil
local monsterPhaseEvent = nil
local notifyEvent = nil

local monsterModel = nil -- set by WorldBuilder via SetMonsterModel
local originalClockTime = 17.5
local originalAmbient = Color3.fromRGB(102, 76, 89)

function MonsterEventService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	tankService = deps.TankService
	stealService = deps.StealService
	monsterState = deps.MonsterState
	monsterPhaseEvent = deps.MonsterPhase
	notifyEvent = deps.Notify

	task.spawn(function()
		-- First event comes early so a short session still sees the monster.
		task.wait(GameConfig.MONSTER_FIRST_DELAY_SECONDS)
		while true do
			local success, err = pcall(function()
				MonsterEventService.RunEventCycle()
			end)
			if not success then
				warn("[MonsterEventService] Event cycle failed: " .. tostring(err))
				monsterState.SetPhase("idle", 0)
				MonsterEventService.RestoreSky()
			end
			local nextIn = math.random(GameConfig.MONSTER_INTERVAL_MIN_SECONDS, GameConfig.MONSTER_INTERVAL_MAX_SECONDS)
			task.wait(nextIn)
		end
	end)
end

function MonsterEventService.SetMonsterModel(model)
	monsterModel = model
end

local function broadcastPhase()
	if monsterPhaseEvent then
		monsterPhaseEvent:FireAllClients(monsterState.GetPhase(), monsterState.GetPhaseSecondsLeft())
	end
end

function MonsterEventService.DarkenSky()
	originalClockTime = Lighting.ClockTime
	originalAmbient = Lighting.Ambient
	Lighting.ClockTime = 19.5
	Lighting.Ambient = Color3.fromRGB(40, 30, 50)
end

function MonsterEventService.RestoreSky()
	Lighting.ClockTime = originalClockTime
	Lighting.Ambient = originalAmbient
end

local function showMonster(visible)
	if not monsterModel then
		return
	end
	for _, part in ipairs(monsterModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = visible and 0 or 1
		elseif part:IsA("PointLight") then
			part.Enabled = visible
		end
	end
end

-- One full event: warning → active → blessing.
function MonsterEventService.RunEventCycle()
	-- WARNING: 15 seconds of dread.
	monsterState.SetPhase("warning", GameConfig.MONSTER_WARNING_SECONDS)
	MonsterEventService.DarkenSky()
	broadcastPhase()
	task.wait(GameConfig.MONSTER_WARNING_SECONDS)

	-- ACTIVE: 30 seconds of the monster on the surface.
	monsterState.SetPhase("active", GameConfig.MONSTER_DURATION_SECONDS)
	showMonster(true)
	broadcastPhase()
	MonsterEventService.RaidUnlockedTanks()
	task.wait(GameConfig.MONSTER_DURATION_SECONDS)

	-- CALM: the monster sinks, the blessing begins.
	showMonster(false)
	MonsterEventService.RestoreSky()
	monsterState.SetPhase("blessing", GameConfig.BLESSING_DURATION_SECONDS)
	broadcastPhase()
	if notifyEvent then
		notifyEvent:FireAllClients("The lake calms... Calm Water Blessing: +10% luck for 60s!")
	end
	task.wait(GameConfig.BLESSING_DURATION_SECONDS)

	monsterState.SetPhase("idle", 0)
	broadcastPhase()
end

-- Raids every unlocked, unguarded tank once per event: each tank has a
-- 25% chance to lose its cheapest fish to the monster.
function MonsterEventService.RaidUnlockedTanks()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = dataService.GetData(player)
		if data and #data.fish > 0 then
			-- Locked bases are immune.
			if stealService and stealService.IsBaseLocked(player) then
				continue
			end
			-- A player standing near their base guards the tanks.
			local guarded = false
			local character = player.Character
			local basePosition = tankService.GetBasePosition(player)
			if character and character:FindFirstChild("HumanoidRootPart") and basePosition then
				local distance = (character.HumanoidRootPart.Position - basePosition).Magnitude
				guarded = distance <= GameConfig.MONSTER_GUARD_RADIUS
			end
			if guarded then
				continue
			end
			-- Roll the raid: 25% per event, one fish at most.
			if math.random(1, 100) <= GameConfig.MONSTER_RAID_CHANCE_PERCENT then
				local cheapestIndex = tankService.GetCheapestFishIndex(player)
				if cheapestIndex then
					local stolen = tankService.RemoveFishFromTank(player, cheapestIndex)
					if stolen then
						local fish = FishDefinitions.GetFishById(stolen.fishId)
						local fishName = fish and fish.name or "a fish"
						if notifyEvent then
							notifyEvent:FireClient(player, "The monster raided your tank! Lost " .. fishName .. ".")
						end
						economyService.PushState(player)
					end
				end
			end
		end
	end
end

return MonsterEventService
