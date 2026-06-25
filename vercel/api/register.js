const { hashPassword, normalizeKey, normalizeUsername } = require("../lib/crypto");
const { accountKey, getRedis, keyRecordKey, linkKeyToAccount } = require("../lib/redis");
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
    const allowed = await checkRateLimit(redis, `register:${clientIp(req)}`, 20, 60);
    if (!allowed) {
      return json(res, 429, { ok: false, error: "Too many attempts" });
    }

    const body = await readJsonBody(req);
    const keyValue = normalizeKey(body.key);
    const username = normalizeUsername(body.username);
    const password = String(body.password || "");
    const discordId = body.discord_id ?? body.discordId ?? null;
    const discordName = String(body.discord_name || body.discordName || "").trim();

    if (!keyValue || !username || !password) {
      return json(res, 400, { ok: false, error: "Missing key, username, or password" });
    }
    if (username.length < 3) {
      return json(res, 400, { ok: false, error: "Username must be at least 3 characters" });
    }
    if (password.length < 4) {
      return json(res, 400, { ok: false, error: "Password must be at least 4 characters" });
    }

    const existingAccount = await redis.get(accountKey(username));
    if (existingAccount) {
      return json(res, 409, { ok: false, error: "Username already taken" });
    }

    const keyRecord = await redis.get(keyRecordKey(keyValue));
    if (!keyRecord) {
      return json(res, 404, { ok: false, error: "Invalid key" });
    }

    if (keyRecord.status === "claimed") {
      const owner = keyRecord.discord_id;
      if (owner && discordId && String(owner) !== String(discordId)) {
        return json(res, 403, { ok: false, error: "That key belongs to someone else" });
      }
    }

    const account = {
      username,
      password_hash: hashPassword(password),
      key: keyValue,
      hwid: null,
      discord_id: discordId,
      discord_name: discordName || null,
      registered_at: new Date().toISOString(),
      last_login: null,
      roblox_user: null,
      roblox_user_id: null,
    };

    await redis.set(accountKey(username), account);
    await linkKeyToAccount(redis, keyValue, username);

    keyRecord.status = "claimed";
    keyRecord.discord_id = discordId;
    keyRecord.discord_name = discordName || keyRecord.discord_name || null;
    keyRecord.claimed_at = keyRecord.claimed_at || new Date().toISOString();
    await redis.set(keyRecordKey(keyValue), keyRecord);

    return json(res, 200, { ok: true, username, key: keyValue });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
};
