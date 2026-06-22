const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { getRedis } = require("../lib/redis");

function loadScriptInfo() {
  const cwd = process.cwd();
  const candidates = [
    path.join(cwd, "hollow.lua"),
    path.join(cwd, "private", "hollow.lua"),
    path.join(cwd, "..", "hollow.lua"),
  ];

  let best = null;
  for (const filePath of candidates) {
    if (!fs.existsSync(filePath)) continue;

    let body;
    try {
      body = fs.readFileSync(filePath, "utf8");
    } catch {
      continue;
    }
    if (!body || !body.trim()) continue;

    const stat = fs.statSync(filePath);
    const hasBuild = /^--\s*HOLLOW_BUILD:/.test(body) ? 1 : 0;
    const score = hasBuild * 1e15 + stat.mtimeMs;

    if (!best || score > best.score) {
      best = { body, filePath, score };
    }
  }

  if (!best) return null;

  const buildMatch = best.body.match(/^--\s*HOLLOW_BUILD:([^\r\n]+)/);
  return {
    hash: crypto.createHash("sha256").update(best.body, "utf8").digest("hex").slice(0, 12),
    build: buildMatch ? buildMatch[1].trim() : null,
    bytes: Buffer.byteLength(best.body, "utf8"),
    file: path.basename(best.filePath),
  };
}

function readScriptManifest() {
  try {
    const filePath = path.join(process.cwd(), "private", "script-manifest.json");
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

module.exports = async (_req, res) => {
  const payload = { ok: true, service: "Hollow API", storage: "kv" };
  const manifest = readScriptManifest();
  const live = loadScriptInfo();

  if (live) {
    payload.script = {
      updatedAt: manifest?.updatedAt ?? null,
      hollowHash: live.hash,
      hollowBuild: live.build,
      loaderHash: manifest?.loader?.hash ?? null,
      servedFrom: live.file,
    };
  } else if (manifest) {
    payload.script = {
      updatedAt: manifest.updatedAt,
      hollowHash: manifest.hollow?.hash ?? null,
      loaderHash: manifest.loader?.hash ?? null,
    };
  }

  try {
    const redis = await getRedis();
    await redis.ping();
    payload.kv = "connected";
  } catch (err) {
    payload.kv = "error";
    payload.kvError = String(err?.message || err);
  }

  res.statusCode = 200;
  res.setHeader("Content-Type", "application/json");
  res.setHeader("Cache-Control", "no-store");
  res.end(JSON.stringify(payload));
};
