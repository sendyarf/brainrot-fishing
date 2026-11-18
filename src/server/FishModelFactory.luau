-- FishModelFactory (server shim): the real factory lives in Shared so the
-- client (Brainrotpedia ViewportFrames) and the server (tanks) build the
-- SAME voxel model from the same code. This file only re-exports it, so
-- TankService's existing require keeps working unchanged.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FishModelFactory"))
