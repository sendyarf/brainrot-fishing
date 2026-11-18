-- MonsterState: a tiny shared flag so FishingService can read the monster event
-- state without requiring MonsterEventService (which would be a require cycle).
-- MonsterEventService writes it; FishingService reads it for reel deadlines.

local MonsterState = {}
MonsterState.Active = false
MonsterState.Phase = "Calm" -- "Calm" | "Warning" | "Active"
MonsterState.NextEventAt = 0 -- os.clock() timestamp of the next wave

function MonsterState.SetActive(active)
	MonsterState.Active = active
end

function MonsterState.IsActive()
	return MonsterState.Active
end

function MonsterState.SetPhase(phase)
	MonsterState.Phase = phase
end

function MonsterState.GetPhase()
	return MonsterState.Phase
end

function MonsterState.SetNextEventAt(at)
	MonsterState.NextEventAt = at
end

-- Seconds until the next wave (0 while one is running or unscheduled).
function MonsterState.GetSecondsUntilNext()
	return math.max(0, MonsterState.NextEventAt - os.clock())
end

return MonsterState
