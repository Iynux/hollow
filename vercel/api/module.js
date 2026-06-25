const fs = require("fs");
const path = require("path");
const { getRedis, tokenKey } = require("../lib/redis");
const { json, text } = require("../lib/http");
const { applySecurityHeaders, checkRateLimit, enforceApiAccess, isValidToken } = require("../lib/security");

const MODULE_NAME = /^[A-Za-z0-9_.-]+\.lua$/;

function moduleCandidates(name) {
  const cwd = process.cwd();
  return [
    path.join(cwd, "public", "scripts", name),
    path.join(cwd, "scripts", name),
    path.join(cwd, "..", "scripts", name),
  ];
}

function loadModuleFromDisk(name) {
  for (const filePath of moduleCandidates(name)) {
    if (!fs.existsSync(filePath)) continue;
    try {
      const body = fs.readFileSync(filePath, "utf8");
      if (body && body.trim()) {
        return body;
      }
    } catch {
      continue;
    }
  }
  return null;
}

module.exports = async (req, res) => {
  if (req.method !== "GET") {
    applySecurityHeaders(res);
    return json(res, 405, { ok: false, error: "GET only" });
  }

  const token = String((req.query && req.query.token) || "").trim();
  const name = String((req.query && req.query.name) || "").trim();

  if (!isValidToken(token)) {
    applySecurityHeaders(res);
    return text(res, 401, "-- missing token");
  }

  if (!MODULE_NAME.test(name)) {
    applySecurityHeaders(res);
    return text(res, 400, "-- invalid module name");
  }

  let redis = null;
  try {
    redis = await getRedis();
  } catch {
    redis = null;
  }

  if (!(await enforceApiAccess(req, res, redis, {
    route: "module",
    requireClient: false,
    ipLimit: 180,
  }))) {
    return;
  }

  try {
    const username = await redis.get(tokenKey(token));
    if (!username) {
      return text(res, 401, "-- invalid or expired token");
    }

    const tokenOk = await checkRateLimit(redis, `module:${token}`, 120, 60);
    if (!tokenOk) {
      return text(res, 429, "-- rate limited");
    }

    const body = loadModuleFromDisk(name);
    if (!body) {
      return text(res, 404, "-- module not found");
    }

    applySecurityHeaders(res);
    return text(res, 200, body);
  } catch (err) {
    return text(res, 500, `-- ${String(err?.message || err)}`);
  }
};
