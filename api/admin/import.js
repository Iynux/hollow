const { normalizeUsername } = require("../../lib/crypto");
const { accountKey, getRedis, keyRecordKey, linkKeyToAccount } = require("../../lib/redis");
const { json, readJsonBody, requireAdmin } = require("../../lib/http");

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }
  if (!requireAdmin(req, res)) {
    return;
  }

  try {
    const body = await readJsonBody(req);
    const accounts = Array.isArray(body.accounts) ? body.accounts : [];
    const keys = Array.isArray(body.keys) ? body.keys : [];
    const redis = await getRedis();
    let accountCount = 0;
    let keyCount = 0;

    for (const entry of keys) {
      const keyValue = String(entry.key || "").trim().toUpperCase();
      if (!keyValue) continue;
      await redis.set(keyRecordKey(keyValue), {
        key: keyValue,
        script: entry.script || "hollow",
        status: entry.status || "available",
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        claimed_at: entry.claimed_at ?? null,
        sent_by: entry.sent_by ?? null,
      });
      keyCount += 1;
    }

    for (const entry of accounts) {
      const username = normalizeUsername(entry.username);
      if (!username) continue;
      await redis.set(accountKey(username), {
        username,
        password_hash: entry.password_hash,
        key: String(entry.key || "").trim().toUpperCase(),
        hwid: entry.hwid ?? null,
        discord_id: entry.discord_id ?? null,
        discord_name: entry.discord_name ?? null,
        registered_at: entry.registered_at ?? null,
        hwid_reset_at: entry.hwid_reset_at ?? null,
        last_login: entry.last_login ?? null,
        roblox_user: entry.roblox_user ?? null,
        roblox_user_id: entry.roblox_user_id ?? null,
      });
      await linkKeyToAccount(redis, entry.key, username);
      accountCount += 1;
    }

    return json(res, 200, {
      ok: true,
      accounts: accountCount,
      keys: keyCount,
    });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
};
