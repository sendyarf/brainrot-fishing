-- HelpClient: the HOW TO PLAY panel. It shows once when the player joins so
-- the game explains itself instead of leaving a new angler guessing, it
-- dismisses with GOT IT, and the "?" button in the HUD reopens it any time.

local Players = game:GetService("Players")

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local HelpClient = {}

local player = Players.LocalPlayer
local gui = nil
local helpPanel = nil

local STEPS = {
	"1.  Walk to the glowing water at Shallow Shore — follow the light beam rising from the water, right in front of you when you spawn.",
	"2.  Press E to cast. When a fish bites, press E (or tap REEL) while the needle is in the GREEN zone. 3 points lands the fish!",
	"3.  Caught fish swim in your tanks and earn $ every second — even while you explore.",
	"4.  Spend $ in the SHOP: better rods, tastier bait, more tank slots, and new fishing spots.",
	"5.  LOCK BASE protects your tanks from thieves and from Naga Nila's wave. REBIRTH at $25,000 for +50% income forever!",
	"6.  Steal from other players: walk up to their tank and hold E for 3 seconds — unless their base is locked or they are guarding it.",
	"7.  Press H (or tap HOLSTER) to put your rod away. Casting picks it back up automatically.",
}

function HelpClient.Show()
	if helpPanel then
		helpPanel.Size = UIHelpers.FitPanelSize(560, 460)
		helpPanel.Visible = true
	end
end

function HelpClient.Hide()
	if helpPanel then
		helpPanel.Visible = false
	end
end

function HelpClient.Toggle()
	if helpPanel then
		if not helpPanel.Visible then
			helpPanel.Size = UIHelpers.FitPanelSize(560, 460)
		end
		helpPanel.Visible = not helpPanel.Visible
	end
end

function HelpClient.Init()
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")

	helpPanel = UIHelpers.NewPanel(gui, "HelpPanel", UIHelpers.FitPanelSize(560, 460), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	UIHelpers.NewLabel(helpPanel, "HelpTitle", "HOW TO PLAY", UDim2.new(1, -32, 0, 32), UDim2.new(0, 16, 0, 12), 26, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	-- The goal, up front: players asked what the game is about beyond fishing.
	local goal = UIHelpers.NewLabel(helpPanel, "GoalLine", "GOAL: grow your $/s income, catch all 12 fish, and become the MASTER ANGLER — while thieves and Naga Nila try to steal your tanks!", UDim2.new(1, -32, 0, 36), UDim2.new(0, 16, 0, 46), 15, UIHelpers.AccentGreen)
	goal.TextWrapped = true
	goal.TextXAlignment = Enum.TextXAlignment.Center
	local stepsFrame = Instance.new("ScrollingFrame")
	stepsFrame.Name = "StepsList"
	stepsFrame.Size = UDim2.new(1, -32, 1, -148)
	stepsFrame.Position = UDim2.new(0, 16, 0, 88)
	stepsFrame.BackgroundTransparency = 1
	stepsFrame.BorderSizePixel = 0
	stepsFrame.ScrollBarThickness = 6
	stepsFrame.CanvasSize = UDim2.new(0, 0, 0, 7 * 56 + 4)
	stepsFrame.Parent = helpPanel
	for i, step in ipairs(STEPS) do
		local label = UIHelpers.NewLabel(stepsFrame, "Step" .. i, step, UDim2.new(1, -8, 0, 52), UDim2.new(0, 0, 0, 4 + (i - 1) * 56), 16, UIHelpers.TextWhite)
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
	local gotIt = UIHelpers.NewButton(helpPanel, "GotItButton", "GOT IT!", UDim2.fromOffset(150, 40), UDim2.new(0.5, 0, 1, -16), Color3.fromRGB(40, 160, 80), 18, Vector2.new(0.5, 1))
	gotIt.MouseButton1Click:Connect(function()
		HelpClient.Hide()
	end)

	-- Show once on join: a new player should never wonder what to do.
	helpPanel.Visible = true
end

return HelpClient
