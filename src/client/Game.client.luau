-- Game.client.luau: Brainrot Fishing client bootstrap. Creates the one ScreenGui
-- every module shares, then starts the HUD, fishing, shop, tanks, dex, quests
-- and monster warnings. The client only draws UI and sends input; the server
-- owns all money, fish and state.

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

-- Start every client module. Order: HUD first (it owns the StateSync feed),
-- then fishing input, then the panels, then the alert listeners.
require(script.Parent:WaitForChild("HUDClient")).Init()
require(script.Parent:WaitForChild("FishingClient")).Init()
require(script.Parent:WaitForChild("ShopClient")).Init()
require(script.Parent:WaitForChild("BrainrotpediaClient")).Init()
require(script.Parent:WaitForChild("QuestClient")).Init()
require(script.Parent:WaitForChild("TankClient")).Init()
require(script.Parent:WaitForChild("MonsterWarningClient")).Init()

print("Brainrot Fishing client started: HUD, fishing, shop, dex, quests live.")
