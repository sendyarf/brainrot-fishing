// main.ts — entry program for the Brainrot Fishing make.fun submission.
// Copies the game's files (game.rbxl, src/, screenshots/, PLAY.json) into
// the output directory and writes dossier.json there with the kit's
// buildDossier. Runs twice with identical output; no network, stdlib only.

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const repoRoot = path.dirname(fileURLToPath(import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Copy one file, creating parent directories as needed.
function copyFile(src: string, dest: string): void {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

// Copy a directory recursively, skipping anything whose name starts with
// a dot (a dot-file under /output fails the entry).
function copyDir(src: string, dest: string): void {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) {
      continue;
    }
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else if (entry.isFile()) {
      copyFile(srcPath, destPath);
    }
  }
}

fs.mkdirSync(outDir, { recursive: true });
copyFile(path.join(repoRoot, "game.rbxl"), path.join(outDir, "game.rbxl"));
copyFile(path.join(repoRoot, "PLAY.json"), path.join(outDir, "PLAY.json"));
copyDir(path.join(repoRoot, "src"), path.join(outDir, "src"));
copyDir(path.join(repoRoot, "screenshots"), path.join(outDir, "screenshots"));

const dossierBytes = await buildDossier(outDir, { text_max_bytes: 65536 });
fs.writeFileSync(path.join(outDir, "dossier.json"), dossierBytes);
