const fs = require("fs");
const path = require("path");
const { getRedis, tokenKey } = require("../lib/redis");
const { json, text } = require("../lib/http");

function loadScriptBody() {
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

  return best;
}

module.exports = async (req, res) => {
  if (req.method !== "GET") {
    return json(res, 405, { ok: false, error: "GET only" });
  }

  const token = String((req.query && req.query.token) || "").trim();
  if (!token) {
    return text(res, 401, "-- missing token");
  }

  try {
    const redis = await getRedis();
    const username = await redis.get(tokenKey(token));
    if (!username) {
      return text(res, 401, "-- invalid or expired token");
    }

    const loaded = loadScriptBody();
    if (!loaded) {
      return text(res, 500, "-- script not found on server");
    }

    const build = loaded.body.match(/^--\s*HOLLOW_BUILD:([^\r\n]+)/)?.[1] || "unknown";
    res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate");
    res.setHeader("X-Hollow-Build", build);
    res.setHeader("X-Hollow-File", path.basename(loaded.filePath));
    return text(res, 200, loaded.body);
  } catch (err) {
    return text(res, 500, `-- ${String(err?.message || err)}`);
  }
};
