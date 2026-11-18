-- MonsterEventService: the lake monster (Naga Nila) stirs every 4-6 minutes.
-- 15 seconds of warning (banner, darkening sky, ripples), then 30 seconds of
-- event: reels must finish in 10 seconds or the rod tangles, and each
-- unlocked, unguarded tank has a 25% chance to lose its cheapest fish.
-- Afterward the lake calms and every angler gets the Calm Water Blessing
-- (+10% luck for 60 seconds). Functions: ScheduleNextEvent, StartMonsterEvent,
-- RaidUnlockedTanks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TankService = require(script.Parent:WaitForChild("TankService"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local MonsterState = require(script.Parent:WaitForChild("MonsterState"))

local MonsterEventService = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function GetRootPosition(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Each unlocked, unguarded tank has a 25% chance to lose its cheapest fish.
-- Locked tanks and tanks whose owner is within 15 studs of their base are safe.
function MonsterEventService.RaidUnlockedTanks()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetData(player)
		if data and #data.Tanks > 0 and data.LockUntil <= os.clock() then
			local basePos = TankService.GetBasePosition(player)
			local playerPos = GetRootPosition(player)
			local guarding = playerPos and (playerPos - basePos).Magnitude <= GameConfig.MonsterGuardRadius
			if not guarding then
				for _ = 1, #data.Tanks do
					-- One raid roll per tank, cheapest fish first.
					if math.random() < GameConfig.MonsterRaidChance then
						local cheapestIndex = TankService.GetCheapestTankIndex(player)
						if cheapestIndex then
							local lost = TankService.RemoveFishFromTank(player, cheapestIndex)
							if lost then
								local def = FishDefinitions.Fish[lost.FishId]
								GetRemote("MonsterEvent"):FireClient(player, "raided", {
									FishName = def and def.Name or "Fish",
								})
								DataService.BroadcastState(player)
							end
						end
					end
				end
			end
		end
	end
end

-- Shows or hides the monster's shadow, fin and glowing eyes.
local function SetMonsterVisible(shadowOnly, fullyVisible)
	local parts = WorldBuilder.GetMonsterParts()
	if not parts.Shadow then
		return
	end
	parts.Shadow.Transparency = (shadowOnly or fullyVisible) and 0.35 or 1
	parts.Fin.Transparency = fullyVisible and 0 or 1
	parts.EyeLeft.Transparency = fullyVisible and 0 or 1
	parts.EyeRight.Transparency = fullyVisible and 0 or 1
	if parts.Glow then
		parts.Glow.Enabled = fullyVisible
	end
end

-- Darkens the sky for the warning/event, restores it after.
local function SetSkyDark(dark)
	local lighting = game:GetService("Lighting")
	if dark then
		lighting.ClockTime = 19.2
		lighting.Brightness = 1.2
		lighting.FogColor = Color3.fromRGB(90, 70, 110)
	else
		lighting.ClockTime = 17.6
		lighting.Brightness = 2.4
		lighting.FogColor = Color3.fromRGB(235, 158, 140)
	end
end

-- Runs one full event cycle: warning -> active -> calm + blessing.
function MonsterEventService.StartMonsterEvent()
	MonsterState.SetPhase("Warning")
	SetMonsterVisible(true, false)
	SetSkyDark(true)
	GetRemote("MonsterEvent"):FireAllClients("warning", { Seconds = GameConfig.MonsterWarningSeconds })
	task.wait(GameConfig.MonsterWarningSeconds)

	MonsterState.SetPhase("Active")
	MonsterState.SetActive(true)
	SetMonsterVisible(false, true)
	GetRemote("MonsterEvent"):FireAllClients("active", { Seconds = GameConfig.MonsterDuration })
	MonsterEventService.RaidUnlockedTanks()
	task.wait(GameConfig.MonsterDuration)

	MonsterState.SetPhase("Calm")
	MonsterState.SetActive(false)
	SetMonsterVisible(false, false)
	SetSkyDark(false)
	-- Calm Water Blessing: +10% luck for 60 seconds for everyone.
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetData(player)
		if data then
			data.BlessingUntil = os.clock() + GameConfig.BlessingDuration
		end
	end
	GetRemote("MonsterEvent"):FireAllClients("ended", { Seconds = GameConfig.BlessingDuration })
	DataService.BroadcastAll()
end

-- Schedules the next event 4-6 minutes out, then loops forever.
function MonsterEventService.ScheduleNextEvent()
	task.spawn(function()
		while true do
			local waitTime = GameConfig.MonsterIntervalMin + math.random() * (GameConfig.MonsterIntervalMax - GameConfig.MonsterIntervalMin)
			task.wait(waitTime)
			MonsterEventService.StartMonsterEvent()
		end
	end)
end

return MonsterEventService
