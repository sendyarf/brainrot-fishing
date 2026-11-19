-- Game.client.luau — client entry point for Brainrot Fishing.
-- Rojo turns this file's folder into a LocalScript named "Client", so
-- every ModuleScript beside it is a CHILD of this script: require them
-- with script:WaitForChild. This script waits for the server's
-- RemoteEvents, starts every UI module, wires the HUD buttons and
-- handles notifications (toasts) and steal alerts from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- All client modules are children of this LocalScript.
local ClientState = require(script:WaitForChild("ClientState"))
local HUDClient = require(script:WaitForChild("HUDClient"))
local FishingClient = require(script:WaitForChild("FishingClient"))
local ShopClient = require(script:WaitForChild("ShopClient"))
local TankClient = require(script:WaitForChild("TankClient"))
local BrainrotpediaClient = require(script:WaitForChild("BrainrotpediaClient"))
local QuestClient = require(script:WaitForChild("QuestClient"))
local MonsterWarningClient = require(script:WaitForChild("MonsterWarningClient"))
local HelpClient = require(script:WaitForChild("HelpClient"))
local UIHelpers = require(script:WaitForChild("UIHelpers"))

-- Wait for the server to create the RemoteEvents folder.
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

-- State sync from the server feeds every UI module.
remotes.StateSync.OnClientEvent:Connect(function(newState)
	ClientState.Update(newState)
end)

-- Toast notifications (purchases, sales, warnings) bottom-centre.
local playerGui = player:WaitForChild("PlayerGui")
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "ToastUI"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.Parent = playerGui
local toastLabel = UIHelpers.MakeLabel(toastGui, UDim2.new(0, 480, 0, 44), UDim2.new(0.5, -240, 1, -230), "", 18)
toastLabel.BackgroundTransparency = 0.25
toastLabel.BackgroundColor3 = UIHelpers.PANEL
toastLabel.Visible = false

local toastToken = 0
local function showToast(message)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(4, function()
		if token == toastToken then
			toastLabel.Visible = false
		end
	end)
end

remotes.Notify.OnClientEvent:Connect(function(message)
	showToast(message)
end)

remotes.StealAlert.OnClientEvent:Connect(function(thiefName, fishName)
	showToast("Someone is stealing your " .. fishName .. "! (" .. thiefName .. ")")
end)

-- Start every UI module.
HUDClient.Init()
FishingClient.Init(remotes)
ShopClient.Init(remotes)
TankClient.Init(remotes)
BrainrotpediaClient.Init()
QuestClient.Init(remotes)
MonsterWarningClient.Init(remotes)
HelpClient.Init()

-- HUD buttons open the panels; LOCK and REBIRTH fire straight to the server.
HUDClient.SetCallbacks({
	shop = function()
		ShopClient.ToggleShop()
	end,
	dex = function()
		BrainrotpediaClient.ToggleDex()
	end,
	quests = function()
		QuestClient.ToggleQuests()
	end,
	lock = function()
		remotes.LockBase:FireServer()
	end,
	rebirth = function()
		remotes.DoRebirth:FireServer()
	end,
	help = function()
		HelpClient.ToggleHelp()
	end,
})

print("[Brainrot Fishing] Client ready. Welcome to the lake!")
