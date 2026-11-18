-- StealService: the steal-and-lock game. A thief holds E for 3 seconds at an
-- unlocked tank; the victim gets an alert; the channel breaks if the owner
-- comes within 12 studs or the thief lets go or walks away. LOCK BASE locks
-- every tank for 5 minutes (10-minute cooldown, free).
-- Functions: StartSteal, CancelSteal, CompleteSteal, LockBase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TankService = require(script.Parent:WaitForChild("TankService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local StealService = {}

-- activeSteals[thief] = { Owner, TankIndex, Holding }
local activeSteals = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function GetRootPosition(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Cancels a thief's in-progress steal (released E, walked away, or owner near).
function StealService.CancelSteal(thief, reason)
	local steal = activeSteals[thief]
	if not steal then
		return
	end
	activeSteals[thief] = nil
	GetRemote("StealUpdate"):FireClient(thief, "cancelled", { Reason = reason or "Steal cancelled." })
end

-- Completes a steal: the fish moves to the thief's tank (or sells if full).
function StealService.CompleteSteal(thief)
	local steal = activeSteals[thief]
	if not steal then
		return
	end
	activeSteals[thief] = nil
	local owner = steal.Owner
	local ownerData = DataService.GetData(owner)
	local thiefData = DataService.GetData(thief)
	if not ownerData or not thiefData then
		return
	end
	local stolen = TankService.RemoveFishFromTank(owner, steal.TankIndex)
	if not stolen then
		return
	end
	local def = FishDefinitions.Fish[stolen.FishId]
	local result, soldFor = TankService.AddFishToTank(thief, stolen.FishId, stolen.Mutation)
	if result == "sold" then
		EconomyService.AddCash(thief, soldFor)
	end
	DataService.BroadcastState(owner)
	DataService.BroadcastState(thief)
	GetRemote("StealUpdate"):FireClient(thief, "stolen", {
		FishName = def and def.Name or "Fish",
		SoldFor = result == "sold" and soldFor or 0,
	})
	GetRemote("StealUpdate"):FireClient(owner, "victim", {
		FishName = def and def.Name or "Fish",
		ThiefName = thief.Name,
	})
end

-- Begins a 3-second steal channel. The channel is watched every 0.2s: it
-- breaks if the owner comes within 12 studs, the thief leaves the tank, or
-- the thief releases the prompt.
function StealService.StartSteal(thief, owner, tankIndex)
	if thief == owner then
		return
	end
	if activeSteals[thief] then
		return
	end
	local ownerData = DataService.GetData(owner)
	local thiefData = DataService.GetData(thief)
	if not ownerData or not thiefData then
		return
	end
	if ownerData.LockUntil > os.clock() then
		GetRemote("StealUpdate"):FireClient(thief, "blocked", { Reason = "That base is locked!" })
		return
	end
	local tank = ownerData.Tanks[tankIndex]
	if not tank then
		return
	end
	local tankPos = TankService.GetTankPosition(owner, tankIndex)
	local ownerPos = GetRootPosition(owner)
	if ownerPos and (ownerPos - tankPos).Magnitude <= GameConfig.StealCancelRadius then
		GetRemote("StealUpdate"):FireClient(thief, "blocked", { Reason = "The owner is guarding this tank!" })
		return
	end
	local def = FishDefinitions.Fish[tank.FishId]
	activeSteals[thief] = { Owner = owner, TankIndex = tankIndex, Holding = true }
	-- Alert the victim immediately.
	GetRemote("StealUpdate"):FireClient(owner, "alert", {
		FishName = def and def.Name or "Fish",
		ThiefName = thief.Name,
	})
	GetRemote("StealUpdate"):FireClient(thief, "started", { FishName = def and def.Name or "Fish" })

	-- Watch the channel: 15 checks of 0.2s = 3 seconds.
	task.spawn(function()
		for _ = 1, 15 do
			task.wait(0.2)
			local steal = activeSteals[thief]
			if not steal or not steal.Holding then
				return
			end
			local ownerDataNow = DataService.GetData(owner)
			if not ownerDataNow or ownerDataNow.LockUntil > os.clock() then
				StealService.CancelSteal(thief, "The base was locked!")
				return
			end
			if not ownerDataNow.Tanks[steal.TankIndex] then
				StealService.CancelSteal(thief, "That fish is gone.")
				return
			end
			local thiefPos = GetRootPosition(thief)
			if not thiefPos or (thiefPos - tankPos).Magnitude > 10 then
				StealService.CancelSteal(thief, "You moved too far from the tank.")
				return
			end
			local ownerPosNow = GetRootPosition(owner)
			if ownerPosNow and (ownerPosNow - tankPos).Magnitude <= GameConfig.StealCancelRadius then
				StealService.CancelSteal(thief, "The owner caught you!")
				return
			end
		end
		StealService.CompleteSteal(thief)
	end)
end

-- Marks a thief's hold as released (ProximityPrompt hold ended).
function StealService.ReleaseHold(thief)
	local steal = activeSteals[thief]
	if steal then
		steal.Holding = false
		StealService.CancelSteal(thief, "You let go.")
	end
end

-- Locks ALL of the player's tanks for 5 minutes (10-minute cooldown, free).
function StealService.LockBase(player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local now = os.clock()
	if data.LockUntil > now then
		GetRemote("StealUpdate"):FireClient(player, "lockinfo", { Message = "Your base is already locked." })
		return
	end
	if data.LockCooldownUntil > now then
		local remaining = math.ceil(data.LockCooldownUntil - now)
		GetRemote("StealUpdate"):FireClient(player, "lockinfo", { Message = "Lock recharges in " .. remaining .. "s." })
		return
	end
	data.LockUntil = now + GameConfig.LockDuration
	data.LockCooldownUntil = now + GameConfig.LockCooldown
	TankService.SetLockVisual(player, true)
	DataService.BroadcastState(player)
	GetRemote("StealUpdate"):FireClient(player, "locked", { Duration = GameConfig.LockDuration })
	-- Auto-unlock visuals when the lock expires.
	task.delay(GameConfig.LockDuration, function()
		local current = DataService.GetData(player)
		if current and current.LockUntil <= os.clock() then
			TankService.SetLockVisual(player, false)
			DataService.BroadcastState(player)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	activeSteals[player] = nil
end)

return StealService
