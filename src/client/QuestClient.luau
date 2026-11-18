-- QuestClient: the daily quest panel. Three quests per session with progress
-- bars and CLAIM buttons. Progress is computed server-side from the player's
-- totals, so the panel only reads state and asks to claim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local QuestClient = {}

local player = Players.LocalPlayer
local panel = nil
local listFrame = nil
local isOpen = false

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function RefreshQuests()
	if not listFrame then
		return
	end
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local state = ClientState.Get()
	for i, configQuest in ipairs(GameConfig.Quests) do
		local quest = state.Quests and state.Quests[i] or { Progress = 0, Claimed = false }
		local y = 8 + (i - 1) * 92
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -16, 0, 84)
		row.Position = UDim2.new(0, 8, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(30, 38, 66)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = listFrame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		UIHelpers.NewLabel(row, "Name", configQuest.Name, UDim2.new(0.6, 0, 0, 26), UDim2.new(0, 12, 0, 8), 18, UIHelpers.TextWhite)
		-- The reward lives ON the button (it used to be a separate label
		-- that overlapped the button and got clipped by it).
		-- Progress bar.
		local barBack = Instance.new("Frame")
		barBack.Size = UDim2.new(1, -150, 0, 18)
		barBack.Position = UDim2.new(0, 12, 0, 44)
		barBack.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
		barBack.BorderSizePixel = 0
		barBack.Parent = row
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 6)
		barCorner.Parent = barBack
		local fill = Instance.new("Frame")
		local frac = math.min(quest.Progress / configQuest.Target, 1)
		fill.Size = UDim2.new(frac, 0, 1, 0)
		fill.BackgroundColor3 = quest.Claimed and UIHelpers.AccentGreen or UIHelpers.AccentGold
		fill.BorderSizePixel = 0
		fill.Parent = barBack
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 6)
		fillCorner.Parent = fill
		UIHelpers.NewLabel(row, "Progress", math.min(quest.Progress, configQuest.Target) .. " / " .. configQuest.Target, UDim2.new(1, -150, 0, 18), UDim2.new(0, 12, 0, 44), 13, UIHelpers.TextWhite).TextXAlignment = Enum.TextXAlignment.Center
		local button
		local rewardText = UIHelpers.FormatMoney(configQuest.Reward)
		if quest.Claimed then
			button = UIHelpers.NewButton(row, "Claim", "DONE", UDim2.fromOffset(110, 38), UDim2.new(1, -10, 0.5, 0), Color3.fromRGB(40, 160, 80), 16, Vector2.new(1, 0.5))
		elseif quest.Progress >= configQuest.Target then
			button = UIHelpers.NewButton(row, "Claim", "CLAIM " .. rewardText, UDim2.fromOffset(110, 38), UDim2.new(1, -10, 0.5, 0), Color3.fromRGB(220, 160, 20), 15, Vector2.new(1, 0.5))
			button.MouseButton1Click:Connect(function()
				GetRemote("ClaimQuest"):FireServer(configQuest.Id)
			end)
		else
			button = UIHelpers.NewButton(row, "Claim", rewardText, UDim2.fromOffset(110, 38), UDim2.new(1, -10, 0.5, 0), Color3.fromRGB(90, 90, 100), 16, Vector2.new(1, 0.5))
		end
	end
end

function QuestClient.Toggle()
	isOpen = not isOpen
	if isOpen then
		RefreshQuests()
	end
	if panel then
		panel.Visible = isOpen
	end
end

function QuestClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")
	panel = UIHelpers.NewPanel(gui, "QuestPanel", UIHelpers.FitPanelSize(560, 380), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	panel.Visible = false
	UIHelpers.NewLabel(panel, "Title", "DAILY QUESTS", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), 24, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	local closeButton = UIHelpers.NewButton(panel, "Close", "X", UDim2.fromOffset(36, 36), UDim2.new(1, -10, 0, 8), Color3.fromRGB(200, 60, 60), 18, Vector2.new(1, 0))
	closeButton.MouseButton1Click:Connect(function()
		QuestClient.Toggle()
	end)
	UIHelpers.NewLabel(panel, "Note", "Quests reset every session. Finish them for bonus cash!", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 46), 14, UIHelpers.TextDim).TextXAlignment = Enum.TextXAlignment.Center
	-- The list scrolls so the third quest is never cut off on a short viewport.
	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "QuestList"
	listFrame.Size = UDim2.new(1, -16, 1, -80)
	listFrame.Position = UDim2.new(0, 8, 0, 72)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 284)
	listFrame.Parent = panel
	ClientState.Changed.Event:Connect(function()
		if isOpen then
			RefreshQuests()
		end
	end)
end

return QuestClient
