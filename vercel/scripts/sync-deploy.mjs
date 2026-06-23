/**
 * Copies live script sources into the Vercel deploy bundle.
 * Run after editing hollow.lua or loader-body.lua (also runs on Vercel build).
 */
import fs from "fs";
import { spawnSync } from "child_process";
import path from "path";
import crypto from "crypto";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const vercelRoot = path.join(__dirname, "..");
const repoRoot = path.join(vercelRoot, "..");
const privateDir = path.join(vercelRoot, "private");
const manifestPath = path.join(privateDir, "script-manifest.json");

function copyDir(src, dest, { exclude } = {}) {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (exclude?.(entry.name)) continue;
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath, { exclude });
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function syncRootDeployBundle() {
  copyDir(path.join(vercelRoot, "api"), path.join(repoRoot, "api"));
  copyDir(path.join(vercelRoot, "lib"), path.join(repoRoot, "lib"));

  const rootPublic = path.join(repoRoot, "public");
  fs.mkdirSync(rootPublic, { recursive: true });
  for (const name of ["hollow.lua", "loader.lua"]) {
    const src = path.join(vercelRoot, "public", name);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(rootPublic, name));
      console.log(`[sync] ${name} -> ${path.join(rootPublic, name)}`);
    }
  }

  const rootPrivate = path.join(repoRoot, "private");
  fs.mkdirSync(rootPrivate, { recursive: true });
  for (const name of ["hollow.lua", "script-manifest.json"]) {
    const src = path.join(privateDir, name);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, path.join(rootPrivate, name));
      console.log(`[sync] ${name} -> ${path.join(rootPrivate, name)}`);
    }
  }

  const rootPackage = {
    name: "hollow",
    private: true,
    scripts: {
      build: "node vercel/scripts/sync-deploy.mjs",
      "vercel-build": "node vercel/scripts/sync-deploy.mjs",
    },
    dependencies: {
      "@upstash/redis": "^1.34.3",
      redis: "^4.7.0",
    },
  };
  fs.writeFileSync(
    path.join(repoRoot, "package.json"),
    JSON.stringify(rootPackage, null, 2) + "\n",
    "utf8"
  );
  console.log(`[sync] package.json -> ${path.join(repoRoot, "package.json")}`);
  console.log(`[sync] api/ + lib/ -> repo root (for Vercel root deploy)`);

  const scriptsSrc = path.join(repoRoot, "scripts");
  for (const scriptsDest of [
    path.join(vercelRoot, "public", "scripts"),
    path.join(repoRoot, "public", "scripts"),
  ]) {
    fs.mkdirSync(scriptsDest, { recursive: true });
    if (fs.existsSync(scriptsSrc)) {
      for (const name of fs.readdirSync(scriptsSrc)) {
        if (!name.endsWith(".lua")) continue;
        fs.copyFileSync(path.join(scriptsSrc, name), path.join(scriptsDest, name));
      }
      console.log(`[sync] scripts/*.lua -> ${scriptsDest}`);
    }
  }
}

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

const embedScript = path.join(repoRoot, "tools", "embed-modules.py");
if (fs.existsSync(embedScript)) {
  const embedResult = spawnSync("py", [embedScript], { cwd: repoRoot, encoding: "utf8" });
  if (embedResult.status !== 0) {
    console.warn("[sync] embed-modules.py failed — hollow.lua may miss embedded map modules.");
  }
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
  const publicLoader = path.join(vercelRoot, "public", "loader.lua");
  const rootLoader = path.join(repoRoot, "loader.lua");
  console.log(`[sync] loader.lua (static) -> ${publicLoader}`);
  fs.writeFileSync(rootLoader, loader.body, "utf8");
  console.log(`[sync] loader.lua -> ${rootLoader}`);
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

syncRootDeployBundle();

console.log("[sync] PUSH api/, lib/, package.json, public/, private/, loader.lua to GitHub");
