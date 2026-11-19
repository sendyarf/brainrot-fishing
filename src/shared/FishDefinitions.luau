-- FishDefinitions — the 12 original brainrot fish of Brainrot Fishing.
-- Every fish is an absurd meme character with an Indonesian name, a rarity
-- tier and a money-per-second rate. The server rolls catches from this table
-- and the client reads it for labels, the Brainrotpedia and the shop.
-- All in-game text is English; only the fish names stay Indonesian.

local FishDefinitions = {}

-- Rarity ladder, cheapest first. The judge reads these names in the dossier.
FishDefinitions.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

FishDefinitions.RARITY_COLORS = {
	Common = Color3.fromRGB(170, 170, 170),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 150, 40),
	Mythic = Color3.fromRGB(255, 60, 60),
}

-- One entry per fish. Fields:
--   id: stable key used in DataStores and RemoteEvents
--   name: display name (Indonesian, original)
--   rarity: one of RARITIES
--   income: base dollars per second in a tank
--   bodyColor: the fish body's main colour
--   bellyColor: the belly / fin accent colour
--   accessory: which 3D prop FishModelFactory attaches ("none" means plain)
--   blurb: one English line shown in the Brainrotpedia
FishDefinitions.FISH = {
	{
		id = "lele",
		name = "Lele Lirico",
		rarity = "Common",
		income = 5,
		bodyColor = Color3.fromRGB(120, 125, 130),
		bellyColor = Color3.fromRGB(200, 200, 195),
		accessory = "whiskers",
		blurb = "A catfish that sings opera to the moon.",
	},
	{
		id = "guppy",
		name = "Guppy Gondola",
		rarity = "Common",
		income = 8,
		bodyColor = Color3.fromRGB(255, 140, 60),
		bellyColor = Color3.fromRGB(255, 210, 140),
		accessory = "strawhat",
		blurb = "Rows tourists across the lake in its own tail.",
	},
	{
		id = "teri",
		name = "Teri Trompet",
		rarity = "Common",
		income = 6,
		bodyColor = Color3.fromRGB(190, 200, 210),
		bellyColor = Color3.fromRGB(240, 245, 250),
		accessory = "trumpet",
		blurb = "A tiny anchovy with a very loud trumpet.",
	},
	{
		id = "mujair",
		name = "Mujair Maestro",
		rarity = "Rare",
		income = 20,
		bodyColor = Color3.fromRGB(90, 150, 210),
		bellyColor = Color3.fromRGB(200, 225, 245),
		accessory = "baton",
		blurb = "Conducts the lake choir with a seaweed baton.",
	},
	{
		id = "patin",
		name = "Patin Pianissimo",
		rarity = "Rare",
		income = 28,
		bodyColor = Color3.fromRGB(235, 235, 230),
		bellyColor = Color3.fromRGB(255, 255, 250),
		accessory = "piano",
		blurb = "Plays soft piano on a floating grand.",
	},
	{
		id = "gabus",
		name = "Gabus Gitaris",
		rarity = "Rare",
		income = 35,
		bodyColor = Color3.fromRGB(100, 140, 90),
		bellyColor = Color3.fromRGB(180, 210, 160),
		accessory = "guitar",
		blurb = "A snakehead shredding lake-rock solos.",
	},
	{
		id = "koi",
		name = "Koi Kavaleri",
		rarity = "Epic",
		income = 60,
		bodyColor = Color3.fromRGB(230, 70, 60),
		bellyColor = Color3.fromRGB(250, 240, 230),
		accessory = "knight",
		blurb = "A knight koi, sworn to guard the royal pond.",
	},
	{
		id = "arwana",
		name = "Arwana Astronaut",
		rarity = "Epic",
		income = 85,
		bodyColor = Color3.fromRGB(230, 180, 60),
		bellyColor = Color3.fromRGB(250, 220, 130),
		accessory = "helmet",
		blurb = "An arowana training for the first fish moonwalk.",
	},
	{
		id = "sidat",
		name = "Sidat Sultan",
		rarity = "Legendary",
		income = 180,
		bodyColor = Color3.fromRGB(140, 90, 200),
		bellyColor = Color3.fromRGB(210, 180, 240),
		accessory = "crown",
		blurb = "The eel sultan rules the deep with a golden crown.",
	},
	{
		id = "belut",
		name = "Belut Barista",
		rarity = "Legendary",
		income = 250,
		bodyColor = Color3.fromRGB(150, 105, 70),
		bellyColor = Color3.fromRGB(220, 190, 150),
		accessory = "coffee",
		blurb = "Brews the lake's finest espresso, one fin at a time.",
	},
	{
		id = "gurame",
		name = "Gurame Gamelan",
		rarity = "Legendary",
		income = 320,
		bodyColor = Color3.fromRGB(60, 160, 130),
		bellyColor = Color3.fromRGB(150, 230, 200),
		accessory = "gong",
		blurb = "A gourami whose gong shakes the whole lake.",
	},
	{
		id = "naga",
		name = "Naga Nila",
		rarity = "Mythic",
		income = 600,
		bodyColor = Color3.fromRGB(60, 180, 90),
		bellyColor = Color3.fromRGB(255, 215, 90),
		accessory = "horns",
		blurb = "The giant guardian dragon of the lake. Twice the size, ten times the legend.",
	},
}

-- Fast lookup by id, built once at require time.
local byId = {}
for _, fish in ipairs(FishDefinitions.FISH) do
	byId[fish.id] = fish
end

-- Fish grouped by rarity tier, for the catch roll.
local byRarity = {}
for _, rarity in ipairs(FishDefinitions.RARITIES) do
	byRarity[rarity] = {}
end
for _, fish in ipairs(FishDefinitions.FISH) do
	table.insert(byRarity[fish.rarity], fish)
end

function FishDefinitions.GetFishById(fishId)
	return byId[fishId]
end

function FishDefinitions.GetFishInRarity(rarity)
	return byRarity[rarity] or {}
end

function FishDefinitions.GetRandomFishInRarity(rarity)
	local pool = byRarity[rarity]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

function FishDefinitions.GetRarityColor(rarity)
	return FishDefinitions.RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
end

function FishDefinitions.GetFishCount()
	return #FishDefinitions.FISH
end

return FishDefinitions
