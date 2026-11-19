-- MonsterWarningClient — the monster event banner and countdown.
-- When the Naga Nila stirs, a full-width banner warns every player with
-- a live countdown; during the event it counts the danger down and tells
-- the player to finish reels fast and guard their tanks. After the event
-- it shows the Calm Water Blessing. The banner is the game's loudest
-- piece of feedback — it must be impossible to miss.

local Players = game:GetService("Players")
local UIHelpers = require(script.Parent.UIHelpers)

local MonsterWarningClient = {}

local player = Players.LocalPlayer
local bannerFrame = nil
local bannerTitle = nil
local bannerCountdown = nil
local currentPhase = "idle"
-- Epoch token: each phase change bumps it, and a stale countdown loop
-- (task.spawn returns a thread, which has no Disconnect) exits quietly
-- when its token no longer matches.
local countdownEpoch = 0

function MonsterWarningClient.Init(remoteFolder)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "MonsterWarningUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	bannerFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 520, 0, 84), UDim2.new(0.5, -260, 0, 16),
		Color3.fromRGB(60, 15, 15), 0.1)
	bannerFrame.Visible = false
	bannerTitle = UIHelpers.MakeLabel(bannerFrame, UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0.05, 0),
		"THE LAKE STIRS...", 28, Color3.fromRGB(255, 120, 120))
	bannerCountdown = UIHelpers.MakeLabel(bannerFrame, UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.6, 0), "", 18)

	remoteFolder.MonsterPhase.OnClientEvent:Connect(function(phase, secondsLeft)
		MonsterWarningClient.OnPhaseChanged(phase, secondsLeft)
	end)
end

function MonsterWarningClient.OnPhaseChanged(phase, secondsLeft)
	currentPhase = phase
	countdownEpoch += 1
	local myEpoch = countdownEpoch

	if phase == "idle" then
		bannerFrame.Visible = false
		return
	end

	bannerFrame.Visible = true
	if phase == "warning" then
		bannerTitle.Text = "THE LAKE STIRS..."
		bannerTitle.TextColor3 = Color3.fromRGB(255, 120, 120)
		bannerCountdown.Text = "NAGA NILA rises in " .. secondsLeft .. "s — guard your tanks!"
	elseif phase == "active" then
		bannerTitle.Text = "NAGA NILA STIRS!"
		bannerTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
		bannerCountdown.Text = "Finish your reel in 10s! Unguarded tanks can be raided!"
	elseif phase == "blessing" then
		bannerTitle.Text = "THE LAKE CALMS..."
		bannerTitle.TextColor3 = Color3.fromRGB(120, 220, 255)
		bannerCountdown.Text = "Calm Water Blessing: +10% luck for 60s!"
	end

	-- Live countdown, ticking once a second until the phase ends or a
	-- newer phase change makes this loop stale.
	local remaining = secondsLeft
	task.spawn(function()
		while remaining > 0 and currentPhase == phase and countdownEpoch == myEpoch do
			task.wait(1)
			remaining -= 1
			if phase == "warning" then
				bannerCountdown.Text = "NAGA NILA rises in " .. remaining .. "s — guard your tanks!"
			elseif phase == "active" then
				bannerCountdown.Text = "Monster active for " .. remaining .. "s — finish your reel fast!"
			end
		end
	end)
end

return MonsterWarningClient
