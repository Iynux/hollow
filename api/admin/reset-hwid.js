import { normalizeKey, normalizeUsername } from "../../lib/crypto.js";
import { accountKey, getRedis } from "../../lib/redis.js";
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
    const username = normalizeUsername(body.username);
    const keyValue = normalizeKey(body.key);

    const redis = getRedis();
    let account = null;

    if (username) {
      account = await redis.get(accountKey(username));
    }

    if (!account && keyValue) {
      const keys = await redis.keys("account:*");
      for (const redisKey of keys) {
        const item = await redis.get(redisKey);
        if (item && normalizeKey(item.key) === keyValue) {
          account = item;
          break;
        }
      }
    }

    if (!account) {
      return json(res, 404, { ok: false, error: "Account not found" });
    }

    const resolvedUsername = normalizeUsername(account.username || username);
    account.hwid = null;
    account.hwid_reset_at = new Date().toISOString();
    await redis.set(accountKey(resolvedUsername), account);

    return json(res, 200, { ok: true, username: resolvedUsername, hwid: null });
  } catch (err) {
    return json(res, 500, { ok: false, error: String(err?.message || err) });
  }
}
