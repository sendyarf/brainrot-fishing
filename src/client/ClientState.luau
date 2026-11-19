-- ClientState — the client's cache of the server's truth. The server
-- pushes the full player state on join and after every change; this
-- module holds the latest copy and lets every UI module read it without
-- asking the server again. It never writes game state itself: purchases,
-- casts and claims all go through RemoteEvents to the server.

local ClientState = {}

local state = {
	cash = 0,
	incomePerSecond = 0,
	rebirthMultiplier = 1,
	rebirths = 0,
	rod = "bamboo",
	bait = "bread",
	tankSlots = 3,
	tankUsed = 0,
	fish = {},
	spots = {},
	collection = {},
	totalCaught = 0,
	quests = {},
	dailyDay = 0,
	blessingActive = false,
	blessingSeconds = 0,
}

local listeners = {}

function ClientState.Update(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	for _, listener in ipairs(listeners) do
		local ok, err = pcall(listener, state)
		if not ok then
			warn("[ClientState] Listener failed: " .. tostring(err))
		end
	end
end

function ClientState.Get()
	return state
end

function ClientState.GetField(field)
	return state[field]
end

-- UI modules register here to redraw when the state changes.
function ClientState.OnChange(listener)
	table.insert(listeners, listener)
end

return ClientState
