-- FishingClient — casting input and the reel minigame.
-- Press E (or click the rod) near water to cast. After a few seconds the
-- bobber sinks and the reel bar appears: a needle sweeps back and forth
-- and the player presses E/click to stop it in a zone. Perfect = 2 reel
-- points + luck bonus, Good = 1 point, Miss = 0 and the needle speeds
-- up. 3 points lands the fish; 3 misses in a row and it escapes.
-- The client runs the minigame and reports the result; the server rolls
-- the catch, so the client never decides what was caught.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ClientState = require(script.Parent.ClientState)
local UIHelpers = require(script.Parent.UIHelpers)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local FishingClient = {}

local player = Players.LocalPlayer
local remotes = nil

local fishing = false -- a cast is in progress
local reeling = false -- the reel minigame is showing
local reelPoints = 0
local reelMisses = 0
local perfectHits = 0
local needlePosition = 0 -- 0..1 across the bar
local needleDirection = 1
local needleSpeed = 0.9 -- bar crossings per second
local reelConnection = nil

local reelFrame = nil
local needle = nil
local pointsLabel = nil
local promptLabel = nil
local bannerFrame = nil
local bannerTitle = nil
local bannerSubtitle = nil

function FishingClient.Init(remoteFolder)
	remotes = remoteFolder

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishingUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- "Press E to Cast" prompt, bottom centre.
	promptLabel = UIHelpers.MakeLabel(gui, UDim2.new(0, 300, 0, 40), UDim2.new(0.5, -150, 1, -120),
		"Press E to Cast", 22, UIHelpers.TEXT)
	promptLabel.BackgroundTransparency = 0.4
	promptLabel.BackgroundColor3 = UIHelpers.PANEL

	-- Reel bar, hidden until a bite.
	reelFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 420, 0, 54), UDim2.new(0.5, -210, 1, -160))
	reelFrame.Visible = false

	-- Miss zone (the whole bar, red at the edges).
	local missZone = Instance.new("Frame")
	missZone.Size = UDim2.new(1, 0, 1, 0)
	missZone.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	missZone.BorderSizePixel = 0
	missZone.Parent = reelFrame
	local missCorner = Instance.new("UICorner")
	missCorner.CornerRadius = UDim.new(0, 10)
	missCorner.Parent = missZone

	-- Good zone (yellow, middle 50%).
	local goodZone = Instance.new("Frame")
	goodZone.Name = "GoodZone"
	goodZone.Size = UDim2.new(0.5, 0, 1, 0)
	goodZone.Position = UDim2.new(0.25, 0, 0, 0)
	goodZone.BackgroundColor3 = Color3.fromRGB(240, 200, 60)
	goodZone.BorderSizePixel = 0
	goodZone.Parent = reelFrame

	-- Perfect zone (green, middle 16% + rod bonus).
	local perfectZone = Instance.new("Frame")
	perfectZone.Name = "PerfectZone"
	perfectZone.Size = UDim2.new(0.16, 0, 1, 0)
	perfectZone.Position = UDim2.new(0.42, 0, 0, 0)
	perfectZone.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	perfectZone.BorderSizePixel = 0
	perfectZone.Parent = reelFrame

	-- The needle.
	needle = Instance.new("Frame")
	needle.Size = UDim2.new(0, 6, 1, 0)
	needle.Position = UDim2.new(0, 0, 0, 0)
	needle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	needle.BorderSizePixel = 0
	needle.Parent = reelFrame

	pointsLabel = UIHelpers.MakeLabel(gui, UDim2.new(0, 300, 0, 30), UDim2.new(0.5, -150, 1, -200),
		"Reel Points: 0/3", 20, UIHelpers.ACCENT)
	pointsLabel.Visible = false

	-- Catch banner, centre screen.
	bannerFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 460, 0, 110), UDim2.new(0.5, -230, 0.25, 0))
	bannerFrame.Visible = false
	bannerTitle = UIHelpers.MakeLabel(bannerFrame, UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0.05, 0), "", 30)
	bannerSubtitle = UIHelpers.MakeLabel(bannerFrame, UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.6, 0), "", 20, UIHelpers.GREEN)

	-- Catch banner from the server.
	remotes.CatchBanner.OnClientEvent:Connect(function(fishId, mutation, income)
		FishingClient.ShowCatchBanner(fishId, mutation, income)
	end)

	-- E key: cast, or stop the needle while reeling.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			if reeling then
				FishingClient.StopNeedle()
			elseif not fishing then
				FishingClient.TryCast()
			end
		end
	end)

	-- Clicking the rod tool also casts.
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			tool.Activated:Connect(function()
				if not fishing and not reeling then
					FishingClient.TryCast()
				elseif reeling then
					FishingClient.StopNeedle()
				end
			end)
		end
	end)
end

-- Picks the nearest owned fishing spot and starts a cast there.
function FishingClient.TryCast()
	local state = ClientState.Get()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local position = character.HumanoidRootPart.Position

	-- Nearest spot wins; locked spots fall back to the shallow shore.
	local bestSpot = "shallow"
	local bestDistance = math.huge
	for _, spotId in ipairs(GameConfig.SPOT_ORDER) do
		local spot = GameConfig.GetSpotById(spotId)
		local owned = spotId == "shallow"
			or state.spots[spotId]
			or (spotId == "royal" and state.rebirths >= 1)
		if owned then
			local distance = (position - spot.position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestSpot = spotId
			end
		end
	end

	fishing = true
	promptLabel.Text = "Casting..."
	remotes.CastFish:FireServer(bestSpot)

	-- The bite comes after the server's wait; start the reel when it does.
	-- We poll the server state: the reel begins ~2-5s after the cast.
	local waitSeconds = math.random(GameConfig.CAST_WAIT_MIN_SECONDS, GameConfig.CAST_WAIT_MAX_SECONDS)
	task.delay(waitSeconds, function()
		if fishing then
			FishingClient.StartReel()
		end
	end)
end

function FishingClient.StartReel()
	reeling = true
	reelPoints = 0
	reelMisses = 0
	perfectHits = 0
	needlePosition = 0
	needleDirection = 1
	needleSpeed = 0.9

	-- Wider Perfect zone for better rods.
	local state = ClientState.Get()
	local rod = GameConfig.GetRodById(state.rod)
	local perfectWidth = 0.16 * (1 + rod.perfectBonus)
	local perfectZone = reelFrame:FindFirstChild("PerfectZone")
	if perfectZone then
		perfectZone.Size = UDim2.new(perfectWidth, 0, 1, 0)
		perfectZone.Position = UDim2.new(0.5 - perfectWidth / 2, 0, 0, 0)
	end

	reelFrame.Visible = true
	pointsLabel.Visible = true
	pointsLabel.Text = "Reel Points: 0/3"
	promptLabel.Text = "Press E in the GREEN!"

	reelConnection = RunService.RenderStepped:Connect(function(deltaTime)
		needlePosition += needleDirection * needleSpeed * deltaTime
		if needlePosition >= 1 then
			needlePosition = 1
			needleDirection = -1
		elseif needlePosition <= 0 then
			needlePosition = 0
			needleDirection = 1
		end
		needle.Position = UDim2.new(needlePosition, 0, 0, 0)
	end)
end

function FishingClient.StopNeedle()
	if not reeling then
		return
	end
	local state = ClientState.Get()
	local rod = GameConfig.GetRodById(state.rod)
	local perfectWidth = 0.16 * (1 + rod.perfectBonus)
	local perfectMin = 0.5 - perfectWidth / 2
	local perfectMax = 0.5 + perfectWidth / 2

	if needlePosition >= perfectMin and needlePosition <= perfectMax then
		reelPoints += GameConfig.REEL_PERFECT_POINTS
		perfectHits += 1
		pointsLabel.Text = "PERFECT! Reel Points: " .. reelPoints .. "/3"
	elseif needlePosition >= 0.25 and needlePosition <= 0.75 then
		reelPoints += GameConfig.REEL_GOOD_POINTS
		pointsLabel.Text = "Good! Reel Points: " .. reelPoints .. "/3"
	else
		reelMisses += 1
		needleSpeed *= 1.1 -- the fish struggles; the needle speeds up
		pointsLabel.Text = "Miss! (" .. reelMisses .. "/3 misses)"
	end

	if reelPoints >= GameConfig.REEL_POINTS_TO_CATCH then
		FishingClient.EndReel(true)
	elseif reelMisses >= GameConfig.REEL_MISSES_TO_ESCAPE then
		FishingClient.EndReel(false)
	end
end

function FishingClient.EndReel(success)
	reeling = false
	fishing = false
	if reelConnection then
		reelConnection:Disconnect()
		reelConnection = nil
	end
	reelFrame.Visible = false
	pointsLabel.Visible = false
	promptLabel.Text = "Press E to Cast"
	remotes.ReelResult:FireServer(success, reelPoints, perfectHits)
end

function FishingClient.ShowCatchBanner(fishId, mutation, income)
	local FishDefinitions = require(ReplicatedStorage.Shared.FishDefinitions)
	local fish = FishDefinitions.GetFishById(fishId)
	if not fish then
		return
	end
	local mutationTag = ""
	if mutation == "golden" then
		mutationTag = "GOLDEN "
	elseif mutation == "rainbow" then
		mutationTag = "RAINBOW "
	end
	bannerTitle.Text = mutationTag .. string.upper(fish.rarity) .. "! " .. fish.name
	bannerTitle.TextColor3 = FishDefinitions.GetRarityColor(fish.rarity)
	bannerSubtitle.Text = "$" .. income .. "/s added to your tanks"
	bannerFrame.Visible = true
	task.delay(4, function()
		bannerFrame.Visible = false
	end)
end

return FishingClient
