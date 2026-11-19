-- MonsterState — the shared, single source of truth for the lake monster
-- event's phase. The event service writes it; fishing, the HUD and the
-- blessing checks read it. Phases: "idle" → "warning" → "active" →
-- "blessing" → "idle". Keeping this in its own tiny module avoids the
-- circular requires that a shared service would create.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local MonsterState = {}

local phase = "idle" -- idle | warning | active | blessing
local phaseEndsAt = 0 -- os.clock when the current phase ends
local blessingEndsAt = 0 -- os.clock when the Calm Water Blessing ends

function MonsterState.GetPhase()
	return phase
end

function MonsterState.GetPhaseSecondsLeft()
	return math.max(0, phaseEndsAt - os.clock())
end

function MonsterState.SetPhase(newPhase, durationSeconds)
	phase = newPhase
	phaseEndsAt = os.clock() + durationSeconds
	if newPhase == "blessing" then
		blessingEndsAt = os.clock() + GameConfig.BLESSING_DURATION_SECONDS
	end
end

function MonsterState.IsEventActive()
	return phase == "active"
end

function MonsterState.IsWarning()
	return phase == "warning"
end

-- Returns (blessingActive, secondsLeft) for a player. The blessing is
-- server-wide: every player gets it after the monster calms down.
function MonsterState.GetBlessingForPlayer(_player)
	local left = blessingEndsAt - os.clock()
	if left > 0 then
		return true, math.ceil(left)
	end
	return false, 0
end

return MonsterState
