const { getRedis, tokenKey } = require("../lib/redis");
const { json, text } = require("../lib/http");
const { loadScriptBody } = require("../lib/script-body");

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

    res.setHeader("X-Hollow-Build", loaded.body.match(/^--\s*HOLLOW_BUILD:([^\r\n]+)/)?.[1] || "unknown");
    return text(res, 200, loaded.body);
  } catch (err) {
    return text(res, 500, `-- ${String(err?.message || err)}`);
  }
};
