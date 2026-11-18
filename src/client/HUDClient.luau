-- HUDClient: the main heads-up display. Cash + income top-center, tanks and
-- rebirth top-right, rarity ladder on the right edge, rod/bait bottom-left,
-- action buttons bottom-right. Nothing sits in the top-left corner (the Roblox
-- menu button lives there). Also owns the catch banner and all feedback toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FishDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishDefinitions"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local HUDClient = {}

local player = Players.LocalPlayer
local gui = nil
local cashLabel = nil
local incomeLabel = nil
local blessingLabel = nil
local tanksLabel = nil
local rebirthBadge = nil
local rodBaitLabel = nil
local ladderRows = {}
local questLines = {}
local lockButton = nil
local rebirthButton = nil
local rebirthConfirmUntil = 0
local catchBanner = nil
local catchBannerLabels = {}

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function FormatTime(seconds)
	local s = math.ceil(seconds or 0)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Refreshes every HUD element from the latest state snapshot.
local function RefreshHUD(state)
	if cashLabel then
		cashLabel.Text = UIHelpers.FormatMoney(state.Cash)
	end
	if incomeLabel then
		incomeLabel.Text = "+" .. UIHelpers.FormatMoney(state.Income) .. "/s"
	end
	if blessingLabel then
		if state.BlessingRemaining > 0 then
			blessingLabel.Text = "Calm Water Blessing +10% luck (" .. math.ceil(state.BlessingRemaining) .. "s)"
			blessingLabel.Visible = true
		elseif state.TangledRemaining > 0 then
			blessingLabel.Text = "Rod tangled! Wait " .. math.ceil(state.TangledRemaining) .. "s"
			blessingLabel.TextColor3 = UIHelpers.AccentRed
			blessingLabel.Visible = true
		else
			blessingLabel.Visible = false
		end
		if state.BlessingRemaining > 0 then
			blessingLabel.TextColor3 = UIHelpers.AccentGold
		end
	end
	if tanksLabel then
		tanksLabel.Text = "Tanks " .. state.TankCount .. "/" .. state.TankSlots
		if state.TankCount >= state.TankSlots then
			tanksLabel.TextColor3 = Color3.fromRGB(255, 170, 60)
		else
			tanksLabel.TextColor3 = UIHelpers.TextWhite
		end
		-- No rebirth yet: center the tanks line in the panel instead of
		-- leaving the bottom half empty.
		if state.Rebirths > 0 then
			tanksLabel.Size = UDim2.new(1, -16, 0.5, 0)
			tanksLabel.Position = UDim2.new(0, 8, 0, 4)
		else
			tanksLabel.Size = UDim2.new(1, -16, 1, 0)
			tanksLabel.Position = UDim2.new(0, 8, 0, 0)
		end
	end
	if rebirthBadge then
		if state.Rebirths > 0 then
			rebirthBadge.Text = "Rebirth x" .. string.format("%.1f", state.RebirthMultiplier)
			rebirthBadge.Visible = true
		else
			rebirthBadge.Visible = false
		end
	end
	if rodBaitLabel then
		local rod = GameConfig.Rods[state.Rod]
		local bait = GameConfig.Baits[state.Bait]
		rodBaitLabel.Text = (rod and rod.Name or state.Rod) .. "  ·  " .. (bait and bait.Name or state.Bait)
	end
	for tier, row in pairs(ladderRows) do
		local count = state.CaughtByTier and state.CaughtByTier[tier] or 0
		row.Text = tier:upper() .. "  " .. count
	end
	for i, line in ipairs(questLines) do
		local quest = state.Quests and state.Quests[i]
		local configQuest = GameConfig.Quests[i]
		if quest and configQuest then
			if quest.Claimed then
				line.Text = "✓ " .. configQuest.Name
				line.TextColor3 = UIHelpers.AccentGreen
			else
				line.Text = configQuest.Name .. "  " .. math.min(quest.Progress, configQuest.Target) .. "/" .. configQuest.Target
				line.TextColor3 = UIHelpers.TextWhite
			end
		end
	end
	if lockButton then
		if state.LockRemaining > 0 then
			lockButton.Text = "LOCKED " .. FormatTime(state.LockRemaining)
			lockButton.BackgroundColor3 = Color3.fromRGB(180, 140, 20)
		elseif state.LockCooldownRemaining > 0 then
			lockButton.Text = "LOCK " .. FormatTime(state.LockCooldownRemaining)
			lockButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		else
			lockButton.Text = "LOCK BASE"
			lockButton.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
		end
	end
	if rebirthButton then
		if state.Rebirths >= GameConfig.RebirthMax then
			rebirthButton.Text = "MAX REBIRTH"
			rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		elseif state.Cash >= GameConfig.RebirthCost then
			if os.clock() < rebirthConfirmUntil then
				rebirthButton.Text = "SURE? TAP AGAIN"
				rebirthButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			else
				rebirthButton.Text = "REBIRTH!"
				rebirthButton.BackgroundColor3 = Color3.fromRGB(200, 60, 200)
			end
		else
			rebirthButton.Text = UIHelpers.FormatMoney(state.Cash) .. " / $25,000"
			rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
end

-- Shows the big catch banner in the middle of the screen.
local function ShowCatchBanner(data)
	local def = FishDefinitions.Fish[data.FishId]
	if not def then
		return
	end
	local rarityColor = FishDefinitions.RarityColors[def.Rarity]
	local title = def.Rarity:upper() .. "!"
	if data.Mutation == "Golden" then
		title = "GOLDEN " .. title
	elseif data.Mutation == "Rainbow" then
		title = "RAINBOW " .. title
	end
	catchBannerLabels.Title.Text = title
	catchBannerLabels.Title.TextColor3 = rarityColor
	catchBannerLabels.Name.Text = def.Name
	if data.SoldFor and data.SoldFor > 0 then
		catchBannerLabels.Sub.Text = "Tank full! Sold for " .. UIHelpers.FormatMoney(data.SoldFor)
	else
		local income = def.Income
		if data.Mutation == "Golden" then
			income = income * GameConfig.MutationMultipliers.Golden
		elseif data.Mutation == "Rainbow" then
			income = income * GameConfig.MutationMultipliers.Rainbow
		end
		catchBannerLabels.Sub.Text = UIHelpers.FormatMoney(income) .. "/s  ·  Added to your tank!"
	end
	catchBanner.Visible = true
	task.delay(3.5, function()
		catchBanner.Visible = false
	end)
end

function HUDClient.Init()
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")

	-- Cash panel, top-center (never top-left: the Roblox menu lives there).
	local cashPanel = UIHelpers.NewPanel(gui, "CashPanel", UDim2.fromOffset(300, 74), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	cashLabel = UIHelpers.NewLabel(cashPanel, "Cash", "$0", UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0, 4), 32, UIHelpers.TextWhite)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Center
	incomeLabel = UIHelpers.NewLabel(cashPanel, "Income", "+$0/s", UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.6, 0), 20, UIHelpers.AccentGreen)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Center
	blessingLabel = UIHelpers.NewLabel(gui, "Blessing", "", UDim2.fromOffset(420, 26), UDim2.new(0.5, 0, 0, 90), 16, UIHelpers.AccentGold, Vector2.new(0.5, 0))
	blessingLabel.TextXAlignment = Enum.TextXAlignment.Center
	blessingLabel.Visible = false

	-- Tanks + rebirth, top-right.
	local infoPanel = UIHelpers.NewPanel(gui, "InfoPanel", UDim2.fromOffset(190, 74), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
	tanksLabel = UIHelpers.NewLabel(infoPanel, "Tanks", "Tanks 0/3", UDim2.new(1, -16, 0.5, 0), UDim2.new(0, 8, 0, 4), 20, UIHelpers.TextWhite)
	rebirthBadge = UIHelpers.NewLabel(infoPanel, "Rebirth", "Rebirth x1.5", UDim2.new(1, -16, 0.4, 0), UDim2.new(0, 8, 0.5, 0), 18, UIHelpers.AccentGold)
	rebirthBadge.Visible = false

	-- Daily reward button under the info panel.
	local dailyButton = UIHelpers.NewButton(gui, "DailyButton", "DAILY REWARD", UDim2.fromOffset(190, 40), UDim2.new(1, -10, 0, 92), Color3.fromRGB(200, 140, 20), 16, Vector2.new(1, 0))
	dailyButton.MouseButton1Click:Connect(function()
		GetRemote("ClaimDaily"):FireServer()
	end)

	-- Rarity ladder, right edge. Same 190px width as the panels above it,
	-- with an even 8px gap from the daily button.
	local ladderPanel = UIHelpers.NewPanel(gui, "RarityLadder", UDim2.fromOffset(190, 148), UDim2.new(1, -10, 0, 140), Vector2.new(1, 0))
	UIHelpers.NewLabel(ladderPanel, "LadderTitle", "CAUGHT", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 6), 16, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	for i, tier in ipairs(FishDefinitions.RarityOrder) do
		local row = UIHelpers.NewLabel(ladderPanel, "Row" .. tier, tier:upper() .. "  0", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 30 + (i - 1) * 23), 15, FishDefinitions.RarityColors[tier])
		ladderRows[tier] = row
	end

	-- Rod + bait, bottom-left. Fixed size (the layout that provably renders);
	-- the action buttons on the right shrink on narrow screens instead, so
	-- the row never collides with this chip.
	local gearPanel = UIHelpers.NewPanel(gui, "GearPanel", UDim2.fromOffset(300, 40), UDim2.new(0, 10, 1, -10), Vector2.new(0, 1))
	rodBaitLabel = UIHelpers.NewLabel(gearPanel, "Gear", "Bamboo Rod  ·  Bread", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 17, UIHelpers.TextWhite)

	-- Quest mini-panel above the gear panel.
	local questPanel = UIHelpers.NewPanel(gui, "QuestMiniPanel", UDim2.fromOffset(300, 96), UDim2.new(0, 10, 1, -58), Vector2.new(0, 1))
	UIHelpers.NewLabel(questPanel, "QuestTitle", "DAILY QUESTS", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 4), 15, UIHelpers.AccentGold)
	for i = 1, 3 do
		local line = UIHelpers.NewLabel(questPanel, "Quest" .. i, "", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 26 + (i - 1) * 22), 15, UIHelpers.TextWhite)
		questLines[i] = line
	end
	-- Placeholder until the first state sync arrives (never an empty panel).
	questLines[1].Text = "Loading quests..."
	questLines[1].TextColor3 = UIHelpers.TextDim
	local questOpenButton = Instance.new("TextButton")
	questOpenButton.Name = "OpenQuests"
	questOpenButton.Size = UDim2.fromScale(1, 1)
	questOpenButton.BackgroundTransparency = 1
	questOpenButton.Text = ""
	questOpenButton.Parent = questPanel
	questOpenButton.MouseButton1Click:Connect(function()
		require(script.Parent:WaitForChild("QuestClient")).Toggle()
	end)

	-- Action buttons, bottom-right. Their width adapts to the viewport so
	-- the row never reaches the gear chip: full 116px on wide screens,
	-- shrinking to 84px at 768px wide (row starts at x = 314, the gear
	-- chip ends at x = 310).
	local camera = game:GetService("Workspace").CurrentCamera
	local viewportWidth = camera and camera.ViewportSize.X or 1280
	local buttonWidth = math.clamp(math.floor((viewportWidth - 360) / 5) - 6, 84, 116)
	local buttonGap = 6
	local buttonFont = buttonWidth >= 100 and 15 or 13
	local buttonSize = UDim2.fromOffset(buttonWidth, 44)
	local function placeButton(index, total)
		local xOffset = -10 - (total - index) * (buttonWidth + buttonGap)
		return UDim2.new(1, xOffset, 1, -10)
	end
	local shopButton = UIHelpers.NewButton(gui, "ShopButton", "SHOP", buttonSize, placeButton(1, 5), Color3.fromRGB(50, 90, 200), buttonFont, Vector2.new(1, 1))
	shopButton.MouseButton1Click:Connect(function()
		require(script.Parent:WaitForChild("ShopClient")).Toggle()
	end)
	local dexButton = UIHelpers.NewButton(gui, "DexButton", "DEX", buttonSize, placeButton(2, 5), Color3.fromRGB(140, 60, 200), buttonFont, Vector2.new(1, 1))
	dexButton.MouseButton1Click:Connect(function()
		require(script.Parent:WaitForChild("BrainrotpediaClient")).Toggle()
	end)
	local questsButton = UIHelpers.NewButton(gui, "QuestsButton", "QUESTS", buttonSize, placeButton(3, 5), Color3.fromRGB(200, 140, 20), buttonFont, Vector2.new(1, 1))
	questsButton.MouseButton1Click:Connect(function()
		require(script.Parent:WaitForChild("QuestClient")).Toggle()
	end)
	lockButton = UIHelpers.NewButton(gui, "LockButton", "LOCK BASE", buttonSize, placeButton(4, 5), Color3.fromRGB(40, 160, 80), buttonFont, Vector2.new(1, 1))
	lockButton.MouseButton1Click:Connect(function()
		GetRemote("LockBase"):FireServer()
	end)
	rebirthButton = UIHelpers.NewButton(gui, "RebirthButton", "$0 / $25,000", buttonSize, placeButton(5, 5), Color3.fromRGB(90, 90, 100), buttonWidth >= 100 and 12 or 11, Vector2.new(1, 1))
	rebirthButton.MouseButton1Click:Connect(function()
		local state = ClientState.Get()
		if state.Cash < GameConfig.RebirthCost or state.Rebirths >= GameConfig.RebirthMax then
			return
		end
		if os.clock() < rebirthConfirmUntil then
			rebirthConfirmUntil = 0
			GetRemote("DoRebirth"):FireServer()
		else
			rebirthConfirmUntil = os.clock() + 3
			UIHelpers.ShowToast("Tap REBIRTH again to confirm! Cash resets to $0.", UIHelpers.AccentGold, 3)
			RefreshHUD(state)
		end
	end)

	-- Help button under the rarity ladder: reopens the HOW TO PLAY panel.
	local helpButton = UIHelpers.NewButton(gui, "HelpButton", "?", UDim2.fromOffset(44, 44), UDim2.new(1, -10, 0, 296), Color3.fromRGB(200, 140, 20), 22, Vector2.new(1, 0))
	helpButton.MouseButton1Click:Connect(function()
		require(script.Parent:WaitForChild("HelpClient")).Toggle()
	end)

	-- Catch banner, center screen.
	catchBanner = UIHelpers.NewPanel(gui, "CatchBanner", UDim2.fromOffset(460, 150), UDim2.new(0.5, 0, 0.32, 0), Vector2.new(0.5, 0))
	catchBanner.Visible = false
	catchBannerLabels.Title = UIHelpers.NewLabel(catchBanner, "Title", "COMMON!", UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0, 8), 34, UIHelpers.TextWhite)
	catchBannerLabels.Title.TextXAlignment = Enum.TextXAlignment.Center
	catchBannerLabels.Name = UIHelpers.NewLabel(catchBanner, "Name", "Lele Lirico", UDim2.new(1, 0, 0.32, 0), UDim2.new(0, 0, 0.4, 0), 26, UIHelpers.TextWhite)
	catchBannerLabels.Name.TextXAlignment = Enum.TextXAlignment.Center
	catchBannerLabels.Sub = UIHelpers.NewLabel(catchBanner, "Sub", "$5/s", UDim2.new(1, 0, 0.26, 0), UDim2.new(0, 0, 0.7, 0), 20, UIHelpers.AccentGreen)
	catchBannerLabels.Sub.TextXAlignment = Enum.TextXAlignment.Center

	-- State sync drives the whole HUD.
	GetRemote("StateSync").OnClientEvent:Connect(function(snapshot)
		ClientState.Update(snapshot)
		RefreshHUD(ClientState.Get())
	end)
	ClientState.Changed.Event:Connect(function(state)
		RefreshHUD(state)
	end)

	-- Feedback events -> toasts and banners.
	GetRemote("CatchBanner").OnClientEvent:Connect(ShowCatchBanner)
	GetRemote("ShopResult").OnClientEvent:Connect(function(result)
		UIHelpers.ShowToast(result.Message, result.Success and UIHelpers.AccentGreen or UIHelpers.AccentRed, 3)
	end)
	GetRemote("QuestResult").OnClientEvent:Connect(function(result)
		UIHelpers.ShowToast(result.Message, result.Success and UIHelpers.AccentGreen or UIHelpers.AccentRed, 3)
	end)
	GetRemote("RebirthResult").OnClientEvent:Connect(function(result)
		if result.Success then
			UIHelpers.ShowToast("REBIRTH! Income multiplier now x" .. string.format("%.1f", result.Multiplier) .. " — Royal Pond unlocked!", UIHelpers.AccentGold, 5)
		else
			UIHelpers.ShowToast(result.Message, UIHelpers.AccentRed, 3)
		end
	end)
	GetRemote("DailyRewardResult").OnClientEvent:Connect(function(result)
		if result.Success then
			UIHelpers.ShowToast("Daily reward: +" .. UIHelpers.FormatMoney(result.Reward) .. " (day " .. result.Streak .. " streak!)", UIHelpers.AccentGold, 4)
		else
			UIHelpers.ShowToast(result.Message, UIHelpers.AccentRed, 3)
		end
	end)
	GetRemote("OfflineEarnings").OnClientEvent:Connect(function(amount)
		UIHelpers.ShowToast("Welcome back! Your tanks earned " .. UIHelpers.FormatMoney(amount) .. " while you were away.", UIHelpers.AccentGreen, 5)
	end)
	GetRemote("CollectionComplete").OnClientEvent:Connect(function(bonus)
		UIHelpers.ShowToast("BRAINROTPEDIA COMPLETE! +" .. UIHelpers.FormatMoney(bonus) .. " — you are now a MASTER ANGLER!", UIHelpers.AccentGold, 6)
	end)

	RefreshHUD(ClientState.Get())
end

return HUDClient
