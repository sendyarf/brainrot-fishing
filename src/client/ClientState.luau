-- ClientState: the client's copy of the server state snapshot. HUDClient writes
-- it on every StateSync; every panel reads it. Changed fires after each update.

local ClientState = {}

local state = {
	Cash = 0,
	Income = 0,
	Rod = "Bamboo",
	Bait = "Bread",
	TankSlots = 3,
	TankCount = 0,
	Tanks = {},
	Spots = { Shallow = true, Deep = false, Abyss = false, Royal = false },
	Rebirths = 0,
	RebirthMultiplier = 1,
	LockRemaining = 0,
	LockCooldownRemaining = 0,
	BlessingRemaining = 0,
	TangledRemaining = 0,
	Quests = {},
	Collection = {},
	CaughtByTier = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 },
	TotalCaught = 0,
	TotalEarned = 0,
	PlotIndex = 0,
	DailyStreak = 0,
	LastDailyClaimDay = 0,
}

ClientState.Changed = Instance.new("BindableEvent")

function ClientState.Get()
	return state
end

function ClientState.Update(snapshot)
	if type(snapshot) == "table" then
		for key, value in pairs(snapshot) do
			state[key] = value
		end
		ClientState.Changed:Fire(state)
	end
end

return ClientState
