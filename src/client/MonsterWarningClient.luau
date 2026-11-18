-- MonsterWarningClient: the lake monster's drama. Warning banner + countdown
-- while Naga Nila stirs, a red alert while the event is active (reels have a
-- 10-second limit!), and the calm + blessing message when it ends. A screen
-- tint sells the mood shift.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local MonsterWarningClient = {}

local player = Players.LocalPlayer
local banner = nil
local bannerTitle = nil
local bannerSub = nil
local tint = nil
local countdownUntil = 0
local countdownConnection = nil

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function StopCountdown()
	if countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
end

local function StartCountdown(seconds, label)
	StopCountdown()
	countdownUntil = os.clock() + seconds
	countdownConnection = game:GetService("RunService").Heartbeat:Connect(function()
		local remaining = math.max(0, countdownUntil - os.clock())
		bannerSub.Text = label .. "  " .. string.format("%.0f", remaining) .. "s"
		if remaining <= 0 then
			StopCountdown()
		end
	end)
end

function MonsterWarningClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")

	-- Full-screen tint (subtle, never blocks clicks).
	tint = Instance.new("Frame")
	tint.Name = "MonsterTint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Active = false
	tint.Parent = gui

	-- Banner under the cash panel.
	banner = UIHelpers.NewPanel(gui, "MonsterBanner", UDim2.fromOffset(560, 76), UDim2.new(0.5, 0, 0, 124), Vector2.new(0.5, 0))
	banner.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
	banner.Visible = false
	bannerTitle = UIHelpers.NewLabel(banner, "Title", "THE LAKE STIRS...", UDim2.new(1, -16, 0.55, 0), UDim2.new(0, 8, 0, 4), 24, Color3.fromRGB(255, 120, 120))
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Center
	bannerSub = UIHelpers.NewLabel(banner, "Sub", "", UDim2.new(1, -16, 0.4, 0), UDim2.new(0, 8, 0.55, 0), 16, UIHelpers.TextWhite)
	bannerSub.TextXAlignment = Enum.TextXAlignment.Center

	GetRemote("MonsterEvent").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "warning" then
			bannerTitle.Text = "THE LAKE STIRS..."
			bannerTitle.TextColor3 = Color3.fromRGB(255, 180, 100)
			banner.BackgroundColor3 = Color3.fromRGB(60, 30, 10)
			tint.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
			tint.BackgroundTransparency = 0.88
			banner.Visible = true
			StartCountdown(data.Seconds or 15, "Naga Nila is coming!")
		elseif kind == "active" then
			bannerTitle.Text = "NAGA NILA STIRS!"
			bannerTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
			banner.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
			tint.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
			tint.BackgroundTransparency = 0.85
			banner.Visible = true
			StartCountdown(data.Seconds or 30, "Reel fast — 10s limit! Guard your tanks!")
		elseif kind == "ended" then
			StopCountdown()
			bannerTitle.Text = "The lake calms..."
			bannerTitle.TextColor3 = UIHelpers.AccentGreen
			bannerSub.Text = "Calm Water Blessing: +10% luck for 60 seconds!"
			banner.BackgroundColor3 = Color3.fromRGB(15, 50, 25)
			tint.BackgroundTransparency = 1
			banner.Visible = true
			task.delay(5, function()
				banner.Visible = false
			end)
		elseif kind == "raided" then
			UIHelpers.ShowToast("The monster raided your tank! Lost " .. (data.FishName or "a fish") .. ".", UIHelpers.AccentRed, 5)
		end
	end)
end

return MonsterWarningClient
