const crypto = require("crypto");

const SCRIPT_BODY_KEY = "hollow:script:body";
const SCRIPT_META_KEY = "hollow:script:meta";

function scriptHash(body) {
  return crypto.createHash("sha256").update(body, "utf8").digest("hex").slice(0, 12);
}

function parseBuild(body) {
  const match = String(body || "").match(/^--\s*HOLLOW_BUILD:([^\r\n]+)/);
  return match ? match[1].trim() : null;
}

async function getLiveScriptMeta(redis) {
  const meta = await redis.get(SCRIPT_META_KEY);
  if (meta && typeof meta === "object") {
    return meta;
  }
  return null;
}

async function getLiveScriptBody(redis) {
  const body = await redis.get(SCRIPT_BODY_KEY);
  if (typeof body === "string" && body.trim() !== "") {
    return body;
  }
  return null;
}

async function setLiveScript(redis, body) {
  const script = String(body || "");
  if (!script.trim()) {
    throw new Error("script body is empty");
  }

  const meta = {
    hash: scriptHash(script),
    build: parseBuild(script),
    updatedAt: new Date().toISOString(),
    bytes: Buffer.byteLength(script, "utf8"),
    source: "kv",
  };

  await redis.set(SCRIPT_BODY_KEY, script);
  await redis.set(SCRIPT_META_KEY, meta);
  return meta;
}

module.exports = {
  SCRIPT_BODY_KEY,
  SCRIPT_META_KEY,
  scriptHash,
  parseBuild,
  getLiveScriptMeta,
  getLiveScriptBody,
  setLiveScript,
};
