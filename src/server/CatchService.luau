-- CatchService — rolls what a cast catches: rarity tier, fish and mutation.
-- The spot sets the baseline odds; luck (rod + bait + Perfect hits +
-- blessing) upgrades the tier. Each luck point is a percent chance to climb
-- one tier. Mythic stays Mythic. Mutations roll independently afterwards.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local FishDefinitions = require(game:GetService("ReplicatedStorage").Shared.FishDefinitions)

local CatchService = {}

local TIER_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

-- Rolls a rarity tier from a spot's odds table (percentages).
local function rollTierFromOdds(odds)
	local roll = math.random(1, 100)
	local running = 0
	for _, tier in ipairs(TIER_ORDER) do
		running += odds[tier] or 0
		if roll <= running then
			return tier
		end
	end
	return "Common"
end

-- Applies luck: each luck point is a 1% chance to climb one tier.
function CatchService.ApplyLuckBonus(tier, luckPercent)
	local index = table.find(TIER_ORDER, tier) or 1
	local capped = math.min(luckPercent, GameConfig.MAX_LUCK_PERCENT)
	if math.random(1, 100) <= capped and index < #TIER_ORDER then
		index += 1
	end
	return TIER_ORDER[index]
end

-- Rolls the mutation for a catch. Rainbow (1%) beats Golden (5%).
function CatchService.RollMutation()
	local roll = math.random(1, 100)
	if roll <= GameConfig.RAINBOW_CHANCE_PERCENT then
		return "rainbow"
	elseif roll <= GameConfig.RAINBOW_CHANCE_PERCENT + GameConfig.GOLDEN_CHANCE_PERCENT then
		return "golden"
	end
	return "none"
end

-- Full catch roll: tier from the spot, luck upgrade, a random fish in the
-- tier, then the mutation. Returns (fish, mutation, tier).
function CatchService.RollCatch(spotId, luckPercent, mythicBoost)
	local spot = GameConfig.GetSpotById(spotId)
	local tier = rollTierFromOdds(spot.odds)

	-- The Dragon Rod doubles the Mythic chance: re-roll once if not Mythic.
	if mythicBoost and mythicBoost > 1 and tier ~= "Mythic" then
		local second = rollTierFromOdds(spot.odds)
		if second == "Mythic" then
			tier = "Mythic"
		end
	end

	tier = CatchService.ApplyLuckBonus(tier, luckPercent)
	local fish = FishDefinitions.GetRandomFishInRarity(tier)
	if not fish then
		fish = FishDefinitions.GetFishById("lele")
	end
	local mutation = CatchService.RollMutation()
	return fish, mutation, tier
end

return CatchService
