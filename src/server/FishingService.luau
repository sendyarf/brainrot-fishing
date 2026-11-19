-- FishingService — the cast → wait → reel → catch state machine.
-- The player casts from a fishing spot; after a short wait the bobber
-- sinks and the reel minigame starts on the client. The client reports
-- the reel result (points earned) and the server rolls the catch.
-- During a monster event the reel has a 10-second limit; failing it
-- tangles the rod for 10 seconds. All rolls happen on the server.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local FishingService = {}

local dataService = nil
local economyService = nil
local catchService = nil
local tankService = nil
local questService = nil
local monsterState = nil
local catchBannerEvent = nil
local notifyEvent = nil

-- [userId] = { state, spotId, perfectHits, castStartedAt, tangledUntil }
local fishingState = {}

function FishingService.Init(deps)
	dataService = deps.DataService
	economyService = deps.EconomyService
	catchService = deps.CatchService
	tankService = deps.TankService
	questService = deps.QuestService
	monsterState = deps.MonsterState
	catchBannerEvent = deps.CatchBanner
	notifyEvent = deps.Notify
end

local function getState(player)
	local state = fishingState[player.UserId]
	if not state then
		state = { state = "idle", spotId = "shallow", perfectHits = 0, castStartedAt = 0, tangledUntil = 0 }
		fishingState[player.UserId] = state
	end
	return state
end

function FishingService.IsTangled(player)
	return os.clock() < getState(player).tangledUntil
end

function FishingService.GetFishingState(player)
	return getState(player).state
end

-- Total luck for a catch: rod + bait + Perfect hits + blessing, capped.
function FishingService.GetTotalLuck(player)
	local data = dataService.GetData(player)
	if not data then
		return 0
	end
	local rod = GameConfig.GetRodById(data.rod)
	local bait = GameConfig.GetBaitById(data.bait)
	local luck = rod.luck + bait.luck
	luck += getState(player).perfectHits * GameConfig.REEL_PERFECT_LUCK_BONUS
	if monsterState then
		local blessingActive = monsterState.GetBlessingForPlayer(player)
		if blessingActive then
			luck += GameConfig.BLESSING_LUCK_BONUS
		end
	end
	return math.min(luck, GameConfig.MAX_LUCK_PERCENT)
end

-- Starts a cast at the given spot. Returns true if the cast began.
function FishingService.StartCast(player, spotId)
	local state = getState(player)
	if state.state ~= "idle" then
		return false
	end
	if FishingService.IsTangled(player) then
		if notifyEvent then
			notifyEvent:FireClient(player, "Your rod is tangled! Wait a moment.")
		end
		return false
	end

	local data = dataService.GetData(player)
	if not data then
		return false
	end
	local spot = GameConfig.GetSpotById(spotId)
	-- Locked spots need to be bought first (Royal needs a rebirth).
	if spotId == "deep" and not data.spots.deep then
		return false
	end
	if spotId == "abyss" and not data.spots.abyss then
		return false
	end
	if spotId == "royal" and data.rebirths < 1 then
		return false
	end

	state.state = "waiting"
	state.spotId = spotId
	state.perfectHits = 0
	state.castStartedAt = os.clock()

	-- The bobber sinks after 2-5 seconds; then the client starts the reel.
	local waitSeconds = math.random(GameConfig.CAST_WAIT_MIN_SECONDS, GameConfig.CAST_WAIT_MAX_SECONDS)
	task.delay(waitSeconds, function()
		if getState(player).state == "waiting" then
			getState(player).state = "reeling"
			-- The client watches the state via its own timer; the server
			-- enforces the monster-event reel limit here.
			if monsterState and monsterState.IsEventActive() then
				task.delay(GameConfig.MONSTER_REEL_LIMIT_SECONDS, function()
					local current = getState(player)
					if current.state == "reeling" then
						current.state = "idle"
						current.tangledUntil = os.clock() + GameConfig.MONSTER_TANGLE_SECONDS
						if notifyEvent then
							notifyEvent:FireClient(player, "The monster scared your catch away! Rod tangled.")
						end
					end
				end)
			end
		end
	end)
	return true
end

-- Resolves the reel minigame result sent by the client.
-- points: reel points earned (3+ catches the fish). perfectHits: Perfect-zone hits.
function FishingService.ResolveReel(player, success, points, perfectHits)
	local state = getState(player)
	if state.state ~= "reeling" and state.state ~= "waiting" then
		return
	end
	state.state = "idle"
	state.perfectHits = perfectHits or 0

	if not success or (points or 0) < GameConfig.REEL_POINTS_TO_CATCH then
		if notifyEvent then
			notifyEvent:FireClient(player, "It got away...")
		end
		return
	end

	local data = dataService.GetData(player)
	if not data then
		return
	end
	local rod = GameConfig.GetRodById(data.rod)
	local luck = FishingService.GetTotalLuck(player)
	local fish, mutation, tier = catchService.RollCatch(state.spotId, luck, rod.mythicBoost)

	local fishEntry = { fishId = fish.id, mutation = mutation }
	local placed, salePrice = tankService.AddFishToTank(player, fishEntry)
	if not placed then
		-- Tanks full: the catch is sold automatically.
		economyService.AddCash(player, salePrice, "tank_full_sale")
		if notifyEvent then
			notifyEvent:FireClient(player, "Tank full! Sold " .. fish.name .. " for $" .. salePrice)
		end
	else
		-- Record the catch in the collection (best income per fish).
		local income = economyService.GetFishIncome(fishEntry)
		local best = data.collection[fish.id] or 0
		if income > best then
			data.collection[fish.id] = income
		end
	end

	data.totalCaught += 1
	if tier == "Rare" or tier == "Epic" or tier == "Legendary" or tier == "Mythic" then
		data.rareCaught += 1
	end

	if questService then
		questService.TrackProgress(player, "catches", 1)
		if tier ~= "Common" then
			questService.TrackProgress(player, "rareCatches", 1)
		end
	end

	if catchBannerEvent then
		catchBannerEvent:FireClient(player, fish.id, mutation, economyService.GetFishIncome(fishEntry))
	end
	economyService.PushState(player)
end

function FishingService.CancelFishing(player)
	local state = getState(player)
	state.state = "idle"
end

function FishingService.ClearPlayer(player)
	fishingState[player.UserId] = nil
end

return FishingService
