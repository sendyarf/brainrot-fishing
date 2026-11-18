-- WaveThiefService: the shadow thief. During a monster wave, the raid no
-- longer deletes a fish silently — a cloaked thief rises from the lake
-- shore, walks to the victim's base, channels 3 seconds on the cheapest
-- tank (visible red beam + alert banner), steals the fish, and melts back
-- into the lake. The owner can save the fish by guarding (within 15 studs
-- of the base) or locking the base before the channel finishes: the thief
-- flees at once. Functions: SendThief.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local TankService = require(script.Parent:WaitForChild("TankService"))

local WaveThiefService = {}

local WALK_SPEED = 12
local CHANNEL_SECONDS = 3

-- activeThieves[player] = true while a thief is working that victim.
local activeThieves = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function GetRootPosition(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- True while the owner can still be robbed: tanks left, base unlocked and
-- unguarded. Checked continuously, so guarding or locking mid-theft saves
-- the fish.
local function IsRobbable(player)
	local data = DataService.GetData(player)
	if not data or #data.Tanks == 0 or data.LockUntil > os.clock() then
		return false
	end
	local basePos = TankService.GetBasePosition(player)
	local playerPos = GetRootPosition(player)
	if playerPos and (playerPos - basePos).Magnitude <= GameConfig.MonsterGuardRadius then
		return false
	end
	return true
end

local function MakePart(model, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

-- A cloaked shadow figure: stepped voxel robe, a voxel head with a dark
-- face plate + glowing red cube eyes, a pointed voxel hood (stacked
-- shrinking boxes, not a ball), a sash, and a sack on its back for the
-- stolen fish. A red light so it reads at night, and a tall red beacon
-- beam so the player can spot it from across the lake (the thief walks in
-- behind a fishing player, who would otherwise never see it). Fix 12:
-- voxel detail to match the fish + the monster (the old ball head/hood
-- looked plain next to them).
local function BuildThiefModel()
	local model = Instance.new("Model")
	model.Name = "ShadowThief"
	local robeColor = Color3.fromRGB(45, 28, 65)
	local bottom = MakePart(model, "RobeBottom", Vector3.new(2.2, 1.2, 2.2), Vector3.new(0, 0.6, 0), robeColor)
	MakePart(model, "RobeMid", Vector3.new(1.7, 1.2, 1.7), Vector3.new(0, 1.8, 0), robeColor)
	MakePart(model, "RobeTop", Vector3.new(1.2, 1, 1.2), Vector3.new(0, 2.9, 0), robeColor)
	-- Voxel robe folds: small cubes on the robe sides so the silhouette
	-- reads as cloth, not a plain stack.
	MakePart(model, "RobeFoldL", Vector3.new(0.3, 1.6, 0.3), Vector3.new(-1, 1.6, 0.6), Color3.fromRGB(35, 22, 52))
	MakePart(model, "RobeFoldR", Vector3.new(0.3, 1.6, 0.3), Vector3.new(1, 1.6, 0.6), Color3.fromRGB(35, 22, 52))
	-- Sash around the robe waist + a sack on the back for stolen fish.
	MakePart(model, "Sash", Vector3.new(1.8, 0.3, 1.8), Vector3.new(0, 2.35, 0), Color3.fromRGB(180, 40, 50))
	MakePart(model, "Sack", Vector3.new(0.9, 1, 0.6), Vector3.new(0, 2.6, -0.9), Color3.fromRGB(150, 110, 60))
	MakePart(model, "SackTie", Vector3.new(0.5, 0.3, 0.4), Vector3.new(0, 3.2, -0.9), Color3.fromRGB(120, 85, 45))
	MakePart(model, "Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 4, 0), Color3.fromRGB(50, 35, 70))
	-- Dark face plate on the front (+Z) + glowing red cube eyes on it.
	MakePart(model, "FacePlate", Vector3.new(0.9, 0.9, 0.2), Vector3.new(0, 4, 0.5), Color3.fromRGB(20, 12, 30))
	for _, side in ipairs({ -1, 1 }) do
		MakePart(model, "Eye" .. (side < 0 and "L" or "R"), Vector3.new(0.28, 0.28, 0.2), Vector3.new(side * 0.25, 4.1, 0.62), Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
	end
	-- Pointed voxel hood: three stacked shrinking boxes over the head.
	MakePart(model, "HoodBase", Vector3.new(1.2, 0.5, 1.2), Vector3.new(0, 4.7, 0), robeColor)
	MakePart(model, "HoodMid", Vector3.new(0.8, 0.5, 0.8), Vector3.new(0, 5.1, 0), robeColor)
	MakePart(model, "HoodTip", Vector3.new(0.4, 0.6, 0.4), Vector3.new(0, 5.6, 0), robeColor)
	local beacon = MakePart(model, "Beacon", Vector3.new(0.5, 20, 0.5), Vector3.new(0, 12, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	beacon.Transparency = 0.5
	local light = Instance.new("PointLight")
	light.Name = "ThiefGlow"
	light.Color = Color3.fromRGB(255, 60, 60)
	light.Brightness = 2
	light.Range = 16
	light.Parent = bottom
	model.PrimaryPart = bottom
	return model
end

-- Walks the model through a list of waypoints in order (straight legs).
-- No pathfinder: the house aisles (2.4 studs) are narrower than the
-- pathfinder's agent diameter, so it would fail and fall back to a straight
-- line through the tables anyway. The thief's parts are CanCollide=false,
-- so a straight leg can never get it stuck — and the waypoints route it
-- down the center aisle and along the row aisle, so it never clips a
-- table visually. Returns false if the victim stopped being robbable.
local function WalkTo(model, waypoints, victim)
	local startY = model.PrimaryPart.Position.Y
	for _, target in ipairs(waypoints) do
		local dest = Vector3.new(target.X, startY, target.Z)
		while (model.PrimaryPart.Position - dest).Magnitude > 0.6 do
			if not IsRobbable(victim) then
				return false
			end
			local pos = model.PrimaryPart.Position
			local dir = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
			if dir.Magnitude < 0.01 then
				break
			end
			dir = dir.Unit
			local step = math.min(WALK_SPEED * 0.05, (dest - pos).Magnitude)
			local newPos = pos + dir * step
			local y = startY + math.sin(os.clock() * 4) * 0.2
			model:PivotTo(CFrame.new(newPos.X, y, newPos.Z) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0))
			task.wait(0.05)
		end
	end
	return true
end

-- Channels on a tank for 3 seconds: red beam + "!" marker + victim alert.
-- Returns false if the victim stopped being robbable mid-channel.
local function ChannelSteal(model, victim, tankIndex)
	local data = DataService.GetData(victim)
	local tank = data and data.Tanks[tankIndex]
	if not tank then
		return false
	end
	local def = FishDefinitions.Fish[tank.FishId]
	local tankPos = TankService.GetTankPosition(victim, tankIndex)
	local thiefPos = model.PrimaryPart.Position
	local beam = Instance.new("Part")
	beam.Name = "StealBeam"
	beam.Size = Vector3.new(0.25, 0.25, (tankPos - thiefPos).Magnitude)
	beam.CFrame = CFrame.lookAt((thiefPos + tankPos) / 2, tankPos)
	beam.Color = Color3.fromRGB(255, 60, 60)
	beam.Material = Enum.Material.Neon
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = model
	local marker = Instance.new("BillboardGui")
	marker.Name = "StealMarker"
	marker.Size = UDim2.fromOffset(60, 60)
	marker.StudsOffset = Vector3.new(0, 5, 0)
	marker.AlwaysOnTop = true
	local markLabel = Instance.new("TextLabel")
	markLabel.Size = UDim2.fromScale(1, 1)
	markLabel.BackgroundTransparency = 1
	markLabel.Text = "!"
	markLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	markLabel.TextSize = 48
	markLabel.Font = Enum.Font.GothamBold
	markLabel.Parent = marker
	marker.Parent = model.PrimaryPart
	GetRemote("StealUpdate"):FireClient(victim, "alert", {
		FishName = def and def.Name or "Fish",
		ThiefName = "A shadow thief",
	})
	for _ = 1, CHANNEL_SECONDS * 4 do
		task.wait(0.25)
		if not IsRobbable(victim) then
			beam:Destroy()
			marker:Destroy()
			return false
		end
	end
	beam:Destroy()
	marker:Destroy()
	return true
end

-- Sinks the model into the ground and destroys it.
local function Despawn(model)
	for _ = 1, 10 do
		if not model.Parent then
			return
		end
		model:PivotTo(model:GetPivot() - Vector3.new(0, 0.5, 0))
		task.wait(0.05)
	end
	model:Destroy()
end

-- Sends one thief to rob `trips` fish from the victim, one per trip.
function WaveThiefService.SendThief(victim, trips)
	if activeThieves[victim] or trips <= 0 then
		return
	end
	activeThieves[victim] = true
	task.spawn(function()
		local world = game:GetService("Workspace"):FindFirstChild("BrainrotFishingWorld")
		if not world then
			activeThieves[victim] = nil
			return
		end
		local basePos = TankService.GetBasePosition(victim)
		local spawnPos = Vector3.new(basePos.X, 0.6, 12)
		local model = BuildThiefModel()
		model.Parent = world
		-- Rise out of the sand.
		model:PivotTo(CFrame.new(spawnPos - Vector3.new(0, 5, 0)))
		for _ = 1, 10 do
			model:PivotTo(model:GetPivot() + Vector3.new(0, 0.5, 0))
			task.wait(0.05)
		end
		for _ = 1, trips do
			if not IsRobbable(victim) then
				break
			end
			local cheapestIndex = TankService.GetCheapestTankIndex(victim)
			if not cheapestIndex then
				break
			end
			local tankPos = TankService.GetTankPosition(victim, cheapestIndex)
			local approach = Vector3.new(tankPos.X, 0.6, tankPos.Z - 4)
			-- Into the house down the center aisle (x = baseX), then
			-- sideways along the aisle in front of the tank's row. The
			-- house front is open, so the entrance waypoint is just the
			-- front wall line (baseZ - 12).
			local entrance = Vector3.new(basePos.X, 0.6, basePos.Z - 12)
			local aisle = Vector3.new(basePos.X, 0.6, approach.Z)
			if not WalkTo(model, { entrance, aisle, approach }, victim) then
				break
			end
			local facing = tankPos - model.PrimaryPart.Position
			model:PivotTo(CFrame.new(model.PrimaryPart.Position) * CFrame.Angles(0, math.atan2(facing.X, facing.Z), 0))
			if not ChannelSteal(model, victim, cheapestIndex) then
				break
			end
			local lost = TankService.RemoveFishFromTank(victim, cheapestIndex)
			if lost then
				local def = FishDefinitions.Fish[lost.FishId]
				GetRemote("MonsterEvent"):FireClient(victim, "raided", {
					FishName = def and def.Name or "Fish",
				})
				DataService.BroadcastState(victim)
			end
			-- Walk back to the shore before the next trip (or to despawn):
			-- sideways to the center aisle, then straight out the entrance.
			if not WalkTo(model, { Vector3.new(basePos.X, 0.6, approach.Z), spawnPos }, victim) then
				break
			end
		end
		Despawn(model)
		activeThieves[victim] = nil
	end)
end

Players.PlayerRemoving:Connect(function(player)
	activeThieves[player] = nil
end)

return WaveThiefService
