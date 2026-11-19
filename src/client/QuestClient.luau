-- QuestClient — the daily quest panel: three quests with progress bars
-- and a claim button each. Progress is tracked by the server and pushed
-- with the state sync; claiming fires ClaimQuest and the server pays.
-- A compact quest tracker also sits in the bottom-right of the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientState = require(script.Parent.ClientState)
local UIHelpers = require(script.Parent.UIHelpers)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local QuestClient = {}

local player = Players.LocalPlayer
local remotes = nil
local questFrame = nil
local questOpen = false
local trackerFrame = nil
local trackerLabels = {}

function QuestClient.Init(remoteFolder)
	remotes = remoteFolder
	-- The compact tracker lives on screen all the time.
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestTrackerUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	trackerFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 240, 0, 110), UDim2.new(1, -256, 1, -230))
	UIHelpers.MakeLabel(trackerFrame, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4), "DAILY QUESTS", 15, UIHelpers.ACCENT)
	for i, quest in ipairs(GameConfig.QUESTS) do
		local label = UIHelpers.MakeLabel(trackerFrame, UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 28 + (i - 1) * 26),
			quest.name .. " 0/" .. quest.goal, 14, UIHelpers.TEXT)
		label.TextXAlignment = Enum.TextXAlignment.Left
		trackerLabels[quest.id] = label
	end
	ClientState.OnChange(function(state)
		QuestClient.RefreshTracker(state)
	end)
end

function QuestClient.RefreshTracker(state)
	if not trackerFrame then
		return
	end
	for _, quest in ipairs(GameConfig.QUESTS) do
		local label = trackerLabels[quest.id]
		if label then
			local entry = state.quests[quest.id] or { progress = 0, claimed = false }
			if entry.claimed then
				label.Text = quest.name .. " DONE"
				label.TextColor3 = UIHelpers.GREEN
			else
				label.Text = quest.name .. " " .. entry.progress .. "/" .. quest.goal
				label.TextColor3 = UIHelpers.TEXT
			end
		end
	end
end

local function buildQuestPanel()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("QuestUI")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "QuestUI"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui
	end
	if questFrame then
		questFrame:Destroy()
	end
	questFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 480, 0, 400), UDim2.new(0.5, -240, 0.5, -200))
	UIHelpers.MakeLabel(questFrame, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), "DAILY QUESTS", 28, UIHelpers.ACCENT)
	local closeButton = UIHelpers.MakeButton(questFrame, UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8), "X", 20)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.MouseButton1Click:Connect(function()
		QuestClient.ToggleQuests()
	end)

	local state = ClientState.Get()
	local y = 64
	for _, quest in ipairs(GameConfig.QUESTS) do
		local entry = state.quests[quest.id] or { progress = 0, claimed = false }
		local row = UIHelpers.MakeFrame(questFrame, UDim2.new(1, -16, 0, 80), UDim2.new(0, 8, 0, y),
			Color3.fromRGB(35, 42, 60), 0.1)
		UIHelpers.MakeLabel(row, UDim2.new(0.6, 0, 0, 26), UDim2.new(0, 10, 0, 6), quest.name, 18)
		local progressBar = UIHelpers.MakeFrame(row, UDim2.new(0.6, 0, 0, 14), UDim2.new(0, 10, 0, 40),
			Color3.fromRGB(60, 65, 80), 0)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(math.min(entry.progress / quest.goal, 1), 0, 1, 0)
		fill.BackgroundColor3 = UIHelpers.GREEN
		fill.BorderSizePixel = 0
		fill.Parent = progressBar
		UIHelpers.MakeLabel(row, UDim2.new(0.6, 0, 0, 18), UDim2.new(0, 10, 0, 56),
			entry.progress .. " / " .. quest.goal .. "  ·  Reward $" .. quest.reward, 13, UIHelpers.MUTED)
		local claimButton = UIHelpers.MakeButton(row, UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0, 20), "CLAIM", 16)
		if entry.claimed then
			claimButton.Text = "CLAIMED"
			claimButton.BackgroundColor3 = Color3.fromRGB(90, 140, 90)
			claimButton.Active = false
		elseif entry.progress < quest.goal then
			claimButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			claimButton.Active = false
		else
			claimButton.MouseButton1Click:Connect(function()
				remotes.ClaimQuest:FireServer(quest.id)
				task.wait(0.3)
				if questOpen then
					buildQuestPanel()
				end
			end)
		end
		y += 88
	end

	-- Daily reward row: the 7-day streak, claimable once per UTC day.
	-- Mirrors the server's day-boundary check (CanClaimDaily).
	local SECONDS_PER_DAY = 86400
	local claimedAt = state.dailyClaimedAt or 0
	local canClaim = claimedAt == 0
		or math.floor(os.time() / SECONDS_PER_DAY) > math.floor(claimedAt / SECONDS_PER_DAY)
	local nextDay = math.min((state.dailyDay or 0) + 1, #GameConfig.DAILY_REWARDS)
	local reward = GameConfig.DAILY_REWARDS[nextDay] or GameConfig.DAILY_REWARDS[1]
	local dailyRow = UIHelpers.MakeFrame(questFrame, UDim2.new(1, -16, 0, 56), UDim2.new(0, 8, 0, y),
		Color3.fromRGB(50, 45, 20), 0.1)
	UIHelpers.MakeLabel(dailyRow, UDim2.new(0.6, 0, 0, 26), UDim2.new(0, 10, 0, 4),
		"Daily Reward — Day " .. nextDay, 18)
	UIHelpers.MakeLabel(dailyRow, UDim2.new(0.6, 0, 0, 20), UDim2.new(0, 10, 0, 30),
		"Come back every day for up to $1,500", 13, UIHelpers.MUTED)
	local dailyButton = UIHelpers.MakeButton(dailyRow, UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0, 8),
		canClaim and ("CLAIM $" .. reward) or "CLAIMED", 16)
	if canClaim then
		dailyButton.MouseButton1Click:Connect(function()
			remotes.ClaimDaily:FireServer()
			task.wait(0.3)
			if questOpen then
				buildQuestPanel()
			end
		end)
	else
		dailyButton.BackgroundColor3 = Color3.fromRGB(90, 140, 90)
		dailyButton.Active = false
	end
end

function QuestClient.ToggleQuests()
	questOpen = not questOpen
	if questOpen then
		buildQuestPanel()
	elseif questFrame then
		questFrame:Destroy()
		questFrame = nil
	end
end

return QuestClient
