import { normalizeKey, normalizeUsername } from "../../lib/crypto.js";
import { accountKey, getRedis, keyRecordKey } from "../../lib/redis.js";
import { json, readJsonBody, requireAdmin } from "../../lib/http.js";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return json(res, 405, { ok: false, error: "POST only" });
  }
  if (!requireAdmin(req, res)) {
    return;
  }

  try {
    const body = await readJsonBody(req);
    const account = body.account || body;
    const username = normalizeUsername(account.username);
    const keyValue = normalizeKey(account.key);

    if (!username || !keyValue) {
      return json(res, 400, { ok: false, error: "Missing username or key" });
    }

    const redis = getRedis();
    const record = {
      username,
      password_hash: account.password_hash,
      key: keyValue,
      hwid: account.hwid ?? null,
      discord_id: account.discord_id ?? null,
      discord_name: account.discord_name ?? null,
      registered_at: account.registered_at ?? new Date().toISOString(),
      last_login: account.last_login ?? null,
      roblox_user: account.roblox_user ?? null,
      roblox_user_id: account.roblox_user_id ?? null,
    };

    await redis.set(accountKey(username), record);

    const keyRecord = (await redis.get(keyRecordKey(keyValue))) || {
      key: keyValue,
      script: "hollow",
    };
    keyRecord.status = "claimed";
    keyRecord.discord_id = record.discord_id;
    keyRecord.discord_name = record.discord_name;
    keyRecord.claimed_at = keyRecord.claimed_at || record.registered_at;
    await redis.set(keyRecordKey(keyValue), keyRecord);

    return json(res, 200, { ok: true, username, key: keyValue });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
}
