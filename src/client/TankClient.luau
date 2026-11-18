-- TankClient: steal feedback. The victim gets a big red banner the moment a
-- thief starts a channel ("Someone is stealing your Sidat Sultan!"), the thief
-- gets progress toasts, and both sides hear the outcome. Lock confirmations
-- also land here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local TankClient = {}

local player = Players.LocalPlayer
local alertBanner = nil
local alertLabel = nil

local function GetRemote(name)
	return ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild(name)
end

local function ShowStealAlert(fishName, thiefName)
	alertLabel.Text = thiefName .. " is stealing your " .. fishName .. "! Get back to your base!"
	alertBanner.Visible = true
	task.delay(4, function()
		alertBanner.Visible = false
	end)
end

function TankClient.Init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotFishingGui")
	alertBanner = UIHelpers.NewPanel(gui, "StealAlert", UDim2.fromOffset(560, 56), UDim2.new(0.5, 0, 0, 130), Vector2.new(0.5, 0))
	alertBanner.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	alertBanner.Visible = false
	alertLabel = UIHelpers.NewLabel(alertBanner, "AlertText", "", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), 18, UIHelpers.TextWhite)
	alertLabel.TextXAlignment = Enum.TextXAlignment.Center

	GetRemote("StealUpdate").OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "alert" then
			ShowStealAlert(data.FishName, data.ThiefName)
		elseif kind == "started" then
			UIHelpers.ShowToast("Stealing " .. data.FishName .. "... hold still for 3s!", UIHelpers.AccentGold, 3)
		elseif kind == "stolen" then
			if data.SoldFor and data.SoldFor > 0 then
				UIHelpers.ShowToast("You stole " .. data.FishName .. "! Tanks full — sold for " .. UIHelpers.FormatMoney(data.SoldFor), UIHelpers.AccentGreen, 4)
			else
				UIHelpers.ShowToast("You stole " .. data.FishName .. "! It's in your tank now.", UIHelpers.AccentGreen, 4)
			end
		elseif kind == "victim" then
			UIHelpers.ShowToast(data.ThiefName .. " stole your " .. data.FishName .. "! Lock your base next time.", UIHelpers.AccentRed, 5)
		elseif kind == "blocked" then
			UIHelpers.ShowToast(data.Reason or "Can't steal that.", UIHelpers.AccentRed, 3)
		elseif kind == "cancelled" then
			UIHelpers.ShowToast(data.Reason or "Steal cancelled.", UIHelpers.TextDim, 3)
		elseif kind == "locked" then
			UIHelpers.ShowToast("Base locked for 5 minutes! Your tanks are safe.", UIHelpers.AccentGreen, 4)
		elseif kind == "lockinfo" then
			UIHelpers.ShowToast(data.Message or "", UIHelpers.AccentGold, 3)
		end
	end)
end

return TankClient
