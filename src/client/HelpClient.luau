-- HelpClient — the how-to-play panel: the loop in six lines, the steal
-- rules, the monster rules and the rebirth goal. New players open it
-- from the HELP button; it also shows once automatically on first join
-- so nobody is lost in the first minute.

local Players = game:GetService("Players")
local UIHelpers = require(script.Parent.UIHelpers)

local HelpClient = {}

local player = Players.LocalPlayer
local helpFrame = nil
local helpOpen = false
local shownOnce = false

local HELP_LINES = {
	"1. Press E near the water to cast your rod.",
	"2. When the bobber sinks, stop the needle in the GREEN zone.",
	"3. Land 3 reel points to catch a fish — it swims into your tank.",
	"4. Fish earn $/s. Spend it in the SHOP on rods, bait and tanks.",
	"5. Hold E on another player's tank to steal their fish — unless their base is LOCKED.",
	"6. When NAGA NILA stirs, finish your reel fast and guard your tanks.",
	"7. At $25,000 cash, REBIRTH for +50% income and the Royal Pond.",
}

function HelpClient.Init()
	-- Show once on first join, after a short delay so the world loads.
	task.delay(3, function()
		if not shownOnce then
			shownOnce = true
			HelpClient.ToggleHelp()
		end
	end)
end

local function buildHelp()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("HelpUI")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HelpUI"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = playerGui
	end
	if helpFrame then
		helpFrame:Destroy()
	end
	helpFrame = UIHelpers.MakeFrame(gui, UDim2.new(0, 520, 0, 380), UDim2.new(0.5, -260, 0.5, -190))
	UIHelpers.MakeLabel(helpFrame, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), "HOW TO PLAY", 28, UIHelpers.ACCENT)
	local closeButton = UIHelpers.MakeButton(helpFrame, UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8), "X", 20)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.MouseButton1Click:Connect(function()
		HelpClient.ToggleHelp()
	end)
	for i, line in ipairs(HELP_LINES) do
		local label = UIHelpers.MakeLabel(helpFrame, UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, 56 + (i - 1) * 42),
			line, 16, UIHelpers.TEXT)
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function HelpClient.ToggleHelp()
	helpOpen = not helpOpen
	if helpOpen then
		buildHelp()
	elseif helpFrame then
		helpFrame:Destroy()
		helpFrame = nil
	end
end

return HelpClient
