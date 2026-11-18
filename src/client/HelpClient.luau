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
	"1.  Walk to the glowing water at Shallow Shore — it's right in front of you when you spawn.",
	"2.  Press E to cast. When a fish bites, press E (or tap REEL) while the needle is in the GREEN zone. 3 points lands the fish!",
	"3.  Caught fish swim in your tanks and earn $ every second — even while you explore.",
	"4.  Spend $ in the SHOP: better rods, tastier bait, more tank slots, and new fishing spots.",
	"5.  Tap LOCK BASE to protect your tanks from thieves. REBIRTH at $25,000 for +50% income forever!",
}

function HelpClient.Show()
	if helpPanel then
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
		helpPanel.Visible = not helpPanel.Visible
	end
end

function HelpClient.Init()
	gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")

	helpPanel = UIHelpers.NewPanel(gui, "HelpPanel", UDim2.fromOffset(560, 440), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
	UIHelpers.NewLabel(helpPanel, "HelpTitle", "HOW TO PLAY", UDim2.new(1, -32, 0, 32), UDim2.new(0, 16, 0, 12), 26, UIHelpers.AccentGold).TextXAlignment = Enum.TextXAlignment.Center
	for i, step in ipairs(STEPS) do
		local label = UIHelpers.NewLabel(helpPanel, "Step" .. i, step, UDim2.new(1, -32, 0, 58), UDim2.new(0, 16, 0, 52 + (i - 1) * 62), 16, UIHelpers.TextWhite)
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
