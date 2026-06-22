/**
 * Copies live script sources into the Vercel deploy bundle.
 * Run after editing hollow.lua or loader-body.lua (also runs on Vercel build).
 */
import fs from "fs";
import path from "path";
import crypto from "crypto";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const vercelRoot = path.join(__dirname, "..");
const repoRoot = path.join(vercelRoot, "..");
const privateDir = path.join(vercelRoot, "private");
const manifestPath = path.join(privateDir, "script-manifest.json");

function sha256(text) {
  return crypto.createHash("sha256").update(text, "utf8").digest("hex").slice(0, 12);
}

function copyFirst(sources, dest, label) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  for (const source of sources) {
    if (!fs.existsSync(source)) continue;
    const body = fs.readFileSync(source, "utf8");
    fs.writeFileSync(dest, body, "utf8");
    console.log(`[sync] ${label}: ${source} -> ${dest}`);
    return { source, body };
  }
  return null;
}

const hollow = copyFirst(
  [path.join(repoRoot, "hollow.lua"), path.join(vercelRoot, "hollow.lua"), path.join(privateDir, "hollow.lua")],
  path.join(privateDir, "hollow.lua"),
  "hollow.lua"
);

const loader = copyFirst(
  [path.join(vercelRoot, "api", "loader-body.lua"), path.join(vercelRoot, "public", "loader.lua")],
  path.join(vercelRoot, "public", "loader.lua"),
  "loader.lua"
);

if (!hollow) {
  console.warn("[sync] Warning: hollow.lua not found — /api/script will fail until private/hollow.lua exists.");
}

const manifest = {
  updatedAt: new Date().toISOString(),
  hollow: hollow
    ? { hash: sha256(hollow.body), bytes: Buffer.byteLength(hollow.body, "utf8"), from: hollow.source }
    : null,
  loader: loader
    ? { hash: sha256(loader.body), bytes: Buffer.byteLength(loader.body, "utf8"), from: loader.source }
    : null,
};

fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
console.log(`[sync] manifest: ${manifestPath}`);
console.log(`[sync] hollow ${manifest.hollow?.hash ?? "missing"} | loader ${manifest.loader?.hash ?? "missing"}`);
