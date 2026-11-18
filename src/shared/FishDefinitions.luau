-- FishDefinitions: the 12 brainrot of Brainrot Fishing — 9 original fish
-- plus 3 famous brainrot legends (Mythic tier). Names are Indonesian (the
-- user's choice); every other word is English. Each fish has a distinct
-- body color, accent color and signature accessory so it reads at a glance
-- in a tank label and in a 382x238 screenshot.

local FishDefinitions = {}

FishDefinitions.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

FishDefinitions.RarityColors = {
	Common = Color3.fromRGB(170, 170, 180),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 150, 40),
	Mythic = Color3.fromRGB(255, 60, 60),
}

FishDefinitions.Fish = {
	LeleLirico = {
		Name = "Lele Lirico",
		Rarity = "Common",
		Income = 5,
		BodyColor = Color3.fromRGB(140, 140, 150),
		AccentColor = Color3.fromRGB(90, 90, 100),
		Accessory = "Whiskers",
		Description = "A singing catfish conducting the lake with its whiskers.",
	},
	GuppyGondola = {
		Name = "Guppy Gondola",
		Rarity = "Common",
		Income = 8,
		BodyColor = Color3.fromRGB(255, 140, 50),
		AccentColor = Color3.fromRGB(255, 220, 120),
		Accessory = "StrawHat",
		Description = "A tiny orange guppy sailing in a gondola-shaped tail.",
	},
	MujairMaestro = {
		Name = "Mujair Maestro",
		Rarity = "Rare",
		Income = 20,
		BodyColor = Color3.fromRGB(110, 180, 255),
		AccentColor = Color3.fromRGB(220, 235, 255),
		Accessory = "Baton",
		Description = "A silver-blue maestro waving a seaweed baton.",
	},
	PatinPianissimo = {
		Name = "Patin Pianissimo",
		Rarity = "Rare",
		Income = 28,
		BodyColor = Color3.fromRGB(245, 245, 240),
		AccentColor = Color3.fromRGB(40, 40, 45),
		Accessory = "Piano",
		Description = "A white catfish playing a floating mini piano.",
	},
	KoiKavaleri = {
		Name = "Koi Kavaleri",
		Rarity = "Epic",
		Income = 60,
		BodyColor = Color3.fromRGB(255, 80, 70),
		AccentColor = Color3.fromRGB(255, 255, 255),
		Accessory = "Knight",
		Description = "A red-and-white koi knight charging with a tiny lance.",
	},
	ArwanaAstronaut = {
		Name = "Arwana Astronaut",
		Rarity = "Epic",
		Income = 85,
		BodyColor = Color3.fromRGB(255, 200, 60),
		AccentColor = Color3.fromRGB(180, 220, 255),
		Accessory = "Astronaut",
		Description = "A golden arowana in a glass space helmet.",
	},
	SidatSultan = {
		Name = "Sidat Sultan",
		Rarity = "Legendary",
		Income = 180,
		BodyColor = Color3.fromRGB(150, 80, 220),
		AccentColor = Color3.fromRGB(255, 210, 60),
		Accessory = "Crown",
		Description = "A long purple eel sultan wearing a golden crown.",
	},
	BelutBarista = {
		Name = "Belut Barista",
		Rarity = "Legendary",
		Income = 250,
		BodyColor = Color3.fromRGB(150, 100, 60),
		AccentColor = Color3.fromRGB(255, 245, 230),
		Accessory = "Barista",
		Description = "A brown eel barista serving coffee from its fin.",
	},
	NagaNila = {
		Name = "Naga Nila",
		Rarity = "Mythic",
		Income = 600,
		BodyColor = Color3.fromRGB(60, 200, 110),
		AccentColor = Color3.fromRGB(255, 210, 60),
		Accessory = "Dragon",
		Description = "The giant green-gold dragon guardian of the lake.",
	},
	TungTungSahur = {
		Name = "Tung Tung Tung Sahur",
		Rarity = "Mythic",
		Income = 900,
		BodyColor = Color3.fromRGB(150, 100, 55),
		AccentColor = Color3.fromRGB(110, 70, 35),
		Accessory = "BaseballBat",
		Description = "A furious wooden log with a baseball bat. Never wake it at sahur.",
	},
	TralaleroTralala = {
		Name = "Tralalero Tralala",
		Rarity = "Mythic",
		Income = 1400,
		BodyColor = Color3.fromRGB(160, 170, 185),
		AccentColor = Color3.fromRGB(60, 120, 255),
		Accessory = "Sneakers",
		Description = "A shark with three legs in blue sneakers. It walks. It swims. It sings.",
	},
	BombardiroCrocodilo = {
		Name = "Bombardiro Crocodilo",
		Rarity = "Mythic",
		Income = 2000,
		BodyColor = Color3.fromRGB(70, 170, 80),
		AccentColor = Color3.fromRGB(230, 230, 235),
		Accessory = "PlaneWings",
		Description = "A crocodile bomber plane with a propeller nose. Cleared for takeoff.",
	},
}

FishDefinitions.FishByTier = {
	Common = { "LeleLirico", "GuppyGondola" },
	Rare = { "MujairMaestro", "PatinPianissimo" },
	Epic = { "KoiKavaleri", "ArwanaAstronaut" },
	Legendary = { "SidatSultan", "BelutBarista" },
	Mythic = { "NagaNila", "TungTungSahur", "TralaleroTralala", "BombardiroCrocodilo" },
}

-- Weighted draw inside the Mythic tier: the lake guardian is the most
-- common Mythic; the bomber croc is the rarest catch in the game.
FishDefinitions.MythicWeights = {
	NagaNila = 40,
	TungTungSahur = 25,
	TralaleroTralala = 20,
	BombardiroCrocodilo = 15,
}

-- All fish ids in rarity order (for the Brainrotpedia grid).
FishDefinitions.AllFishIds = {
	"LeleLirico",
	"GuppyGondola",
	"MujairMaestro",
	"PatinPianissimo",
	"KoiKavaleri",
	"ArwanaAstronaut",
	"SidatSultan",
	"BelutBarista",
	"NagaNila",
	"TungTungSahur",
	"TralaleroTralala",
	"BombardiroCrocodilo",
}

-- Returns the rarity tier one step above the given tier (Mythic stays Mythic).
function FishDefinitions.GetNextTier(tier)
	for i, name in ipairs(FishDefinitions.RarityOrder) do
		if name == tier then
			return FishDefinitions.RarityOrder[math.min(i + 1, #FishDefinitions.RarityOrder)]
		end
	end
	return tier
end

-- Returns the numeric rank of a tier (Common = 1, Mythic = 5).
function FishDefinitions.GetTierRank(tier)
	for i, name in ipairs(FishDefinitions.RarityOrder) do
		if name == tier then
			return i
		end
	end
	return 1
end

return FishDefinitions
