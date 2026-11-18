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
local WaveThiefService = require(script.Parent:WaitForChild("WaveThiefService"))
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

-- Each unlocked, unguarded tank has a 25% chance to be robbed. The theft is
-- no longer instant: a shadow thief walks in from the lake and channels on
-- the tank, so the owner can see it coming and save the fish by guarding
-- or locking the base before the channel finishes. At least one thief is
-- guaranteed per eligible victim per wave: a wave that rolls zero trips
-- looks identical to a broken event (the player never sees the thief).
function MonsterEventService.RaidUnlockedTanks()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetData(player)
		if data and #data.Tanks > 0 and data.LockUntil <= os.clock() then
			local basePos = TankService.GetBasePosition(player)
			local playerPos = GetRootPosition(player)
			local guarding = playerPos and (playerPos - basePos).Magnitude <= GameConfig.MonsterGuardRadius
			if not guarding then
				local trips = 0
				for _ = 1, #data.Tanks do
					if math.random() < GameConfig.MonsterRaidChance then
						trips = trips + 1
					end
				end
				trips = math.clamp(trips, 1, 3)
				WaveThiefService.SendThief(player, trips)
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
	if parts.GlowDisc then
		parts.GlowDisc.Transparency = (shadowOnly or fullyVisible) and 0.55 or 1
	end
	if parts.Glow then
		parts.Glow.Enabled = fullyVisible
	end
end

-- The sky is a mood signal (top-1 games tint it per event): red-orange
-- while the monster is out, golden while the Calm Water Blessing is
-- active, warm sunset otherwise. Normal matches the values the world
-- was built with (WorldBuilder only sets the Atmosphere, never Lighting,
-- so Ambient/OutdoorAmbient are the engine defaults 128,128,128).
local SKY = {
	Normal = {
		ClockTime = 17.6,
		Brightness = 2.4,
		FogColor = Color3.fromRGB(235, 158, 140),
		Ambient = Color3.fromRGB(128, 128, 128),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		AtmosphereColor = Color3.fromRGB(255, 170, 130),
		AtmosphereDecay = Color3.fromRGB(140, 90, 160),
	},
	Wave = {
		ClockTime = 19.2,
		Brightness = 1.0,
		FogColor = Color3.fromRGB(180, 60, 40),
		Ambient = Color3.fromRGB(90, 30, 30),
		OutdoorAmbient = Color3.fromRGB(140, 50, 40),
		AtmosphereColor = Color3.fromRGB(255, 100, 60),
		AtmosphereDecay = Color3.fromRGB(120, 40, 60),
	},
	Blessing = {
		ClockTime = 17.6,
		Brightness = 2.8,
		FogColor = Color3.fromRGB(255, 210, 120),
		Ambient = Color3.fromRGB(255, 225, 170),
		OutdoorAmbient = Color3.fromRGB(255, 215, 140),
		AtmosphereColor = Color3.fromRGB(255, 210, 130),
		AtmosphereDecay = Color3.fromRGB(180, 130, 80),
	},
}

local function SetSky(mode)
	local s = SKY[mode] or SKY.Normal
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = s.ClockTime
	lighting.Brightness = s.Brightness
	lighting.FogColor = s.FogColor
	lighting.Ambient = s.Ambient
	lighting.OutdoorAmbient = s.OutdoorAmbient
	local atmosphere = lighting:FindFirstChild("SunsetHaze")
	if atmosphere then
		atmosphere.Color = s.AtmosphereColor
		atmosphere.Decay = s.AtmosphereDecay
	end
end

-- Runs one full event cycle: warning -> active -> calm + blessing.
function MonsterEventService.StartMonsterEvent()
	MonsterState.SetPhase("Warning")
	SetMonsterVisible(true, false)
	SetSky("Wave")
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
	SetSky("Blessing")
	-- Calm Water Blessing: +10% luck for 60 seconds for everyone.
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetData(player)
		if data then
			data.BlessingUntil = os.clock() + GameConfig.BlessingDuration
		end
	end
	GetRemote("MonsterEvent"):FireAllClients("ended", { Seconds = GameConfig.BlessingDuration })
	DataService.BroadcastAll()
	-- Golden sky while the blessing lasts, then back to the normal
	-- sunset. The phase check guards against a new wave starting
	-- inside the 60 seconds (the scheduler waits 4-6 minutes, so it
	-- should not happen — but a stuck golden sky would be worse).
	task.spawn(function()
		task.wait(GameConfig.BlessingDuration)
		if MonsterState.GetPhase() == "Calm" then
			SetSky("Normal")
		end
	end)
end

-- Schedules the next event, then loops forever. The FIRST wave comes after
-- 90 seconds so a new player actually sees the monster; later waves are
-- 4-6 minutes apart. The event body runs inside a pcall: one error inside
-- an event must never kill the scheduler and silence every future wave.
function MonsterEventService.ScheduleNextEvent()
	task.spawn(function()
		local first = true
		while true do
			local waitTime
			if first then
				waitTime = GameConfig.MonsterFirstDelay
				first = false
			else
				waitTime = GameConfig.MonsterIntervalMin + math.random() * (GameConfig.MonsterIntervalMax - GameConfig.MonsterIntervalMin)
			end
			MonsterState.SetNextEventAt(os.clock() + waitTime)
			task.wait(waitTime)
			local ok, err = pcall(MonsterEventService.StartMonsterEvent)
			if not ok then
				warn("[BrainrotFishing] Monster event failed: " .. tostring(err))
				MonsterState.SetPhase("Calm")
				MonsterState.SetActive(false)
				SetSky("Normal")
			end
		end
	end)
end

return MonsterEventService
