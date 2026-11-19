-- TankClient — the steal interaction on other players' tanks.
-- Every tank in the world gets a ProximityPrompt: approach a tank that
-- is not yours, hold E for 3 seconds, and the server moves the fish to
-- your tanks (or sells it if you are full). Locked bases show a lock
-- prompt instead and cannot be stolen from. Your own tanks show no
-- prompt at all — you cannot steal from yourself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local TankClient = {}

local player = Players.LocalPlayer
local remotes = nil

function TankClient.Init(remoteFolder)
	remotes = remoteFolder
	-- Watch for tanks appearing in the world (bases are built on join).
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") and string.sub(descendant.Name, 1, 4) == "Tank" then
			task.wait(0.5)
			TankClient.AttachStealPrompt(descendant)
		end
	end)
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and string.sub(descendant.Name, 1, 4) == "Tank" then
			TankClient.AttachStealPrompt(descendant)
		end
	end
end

-- Attaches a hold-to-steal prompt to one tank. The tank's owner is found
-- from its position: each base plot belongs to one player, and the
-- server re-validates ownership, distance and lock at steal time.
function TankClient.AttachStealPrompt(tank)
	if tank:FindFirstChild("StealPrompt") then
		return
	end
	local glass = tank:FindFirstChild("Glass")
	if not glass then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ObjectText = "Fish Tank"
	prompt.ActionText = "Steal Fish"
	prompt.HoldDuration = GameConfig.STEAL_HOLD_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = glass

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		-- The owner is stamped on the tank by the server (OwnerUserId
		-- IntValue). No guessing: the owner is often away fishing.
		local ownerTag = tank:FindFirstChild("OwnerUserId")
		local ownerUserId = ownerTag and ownerTag.Value or 0
		local tankIndex = tonumber(string.sub(tank.Name, 5)) or 1
		if ownerUserId > 0 and ownerUserId ~= player.UserId then
			remotes.StealFish:FireServer(ownerUserId, tankIndex)
		end
	end)
end

return TankClient
