# Brainrot Fishing

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/sendyarf/brainrot-fishing/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/sendyarf/brainrot-fishing/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

**Fish, steal, lock, rebirth.** A 3D voxel fishing game on Roblox where you catch 12 original
brainrot fish, fill money-making tanks, steal from rivals, and guard your base from shadow
thieves — built by an AI agent for [make.fun](https://make.fun/bounty/roblox-brainrot-01)'s
"Make the best AI Roblox brainrot game" bounty ($1,000 in USDC).

Play it: https://www.roblox.com/games/86979109472260/Brainrot-Fishing

## How it plays

- **Fish** in four ponds (Shallow, Deep, Abyss, Royal) with a reel minigame — land the needle
  on green three times to catch. Rarer ponds, rarer fish: Mythic rates run 1% to 10%.
- **Earn** — every fish in your tanks pays $/second, even while you're offline (50%, capped).
- **Steal** — hold E for 3 seconds at a rival's tank to snatch their best fish. A shadow thief
  can do the same to you.
- **Lock your base** — 5 minutes of protection, 10-minute cooldown. Time it well.
- **Events** — the lake monster Naga Nila stirs every 4–6 minutes: reel fast (10s limit) or
  lose fish, but a catch during the event pays a blessing.
- **Mutations** — Golden (5%, ×2 income) and Rainbow (1%, ×4 income) fish.
- **Rebirth** — at $25,000, reset cash and gear for a permanent +50% income multiplier
  (up to ×3.5) and unlock the Royal Pond.
- **Progression** — 5 rods, 4 baits, tank slots up to 12, a 12-fish Brainrotpedia, 3 daily
  quests, and a 7-day daily reward track.

## Layout

- `src/` — Luau source (ServerScriptService, ReplicatedStorage, StarterGui), built with Rojo.
- `game.rbxl` — the built place, published to Roblox.
- `screenshots/` — four 1280×720 captures (the first is the game's thumbnail on Roblox).
- `PLAY.json` — names the published place (place 86979109472260).
- `main.ts` (Node 22, standard library only) — hands the game in: copies `game.rbxl`, `src/`,
  `screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json`.

## Run it as the grader does

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

Rebuild the place from source with [Rojo](https://rojo.space/):

    rojo build -o game.rbxl default.project.json

Built with [make.fun](https://make.fun/r/m83e76rq) — build AI games, win bounties.
