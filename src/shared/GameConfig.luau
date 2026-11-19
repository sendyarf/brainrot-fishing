-- GameConfig — every tunable number in Brainrot Fishing, in one place.
-- Prices, catch odds, timers and world positions live here so the economy
-- can be rebalanced without touching any system's logic.

local GameConfig = {}

-- ---------------------------------------------------------------------------
-- Economy
-- ---------------------------------------------------------------------------

GameConfig.STARTING_CASH = 0
GameConfig.INCOME_TICK_SECONDS = 1
GameConfig.TANK_FULL_SELL_MULTIPLIER = 100 -- overflow catch sells for income * 100
GameConfig.MAX_REBIRTHS = 5
GameConfig.REBIRTH_CASH_REQUIRED = 25000
GameConfig.REBIRTH_MULTIPLIER_PER_LEVEL = 0.5 -- +50% income per rebirth, additive
GameConfig.COMPLETE_DEX_BONUS_CASH = 2000

-- ---------------------------------------------------------------------------
-- Rods (one active; buying is a permanent upgrade)
-- ---------------------------------------------------------------------------

GameConfig.RODS = {
	{ id = "bamboo", name = "Bamboo Rod", price = 0, luck = 0, perfectBonus = 0, mythicBoost = 1 },
	{ id = "wooden", name = "Wooden Rod", price = 150, luck = 10, perfectBonus = 0, mythicBoost = 1 },
	{ id = "steel", name = "Steel Rod", price = 600, luck = 20, perfectBonus = 0.10, mythicBoost = 1 },
	{ id = "golden", name = "Golden Rod", price = 2000, luck = 35, perfectBonus = 0.20, mythicBoost = 1 },
	{ id = "dragon", name = "Dragon Rod", price = 6000, luck = 50, perfectBonus = 0.30, mythicBoost = 2 },
}

-- ---------------------------------------------------------------------------
-- Baits (one active; buying is a permanent passive luck bonus)
-- ---------------------------------------------------------------------------

GameConfig.BAITS = {
	{ id = "bread", name = "Bread", price = 0, luck = 0 },
	{ id = "worm", name = "Worm Bait", price = 100, luck = 5 },
	{ id = "shiny", name = "Shiny Lure", price = 500, luck = 10 },
	{ id = "dragonbait", name = "Dragon Bait", price = 1500, luck = 15 },
}

GameConfig.MAX_LUCK_PERCENT = 80

-- ---------------------------------------------------------------------------
-- Tank slots: start with 3, buy up to 12. Prices in buy order.
-- ---------------------------------------------------------------------------

GameConfig.STARTING_TANK_SLOTS = 3
GameConfig.MAX_TANK_SLOTS = 12
GameConfig.TANK_SLOT_PRICES = { 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200 }

-- ---------------------------------------------------------------------------
-- Fishing spots and their catch tables (Bamboo rod + Bread bait baseline).
-- Each row is a percentage chance per rarity tier.
-- ---------------------------------------------------------------------------

GameConfig.SPOTS = {
	shallow = {
		name = "Shallow Shore",
		price = 0,
		position = Vector3.new(0, 1, 14),
		odds = { Common = 60, Rare = 25, Epic = 10, Legendary = 4, Mythic = 1 },
	},
	deep = {
		name = "Deep Dock",
		price = 500,
		position = Vector3.new(0, 1, -28),
		odds = { Common = 45, Rare = 30, Epic = 17, Legendary = 6, Mythic = 2 },
	},
	abyss = {
		name = "Abyss Point",
		price = 2500,
		position = Vector3.new(-62, 1, -52),
		odds = { Common = 30, Rare = 30, Epic = 25, Legendary = 11, Mythic = 4 },
	},
	royal = {
		name = "Royal Pond",
		price = 0, -- unlocked by the first rebirth, not by cash
		requiresRebirth = true,
		position = Vector3.new(62, 1, -58),
		odds = { Common = 15, Rare = 25, Epic = 30, Legendary = 20, Mythic = 10 },
	},
}

GameConfig.SPOT_ORDER = { "shallow", "deep", "abyss", "royal" }

-- ---------------------------------------------------------------------------
-- Mutations (rolled independently on every catch; Rainbow beats Golden)
-- ---------------------------------------------------------------------------

GameConfig.GOLDEN_CHANCE_PERCENT = 5
GameConfig.GOLDEN_INCOME_MULTIPLIER = 2
GameConfig.RAINBOW_CHANCE_PERCENT = 1
GameConfig.RAINBOW_INCOME_MULTIPLIER = 4

-- ---------------------------------------------------------------------------
-- Reel minigame
-- ---------------------------------------------------------------------------

GameConfig.REEL_POINTS_TO_CATCH = 3
GameConfig.REEL_MISSES_TO_ESCAPE = 3
GameConfig.REEL_PERFECT_POINTS = 2
GameConfig.REEL_GOOD_POINTS = 1
GameConfig.REEL_PERFECT_LUCK_BONUS = 5 -- +5% luck on this catch per Perfect hit
GameConfig.CAST_WAIT_MIN_SECONDS = 2
GameConfig.CAST_WAIT_MAX_SECONDS = 5

-- ---------------------------------------------------------------------------
-- Stealing and base lock
-- ---------------------------------------------------------------------------

GameConfig.STEAL_HOLD_SECONDS = 3
GameConfig.STEAL_OWNER_CANCEL_RADIUS = 12 -- owner this close cancels the steal
GameConfig.LOCK_DURATION_SECONDS = 300 -- 5 minutes
GameConfig.LOCK_COOLDOWN_SECONDS = 600 -- 10 minutes

-- ---------------------------------------------------------------------------
-- Lake monster event
-- ---------------------------------------------------------------------------

GameConfig.MONSTER_INTERVAL_MIN_SECONDS = 240 -- 4 minutes
GameConfig.MONSTER_INTERVAL_MAX_SECONDS = 360 -- 6 minutes
GameConfig.MONSTER_FIRST_DELAY_SECONDS = 90 -- first event 90s after server start
GameConfig.MONSTER_WARNING_SECONDS = 15
GameConfig.MONSTER_DURATION_SECONDS = 30
GameConfig.MONSTER_REEL_LIMIT_SECONDS = 10 -- reel must finish in 10s during the event
GameConfig.MONSTER_TANGLE_SECONDS = 10 -- rod tangled this long if the catch escapes
GameConfig.MONSTER_RAID_CHANCE_PERCENT = 25 -- per unlocked tank
GameConfig.MONSTER_GUARD_RADIUS = 15 -- owner this close to base guards the tanks
GameConfig.BLESSING_DURATION_SECONDS = 60
GameConfig.BLESSING_LUCK_BONUS = 10

-- ---------------------------------------------------------------------------
-- Daily quests (reset every new session)
-- ---------------------------------------------------------------------------

GameConfig.QUESTS = {
	{ id = "catch5", name = "Catch 5 fish", goal = 5, reward = 150, kind = "catches" },
	{ id = "earn1000", name = "Earn $1,000 total", goal = 1000, reward = 300, kind = "earned" },
	{ id = "rare1", name = "Catch a Rare or better", goal = 1, reward = 500, kind = "rareCatches" },
}

-- ---------------------------------------------------------------------------
-- Daily rewards (7-day streak) and offline earnings
-- ---------------------------------------------------------------------------

GameConfig.DAILY_REWARDS = { 100, 200, 350, 500, 750, 1000, 1500 }
GameConfig.OFFLINE_EARNINGS_RATE = 0.5 -- 50% of normal income while away
GameConfig.OFFLINE_EARNINGS_CAP = 5000
GameConfig.OFFLINE_EARNINGS_MAX_HOURS = 12

-- ---------------------------------------------------------------------------
-- World layout (studs). WorldBuilder reads these positions.
-- ---------------------------------------------------------------------------

GameConfig.WORLD = {
	lakeCenter = Vector3.new(0, -1, -40),
	lakeSize = Vector3.new(220, 2, 180),
	shoreCenter = Vector3.new(0, -2, 62),
	shoreSize = Vector3.new(220, 2, 90),
	spawnPosition = Vector3.new(0, 3, 12),
	-- Eight base plots along the shore, x from -84 to +84.
	basePlots = {
		Vector3.new(-84, 0, 38),
		Vector3.new(-60, 0, 38),
		Vector3.new(-36, 0, 38),
		Vector3.new(-12, 0, 38),
		Vector3.new(12, 0, 38),
		Vector3.new(36, 0, 38),
		Vector3.new(60, 0, 38),
		Vector3.new(84, 0, 38),
	},
	monsterPosition = Vector3.new(0, -4, -70),
	questBoardPosition = Vector3.new(-6, 0, 20),
	leaderboardPosition = Vector3.new(6, 0, 20),
}

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------

function GameConfig.GetRodById(rodId)
	for _, rod in ipairs(GameConfig.RODS) do
		if rod.id == rodId then
			return rod
		end
	end
	return GameConfig.RODS[1]
end

function GameConfig.GetBaitById(baitId)
	for _, bait in ipairs(GameConfig.BAITS) do
		if bait.id == baitId then
			return bait
		end
	end
	return GameConfig.BAITS[1]
end

function GameConfig.GetSpotById(spotId)
	return GameConfig.SPOTS[spotId] or GameConfig.SPOTS.shallow
end

function GameConfig.GetQuestById(questId)
	for _, quest in ipairs(GameConfig.QUESTS) do
		if quest.id == questId then
			return quest
		end
	end
	return nil
end

return GameConfig
