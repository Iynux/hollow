const fs = require("fs");
const path = require("path");
const { getRedis, tokenKey } = require("../lib/redis");
const { json, text } = require("../lib/http");

function loadScriptBody() {
  const candidates = [
    path.join(process.cwd(), "private", "hollow.lua"),
    path.join(process.cwd(), "..", "hollow.lua"),
  ];
  for (const filePath of candidates) {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, "utf8");
    }
  }
  return null;
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

    const script = loadScriptBody();
    if (!script) {
      return text(res, 500, "-- script not found on server");
    }

    return text(res, 200, script);
  } catch (err) {
    return text(res, 500, `-- ${String(err?.message || err)}`);
  }
};
