-- StealService — stealing fish from other players' tanks, and the base
-- lock that stops it. A thief holds E on a tank for 3 seconds (the
-- ProximityPrompt does the hold); the server validates at completion:
-- the tank must be unlocked, the owner must not be nearby, and the thief
-- needs a free tank slot. LOCK BASE seals every tank for 5 minutes with
-- a 10-minute cooldown. No combat, no damage — stealing is the only
-- player-vs-player interaction, and that is enough.

local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local FishDefinitions = require(game:GetService("ReplicatedStorage").Shared.FishDefinitions)

local StealService = {}

local dataService = nil
local economyService = nil
local tankService = nil
local notifyEvent = nil
local stealAlertEvent = nil

-- [userId] = { lockedUntil, cooldownUntil } (os.clock seconds)
local lockState = {}

function StealService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	tankService = deps.TankService
	notifyEvent = deps.Notify
	stealAlertEvent = deps.StealAlert
end

function StealService.IsBaseLocked(player)
	local state = lockState[player.UserId]
	if not state then
		return false
	end
	return os.clock() < state.lockedUntil
end

function StealService.GetLockSecondsLeft(player)
	local state = lockState[player.UserId]
	if not state then
		return 0
	end
	return math.max(0, state.lockedUntil - os.clock())
end

function StealService.GetLockCooldownSecondsLeft(player)
	local state = lockState[player.UserId]
	if not state then
		return 0
	end
	return math.max(0, state.cooldownUntil - os.clock())
end

-- Locks the player's base for 5 minutes. Free, 10-minute cooldown.
function StealService.LockBase(player)
	local state = lockState[player.UserId]
	if not state then
		state = { lockedUntil = 0, cooldownUntil = 0 }
		lockState[player.UserId] = state
	end
	if os.clock() < state.cooldownUntil then
		local left = math.ceil(state.cooldownUntil - os.clock())
		if notifyEvent then
			notifyEvent:FireClient(player, "Lock is on cooldown (" .. left .. "s left).")
		end
		return false
	end
	state.lockedUntil = os.clock() + GameConfig.LOCK_DURATION_SECONDS
	state.cooldownUntil = os.clock() + GameConfig.LOCK_COOLDOWN_SECONDS
	if notifyEvent then
		notifyEvent:FireClient(player, "Base locked for 5 minutes! Your tanks are safe.")
	end
	economyService.PushState(player)
	return true
end

-- Attempts a steal: thief takes the fish at tankIndex from the owner's base.
-- Returns true if the fish changed hands.
function StealService.CompleteSteal(thief, ownerUserId, tankIndex)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner or owner == thief then
		return false
	end
	if StealService.IsBaseLocked(owner) then
		if notifyEvent then
			notifyEvent:FireClient(thief, "That base is locked!")
		end
		return false
	end

	-- The owner standing close to the tank cancels the steal.
	local ownerCharacter = owner.Character
	local thiefCharacter = thief.Character
	if ownerCharacter and ownerCharacter:FindFirstChild("HumanoidRootPart") then
		local basePosition = tankService.GetBasePosition(owner)
		if basePosition then
			local distance = (ownerCharacter.HumanoidRootPart.Position - basePosition).Magnitude
			if distance <= GameConfig.STEAL_OWNER_CANCEL_RADIUS then
				if notifyEvent then
					notifyEvent:FireClient(thief, "The owner is guarding their base!")
				end
				return false
			end
		end
	end

	-- The thief must be near the victim's base to steal.
	if thiefCharacter and thiefCharacter:FindFirstChild("HumanoidRootPart") then
		local basePosition = tankService.GetBasePosition(owner)
		if basePosition then
			local distance = (thiefCharacter.HumanoidRootPart.Position - basePosition).Magnitude
			if distance > 25 then
				return false
			end
		end
	end

	local stolen = tankService.RemoveFishFromTank(owner, tankIndex)
	if not stolen then
		return false
	end

	local fish = FishDefinitions.GetFishById(stolen.fishId)
	local fishName = fish and fish.name or "a fish"

	-- The stolen fish goes into the thief's tank, or sells if full.
	local placed, salePrice = tankService.AddFishToTank(thief, stolen)
	if not placed then
		economyService.AddCash(thief, salePrice, "steal_overflow_sale")
		if notifyEvent then
			notifyEvent:FireClient(thief, "Stole " .. fishName .. "! Tanks full, sold for $" .. salePrice)
		end
	else
		if notifyEvent then
			notifyEvent:FireClient(thief, "You stole " .. fishName .. "!")
		end
	end

	-- The victim gets an alert with the thief's name.
	if stealAlertEvent then
		stealAlertEvent:FireClient(owner, thief.Name, fishName)
	end

	economyService.PushState(owner)
	economyService.PushState(thief)
	return true
end

function StealService.ClearPlayer(player)
	lockState[player.UserId] = nil
end

return StealService
