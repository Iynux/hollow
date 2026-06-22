const fs = require("fs");
const path = require("path");
const { getRedis } = require("../lib/redis");

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
  if (manifest) {
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
  res.end(JSON.stringify(payload));
};
