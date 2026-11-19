-- LeaderboardService — the server leaderboard: the richest anglers in
-- this server, ranked by cash, shown on the wooden board at the dock
-- and sent to clients for the HUD. It refreshes every 30 seconds from
-- live player data, so it always reflects this server's race.

local Players = game:GetService("Players")

local LeaderboardService = {}

local dataService = nil
local leaderboardEvent = nil
local boardSurface = nil -- SurfaceGui on the dock board, set by WorldBuilder

function LeaderboardService.Init(deps)
	dataService = deps.DataService
	leaderboardEvent = deps.LeaderboardUpdate

	task.spawn(function()
		while true do
			task.wait(30)
			local success, err = pcall(function()
				LeaderboardService.RefreshLeaderboard()
			end)
			if not success then
				warn("[LeaderboardService] Refresh failed: " .. tostring(err))
			end
		end
	end)
end

function LeaderboardService.SetBoardSurface(surfaceGui)
	boardSurface = surfaceGui
end

-- Returns the top 5 players by cash: { {name, cash}, ... }.
function LeaderboardService.GetTopPlayers()
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = dataService.GetData(player)
		if data then
			table.insert(entries, { name = player.Name, cash = data.cash })
		end
	end
	table.sort(entries, function(a, b)
		return a.cash > b.cash
	end)
	local top = {}
	for i = 1, math.min(5, #entries) do
		top[i] = entries[i]
	end
	return top
end

function LeaderboardService.RefreshLeaderboard()
	local top = LeaderboardService.GetTopPlayers()
	if leaderboardEvent then
		leaderboardEvent:FireAllClients(top)
	end
	-- Update the physical board at the dock, if WorldBuilder made one.
	if boardSurface then
		local label = boardSurface:FindFirstChild("BoardText")
		if label then
			local lines = { "TOP ANGLERS" }
			for i, entry in ipairs(top) do
				table.insert(lines, i .. ". " .. entry.name .. "  $" .. entry.cash)
			end
			if #top == 0 then
				table.insert(lines, "No anglers yet!")
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end

return LeaderboardService
