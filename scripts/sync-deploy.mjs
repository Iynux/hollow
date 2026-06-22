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

function stripBom(text) {
  if (text.charCodeAt(0) === 0xfeff) {
    return text.slice(1);
  }
  if (text.startsWith("\uFEFF")) {
    return text.slice(1);
  }
  return text;
}

function stripBuildLine(text) {
  return text.replace(/^--\s*HOLLOW_BUILD:[^\r\n]*\r?\n/, "");
}

function stampBody(body, hash) {
  const clean = stripBuildLine(stripBom(body)).replace(/^\n+/, "");
  return `-- HOLLOW_BUILD:${hash}\n${clean}`;
}

function copyFirst(sources) {
  for (const source of sources) {
    if (!fs.existsSync(source)) continue;
    const body = stripBom(fs.readFileSync(source, "utf8"));
    return { source, body };
  }
  return null;
}

function writeHollowCopies(body, hash) {
  const stamped = stampBody(body, hash);
  const targets = [
    path.join(vercelRoot, "hollow.lua"),
    path.join(privateDir, "hollow.lua"),
    path.join(vercelRoot, "public", "hollow.lua"),
  ];

  for (const dest of targets) {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, stamped, "utf8");
    console.log(`[sync] hollow.lua -> ${dest}`);
  }

  return stamped;
}

const hollowSource = copyFirst([
  path.join(repoRoot, "hollow.lua"),
  path.join(vercelRoot, "hollow.lua"),
  path.join(privateDir, "hollow.lua"),
]);

let hollow = null;
if (hollowSource) {
  const hash = sha256(stripBuildLine(hollowSource.body));
  const stamped = writeHollowCopies(hollowSource.body, hash);
  hollow = { source: hollowSource.source, body: stamped, hash };
}

function copyLoader(sources, dest, label) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  for (const source of sources) {
    if (!fs.existsSync(source)) continue;
    const body = stripBom(fs.readFileSync(source, "utf8"));
    fs.writeFileSync(dest, body, "utf8");
    console.log(`[sync] ${label}: ${source} -> ${dest}`);
    return { source, body };
  }
  return null;
}

const loader = copyLoader(
  [path.join(vercelRoot, "api", "loader-body.lua"), path.join(vercelRoot, "public", "loader.lua")],
  path.join(vercelRoot, "public", "loader.lua"),
  "loader.lua"
);

if (loader) {
  console.log(`[sync] loader.lua (static) -> ${path.join(vercelRoot, "public", "loader.lua")}`);
}

if (!hollow) {
  console.warn("[sync] Warning: hollow.lua not found — /api/script will fail until vercel/hollow.lua exists.");
}

const manifest = {
  updatedAt: new Date().toISOString(),
  hollow: hollow
    ? { hash: hollow.hash, bytes: Buffer.byteLength(hollow.body, "utf8"), from: hollow.source }
    : null,
  loader: loader
    ? { hash: sha256(loader.body), bytes: Buffer.byteLength(loader.body, "utf8"), from: loader.source }
    : null,
};

fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
console.log(`[sync] manifest: ${manifestPath}`);
console.log(`[sync] hollow ${manifest.hollow?.hash ?? "missing"} | loader ${manifest.loader?.hash ?? "missing"}`);
console.log("[sync] PUSH vercel/hollow.lua + vercel/private/hollow.lua to GitHub");
