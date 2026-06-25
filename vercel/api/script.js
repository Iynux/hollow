const fs = require("fs");
const path = require("path");
const { getRedis, tokenKey } = require("../lib/redis");
const { getLiveScriptBody } = require("../lib/script-store");
const { json, text } = require("../lib/http");
const {
  applySecurityHeaders,
  checkRateLimit,
  enforceApiAccess,
  isValidToken,
} = require("../lib/security");

function loadScriptFromDisk() {
  const cwd = process.cwd();
  const candidates = [
    path.join(cwd, "private", "hollow.lua"),
    path.join(cwd, "hollow.lua"),
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
    if (/Input Towers Now/.test(body)) continue;

    const stat = fs.statSync(filePath);
    const hasBuild = /^--\s*HOLLOW_BUILD:/.test(body) ? 1 : 0;
    const score = hasBuild * 1e15 + stat.mtimeMs;

    if (!best || score > best.score) {
      best = { body, filePath, score, source: "file" };
    }
  }

  return best;
}

function isStaleScriptBody(body) {
  if (!body || !String(body).trim()) return true;
  if (/Input Towers Now/.test(body)) return true;
  if (!/^--\s*HOLLOW_BUILD:/.test(body)) return true;
  return false;
}

module.exports = async (req, res) => {
  if (req.method !== "GET") {
    applySecurityHeaders(res);
    return json(res, 405, { ok: false, error: "GET only" });
  }

  const token = String((req.query && req.query.token) || "").trim();
  if (!isValidToken(token)) {
    applySecurityHeaders(res);
    return text(res, 401, "-- missing token");
  }

  let redis = null;
  try {
    redis = await getRedis();
  } catch {
    redis = null;
  }

  if (!(await enforceApiAccess(req, res, redis, {
    route: "script",
    requireClient: true,
    ipLimit: 90,
  }))) {
    return;
  }

  try {
    const username = await redis.get(tokenKey(token));
    if (!username) {
      return text(res, 401, "-- invalid or expired token");
    }

    const tokenOk = await checkRateLimit(redis, `script:${token}`, 40, 60);
    if (!tokenOk) {
      return text(res, 429, "-- rate limited");
    }

    let loaded = null;
    const fromDisk = loadScriptFromDisk();
    const fromKv = await getLiveScriptBody(redis);

    if (fromDisk && !isStaleScriptBody(fromDisk.body)) {
      loaded = fromDisk;
    } else if (fromKv && !isStaleScriptBody(fromKv)) {
      loaded = { body: fromKv, source: "kv" };
    }

    if (!loaded) {
      return text(res, 500, "-- script not found on server");
    }

    applySecurityHeaders(res);
    return text(res, 200, loaded.body);
  } catch (err) {
    return text(res, 500, "-- unavailable");
  }
};
