-- CatchService: the catch lottery. Rolls a rarity tier from the spot's table,
-- bumps tiers with the player's luck, picks a fish inside the tier, and rolls
-- Golden/Rainbow mutations. Pure logic: no state of its own.
-- Functions: RollCatch, RollMutation, ApplyLuckBonus.

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FishDefinitions"))

local CatchService = {}

-- Rolls a rarity tier from the spot's weighted table (Dragon Rod doubles Mythic).
local function RollTier(spotId, mythicMult)
	local spot = GameConfig.Spots[spotId]
	if not spot then
		spot = GameConfig.Spots.Shallow
	end
	local weights = {}
	local total = 0
	for _, tier in ipairs(FishDefinitions.RarityOrder) do
		local w = spot.Rates[tier] or 0
		if tier == "Mythic" then
			w = w * (mythicMult or 1)
		end
		weights[tier] = w
		total = total + w
	end
	local roll = math.random() * total
	local acc = 0
	for _, tier in ipairs(FishDefinitions.RarityOrder) do
		acc = acc + weights[tier]
		if roll <= acc then
			return tier
		end
	end
	return "Common"
end

-- Each luck point is a chance (luck%) to bump the catch one tier up.
-- Luck is capped at 80%; Mythic never bumps further.
function CatchService.ApplyLuckBonus(tier, luckPercent)
	local luck = math.min(luckPercent or 0, 80)
	if luck <= 0 then
		return tier
	end
	if math.random(1, 100) <= luck then
		return FishDefinitions.GetNextTier(tier)
	end
	return tier
end

-- Rolls a mutation. Rainbow (1%) beats Golden (5%) when both hit.
function CatchService.RollMutation()
	local rainbow = math.random() < GameConfig.MutationRates.Rainbow
	local golden = math.random() < GameConfig.MutationRates.Golden
	if rainbow then
		return "Rainbow"
	elseif golden then
		return "Golden"
	end
	return "None"
end

-- Rolls one full catch: tier (spot table + luck), a fish inside the tier,
-- and a mutation. luckPercent = rod luck + bait luck + blessing + Perfect hits.
-- Mythic picks are weighted (Naga 40, Tung 25, Tralalero 20, Bombardiro 15);
-- every other tier picks uniformly.
function CatchService.RollCatch(spotId, luckPercent, mythicMult)
	local tier = RollTier(spotId, mythicMult)
	tier = CatchService.ApplyLuckBonus(tier, luckPercent)
	local pool = FishDefinitions.FishByTier[tier] or FishDefinitions.FishByTier.Common
	local fishId = pool[math.random(1, #pool)]
	if tier == "Mythic" and FishDefinitions.MythicWeights then
		local total = 0
		for _, id in ipairs(pool) do
			total = total + (FishDefinitions.MythicWeights[id] or 0)
		end
		if total > 0 then
			local roll = math.random() * total
			local acc = 0
			for _, id in ipairs(pool) do
				acc = acc + (FishDefinitions.MythicWeights[id] or 0)
				if roll <= acc then
					fishId = id
					break
				end
			end
		end
	end
	local mutation = CatchService.RollMutation()
	return fishId, tier, mutation
end

return CatchService
