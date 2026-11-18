-- Game.client.luau: Brainrot Fishing client bootstrap. Creates the one ScreenGui
-- every module shares, then starts the HUD, fishing, shop, tanks, dex, quests
-- and monster warnings. The client only draws UI and sends input; the server
-- owns all money, fish and state.
--
-- Every module starts inside a pcall: one module failing must never take the
-- rest of the UI down with it (a silent half-built HUD is worse than an error
-- message). Failures are warned to the Output log AND shown on screen in red,
-- so a playtester can screenshot exactly what broke.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The single ScreenGui for the whole game UI (never resets on respawn).
local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotFishingGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

-- On-screen boot error readout (hidden unless a module fails to start).
local errorLabel = Instance.new("TextLabel")
errorLabel.Name = "BootErrorLabel"
errorLabel.Size = UDim2.fromOffset(640, 90)
errorLabel.Position = UDim2.new(0.5, 0, 0, 122)
errorLabel.AnchorPoint = Vector2.new(0.5, 0)
errorLabel.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
errorLabel.BackgroundTransparency = 0.2
errorLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
errorLabel.TextSize = 14
errorLabel.Font = Enum.Font.GothamBold
errorLabel.TextWrapped = true
errorLabel.TextXAlignment = Enum.TextXAlignment.Left
errorLabel.TextYAlignment = Enum.TextYAlignment.Top
errorLabel.Text = ""
errorLabel.Visible = false
errorLabel.Parent = gui

local function SafeInit(moduleName)
	local ok, err = pcall(function()
		require(script.Parent:WaitForChild(moduleName)).Init()
	end)
	if not ok then
		warn("[BrainrotFishing] " .. moduleName .. " failed to start: " .. tostring(err))
		errorLabel.Text = errorLabel.Text .. moduleName .. " FAILED: " .. tostring(err) .. "\n"
		errorLabel.Visible = true
	end
end

-- Start every client module. Order: HUD first (it owns the StateSync feed),
-- then fishing input, then the panels, then the alert listeners.
SafeInit("HUDClient")
SafeInit("FishingClient")
SafeInit("ShopClient")
SafeInit("BrainrotpediaClient")
SafeInit("QuestClient")
SafeInit("TankClient")
SafeInit("MonsterWarningClient")
SafeInit("HelpClient")

print("Brainrot Fishing client started: HUD, fishing, shop, dex, quests live.")
