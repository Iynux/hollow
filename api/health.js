const fs = require("fs");
const path = require("path");
const { getRedis } = require("../lib/redis");
const { getLiveScriptMeta, getLiveScriptBody, scriptHash, parseBuild } = require("../lib/script-store");

function loadScriptFromDisk() {
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
      best = {
        hash: scriptHash(body),
        build: parseBuild(body),
        bytes: Buffer.byteLength(body, "utf8"),
        file: path.basename(filePath),
        source: "file",
        score,
      };
    }
  }

  return best;
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

  try {
    const redis = await getRedis();
    await redis.ping();
    payload.kv = "connected";

    const kvMeta = await getLiveScriptMeta(redis);
    const kvBody = await getLiveScriptBody(redis);
    const disk = loadScriptFromDisk();

    if (kvMeta && kvBody) {
      payload.script = {
        updatedAt: kvMeta.updatedAt,
        hollowHash: kvMeta.hash,
        hollowBuild: kvMeta.build,
        loaderHash: manifest?.loader?.hash ?? null,
        servedFrom: "redis",
        bytes: kvMeta.bytes,
      };
    } else if (disk) {
      payload.script = {
        updatedAt: manifest?.updatedAt ?? null,
        hollowHash: disk.hash,
        hollowBuild: disk.build,
        loaderHash: manifest?.loader?.hash ?? null,
        servedFrom: disk.file,
        bytes: disk.bytes,
      };
    } else if (manifest) {
      payload.script = {
        updatedAt: manifest.updatedAt,
        hollowHash: manifest.hollow?.hash ?? null,
        loaderHash: manifest.loader?.hash ?? null,
        servedFrom: "manifest-only",
      };
    }
  } catch (err) {
    payload.kv = "error";
    payload.kvError = String(err?.message || err);
  }

  res.statusCode = 200;
  res.setHeader("Content-Type", "application/json");
  res.setHeader("Cache-Control", "no-store");
  res.end(JSON.stringify(payload));
};
