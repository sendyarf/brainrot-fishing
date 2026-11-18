-- FishingClient: casting and the reel minigame. Detects the nearest fishing
-- spot, prompts "Press E to Cast", shows the bobber, and runs the needle bar:
-- Perfect (green, 2 points), Good (yellow, 1 point), Miss (red, 0 points).
-- Keys are bound with ContextActionService (never an InputBegan handler that
-- returns on gameProcessedEvent — the default camera eats the arrow keys).
-- Also welds the fishing rod into the character's hand.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local FishingClient = {}

local player = Players.LocalPlayer
local gui = nil
local promptLabel = nil
local arrowLabel = nil
local arrowNameLabel = nil
local reelFrame = nil
local needle = nil
local perfectZone = nil
local pointsLabel = nil
local timerLabel = nil
local reelButton = nil

local fishingPhase = "Idle" -- Idle | Waiting | Reeling
local currentSpotId = nil
local needleSpeed = 1
local reelStartTime = 0
local reelDeadline = 0
local missStreak = 0
local points = 0
local bobber = nil
local bobberAlert = nil
local rodModel = nil
local needleConnection = nil

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

-- Rod colors per tier (the rod in the character's hand changes as you upgrade).
local ROD_COLORS = {
	Bamboo = Color3.fromRGB(170, 130, 70),
	Wooden = Color3.fromRGB(120, 80, 40),
	Steel = Color3.fromRGB(160, 165, 175),
	Golden = Color3.fromRGB(255, 205, 60),
	Dragon = Color3.fromRGB(180, 60, 220),
}

-- Welds a fishing rod into the character's right hand.
local function AttachFishingRod(character)
	if rodModel then
		rodModel:Destroy()
		rodModel = nil
	end
	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand then
		return
	end
	local state = ClientState.Get()
	local rodColor = ROD_COLORS[state.Rod] or ROD_COLORS.Bamboo
	local model = Instance.new("Model")
	model.Name = "FishingRod"
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.14, 5.5, 0.14)
	shaft.Color = rodColor
	shaft.Material = Enum.Material.Wood
	shaft.CanCollide = false
	shaft.Parent = model
	local reel = Instance.new("Part")
	reel.Name = "Reel"
	reel.Size = Vector3.new(0.5, 0.5, 0.4)
	reel.Color = Color3.fromRGB(60, 60, 70)
	reel.Material = Enum.Material.Metal
	reel.CanCollide = false
	reel.Parent = model
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.08, 0.8, 0.08)
	tip.Color = UIHelpers.AccentGold
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Parent = model
	-- Weld the shaft to the hand, angled up and forward.
	local weld = Instance.new("Weld")
	weld.Part0 = rightHand
	weld.Part1 = shaft
	weld.C0 = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-50), 0, math.rad(15))
	weld.Parent = shaft
	local weld2 = Instance.new("Weld")
	weld2.Part0 = shaft
	weld2.Part1 = reel
	weld2.C0 = CFrame.new(0, -2.2, 0.3)
	weld2.Parent = reel
	local weld3 = Instance.new("Weld")
	weld3.Part0 = shaft
	weld3.Part1 = tip
	weld3.C0 = CFrame.new(0, 3, 0)
	weld3.Parent = tip
	model.Parent = character
	rodModel = model
end

local function UpdateRodColor()
	if not rodModel then
		return
	end
	local state = ClientState.Get()
	local shaft = rodModel:FindFirstChild("Shaft")
	if shaft then
		shaft.Color = ROD_COLORS[state.Rod] or ROD_COLORS.Bamboo
	end
end

-- The nearest fishing spot the player stands in (and whether they own it).
local function FindNearestSpot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, false
	end
	local state = ClientState.Get()
	for _, spotId in ipairs(GameConfig.SpotOrder) do
		local spot = GameConfig.Spots[spotId]
		local dist = (root.Position - spot.Position).Magnitude
		if dist <= spot.Radius + 6 then
			local owned = false
			if spotId == "Shallow" then
				owned = true
			elseif spotId == "Royal" then
				owned = state.Rebirths >= 1
			else
				owned = state.Spots and state.Spots[spotId] or false
			end
			return spotId, owned
		end
	end
	return nil, false
end

-- The nearest spot the player actually owns (Shallow is always owned).
-- The wayfinding arrow points here, so it always leads somewhere fishable.
local function FindNearestOwnedSpot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local state = ClientState.Get()
	local bestId = nil
	local bestDist = math.huge
	for _, spotId in ipairs(GameConfig.SpotOrder) do
		local spot = GameConfig.Spots[spotId]
		local owned = false
		if spotId == "Shallow" then
			owned = true
		elseif spotId == "Royal" then
			owned = state.Rebirths >= 1
		else
			owned = state.Spots and state.Spots[spotId] or false
		end
		if owned then
			local dist = (root.Position - spot.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestId = spotId
			end
		end
	end
	return bestId
end

-- Rotates the wayfinding arrow toward a spot, relative to the camera:
-- 0 = straight ahead, +90 = to the right, 180 = behind. Only the ▲ glyph
-- rotates — the spot name above it always stays readable.
local function PointArrowAt(spotId)
	if not arrowLabel or not arrowNameLabel then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = game:GetService("Workspace").CurrentCamera
	if not root or not camera or not spotId then
		arrowLabel.Visible = false
		arrowNameLabel.Visible = false
		return
	end
	local spot = GameConfig.Spots[spotId]
	local toSpot = spot.Position - root.Position
	toSpot = Vector3.new(toSpot.X, 0, toSpot.Z)
	if toSpot.Magnitude < 1 then
		arrowLabel.Visible = false
		arrowNameLabel.Visible = false
		return
	end
	toSpot = toSpot.Unit
	local camLook = camera.CFrame.LookVector
	camLook = Vector3.new(camLook.X, 0, camLook.Z)
	if camLook.Magnitude < 0.01 then
		arrowLabel.Visible = false
		arrowNameLabel.Visible = false
		return
	end
	camLook = camLook.Unit
	local crossY = camLook.Z * toSpot.X - camLook.X * toSpot.Z
	local dot = camLook.X * toSpot.X + camLook.Z * toSpot.Z
	arrowNameLabel.Text = spot.Name
	arrowLabel.Rotation = math.deg(math.atan2(-crossY, dot))
	arrowLabel.Visible = true
	arrowNameLabel.Visible = true
end

local function HideArrow()
	if arrowLabel then
		arrowLabel.Visible = false
	end
	if arrowNameLabel then
		arrowNameLabel.Visible = false
	end
end

local RemoveBobber

-- Creates the bobber at the cast point (in front of the player, on the water).
local function CreateBobber()
	RemoveBobber()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local castPos = root.Position + root.CFrame.LookVector * 9
	castPos = Vector3.new(castPos.X, 0.6, castPos.Z)
	local part = Instance.new("Part")
	part.Name = "FishingBobber"
	part.Size = Vector3.new(0.8, 0.8, 0.8)
	part.Shape = Enum.PartType.Ball
	part.Color = Color3.fromRGB(255, 60, 60)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Position = castPos
	part.Parent = game:GetService("Workspace")
	local alert = Instance.new("BillboardGui")
	alert.Name = "BiteAlert"
	alert.Size = UDim2.fromOffset(60, 60)
	alert.StudsOffset = Vector3.new(0, 2, 0)
	alert.AlwaysOnTop = true
	alert.Enabled = false
	alert.Parent = part
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "!"
	mark.TextColor3 = Color3.fromRGB(255, 220, 60)
	mark.TextSize = 44
	mark.Font = Enum.Font.GothamBold
	mark.TextStrokeTransparency = 0.3
	mark.Parent = alert
	bobber = part
	bobberAlert = alert
end

RemoveBobber = function()
	if bobber then
		bobber:Destroy()
		bobber = nil
		bobberAlert = nil
	end
end

-- Needle position 0..1 as a triangle wave over time.
local function GetNeedlePosition()
	local speed = 0.55 * needleSpeed * (GameConfig.ReelMissSpeedUp ^ missStreak)
	local phase = ((os.clock() - reelStartTime) * speed) % 2
	if phase < 1 then
		return phase
	end
	return 2 - phase
end

local function GetPerfectHalfWidth()
	local state = ClientState.Get()
	local rod = GameConfig.Rods[state.Rod]
	local bonus = rod and rod.PerfectBonus or 0
	return 0.07 * (1 + bonus / 100)
end

-- Which zone is the needle in right now?
local function GetCurrentZone()
	local pos = GetNeedlePosition()
	local dist = math.abs(pos - 0.5)
	if dist <= GetPerfectHalfWidth() then
		return "Perfect"
	elseif dist <= 0.22 then
		return "Good"
	end
	return "Miss"
end

-- One reel hit: report the zone to the server.
local function DoReelHit()
	if fishingPhase ~= "Reeling" then
		return
	end
	GetRemote("ReelResult"):FireServer(GetCurrentZone())
end

local function StopNeedle()
	if needleConnection then
		needleConnection:Disconnect()
		needleConnection = nil
	end
end

local function HideReel()
	StopNeedle()
	RemoveBobber()
	if reelFrame then
		reelFrame.Visible = false
	end
end

local function ShowReel(tier, speed, deadlineSeconds)
	fishingPhase = "Reeling"
	needleSpeed = speed
	missStreak = 0
	points = 0
	reelStartTime = os.clock()
	reelDeadline = os.clock() + deadlineSeconds
	-- Resize the Perfect zone for the equipped rod.
	local halfWidth = GetPerfectHalfWidth()
	perfectZone.Size = UDim2.new(halfWidth * 2, 0, 1, 0)
	perfectZone.Position = UDim2.new(0.5 - halfWidth, 0, 0, 0)
	pointsLabel.Text = "Reel Points: 0/3"
	reelFrame.Visible = true
	if bobberAlert then
		bobberAlert.Enabled = true
	end
	StopNeedle()
	needleConnection = RunService.RenderStepped:Connect(function()
		if fishingPhase ~= "Reeling" then
			return
		end
		local pos = GetNeedlePosition()
		needle.Position = UDim2.new(pos, -3, 0, 0)
		local remaining = math.max(0, reelDeadline - os.clock())
		timerLabel.Text = string.format("%.0fs", remaining)
		if remaining <= 0 then
			timerLabel.TextColor3 = UIHelpers.AccentRed
		else
			timerLabel.TextColor3 = UIHelpers.TextWhite
		end
	end)
end

-- The E key: cast when idle near a spot, reel-hit while reeling.
local function OnCastAction(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if fishingPhase == "Reeling" then
		DoReelHit()
		return Enum.ContextActionResult.Sink
	end
	if fishingPhase ~= "Idle" then
		return Enum.ContextActionResult.Sink
	end
	local spotId, owned = FindNearestSpot()
	if spotId and owned then
		GetRemote("CastFish"):FireServer(spotId)
	elseif spotId and not owned then
		if spotId == "Royal" then
			UIHelpers.ShowToast("Royal Pond opens after your first Rebirth!", UIHelpers.AccentGold, 3)
		else
			local spot = GameConfig.Spots[spotId]
			UIHelpers.ShowToast(spot.Name .. " costs " .. UIHelpers.FormatMoney(spot.Price) .. " in the Shop.", UIHelpers.AccentGold, 3)
		end
	end
	return Enum.ContextActionResult.Sink
end

function FishingClient.Init()
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")

	-- Cast prompt, bottom-center.
	promptLabel = UIHelpers.NewLabel(gui, "CastPrompt", "", UDim2.fromOffset(640, 36), UDim2.new(0.5, 0, 1, -180), 20, UIHelpers.TextWhite, Vector2.new(0.5, 0))
	promptLabel.TextXAlignment = Enum.TextXAlignment.Center
	promptLabel.Visible = false

	-- Wayfinding arrow, above the prompt: the ▲ points at the nearest owned
	-- fishing spot (name above it, never rotated) whenever the player is
	-- nowhere near water, so "walk to the glowing water" always has both
	-- a direction and a destination.
	arrowNameLabel = UIHelpers.NewLabel(gui, "SpotArrowName", "", UDim2.fromOffset(320, 26), UDim2.new(0.5, 0, 1, -252), 18, UIHelpers.AccentGold, Vector2.new(0.5, 0))
	arrowNameLabel.TextXAlignment = Enum.TextXAlignment.Center
	arrowNameLabel.Visible = false
	arrowLabel = UIHelpers.NewLabel(gui, "SpotArrow", "▲", UDim2.fromOffset(48, 36), UDim2.new(0.5, 0, 1, -224), 28, UIHelpers.AccentGold, Vector2.new(0.5, 0))
	arrowLabel.TextXAlignment = Enum.TextXAlignment.Center
	arrowLabel.Visible = false

	-- Reel minigame frame, bottom-center.
	reelFrame = UIHelpers.NewPanel(gui, "ReelFrame", UDim2.fromOffset(520, 130), UDim2.new(0.5, 0, 1, -160), Vector2.new(0.5, 1))
	reelFrame.Visible = false
	UIHelpers.NewLabel(reelFrame, "ReelTitle", "REEL IT IN!  Press E or tap REEL when the needle is green!", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 6), 15, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	-- The zone bar: red Miss base, yellow Good middle, green Perfect center.
	local barBack = Instance.new("Frame")
	barBack.Name = "ZoneBar"
	barBack.Size = UDim2.new(1, -20, 0, 36)
	barBack.Position = UDim2.new(0, 10, 0, 34)
	barBack.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	barBack.BorderSizePixel = 0
	barBack.Parent = reelFrame
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = barBack
	local goodZone = Instance.new("Frame")
	goodZone.Name = "GoodZone"
	goodZone.Size = UDim2.new(0.44, 0, 1, 0)
	goodZone.Position = UDim2.new(0.28, 0, 0, 0)
	goodZone.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	goodZone.BorderSizePixel = 0
	goodZone.Parent = barBack
	perfectZone = Instance.new("Frame")
	perfectZone.Name = "PerfectZone"
	perfectZone.Size = UDim2.new(0.14, 0, 1, 0)
	perfectZone.Position = UDim2.new(0.43, 0, 0, 0)
	perfectZone.BackgroundColor3 = Color3.fromRGB(60, 220, 100)
	perfectZone.BorderSizePixel = 0
	perfectZone.Parent = barBack
	needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.Size = UDim2.new(0, 6, 1, 6)
	needle.Position = UDim2.new(0, -3, 0, -3)
	needle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	needle.BorderSizePixel = 0
	needle.ZIndex = 3
	needle.Parent = barBack
	pointsLabel = UIHelpers.NewLabel(reelFrame, "Points", "Reel Points: 0/3", UDim2.new(0.5, 0, 0, 26), UDim2.new(0, 10, 0, 76), 17, UIHelpers.TextWhite)
	timerLabel = UIHelpers.NewLabel(reelFrame, "Timer", "30s", UDim2.new(0.3, 0, 0, 26), UDim2.new(0.55, 0, 0, 76), 17, UIHelpers.TextWhite)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	reelButton = UIHelpers.NewButton(reelFrame, "ReelButton", "REEL!", UDim2.fromOffset(120, 36), UDim2.new(1, -10, 0, 84), Color3.fromRGB(220, 160, 20), 20, Vector2.new(1, 0))
	reelButton.MouseButton1Click:Connect(DoReelHit)
	barBack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			DoReelHit()
		end
	end)

	-- Bind E for cast + reel hits (with an on-screen button on touch devices).
	ContextActionService:BindAction("BrainrotCast", OnCastAction, true, Enum.KeyCode.E)
	ContextActionService:SetTitle("BrainrotCast", "CAST")
	ContextActionService:SetPosition("BrainrotCast", UDim2.new(0.5, 0, 1, -250))

	-- Rod in hand on every spawn; recolor on rod upgrades.
	if player.Character then
		AttachFishingRod(player.Character)
	end
	player.CharacterAdded:Connect(AttachFishingRod)
	ClientState.Changed.Event:Connect(UpdateRodColor)

	-- Spot prompt refresh (4x per second).
	task.spawn(function()
		while true do
			task.wait(0.25)
			if fishingPhase == "Idle" then
				local spotId, owned = FindNearestSpot()
				currentSpotId = spotId
				if spotId then
					local spot = GameConfig.Spots[spotId]
					if owned then
						promptLabel.Text = "Press E to Cast  —  " .. spot.Name
						promptLabel.TextColor3 = UIHelpers.TextWhite
					else
						promptLabel.Text = spot.Name .. "  —  Locked (" .. UIHelpers.FormatMoney(spot.Price) .. " in the Shop)"
						promptLabel.TextColor3 = UIHelpers.AccentGold
					end
					promptLabel.Visible = true
					HideArrow()
				else
					-- No spot nearby: this is a TIP, not a quest — say so,
					-- point at the nearest water with the arrow, and name
					-- the light beam the player can actually see.
					promptLabel.Text = "TIP: Follow the light beam to the water — press E to fish!"
					promptLabel.TextColor3 = UIHelpers.TextDim
					promptLabel.Visible = true
					PointArrowAt(FindNearestOwnedSpot())
				end
			elseif fishingPhase == "Waiting" then
				promptLabel.Text = "Waiting for a bite..."
				promptLabel.TextColor3 = UIHelpers.TextDim
				promptLabel.Visible = true
				HideArrow()
			else
				promptLabel.Visible = false
				HideArrow()
			end
		end
	end)

	-- Server fishing updates.
	GetRemote("FishingUpdate").OnClientEvent:Connect(function(phase, data)
		data = data or {}
		if phase == "cast" then
			fishingPhase = "Waiting"
			CreateBobber()
		elseif phase == "bite" then
			ShowReel(data.Tier, data.NeedleSpeed or 1, data.DeadlineSeconds or 30)
		elseif phase == "hit" then
			points = data.Points or points
			missStreak = data.MissStreak or missStreak
			pointsLabel.Text = "Reel Points: " .. points .. "/3"
			if data.Zone == "Perfect" then
				pointsLabel.TextColor3 = Color3.fromRGB(60, 220, 100)
			elseif data.Zone == "Good" then
				pointsLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
			else
				pointsLabel.TextColor3 = UIHelpers.AccentRed
			end
		elseif phase == "escaped" then
			fishingPhase = "Idle"
			HideReel()
			UIHelpers.ShowToast(data.Reason or "It got away...", UIHelpers.AccentRed, 3)
		elseif phase == "tangled" then
			fishingPhase = "Idle"
			HideReel()
			UIHelpers.ShowToast("Your rod is tangled! Wait 10 seconds.", UIHelpers.AccentRed, 3)
		elseif phase == "cancelled" then
			fishingPhase = "Idle"
			HideReel()
		end
	end)

	-- A catch hides the reel bar.
	GetRemote("CatchBanner").OnClientEvent:Connect(function()
		fishingPhase = "Idle"
		HideReel()
	end)
end

return FishingClient
