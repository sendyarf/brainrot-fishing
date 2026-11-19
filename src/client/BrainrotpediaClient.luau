-- BrainrotpediaClient — the collection panel: a grid of all 12 fish.
-- Caught fish show in colour with their best $/s; uncaught fish are
-- silhouettes with "???". Completing the dex (12/12) pays a $2,000 bonus
-- and the "Master Angler" title above the player's head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientState = require(script.Parent.ClientState)
local UIHelpers = require(script.Parent.UIHelpers)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local FishDefinitions = require(ReplicatedStorage.Shared.FishDefinitions)

local BrainrotpediaClient = {}

local player = Players.LocalPlayer
local dexFrame = nil
local dexOpen = false

function BrainrotpediaClient.Init()
	-- No remotes needed: the dex reads the collection from ClientState.
end

local function buildDex()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("DexUI")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "DexUI"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui
	end
	if dexFrame then
		dexFrame:Destroy()
	end
	dexFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 560, 0, 480), UDim2.new(0.5, -280, 0.5, -240))
	UIHelpers.MakeLabel(dexFrame, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), "BRAINROTPEDIA", 28, UIHelpers.ACCENT)
	local closeButton = UIHelpers.MakeButton(dexFrame, UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8), "X", 20)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.MouseButton1Click:Connect(function()
		BrainrotpediaClient.ToggleDex()
	end)

	local state = ClientState.Get()
	local caught = 0
	for _ in pairs(state.collection) do
		caught += 1
	end
	local total = FishDefinitions.GetFishCount()
	local progress = UIHelpers.MakeLabel(dexFrame, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 52),
		caught .. " / " .. total .. " caught", 18, UIHelpers.MUTED)
	if caught >= total then
		progress.Text = "COMPLETE! Master Angler (+$" .. GameConfig.COMPLETE_DEX_BONUS_CASH .. ")"
		progress.TextColor3 = UIHelpers.GREEN
	end

	-- 3 columns x 4 rows of fish cards.
	local cardWidth = 170
	local cardHeight = 90
	for i, fish in ipairs(FishDefinitions.FISH) do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local card = UIHelpers.MakeFrame(dexFrame,
			UDim2.new(0, cardWidth, 0, cardHeight),
			UDim2.new(0, 12 + col * (cardWidth + 8), 0, 88 + row * (cardHeight + 8)),
			Color3.fromRGB(35, 42, 60), 0.1)
		local best = state.collection[fish.id]
		if best then
			UIHelpers.MakeLabel(card, UDim2.new(1, -8, 0, 24), UDim2.new(0, 4, 0, 4), fish.name, 16)
			local rarityLabel = UIHelpers.MakeLabel(card, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 28),
				fish.rarity, 14, FishDefinitions.GetRarityColor(fish.rarity))
			rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
			UIHelpers.MakeLabel(card, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 48),
				"Best $" .. best .. "/s", 14, UIHelpers.GREEN)
			local blurb = UIHelpers.MakeLabel(card, UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 68), fish.blurb, 11, UIHelpers.MUTED)
			blurb.TextXAlignment = Enum.TextXAlignment.Left
		else
			UIHelpers.MakeLabel(card, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 10), "???", 24, UIHelpers.MUTED)
			UIHelpers.MakeLabel(card, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 44), fish.rarity, 14, UIHelpers.MUTED)
			UIHelpers.MakeLabel(card, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 64), "Not caught yet", 12, UIHelpers.MUTED)
		end
	end
end

function BrainrotpediaClient.ToggleDex()
	dexOpen = not dexOpen
	if dexOpen then
		buildDex()
	elseif dexFrame then
		dexFrame:Destroy()
		dexFrame = nil
	end
end

return BrainrotpediaClient
