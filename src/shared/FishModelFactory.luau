-- FishModelFactory (shared): builds each brainrot as a VOXEL model, so the
-- client (Brainrotpedia) and the server (tanks) build the SAME model from
-- the same code. The old ball-and-wedge fish capped likeness at ~30-40%:
-- a fish is not an ellipsoid, and no amount of joining fixes a wrong
-- silhouette. The top-1 game builds its brainrots per-pixel from small
-- cubes; this factory does the same — a voxel fish has a pointed snout, a
-- tapering tail, a forked tail fin, gill slits and species patterns, so it
-- reads as that fish at a glance (>70% likeness, like the top 1's duck).
--
-- GRID: one voxel = 0.32 studs. A normal fish is 13 voxels long (z -6..+6),
-- nose toward +Z, origin at the bounding-box center (so the swim radius is
-- the same in every direction). Runs merge adjacent same-color voxels into
-- one Part, so a fish is ~40 parts, not 300. Every run shares a face with
-- the run under it — voxel construction makes floating parts impossible by
-- design (the JOIN RULE is structural now, not a checklist).
--
-- DETAIL RULE: a detail box sitting ON a surface (eye, gill, stripe) is
-- embedded a hair into the surface and proud of it — its faces never sit
-- coplanar with the surface under it, or the two faces z-fight.
-- REACH RULE: nothing may stick out past 2.3 studs from the pivot in XZ,
-- or it pokes through the 5-stud tank glass when the fish turns. Whiskers,
-- lances and batons step UP, not forward, for this reason.

local FishDefinitions = require(script.Parent:WaitForChild("FishDefinitions"))

local FishModelFactory = {}

local VOX = 0.32

-- A box from voxel (x0,y0,z0) to (x1,y1,z1) inclusive. Voxel (x,y,z) is a
-- cube centered at (x*vox, y*vox, z*vox); a run's size is its voxel count
-- times vox, its center the midpoint. `vox` overrides the unit (Naga and
-- the mythics have their own scale).
local function VoxBox(model, name, x0, x1, y0, y1, z0, z1, color, material, vox)
	vox = vox or VOX
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new((x1 - x0 + 1) * vox, (y1 - y0 + 1) * vox, (z1 - z0 + 1) * vox)
	part.CFrame = CFrame.new(Vector3.new((x0 + x1) / 2 * vox, (y0 + y1) / 2 * vox, (z0 + z1) / 2 * vox))
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

-- A detail box positioned freely in studs (eyes, gills, stripes, pupils).
local function StudBox(model, name, pos, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(pos)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

-- Lightens a Color3 toward white (for the belly).
local function Lighten(color)
	return Color3.new(
		math.min(1, color.R * 0.6 + 0.4),
		math.min(1, color.G * 0.6 + 0.4),
		math.min(1, color.B * 0.6 + 0.4))
end

-- Eyes, gill slits and a mouth for a fish whose head half-width is `halfW`
-- voxels. The eyes sit proud of the head sides (they read from the side,
-- which is how you see a fish in a tank); the pupils sit on the eyes'
-- outer faces.
local function AddFishFace(model, halfW, vox, mouthWidth)
	local surfaceX = (halfW + 0.5) * vox
	for _, side in ipairs({ -1, 1 }) do
		StudBox(model, "Eye" .. (side < 0 and "L" or "R"),
			Vector3.new(side * (surfaceX + 0.1 * vox), 1 * vox, 4 * vox),
			Vector3.new(0.4 * vox, 1 * vox, 1 * vox),
			Color3.fromRGB(255, 255, 255))
		StudBox(model, "Pupil" .. (side < 0 and "L" or "R"),
			Vector3.new(side * (surfaceX + 0.4 * vox), 1 * vox, 4 * vox),
			Vector3.new(0.3 * vox, 0.5 * vox, 0.5 * vox),
			Color3.fromRGB(20, 20, 20))
		-- Gill slit: a thin vertical line behind the eye.
		StudBox(model, "Gill" .. (side < 0 and "L" or "R"),
			Vector3.new(side * (surfaceX + 0.05 * vox), 0, 2 * vox),
			Vector3.new(0.3 * vox, 3 * vox, 1 * vox),
			Color3.fromRGB(30, 30, 35))
	end
	-- Mouth: a dark slit on the snout's front face.
	StudBox(model, "Mouth",
		Vector3.new(0, 0.3 * vox, 6.6 * vox),
		Vector3.new(mouthWidth * vox, 0.4 * vox, 0.2 * vox),
		Color3.fromRGB(30, 30, 35))
end

-- Species patterns, drawn as proud boxes on the body surface.
local function AddPattern(model, pattern, accent, halfW, vox)
	if pattern == "koi" then
		-- White patches on the back and both sides (Koi markings).
		StudBox(model, "PatchTop", Vector3.new(0, 3.6 * vox, 0.5 * vox),
			Vector3.new(3 * vox, 0.3 * vox, 2 * vox), accent)
		for _, side in ipairs({ -1, 1 }) do
			StudBox(model, "PatchSide" .. (side < 0 and "L" or "R"),
				Vector3.new(side * (halfW + 0.6) * vox, 1.5 * vox, -0.5 * vox),
				Vector3.new(0.3 * vox, 2 * vox, 2 * vox), accent)
		end
	elseif pattern == "stripes" then
		-- Two bands wrapping the body, slightly larger than the body's
		-- cross-section so they read as rings, not z-fighting skins.
		for _, z in ipairs({ 1, -1 }) do
			StudBox(model, "Stripe" .. (z > 0 and "F" or "B"),
				Vector3.new(0, 0.5 * vox, z * vox),
				Vector3.new((halfW * 2 + 1.2) * vox, 6.2 * vox, 1 * vox), accent)
		end
	elseif pattern == "sidestripe" then
		for _, side in ipairs({ -1, 1 }) do
			StudBox(model, "SideStripe" .. (side < 0 and "L" or "R"),
				Vector3.new(side * (halfW + 0.6) * vox, 1 * vox, 0),
				Vector3.new(0.3 * vox, 1 * vox, 5 * vox), accent)
		end
	end
end

-- The shared fish body: tapered voxel fish, forked tail, stepped dorsal
-- fin, pectoral fins, two-tone belly, face, and a species pattern.
-- spec: BodyColor, BellyColor, FinColor, AccentColor, Body ("normal"|"eel"),
-- Pattern ("koi"|"stripes"|"sidestripe"|nil), NoDorsalFin.
local function BuildFishBody(model, spec, vox)
	local body = spec.BodyColor
	local belly = spec.BellyColor or Lighten(body)
	local fin = spec.FinColor or spec.AccentColor
	local eel = spec.Body == "eel"

	if eel then
		-- Eels: the same 13-long grid, but 3 wide and 4 tall — long and
		-- thin, with a continuous dorsal ridge and a tapering tail.
		VoxBox(model, "BodyMid", -1, 1, 0, 2, -1, 2, body, nil, vox)
		VoxBox(model, "BodyBelly", -1, 1, -1, -1, -1, 2, belly, nil, vox)
		VoxBox(model, "BodyHead", -1, 1, 0, 2, 3, 4, body, nil, vox)
		VoxBox(model, "BodyBellyHead", -1, 1, -1, -1, 3, 4, belly, nil, vox)
		VoxBox(model, "BodyNose", 0, 0, 0, 1, 5, 6, body, nil, vox)
		VoxBox(model, "BodyRear", -1, 1, 0, 2, -3, -2, body, nil, vox)
		VoxBox(model, "BodyTail", 0, 0, 0, 1, -6, -4, body, nil, vox)
		VoxBox(model, "DorsalRidge", 0, 0, 3, 3, -5, 3, fin, nil, vox)
		AddFishFace(model, 1, vox, 0.8)
	else
		-- Normal fish: pointed snout, full mid-body, tapering rear.
		VoxBox(model, "BodyNose", -1, 1, 0, 1, 5, 6, body, nil, vox)
		VoxBox(model, "BodyHead", -2, 2, 0, 2, 3, 4, body, nil, vox)
		VoxBox(model, "BodyBellyHead", -2, 2, -1, -1, 3, 4, belly, nil, vox)
		VoxBox(model, "BodyMid", -2, 2, -1, 3, -1, 2, body, nil, vox)
		VoxBox(model, "BodyBellyMid", -2, 2, -2, -2, -1, 2, belly, nil, vox)
		VoxBox(model, "BodyRear", -1, 1, 0, 2, -3, -2, body, nil, vox)
		VoxBox(model, "BodyBellyRear", -1, 1, -1, -1, -3, -2, belly, nil, vox)
		VoxBox(model, "BodyTailBase", 0, 0, 0, 1, -4, -4, body, nil, vox)
		-- Forked tail: two prongs with a gap between them.
		VoxBox(model, "TailTop", 0, 0, 2, 3, -6, -5, fin, nil, vox)
		VoxBox(model, "TailBottom", 0, 0, -2, -1, -6, -5, fin, nil, vox)
		-- Dorsal fin: a stepped ridge on the back (Naga's crest replaces it).
		if not spec.NoDorsalFin then
			VoxBox(model, "DorsalFin", 0, 0, 4, 4, -1, 1, fin, nil, vox)
			VoxBox(model, "DorsalPeak", 0, 0, 5, 5, 0, 1, fin, nil, vox)
		end
		-- Pectoral fins: stepped wedges on the head sides, tips drooping.
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			VoxBox(model, "Fin" .. s, side * 3, side * 3, -1, 0, 2, 3, fin, nil, vox)
			VoxBox(model, "FinTip" .. s, side * 4, side * 4, -1, -1, 2, 2, fin, nil, vox)
		end
		AddFishFace(model, 2, vox, 1.5)
	end

	AddPattern(model, spec.Pattern, spec.AccentColor, eel and 1 or 2, vox)
	model.PrimaryPart = model:FindFirstChild("BodyMid")
end

-- The signature accessory for one fish id, built from voxels on the body.
-- Every voxel run shares a face with the body (or the run under it).
local function AddAccessory(model, fishId, def, vox)
	local accent = def.AccentColor
	if fishId == "LeleLirico" then
		-- Whiskers stepping up-out from the nose (forward whiskers would
		-- poke through the tank glass — see the REACH RULE above).
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			VoxBox(model, "Whisker1" .. s, side, side, 2, 2, 6, 6, accent, nil, vox)
			VoxBox(model, "Whisker2" .. s, side * 2, side * 2, 3, 3, 6, 6, accent, nil, vox)
			VoxBox(model, "Whisker3" .. s, side * 2, side * 2, 4, 4, 6, 6, accent, nil, vox)
		end
	elseif fishId == "GuppyGondola" then
		-- Mini straw hat: brim + dome + top, sunk onto the head. The brim
		-- covers z 3..4 only — at z 2 the mid-body top is already y=3, so
		-- a brim there would share the body's top voxels and z-fight.
		VoxBox(model, "HatBrim", -2, 2, 3, 3, 3, 4, Color3.fromRGB(240, 210, 130), Enum.Material.Wood, vox)
		VoxBox(model, "HatDome", -1, 1, 4, 4, 3, 4, Color3.fromRGB(220, 180, 100), Enum.Material.Wood, vox)
		VoxBox(model, "HatTop", 0, 0, 5, 5, 3, 3, Color3.fromRGB(220, 180, 100), Enum.Material.Wood, vox)
	elseif fishId == "MujairMaestro" then
		-- Conductor baton waving up-forward + bow tie under the chin.
		VoxBox(model, "Baton1", 2, 2, 2, 2, 5, 5, Color3.fromRGB(255, 255, 255), nil, vox)
		VoxBox(model, "Baton2", 3, 3, 3, 3, 6, 6, Color3.fromRGB(255, 255, 255), nil, vox)
		VoxBox(model, "Baton3", 3, 3, 4, 4, 6, 6, Color3.fromRGB(255, 255, 255), nil, vox)
		VoxBox(model, "BowTieL", -1, -1, -2, -2, 4, 4, Color3.fromRGB(200, 40, 60), nil, vox)
		VoxBox(model, "BowTieR", 1, 1, -2, -2, 4, 4, Color3.fromRGB(200, 40, 60), nil, vox)
	elseif fishId == "PatinPianissimo" then
		-- Mini piano under the belly, keys facing forward.
		VoxBox(model, "Piano", -2, 2, -4, -3, 1, 3, Color3.fromRGB(30, 30, 35), nil, vox)
		for i = 1, 5 do
			VoxBox(model, "PianoKey" .. i, -3 + i, -3 + i, -3, -3, 4, 4, Color3.fromRGB(255, 255, 255), nil, vox)
		end
	elseif fishId == "KoiKavaleri" then
		-- Knight helmet + red plume + lance pointing forward.
		VoxBox(model, "Helmet", -2, 2, 3, 3, 3, 4, Color3.fromRGB(180, 180, 190), Enum.Material.Metal, vox)
		VoxBox(model, "Plume", 0, 0, 4, 5, 3, 3, Color3.fromRGB(220, 40, 40), nil, vox)
		VoxBox(model, "Lance", 3, 3, 1, 1, 3, 5, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, vox)
	elseif fishId == "ArwanaAstronaut" then
		-- Glass helmet: panels around the head, built as frames with holes
		-- where the snout (front) and the body (back) pass through — a
		-- solid panel would overlap the nose/body voxels and z-fight.
		-- The snout pokes out the front hole, like a dog's nose out of a
		-- car window. The side panels stop at y=3 so they never share a
		-- voxel with the top panel (y=4).
		local glass = Color3.fromRGB(180, 220, 255)
		VoxBox(model, "HelmetFrontTop", -3, 3, 2, 4, 5, 5, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetFrontBottom", -3, 3, -2, -1, 5, 5, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetFrontL", -3, -2, 0, 1, 5, 5, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetFrontR", 2, 3, 0, 1, 5, 5, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetBackTop", -3, 3, 4, 4, 1, 1, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetBackBottom", -3, 3, -2, -2, 1, 1, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetBackL", -3, -3, -1, 3, 1, 1, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetBackR", 3, 3, -1, 3, 1, 1, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetSideL", -3, -3, -2, 3, 2, 4, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetSideR", 3, 3, -2, 3, 2, 4, glass, Enum.Material.Glass, vox)
		VoxBox(model, "HelmetTop", -3, 3, 4, 4, 2, 4, glass, Enum.Material.Glass, vox)
		for _, part in ipairs(model:GetChildren()) do
			if part.Name:sub(1, 6) == "Helmet" then
				part.Transparency = 0.4
			end
		end
		VoxBox(model, "OxygenTank", -1, 0, 3, 3, -3, -2, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, vox)
	elseif fishId == "SidatSultan" then
		-- Golden crown + purple cape along the eel's back.
		VoxBox(model, "CrownBase", -1, 1, 3, 3, 3, 4, Color3.fromRGB(255, 210, 60), Enum.Material.Metal, vox)
		for i = 1, 3 do
			VoxBox(model, "CrownSpike" .. i, -2 + i, -2 + i, 4, 4, 3, 3, Color3.fromRGB(255, 210, 60), Enum.Material.Metal, vox)
		end
		VoxBox(model, "Cape", -1, 1, 3, 3, -3, 2, Color3.fromRGB(120, 50, 200), nil, vox)
	elseif fishId == "BelutBarista" then
		-- Barista apron under the belly + coffee cup on the side.
		VoxBox(model, "Apron", -1, 1, -2, -2, 1, 4, Color3.fromRGB(255, 245, 230), nil, vox)
		VoxBox(model, "CoffeeCup", 2, 2, 0, 0, 4, 4, Color3.fromRGB(255, 255, 255), nil, vox)
		VoxBox(model, "Coffee", 2, 2, 1, 1, 4, 4, Color3.fromRGB(90, 55, 25), nil, vox)
	elseif fishId == "NagaNila" then
		-- Dragon horns sweeping up-out + red crest down the back (the
		-- crest replaces the dorsal fin for Naga).
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			VoxBox(model, "Horn1" .. s, side * 2, side * 2, 3, 3, 4, 4, Color3.fromRGB(255, 240, 200), nil, vox)
			VoxBox(model, "Horn2" .. s, side * 3, side * 3, 4, 4, 4, 4, Color3.fromRGB(255, 240, 200), nil, vox)
			VoxBox(model, "Horn3" .. s, side * 3, side * 3, 5, 5, 3, 3, Color3.fromRGB(255, 240, 200), nil, vox)
		end
		for i, z in ipairs({ 2, 0, -2 }) do
			VoxBox(model, "Crest" .. i, 0, 0, 4, 4, z, z, Color3.fromRGB(220, 40, 40), nil, vox)
		end
	end
end

-- The 3 famous brainrot legends (Mythic tier). Each is a custom voxel
-- build, not a fish: a log, a sneaker shark, and a winged crocodile.
local function BuildMythic(model, fishId)
	if fishId == "TungTungSahur" then
		-- A wooden log standing upright, angry face, baseball bat leaning
		-- on its shoulder. VOX 0.42: the log is 2.1 wide, 2.94 tall.
		local vox = 0.42
		local wood = Color3.fromRGB(150, 100, 55)
		local darkWood = Color3.fromRGB(110, 70, 35)
		VoxBox(model, "BodyLog", -2, 2, -3, 3, -2, 2, wood, Enum.Material.Wood, vox)
		VoxBox(model, "BarkRingTop", -2, 2, 2, 2, -2, 2, darkWood, Enum.Material.Wood, vox)
		VoxBox(model, "BarkRingBottom", -2, 2, -2, -2, -2, 2, darkWood, Enum.Material.Wood, vox)
		-- Angry eyes + brows + mouth on the front face (+Z).
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			local ex0 = side < 0 and -2 or 1
			local ex1 = side < 0 and -1 or 2
			VoxBox(model, "Eye" .. s, ex0, ex1, 1, 1, 3, 3, Color3.fromRGB(255, 255, 255), nil, vox)
			VoxBox(model, "Pupil" .. s, side < 0 and -1 or 1, side < 0 and -1 or 1, 1, 1, 4, 4, Color3.fromRGB(20, 20, 20), nil, vox)
			VoxBox(model, "Brow" .. s, ex0, ex1, 2, 2, 3, 3, darkWood, nil, vox)
		end
		VoxBox(model, "Mouth", -1, 1, -1, -1, 3, 3, Color3.fromRGB(30, 20, 10), nil, vox)
		-- Baseball bat leaning on the right shoulder.
		VoxBox(model, "Bat1", 3, 3, -1, 0, 1, 1, Color3.fromRGB(200, 150, 90), Enum.Material.Wood, vox)
		VoxBox(model, "Bat2", 3, 3, 1, 2, 1, 1, Color3.fromRGB(200, 150, 90), Enum.Material.Wood, vox)
		VoxBox(model, "BatTop", 3, 3, 3, 3, 1, 1, Color3.fromRGB(180, 130, 70), Enum.Material.Wood, vox)
		model.PrimaryPart = model:FindFirstChild("BodyLog")
	elseif fishId == "TralaleroTralala" then
		-- A shark (the fish generator, grey + white belly + big fins) with
		-- three legs in blue sneakers dangling under it.
		local vox = 0.34
		BuildFishBody(model, {
			BodyColor = Color3.fromRGB(160, 170, 185),
			BellyColor = Color3.fromRGB(240, 240, 245),
			FinColor = Color3.fromRGB(120, 130, 145),
			AccentColor = Color3.fromRGB(120, 130, 145),
			Body = "normal",
		}, vox)
		local shoe = Color3.fromRGB(60, 120, 255)
		local legX = { -1, 0, 1 }
		local legZ = { 2, 0, -2 }
		for i = 1, 3 do
			local x, z = legX[i], legZ[i]
			-- The rear leg (z=-2) reaches one voxel higher: the belly
			-- above it is the rear belly (y=-1), not the mid belly (y=-2).
			local top = (z == -2) and -2 or -3
			VoxBox(model, "Leg" .. i, x, x, -4, top, z, z, Color3.fromRGB(140, 150, 165), nil, vox)
			VoxBox(model, "Shoe" .. i, x, x + 1, -5, -5, z, z + 1, shoe, nil, vox)
		end
	elseif fishId == "BombardiroCrocodilo" then
		-- A long low crocodile with plane wings, a snout full of teeth and
		-- a propeller on its nose. VOX 0.28: 4.2 long, fits the tank.
		local vox = 0.28
		local green = Color3.fromRGB(70, 170, 80)
		local darkGreen = Color3.fromRGB(45, 130, 60)
		VoxBox(model, "BodyCroc", -2, 2, -1, 1, -4, 4, green, nil, vox)
		VoxBox(model, "BodyBellyCroc", -2, 2, -2, -2, -4, 4, Color3.fromRGB(220, 230, 180), nil, vox)
		VoxBox(model, "Snout", -1, 1, 0, 1, 5, 6, green, nil, vox)
		-- Teeth under the snout + eyes on top of the head.
		for _, side in ipairs({ -1, 1 }) do
			VoxBox(model, "Tooth" .. (side < 0 and "L" or "R"), side, side, -1, -1, 6, 6, Color3.fromRGB(255, 255, 255), nil, vox)
			VoxBox(model, "Eye" .. (side < 0 and "L" or "R"), side, side, 2, 2, 4, 4, Color3.fromRGB(255, 220, 60), nil, vox)
		end
		-- Tail tapering back + 4 short legs.
		VoxBox(model, "TailBase", -1, 1, -1, 1, -5, -5, green, nil, vox)
		VoxBox(model, "TailMid", 0, 0, 0, 1, -6, -6, green, nil, vox)
		VoxBox(model, "TailTip", 0, 0, 0, 0, -7, -7, darkGreen, nil, vox)
		for _, z in ipairs({ 3, -3 }) do
			for _, side in ipairs({ -1, 1 }) do
				VoxBox(model, "Leg" .. (side < 0 and "L" or "R") .. (z > 0 and "F" or "B"),
					side * 2, side * 2, -3, -3, z, z, darkGreen, nil, vox)
			end
		end
		-- Plane wings on the sides + a propeller on the nose (z=7, right
		-- against the snout — a propeller at z=8 would poke through the
		-- tank glass when the croc turns).
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			VoxBox(model, "Wing" .. s, math.min(side * 3, side * 4), math.max(side * 3, side * 4), 2, 2, -1, 1, Color3.fromRGB(230, 230, 235), Enum.Material.Metal, vox)
			VoxBox(model, "WingTip" .. s, side * 5, side * 5, 2, 2, 0, 0, Color3.fromRGB(220, 60, 60), nil, vox)
		end
		-- Crossed blades (the vertical blade skips the center voxel, which
		-- belongs to the horizontal blade — two parts on one voxel fight).
		VoxBox(model, "PropBladeUp", 0, 0, 1, 1, 7, 7, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, vox)
		VoxBox(model, "PropBladeDown", 0, 0, -1, -1, 7, 7, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, vox)
		VoxBox(model, "PropBladeH", -1, 1, 0, 0, 7, 7, Color3.fromRGB(200, 200, 210), Enum.Material.Metal, vox)
		model.PrimaryPart = model:FindFirstChild("BodyCroc")
	end
end

-- Applies a mutation skin to a finished model.
local function ApplyMutationSkin(model, mutation)
	if mutation == "Golden" then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(255, 205, 60)
				part.Material = Enum.Material.Neon
			end
		end
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 100)
		sparkles.Parent = model.PrimaryPart
	elseif mutation == "Rainbow" then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.Neon
			end
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
		})
		emitter.Size = NumberSequence.new(0.3)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Parent = model.PrimaryPart
	end
end

-- Species specs for the 9 original fish.
local FishSpecs = {
	LeleLirico = { Pattern = "stripes" },
	GuppyGondola = { Pattern = "sidestripe" },
	MujairMaestro = { Pattern = "sidestripe" },
	PatinPianissimo = {},
	KoiKavaleri = { Pattern = "koi" },
	ArwanaAstronaut = {},
	SidatSultan = { Body = "eel" },
	BelutBarista = { Body = "eel" },
	NagaNila = { NoDorsalFin = true },
}

-- Builds the full model for a fish id. mutation: "None" | "Golden" | "Rainbow".
-- The 9 original fish use the voxel fish generator; the 3 legends use
-- custom voxel builders. The model is built at the origin, nose toward +Z.
function FishModelFactory.BuildFishModel(fishId, mutation)
	local def = FishDefinitions.Fish[fishId]
	if not def then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = def.Name .. "Model"

	local spec = FishSpecs[fishId]
	if spec then
		local vox = VOX
		if fishId == "NagaNila" then
			vox = 0.34 -- Naga is the biggest fish in the lake.
		end
		BuildFishBody(model, {
			BodyColor = def.BodyColor,
			BellyColor = Lighten(def.BodyColor),
			FinColor = def.AccentColor,
			AccentColor = def.AccentColor,
			Body = spec.Body or "normal",
			Pattern = spec.Pattern,
			NoDorsalFin = spec.NoDorsalFin,
		}, vox)
		AddAccessory(model, fishId, def, vox)
	else
		BuildMythic(model, fishId)
	end

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	end
	if mutation and mutation ~= "None" then
		ApplyMutationSkin(model, mutation)
	end

	return model
end

return FishModelFactory
