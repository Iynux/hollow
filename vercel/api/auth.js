const { hashPassword, normalizeUsername, randomToken } = require("../lib/crypto");
const { accountKey, getRedis, tokenKey } = require("../lib/redis");
const { json, readJsonBody } = require("../lib/http");
const { applySecurityHeaders, checkRateLimit, clientIp, isBrowserOrScraper } = require("../lib/security");

module.exports = async (req, res) => {
  applySecurityHeaders(res);

  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }

  if (isBrowserOrScraper(req)) {
    return json(res, 403, { ok: false, error: "Forbidden" });
  }

  try {
    const redis = await getRedis();
    const ip = clientIp(req);
    const allowed = await checkRateLimit(redis, `auth:${ip}`, 40, 60);
    if (!allowed) {
      return json(res, 429, { ok: false, error: "Too many attempts" });
    }

    const body = await readJsonBody(req);
    const username = normalizeUsername(body.username);
    const password = String(body.password || "");
    const hwid = String(body.hwid || "").trim();
    const robloxUser = String(body.robloxUser || "").trim();
    const robloxUserId = body.robloxUserId;

    if (!username || !password || !hwid) {
      return json(res, 400, { ok: false, error: "Missing username, password, or hwid" });
    }

    const account = await redis.get(accountKey(username));
    if (!account) {
      return json(res, 401, { ok: false, error: "Invalid login" });
    }

    if (account.password_hash !== hashPassword(password)) {
      return json(res, 401, { ok: false, error: "Invalid login" });
    }

    if (account.hwid && account.hwid !== hwid) {
      return json(res, 403, {
        ok: false,
        error: "HWID mismatch. Use Discord HWID Reset.",
      });
    }

    if (!account.hwid) {
      account.hwid = hwid;
      account.roblox_user = robloxUser || account.roblox_user || null;
      account.roblox_user_id = robloxUserId ?? account.roblox_user_id ?? null;
      account.last_login = new Date().toISOString();
      await redis.set(accountKey(username), account);
    } else {
      account.last_login = new Date().toISOString();
      if (robloxUser) account.roblox_user = robloxUser;
      if (robloxUserId != null) account.roblox_user_id = robloxUserId;
      await redis.set(accountKey(username), account);
    }

    const token = randomToken();
    await redis.set(tokenKey(token), username, { ex: 3600 });

    return json(res, 200, {
      ok: true,
      token,
      username: account.username || username,
      expiresIn: 3600,
    });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
};
