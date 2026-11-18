-- GameConfig: every number the game runs on lives here (prices, rates, timers).
-- One config file so the economy can be tuned without touching any logic.
-- Client and server both read it (it lives in ReplicatedStorage/Shared).

local GameConfig = {}

-- ---------------------------------------------------------------------------
-- Fishing spots. Position = the marker players stand near; Radius = cast zone.
-- Rates = rarity weights (out of 100) with a Bamboo Rod and Bread bait.
-- ---------------------------------------------------------------------------
GameConfig.Spots = {
	Shallow = {
		Name = "Shallow Shore",
		Price = 0,
		Position = Vector3.new(4, 1, 22),
		Radius = 12,
		WaterColor = Color3.fromRGB(110, 220, 200),
		Rates = { Common = 60, Rare = 25, Epic = 10, Legendary = 4, Mythic = 1 },
	},
	Deep = {
		Name = "Deep Dock",
		Price = 500,
		Position = Vector3.new(0, 1, -62),
		Radius = 12,
		WaterColor = Color3.fromRGB(40, 140, 210),
		Rates = { Common = 45, Rare = 30, Epic = 17, Legendary = 6, Mythic = 2 },
	},
	Abyss = {
		Name = "Abyss Point",
		Price = 2500,
		Position = Vector3.new(-70, 1, -95),
		Radius = 12,
		WaterColor = Color3.fromRGB(25, 60, 170),
		Rates = { Common = 30, Rare = 30, Epic = 25, Legendary = 11, Mythic = 4 },
	},
	Royal = {
		Name = "Royal Pond",
		Price = 0,
		Position = Vector3.new(70, 1, -95),
		Radius = 12,
		WaterColor = Color3.fromRGB(255, 214, 90),
		Rates = { Common = 15, Rare = 25, Epic = 30, Legendary = 20, Mythic = 10 },
	},
}
GameConfig.SpotOrder = { "Shallow", "Deep", "Abyss", "Royal" }

-- ---------------------------------------------------------------------------
-- Rods: one active at a time; buying is a permanent upgrade.
-- PerfectBonus widens the reel minigame's Perfect zone (percentage points).
-- ---------------------------------------------------------------------------
GameConfig.Rods = {
	Bamboo = { Name = "Bamboo Rod", Price = 0, Luck = 0, PerfectBonus = 0, MythicMult = 1 },
	Wooden = { Name = "Wooden Rod", Price = 150, Luck = 10, PerfectBonus = 0, MythicMult = 1 },
	Steel = { Name = "Steel Rod", Price = 600, Luck = 20, PerfectBonus = 10, MythicMult = 1 },
	Golden = { Name = "Golden Rod", Price = 2000, Luck = 35, PerfectBonus = 20, MythicMult = 1 },
	Dragon = { Name = "Dragon Rod", Price = 6000, Luck = 50, PerfectBonus = 30, MythicMult = 2 },
}
GameConfig.RodOrder = { "Bamboo", "Wooden", "Steel", "Golden", "Dragon" }

-- ---------------------------------------------------------------------------
-- Baits: one active at a time; buying is a permanent passive luck upgrade.
-- ---------------------------------------------------------------------------
GameConfig.Baits = {
	Bread = { Name = "Bread", Price = 0, Luck = 0 },
	Worm = { Name = "Worm Bait", Price = 100, Luck = 5 },
	Shiny = { Name = "Shiny Lure", Price = 500, Luck = 10 },
	Dragon = { Name = "Dragon Bait", Price = 1500, Luck = 15 },
}
GameConfig.BaitOrder = { "Bread", "Worm", "Shiny", "Dragon" }

-- ---------------------------------------------------------------------------
-- Tanks: players start with 3 slots, max 12. Prices are sequential per slot.
-- ---------------------------------------------------------------------------
GameConfig.StartTankSlots = 3
GameConfig.MaxTankSlots = 12
GameConfig.TankSlotPrices = { 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200 }

-- ---------------------------------------------------------------------------
-- Rebirth: cash resets for a permanent additive +50% income multiplier.
-- ---------------------------------------------------------------------------
GameConfig.RebirthCost = 25000
GameConfig.RebirthMax = 5
GameConfig.RebirthBonusPer = 0.5

-- ---------------------------------------------------------------------------
-- Mutations: rolled independently at catch time. Rainbow beats Golden.
-- ---------------------------------------------------------------------------
GameConfig.MutationRates = { Golden = 0.05, Rainbow = 0.01 }
GameConfig.MutationMultipliers = { Golden = 2, Rainbow = 4 }

-- ---------------------------------------------------------------------------
-- Steal + lock.
-- ---------------------------------------------------------------------------
GameConfig.StealHoldSeconds = 3
GameConfig.StealCancelRadius = 12 -- owner this close to the tank cancels the channel
GameConfig.LockDuration = 300 -- 5 minutes
GameConfig.LockCooldown = 600 -- 10 minutes

-- ---------------------------------------------------------------------------
-- Lake monster event.
-- ---------------------------------------------------------------------------
GameConfig.MonsterIntervalMin = 240 -- 4 minutes
GameConfig.MonsterIntervalMax = 360 -- 6 minutes
GameConfig.MonsterFirstDelay = 90 -- first wave comes early so new players see it
GameConfig.MonsterWarningSeconds = 15
GameConfig.MonsterDuration = 30
GameConfig.MonsterRaidChance = 0.25
GameConfig.MonsterGuardRadius = 15 -- owner this close to their base guards it
GameConfig.MonsterReelDeadline = 10
GameConfig.TangleSeconds = 10
GameConfig.BlessingLuck = 10 -- Calm Water Blessing after the event ends
GameConfig.BlessingDuration = 60

-- ---------------------------------------------------------------------------
-- Reel minigame.
-- ---------------------------------------------------------------------------
GameConfig.ReelPointsToLand = 3
GameConfig.ReelMissStreakToEscape = 3
GameConfig.PerfectLuckBonus = 5 -- each Perfect hit: +5% tier-bump chance on landing
GameConfig.ReelTimeoutSeconds = 30
GameConfig.ReelNeedleSpeeds = { Common = 1.0, Rare = 1.3, Epic = 1.6, Legendary = 2.0, Mythic = 2.6 }
GameConfig.ReelMissSpeedUp = 1.1 -- needle gets 10% faster after each Miss

-- ---------------------------------------------------------------------------
-- Economy.
-- ---------------------------------------------------------------------------
GameConfig.OverflowSellMultiplier = 100 -- tank-full catch sells for $/s x 100
GameConfig.IncomeTickSeconds = 1
GameConfig.AutosaveSeconds = 60
GameConfig.CollectionBonus = 2000 -- catching all 9 fish
GameConfig.OfflineEarningsCap = 5000
GameConfig.OfflineEarningsRate = 0.5 -- 50% of income while away

-- ---------------------------------------------------------------------------
-- Daily quests (reset every session).
-- ---------------------------------------------------------------------------
GameConfig.Quests = {
	{ Id = "catch5", Name = "Catch 5 fish", Target = 5, Reward = 150 },
	{ Id = "earn1000", Name = "Earn $1,000 total", Target = 1000, Reward = 300 },
	{ Id = "rare1", Name = "Catch a Rare or better", Target = 1, Reward = 500 },
}

-- ---------------------------------------------------------------------------
-- Daily rewards (claim once per day, escalating).
-- ---------------------------------------------------------------------------
GameConfig.DailyRewards = { 100, 200, 350, 500, 750, 1000, 1500 }

-- ---------------------------------------------------------------------------
-- Base plots along the shore (10 plots, one per player, assigned on join).
-- ---------------------------------------------------------------------------
GameConfig.BasePlots = {}
for i = 1, 10 do
	GameConfig.BasePlots[i] = Vector3.new(-135 + (i - 1) * 30, 0, 48)
end

-- Tank anchors inside a plot: 2 rows of 6, local to the plot center.
-- Column-major order (down each column first) so the first tanks fill as a
-- grid, not a single row: with 4 tanks the base already looks 2x2. The old
-- row-major order filled row 1 first, so a base with 6 or fewer tanks
-- looked like one row.
GameConfig.TankAnchors = {}
for col = 1, 6 do
	for row = 1, 2 do
		table.insert(GameConfig.TankAnchors, Vector3.new(-11 + (col - 1) * 4.4, 0, -3.5 + (row - 1) * 7))
	end
end

GameConfig.SpawnPosition = Vector3.new(0, 2, 18)

return GameConfig
